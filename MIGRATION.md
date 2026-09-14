# Migrating from HotMicMediaPlayer

HotMicCore exposes the HotMic service without a prebuilt player UI. This guide is written for **data-only** integrators (for example Bleacher Report) who keep their own player and screens, and only replace networking, session lifecycle, chat, polls, and moderation.

For a full product tour of the API, see [README.md](README.md).

## Integration paths

| Path | Who it is for | What you replace |
| --- | --- | --- |
| **Data-only (recommended for BR-class apps)** | Host owns video player, layout, theming, and navigation | Networking (`HotMicClient`), stream discovery, `HotMicStreamSession`, chat/polls/moderation APIs, and playback **URL selection** (`hlsURL` / `vodURL`) |
| **Full UI rewrite** | Apps that previously presented HotMic’s player view controller as the entire experience | Everything above **plus** building a complete stream UI (chat list, polls, participants, end states) from session snapshot + events |

Bleacher Report–style apps should follow the **data-only** path: keep your player and chrome; wire HotMicCore as the data and interaction layer.

## Requirements and installation

HotMicCore requires iOS 16 or newer. It is distributed through Swift Package Manager instead of CocoaPods.

Remove `HotMicMediaPlayer` from your Podfile, add `https://github.com/hotmic-wp/hotmic-core-ios` as a package dependency, and replace:

```swift
import HotMicMediaPlayer
```

with:

```swift
import HotMicCore
```

### Distribution caveat (pilot)

`Package.swift` points at the public GitHub Release asset for `1.0.0`. That binary may be **unpublished or return 404** during early rollout. For a pilot integration:

