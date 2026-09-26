# Vory — handoff and change log (2026-09-23 → 2026-09-25)

For the next agent picking this up. Everything below is committed on `master` of the private repo
`github.com/matt0975/vory` (local checkout `~/claude-sandbox/Vory`). The user is Matt (they/them);
they test on their own iPhone 17 Pro via TestFlight and send screenshots with feedback. Work one item
at a time, ship a TestFlight build, wait for their verdict.

## Where things stand

- **Latest TestFlight build: 1.0.1 (30)**, uploaded 2026-09-25 21:25. Companion plugin **1.0.25**.
  Builds 20 and 22 were superseded cuts and are expired. Build 30 is untested by the user.
- **Versioning plan (user's decision):** marketing version stays `1.0.1` through the beta, then
  `1.2`, `1.3`…; `2.0` is the real App Store release. Build numbers are small iteration numbers.
  `Tools/release/testflight.sh` picks the next one from App Store Connect automatically (override
  with `BUILD_NUMBER=<n>`).
- **What works end to end on the phone:** Live Activities (start, phases, tokens/context live, finish
  without expanding, 30 s in the Island then 60 s on the Lock Screen), the reply notification with the
  bot as sender and its avatar, replying from the notification (the answer comes back as a new
  notification), the long-press reply window, the Software Update page for the companion, the Creator
  Studio bots, the Messages-style chat header, swipe-back from anywhere.
- **Open feedback backlog** (full text with what is already closed: `docs/agent-memory/
  vory-feedback-backlog.md`). Still open, in the user's numbering: #3 pinned chats disappear; #5 chats
  open blank until scrolled; #6 Watch scroll-to-bottom spacing; extra space under the last message when
  a chat opens (unreproduced); older mic-button crash; the gateway's "session could not be re-attached"
  reconnect error; #7 profile picker layout; #8 a menu item's title padding; #10 refresh icon inside the
  search bar; #13 bot animates everywhere while working (and still when idle); #14 animate the "…"
  thinking indicator; #15 active bot's avatar in the menu item; #16 motion-style setting (ask if still
  wanted after the Creator Studio); #17 Stop button becomes a grey Send while typing (queue/steer);
  #18 in-chat iMessage-style reply UI (the notification reply window part is done); #20 notifications
  on/off toggle; #21 plain-language status screen; #22 general plugins list; #23 @mention bot picker.

## Build, install, ship

```bash
# TestFlight (archive → export with manual signing → upload). Needs Tools/release/.env (gitignored).
cd ~/claude-sandbox/Vory && ./Tools/release/testflight.sh
```

- After upload, poll App Store Connect until `processingState == VALID`, then PATCH/POST
  `betaBuildLocalizations` with What-to-Test notes (blank line between entries; the user reads them).
  A JWT for the API comes from `swift Tools/release/asc-jwt.swift` with `ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_KEY_PATH` exported. App Store Connect app id `6814980297`. Escape `[`/`]` as `%5B`/`%5D` in
  API URLs (zsh).
- **Never kill a running `testflight.sh`**: altool may already have delivered the build (that is how
  builds 20 and 22 slipped out). Check the log for "No errors uploading" first.
