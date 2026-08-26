import Foundation
import Observation
import HotMicCore

@MainActor
@Observable
final class StreamSessionModel {
    private let client: HotMicClient
    private let streamID: String
    private var session: HotMicStreamSession?
    private var eventTask: Task<Void, Never>?

    private(set) var stream: HotMicStream?
    private(set) var chatMessages: [HotMicChatMessage] = []
    private(set) var isStarting = false
    private(set) var isConnected = false
    private(set) var isSendingMessage = false
    private(set) var statusText = "Not Connected"
    private(set) var errorMessage: String?
    var messageText = ""
    var title: String

    init(client: HotMicClient, streamID: String, initialTitle: String?) {
        self.client = client
        self.streamID = streamID
        title = initialTitle ?? "Stream"
    }

    var canSendMessage: Bool {
        session?.state == .active && !isSendingMessage && !messageText.isEmpty
    }

    func start() async {
        guard session == nil else { return }

        let session = client.makeStreamSession(streamID: streamID)
        self.session = session
        isStarting = true
        statusText = "Connecting…"

        eventTask = Task { [weak self] in
            for await event in session.events {
                guard !Task.isCancelled else { break }
                self?.handle(event)
            }
        }

        do {
            let snapshot = try await session.start()
            stream = snapshot.stream
            title = snapshot.stream.title ?? title
            chatMessages = snapshot.chatMessages
            isConnected = true
            statusText = "Connected"
        } catch {
            guard self.session != nil else {
                isStarting = false
                return
            }
            errorMessage = error.localizedDescription
            await stop()
            statusText = "Unable to Connect"
        }

        isStarting = false
    }

    func stop() async {
        guard let session else { return }

        eventTask?.cancel()
        eventTask = nil
        await session.stop()
        self.session = nil
        isConnected = false
        isStarting = false
        statusText = "Disconnected"
    }

    func sendMessage() async {
        guard canSendMessage, let session else { return }

        let text = messageText
        messageText = ""
        isSendingMessage = true
        defer { isSendingMessage = false }

        do {
            let message = try await session.chat.sendChatMessage(text)
            upsert(message)
        } catch {
            messageText = text
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func handle(_ event: HotMicStreamSession.Event) {
        switch event {
        case .stateChanged(let state):
            handle(state)
        case .connectionChanged(let state):
            handle(state)
        case .streamUpdated(let stream):
            self.stream = stream
            title = stream.title ?? title
        case .streamEnded:
            isConnected = false
            statusText = "Stream Ended"
        case .streamDeleted:
            isConnected = false
            statusText = "Stream Unavailable"
        case .chatBatchReceived(let batch):
            batch.messages.forEach(upsert)
        case .chatMessageDeleted(let id):
            chatMessages.removeAll { $0.id == id }
        case .chatMessageReactionDeleted,
             .pollCreated,
             .pollUpdated,
             .pollDeleted,
             .participantsUpdated:
            break
        @unknown default:
            break
        }
    }

    private func handle(_ state: HotMicStreamSession.State) {
        switch state {
        case .idle:
            statusText = "Not Connected"
        case .starting:
            statusText = "Connecting…"
        case .active:
            statusText = "Connected"
        case .stopping:
            statusText = "Disconnecting…"
        case .stopped:
            isConnected = false
            statusText = "Disconnected"
        case .failed(let error):
            isConnected = false
            statusText = "Connection Failed"
            errorMessage = error.localizedDescription
        @unknown default:
            break
        }
    }

    private func handle(_ state: HotMicStreamSession.ConnectionState) {
        switch state {
        case .connected:
            isConnected = true
            statusText = "Connected"
        case .reconnecting(let attempt):
            isConnected = false
            statusText = "Reconnecting (attempt \(attempt))…"
        case .disconnected:
            isConnected = false
            statusText = "Disconnected"
        @unknown default:
            break
        }
    }

    private func upsert(_ message: HotMicChatMessage) {
        if let index = chatMessages.firstIndex(where: { $0.id == message.id }) {
            chatMessages[index] = message
        } else {
            chatMessages.append(message)
        }
    }
}
