import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PushHistoryRecord.createdAt, order: .reverse) private var records: [PushHistoryRecord]

    @Bindable var state: PushToolState

    @State private var selectedEnvironment: APNsEnvironment?
    @State private var selectedEvent: LiveActivityEvent?
    @State private var statusFilter: StatusFilter = .all
    @State private var searchText: String = ""
    @State private var localMessage: String?
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controls

            if let localMessage {
                Text(localMessage)
                    .foregroundStyle(.secondary)
            }

            if let localError {
                Text(localError)
                    .foregroundStyle(.red)
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.badge.xmark",
                    description: Text("Send a push request to populate history.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredRecords) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(record.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.headline)

                            Spacer()

                            Text(record.environment.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.gray.opacity(0.15), in: .capsule)

                            Text(record.event.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.12), in: .capsule)

                            Text("\(record.statusCode)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(for: record.statusCode).opacity(0.15), in: .capsule)
                        }

                        HStack {
                            Text("Token: \(record.tokenMasked)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(record.latencyMs) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let reason = record.reason,
                           !reason.isEmpty {
                            Text("Reason: \(reason)")
                                .font(.caption)
                        }

                        HStack(spacing: 10) {
                            Button("Replay") {
                                state.loadFromHistory(record)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Copy cURL") {
                                PasteboardHelper.copy(CurlCommandBuilder.build(from: record))
                                localMessage = "Copied cURL for \(record.createdAt.formatted(date: .abbreviated, time: .shortened))."
                                localError = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("Environment", selection: $selectedEnvironment) {
                    Text("All").tag(Optional<APNsEnvironment>.none)
                    ForEach(APNsEnvironment.allCases) { environment in
                        Text(environment.displayName).tag(Optional(environment))
                    }
                }
                .frame(width: 220)

                Picker("Event", selection: $selectedEvent) {
                    Text("All").tag(Optional<LiveActivityEvent>.none)
                    ForEach(LiveActivityEvent.allCases) { event in
                        Text(event.displayName).tag(Optional(event))
                    }
                }
                .frame(width: 180)

                Picker("Status", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .frame(width: 180)

                Spacer()

                Button("Clear History") {
                    do {
                        try PushHistoryStore(context: modelContext).clearAll()
                        localMessage = "History cleared."
                        localError = nil
                    } catch {
                        localError = "Failed to clear history: \(error.localizedDescription)"
                        localMessage = nil
                    }
                }
                .buttonStyle(.bordered)
            }

            TextField("Search by token suffix or reason", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var filteredRecords: [PushHistoryRecord] {
        records.filter { record in
            if let selectedEnvironment,
               record.environment != selectedEnvironment {
                return false
            }

            if let selectedEvent,
               record.event != selectedEvent {
                return false
            }

            if !statusFilter.matches(statusCode: record.statusCode) {
                return false
            }

            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSearch.isEmpty else {
                return true
            }

            if record.tokenMasked.localizedStandardContains(trimmedSearch) {
                return true
            }

            if let reason = record.reason,
               reason.localizedStandardContains(trimmedSearch) {
                return true
            }

            return false
        }
    }

    private func statusColor(for code: Int) -> Color {
        (200..<300).contains(code) ? .green : .red
    }
}

private enum StatusFilter: String, CaseIterable, Identifiable {
    case all
    case success
    case failed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            "All"
        case .success:
            "Success"
        case .failed:
            "Failed"
        }
    }

    func matches(statusCode: Int) -> Bool {
        switch self {
        case .all:
            true
        case .success:
            (200..<300).contains(statusCode)
        case .failed:
            !(200..<300).contains(statusCode)
        }
    }
}
