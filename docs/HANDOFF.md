# Vory — handoff and change log (2026-09-23 → 2026-09-25)

For the next agent picking this up. Everything below is committed on `master` of the private repo
`github.com/matt0975/vory` (local checkout `~/claude-sandbox/Vory`). The user is Matt (they/them);
they test on their own iPhone 17 Pro via TestFlight and send screenshots with feedback. Work one item
at a time, ship a TestFlight build, wait for their verdict.

## Where things stand

- **Latest: 1.1 (5)** (2026-09-27, the public-launch build: time reveal as a UIKit pan, one back
  pan per stack, filters/sorts, sticky pins, tab re-tap to top, About cloud, LA tap link +
  per-session tokens), companion **1.0.28**. Uploaded 2026-09-27 ~19:50, BETA_APPROVED at
  20:00 (build id 1359ef93-5e79-42a9-b331-2dd2427397d5): live for the public link.
- 1.1 (4) (2026-09-27, build-3 review fixes: studio taps, header pill, top inset, To: chips, list
  keeps new chats, scroll perf, time reveal), companion 1.0.27. Uploaded ~14:00 and
  NOT submitted: build 3 keeps its place in Beta App Review; internal testers get 4 at once
  (internal groups take every build automatically). Build 3 was approved later that day; 4 was
  added to the Public beta group and submitted, and went BETA_APPROVED within seconds. **Later 1.1
  builds:** add to the public group + POST betaAppReviewSubmissions; `buildBetaDetail.
  externalBuildState == BETA_APPROVED` means live for the public. See memory
  vory-public-beta-launch.md for the recipe.
- 1.1 (3): Live Activity + snapshot-order fixes, uploaded 2026-09-27 ~02:40.
- Earlier: 1.0.1 (43) uploaded 2026-09-26 ~15:05 (31–41 earlier that day), companion 1.0.26.
- **Build 45 uploaded 2026-09-26 ~18:05** (user: "Once done go ahead and push it") — the build-44
  review list (group composer, scroll/side-pull smoothness, tails, typing indicators, group
  previews + summaries + merged list, rename chat) and the **motion second cut** with its two
  review passes. Notes posted by `scratchpad/post-notes45.sh`. Awaiting the user's verdict;
  phone-only checks: header holds on a real reply (pebble → stem → back, "!" on a card), the
  typing bubble (grey / dark tool), scroll smoothness in long chats, group typing on the real
  gateway, LA held poses.
- Build 44 (2026-09-26 ~14:40) reviewed → the list above.
- Build 43 (2026-09-26 ~15:50) reviewed: approvals work, summaries "look amazing".
- **Public beta rule (user, 2026-09-26):** nothing user-specific in notes, setup copy, sample data
  or docs — no bot names, gateway names or hostnames. Write for strangers.
  Build 39 (shipped on the user's "ship it"): dark-mode icon blue lighter
  (layer `fill-specializations` for dark, light unchanged), cloud 1.21× and up 20 pt, slash-command
  list in the composer, bottom lock in the transcript, glass bots redraw on change, darker glass
  eyes, grey steer bubbles, no banners while the app is in front, composer morph id on the capsule, profile menu rebuilds on look changes, painted glass
  while the scene is inactive (switcher snapshot), composer drafts per session (`ComposerDrafts`). Companion plugin **1.0.25**.
  Builds 20 and 22 were superseded cuts and are expired. Build 38 = 37 + the icon's cloud 10 % larger (layer `position.scale` 1.1). Build 37 = 36 + Settings › Bots with "Liquid Glass for all bots" (greys out the per-bot
  switch with a note). Build 36 = 35 + Liquid Glass bots (beta toggle in the Creator Studio), bots in the profile
  switcher, bigger Bots tab icon, more room above the bar. Build 35 = 34 + the new app icon
  (user approved 34 and 35). Build 34 = 33 + capsule 56 pt (user: 62 felt tall; bottom edge kept) and the lens refracting the
  icons while dragged. Compose glyph centred on its square (user approved the zoom). Verdict on 31: not
  aligned like the system bar, no refracting glass lens, list rows cut off under the bar, labels
  should show only under the selected tab, compose circle should be the bar's height and its
  glyph centred — all addressed in 32.
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

## Public beta (TestFlight public link), 2026-09-26

- **Version 1.1, build 1** = the build-45 code re-tagged (MARKETING_VERSION 1.1 in the project;
  `testflight.sh` now passes `MARKETING_VERSION` to xcodebuild) plus Settings › About links
  (Send feedback → mailto:matt@vory.dev, Privacy policy, vory.dev) and a neutralised dev string
  in the mock. Upload: `MARKETING_VERSION=1.1 BUILD_NUMBER=1 ./Tools/release/testflight.sh`.
