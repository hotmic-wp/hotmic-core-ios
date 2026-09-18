# Migrating from HotMicMediaPlayer

HotMicCore makes the HotMic service available to your app without a prebuilt user interface. Migration requires replacing the networking and session APIs, and implementing a player and interface appropriate for your app.

## Requirements and Installation

HotMicCore requires iOS 16 or newer. It is distributed through Swift Package Manager instead of CocoaPods.

Remove `HotMicMediaPlayer` from your Podfile, add `https://github.com/hotmic-wp/hotmic-core-ios` as a package dependency, and replace:

```swift
import HotMicMediaPlayer
```

with:

```swift
import HotMicCore
```

## Initialization

Replace the `HMMediaPlayer` configuration

```swift
HMMediaPlayer.initialize(apiKey: apiKey, accessToken: accessToken)
```

with an explicit client instance:

```swift
let hotMic = HotMicClient(apiKey: apiKey, accessToken: accessToken)
```

Retain the client for as long as its credentials remain valid. Create a new client when the access token changes.

## Stream Discovery

Replace `HMMediaPlayer.getStreams(...)` with:

```swift
let page = try await hotMic.fetchStreams(
    matching: HotMicStreamQuery(
        includesLive: true,
        includesScheduled: true,
        includesVOD: true,
        userID: nil,
        page: 1,
        limit: 20
    )
)
let streams = page.streams
```

Use `page.pagination.hasNext` and increment `HotMicStreamQuery.page` to request additional pages.

Replace `HMMediaPlayer.getStream(id:completion:)` with:

```swift
let stream = try await hotMic.fetchStream(id: streamID)
```

Completion-handler functions are available as an alternative to Swift concurrency throughout the SDK.

## Replace the Player View Controller with a Stream Session

Replace `HotMicMediaPlayer.initializePlayerViewController(streamID:delegate:supportsMinimizingToPiP:prefersVideoControlsHidden:)` with:

```swift
let session = hotMic.makeStreamSession(streamID: streamID)
```

Present your own interface that utilizes the session to get data and perform operations.

Starting a session creates the backend session and loads the initial stream, authenticated user, chats, polls, and participants. It then polls for changes until stopped.

Call `await session.stop()` when the stream experience closes.

## Replace Delegate Updates with Events

Replace delegates like `HMPlayerViewControllerDelegate` and `HMChatHandlerDelegate` with session events. Consume `HotMicStreamSession.events` or assign an `HotMicStreamSession.eventHandler`.

Handle each event by updating the corresponding app state:

| HotMicCore event | State to update |
| --- | --- |
| `stateChanged` | Reflect session lifecycle changes if desired. |
| `connectionChanged` | Show connected or reconnecting state if desired. |
| `streamUpdated` | Replace displayed stream data and handle changes. |
| `streamEnded` | Transition to your end-of-stream experience. |
| `streamDeleted` | Close the stream experience. |
| `chatBatchReceived` | Add the messages and reactions into local chat state. |
| `chatMessageDeleted` | Remove the matching local message. |
| `chatMessageReactionDeleted` | Remove the matching local reaction. |
| `pollCreated`, `pollUpdated`, `pollDeleted` | Update local poll state. |
| `participantsUpdated` | Refresh the participants. |

## Media Playback

Replace the player view controller-provided player with a player owned by your app.

Select a playback URL from `HotMicStream` based on its state as follows:

- Live: `hlsURL`
- Video on demand: `vodURL`
- Scheduled or ended: no active playback, display a thumbnail

## Chat

Replace calls made through `HMChatHandlerDelegate` with `session.chat`:

| HotMicMediaPlayer action | HotMicCore replacement |
| --- | --- |
| Send chat text | `sendChatMessage(_:)` |
| Report a chat message | `reportChatMessage(chatID:)` |
| Delete a chat message | `deleteChatMessage(chatID:)` |
| Add a chat reaction | `addChatMessageReaction(_:to:)` |
| Remove a chat reaction | `removeChatMessageReaction(_:from:)` |
| Fetch users who reacted | `fetchChatMessageReactions(forChatID:)` |

## Polls

Use the polls in the initial session snapshot and update them using session events. Replace the answer action with:

```swift
try await session.polls.submitResponse(pollID: poll.id, optionID: option.id)
```

## Participants and Users

Use the participants in the initial snapshot and update them using the session event.

To get a user's information, call:

```swift
let user = try await hotMic.fetchUser(id: userID)
```

## User Blocking and Moderation

Personal block-list and elevated moderation actions are available from the stream session:

```swift
try await session.blockUser(userID: userID)
try await session.unblockUser(userID: userID)
try await session.makeUserModerator(userID: userID)
try await session.blockUserFromStreamChat(userID: userID)
```

## Type Mapping

| HotMicMediaPlayer concept | HotMicCore type |
| --- | --- |
| Stream list result | `HotMicStreamPage` |
| Lightweight stream returned by stream lookup/list APIs | `HotMicStreamSummary` |
| Full stream used by an active player experience | `HotMicStream` |
| Stream/player lifecycle | `HotMicStreamSession` |
| Initial player data | `HotMicStreamSession.Snapshot` |
| Chat | `HotMicChatMessage` |
| Chat reaction | `HotMicChatMessage.Reaction` |
| Poll | `HotMicPoll` |
| Participant | `HotMicParticipant` |
| Participant groups (host, cohosts, guests, waiting, room) | `HotMicParticipant.Snapshot` |
| Chat batch delivered by `chatBatchReceived` | `HotMicChatMessage.Batch` |
| User details | `HotMicUser` |
| SDK/network error | `HotMicError` |
