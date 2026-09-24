import Foundation
import Observation
import HotMicCore

@MainActor
@Observable
final class StreamSessionModel {
    struct TraceEntry: Identifiable {
        let id = UUID()
        let time = Date()
        let text: String
    }

    private let client: HotMicClient
    private let streamID: String
    private var session: HotMicStreamSession?
    private var eventTask: Task<Void, Never>?
    private var messageNumbers: [String: Int] = [:]
    private var likeOverrides: [String: Bool] = [:]
    private var likeCountAdjustments: [String: Int] = [:]
    private var pendingLikeIDs: Set<String> = []
    private var pendingPollIDs: Set<String> = []
    private var answeredPollIDs: Set<String> = []
    private var userID: String?
    private var streamOwnerID: String?

    private(set) var stream: HotMicStream?
    private(set) var chatMessages: [HotMicChatMessage] = []
    private(set) var polls: [HotMicPoll] = []
    private(set) var participants: HotMicParticipant.Snapshot?
    private(set) var eventTrace: [TraceEntry] = []
    private(set) var eventCounts: [String: Int] = [:]
    private(set) var isStarting = false
    private(set) var isConnected = false
    private(set) var isSendingMessage = false
    private(set) var playbackEnded = false
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

    func canDelete(_ message: HotMicChatMessage) -> Bool {
        guard let userID else { return false }
        return message.userID == userID || streamOwnerID == userID
    }

    func isLiked(_ message: HotMicChatMessage) -> Bool {
        likeOverrides[message.id] ?? message.userReactions.contains(.like)
    }

    func isLikePending(_ message: HotMicChatMessage) -> Bool { pendingLikeIDs.contains(message.id) }

    func canAnswer(_ poll: HotMicPoll) -> Bool {
        session?.state == .active && stream?.state == .live && !poll.closed && poll.myAnswer == nil &&
            !pendingPollIDs.contains(poll.id) && !answeredPollIDs.contains(poll.id)
    }

    func likeCount(_ message: HotMicChatMessage) -> Int {
        let ownDelta: Int
        if let override = likeOverrides[message.id] {
            ownDelta = (override ? 1 : 0) - (message.userReactions.contains(.like) ? 1 : 0)
        } else {
            ownDelta = 0
        }
        return max(0, message.likeCount + ownDelta + (likeCountAdjustments[message.id] ?? 0))
    }

    func start() async {
        guard session == nil else { return }

        let session = client.makeStreamSession(streamID: streamID)
        self.session = session
        isStarting = true
        statusText = "Connecting…"
        record("session", "start requested")

        do {
            let snapshot = try await session.start()
            guard self.session === session else { return }
            userID = snapshot.user.id
            streamOwnerID = snapshot.stream.user.id
            stream = snapshot.stream
            playbackEnded = snapshot.stream.state == .ended
            title = snapshot.stream.title ?? title
            chatMessages = snapshot.chatMessages
            likeOverrides.removeAll()
            likeCountAdjustments.removeAll()
            pendingLikeIDs.removeAll()
            polls = snapshot.polls
            pendingPollIDs.removeAll()
            answeredPollIDs.removeAll()
            participants = snapshot.participants
            for message in snapshot.chatMessages { _ = messageNumber(message.id) }
            isConnected = !playbackEnded
            statusText = playbackEnded ? "Stream Ended" :
                snapshot.stream.state == .vod ? "Replay Available" : "Connected"
            record(
                "snapshot",
                "\(snapshot.chatMessages.count) chats, \(snapshot.polls.count) polls, " +
                    "\(snapshot.participants.room.count) in room"
            )
            eventTask = Task { [weak self] in
                for await event in session.events {
                    guard let self, self.session === session, !Task.isCancelled else { break }
                    self.handle(event)
                }
            }
        } catch {
            guard self.session === session else { return }
            errorMessage = error.localizedDescription
            record("error", "session start failed")
            await stop()
            if self.session == nil { statusText = "Unable to Connect" }
        }

        if self.session === session { isStarting = false }
    }

