# Reddit — post

**Video:** `vory-promo-4x5.mp4` (1080×1350; tall enough to fill the mobile feed without the top and
bottom being cropped, and it reads well on desktop).
Alternate for subreddits that prefer landscape: `vory-promo-16x9.mp4`.
**Thumbnail:** `vory-promo-4x5-poster.png` (Reddit picks its own from the video; upload this if it
asks).

Suggested homes: r/selfhosted, r/LocalLLaMA, r/iOSProgramming, r/SideProject, and any Hermes
community. Read each subreddit's rules on self‑promotion first; some want a "[Project]" or
"[Beta]" tag.

---

**Title (pick one):**

- I built an iPhone remote for a self‑hosted Hermes agent gateway. Your agents as characters you can talk to. Public beta on TestFlight.
- Vory: talk to your self‑hosted agents like people in Messages, and approve their commands from your Lock Screen (iOS, public beta)

**Body:**

Vory is a native iOS app that connects to a Hermes agent gateway you run and turns every profile into a bot: a small living character with a body, eyes and a colour, drawn in Liquid Glass.

What it does:

- **Chats like Messages.** Streamed replies with live token counts, reasoning you can unfold, tool calls as cards, attachments, "/" commands, steering a bot mid‑reply, dictation.
- **Approve from your pocket.** When a bot wants to run a shell command or change a file, the approval card lands in the chat, in a notification, and in the Live Activity on the Lock Screen and Dynamic Island. Once, for the session, always, or deny.
- **You can read what it's doing off the face.** Thinking, using a tool, waiting for you, error, reconnecting. Each has its own held pose.
- **Group chats.** Two to six bots in one room, talking to you and to each other.
- **The whole gateway from the phone.** Model, config, API keys, tools, skills, MCP servers, approvals policy, scheduled tasks, sessions, channels, health, logs, restarts, updates.
- **Yours.** Talks to your gateway over LAN, Tailscale or a Cloudflare Tunnel. No account, no middleman cloud. Chat summaries are made on‑device with Apple Intelligence.

Requirements: an iPhone on iOS 27, TestFlight, and a Hermes gateway you run. Not on the App Store yet; iPhone only for now.

Site and TestFlight link: https://vory.dev
Source: https://github.com/matt0975/vory (SwiftUI, Swift 6; the bots are drawn from code in `Shared/BotFace.swift`; the push companion and relay are in `server/`)

Happy to answer questions about the bot motion system (everything is drawn from code, nothing is a sprite) or the approval flow.