- App Store Connect (all set through the API, script pattern in the session scratchpad
  `asc_beta_setup.py` / `asc_submit_11.py`): beta app description + feedback email
  matt@vory.dev + privacy URL https://vory.dev/privacy/ + marketing URL; Beta App Review contact
  (Matthew Wagner, +1 978-935-6822, no demo account, review notes explain "no demo server; the
  tour, Connect and Settings work without a gateway"); external group **Public beta**
  (`adad2fc6-6da7-4a21-a47e-e7660b759cd5`), public link **https://testflight.apple.com/join/tJ4PyTfc**,
  cap 1000 (raise with a PATCH on `publicLinkLimit`). The first build of a version needs Beta
  App Review (24–48 h); later 1.1 builds usually go straight to the group.
- Export compliance stays `ITSAppUsesNonExemptEncryption = false`: the notification decryption is
  CryptoKit AES-GCM (Apple's OS encryption), which is the exempt case.
- Audit (2026-09-26): shipped code has no personal identifiers; the only developer-operated
  service is the push relay (device tokens + ciphertext only). Watch it with
  `Tools/release/relay-usage.sh` (Cloudflare GraphQL + KV; warns past 60k requests/day; free
  tier 100k/day, paid $5/mo for 10M). Baseline 2026-09-26: ~280 requests/day, 1 device.
- Privacy policy source: `docs/promo/privacy.md` (promo branch), live at vory.dev/privacy/.
- **App Store listing kept in step with TestFlight**: `Tools/release/asc-listing.py attach <ver>
  <build>` attaches a processed build to the App Store version (created if missing; state stays
  "Prepare for Submission" — nothing is submitted) and `… screenshots` replaces the 6.9" iPhone
  set from `Tools/release/screenshots/*.png` (sorted; any iPhone size, scaled to 1320×2868).
  `testflight.sh` runs both after every upload (`SKIP_LISTING=1` to skip). The current set (8:
  chats, chat + tool call, finished reply, bots, Creator Studio, and dark chat/chats/bots) was
  captured on the sim with the mock gateway, status bar overridden to 9:41. Recapture by hand when
  the UI changes; the approval-card frame is left out until the header "!" no longer covers the
  bot's name on the pill (nit for the next build). TestFlight itself never shows screenshots.
- 1.1 (2) replaced 1.1 (1) in review (build 1 expired to withdraw its submission; 1.1 (2) is
  `WAITING_FOR_REVIEW`); it is also attached to the App Store version 1.1.

## Promo (video + vory.dev site), 2026-09-26

`docs/promo/`: `VORY-PRODUCT-BRIEF.md` (public-beta-safe product brief), `PROMPT-claude-session.md`
(paste into a fresh session in this repo: asks questions → full plan → `/go` → video then site,
branch `promo`, output in `docs/promo/video` and `docs/promo/site`), `grok-package/` +
`vory-grok-package.zip` (self-contained package for Grok: prompt, brief, motion briefs,
BotFace.swift, icon renders, screenshots, demo video). Icon renders come from `ictool` (see
`docs/agent-memory/icon-composer-cli.md`).

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
- **Ask before shipping** (user, 2026-09-26: "Check with me before ship"): show the change, wait for
  "ship it". **Stale build number:** `testflight.sh` asks App Store Connect for the next number; while
  the previous upload is still processing it gets the same one back and altool fails with
  "Redundant Binary Upload" (90189). Within ~10 min of the last upload pass `BUILD_NUMBER=<n>`.
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

- `Vory/App/VoryTabBar.swift` — **our own tab bar** (builds 30–31), drawn to the native iOS 27 UITabBar's
  measurements (dumped from a throwaway native TabView on the simulator: capsule 62 pt, 4 pt inset,
  equal 54 pt slots with icon over a 10 pt label, 21 pt side margins, bottom edge 13 pt into the
  home-indicator area, 48 pt compose circle). Press-and-hold/slide drags the selection pill and
  switches pages as it passes tabs (one DragGesture on the capsule; slots are plain views with
  button accessibility). Detached glass compose circle. `MainTabView` in
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

### 2026-09-27 (1.1 build 5, the public-launch build, from the build-4 review)
- **Time reveal is a UIKit pan** (`TimeRevealPan` in TranscriptView.swift) on the thread's
  UIScrollView: begins only on a leftward, mostly horizontal drag while the thread is at rest
  (not decelerating, no offset change in the last 0.3 s), cancels the scroll view's own pan when
  it begins, slides the column left up to 80 pt, never right. Times sit past the right edge again.
- **Swipe back from anywhere, on every pane.** `FullScreenPop` (ConversationView.swift) owns ONE
  pan per UINavigationController (associated object, name `vory.fullScreenPop`) and is the
  delegate for it and the edge gesture; `InteractivePopEnabler` under each tab root (Chats, Bots,
  Files, Settings) and the chat installs it. Root cause of "some threads slide both ways and show
  no time": every pushed chat used to add its own pan and leave it behind with a dead delegate,
  so a stack accumulated pans that began on ANY drag.
- **Chats filters/sorts**: one comparator; pinned first in every order, then the key, ties by
  recency. Pinned rows the gateway's page leaves out are kept from the last load (`droppedIDs`
  excludes ones deleted here). A tap on the selected Chats tab scrolls the list to the top
  (`AppModel.tabReselected`, bumped in `VoryTabBar.select`).
- **About**: the cloud is `allowsHitTesting(false)` inside its tap box (same hole as the studio
  tiles), top padding 34 + `listSectionSpacing(8)`; rain and the caption verified on the sim.
- **Live Activity**: every surface carries `widgetURL` `vory://chat/<id>?profile=<bot>` (AppModel.open
  reads the profile); `PushRegistrar.liveActivities` files every open activity under
  `live_activities` in the device file (the single fields keep the latest for companions < 1.0.28);
  companion **1.0.28** `live_activity_devices` yields one target per matching entry, so two running
  chats each get their own updates and end; the app no longer raises its own approval alert when
  the companion delivers (one buzz).
- Not done (a later build): push-to-start Live Activities for turns started elsewhere.

### 2026-09-27 (1.1 build 4, from the build-3 review)
- **Time reveal.** The bubbles no longer move: `TimeRevealColumn` hands `reveal` (0…1) to its
  content and each row overlays its time (thin-material capsule) sliding in from the right edge,
  built only while a pull is in progress. A pull to the right does nothing.
- **A new chat vanished from the list.** The gateway creates a session's DB row only on the first
  prompt ("no Untitled litter") and the row fills in as the turn flushes, so `/api/sessions` can
  miss a chat started moments ago or still running; leaving it (via the Live Activity, say) showed
  a list without it. `ChatListView.load` now appends a row for every chat open in the app
  (`runtime.chats`) that the gateway did not list, if it is running or has a prompt.
- **Scroll stutter.** Every finished reply drew a live bot view (glass + timeline) beside its
  bubble and every tool card was interactive glass; both composite per frame. Finished replies
  now show a painted bot (`BotAvatarImage.cached`, memoised by look), only the streaming reply
  keeps the live bot, and tool cards are painted (secondary grouped fill + hairline).
- **Creator Studio tiles did not respond to a tap on the face.** `BotFaceView` marks its layers
  `allowsHitTesting(false)`, which leaves a hole in any SwiftUI `Button` it sits in exactly where
  people tap (the label text still worked). Rule: a button or tap target that contains a bot face
  needs `.contentShape(.rect)` (or `.capsule`) on its label so the whole tile is the target. Applied
  to the studio grid (`grid` in BotAvatars.swift; preview also `allowsHitTesting(false)` so its
  spin-tap does not compete), the chat header pill (bot + capsule are one button; the tap also
  plays the small turn via `BotAmbient.shared.tap`) and the New Message chips.
- **Header pill let taps through / did nothing on the bot.** Same cause; the header `HStack` is
  now one surface (`contentShape(.rect)` + empty `onTapGesture`) so a tap on the bar never reaches
  the thread under it (a tool card used to expand).
- **First message under the header at the top of a thread.** `TranscriptView` ignores the top safe
  area (the thread runs under the status bar) while the header overlay sits inside it; the top
  content margin is now `headerHeight + safeTop` (ConversationView).
- **New Message: a chosen bot could not be removed.** The chip is a full-capsule tap target, and
  Backspace on the empty To: field removes the last chip on the software keyboard: an invisible
  zero-width mark (`mark`) sits at the start of `query` while bots are chosen, and its deletion is
  the Backspace signal (`onKeyPress(.delete)` only sees hardware keys). `typed` is the query
  without the mark; use it for matching.

### 2026-09-27 (1.1 build 3: Live Activity updates on its own, mid-turn snapshot order)
- **Live Activity did not update unless the chat was open — companion 1.0.27.** The gateway sends a
  session's events (`message.delta`, `tool.start`, `session.usage`, `message.complete`, approval
  requests) ONLY to the clients attached to that session. 1.0.26 stopped calling `session.activate`
  (it stole the phone's approval cards) and so received no events at all: the LA only moved when the
  app's own socket was attached. 1.0.27 mirrors instead: after discovery it calls
  `session.resume {session_id, omit_messages: true}` on each live session, which attaches its socket
  ALONGSIDE the phone (a fan-out, additive membership), so every event reaches both. It advertises
  `client.capabilities {server_requests: true}` but NEVER answers a request (the gateway settles a
  request on the first reply, so an error reply would withdraw the phone's card); request frames go
  to `handle_request` as `__request__` events, which pushes the LA `waiting` + `needsAttention` state
  and the alert. Unanswered requests wait in the gateway's `open_requests` and replay on the phone's
  next resume. `request.cancel` clears `needsAttention`. Mirror memberships keep a session alive, so
  after `HERMES_PUSH_RELEASE_IDLE_SECONDS` (600) of nothing running the companion drops its socket
  (`ReleaseIdle`) and reconnects, re-mirroring whatever is live. Diagnostics: `_note_la("mirror …")`.
  Verified with the companion dry-run against the fan-out mock: thinking → streaming → tool → waiting
  (attention) → done + alert, while the phone still got its card.
- **Duplicate section after multitasking.** Mid-turn the gateway snapshot already holds the turn's
  flushed tool/assistant rows in `messages` while the prompt is still `inflight.user`; the app
  appended the prompt at the end, so the turn's rows sat above it and the partial reply below.
  `ChatSession.apply(snapshot:)` now inserts the prompt at the first row stamped after
  `turn_started_at` (fallback: after the last reply), stamps it with that time, and dedupes a flushed
  prefix of the partial only among rows after that point. Tested by killing the app ~3 s and ~7 s
  into a turn and relaunching: previous turn intact → prompt → tool card → partial/streaming, and
  the pending approval card replayed.
- **Mock gateway** models the fan-out: a shared `LIVE` registry with members, flushed `history`,
  `inflight`, `running`, `turn_started_at`, open requests replayed in `open_requests`;
  `session.active_list` lists live sessions with `session_key`/`status`; `session.resume` joins a
  live session (respects `omit_messages`). Restart the mock after editing it.
- The "!" ask pose lifts off the pill (`ConversationView` header spacing 2 while awaiting approval)
  so its dot no longer covers the bot name.
- **Ship:** 1.1 (3). The user must install companion 1.0.27 from Settings › Software Update.

### 2026-09-26 (build 45, from the build-44 review + the motion second cut)
- Group chat: `RoomView` gets `.hidesTabBar()` so the composer is not under the tab bar.
- **Scroll performance**: `BotAmbient.scrolled` throttles the gaze to ~16 Hz and only when it
  changed by > 0.03, and sets `scrolling` once; `BotFaceView` under 32 pt (beside bubbles, the
  toolbar) does not read the ambient at all, so a long thread's bots do not redraw per tick.
- **Time reveal** (drag left for timestamps): `TimeRevealColumn` wraps the thread — one `.offset`
  on the column plus the drag gesture in that small view; each row's time sits at a fixed
  `offset(x: 60)` past the right edge. Rows no longer read the drag state, so a drag re-renders
  nothing but the wrapper.
- **Tails** (`Vory/Chat/MessageBubbleShape.swift`): Messages' curl at the bottom corner on the
  speaker's side; only the last bubble of a run (`TranscriptRowModel.lastOfRun`, now for user
  runs too). Used in TranscriptRow (user, reply, steer) and RoomView.
- **Typing indicators** (`Vory/Chat/TypingBubble.swift`): thought bubble with the two trailing
  circles and three dots rising in turn (TimelineView); dark with a mint `ToolBadge` when
  `typingTool` is set. Single chat: a reply row with no text yet shows it (reasoning above in
  a plain bubble, live `TurnStats` label below), and `TranscriptView` adds a standalone typing
  row whenever `chat.isRunning` and the last item is not an empty streaming reply (between
  parts, during a tool) — dark while `chat.botState == .usingTool`. Group chat: `RoomView.typing`
  derives who is composing from `room.activity` (status containing typing/thinking/working,
  member from `member_id`/`handle` or the status's first word; a message from them or a
  settled/idle/done activity clears it); typing activities are not drawn as lines; polling
  runs at 1.2 s while someone is typing or within 30 s of a send, else 4 s. Mock: `groups.send`
  now answers 4 s later (`call_later`) with a `settled` activity after.
- **Chats list**: group chats show only with the "Group chats" filter on — and then **in the
  main list**, merged with chats by recency (`ListEntry` session/room, `merge`: pinned first,
  then `lastActive`/`updatedAt`), each with a `person.2.fill` mark; rows are `sessionRow` /
  `roomRow` builder funcs. Group rows fetch `groups.log` (last 40) into
  `roomLogs` for a "You: …"/"Hermes: …" preview (markdown marks stripped) and feed
  `ChatSummarizer.refreshRoom` — summaries keyed `room:<id>`, stamped with the last seq —
  showing the sparkle title + summary like session rows.
- **Rename chat**: profile sheet › This chat › Name row → alert with a text field →
  `chat.rename(_:)` (`session.title`).
- **Motion second cut** (user's follow-up brief, `docs/bot-motion-brief-2.md`): the named states
  now HOLD a silhouette, morphed in place on the same view (never a swapped view — glass would
  bloom). `BotFace.Motion` gained `morph` (0…1), `morphTarget` (`MorphTarget`: none /
  exclamation / pebble / stem), `eyeOpacity`, `dim`. `bodyPath(morph:target:)` →
  `morphedPath`: the rest outline and the target are sampled as 72-point radial rings from the
  square's centre (`radialRing`: march out + bisect on `Path.contains`) and lerped point for
  point; rings are cached per shape/size/target (`ringCache` + lock). Targets: `pebblePath`
  (superellipse, mass in the lower half, same bounds), `stemmedPath` (body lowered to 80 % from
  its base + rounded stem to the top of the square), exclamation = the rest ring clipped at 66 %
  into two polygons (`clip`, Sutherland–Hodgman) each `resample`d (even spacing, start at the
  topmost point) and paired with the stem / dot rings (`exclamationRects`). States: approval →
  exclamation over 0.6 s, eyes fade with it, +8° roll (×0.75 on the cloud), nudge every 2.8 s;
  thinking → pebble 0.55 s, 0.42 squint, blinks at 2.8 s; usingTool → stem 0.6 s, eyes
  down-right frozen, one lean; error → eyes shut to dashes at the bottom, −4° roll, `dim`
  (crown/sheen die; live glass darkens the colour layer under the plate and halves the tint);
  reconnecting → `eyeX = 1.8·sin` (a visible sweep, 1.1 s a side); streaming → 0.55 squint and a
  sheen every 2.2 s; guide → per 8 s a glance down at the bubble, one sheen, a 1.5 % nod (the
  `VoryGuide` no longer passes a fixed gaze); working → **3.2 s blocks** (~1.1 s routine, ~2 s
  rest). `BotFaceView.pose(now:)` morphs back over 0.4 s after a held state ends
  (`exitTarget`/`exitAt` from `onChange(of: state)`); Reduce Motion jumps to the held pose.
  `widgetPose` holds the same silhouettes for the Live Activity. Light bots (`isLight`, luminance
  > 0.82): a 1 pt `#D0D0D5` @ 40 % inner stroke (`drawInnerStroke`, body minus body inset; live:
  a masked ring) and a cool grey crown instead of white. Demo grid: "Release states" / "Hold
  states" toggles the holds so the morph in/out can be watched.
  **Review fixes** (an adversarial workflow — 5 lenses × 2 refuters per finding — ran over the
  diff; 33 confirmed): held→held changes (thinking → tool, the commonest in a chat) popped to
  rest — `BotFaceView.pose` now eases the OLD state's whole pose out over 0.4 s (`exitState`,
  silhouette + roll + dim + eyes lerped) and delays the new state's clock by 0.4 s, so the path
  is continuous held to held; taps/finish spins dropped the hold — `motion()` computes the
  state pose first and overlays the one-shot in a `defer`; the sheen never painted on flat bots
  — the Canvas twin gets `Motion.transformsStill` (yaw/roll/offsets zeroed, sheen kept) instead
  of `bodyStill`; `drawGlassBody(dim:pale:)` kills the crown/rim with `dim` and paints the cool
  crown for white bots; `BotFace.rimInner` insets each disjoint piece of a path toward its own
  centre (the "!" no longer gets a lopsided rim; the cloud's overlapping bumps stay one group),
  used by the painted rim/sheen/hairline and by `BotBodyShape(inset:)` for the live masks; the
  pebble and "!" are built from the rest shape's bounds (base and width kept — no sinking into
  the header pill); the blob's outline phase is continuous (`Motion.blobPhase` from
  `blobOffset/blobFrozen/blobRunning`, `BotFace.blobRing` computes its live rest ring) so no pop
  at working↔held; the guide never morphs (`Mood.squint` instead of `.thinking`); Reduce Motion
  jumps eyeOpacity/dim to the end pose; streaming sheen fades to 0 at the seam; routine 5 is an
  eyes-only look-up (no 5 s freezes); thinking blinks slowly (`blinkLength` 0.22); `draw()`
  keeps the eye fade in its own layer; sleepy lids no longer double-apply roll/fade; rings are
  cached relative to the box origin; bots under 32 pt hold their shape (eyes only).
  **Pass 2** (the review re-run, cut short by the usage limit but with the key finds): the
  ease-out still popped at its end (the new state's clock jumped 0 → 0.4 s) and read the old
  state as fully held — replaced by a **snapshot blend**: `BotFaceView` records the pose it
  rendered each frame (`shown`, a class box so no state changes mid-frame); on a state change
  `exitPose = shown.pose`, `exitAt = now`, and `stateSince` is set 0.4 s AHEAD when the snapshot
  holds a silhouette (so the old shape unwinds before the new grows); `pose()` then lerps
  morph/roll/dim/eyeOpacity/eyeOpen/eyeX/eyeY from the snapshot to the new pose over 0.4 s.
  Verified with a 30 fps harness (`scratchpad/cont`): every channel now moves ≤ one ease-step
  per frame across idle→thinking→tool→thinking→working→idle, a state left mid-morph, a tap
  during thinking, a finish spin during approval, reconnect and streaming entry/exit. Also:
  Reduce Motion block runs before the < 32 pt gate (small bots stay eyes-only under RM), RM
  keeps the held lean and freezes the blob (`onChange(of: wobble && !reduceMotion)`),
  reconnecting eases in (`smooth(since/0.4)`), routine order interleaves eyes-only beats
  (`order = [0,5,1,8,2,6,3,7,4,9]`) so the body never rests two blocks running, rings sample
  144 rays, the "!" on a short body (pill) uses a mark ≥ 72 % of the square so stem and dot
  clear by ~10 pt, `rimInner` groups pieces by ≥ 20 % area overlap (no flip as the "!" parts).

### 2026-09-26 (build 44, from the build-43 review)
- **Light-mode bot colour everywhere painted**: `BotFace.draw(..., light:)` →
  `drawGlassBody(light:)` uses the live glass's light recipe (lighter shadow 0.12, fill 0.82→0.68,
  rim dark 0.10, specular 0.5). `BotFaceView` passes `colorScheme == .light`. Menu/picker images
  (`BotAvatarImage.make(scheme:)`) render for the current scheme and are `.renderingMode(.original)`
  so the toolbar/menu tint no longer paints them blue; `.id` keys include the scheme. Fixes the
  corner profile button, Settings picker, context-menu preview and app-switcher snapshot.
