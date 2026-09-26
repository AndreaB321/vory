---
name: vory-feedback-backlog
description: Open TestFlight feedback items for Vory still to do after the 2026-09-23/24 Live Activity + push-setup work
metadata:
  node_type: memory
  type: project
  originSessionId: 6f579f10-c86e-4879-b1e8-857a212b563d
  modified: 2026-09-24T05:27:57.518Z
---

Remaining items from the 2026-09-23 TestFlight feedback pull (22 notes on build 2609230353),
after the Live Activity / background-push / setup-wizard work shipped on 2026-09-24. Numbers are
the ones used in that session's list.

**Bugs**
- #3 Pinned chats disappear when pinned; can't be found.
- #5 Some chats open blank until you scroll; must load faster and reliably.
- #6 Apple Watch: scroll-to-bottom leaves the message box too high / too much blank space.
- (new) iPhone chat: extra empty space under the last message when a chat opens (not reproduced on the
  simulator; ask whether it was opened from a notification / after the keyboard was up).
- (older) Mic button crash on tap / on allowing access (builds 2609222212, 2609222259) — not re-reported since.
- (2026-09-25) Chat shows "Reconnected, but the session could not be re-attached: session not found" after a
  socket reconnect (seen on a cron/defender session); the banner also shoved the composer (animated in build 26).

**Layout**
- #7 Profile picker laid out wrong.
- #8 A menu item's title padding.
- #9 Avatar/character icons: hard cut-offs at the ends; bots too close to the edge (per-style zoom was
  added in AnimatedAvatar 2026-09-24 — verify on device).
- #10 Refresh icon shows inside the search bar.
- #11 Message button moves back up too early — build 26 drives it from the real tab bar frame (TabBarMinimizeObserver); verify.
- #12 Swipe-back should trigger from further out (left→right from mid-screen).

**Animation / avatars**
- #13 Bot animates everywhere while working (Chats page too), still when idle.
- #14 Animate the "…" thinking indicator.
- #15 Active bot's avatar in the menu item screenshotted (no animation there).
- #16 Setting to choose the animation style (spin, bounce…).

**Features**
- #17 Stop button becomes a grey Send while typing during a turn (queue or interrupt/steer); red Stop when empty.
- #18 Replies styled like iMessage reply interface (user's second screenshot).
- #20 Notifications on/off toggle.
- #21 Status screen in plain language: green/red status, tappable rows, version kept.
- #22 Plugins section listing Vory + other installed plugins (Vory plugin status/update/reinstall/uninstall is
  done on the Background Notifications page; the general plugins list is not).
- #23 @mention bot picker in the composer.

**Done in that session:** #1/#2/#4/#19 (Live Activity start/end/alerts, bot name + labelled bar, no duplicate
banners), setup wizard, Background Notifications page, companion self-update, relay hold-for-an-hour.

**How to apply:** work through these one at a time with the user, USB-install to verify, then TestFlight.
See [[hermes-remote-ios-project]] for build/install commands.
