import Foundation
import Observation
import SwiftData

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case send
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .send:
            "Send"
        case .history:
            "History"
        }
    }

    var systemImage: String {
        switch self {
        case .send:
            "paperplane.fill"
        case .history:
            "clock.arrow.circlepath"
        }
    }
}

@MainActor
@Observable
final class PushToolState {
    var selectedTab: AppTab = .send

    var teamID: String = ""
    var keyID: String = ""
    var bundleID: String = ""
    var p8PEM: String = ""
    var importedP8Filename: String?

    var environment: APNsEnvironment = .sandbox
    var pushType: APNsPushType = .alert {
        didSet {
            guard pushType != oldValue else { return }
            applyTemplateForCurrentSelectionIfNeeded()
        }
    }
    var event: LiveActivityEvent = .start {
        didSet {
            guard event != oldValue else { return }
            guard isLiveActivityMode else { return }
            applyLiveActivityEventToPayloadIfPossible()
        }
    }
    var deviceToken: String = ""
    var priority: Int = 10
    var collapseID: String = ""
    var topicOverride: String = ""
    var payloadJSON: String = APNsPayloadTemplates.template(pushType: .alert, event: .start)

    var validationErrors: [String] = []
    var result: APNsSendResult?
    var requestTopic: String?
    var sendErrorMessage: String?
    var infoMessage: String?
    var isSending = false

    @ObservationIgnored
    private let sender: APNsSending

    @ObservationIgnored
    private var isReplayingHistory = false

    init() {
        sender = APNsClient()
    }

    init(sender: APNsSending) {
        self.sender = sender
    }

    var credentials: APNsCredentials {
        APNsCredentials(teamID: teamID.trimmed, keyID: keyID.trimmed, bundleID: bundleID.trimmed, p8PEM: p8PEM)
    }

    var hasValidCredentials: Bool {
        credentials.isValid
    }

    var isLiveActivityMode: Bool {
        pushType.isLiveActivity
    }

    var defaultTopicDescription: String {
        let bundle = bundleID.trimmed.nilIfEmpty ?? "<BundleID>"
        return pushType.defaultTopic(for: bundle)
    }

    var canSend: Bool {
        !isSending &&
        !deviceToken.trimmed.isEmpty &&
        hasValidCredentials
    }

    func applyTemplateForCurrentSelection() {
        payloadJSON = APNsPayloadTemplates.template(pushType: pushType, event: event)
        validationErrors = []
    }

    func requiresTemplateOverwriteConfirmation() -> Bool {
        guard !payloadJSON.trimmed.isEmpty else { return false }
        return !payloadMatchesCurrentTemplate()
    }

    func payloadMatchesCurrentTemplate() -> Bool {
        let currentTemplate = APNsPayloadTemplates.template(pushType: pushType, event: event)

        do {
            let normalizedPayload = try JSONPayloadFormatter.format(payloadJSON)
            let normalizedTemplate = try JSONPayloadFormatter.format(currentTemplate)
            return normalizedPayload == normalizedTemplate
        } catch {
            return false
        }
    }

    func clearCredentials() {
        teamID = ""
        keyID = ""
        bundleID = ""
        clearImportedP8State()
    }

    func importP8(text: String, fileName: String) {
        p8PEM = text
        importedP8Filename = fileName

        if keyID.trimmed.isEmpty,
           let extractedKeyID = P8KeyIDExtractor.extract(fromFileName: fileName) {
            keyID = extractedKeyID
            infoMessage = "Imported \(fileName) into memory only. Auto-filled Key ID: \(extractedKeyID)."
        } else {
            infoMessage = "Imported \(fileName) into memory only."
        }
    }

    func validatePayload() -> Bool {
        validationErrors = []

        if deviceToken.trimmed.isEmpty {
            validationErrors.append("Push token is required.")
        }

        let payloadErrors = PayloadValidator.validate(
            payloadJSON: payloadJSON,
            event: event,
            pushType: pushType
        )
        validationErrors.append(contentsOf: payloadErrors)

        return validationErrors.isEmpty
    }

    func loadFromHistory(_ record: PushHistoryRecord) {
        selectedTab = .send
        isReplayingHistory = true
        defer { isReplayingHistory = false }

        if let teamID = record.credentialTeamID?.nilIfEmpty,
           let keyID = record.credentialKeyID?.nilIfEmpty,
           let bundleID = record.credentialBundleID?.nilIfEmpty {
            self.teamID = teamID
            self.keyID = keyID
            self.bundleID = bundleID
        } else {
            clearCredentials()
        }
        clearImportedP8State()

        environment = record.environment
        pushType = record.pushType
        event = record.event
        deviceToken = record.deviceToken
        priority = record.priority
        collapseID = record.collapseID ?? ""
        topicOverride = record.topicOverrideInput ?? ""
        payloadJSON = record.payloadJSON
        validationErrors = []
        result = nil
        requestTopic = nil
        sendErrorMessage = nil
        infoMessage = nil
    }

