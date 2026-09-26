---
name: hermes-remote-ios-project
description: "HermesRemote iOS app (SwiftUI, iOS 27) built in ~/claude-sandbox/Vory; how it was verified and local Hermes/simulator quirks"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1dc8a15b-467b-4467-8278-3551756426ec
  modified: 2026-09-22T06:37:29.088Z
---

HermesRemote (generic iOS remote for a self-hosted Hermes Agent dashboard) lives at
`~/claude-sandbox/Vory` (Xcode project, hand-written pbxproj with synchronized folders;
targets: app, HermesLiveActivity widget, unit tests, UI tests). Built 2026-09-22.

**Why:** the user asked for a one-pass, stock-Apple, no-hardcoded-server client; protocol facts were
taken from the local Hermes source at `~/.hermes/hermes-agent` (tui_gateway/contracts/*.py is the
JSON-RPC source of truth; hermes_cli/web_routers/*.py for REST).

**How to apply:** rebuild with
`xcodebuild -project HermesRemote.xcodeproj -scheme HermesRemote -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
For real e2e tests run `~/.local/bin/hermes serve --skip-build --port 9119` with
`HERMES_DASHBOARD_SESSION_TOKEN` set, then inject `HERMES_E2E_URL/TOKEN` via
`xcrun simctl spawn <udid> launchctl setenv` (TEST_RUNNER_ vars do not reach the app-hosted tests).
The local Hermes install has no AI provider configured, so turns error with "not connected to any AI
provider"; the simulator "Hermes iPad Check" is not granted to Claude's simulator panel, use
`xcrun simctl io <udid> screenshot` instead. See [[hermes-agent-local-install]].

**Update 2026-09-23:** the app is now "Vory" (bundle `com.vorantx.vory`, TestFlight via
`Tools/release/testflight.sh`, App Store Connect API key in `Tools/release/.env`). Core code lives in
`Packages/VoryCore` (SwiftPM, iOS/macOS/watchOS); the iOS app links it as a local package. Platform
hooks: `TurnActivityReporting`, `CardNotifying`, `PushRegistrationSyncing` in `Runtime/Hooks.swift`.
Check another platform with `cd Packages/VoryCore && xcodebuild -scheme VoryCore -destination
'generic/platform=macOS' build`. macOS has no `timeout` binary — background + kill instead. The
user paused before the Mac / Watch / widget phase; next steps agreed: APNs key + `hermes-push`
companion running, then widgets/complications, Mac app, Watch app.

**Watch (2026-09-23):** targets `VoryWatch` + `VoryWatchComplications` are hand-written in the pbxproj
(product type application with SDKROOT watchos, embedded via "Embed Watch Content" dstSubfolderSpec 16).
No watch simulator existed: create one with a device type from the runtime's `supportedDeviceTypes`
(`xcrun simctl list runtimes -j`; e.g. Apple-Watch-Ultra-3-49mm on watchOS 27). Build the `VoryWatch` scheme
signed for the watch sim, install with `simctl install`, launch with `SIMCTL_CHILD_VORY_E2E_URL/TOKEN` env
(DEBUG-only seed) to point at the mock gateway. The iOS Simulator MCP cannot tap a watch sim.

**Push architecture (2026-09-23):** users never touch APNs. Developer runs `server/push-relay`
(Cloudflare Worker, holds the .p8; needs `wrangler deploy` on his CF account, then
`VORY_PUSH_RELAY_URL` in Tools/release/.env). App mints install id + secret + AES key
(`PushRelay` in VoryCore, shared Keychain group), `hermes-push` encrypts (AES-GCM) and posts to
the relay, `VoryNotificationService` NSE decrypts. The companion can be installed as a Hermes
plugin (`<HERMES_HOME>/plugins/vory-push`, enabled via `/api/dashboard/agent-plugins/<name>/enable`,
loads on gateway restart). Bundle ids/profiles exist for watchkitapp, watchkitapp.complications,
notifications (all App Store profiles installed locally under ~/Library/Developer/Xcode/UserData/Provisioning Profiles).

**Round-six learnings (2026-09-23):** REST `GET /api/sessions/{id}/messages` returns raw stored rows
(`content` string or parts list, integer `id`, ISO `timestamp`, tool name under `tool_calls`) whereas the
WebSocket `session.resume` history is flattened to `text`/`row_id`; `TranscriptMessage` decodes both.
Hermes native auth: "password" is an auth *mode*, the provider name comes from `/api/auth/providers`
(`supports_password`) or `GatewaySecrets.provider` — passing "password" as the provider gives HTTP 404.
The mock gateway (websockets `process_request`) cannot read request bodies, so PATCH/PUT with JSON
bodies fail against it. `ictool` renders Icon Composer docs headlessly (see [[icon-composer-cli]]).
Chats now open from a per-session transcript cache (`TranscriptCache`, Caches/transcripts) while
`session.resume` runs; `openChat(waitForResume:)` keeps the blocking contract for the watch proxy.
TestFlight "What to Test" notes: the user wants a blank line between entries.

**Push companion learnings (2026-09-23 evening):** the `vory-push` plugin runs in the *gateway* process
(`hermes gateway` calls `discover_plugins()` at startup); `hermes serve` only loads plugins lazily, so an
in-process loopback shortcut (`inprocess_dashboard()` in hermes_push.py) is opportunistic, not the fix.
The companion writes a heartbeat to `<home>/push/status.json` every poll (version, connected, transport,
error) and the app's Background push screen reads it plus `plugins/vory-push/plugin.yaml` via
`GET /api/files/read`. Hermes never answers 403 on its auth paths, so a 403 from the public URL is
Cloudflare Access refusing the companion (no service token); the robust setup is the loopback dashboard
URL + "Sign in for the companion" (bearer). `relay.lock` (flock) keeps only one relay per machine.
TestFlight feedback is pulled with the ASC API (`betaFeedbackScreenshotSubmissions`, no `limit` param,
use `-g` with curl for bracketed query keys); JWT minted with a small Swift/CryptoKit script.
A stale `mock_gateway.py --port 9119` (pid 42123) from an older session may still hold 9119.

**USB device builds (2026-09-23):** install with
`xcodebuild -scheme HermesRemote -configuration Debug -destination 'id=00008150-001069912108401C' -derivedDataPath build/device -allowProvisioningUpdates -authenticationKey{Path,ID,IssuerID} <ASC vars> VORY_PUSH_RELAY_URL="$VORY_PUSH_RELAY_URL" build`
then `xcrun devicectl device install app --device <udid> …/Debug-iphoneos/HermesRemote.app` and
`devicectl device process launch … com.vorantx.vory`. **Always pass VORY_PUSH_RELAY_URL** (from
Tools/release/.env) — without it PushRelay.isConfigured is false, the "Upload to gateway" button is
disabled (wants a .p8) and relay registration is skipped. Bump the companion VERSION + plugin.yaml on
every companion change; the heartbeat also carries `script_sha256` so the app can tell "reinstalled
but not restarted" apart.

**Renamed 2026-09-23 (late):** the project folder is now `~/claude-sandbox/Vory` with `Vory.xcodeproj`,
scheme `Vory`, app folder `Vory/`, tests `VoryTests` / `VoryUITests`, product `Vory.app` (bundle id
unchanged). Build/install commands use `-project Vory.xcodeproj -scheme Vory` and
`build/device/Build/Products/Debug-iphoneos/Vory.app`. Live Activity lifecycle is logged in
`LiveActivityController.log` and shown on Settings › Notifications › Background Notifications.

**Live Activity on Debug/USB builds (2026-09-24):** Xcode's Debug "debug dylib" split
(ENABLE_DEBUG_DYLIB) turns the widget extension into a stub that iOS cannot spawn on a device
("Bad executable", extensionKit error 2) — every activity is dismissed within a second of creation while
TestFlight (Release) works. `ENABLE_DEBUG_DYLIB = NO` is now set in every Debug config. Diagnose device
issues with `idevicesyslog -u <udid> -p Vory -p chronod -p liveactivitiesd` (libimobiledevice via brew);
the simulator MCP can tap the "Hermes iPhone" sim (1C5C2D80…). GitHub: private repo matt0975/vory.

**Where things stand (2026-09-25 ~21:40):** Latest build 1.0.1 (30), companion 1.0.25. FULL HANDOFF for the
next agent: `docs/HANDOFF.md` in the repo (build/ship recipes, secrets locations, architecture map, change
log, gotchas) — read it first. Bots are drawn
by `Shared/BotFace.swift` (BotLookSpec shape/eyes/hex; "studio:<shape>:<eyes>" avatar choice; legacy
"animated:<style>" and "initial" map onto shapes; the bot itself is the icon, no disc). Creator Studio
(`CreatorStudio` in BotAvatars.swift) on the profile page. Chat header: bot above the name pill, springs in.
Swipe back from anywhere (InteractivePopEnabler full-screen pan via the pop gesture's "targets"). Settings:
Software Update page (`SoftwareUpdateView`, companion update card + red badge on the tab and that row), a
one-time "Set up notifications" card (`notificationsSetupCardDone`) opening `SetupWizardHost`, About with
the Vory cloud (5 taps → RainOverlay 10 s) and installed versions; Background Notifications shows only two
check marks (`CompanionStatusChecks`). Reply window: earlier exchanges on a sideways page (TabView .page) —
vertical drags inside a content extension belong to the system's pull-to-dismiss in SpringBoard's process,
gesture delegates cannot block it; reply capped at 9 lines, pane 34% of the screen. Companion finishes the
LA first, thread fetch capped 1.5 s. Simulator: if the content extension launch fails with RunningBoard
"Client not authorized" after a reinstall, shut down + boot the simulator.
Build 25 adds: eyes glance as a pair (gaze param on BotFaceView, About's cloud looks down while it rains
5 s), triangle drawn larger/lower, clipped-gradient highlight (no seams on the cloud), borderless studio
buttons (List row-tap quirk fired "Reset to default"), Bots page "Profile" row → ProfileCardView, chat
header bot → ProfileCardView in a medium sheet with SOUL editor at the bottom, compose buttons as
`ToolbarItem(placement: .bottomBar)` (move with the tab bar's own minimize), Appearance "Chat header
shows" (ChatStyle.headerShowsTitle), notification replies: `AppModel.shared` created before any scene +
ensureConnection activates the saved gateway, waits for the socket, holds a background task (a reply that
launched the app in the background previously found no model). Reply pane capped at 29% with 6-line reply.
Build 25 verified by the user: bots look right, notification replies reach the bot and the answer comes
back. Build 26: compose button driven by `TabBarMinimizeObserver` (CADisplayLink probe reads the narrowest
"*TabBar*" view's width; `ToolbarItem(.bottomBar)` sat BEHIND the tab bar, do not use it), About cloud
lifts → rains 5 s → settles → "Ahhhh…that's better." bubble, reply pages top-aligned, composer banner
animated. Build 26 verdict: About worked but the cloud clipped/rain too tall/bubble had no tail; the floating compose
still lagged. Build 27: compose is `Tab(role: .search)` (iOS draws it as the detached circle right of the
bar, Messages' layout) with `.tabBarMinimizeBehavior(.never)`; selecting it sets `newChatRequest` and
snaps back (`AppTab.compose`; bots page sets `composeProfile`). TabBarMinimizeObserver is unused now.
Reply window: UIKit UITapGestureRecognizer on the controller view flips pages via `ReplyPager`
(ObservableObject; SwiftUI Button taps are NOT delivered inside the platter); pane height = showing page;
BubbleShape tails are small curls. Build 27 verdict: `Tab(role: .search)` was NOT drawn detached and not tappable on iOS 27 — do not use it.
Build 28: compose is the floating glass circle fixed above the tab bar's right end (`.tabBarMinimizeBehavior
(.never)`, overlay bottomTrailing, no offset); About bubble centred above the cloud with a down tail; the
reply window is ONE card (bot, chat, time, bubble; no thread pages, no pager, no tap gesture — the
companion still sends `hermes.thread`, unused). Build 29: BubbleShape / SpeechBubbleShape square the corner under the tail so the curl is one piece.
`Tab(role: .search)` verified on the simulator with BOTH `.tabBarMinimizeBehavior(.never)` and
`.onScrollDown`: iOS 27 draws it INLINE as a fifth tab (tap does work). Compose stays the floating circle.
Simulator app past onboarding: build WITH signing (no CODE_SIGNING_ALLOWED=NO, derivedData build/simsigned),
run `Tools/mock-gateway/mock_gateway.py --port 9119 --token mock-token`, `simctl spawn <udid> launchctl setenv
HERMES_E2E_URL http://127.0.0.1:9119` + `HERMES_E2E_TOKEN mock-token`, uninstall + install + launch → lands on
Chats with mock sessions. Build 30: the system TabView is GONE. `MainTabView` = ZStack of pages (opacity/hit-testing by selection)
+ `.safeAreaInset(.bottom)` with `VoryTabBar` (Vory/App/VoryTabBar.swift: glass capsule, icon-only tabs,
label + sliding pill on the selected one, detached compose circle; badges drawn there). Hidden via
`AppModel.chatsPathOpen` (Chats path, instant) and `tabBarHiders` (`.hidesTabBar()` on ConversationView
and PushSetupView; only counts off the Chats tab). Compose → `newChatRequest`; ChatListView handles on
Chats, BotDetailView (`composing` navigationDestination) when its `composeProfile` is set. Bots icon =
`VoryOutlineIcon` (cloud filled then inner cloud punched with .destinationOut, tilted −10°). Chats search
must use `.navigationBarDrawer(displayMode: .always)` or iOS docks it at the bottom over our bar. Verified
on the mock-gateway simulator. Untested by the user yet: build 30. Next: the user's verdict, then
[[vory-feedback-backlog]].

**Release tooling gotchas (2026-09-24):**
- ASC API `bundleIds?filter[identifier]=x` is a PREFIX match: `data[0]` for `com.vorantx.vory` was the
  LiveActivity App ID. Always map exact identifier → id from `bundleIds?limit=200`. App IDs: app
  U4NQCTQ9BB, LiveActivity 782XTY4C7G, notifications T65FW8D9U5, notificationcontent ZBC5D75JZF,
  watchkitapp JL6S5UT9X8, complications CCL328DN67.
- App Store profiles are created via the API (profiles POST, IOS_APP_STORE, cert H37X3HCYJ9) and written
  to ~/Library/Developer/Xcode/UserData/Provisioning Profiles; ExportOptions maps names → bundle ids.
  Regenerate a profile after any capability change. The Communication Notifications capability is not in
  the API's enum; Xcode's automatic signing during `xcodebuild archive -allowProvisioningUpdates`
  registered it (record U4NQCTQ9BB_USERNOTIFICATIONS_COMMUNICATION), then the API profile picked it up.
- Automatic-signing EXPORT always fails ("Cloud signing permission error") with this API key; keep manual.
- PlistBuddy treats dots in keys as path separators: check entitlements with `codesign -d --entitlements :-`.
- Never kill a running testflight.sh: altool may have already delivered the build (build 20 slipped out that
  way); check the log for 'No errors uploading' first, and re-upload with BUILD_NUMBER=<n+1> if it did.
- Simulator notification testing: build with CODE_SIGNING_ALLOWED=NO, launch with
  `-vory-request-notifications` (DEBUG flag asks permission), tap Allow, `xcrun simctl push <udid>
  scratchpad/turn.apns`, then long-press the banner within ~2 s (simulator MCP tap with duration 1.2);
  in-app banners do not expand. Extension crash reports land in ~/Library/Logs/DiagnosticReports.
**Versioning plan (user, 2026-09-24):** build numbers are small iteration numbers (13, 14, …), not
date-style. Marketing version is 1.0.1 now (1.0 with a small build number sorted under "previous
builds" in TestFlight below the date-numbered ones, so the user moved on); later 1.2, 1.3…; 2.0 is the
real App Store release. `Tools/release/testflight.sh` reads the existing builds from App Store Connect
(token from `Tools/release/asc-jwt.swift`) and uses max small number + 1; override with
`BUILD_NUMBER=<n>`. App Store Connect app id 6814980297. Escape `[`/`]` in API URLs as %5B/%5D (zsh).
App Store Connect did accept 1.0 (12) after 2609240140, so a lower build number within a version is
not refused for TestFlight.
Next: continue with [[vory-feedback-backlog]].
