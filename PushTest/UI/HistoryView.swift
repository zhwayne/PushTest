import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \PushHistoryRecord.createdAt, order: .reverse) private var records: [PushHistoryRecord]

    @Bindable var state: PushToolState

    @State private var selectedEnvironment: APNsEnvironment?
    @State private var selectedPushType: APNsPushType?
    @State private var selectedEvent: LiveActivityEvent?
    @State private var statusFilter: StatusFilter = .all
    @State private var searchText: String = ""
    @State private var selectedRecordID: PushHistoryRecord.ID?
    @State private var isClearHistoryConfirmationPresented = false
    @State private var localMessage: String?
    @State private var localError: String?
    @State private var lastOpenedDetailRecordID: PushHistoryRecord.ID?
    @State private var lastOpenedDetailAt: Date = .distantPast

    private let detailOpenDedupInterval: TimeInterval = 0.25

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controls
            actionsBar
            feedbackMessages

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.badge.xmark",
                    description: Text("Send a push request to populate history.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                historyTable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .alert("Clear History?", isPresented: $isClearHistoryConfirmationPresented) {
            Button("Clear", role: .destructive) {
                clearHistory()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove all history records.")
        }
        .onChange(of: filteredRecordIDs) { _, visibleIDs in
            if let selectedRecordID,
               !visibleIDs.contains(selectedRecordID) {
                self.selectedRecordID = nil
            }
        }
        .onChange(of: selectedRecordID) { _, _ in
            localError = nil
        }
    }

    private var feedbackMessages: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let localMessage {
                Text(localMessage)
                    .foregroundStyle(.secondary)
            }

            if let localError {
                Text(localError)
                    .foregroundStyle(.red)
            }

            Text("Double-click a row to open details in a new window.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var historyTable: some View {
        Table(filteredRecords, selection: $selectedRecordID) {
            TableColumn("Time") { record in
                detailCell {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .standard))
                        .font(.subheadline)
                }
            }
            .width(min: 180, ideal: 200)

            TableColumn("Environment") { record in
                detailCell {
                    Text(record.environment.displayName)
                        .font(.caption)
                }
            }
            .width(min: 110, ideal: 130)

            TableColumn("Push Type") { record in
                detailCell {
                    pushTypeBadge(for: record)
                }
            }
            .width(min: 130, ideal: 160)

            TableColumn("Event") { record in
                detailCell {
                    Text(record.event.displayName)
                        .font(.caption)
                }
            }
            .width(min: 90, ideal: 110)

            TableColumn("Status") { record in
                detailCell {
                    Text("\(record.statusCode)")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor(for: record.statusCode).opacity(0.15), in: .capsule)
                }
            }
            .width(min: 90, ideal: 105)

            TableColumn("Latency") { record in
                detailCell {
                    Text("\(record.latencyMs) ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 90, ideal: 110)

            TableColumn("Token Suffix") { record in
                detailCell {
                    Text(tokenSuffix(from: record.tokenMasked))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 130, ideal: 160)
        }
        .contextMenu {
            if let selectedRecord {
                Button("Open Detail") {
                    openDetailWindow(for: selectedRecord)
                }

                Button("Replay") {
                    replay(selectedRecord)
                }
                .disabled(selectedRecord.unsupportedPushTypeRaw != nil)

                Button("Copy cURL") {
                    copyCURL(for: selectedRecord)
                }
            }
        }
        .onTapGesture(count: 2) {
            openDetailWindowForSelectedRecord()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var actionsBar: some View {
        HStack(spacing: 10) {
            Button("Replay") {
                replaySelectedRecord()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canReplaySelectedRecord)
            .help(replayDisabledReason)

            Button("Copy cURL") {
                copyCURLFromSelectedRecord()
            }
            .buttonStyle(.bordered)
            .disabled(selectedRecord == nil)

            Spacer()

            Button("Clear History") {
                isClearHistoryConfirmationPresented = true
            }
            .buttonStyle(.bordered)
        }
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
                .pickerStyle(.menu)
                .frame(width: 220)

                Picker("Event", selection: $selectedEvent) {
                    Text("All").tag(Optional<LiveActivityEvent>.none)
                    ForEach(LiveActivityEvent.allCases) { event in
                        Text(event.displayName).tag(Optional(event))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Picker("Push Type", selection: $selectedPushType) {
                    Text("All").tag(Optional<APNsPushType>.none)
                    ForEach(APNsPushType.allCases) { pushType in
                        Text(pushType.displayName).tag(Optional(pushType))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Picker("Status", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Spacer()
            }

            TextField("Search by token suffix, reason, push type, or topic", text: $searchText)
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

            if let selectedPushType,
               (record.unsupportedPushTypeRaw != nil || record.pushType != selectedPushType) {
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

            if record.pushType.rawValue.localizedStandardContains(trimmedSearch) {
                return true
            }

            if let pushTypeRaw = record.pushTypeRaw,
               pushTypeRaw.localizedStandardContains(trimmedSearch) {
                return true
            }

            if record.topic.localizedStandardContains(trimmedSearch) {
                return true
            }

            return false
        }
    }

    private var filteredRecordIDs: Set<PushHistoryRecord.ID> {
        Set(filteredRecords.map(\.id))
    }

    private var selectedRecord: PushHistoryRecord? {
        guard let selectedID = selectedRecordID else {
            return nil
        }
        return filteredRecords.first { $0.id == selectedID } ?? records.first { $0.id == selectedID }
    }

    private var canReplaySelectedRecord: Bool {
        guard let selectedRecord else { return false }
        return selectedRecord.unsupportedPushTypeRaw == nil
    }

    private var replayDisabledReason: String {
        guard let selectedRecord else {
            return "Select a history record to replay."
        }

        if let unsupportedRaw = selectedRecord.unsupportedPushTypeRaw {
            return "Replay unavailable for unsupported push type \"\(unsupportedRaw)\"."
        }

        return "Replay selected request in Send."
    }

    private func replaySelectedRecord() {
        guard let selectedRecord else { return }
        replay(selectedRecord)
    }

    private func replay(_ record: PushHistoryRecord) {
        if let unsupportedRaw = record.unsupportedPushTypeRaw {
            localError = "Replay unavailable for unsupported push type \"\(unsupportedRaw)\"."
            localMessage = nil
            return
        }

        state.loadFromHistory(record)
        localError = nil
        localMessage = "Loaded request into Send."
    }

    private func openDetailWindow(for record: PushHistoryRecord) {
        let now = Date()
        if lastOpenedDetailRecordID == record.id,
           now.timeIntervalSince(lastOpenedDetailAt) < detailOpenDedupInterval {
            return
        }
        lastOpenedDetailRecordID = record.id
        lastOpenedDetailAt = now
        openWindow(value: HistoryDetailSnapshot(record: record))
    }

    private func openDetailWindowForSelectedRecord() {
        guard let selectedRecord else { return }
        openDetailWindow(for: selectedRecord)
    }

    private func detailCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func copyCURLFromSelectedRecord() {
        guard let selectedRecord else { return }
        copyCURL(for: selectedRecord)
    }

    private func copyCURL(for record: PushHistoryRecord) {
        PasteboardHelper.copy(CurlCommandBuilder.build(from: record))
        localMessage = "Copied cURL for \(record.createdAt.formatted(date: .abbreviated, time: .shortened))."
        localError = nil
    }

    private func clearHistory() {
        do {
            try PushHistoryStore(context: modelContext).clearAll()
            selectedRecordID = nil
            localMessage = "History cleared."
            localError = nil
        } catch {
            localError = "Failed to clear history: \(error.localizedDescription)"
            localMessage = nil
        }
    }

    private func tokenSuffix(from maskedToken: String) -> String {
        let trimmed = maskedToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }
        return String(trimmed.suffix(8))
    }

    @ViewBuilder
    private func pushTypeBadge(for record: PushHistoryRecord) -> some View {
        if let unsupportedRaw = record.unsupportedPushTypeRaw {
            Text("Unsupported (\(unsupportedRaw))")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.18), in: .capsule)
        } else {
            Text(record.pushType.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.teal.opacity(0.15), in: .capsule)
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