- **Per-shape seating**: `BotFace.baseline(of:)` is now a hand-set table (blob .985, pill .795,
  cloud .825, triangle .815, others .96) and `seatDrop(_:)` = distance to the blob's base. `BotCard`
  overlap `10 + 78 * seatDrop`, chat header `9 + 52 * seatDrop`. DEBUG `-vory-shape-grid` overlays
  every shape on a pill on the Bots tab to eyeball it.
- **Group chats**: `groups.send` params `{room_id, event_id: "evt-<12 hex>", payload: {text,
  thread_id: "main"}}` (the gateway rejects any other payload key set). RoomView renders
  `message.user` (blue bubble, right), any other `message.*` (grey bubble with the member's bot,
  name above) and `room.activity` (`payload.status`, quiet centred line); other kinds hidden.
  Empty state shows the room's bots overlapped + names + "Say something to the group"
  (`loaded` flag so it does not flash before the first `groups.log`). Chats list: filter toggle
  "Group chats" (`chats.filter.groups`), context-menu `RoomPreview` (last 5 messages), swipe
  leading Archive (local `chats.archivedRooms` CSV of room ids; hidden unless "Archived" is on)
  and trailing Delete (tries `groups.disband`, `groups.delete`, `groups.close`; alert first).
  Mock gateway now has `groups.send` (validates the payload, appends user + activity + member
  reply to `ROOM_LOGS`) and a real `groups.log`.
