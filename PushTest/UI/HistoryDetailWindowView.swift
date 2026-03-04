import AppKit
import SwiftUI

enum HistoryDetailWindowIdentity {
    static let identifier = NSUserInterfaceItemIdentifier("PushTest.HistoryDetailWindow")
}

struct HistoryDetailSnapshot: Identifiable, Hashable, Codable {
    let id: UUID
    let createdAt: Date
    let environmentRaw: String
    let eventRaw: String
    let pushTypeRaw: String?
    let environmentName: String
    let pushTypeName: String
    let eventName: String
    let statusCode: Int
    let latencyMs: Int
    let topic: String
    let priority: Int
    let collapseID: String?
    let deviceToken: String
    let tokenMasked: String
    let apnsID: String?
    let reason: String?
    let responseBody: String?
    let payloadJSON: String
    let curlCommand: String
    let topicOverrideInput: String?
    let credentialTeamID: String?
    let credentialKeyID: String?
    let credentialBundleID: String?

    init(record: PushHistoryRecord) {
        id = UUID()
        createdAt = record.createdAt
        environmentRaw = record.environmentRaw
        eventRaw = record.eventRaw
        pushTypeRaw = record.pushTypeRaw
        environmentName = record.environment.displayName
        pushTypeName = record.unsupportedPushTypeRaw.map { "Unsupported (\($0))" } ?? record.pushType.displayName
        eventName = record.event.displayName
        statusCode = record.statusCode
        latencyMs = record.latencyMs
        topic = record.topic
        priority = record.priority
        collapseID = record.collapseID
        deviceToken = record.deviceToken
        tokenMasked = record.tokenMasked
        apnsID = record.apnsID
        reason = record.reason
        responseBody = record.responseBody
        payloadJSON = record.payloadJSON
        curlCommand = CurlCommandBuilder.build(from: record)
        topicOverrideInput = record.topicOverrideInput
        credentialTeamID = record.credentialTeamID
        credentialKeyID = record.credentialKeyID
        credentialBundleID = record.credentialBundleID
    }

    var environment: APNsEnvironment {
        APNsEnvironment(rawValue: environmentRaw) ?? .sandbox
    }

    var event: LiveActivityEvent {
        LiveActivityEvent(rawValue: eventRaw) ?? .update
    }

    var pushType: APNsPushType {
        APNsPushType(rawValue: pushTypeRaw ?? "") ?? .alert
    }

    var unsupportedPushTypeRaw: String? {
        guard let raw = pushTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return APNsPushType(rawValue: raw) == nil ? raw : nil
    }
}

struct HistoryDetailWindowView: View {
    @Environment(\.dismiss) private var dismiss

    let state: PushToolState
    let snapshot: HistoryDetailSnapshot

    @State private var feedbackMessage: String?

    private let contentSpacing: CGFloat = 16
    private let sectionCornerRadius: CGFloat = 12

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: contentSpacing) {
                headerSection
                overviewSection
                requestSection
                responseSection
                payloadSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    replay()
                } label: {
                    Label("Replay", systemImage: "highlighter")
                }
                .disabled(snapshot.unsupportedPushTypeRaw != nil)
                .help(replayDisabledReason)
                
                Spacer()
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copy(snapshot.payloadJSON, successMessage: "Payload copied.")
                } label: {
                    Label("Payload", systemImage: "doc")
                }
                .help("Copy payload JSON to clipboard.")
                
                Button {
                    copy(snapshot.deviceToken, successMessage: "Device token copied.")
                } label: {
                    Label("Token", systemImage: "key")
                }
                .disabled(snapshot.deviceToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Copy device token to clipboard.")
                
                Button {
                    copy(snapshot.curlCommand, successMessage: "cURL command copied.")
                } label: {
                    Label("cURL", systemImage: "terminal")
                }
                .help("Copy cURL command to clipboard.")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            feedbackMessageBar
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("History Detail")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 8) {
                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .standard))
                Text("•")
                Text(snapshot.environmentName)
                Text("•")
                Text(snapshot.pushTypeName)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var overviewSection: some View {
        sectionCard(title: "Overview") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .leading)], spacing: 12) {
                infoItem(label: "Status") {
                    Text("\(snapshot.statusCode)")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.16), in: .capsule)
                }

                infoItem(label: "Latency") {
                    Text("\(snapshot.latencyMs) ms")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                infoItem(label: "Event") {
                    Text(snapshot.eventName)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                infoItem(label: "Push Type") {
                    Text(snapshot.pushTypeName)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var requestSection: some View {
        sectionCard(title: "Request") {
            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 220), spacing: 12, alignment: .leading),
                GridItem(.flexible(minimum: 220), spacing: 12, alignment: .leading)
            ], spacing: 12) {
                detailItem(label: "Topic", value: snapshot.topic)
                detailItem(label: "Priority", value: "\(snapshot.priority)")
                detailItem(label: "Collapse ID", value: normalized(snapshot.collapseID))
                detailItem(label: "Token (masked)", value: snapshot.tokenMasked)
            }
        }
    }

    private var responseSection: some View {
        sectionCard(title: "Response") {
            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 220), spacing: 12, alignment: .leading),
                GridItem(.flexible(minimum: 220), spacing: 12, alignment: .leading)
            ], spacing: 12) {
                detailItem(label: "apns-id", value: normalized(snapshot.apnsID))
                detailItem(label: "Reason", value: normalized(snapshot.reason))
            }

            detailItem(label: "Body", value: responseBodyText)
                .padding(.top, 6)
        }
    }

    private var payloadSection: some View {
        sectionCard(title: "Payload") {
            highlightedPayloadText
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var statusColor: Color {
        (200..<300).contains(snapshot.statusCode) ? .green : .red
    }

    private var responseBodyText: String {
        normalized(snapshot.responseBody)
    }

    @ViewBuilder
    private var feedbackMessageBar: some View {
        if let feedbackMessage,
           !feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(spacing: 0) {
                Divider()
                Text(feedbackMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private func copy(_ text: String, successMessage: String) {
        PasteboardHelper.copy(text)
        feedbackMessage = successMessage
    }

    private var replayDisabledReason: String {
        if let unsupportedRaw = snapshot.unsupportedPushTypeRaw {
            return "Replay unavailable for unsupported push type \"\(unsupportedRaw)\"."
        }
        return "Replay this request in Send."
    }

    private func replay() {
        if let unsupportedRaw = snapshot.unsupportedPushTypeRaw {
            feedbackMessage = "Replay unavailable for unsupported push type \"\(unsupportedRaw)\"."
            return
        }

        state.loadFromHistorySnapshot(snapshot)
        dismiss()
    }

    private func normalized(_ text: String?) -> String {
        guard let text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "—"
        }
        return text
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous))
    }

    private func infoItem<Content: View>(label: String, @ViewBuilder value: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var highlightedPayloadText: some View {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(
                ofSize: 13,
                weight: .regular
            ),
            .foregroundColor: NSColor.labelColor
        ]
        let highlighted = JSONSyntaxHighlighter.shared.attributedString(
            for: snapshot.payloadJSON,
            baseAttributes: baseAttributes
        )

        if let attributed = try? AttributedString(highlighted, including: \.appKit) {
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(snapshot.payloadJSON)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