    func stop() async {
        guard let session else { return }
        self.session = nil
        eventTask?.cancel()
        eventTask = nil
        pendingLikeIDs.removeAll()
        pendingPollIDs.removeAll()
        isConnected = false
        isStarting = false
        statusText = "Disconnected"
        record("session", "stopped")
        await session.stop()
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
            record("action", "sent chat #\(messageNumber(message.id))")
        } catch {
            messageText = text
            showError(error, action: "send chat")
        }
    }

    func toggleLike(_ message: HotMicChatMessage) async {
        guard let session, session.state == .active,
              !pendingLikeIDs.contains(message.id) else { return }
        let liked = isLiked(message)
        let previousOverride = likeOverrides[message.id]
        pendingLikeIDs.insert(message.id)
        likeOverrides[message.id] = !liked
        defer { if self.session === session { pendingLikeIDs.remove(message.id) } }
        do {
            if liked {
                _ = try await session.chat.removeChatMessageReaction(.like, from: message.id)
            } else {
                _ = try await session.chat.addChatMessageReaction(.like, to: message.id)
            }
            guard self.session === session else { return }
            record("action", "\(liked ? "removed" : "added") like on chat #\(messageNumber(message.id))")
        } catch {
            guard self.session === session else { return }
            likeOverrides[message.id] = previousOverride
            showError(error, action: "change reaction")
        }
    }

    func delete(_ message: HotMicChatMessage) async {
        guard let session, canDelete(message) else { return }
        do {
            try await session.chat.deleteChatMessage(chatID: message.id)
            chatMessages.removeAll { $0.id == message.id }
            record("action", "deleted chat #\(messageNumber(message.id))")
        } catch {
            showError(error, action: "delete chat")
        }
    }

    func report(_ message: HotMicChatMessage) async {
        guard let session else { return }
        do {
            try await session.chat.reportChatMessage(chatID: message.id)
            record("action", "reported chat #\(messageNumber(message.id))")
        } catch {
            showError(error, action: "report chat")
        }
    }

    func block(_ message: HotMicChatMessage) async {
        guard let session else { return }
        do {
            try await session.blockUser(userID: message.userID)
            record("action", "blocked author of chat #\(messageNumber(message.id))")
        } catch {
            showError(error, action: "block user")
        }
    }

    func unblock(_ message: HotMicChatMessage) async {
        guard let session else { return }
        do {
            try await session.unblockUser(userID: message.userID)
            record("action", "unblocked author of chat #\(messageNumber(message.id))")
        } catch {
            showError(error, action: "unblock user")
        }
    }

    func answer(_ poll: HotMicPoll, option: HotMicPoll.Option) async {
        guard let session, canAnswer(poll) else { return }
        pendingPollIDs.insert(poll.id)
        defer { if self.session === session { pendingPollIDs.remove(poll.id) } }
        do {
            try await session.polls.submitResponse(pollID: poll.id, optionID: option.id)
            guard self.session === session else { return }
            answeredPollIDs.insert(poll.id)
            record("action", "answered poll")
        } catch {
            guard self.session === session else { return }
            showError(error, action: "answer poll")
        }
    }

    func dismissError() { errorMessage = nil }
}

private extension StreamSessionModel {
    private func handle(_ event: HotMicStreamSession.Event) {
        switch event {
        case .stateChanged(let state):
            handle(state)
        case .connectionChanged(let state):
            handle(state)
        case .streamUpdated(let stream):
            self.stream = stream
            title = stream.title ?? title
            if stream.state == .vod {
                playbackEnded = false
                statusText = "Replay Available"
            } else if stream.state == .ended {
                playbackEnded = true
                isConnected = false
                statusText = "Stream Ended"
            }
            record("stream", "updated: \(stream.state.rawValue)")
        case .streamEnded:
            if stream?.state == .vod {
                playbackEnded = false
                statusText = "Replay Available"
            } else {
                playbackEnded = true
                isConnected = false
                statusText = "Stream Ended"
            }
            record("stream", "ended")
        case .streamDeleted:
            playbackEnded = true
            isConnected = false
            statusText = "Stream Unavailable"
            record("stream", "deleted")
        default:
            handleContent(event)
        }
    }