- **Attachments**: composer strip shows photos as 64 pt thumbnails (tap → QuickLook via
  `stagedPreview`) with an × badge; other files stay chips. `ChatSession.apply(snapshot:)` keeps
  local `AttachmentPreview`s for user messages with the same text (the gateway transcript has
  none) — including the `inflight-user` row — so the photo stays in the bubble after send.
- **Companion page**: Configure / Software Update section first, then status, then This phone.
  Software Update "Check again" → card says "Checking for updates…" and Vory (profile
  `vory-update`) does the 360° turn (`turnFinished` on `checkingCompanion` rising edge).
- **Wizard**: `StepPage` content margin `headerHeight + 10` (initial 270) so the Install step's
  section header clears the title. `SpeechBubbleShape(tailOnTop:)` — `VoryTypedBubble` tail now
  points up at Vory. `Color.readableGreen` (dark: systemGreen; light: 0.10/0.50/0.22) for the done
  bubble tint and the "Installed at…" line.
- **Test notification**: NSE sets `categoryIdentifier = "HERMES_TEST"` (registered with no
  actions, no content extension) and Vory's look `studio:cloud:classic:glass`.
- **Live Activity**: `GlassDisc` (gradient fill, top specular, gradient rim, shadow) behind
  `PhaseGlyph` (20 pt) and `PhaseBadge`; attention state keeps yellow with a dark symbol.
