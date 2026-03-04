import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SendPushView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: PushToolState

    @State private var isImportingP8 = false
    @State private var activeAlert: PresentedAlert?
    @State private var pendingTemplateAction: PendingTemplateAction?
    @State private var payloadFormatMessage: String?

    private let horizontalPadding: CGFloat = 20
    private let splitDividerWidthAllowance: CGFloat = 2
    private let splitContentInset: CGFloat = 10
    private let wideLayoutThreshold: CGFloat = 900
    private let wideLeftColumnMinWidth: CGFloat = 460
    private let wideLeftColumnIdealWidth: CGFloat = 540
    private let wideRightColumnMinWidth: CGFloat = 420
    private let compactPayloadMinHeight: CGFloat = 360
    private let resultMinHeight: CGFloat = 200
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
            .padding(horizontalPadding)
        }
        .fileImporter(
            isPresented: $isImportingP8,
            allowedContentTypes: [UTType(filenameExtension: "p8") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleP8Import(result: result)
        }
        .alert(item: $activeAlert, content: alertContent)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                sendPushToolbarButton
                Spacer()
                validateToolbarButton
                applyTemplateToolbarButton
                formatJSONToolbarButton
                useCurrentTimestampToolbarButton
                Spacer()
                clearFormToolbarButton
            }
        }
    }

    private var wideLayout: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    credentialsPanel
                    targetPanel
                    resultPanel(maxHeight: resultMaxHeight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, splitContentInset)
            }
            .frame(minWidth: wideLeftColumnMinWidth, idealWidth: wideLeftColumnIdealWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()

            payloadPanel(isWide: true)
                .padding(.leading, splitContentInset)
                .frame(minWidth: wideRightColumnMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                credentialsPanel
                targetPanel
                payloadPanel(isWide: false)
                resultPanel(maxHeight: resultMaxHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var credentialsPanel: some View {
        GroupBox("Credentials") {
            VStack(alignment: .leading, spacing: 14) {
                Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        fieldGroup(title: "Team ID") {
                            TextField("Team ID", text: $state.teamID)
                        }

                        fieldGroup(title: "Key ID") {
                            TextField("Key ID", text: $state.keyID)
                        }
                    }

                    GridRow {
                        fieldGroup(title: "Bundle ID") {
                            TextField("Bundle ID", text: $state.bundleID)
                        }
                            .gridCellColumns(2)
                    }
                }
                .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button("Import P8") {
                        isImportingP8 = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear Credentials") {
                        state.clearCredentials()
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 0)

                    if let filename = state.importedP8Filename {
                        Text(filename)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No P8 loaded")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("P8 is stored in memory only and is cleared when app exits or you tap Clear Credentials.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var targetPanel: some View {
        GroupBox("Target") {
            VStack(alignment: .leading, spacing: 14) {
                Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        fieldGroup(title: "Environment") {
                            Picker("", selection: $state.environment) {
                                ForEach(APNsEnvironment.allCases) { environment in
                                    Text(environment.displayName).tag(environment)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .accessibilityLabel("APNs Environment")
                        }
                        fieldGroup(title: "Push Type") {
                            Picker("", selection: pushTypeSelection) {
                                ForEach(APNsPushType.allCases) { pushType in
                                    Text(pushType.displayName).tag(pushType)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .accessibilityLabel("APNs Push Type")
                        }
                    }

                    if state.isLiveActivityMode {
                        GridRow {
                            fieldGroup(title: "Event") {
                                Picker("", selection: eventSelection) {
                                    ForEach(LiveActivityEvent.allCases) { event in
                                        Text(event.displayName).tag(event)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .accessibilityLabel("Event")
                            }
                            .gridCellColumns(2)
                        }
                    }

                    GridRow {
                        fieldGroup(title: "Push Token") {
                            TextField("Push Token", text: $state.deviceToken)
                                .textFieldStyle(.roundedBorder)
                        }
                        .gridCellColumns(2)
                    }

                    GridRow {
                        fieldGroup(title: "Priority") {
                            Picker("", selection: $state.priority) {
                                Text("10 (Immediate)").tag(10)
                                Text("5 (Power Saving)").tag(5)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .accessibilityLabel("Priority")
                            .frame(minWidth: 180, alignment: .leading)
                        }

                        fieldGroup(title: "Collapse ID") {
                            TextField("Collapse ID (optional)", text: $state.collapseID)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    GridRow {
                        fieldGroup(title: "Topic Override") {
                            TextField("Topic Override (optional)", text: $state.topicOverride)
                                .textFieldStyle(.roundedBorder)
                        }
                        .gridCellColumns(2)
                    }
                }

                Text("Default topic: \(state.defaultTopicDescription)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func payloadPanel(isWide: Bool) -> some View {
        GroupBox("Payload") {
            VStack(alignment: .leading, spacing: 14) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: isWide ? .infinity : nil, alignment: .topLeading)
        .clipped()
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
        .clipped()
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

    private var validateToolbarButton: some View {
        Button {
            _ = state.validatePayload()
        } label: {
            Label("Validate", systemImage: "checkmark.seal")
        }
        .help("Validate")
    }

    private var applyTemplateToolbarButton: some View {
        Button {
            requestApplyTemplateAction()
        } label: {
            Label("Apply Template", systemImage: "doc.badge.gearshape")
        }
        .help("Apply Template")
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
        .disabled(!state.isLiveActivityMode)
        .help("Use Current Timestamp")
    }

    private var clearFormToolbarButton: some View {
        Button {
            activeAlert = .clearForm
        } label: {
            Label("Clear", systemImage: "trash")
        }
        .disabled(state.isSending)
        .help("Clear Form")
    }

    private var sendPushToolbarButton: some View {
        Button {
            state.clearResultState()
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
        .disabled(!state.canSend)
    }

    private var pushTypeSelection: Binding<APNsPushType> {
        Binding(
            get: { state.pushType },
            set: { newValue in
                requestTemplateAction(.pushType(newValue))
            }
        )
    }

    private var eventSelection: Binding<LiveActivityEvent> {
        Binding(
            get: { state.event },
            set: { newValue in
                requestTemplateAction(.event(newValue))
            }
        )
    }

    private func requestTemplateAction(_ action: PendingTemplateAction) {
        if action.matchesCurrentSelection(state) {
            return
        }

        if state.requiresTemplateOverwriteConfirmation() {
            pendingTemplateAction = action
            activeAlert = .templateOverwrite
            return
        }

        applyTemplateAction(action)
    }

    private func requestApplyTemplateAction() {
        if state.requiresTemplateOverwriteConfirmation() {
            pendingTemplateAction = .applyCurrentSelection
            activeAlert = .templateOverwrite
            return
        }

        state.applyTemplateForCurrentSelection()
        payloadFormatMessage = nil
    }

    private func applyPendingTemplateAction() {
        guard let action = pendingTemplateAction else { return }
        applyTemplateAction(action)
        pendingTemplateAction = nil
    }

    private func applyTemplateAction(_ action: PendingTemplateAction) {
        switch action {
        case .applyCurrentSelection:
            state.applyTemplateForCurrentSelection()
            payloadFormatMessage = nil
        case let .pushType(pushType):
            state.pushType = pushType
        case let .event(event):
            state.event = event
        }
    }

    private func alertContent(for alert: PresentedAlert) -> Alert {
        switch alert {
        case .clearForm:
            return Alert(
                title: Text("Clear Send Form?"),
                message: Text("This will clear credentials, target, payload, and current result."),
                primaryButton: .destructive(Text("Clear")) {
                    state.resetSendFormToDefaults()
                    payloadFormatMessage = nil
                },
                secondaryButton: .cancel()
            )
        case .templateOverwrite:
            return Alert(
                title: Text("Overwrite Payload with Template?"),
                message: Text(templateOverwriteMessage(for: pendingTemplateAction)),
                primaryButton: .destructive(Text("Apply")) {
                    applyPendingTemplateAction()
                },
                secondaryButton: .cancel {
                    pendingTemplateAction = nil
                }
            )
        }
    }

    private func templateOverwriteMessage(for action: PendingTemplateAction?) -> String {
        switch action {
        case .pushType, .event:
            return "Switching selection will apply a new template and overwrite the current payload."
        case .applyCurrentSelection:
            return "Applying template will overwrite the current payload."
        case nil:
            return "Applying template will overwrite the current payload."
        }
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
        width >= max(wideLayoutThreshold, wideMinimumRequiredWidth) ? .wide : .compact
    }

    private var wideMinimumRequiredWidth: CGFloat {
        wideLeftColumnMinWidth + wideRightColumnMinWidth + horizontalPadding * 2 + splitDividerWidthAllowance
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

private enum PendingTemplateAction {
    case applyCurrentSelection
    case pushType(APNsPushType)
    case event(LiveActivityEvent)

    func matchesCurrentSelection(_ state: PushToolState) -> Bool {
        switch self {
        case .applyCurrentSelection:
            return false
        case let .pushType(pushType):
            return state.pushType == pushType
        case let .event(event):
            return state.event == event
        }
    }
}

private enum PresentedAlert: Int, Identifiable {
    case clearForm
    case templateOverwrite

    var id: Int { rawValue }
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
