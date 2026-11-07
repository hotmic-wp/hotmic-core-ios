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
                if model.playbackEnded {
                    Text(model.statusText)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .background(.black)
                        .listRowInsets(.init())
                } else {
                    StreamVideoPlayerView(stream: model.stream)
                        .listRowInsets(.init())
                }
            } footer: {
                Text(model.statusText)
            }

            if let participants = model.participants {
                Section("Participants") {
                    Text("Host: \(participants.host.name ?? "Host")")
                    Text(
                        "Room \(participants.room.count) · Cohosts \(participants.cohosts.count) · " +
                            "Guests \(participants.guests.count) · Waiting \(participants.waiting.count)"
                    )
                        .font(.caption)
                }
            }

            if !model.polls.isEmpty {
                Section("Polls") {
                    ForEach(model.polls, id: \.id) { poll in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(poll.question ?? "Poll").font(.headline)
                            Text("\(poll.responses) responses\(poll.closed ? " · Closed" : "")")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(poll.options, id: \.id) { option in
                                Button("\(option.answer) (\(option.responses))") {
                                    Task { await model.answer(poll, option: option) }
                                }
                                .disabled(!model.canAnswer(poll))
                            }
                        }
                    }
                }
            }

            if !model.isStarting {
                Section {
                    if model.chatMessages.isEmpty {
                        Text("No chat messages yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.chatMessages, id: \.id) { message in
                            ChatMessageRow(message: message, model: model)
                        }
                    }
                }
            }

            Section {
                DisclosureGroup("Event trace (\(model.eventTrace.count))") {
                    ForEach(model.eventCounts.keys.sorted(), id: \.self) { key in
                        Text("\(key): \(model.eventCounts[key, default: 0])")
                            .font(.caption.monospacedDigit())
                    }
                    ForEach(model.eventTrace) { entry in
                        Text("\(entry.time.formatted(date: .omitted, time: .standard))  \(entry.text)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
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
    let model: StreamSessionModel

    var body: some View {
        let name = Text(message.userName).font(.headline)
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: message.profilePic) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
            }
            .frame(width: 22, height: 22)
            .clipShape(.circle)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(name): \(message.message)")
                Button {
                    Task { await model.toggleLike(message) }
                } label: {
                    Label(
                        "\(model.likeCount(message))",
                        systemImage: model.isLiked(message) ? "hand.thumbsup.fill" : "hand.thumbsup"
                    )
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(model.isLiked(message) ? "Remove like" : "Add like")
                .disabled(model.isLikePending(message))
            }
            Spacer(minLength: 0)
            Menu {
                Button("Report message") { Task { await model.report(message) } }
                if model.canDelete(message) {
                    Button("Delete message", role: .destructive) {
                        Task { await model.delete(message) }
                    }
                }
                Divider()
                Button("Block user") { Task { await model.block(message) } }
                Button("Unblock user") { Task { await model.unblock(message) } }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Message actions")
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
