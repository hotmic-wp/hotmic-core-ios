# HotMicCore

HotMicCore allows you to integrate the HotMic stream experience into your app with a fully custom user interface. Use this framework to get streams, create a stream session, and build your live stream experience.

See [MIGRATION.md](MIGRATION.md) to migrate to HotMicCore from HotMicMediaPlayer.

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

The Example app itself requires Xcode 26 and an iOS 26 simulator or device; the framework supports iOS 16 and later.

## Installation

In Xcode, select File > Add Package Dependencies, enter the package URL `https://github.com/hotmic-wp/hotmic-core-ios`, select Up to Next Major, and add HotMicCore to your app target.

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

`profile_pic` and `badge` are optional. Create a new `HotMicClient` when the access token changes.

The client always talks to the production HotMic service at `https://api.hotmic.io`; use a separate API key for staging tenants.

Logging is disabled by default. To enable diagnostics, specify `logLevel` in the initializer. Log lines are written to the unified log (OSLog) under the subsystem `io.hotmic.HotMicCore` and describe request starts and results only; credentials, headers, and bodies are never logged.

If the access token is missing, expired, malformed, or signed with the wrong secret, `fetchStreams` and chat operations fail with `HotMicError.unauthorized`, but a stream session still starts as an anonymous guest whose `HotMicUser.userRestrictions` is `.viewAndPollsOnly`. Check `Snapshot.user` after `start()` if your app must distinguish an authenticated viewer from a guest.

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
let stream = try await hotMic.fetchStream(id: streamID)
```

These requests return `HotMicStreamSummary`. Summaries returned by `fetchStreams(matching:)` do not include playback URLs; `fetchStream(id:)` includes `hlsURL` and `vodURL`, and the full `HotMicStream` (which adds `endThumbnail`, `videoOrientation`, and `shareText`) is provided when a stream session is started.

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

Keep a strong reference to the session and begin consuming `events`, or assign `eventHandler`, before starting it.

`start()` returns the initial stream, authenticated user, chat messages, polls, and participants. Session events report subsequent changes; chat and poll changes are polled about every 3 seconds and participant changes about every 2 minutes. While your app is in the background polling pauses, and on return the session fetches everything that happened in between.

`events` is a single-consumer `AsyncStream`; use either `events` or `eventHandler`, not both.

You can monitor `.stateChanged` events for transitions between `session.state` and `.connectionChanged` to determine whether polling is connected, reconnecting, or disconnected.

Events also report changes to session content:

- `.streamUpdated`, `.streamEnded`, and `.streamDeleted` report changes to the stream.
- `.chatBatchReceived`, `.chatMessageDeleted`, and `.chatMessageReactionDeleted` report chat and reaction changes.
- `.pollCreated`, `.pollUpdated`, and `.pollDeleted` report poll changes.
- `.participantsUpdated` reports changes to participant groups.

Call `stop()` and release the session when the experience closes. A stopped or failed session cannot be started again.

### Chat

Chat messages are included in the initial session snapshot and updated through chat events.

Send a message after the session has started:

```swift
let message = try await session.chat.sendChatMessage("Hello!")
```

Insert the chat message immediately as it will not be delivered through session events. Validate the text in your app before sending; the service does not reject empty messages.

Delete a chat message:

```swift
try await session.chat.deleteChatMessage(chatID: message.id)
```

Remove the message immediately as it will not be delivered through session events.

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

Apply the change immediately as they will not be delivered through session events.

Reactions added by other users arrive in `.chatBatchReceived` as `HotMicChatMessage.Batch.reactions`; reactions they remove arrive as `.chatMessageReactionDeleted`.

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

### Errors

Every throwing call throws `HotMicError`:

- `unauthorized` — the access token was rejected.
- `forbidden(message:)` — the service refused the action for this user.
- `server(statusCode:message:)` — any other non-success response; `message` carries the service's text when there is one.
- `transport(description:)` — the request could not reach the service (offline, DNS, timeout).
- `cancelled` — the calling task was cancelled, or the session was stopped while starting.
- `invalidRequest` — the query could not be built (for example `limit` or `page` below 1).
- `decoding(description:)` — the response could not be parsed.
- `invalidSessionState` — `start()` was called on a session that is already starting, active, stopped, or failed.

### Completion Handlers

Each asynchronous function also has a completion-handler alternative:

```swift
hotMic.fetchStreams { result in
    switch result {
    case .success(let page):
        display(page.streams)
    case .failure(let error):
        handle(error)
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
        display(snapshot)
    case .failure(let error):
        handle(error)
    }
}
```