- **Summaries** generate one at a time (`pending` queue, `drain()`, `Task(priority: .utility)`).
- `UpdateCommit.at` decodes a String or a number (Unix seconds → formatted); fixes the System
  page's Maintenance decode error.
- Settings symbols: Scheduled Tasks `timer`, Companion `puzzlepiece.fill` (rows + header cards).
- Creator Studio swatches get a 1 pt `primary.opacity(0.18)` hairline (white swatch visible).
  New Bot sheet: preview (84 pt, zero row insets, 6 pt top margin) → Creator Studio → Bot →
  Model; no auto-focus on Name (it scrolled the sheet to the middle on open).
- Conversation with a resume error: placeholder hidden, `ContentUnavailableView` padded above
  the dock + keyboard, composer disabled until the chat opens.
- **Chat rows**: `ChatRowStyle` — card inset 8 (was 16), row leading inset 12, preview 2 lines;
  DEBUG `-vory-row-style a|b|c` (a = old, b = default, c = 3-line preview). User picked **B**.
- **Bot beside replies** (user ask after seeing the group chat): `TranscriptRow(profile:botShown:)`
  puts a 28 pt `BotAvatar` (active while streaming, squint while empty) at the bottom-left of a
  reply bubble; `TranscriptRowModel.lastOfRun` so a run of replies (tool cards between them
  allowed) shows the bot once, the others keep a 28 pt margin. Toggle "Bot beside replies"
  (`chat.showBots`, on) in Appearance and the chat's display sheet.
- **Group chat empty state**: the room's bots overlapped + names + "Say something to the group".
- **Attachment cards** (`Vory/Chat/StagedCard.swift`, modelled on Grok's composer): 92 pt rounded
  card with the photo, or the document's first page from `QLThumbnailGenerator` (PDF, text, video
  frame) inset on the card; a glass pill along the bottom edge names the kind (Image / PDF / Audio /
  Video / Text / EXT); a black × on the top corner removes it; tap → Quick Look.
- **Long text → file**: `ComposerView.onChange(of: text)` — at 800+ characters (a paste lands in
  one jump, typing crosses the line once) a glass strip appears above the field: "That's a lot of
  text." Keep / Attach as file. Attach writes the text to `<first line>.txt`, stages it as
  `.file` (uploads via `file.attach` as text/plain) and clears the field. Keep holds until the
  text shrinks under the limit again.
- **Motion system v2** (from the user's `FABLE_VORY_BOT_MOTION_BRIEF.md`, saved as
  `docs/bot-motion-brief.md`), all in `Shared/BotFace.swift`:
  - `BotFace.State` — idle, working, thinking, usingTool, streaming, awaitingApproval, error,
    reconnecting, guide. `BotFaceView.Mood(state:groupIndex:groupCount:still:)`; `.idle` +
    `active` still means `.working` (old callers unchanged). `ChatSession.botState`
    (`Vory/Chat/ChatSession+BotState.swift`) maps cards → approval, resume error → error,
    "Reconnected…" banner → reconnecting, status line Thinking/Sending/Queued → thinking,
    Running/Preparing → usingTool, else working.
  - `BotFace.Motion` grew `eyeOpen` (cap), `eyeX/eyeY` (extra glance), `freezeGlance`,
    `blinkPeriod`, `sheen` + `sheenAngle` (rim light, degrees clockwise from the right, −130 =
    lit top-left); `bodyStill` for Reduce Motion / painted renders.
  - `BotFace.motion(time:seed:spec:state:since:finishedAt:tappedAt:group:)`: finish spin (turn +
    blink edge-on + glance down after), tap (18° and back, blink, sheen tick), then per state.
    Working = 5 s blocks, kind `(((index + seed) % 10) + 10) % 10`: 0 full turn (sheen rides), 1
    glance turn (eyes lead 60 ms), 2 head tilt, 3 nod (drop 1.5 %), 4 lean, 5 rest, 6 squint &
    settle, 7 scan, 8 rim sheen, 9 half-turn (round, blink, round again). Cloud roll ×0.75, pill
    roll ≤3°, triangle nod→lean. Groups (`group`) share the clock and take turns, one body per
    block. `widgetPose(phase:attention:)` for the Live Activity Canvas (squint / rolled ask /
    lowered eyes; `draw(motion:)` paints roll + sheen).
  - Eyes: `liveliness(blinkPeriod:blinkLength:doubleBlinks:glancePeriod:rare:)` — rare slow blink
    / micro-squint every ~25 s; tiny eyes blink 90 ms and skip the double blink under 32 pt;
    curious's tall eye glances 60 ms late; sleepy lids weigh instead of squashing.
  - Sheen: painted via `drawSheen` (conic arc, body minus shrunk body); live glass via an
    AngularGradient-filled body masked to a ring.
  - `BotAmbient.tap(profile:)` + `tapped` (BotFaceView adds a simultaneous TapGesture).
  - **Bug found on the way**: `BotFaceView.seed` folded the profile name with `&*`, which wraps
    negative, and Swift's `%` keeps the sign, so bots with longer names picked one routine
    forever (before this build: never moved). Seed is now `UInt(bitPattern:) % 1_000_003`.
  - `MotionDemoView` — Settings › Bots › **Preview motion** (in Release too, so the user can
    review every pose on the phone) and DEBUG `-vory-motion-demo` over the Bots tab: every
    state on six hero looks plus a "Finish spin (all)" button; `Tools`: `ffmpeg … fps=10,tile=` strips from
    `simctl io recordVideo` are how the motion was checked.
  - Callers: header `Mood(state: chat.botState)`; chat list rows `.streaming`/`.thinking` while
    live (eyes only, no body routines at 34 pt); bubble bot `.thinking` until text, then
    `.streaming`; Bots grid cards `groupIndex/groupCount`; room empty-state stack `still` for the
    back bots; `VoryGuide` `.guide` (sheen every 8 s) / `.thinking`; Software Update `.thinking`
    while checking, turn on the falling edge.
- Shipped as build 44 after the user reviewed the motion demo ("Okay ship it").

