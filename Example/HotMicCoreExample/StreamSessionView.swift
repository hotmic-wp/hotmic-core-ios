import SwiftUI
import Observation
import HotMicCore

struct StreamSessionView: View {
    @State private var model: StreamSessionModel

    init(client: HotMicClient, streamID: String, title: String?) {
        _model = State(initialValue: StreamSessionModel(
            client: client,
            streamID: streamID,
            initialTitle: title
        ))
    }

    var body: some View {
        List {
            Section {
                StreamVideoPlayerView(stream: model.stream)
                    .listRowInsets(.init())
            } footer: {
                Text(model.statusText)
            }

            if !model.isStarting {
                Section {
                    if model.chatMessages.isEmpty {
                        Text("No chat messages yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.chatMessages, id: \.id) { message in
                            ChatMessageRow(message: message)
                        }
                    }
                }
            }
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaBar(edge: .bottom) {
            ChatComposer(model: model)
        }
        .task {
            await model.start()
        }
        .onDisappear {
            Task { await model.stop() }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.dismissError() } }
            )
        ) {
            Button("OK") { model.dismissError() }
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
    }
}

private struct ChatMessageRow: View {
    let message: HotMicChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: message.profilePic) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
            }
            .frame(width: 22, height: 22)
            .clipShape(.circle)

            Text("\(Text(message.userName).font(.headline)): \(Text(message.message).font(.body))")
        }
    }
}

private struct ChatComposer: View {
    @Bindable var model: StreamSessionModel

    var body: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $model.messageText)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit {
                    Task { await model.sendMessage() }
                }

            Button {
                Task { await model.sendMessage() }
            } label: {
                if model.isSendingMessage {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(!model.canSendMessage)
            .accessibilityLabel("Send message")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .scenePadding(.horizontal)
        .padding(.vertical, 8)
    }
}
