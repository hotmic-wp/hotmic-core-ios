# HotMicCore

HotMicCore lets you integrate the HotMic stream experience with a fully custom user interface—or as a **data-only** layer behind a host-owned player and screens (for example Bleacher Report–class apps). Use this framework to fetch streams, create a stream session, and drive chat, polls, and moderation from your own UI.

Migrating from HotMicMediaPlayer? Start with [MIGRATION.md](MIGRATION.md) (integration paths, session recipe, playback URLs, auth refresh, and a BR verification checklist).

## Features

- Fetch live, scheduled, and video-on-demand replay streams
- Retrieve stream and user information
- Observe stream updates
- Build a chat interface using the HotMic service
- Perform moderation and user-blocking actions
- Observe and answer polls
- Observe participant groups

## Requirements

- Swift app targeting iOS 16+

## Example

The Example app demonstrates loading streams, starting a stream session, monitoring session state, playing video, and sending chat messages. Download or clone this repository, open the Xcode project, and run the app. You can add your API key and access token in the Settings screen.

## Installation

In Xcode, select File > Add Package Dependencies, enter the package URL `https://github.com/hotmic-wp/hotmic-core-ios`, select Up to Next Major, and add HotMicCore to your app target.

During early rollout the public `1.0.0` binary asset may be unavailable; see the [distribution caveat in MIGRATION.md](MIGRATION.md#distribution-caveat-pilot).

## Usage

### Create a Client

Initialize a HotMicClient with your API key and access token:

```swift
import HotMicCore

let hotMic = HotMicClient(
    apiKey: apiKey, 
    accessToken: accessToken
)
```

Create the access token on your backend for the authenticated user by signing an HS256 JWT with your API secret using a payload in this format:

```json
{
  "identity": {
    "user_id": "stable-user-id",
    "display_name": "Username",
    "profile_pic": "https://example.com/profile.jpg",
    "badge": "https://example.com/badge.png"
  },
  "iat": 1787072400,
  "exp": 1787158800
}
```

`profile_pic` and `badge` are optional. Create a new `HotMicClient` when the access token changes (for example after an `unauthorized` error). There is no MediaPlayer-style auth observer.

Logging is disabled by default. To enable diagnostics, specify `logLevel` in the initializer.

### Get Streams

Fetch live, scheduled, and video-on-demand streams, optionally limiting results to streams created by a specific user:

```swift
let query = HotMicStreamQuery(
    includesLive: true,
    includesScheduled: true,
    includesVOD: true,
    userID: nil,
    page: 1,
    limit: 20
)

let page = try await hotMic.fetchStreams(matching: query)
let streams = page.streams
```

Fetch the next page when needed:

```swift
if page.pagination.hasNext {
    var nextQuery = query
    nextQuery.page = page.pagination.currentPage + 1
    let nextPage = try await hotMic.fetchStreams(matching: nextQuery)
}
```

Fetch one stream by ID:

```swift
let summary = try await hotMic.fetchStream(id: streamID) // HotMicStreamSummary
```

These requests return `HotMicStreamSummary`. Full `HotMicStream` details (including `hlsURL` / `vodURL`) come from the session `Snapshot` after `start()` and from `streamUpdated` events—not from discovery APIs.

### Stream Session

Create and configure a stream session to manage the backend session, polling, presence, and interactive services for a stream:

```swift
@MainActor
final class StreamController {
    private let hotMic: HotMicClient
    private var session: HotMicStreamSession?
    private var eventTask: Task<Void, Never>?

    init(hotMic: HotMicClient) {
        self.hotMic = hotMic
    }

    func open(streamID: String) async throws -> HotMicStreamSession.Snapshot {
        let session = hotMic.makeStreamSession(streamID: streamID)
        self.session = session

        eventTask = Task {
            for await event in session.events {
                // Update your app's state for the event.
            }
        }

        do {
            return try await session.start()
        } catch {
            await close()
            throw error
        }
    }

    func close() async {
        await session?.stop()
        eventTask?.cancel()
        eventTask = nil
        session = nil
    }
}
```

Keep a strong reference to the session and begin consuming `events`, or assign `eventHandler`, **before** starting it. Session APIs are `@MainActor`. A stopped or failed session is one-shot—create a new session rather than calling `start()` again.

`start()` returns the initial stream, authenticated user, chat messages, polls, and participants. Session events report subsequent changes.

You can monitor `.stateChanged` events for transitions between `session.state` and `.connectionChanged` to determine whether polling is connected, reconnecting, or disconnected.

Events also report changes to session content:

- `.streamUpdated`, `.streamEnded`, and `.streamDeleted` report changes to the stream.
- `.chatBatchReceived`, `.chatMessageDeleted`, and `.chatMessageReactionDeleted` report chat and reaction changes.
- `.pollCreated`, `.pollUpdated`, and `.pollDeleted` report poll changes.
- `.participantsUpdated` reports changes to participant groups.

Call `stop()` and release the session when the experience closes.

For host-owned playback, select `stream.hlsURL` (live) or `stream.vodURL` (VOD) from the snapshot / `streamUpdated` event and feed your own player. HotMicCore does not require a specific player SDK.

### Chat

Chat messages are included in the initial session snapshot and updated through chat events. All chat calls use the `session.chat` prefix.

Send a message after the session has started:

```swift
let message = try await session.chat.sendChatMessage("Hello!")
```

Insert the chat message immediately (optimistic local update)—your own send/react/delete results are not echoed through session events.

Delete a chat message:

```swift
try await session.chat.deleteChatMessage(chatID: message.id)
```

Remove the message immediately (optimistic local update).

Report a chat message as inappropriate:

```swift
try await session.chat.reportChatMessage(chatID: message.id)
```

### Reactions

Add or remove a reaction to a chat message:

```swift
let reaction = try await session.chat.addChatMessageReaction(.like, to: message.id)

try await session.chat.removeChatMessageReaction(.like, from: message.id)
```

Apply the change immediately (optimistic local update).

Fetch reaction details:

```swift
let reactionDetails = try await session.chat.fetchChatMessageReactions(forChatID: message.id)
```

### Polls

Polls are included in the initial session snapshot and updated through poll events.

Submit an answer to a poll:

```swift
try await session.polls.submitResponse(pollID: poll.id, optionID: option.id)
```

### Participants and Users

The initial participant snapshot and subsequent events provide information about users in the stream.

Fetch information for a user by ID:

```swift
let user = try await hotMic.fetchUser(id: userID)
```

### User Blocking

Add or remove a user from the authenticated user's block list:

```swift
try await session.blockUser(userID: userID)
try await session.unblockUser(userID: userID)
```

When a user is blocked, their new chat messages are excluded from subsequent session events.

### Moderation

Authorized users can perform elevated moderation operations:

```swift
try await session.makeUserModerator(userID: userID)
try await session.blockUserFromStreamChat(userID: userID)
```

### Completion Handlers

Each asynchronous function also has a completion-handler alternative:

```swift
hotMic.fetchStreams { result in
    switch result {
    case .success(let page):
        // Display page.streams.
    case .failure(let error):
        // Handle HotMicError.
    }
}
```

To handle events in a stream session without using Swift concurrency, assign `eventHandler` before starting the session:

```swift
let session = hotMic.makeStreamSession(streamID: streamID)

session.eventHandler = { [weak self] event in
    // Update your app's state for the event.
}

session.start { result in
    switch result {
    case .success(let snapshot):
        // Display the initial session state.
    case .failure(let error):
        // Handle HotMicError.
    }
}
```
