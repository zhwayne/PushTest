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
    var event: LiveActivityEvent = .start
    var deviceToken: String = ""
    var priority: Int = 10
    var collapseID: String = ""
    var topicOverride: String = ""
    var payloadJSON: String = LiveActivityPayloadTemplates.template(for: .start)

    var validationErrors: [String] = []
    var result: APNsSendResult?
    var requestTopic: String?
    var sendErrorMessage: String?
    var infoMessage: String?
    var isSending = false

    @ObservationIgnored
    private let sender: APNsSending

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

    var canSend: Bool {
        !isSending &&
        !deviceToken.trimmed.isEmpty &&
        hasValidCredentials
    }

    func applyTemplateForCurrentEvent() {
        payloadJSON = LiveActivityPayloadTemplates.template(for: event)
        validationErrors = []
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

        let payloadErrors = PayloadValidator.validate(payloadJSON: payloadJSON, event: event)
        validationErrors.append(contentsOf: payloadErrors)

        return validationErrors.isEmpty
    }

    func loadFromHistory(_ record: PushHistoryRecord) {
        selectedTab = .send

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

    func sendPush(modelContext: ModelContext) async {
        sendErrorMessage = nil
        infoMessage = nil
        result = nil
        requestTopic = nil

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
            deviceToken: deviceToken,
            priority: priority,
            collapseID: collapseID,
            payloadJSON: payloadJSON,
            topicOverride: topicOverride
        )

        let topic = draft.normalizedTopicOverride ?? "\(credentials.bundleID).push-type.liveactivity"
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