    private func handleContent(_ event: HotMicStreamSession.Event) {
        switch event {
        case .chatBatchReceived(let batch):
            handle(batch)
        case .chatMessageDeleted(let id):
            chatMessages.removeAll { $0.id == id }
            record("chat delete", "chat #\(messageNumber(id))")
        case .chatMessageReactionDeleted(let chatID, let reactionUserID, let type):
            if type == .like, let userID, reactionUserID != userID {
                likeCountAdjustments[chatID, default: 0] -= 1
            }
            record(
                "reaction remove",
                "chat #\(messageNumber(chatID)), \(type.rawValue)"
            )
        case .pollCreated(let poll):
            upsert(poll)
            record("poll", "created")
        case .pollUpdated(let poll):
            upsert(poll)
            record("poll", "updated")
        case .pollDeleted(let id):
            polls.removeAll { $0.id == id }
            record("poll", "deleted")
        case .participantsUpdated(let snapshot):
            participants = snapshot
            record("participants", "\(snapshot.room.count) in room")
        default:
            record("unknown", "session event")
        }
    }

    private func handle(_ batch: HotMicChatMessage.Batch) {
        let updatedIDs = Set(batch.messages.map(\.id))
        for message in batch.messages {
            let previous = chatMessages.first { $0.id == message.id }
            upsert(message)
            likeCountAdjustments[message.id] = 0
            if let previous {
                let category = previous == message ? "chat unchanged" : "chat changed"
                record(category, "chat #\(messageNumber(message.id))")
            } else {
                record("chat new", "chat #\(messageNumber(message.id))")
            }
        }
        for reaction in batch.reactions {
            if !updatedIDs.contains(reaction.chatID), reaction.type == .like,
               let userID, reaction.userID != userID {
                likeCountAdjustments[reaction.chatID, default: 0] += 1
            }
            record("reaction add", "chat #\(messageNumber(reaction.chatID)), \(reaction.type.rawValue)")
        }
    }

    private func handle(_ state: HotMicStreamSession.State) {
        switch state {
        case .idle: statusText = "Not Connected"
        case .starting: statusText = "Connecting…"
        case .active: statusText = "Connected"
        case .stopping: statusText = "Disconnecting…"
        case .stopped:
            isConnected = false
            statusText = "Disconnected"
        case .failed(let error):
            isConnected = false
            statusText = "Connection Failed"
            errorMessage = error.localizedDescription
        @unknown default: break
        }
        record("state", statusText)
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
        @unknown default: break
        }
        record("connection", statusText)
    }

    private func upsert(_ message: HotMicChatMessage) {
        if let index = chatMessages.firstIndex(where: { $0.id == message.id }) {
            chatMessages[index] = message
        } else {
            chatMessages.append(message)
        }
    }

    private func upsert(_ poll: HotMicPoll) {
        if let index = polls.firstIndex(where: { $0.id == poll.id }) {
            polls[index] = poll
        } else {
            polls.append(poll)
        }
    }

    private func messageNumber(_ id: String) -> Int {
        if let number = messageNumbers[id] { return number }
        let number = messageNumbers.count + 1
        messageNumbers[id] = number
        return number
    }

    private func record(_ category: String, _ text: String) {
        eventCounts[category, default: 0] += 1
        eventTrace.insert(TraceEntry(text: "\(category): \(text)"), at: 0)
        if eventTrace.count > 200 { eventTrace.removeLast() }
    }

    private func showError(_ error: Error, action: String) {
        errorMessage = error.localizedDescription
        record("error", "\(action) failed")
    }
}