### 2026-09-26 (build 43, from the build-42 review)
- **Tilt** is its own switch (Settings › Bots › "Tilt with the phone", BETA, `bots.tilt`, off by
  default; needs Motion effects on). Curve: 5° dead zone, full at ~40°, smoothing 0.12.
- Triangle corner radius 0.24 (glass rim smudged at the sharp vertices).
- **Re-tap a tab → animated pop**: `PopToRootProbe` (UIViewRepresentable under each root page)
  finds the UINavigationController and `popToRootViewController(animated:)`; no more `.id` re-create.
- **Setup wizard**: opens on step 1 always; glass back button top-left (`step.previous`).
- **FlowLayout** measures each child against the remaining width (a TextField's ideal width is
  huge) so the To: row only wraps when a chip will not fit.
- New messages glide (`withAnimation(.easeOut(0.28))` on the count-driven follow scroll).
- **groups.create** sends a client `room_id` ("room-" + 10 hex), `handle` per member, ≤ 6 members
  (compose sheet caps at 6); the created room is read back from `groups.list`.
- **Scheduled Tasks**: list has top margin and a readable schedule (`CronSchedule.expression(of:)`
  unwraps object schedules); `CronJobDetailView` is a form — name, Enabled (pause/resume),
  Repeats picker + weekday/day-of-month + time DatePicker building the cron line, prompt editor
  (falls back to prompt_preview), Delivers-to picker, details — plus a "Raw JSON" DisclosureGroup
  with a TextEditor; save = raw diff + form fields via PUT updates.
- **Companion page** (`CompanionView`, was BackgroundNotificationsView): status → Configure →
  Software Update (badge) → Uninstall → diagnostics. Settings row "Companion" replaces Software
  Update; Notifications page links to it; first-run card leads to it.
- **Uninstall**: `install.sh --uninstall` (stops systemd/launchd, deletes plugins/vory-push and the
  push dir); the app disables the plugin, withdraws the device file, asks Hermes to run the
  uninstall (approval card in a new chat, like the install), then `startOver`.
- **Live Activity**: `BotMark` draws with a Canvas (a TimelineView blanked the bot per update);
  expanded layout restored (timer `.frame(width: 52)`, no fixedSize); approval state = "Needs
  Approval" + detail in the bottom region and `ApprovalButtons` (Approve / Deny `Link`s to
  `vory://approval?session=…&choice=once|deny`) in the trailing region and on the Lock Screen.
  `AppModel.open(_:)` routes that to a `PendingRoute` with the notification action, which opens
  the chat and applies the choice.
- **Chat menus on the phone** (unreproducible on the sim): composer capsule is `.regular` glass,
  not `.interactive()` (interactive glass answers touches itself); noted in the composer.
- **Vory Summaries** (`Vory/Chat/ChatSummaries.swift`, FoundationModels): `ChatSummarizer.shared`,
  `@Generable Draft {title, summary}`, `LanguageModelSession.respond(to:generating:)`; cache
  `chats.aiSummaries.cache` keyed by session id with the `lastActive` stamp (≤ 300); switch
  `chats.aiSummaries` in Appearance (disabled with the reason when the model is unavailable);
  `SessionRow(summary:)` shows title + summary with a sparkle; a tour page (inserted before
  Connect) with the switch, only when the model is available. The simulator has no model.
- Settings tiles: one symbol size (15 pt medium) centred in 28 pt. Every Settings sub-page starts
  with `SettingsHeaderSection` (60 pt tile, title, one-line description; the bar title is "") —
  inserted as the first section of each page's List by struct name (see `b43e.py` in the session
  scratchpad for the list of pages; add one to any new page).

### 2026-09-26 (build 42, from the build-41 review)
- **Motion, gentle**: `BotFace.Motion` is now {yaw, roll, dx, dy} — no scale anywhere (breathing
  removed too). Routines per 5 s block: full 360° turn about the vertical axis (`rotation3DEffect`,
  eased by `stroke()` = slow–fast–slow), a partial yaw glance, a ±4° head tilt, a 2 % nod, a small
  lean; the rest of the block is still. Applied as view modifiers in `BotFaceView` (both painted
  and glass); `draw()` no longer transforms. The finish spin is the same turn. Seed now includes
  `mood.profile` and offsets the block clock (`seed % 47 * 0.31 s`) so bots never move in unison.
- Pills: the overlap is measured from the shape's base (`BotFace.baseline(of:)` = bodyPath
  boundingRect.maxY) so every shape sits the same (Bots page 10 pt, header 9 pt onto the pill).
- Header status line is `.secondary` (was the bot colour, unreadable).
- **LA approval state**: yellow keyline/tint, `exclamationmark.triangle.fill` pulsing, compact
  trailing "Approve", headline "Approval needed"; bot name `.minimumScaleFactor(0.6)` +
  `.layoutPriority(1)` and the timer column no longer fixed-width (it truncated "defen…"). In-app
  haptic (`.warning`) when a card arrives in the foreground. The LA already stays while waiting
  (no message.complete until the card is answered).
- **Companion copy** (generic): Software Update card/footer and the update rows say
  notifications + Live Activities + approval cards; Software Update shows an "Install the Vory
  Companion" link (→ `SetupWizardHost`) when nothing is installed; the Settings first-run card is
  "Unlock Vory's full potential" and leads to Software Update.
- **Post-connect prompt** (`RootView` → `CompanionPromptSheet`): once, when `hasConnections`
  flips false→true (`companionPromptShown`); "Install now" opens the wizard in a sheet and sets
  `notificationsSetupCardDone = true` (the Settings card never shows); "Later" leaves the card on.
  DEBUG launch args: `-vory-show-tour`, `-vory-show-companion-prompt`.
- **Connection types** (`GatewayFormView.ConnectionKind` local/tailscale/cloudflare/other, saved as
  `GatewayConnection.connectionKind`): a menu picker with a short footer per type, per-type URL
  placeholder, warnings (Tailscale address check via `GatewayURL.isTailscaleHost` = *.ts.net or
  100.64/10; local vs public; Cloudflare needs https), the Access section only for Cloudflare/Other.
  Nothing in the transport changed — Cloudflare Access headers and local http work as before.
- **Tour** (`Vory/Connect/OnboardingView.swift`): Vory at the top, a typed speech bubble
  (`TypedBubble`), a 360° on every page (`BotAmbient.turnFinished("vory-tour")`), a squint on the
  approvals page; per-page demos loop on their own: `BotsDemo` (six bots, all `active`, own
  clocks), `ChatDemo` (question pops in → typing dots → reply types → tool card slides in and
  ticks → second reply; repeats), `ApprovalDemo` (card slides up → "Once" is pressed with a
  ring → green; repeats), `IslandDemo` (compact Island on a wallpaper gradient panel → expands →
  Finished → notification drops in; repeats), `StudioDemo` (a body, then a colour, then eyes are
  "tapped" in turn), `ConnectDemo`. All copy generic; the sample bot is "Ada". The 3D turn uses
  `perspective: 0` — any perspective stretched the glass body near edge-on.
