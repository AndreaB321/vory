---
name: vory-ui-tests-need-signing
description: "Vory/HermesRemote UI + e2e tests must run WITHOUT CODE_SIGNING_ALLOWED=NO, and the mock gateway + simulator env setup they need"
metadata:
  node_type: memory
  type: project
  originSessionId: 1dc8a15b-467b-4467-8278-3551756426ec
  modified: 2026-09-23T02:02:02.552Z
---

For the Vory app (`~/claude-sandbox/HermesRemote`), the UI/e2e tests (`ChatShowcaseUITests`,
`GatewayIntegrationTests`) fail silently on the Add Gateway form when the simulator build is
unsigned: `xcodebuild test … CODE_SIGNING_ALLOWED=NO` makes every Keychain write fail, so Save
never persists the gateway and the app stays on onboarding ("chats.new" never appears).

**Why:** Keychain on the simulator requires a signed (ad-hoc is fine) bundle. Pure unit tests
don't care, which is why `-only-testing:HermesRemoteTests` passes either way.

**How to apply:** build/unit-test with `CODE_SIGNING_ALLOWED=NO` if you like, but run UI tests
without it. Before UI tests: start `Tools/mock-gateway/mock_gateway.py --port 9119 --token
mock-token` (venv python at `~/.hermes/hermes-agent/venv/bin/python`), then on the booted sim
`xcrun simctl spawn <udid> launchctl setenv HERMES_E2E_URL http://127.0.0.1:9119` and
`HERMES_E2E_TOKEN mock-token`; a `simctl shutdown`/`boot` cycle is needed if `launchctl` says
"device is not booted" after an xcodebuild run used a clone. SwiftUI List rows below the fold do
not exist to XCUITest until scrolled — scroll while waiting. Screenshots land in the runner's
temp dir; the log prints `CHAT-SHOT <path>`. Sim used: HermesPhone
`46A9CF48-63F7-4C9B-814C-DF7D175FB208`. See [[hermes-remote-ios-project]].
