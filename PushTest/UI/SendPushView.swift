import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SendPushView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var state: PushToolState

    @State private var isImportingP8 = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                credentialsSection
                targetSection
                payloadSection
                resultSection
            }
            .padding(20)
        }
        .fileImporter(
            isPresented: $isImportingP8,
            allowedContentTypes: [UTType(filenameExtension: "p8") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleP8Import(result: result)
        }
    }

    private var credentialsSection: some View {
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

    private var targetSection: some View {
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

                HStack(alignment: .top, spacing: 12) {
                    Picker("Priority", selection: $state.priority) {
                        Text("10 (Immediate)").tag(10)
                        Text("5 (Power Saving)").tag(5)
                    }
                    .pickerStyle(.segmented)

                    TextField("Collapse ID (optional)", text: $state.collapseID)
                        .textFieldStyle(.roundedBorder)
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

    private var payloadSection: some View {
        GroupBox("Payload") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button("Apply \(state.event.displayName) Template") {
                        state.applyTemplateForCurrentEvent()
                    }
                    .buttonStyle(.bordered)

                    Button("Validate") {
                        _ = state.validatePayload()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

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
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.canSend)
                }

                TextEditor(text: $state.payloadJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(state.validationErrors.isEmpty ? Color.gray.opacity(0.2) : .red, lineWidth: 1)
                    }

                if !state.validationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.validationErrors, id: \.self) { error in
                            Text("• \(error)")
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    }
                }

                Text("Security note: History stores full token values in local SwiftData for replay. UI shows masked token only.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        GroupBox("Result") {
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
            .padding(.top, 4)
        }
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