- **Companion setup restyled like the tour** (`PushSetupView`): `VoryGuide` (Vory + typed bubble,
  shared in `Vory/Connect/VoryTalk.swift` with the tour) over each step's form; the bubble says the
  step's hint, then "That's done — tap Continue."; Vory turns on each step and again when a step
  completes (`turnKey`), squints while installing/waiting. Buttons: Continue (Done on the last
  step), and under it Exit on step 1 / "Cancel setup" after that (confirm → `startOver` wipes the
  phone's progress). No step marks, no arrows, no X. DEBUG arg `-vory-show-setup` opens it.
- **No materialize bloom on bots**: `BotFaceView` no longer changes identity on a look change
  (it nudges `eyesBusy` to un-pause the timeline instead) and both glass layers carry
  `.glassEffectTransition(.identity)`. The chat header bot fades in (no spring from 0.3). The
  Chats profile button draws the bot `drawn: true` — glass on the toolbar's glass went murky.
- **Bubbles**: `SpeechBubbleShape` (tour, wizard, About) and the reply window's `BubbleShape` are
  single continuous outlines with the tail in the stroke; the wizard's `TypingBubble` is gone.
- Compose chips wrap (`FlowLayout`); `GroupChats.create` takes the room from `groups.list` (by the
  returned id, else newest by name) — the real gateway's create response is not the room.

### 2026-09-26 (build 41, from the build-40 review)
- **Approval cards — the real cause.** The app's `client.capabilities {server_requests: true}` was
  always sent; the gateway log said "the attached client predates server→client requests" because
  the *companion* (`hermes_push.py`) called `session.activate` on every session (discover, thread
  fetch), which made ITS socket (advertising `server_requests: false`) the attached client. 1.0.26
  never activates: attribution from the live list + per-profile REST list, the reply-window thread
  from `GET /api/sessions/{id}/messages`, pending cards from `approval.pending`. If cards still fail,
  check the gateway log for which client is attached when the approval is raised.
- **Motion**: routines are now nod / 360° spin / small wiggle / lean (5 s blocks, only while
  working); the hop and pulse are gone. `BotFace.motion(…, finishedAt:)` plays one 360° whenever a
  turn ends (`BotAmbient.finished[profile]`, set from `LiveActivityController.end`; the view nudges
  itself after 1.4 s so the timeline pauses again). `strain` (thinking: `isRunning && statusLine ∈
  {nil, "Thinking…"}`) squints the eyes to 42 % open. `glanceFree` false (Bots page, tilt > 0.3 of
  the ±1 range) stops the wandering glance; the eyes follow the tilt fully instead. Bots page bots
  play random routines while `BotAmbient.scrolling` (450 ms after the last scroll delta).
- **Light mode**: tinted glass alone rendered dark on white (sky-blue → navy); `liveGlass` now lays
  the colour down first (`BotBodyShape.fill(tint 62 % light / 28 % dark)`) with lighter glass tint.
- Pills: capsules, thinner; the bot overlaps the top edge by ~9–10 pt (user tuned by eye: "sitting
  on it", then "a tiny bit lower"). Chat header `VStack(spacing: -9)`, Bots page `spacing: -10`.
- `NewBotSheet` (Bots and Chats "+"): name (sanitised to a folder name), description, default
  model, clone-from, Creator Studio under a draft key that moves to the real name on create; POST
  /api/profiles then PUT description/model. Settings › Profile rows show the bots.
- groups.create members now carry `handle` (the real gateway requires it); compose chips scroll
  instead of truncating; the slash list fades/scales in place instead of sliding from under the
  keyboard.

### 2026-09-26 (build 40, from the build-39 review)
- **Painted glass cloud**: rim = body filled minus body shrunk (destinationOut), not a stroke
  (`BotFace.drawGlassBody`) — a stroke drew every inner edge of the multi-piece cloud.
- **Slash list**: any ScrollView inside the dock swallows SwiftUI keyboard avoidance → the dock is
  lifted by hand (`ConversationView.keyboardInset` from `keyboardWillChangeFrame`, whole view
  `.ignoresSafeArea(.keyboard)`); names arriving with "/" are shown with one; rows fixed 38 pt.
- **Tab bar hiding per tab** (`AppModel.tabBarHiders: [AppTab: Int]`, `chatsPathOpen` only counts on
  Chats, bar `.allowsHitTesting(!hidden)`): a tap on the bar while it slid away switched tabs under
  an open chat and hid the bar everywhere (reproduced with automation; log via NSLog on the flags).
- **Re-tap tab → root**: `tabAtRoot[tab]` reported by `.tabRoot(tab)` on each root page (Chats via
  its path); `popToRoot[tab]` bumps an `.id` on the tab's content (re-creates at root; Chats resets
  its path instead).
- **Approvals**: routing by runtime OR stored id, unknown sessions are opened (`openChat`) and then
  answered; `advertiseCapabilities()` logs the result and retries once if "approval" is missing;
  `ChatSession.pollPendingApprovals()` after every resume. The handshake itself already existed —
  if cards still fail on the real gateway, check the os_log line `client.capabilities → …`.
- **Notification bot lookup**: `BotLooks.key(profile:label:)` (name → label → case-insensitive);
  the mirror writes each look under name AND label and fills default colours; the NSE breadcrumb
  (Background Notifications page) now says which key it found. Reply window text scrolls.
- **Motion system** (`Shared/BotFace.swift`): `BotFace.motion(time:seed:active:)` — 5 s blocks,
  routines hop / spin / wiggle / pulse / rest, only while `active`; idle bots blink+glance
  (`idleEyes`), with the TimelineView paused except during `eyesBusy` windows (¼ s poll).
  `BotAmbient.shared` (Observable): `gaze` from scrolls (transcript, chat list, Bots page →
  `scrolled(dy:)`, decays after 450 ms) and `tilt` from CoreMotion (`Vory/App/BotMotionSource.swift`,
  attitude relative to a drifting rest hold, 30 Hz, started/stopped with the scene phase).
  Settings › Bots "Motion effects" (`bots.motion`). Reduce Motion disables body motion and tilt.
- **Bots page**: 2-column `BotCard`s (bot floating over a glass name/model pill), `RoomCard`s for
  group chats; room creation removed from here ("Group rooms" → "Group chats").
- **Compose** (`Vory/Chat/NewChatSheet.swift`): Messages-style — To: chips + search, matching bots
  as rows, first message at the bottom. One bot → `ChatRoute(profile:initialText:)` (ConversationView
  sends it once the chat exists, `sentInitial`); several → `GroupChats.create` (groups.create) →
  `RoomRoute(room:initialText:)` → `RoomView(initialText:)` sends it. The Chats list shows a
  "Group chats" section (groups.list in `load()`); the mock gateway lacks `groups.send`.
- **Chats filters** (funnel, top right): pinned / needs you / working now / archived, sort recent /
  title / bot / model; `@AppStorage("chats.filter.*", "chats.sort")`, applied in `filtered(_:runtime:)`.
- Cron Jobs → Scheduled Tasks (tab "Tasks", symbol calendar.badge.clock); Settings › Profile picker
  shows the bots' pictures (`.id` on the look raws to redraw); chat profile page has the four
  display toggles; Gateways row text on one line; gateway icon = Vory cloud tile (`GatewayTile`).

### 2026-09-26 (builds 31–39)
- 39: icon: the Cloud layer has a `fill-specializations` entry for `dark` (2-stop lighter
  gradient; validated by ictool AND the Xcode build); layers at `scale 1.21`, `translation-in-points
  [0, -20]`. Composer: placeholder "Type / for commands"; a bare "/" lists EVERY command from
  `commands.catalog` (sorted) in a ScrollView capped at 30 % of the screen height (max 280 pt) so
  it never reaches the header; typing narrows it; tapping inserts "/name ". Dispatch was already
  there (`ChatSession.dispatchSlash`). Sim note: the composer sits ~13 pt under the keyboard's
  predictive bar on the simulator — pre-existing, not seen on the phone.
- 39 (cont.): **transcript bottom lock** (`TranscriptView`): `stickToBottom` is released only by the
  user's own drag (`onScrollPhaseChange` → `userScrolling`, and > 24 pt from the end), re-locked
  by the jump button or by scrolling back within 4 pt of the end; following scrolls are
  unanimated (animated ones lagged the stream and the old > 120 pt test unlocked by itself).
  `BotFaceView` has `.id(spec)` (a paused TimelineView did not redraw a bot switched to glass).
  Glass eyes: `.clear.tint(ink 92 %)` live, ink 90 % painted. `TranscriptItem.Kind.steer(text:
  status:)` — grey right-aligned bubble with a "Steered · queued" caption (cache saves it as a
  user row; the watch draws a grey box). `willPresent` returns `[]` unless `hermes.kind == "test"`.
  `glassEffectID("dock")` moved from the whole ComposerView onto the text capsule (the stack's
  shape changes while typing during a run — the steer strip — and the bubble broke).
- 38: icon cloud 10 % larger.
- 37: **Settings › Bots** (`BotsSettingsView`, App section): "Liquid Glass for all bots" (BETA),
  `bots.glassAll` in UserDefaults (`BotAvatarStore.glassAllKey`). `BotAvatarStore.effective(raw)`
  applies it to any studio choice; `BotAvatar`, `BotAvatarStore.choice(for:)` and the keychain mirror
  (`BotLooksMirror`, now @MainActor; bakes the setting in for every gateway profile so the
  extensions match) all go through it. The studio's own switch stays per bot; with the global on
  it shows on, disabled, captioned "On for every bot in Settings › Bots." The page also lists the
  bots with a sparkle on the glass ones.
- 36: **Liquid Glass bots (beta)**: `BotLookSpec.finish` ("flat"|"glass"), stored as a fourth part
  of the choice string (`studio:<shape>:<eyes>:glass`); `BotAvatarChoice.studio(shape:eyes:glass:)`;
  a Toggle at the bottom of the Creator Studio. In the app (`BotFace.liveGlass = true`, set in
  `VoryApp.init`) `BotFaceView` draws the body as `glassEffect(.regular.tint(colour 72 %))` in
  `BotBodyShape` and the eyes as `glassEffect(.clear.tint(ink 70 %))` in `BotEyesShape`, each in its
  OWN GlassEffectContainer (one container would union them); sleepy lids stay painted. Everywhere
  glass cannot render (widgets, NSE images, menu icons via `drawn: true`) `BotFace.drawGlassBody`
  paints an approximation (translucent tint, lit rim, dark underside, top specular). The Vory
  mascot (`AboutView.voryBot`) is glass, matching the icon. `BotAvatarImage.make` now renders the
  real bot (painted) for the Chats profile menu instead of a letter. Bots tab icon 1.5×/1.28× of the
  slot's icon size. Lists get `reservedHeight + 16` bottom margin.
- 35: **new app icon** — the Vory cloud as layered Liquid Glass (`Shared/AppIcon.icon`): cloud in the
  brand cyan→navy gradient (glass, 72 % translucent, max refraction), classic eyes in front (glass,
  65 % translucent, dark), white tile in light mode, near-black in dark. Chosen by the user from ~20
  rendered variants (a V-shaped mark is gone; the app's face is the cloud). Lessons: `groups` are
  listed FRONT to back; dark details as glass must be listed in front or they vanish; Icon Composer
  ignores SVG clip-paths (rasterise to PNG for clipped layers); glass only reads as glass with
  something behind it. Generator scripts were in the session scratchpad (`icon/gen*.py`,
  `sheet.swift` contact sheet, `streak.swift` clipped streak) — not kept in the repo.
- 34: capsule 56 pt (reserved 43 + 13 overhang), icons 25/21 pt; while dragged the lens moves ABOVE
  the icons (zIndex) and a second copy of the icon row rides on top of it, masked to the lens minus
  a 4 pt rim, so the icon inside stays crisp and only the rim refracts — the system bar draws its
  icons twice for the same reason (two sets of _UITabButton in the dump). Plain `.clear` glass over
  the icons smears them into a blur.
- 32: icon-only tabs (27 pt) with the label only under the selected one (22 pt icon + 10 pt label);
  the selection is a clear glass lens (`.glassEffect(.clear.interactive())` in its own
  GlassEffectContainer, drawn UNDER the icons — on top it blurred them); compose circle 62 pt = bar
  height; 33: the glyph is centred on its SQUARE (offset 0, −2.5), which the user judged by eye
  against Messages — ink-centred (−1, +1) read too low. Measure from a simulator screenshot
  (scratch script: white pixels vs the circle's bounds), not from the symbol's own box; the bar reserves 49 pt
  (`VoryTabBar.reservedHeight`) and the capsule overflows 13 pt into the home area. Lists inside
  the pages' NavigationStacks do NOT honour the ZStack's `safeAreaInset` on iOS 27, so `MainTabView`
  also sets `.contentMargins(.bottom, 49, for: .scrollContent)` while the bar is shown.
- 31: tab bar to the native measurements (equal slots, labels on every tab, lower and taller),
  press-and-hold drag of the selection pill, Settings (+ Config/Env/MCP/Skills) search under the
  title (`.navigationBarDrawer(displayMode: .always)`; iOS 27 then forces the title inline — the
  `.automatic` mode keeps the large title but hides the search until pulled), no gap under the
  Chats search (`.contentMargins(.top, 0, for: .scrollContent)`). The `testflight.sh` upload is
  denied by the permission classifier unless the user asks to deploy in so many words.

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