- **USB device build** (user's phone UDID `00008150-001069912108401C`):
  `xcodebuild -project Vory.xcodeproj -scheme Vory -configuration Debug -destination 'generic/platform=iOS'
  -derivedDataPath build/device -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  VORY_PUSH_RELAY_URL="$VORY_PUSH_RELAY_URL" build`, then `xcrun devicectl device install app --device
  <udid> build/device/Build/Products/Debug-iphoneos/Vory.app`. `VORY_PUSH_RELAY_URL` must be passed or
  the relay is "not configured". `ENABLE_DEBUG_DYLIB = NO` is set in every Debug config (Live
  Activities do not run otherwise).
- **Simulator that gets past onboarding** ("Hermes iPhone", `1C5C2D80-B7E5-4995-AF84-13C4AD9CA7DE`):
  build WITH signing (`-derivedDataPath build/simsigned`, no `CODE_SIGNING_ALLOWED=NO`), run
  `~/.hermes/hermes-agent/venv/bin/python Tools/mock-gateway/mock_gateway.py --port 9119 --token
  mock-token`, then `xcrun simctl spawn <udid> launchctl setenv HERMES_E2E_URL http://127.0.0.1:9119`
  and `HERMES_E2E_TOKEN mock-token`; uninstall, install, launch → lands on Chats with mock sessions.
  Unsigned builds stall on onboarding (Keychain).
- **Notification extension testing on the simulator:** launch the app once with
  `-vory-request-notifications` (DEBUG flag) and tap Allow, then `xcrun simctl push <udid>
  <file>.apns` (samples: scratchpad `turn.apns`, `turn2.apns` with a `hermes.thread`). Long-press the
  banner within ~2 s (simulator MCP `tap` with `duration: 1.2`). If the content extension shows a
  blank white box with no crash report, it is RunningBoard's "Client not authorized" after a
  reinstall: shut down and boot the simulator.
- **Relay** (Cloudflare Worker, `server/push-relay`): the permission classifier denies the assistant
  running `Tools/release/deploy-relay.sh`; the user runs it. Currently deployed with the `sound`
  push type and the "dead Live Activity token does not delete the registration" change.
- **Companion** (`server/hermes-push/hermes_push.py`): bump `VERSION` and `plugin.yaml` together, run
  `Tools/sync-push-companion.sh` (copies into the app bundle; a unit test checks parity). The app
  installs it from Settings › Software Update; it self-reloads on file change.

## Secrets (never commit)

`Tools/release/.env` (gitignored): App Store Connect API key id/issuer/path, APNs key path,
Cloudflare token/account, relay URL. The `.p8` files live in `~/.appstoreconnect/private_keys/`.
App Store profiles were created through the ASC API and dropped into
`~/Library/Developer/Xcode/UserData/Provisioning Profiles`; `Tools/release/ExportOptions.plist` maps
profile names to bundle ids (app, LiveActivity, notifications, notificationcontent, watch app, watch
complications). Regenerate a profile after any capability change. The ASC `bundleIds` filter is a
prefix match: map exact identifier → id from `bundleIds?limit=200` (ids: app `U4NQCTQ9BB`,
LiveActivity `782XTY4C7G`, notifications `T65FW8D9U5`, notificationcontent `ZBC5D75JZF`, watchkitapp
`JL6S5UT9X8`, complications `CCL328DN67`).

## Architecture map (what changed where)

- `Vory/App/VoryTabBar.swift` — **our own tab bar** (build 30): glass capsule of icon-only tabs, label
  and sliding pill under the selected one, detached glass compose circle. `MainTabView` in
  `RootView.swift` is a ZStack of pages + `.safeAreaInset(.bottom)` with the bar. Hidden by
  `AppModel.chatsPathOpen` (Chats path, instant) and `tabBarHiders` (`.hidesTabBar()` on
  `ConversationView` and `PushSetupView`). Compose raises `AppModel.newChatRequest`; `ChatListView`
  answers on Chats, `BotDetailView` answers with its `composeProfile` on Bots. `VoryOutlineIcon` is
  the Bots icon. `TabBarMinimizeObserver.swift` is unused now. The Chats `.searchable` must use
  `.navigationBarDrawer(displayMode: .always)` or iOS docks it at the bottom over our bar.
  Tried and rejected: `Tab(role: .search)` renders INLINE on this iOS; `ToolbarItem(.bottomBar)` sits
  behind the tab bar.
- `Shared/BotFace.swift` — **bot drawing** shared by app, Live Activity, notification service and
  reply window: `BotLookSpec(shape, eyes, hex)`, 8 body shapes, 8 eye styles, blink/glance/breath,
  `gaze` for the About easter egg. Avatar choice string `"studio:<shape>:<eyes>"`; legacy
  `"animated:<style>"`/`"initial"` map onto shapes. `CreatorStudio` (`Vory/App/BotAvatars.swift`)
  is the picker on the profile page; buttons must be `.borderless` (a List row tap otherwise fires
  "Reset to default"). `BotLooks` (VoryCore) mirrors colours/avatars/photo thumbnails into the
  shared keychain (`BotLooksMirror.mirror()` on launch and on change) for the extensions.
- `Vory/Chat/ConversationView.swift` — Messages-style header (bot above the name pill, springs in;
  Appearance › "Chat header shows" = `ChatStyle.headerShowsTitle`), `InteractivePopEnabler` drives
  the pop gesture from a full-screen pan (swipe back anywhere). `TranscriptView` follows the keyboard
  with a manual inset on an interpolating spring.
- `Vory/Push/LiveActivityController.swift` — start/adopt, phases (`thinking`/`streaming`/`tool`),
  finish: update to Finished (no expand), stays 30 s in the Island, then end with a 60 s Lock Screen
  linger; the LA token stays registered so the companion's end push lands. `HermesLiveActivityWidget`
  draws `BotMark` (still bot + phase badge), stats row = tokens + context "used/size".
- `VoryNotificationService/NotificationService.swift` — decrypts relay payloads, presents bot
  notifications as communication notifications (`INSendMessageIntent`, avatar rendered with
  `ImageRenderer`); test notifications use the cloud bot. Entitlement
  `com.apple.developer.usernotifications.communication` is on the APP only.
- `VoryNotificationContent/NotificationViewController.swift` — the long-press **reply window**: one
  card (bot, chat, time, bubble). It crashed until `UserNotificationsUI`/`UserNotifications` were
  linked explicitly (`OTHER_LDFLAGS`); the hosted view must be pinned with constraints (autoresizing
  from zero bounds stays zero). iOS fixes the pane height with the keyboard up (cap 29% of the screen);
  vertical drags belong to the system's pull-to-dismiss and SwiftUI button taps are not delivered
  inside the platter (a UIKit tap recognizer is). The companion still sends `hermes.thread` (unused).
- `Vory/App/AppModel.swift` — `AppModel.shared` exists before any scene so a notification reply that
  launches the app in the background has a model; `ensureConnection` activates the saved gateway,
  waits for the socket, holds a background task. `companionUpdateAvailable` drives the red badge on
  Settings and Software Update; refreshed on foreground.
- `Vory/Settings/SettingsView.swift` — Software Update page (`SoftwareUpdateView`, the companion's
  iOS-style update card), one-time "Set up notifications" card (`notificationsSetupCardDone`),
  About (Vory cloud; 5 taps → lifts, rains 5 s looking down, settles, `SpeechBubble` "Ahhhh…that's
  better."), Installed versions. Background Notifications shows two check marks only.
- `server/hermes-push/hermes_push.py` (1.0.25) — attributes a session to the profile whose REST
  `/api/sessions?profile=` list contains it (`session_profile`; `session.activate` echoes the profile
  it was asked with); forwards `session.usage` into the LA; phase pushes; finish = update then
  scheduled end (`HERMES_PUSH_FINISH_ISLAND` 30, `HERMES_PUSH_FINISH_LINGER` 60,
  `HERMES_PUSH_FINISH_EXPAND=1` restores the alerting update); reply notification always follows with
  `hermes.text` (≤1200) and `hermes.title`; payload trimmed under Apple's 4 KB.

## Change log

### 2026-09-25 (builds 25–30)
- 30: custom tab bar (Messages layout), Vory-cloud Bots icon, search pinned under the title.
- 29: bubble tails one piece with the bubble (reply card, About). Search-role tab verified inline.
- 28: compose as a fixed floating circle; About bubble above the cloud; reply window one card.
- 27: tried the detached search-role tab; About cloud lift/rain/bubble; reply window paging.
- 26: compose driven by the real tab bar frame; About lift-rain-settle sequence; reply pages pinned to
  the top; composer banner animated.
- 25: eyes glance as a pair; triangle face; no cloud seam; studio row-tap fix; Bots page Profile row;
  chat header → studio sheet (medium) with instructions at the bottom; native compose toolbar items
  (later replaced); Appearance header preference; notification replies reach the bot; reply bubbles
  tightened.

### 2026-09-24 (builds 11–24)
- 24: Creator Studio, BotFace drawing everywhere, Messages-style chat header, swipe back anywhere,
  Software Update page, first-run setup card, About with the Vory bot and rain, reply window with
  thread pages, companion 1.0.25 (LA finished first, thread fetch capped).
- 23: bot attribution from the gateway's session list (unifi chats no longer "Hermes MA"), live
  tokens/context in the LA, red row badges, keyboard spring, reply pane drag no longer dismisses.
- 21: reply window shows the thread, companion 1.0.23 sends it, test notifications from the cloud bot,
  update badge path, keyboard-following transcript. (20 and 22: stray cuts, expired.)
- 19: LA phases (brain/bubble/wrench), communication notifications with the bot's avatar, reply
  window crash fixed (framework link).
- 18: finished card 30 s in the Island then 60 s on the Lock Screen; reply window sizing.
- 17: notification content extension (reply window) added, with its own App Store profile.
- 16: LA ends 30 s after the turn, reply always arrives as a notification, context as used/size.
- 15: bot avatar in the Island, collapsed finish with a sound-only buzz (later replaced), stats row
  tokens + context.
- 14: total time instead of tokens once finished; companion carries usage.
- 13: version 1.0.1 with small build numbers (the user chose 1.0.1 after 1.0 (12) sorted under
  "previous builds"). 11/12: the same code as earlier builds under other version numbers.

### 2026-09-23 → 24 (date-numbered builds up to 2609240140)
- Project renamed HermesRemote → Vory; git repo + private GitHub; release tooling
  (`testflight.sh`, `deploy-relay.sh`, ASC JWT script).
- Live Activities fixed on Debug/USB (debug dylib, stale profile), NSE decryption fixed (keychain
  group from the extension's bundle id), companion 1.0.11–1.0.16 (self-reload, session id matching,
  heartbeat diagnostics, single alerting finish push), relay holds pushes for an hour, six-step setup
  wizard with animated mascots, Software-Update-style companion updates with restart countdown,
  Background Notifications page.

## Memory files (auto-memory, `~/.claude/projects/-Users-matt-claude-sandbox/memory/`)
- `hermes-remote-ios-project.md` — running state and every hard-won lesson above, in more detail.
- `vory-feedback-backlog.md` — the open TestFlight feedback items.
- `vory-ui-tests-need-signing.md` — the simulator/mock-gateway recipe.
