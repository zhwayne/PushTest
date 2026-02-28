import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SendPushView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: PushToolState

    @State private var isImportingP8 = false
    @State private var payloadFormatMessage: String?

    private let wideLayoutThreshold: CGFloat = 960
    private let sidebarWidth: CGFloat = 540
    private let compactPayloadMinHeight: CGFloat = 450
    private let resultMinHeight: CGFloat = 170
    private let resultMaxHeight: CGFloat = 240

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch layoutMode(for: proxy.size.width) {
                case .wide:
                    wideLayout
                case .compact:
                    compactLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .fileImporter(
            isPresented: $isImportingP8,
            allowedContentTypes: [UTType(filenameExtension: "p8") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleP8Import(result: result)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                applyTemplateToolbarButton
                validateToolbarButton
                useCurrentTimestampToolbarButton
                formatJSONToolbarButton
                sendPushToolbarButton
            }
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                credentialsPanel
                targetPanel
                Spacer(minLength: 0)
            }
            .frame(width: sidebarWidth, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 16) {
                payloadPanel(isWide: true)
                if shouldShowResultPanel {
                    resultPanel(maxHeight: resultMaxHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                credentialsPanel
                targetPanel
                payloadPanel(isWide: false)
                if shouldShowResultPanel {
                    resultPanel(maxHeight: resultMaxHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var credentialsPanel: some View {
        GroupBox("Credentials") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Team ID", text: $state.teamID)
                TextField("Key ID", text: $state.keyID)
                TextField("Bundle ID", text: $state.bundleID)

                HStack(spacing: 12) {
                    Button("Import P8") {
                        isImportingP8 = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear Credentials") {
                        state.clearCredentials()
                    }
                    .buttonStyle(.bordered)

                    if let filename = state.importedP8Filename {
                        Text(filename)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No P8 loaded")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("P8 is stored in memory only and is cleared when app exits or you tap Clear Credentials.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .textFieldStyle(.roundedBorder)
            .padding(.top, 4)
        }
    }

    private var targetPanel: some View {
        GroupBox("Target") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("APNs Environment", selection: $state.environment) {
                    ForEach(APNsEnvironment.allCases) { environment in
                        Text(environment.displayName).tag(environment)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Event", selection: $state.event) {
                    ForEach(LiveActivityEvent.allCases) { event in
                        Text(event.displayName).tag(event)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Push Token (start/update/end)", text: $state.deviceToken)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Picker("Priority", selection: $state.priority) {
                        Text("10 (Immediate)").tag(10)
                        Text("5 (Power Saving)").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    
                    Spacer(minLength: 0)

                    TextField("Collapse ID (optional)", text: $state.collapseID)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 210)
                }

                TextField("Topic Override (optional)", text: $state.topicOverride)
                    .textFieldStyle(.roundedBorder)

                Text("Default topic: <BundleID>.push-type.liveactivity")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func payloadPanel(isWide: Bool) -> some View {
        GroupBox("Payload") {
            VStack(alignment: .leading, spacing: 12) {
                payloadEditor(isWide: isWide)

                if !state.validationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.validationErrors, id: \.self) { error in
                            Text("• \(error)")
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    }
                }

                if let payloadFormatMessage {
                    Text(payloadFormatMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Text("Security note: History stores full token values in local SwiftData for replay. UI shows masked token only.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            .padding(.top, 4)
            .frame(maxHeight: isWide ? .infinity : nil, alignment: .topLeading)
        }
        .frame(maxHeight: isWide ? .infinity : nil, alignment: .topLeading)
    }

    @ViewBuilder
    private func payloadEditor(isWide: Bool) -> some View {
        if isWide {
            payloadEditorBase
                .frame(minHeight: 200, maxHeight: .infinity)
        } else {
            payloadEditorBase
                .frame(minHeight: compactPayloadMinHeight)
        }
    }

    private var payloadEditorBase: some View {
        JSONCodeEditor(
            text: $state.payloadJSON,
            syntaxHighlighter: .shared,
            onTextChange: { _ in
                payloadFormatMessage = nil
            },
            onEditingEnded: {
                formatPayload(trigger: .automatic)
            }
        )
        .padding(4)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(state.validationErrors.isEmpty ? Color.gray.opacity(0.2) : .red, lineWidth: 1)
        }
    }

    private func resultPanel(maxHeight: CGFloat) -> some View {
        GroupBox("Result") {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let message = state.infoMessage {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage = state.sendErrorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    if let result = state.result {
                        LabeledContent("Status") {
                            Text("\(result.statusCode)")
                                .foregroundStyle(result.isSuccess ? .green : .red)
                        }

                        if let topic = state.requestTopic {
                            LabeledContent("Topic") {
                                Text(topic)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }

                        if let apnsID = result.apnsID {
                            LabeledContent("apns-id") {
                                Text(apnsID)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }

                        if let reason = result.reason,
                           !reason.isEmpty {
                            LabeledContent("Reason") {
                                Text(reason)
                            }
                        }

                        if let body = result.responseBody,
                           !body.isEmpty {
                            LabeledContent("Body") {
                                Text(body)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }

                        LabeledContent("Latency") {
                            Text("\(result.latencyMs) ms")
                        }
                    } else {
                        Text("No request sent yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: resultMinHeight, maxHeight: maxHeight)
        }
    }

    private var applyTemplateToolbarButton: some View {
        Button {
            state.applyTemplateForCurrentEvent()
            payloadFormatMessage = nil
        } label: {
            Label("Apply Template", systemImage: "doc.badge.gearshape")
        }
        .help("Apply Template")
    }

    private var validateToolbarButton: some View {
        Button {
            _ = state.validatePayload()
        } label: {
            Label("Validate", systemImage: "checkmark.seal")
        }
        .help("Validate")
    }

    private var formatJSONToolbarButton: some View {
        Button {
            formatPayload(trigger: .manual)
        } label: {
            Label("Format JSON", systemImage: "curlybraces.square")
        }
        .help("Format JSON")
    }

    private var useCurrentTimestampToolbarButton: some View {
        Button {
            applyCurrentTimestamp()
        } label: {
            Label("Use Current Timestamp", systemImage: "clock.arrow.circlepath")
        }
        .help("Use Current Timestamp")
    }

    private var sendPushToolbarButton: some View {
        Button {
            Task {
                await state.sendPush(modelContext: modelContext)
            }
        } label: {
            if state.isSending {
                Label("Sending...", systemImage: "hourglass")
            } else {
                Label("Send Push", systemImage: "paperplane")
            }
        }
        .help(state.isSending ? "Sending..." : "Send Push")
        .buttonStyle(.borderedProminent)
        .tint(state.canSend ? .accentColor : .gray)
        .disabled(!state.canSend)
    }

    private var shouldShowResultPanel: Bool {
        state.result != nil ||
        state.sendErrorMessage != nil ||
        state.infoMessage != nil
    }

    private func formatPayload(trigger: FormatTrigger) {
        do {
            let formatted = try JSONPayloadFormatter.format(state.payloadJSON)
            if formatted != state.payloadJSON {
                state.payloadJSON = formatted
            }
            payloadFormatMessage = nil
        } catch {
            switch trigger {
            case .manual:
                payloadFormatMessage = "Format failed: \(error.localizedDescription)"
            case .automatic:
                payloadFormatMessage = "Auto-format skipped: \(error.localizedDescription)"
            }
        }
    }

    private func applyCurrentTimestamp() {
        do {
            let updatedPayload = try payloadByUpdatingTimestamp(state.payloadJSON)
            if updatedPayload != state.payloadJSON {
                state.payloadJSON = updatedPayload
            }
            payloadFormatMessage = nil
        } catch {
            payloadFormatMessage = "Timestamp update failed: \(error.localizedDescription)"
        }
    }

    private func payloadByUpdatingTimestamp(_ text: String) throws -> String {
        guard let inputData = text.data(using: .utf8) else {
            throw TimestampUpdateError.invalidUTF8
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: inputData, options: [])
        } catch {
            throw TimestampUpdateError.invalidJSON
        }

        guard var rootObject = jsonObject as? [String: Any] else {
            throw TimestampUpdateError.invalidRootObject
        }

        var apsObject: [String: Any]
        if let existingAPS = rootObject["aps"] {
            guard let existingAPSObject = existingAPS as? [String: Any] else {
                throw TimestampUpdateError.invalidAPSObject
            }
            apsObject = existingAPSObject
        } else {
            apsObject = [:]
        }

        apsObject["timestamp"] = Int(Date().timeIntervalSince1970)
        rootObject["aps"] = apsObject

        let updatedData: Data
        do {
            updatedData = try JSONSerialization.data(withJSONObject: rootObject, options: [])
        } catch {
            throw TimestampUpdateError.unableToEncode
        }

        guard let updatedText = String(data: updatedData, encoding: .utf8) else {
            throw TimestampUpdateError.unableToEncode
        }

        return try JSONPayloadFormatter.format(updatedText)
    }

    private func layoutMode(for width: CGFloat) -> LayoutMode {
        width >= wideLayoutThreshold ? .wide : .compact
    }

    private func handleP8Import(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                state.sendErrorMessage = "No file selected."
                return
            }

            let hasScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    state.sendErrorMessage = "Unable to decode P8 file as UTF-8 text."
                    return
                }

                state.importP8(text: text, fileName: url.lastPathComponent)
                state.sendErrorMessage = nil
            } catch {
                state.sendErrorMessage = "Failed to read P8 file: \(error.localizedDescription)"
            }

        case let .failure(error):
            state.sendErrorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

private enum LayoutMode {
    case wide
    case compact
}

private enum FormatTrigger {
    case manual
    case automatic
}

private enum TimestampUpdateError: LocalizedError {
    case invalidUTF8
    case invalidJSON
    case invalidRootObject
    case invalidAPSObject
    case unableToEncode

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "Payload is not valid UTF-8."
        case .invalidJSON:
            "Payload is not valid JSON."
        case .invalidRootObject:
            "Payload root must be a JSON object."
        case .invalidAPSObject:
            "aps must be a JSON object."
        case .unableToEncode:
            "Unable to encode JSON payload."
        }
    }
}