- Prefer a **local xcframework** or a **private package** feed until the public release asset is confirmed available.
- Do not change the published checksum/URL in this repo unless you are intentionally republishing the binary.
- Tracker: [mchusma/hotmic-engineering-manager#73](https://github.com/mchusma/hotmic-engineering-manager/issues/73).

## Initialization and auth

Replace the `HMMediaPlayer` configuration

```swift
HMMediaPlayer.initialize(apiKey: apiKey, accessToken: accessToken)
```

with an explicit client instance:

```swift
let hotMic = HotMicClient(apiKey: apiKey, accessToken: accessToken)
```

Retain the client for as long as its credentials remain valid.

**Auth refresh differs from MediaPlayer:**

- There is **no** MediaPlayer-style auth observer on HotMicCore.
- On `unauthorized` (or equivalent auth failure), mint a **new JWT** on your backend and create a **new `HotMicClient`** with the new access token.
- Tear down any active `HotMicStreamSession` before swapping clients; sessions are bound to the client that created them.

## Stream discovery

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
let streams = page.streams // [HotMicStreamSummary]
```

### Pagination (new vs MediaPlayer)

HotMicCore returns a paged result (`HotMicStreamPage`). Use `page.pagination.hasNext` and increment `HotMicStreamQuery.page` to request additional pages. MediaPlayer’s list APIs did not expose this page/limit model the same way—plan UI for paging (or load-more) rather than assuming a single unbounded list.

### Stream lookup returns a summary

Replace `HMMediaPlayer.getStream(id:completion:)` with:

```swift
let summary = try await hotMic.fetchStream(id: streamID) // HotMicStreamSummary
```

**Important:** `fetchStream` and `fetchStreams` return **`HotMicStreamSummary`**, not full `HotMicStream`. Full stream details (including playback URLs) come from:

- `HotMicStreamSession.Snapshot.stream` after `start()`, and
- subsequent `streamUpdated` session events.

Completion-handler overloads are available throughout the SDK as an alternative to Swift concurrency.

## Stream session recipe

Replace `HotMicMediaPlayer.initializePlayerViewController(...)` with a host-owned session controller. Follow this order every time:

1. `makeStreamSession(streamID:)`
2. **Subscribe to events** (`session.events` or `eventHandler`) **before** `start()`
3. `start()` → receive `HotMicStreamSession.Snapshot`
4. Drive UI and player from snapshot + events
5. `stop()` when the experience closes

Sessions are **`@MainActor`**. Treat them as **one-shot**: after `stop()` or a failed `start()`, create a **new** session; do not call `start()` again on the same instance.

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

        // Subscribe BEFORE start so you do not miss early events.
        eventTask = Task {
            for await event in session.events {
                // Update app state for the event.
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

`start()` creates the backend session and loads the initial stream, authenticated user, chats, polls, and participants, then polls for changes until stopped.

## Replace delegate updates with events

Replace delegates like `HMPlayerViewControllerDelegate` and `HMChatHandlerDelegate` with session events. Consume `HotMicStreamSession.events` or assign `HotMicStreamSession.eventHandler`.

| HotMicCore event | State to update |
| --- | --- |
| `stateChanged` | Reflect session lifecycle changes if desired. |
| `connectionChanged` | Show connected or reconnecting state if desired. |
| `streamUpdated` | Replace displayed **`HotMicStream`** (including playback URLs) and handle changes. |
| `streamEnded` | Transition to your end-of-stream experience. |
| `streamDeleted` | Close the stream experience. |
| `chatBatchReceived` | Add the messages and reactions into local chat state. |
| `chatMessageDeleted` | Remove the matching local message. |
| `chatMessageReactionDeleted` | Remove the matching local reaction. |
| `pollCreated`, `pollUpdated`, `pollDeleted` | Update local poll state. |
| `participantsUpdated` | Refresh the participants. |

## Playback URLs (host-owned player)

HotMicCore does **not** require replacing your player with Bitmovin or any HotMic-bundled player. Keep your existing player; select a URL from full `HotMicStream` (snapshot / `streamUpdated`):

| Stream state | URL field | Host action |
| --- | --- | --- |
| Live | `hlsURL` | Play live HLS |
| Video on demand | `vodURL` | Play VOD / replay |
| Scheduled or ended | — | No active playback; show thumbnail / countdown / ended UI |

Update the player when `streamUpdated` changes URLs or state.

## Chat

Call chat APIs on **`session.chat`** (not on the client or a MediaPlayer chat handler):

| HotMicMediaPlayer action | HotMicCore replacement |
| --- | --- |
| Send chat text | `session.chat.sendChatMessage(_:)` |
| Report a chat message | `session.chat.reportChatMessage(chatID:)` |
| Delete a chat message | `session.chat.deleteChatMessage(chatID:)` |
| Add a chat reaction | `session.chat.addChatMessageReaction(_:to:)` |
| Remove a chat reaction | `session.chat.removeChatMessageReaction(_:from:)` |
| Fetch users who reacted | `session.chat.fetchChatMessageReactions(forChatID:)` |

### Optimistic local updates

Your own send / react / delete results are **not** echoed back through session events for the sender. Apply them **locally** as soon as the API succeeds:

- After `sendChatMessage`, insert the returned `HotMicChatMessage`.
- After add/remove reaction, update local reaction state from the return value (or remove locally).
- After `deleteChatMessage`, remove the message from local state immediately.

Remote users’ activity still arrives via `chatBatchReceived`, `chatMessageDeleted`, and `chatMessageReactionDeleted`.

## Polls

Use polls from the initial session snapshot and keep them current with poll events. Replace the answer action with:

```swift
try await session.polls.submitResponse(pollID: poll.id, optionID: option.id)
```

## Participants and users

Use participants from the initial snapshot and update them from `participantsUpdated`.

To get a user's information:

```swift
let user = try await hotMic.fetchUser(id: userID)
```

## User blocking and moderation

Personal block-list and elevated moderation actions are available from the stream session:

```swift
try await session.blockUser(userID: userID)
try await session.unblockUser(userID: userID)
try await session.makeUserModerator(userID: userID)
try await session.blockUserFromStreamChat(userID: userID)
```

Blocked users’ new chat messages are excluded from subsequent session events.

## Type mapping

| HotMicMediaPlayer concept | HotMicCore type |
| --- | --- |
| Stream list result | `HotMicStreamPage` (includes `pagination`) |
| Lightweight stream from list/lookup (`fetchStreams` / `fetchStream`) | `HotMicStreamSummary` |
| Full stream (playback URLs, live details) | `HotMicStream` (from `Snapshot` / `streamUpdated`) |
| Stream/player lifecycle | `HotMicStreamSession` |
| Initial player data | `HotMicStreamSession.Snapshot` |
| Chat | `HotMicChatMessage` |
| Chat reaction | `HotMicChatMessage.Reaction` |
| Chat API surface | `session.chat` |
| Poll | `HotMicPoll` |
| Poll API surface | `session.polls` |
| Participant | `HotMicParticipant` |
| User details | `HotMicUser` |
| SDK/network error | `HotMicError` |

## Verification checklist (BR scenarios)

Use this against a Bleacher Report–class data-only integration:

- [ ] **Streams** — List live/scheduled/VOD via `fetchStreams`; exercise pagination (`hasNext` / next `page`); open a stream from `HotMicStreamSummary` without expecting full `HotMicStream` yet.
- [ ] **Session** — `makeStreamSession` → subscribe events → `start()` → apply `Snapshot` → `stop()`; confirm `@MainActor` usage; confirm a stopped session cannot be restarted (create a new one).
- [ ] **Chat** — Send, react, delete via `session.chat.*`; apply optimistic local updates for own actions; confirm remote messages arrive on events.
- [ ] **Polls** — Render snapshot polls; handle create/update/delete events; submit a response via `session.polls.submitResponse`.
- [ ] **Block / moderation** — Block and unblock a user; confirm blocked users’ new messages stop appearing; exercise moderator actions if the test identity allows them.
- [ ] **Auth** — Force token expiry / unauthorized; mint a new JWT; create a new `HotMicClient` (no MediaPlayer auth observer).
- [ ] **Playback** — Bind host player to `hlsURL` / `vodURL` from snapshot/`streamUpdated` without adopting a HotMic UI player.

## Appendix: out of scope for data-only migration

These MediaPlayer or product surfaces are **not** part of a data-only HotMicCore migration. Do not block BR pilot work on them:

| Topic | Notes |
| --- | --- |
| Tips / tipping | Not exposed as a HotMicCore data API in this package. |
| OpenTok / publisher video | Host or other SDKs own publisher/subscriber video; HotMicCore is not a drop-in OpenTok replacement. |
| Theming / HotMic chrome | No bundled theme; you own all UI styling. |
| Picture-in-Picture | Host implements PiP with your player; there is no `supportsMinimizingToPiP` flag on Core. |
| Ads | Ad insertion remains host-owned. |
| Analytics observer | No MediaPlayer-style analytics observer bridge; instrument in your app if needed. |
| `canParticipate` | MediaPlayer participation gating is not a Core session API; decide participation in host product logic. |