    func loadFromHistorySnapshot(_ snapshot: HistoryDetailSnapshot) {
        selectedTab = .send
        isReplayingHistory = true
        defer { isReplayingHistory = false }

        if let teamID = snapshot.credentialTeamID?.nilIfEmpty,
           let keyID = snapshot.credentialKeyID?.nilIfEmpty,
           let bundleID = snapshot.credentialBundleID?.nilIfEmpty {
            self.teamID = teamID
            self.keyID = keyID
            self.bundleID = bundleID
        } else {
            clearCredentials()
        }
        clearImportedP8State()

        environment = snapshot.environment
        pushType = snapshot.pushType
        event = snapshot.event
        deviceToken = snapshot.deviceToken
        priority = snapshot.priority
        collapseID = snapshot.collapseID ?? ""
        topicOverride = snapshot.topicOverrideInput ?? ""
        payloadJSON = snapshot.payloadJSON
        validationErrors = []
        result = nil
        requestTopic = nil
        sendErrorMessage = nil
        infoMessage = nil
    }

    func sendPush(modelContext: ModelContext) async {
        clearResultState()

        guard validatePayload() else {
            sendErrorMessage = "Validation failed. Fix payload or token and try again."
            return
        }

        guard hasValidCredentials else {
            sendErrorMessage = "Team ID, Key ID, Bundle ID, and P8 are all required."
            return
        }

        isSending = true
        defer { isSending = false }

        let draft = PushRequestDraft(
            event: event,
            pushType: pushType,
            deviceToken: deviceToken,
            priority: priority,
            collapseID: collapseID,
            payloadJSON: payloadJSON,
            topicOverride: topicOverride
        )

        let topic = draft.normalizedTopicOverride ?? draft.pushType.defaultTopic(for: credentials.bundleID)
        requestTopic = topic

        do {
            let sendResult = try await sender.send(
                draft: draft,
                credentials: credentials,
                environment: environment
            )
            result = sendResult

            try PushHistoryStore(context: modelContext).add(
                draft: draft,
                environment: environment,
                topic: topic,
                result: sendResult,
                credentialTeamID: credentials.teamID,
                credentialKeyID: credentials.keyID,
                credentialBundleID: credentials.bundleID
            )

            infoMessage = sendResult.isSuccess ? "Push sent successfully." : "Push sent but APNs returned an error."
        } catch {
            sendErrorMessage = error.localizedDescription
        }
    }

    private func clearImportedP8State() {
        p8PEM = ""
        importedP8Filename = nil
    }

    func clearResultState() {
        sendErrorMessage = nil
        infoMessage = nil
        result = nil
        requestTopic = nil
    }

    func resetSendFormToDefaults() {
        clearCredentials()
        environment = .sandbox
        pushType = .alert
        event = .start
        deviceToken = ""
        priority = 10
        collapseID = ""
        topicOverride = ""
        payloadJSON = APNsPayloadTemplates.template(pushType: .alert, event: .start)
        validationErrors = []
        clearResultState()
    }

    private func applyTemplateForCurrentSelectionIfNeeded() {
        guard !isReplayingHistory else { return }
        applyTemplateForCurrentSelection()
    }

    private func applyLiveActivityEventToPayloadIfPossible() {
        guard !isReplayingHistory else { return }

        guard let updatedPayload = payloadByUpdatingLiveActivityEvent(payloadJSON, event: event) else {
            return
        }

        if updatedPayload != payloadJSON {
            payloadJSON = updatedPayload
        }
    }

    private func payloadByUpdatingLiveActivityEvent(_ text: String, event: LiveActivityEvent) -> String? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        guard var rootObject = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return nil
        }

        var apsObject = (rootObject["aps"] as? [String: Any]) ?? [:]
        apsObject["event"] = event.rawValue
        rootObject["aps"] = apsObject

        guard let updatedData = try? JSONSerialization.data(withJSONObject: rootObject, options: []) else {
            return nil
        }
        guard let updatedText = String(data: updatedData, encoding: .utf8) else {
            return nil
        }

        return (try? JSONPayloadFormatter.format(updatedText)) ?? updatedText
    }

}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
