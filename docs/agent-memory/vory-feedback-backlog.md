---
name: vory-feedback-backlog
description: Open TestFlight feedback items for Vory still to do as of 2026-09-25 (build 30), with what the Live Activity / push / studio / tab bar sessions already closed
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
- #10 Refresh icon shows inside the search bar.
- ~~#9 avatar cut-offs~~ superseded: Creator Studio bots (build 24+) are the icon itself, no discs.
- ~~#11 message button timing~~ superseded: build 30's own tab bar never minimizes; compose is a fixed circle.
- ~~#12 swipe-back from anywhere~~ done in build 24 (InteractivePopEnabler full-screen pan).

**Animation / avatars**
- #13 Bot animates everywhere while working (Chats page too), still when idle.
- #14 Animate the "…" thinking indicator.
- #15 Active bot's avatar in the menu item screenshotted (no animation there).
- #16 Setting to choose the animation style (spin, bounce…) — partly superseded by the Creator Studio
  (body/eyes/colour; eyes blink and glance). Ask whether a separate motion style is still wanted.

**Features**
- #17 Stop button becomes a grey Send while typing during a turn (queue or interrupt/steer); red Stop when empty.
- #18 Replies styled like iMessage reply interface — the NOTIFICATION reply window is done (builds 17–28:
  bot header + bubble, Reply field). The in-chat reply UI, if that was meant too, is not.
- #20 Notifications on/off toggle.
- #21 Status screen in plain language: green/red status, tappable rows, version kept.
- #22 Plugins section listing Vory + other installed plugins (Vory plugin status/update/reinstall/uninstall is
  done on the Background Notifications page; the general plugins list is not).
- #23 @mention bot picker in the composer.

**Done 2026-09-23/24 (first session):** #1/#2/#4/#19 (Live Activity start/end/alerts, bot name + labelled
bar, no duplicate banners), setup wizard, Background Notifications page, companion self-update, relay
hold-for-an-hour.

**Done 2026-09-24/25 (builds 11–30), all from the user's live feedback, not from the numbered list:**
Live Activity finish behaviour (no expand, 30 s Island + 60 s Lock Screen), phases (brain/bubble/wrench),
live tokens + context used/size, bot avatar in the Island; reply notification always follows, from the
right bot, as a communication notification with the bot's avatar; notification reply window (one card);
replying from a notification reaches the bot and the answer comes back; Creator Studio (shapes, eyes,
colours, animated eyes, no discs); Messages-style chat header (+ Appearance setting bot name / chat
title); swipe back from anywhere; Software Update page + red badges; first-run setup card; About with
the Vory cloud (rain easter egg) and installed versions; Background Notifications reduced to two checks;
Bots page Profile row; profile sheet opens on the studio (medium) with instructions at the bottom;
transcript follows the keyboard; reconnect banner animated; own tab bar with detached compose and the
Vory-cloud Bots icon; TestFlight build numbering (small numbers, 1.0.1) and release tooling.

**How to apply:** work through these one at a time with the user, USB-install to verify, then TestFlight.
See [[hermes-remote-ios-project]] for build/install commands.
