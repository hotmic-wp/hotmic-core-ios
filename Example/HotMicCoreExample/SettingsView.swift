import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let model: StreamsModel
    @State private var apiKey: String
    @State private var accessToken: String

    init(model: StreamsModel) {
        self.model = model
        _apiKey = State(initialValue: model.apiKey)
        _accessToken = State(initialValue: model.accessToken)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("API Key & Access Token") {
                    CredentialField("API Key", text: $apiKey)
                    CredentialField("Access Token", text: $accessToken)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                        Task {
                            await model.updateCredentials(
                                apiKey: apiKey,
                                accessToken: accessToken
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct CredentialField: View {
    let title: String
    @Binding var text: String

    init(_ title: String, text: Binding<String>) {
        self.title = title
        _text = text
    }

    var body: some View {
        HStack {
            TextField(title, text: $text, prompt: Text(title))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            PasteButton(payloadType: String.self) { strings in
                text = strings.first ?? ""
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
        }
    }
}
