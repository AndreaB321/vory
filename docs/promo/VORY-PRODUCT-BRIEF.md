# Vory — product brief for promo work

Everything a designer or writer needs to talk about Vory without the source code. Written for
public beta: no names of any real gateway, bot, host or person. Say "your gateway", "your bots".

## One line

**Vory is the iPhone remote for your Hermes agent gateway.** Your self-hosted AI agents, in your
pocket, as characters you can talk to.

## What it is

Hermes is a self-hosted AI agent gateway: it runs "profiles" — independent AI agents, each with
its own model, tools, memory and personality — on a machine you own. Vory is the native iOS 27
app that connects to that gateway over its WebSocket API and makes each agent a **bot**: a small
living character with a body shape, eyes and a colour, drawn in Liquid Glass.

You chat with a bot like a person in Messages. It thinks, uses tools, asks you before doing
anything risky, and replies — while its face tells you what it is doing.

## How it works (the loop)

1. **Connect.** Point Vory at your gateway (local network, Tailscale, Cloudflare Tunnel, or any
   URL) and sign in with its token. A guided tour introduces the bots.
2. **Meet your bots.** Every profile on the gateway appears as a bot. Design it in the **Creator
   Studio**: 8 body shapes (circle, blob, square, pill, triangle, hexagon, cloud, drop), 8 eye
   styles (classic, tall, tiny, round, wide, curious, bold, sleepy), any colour, flat or
   **Liquid Glass** finish.
3. **Talk.** Messages-style chats: bubbles with tails, typing indicators (grey while the bot
   writes, dark with a badge while it runs a tool), streamed replies with live token counts,
   reasoning you can unfold, tool cards, attachments as cards, "/" commands, steer a bot
   mid-reply, dictation.
4. **Approve.** When a bot wants to run something that needs a yes — a shell command, a file
   change — an **approval card** appears in the chat, in a notification, and in the **Live
   Activity** on the Lock Screen / Dynamic Island, with Approve and Deny right there.
5. **Get told.** The **Vory Companion** — a small plugin installed on the gateway from the app —
   sends replies as notifications from the bot (with its face as the sender), keeps the Live
   Activity updated with the bot's phase (thinking / tools / writing / done, token count, context
   used), and delivers approval requests instantly. Reply from the notification; the answer
   comes back the same way.
6. **Group chats.** Put two to six bots in one room and let them talk to you and to each other.
7. **Run the gateway.** Settings for every profile: model, config, API keys, tools, skills, MCP
   servers, approvals policy, scheduled tasks (cron) with a form editor, sessions, channels,
   system health, logs, restarts and updates. Software Update installs and updates the
   Companion in place.
8. **Vory Summaries (beta).** Apple Intelligence, on-device, gives every chat a title and a
   two-line summary in the list. Nothing leaves the phone.

## The bots (the heart of the brand)

- A bot is `shape + eyes + colour + finish`. Everything is drawn from code; nothing is a sprite.
- **Idle life:** blinks every ~4 s (every third a double blink), a glance to one side every
  ~7 s, a rare slow blink. Eyes follow where you scroll. Optional: they lean with the phone's
  tilt.
- **Working:** every 3 s one small routine — the signature **coin-turn** (a 360° turn about the
  vertical axis, slow–fast–slow, 1.15 s), a glance-turn, a head tilt, a nod, a lean, a scan, a
  squint-and-settle, a light travelling the glass rim, a half-turn check.
- **States, each with its own held silhouette, morphed in place on the same piece of glass:**
  - *thinking* → a shorter, heavier pebble with narrowed eyes
  - *using a tool* → a small stem grows out of the top (a key)
  - *waiting for your approval* → the body becomes a bold rounded **"!"** and holds, leaning 8°,
    nudging toward you every few seconds
  - *error* → eyes drop and shut, a lean back, the light on the rim dies
  - *reconnecting* → the eyes sweep left–right like a metronome
  - *writing* → a squint and a light looping the rim every 2 s
  - *finished* → one full coin-turn, a blink edge-on, a glance down at the new bubble
- **Never** scales, bounces, hops or pops. Motion is a glance, a squint, a lean, a turn, a light
  on the rim. "If it looks like the bots are dancing, cut it. If it looks like one just had a
  thought, keep it."
- **Vory itself** is the mascot: a blue glass cloud (`#3B7BFF`; icon gradient
  `#3EC4EE → #1F86C6 → #0B2868`), classic eyes. It guides the tour and the setup, talks in a
  typed speech bubble, and squints while it checks for updates.

## Visual language

- iOS 27 **Liquid Glass**: translucent tinted plates that refract what is behind them, specular
  rims, contact shadows. Bots are glass; the tab bar is a glass capsule with a lens that
  refracts the icons as you drag it; the composer is a glass capsule.
- Light `#F2F2F7` and dark `#000000` pairs. Accent blue `#0A84FF` (system). Bubbles: blue
  (you) / `systemGray5` (bot). Approval amber `#F5A524`; error red; green `#30D158` for "done".
- Type: SF Pro (system). Rounded corners 18 pt bubbles, 22 pt typing bubble.
- Tabs: Chats · Bots · Files · Settings, plus a detached round compose button.
- App icon: the Vory cloud in layered glass on a white tile (dark: near-black tile).

## Benefits (say it plainly)

- Your agents run on **your** machine; Vory is the remote. No middleman cloud.
- **Approve from your pocket** — the agent waits for you, not the other way round.
- **Know what it's doing** at a glance: the face and the Live Activity say thinking / tools /
  writing / needs you.
- **Every agent is a character**, so a house of bots is a cast, not a list of sessions.
- Works over your LAN, Tailscale or Cloudflare Tunnel — no port-forwarding.
- Group chats put several agents in one room.
- Summaries stay on the phone (Apple Intelligence).

## Tone

Confident, warm, a little playful; never "AI hype". Short sentences. Talk to one person.

## Don'ts

- No real gateway names, hostnames, bot names, people or org names — this is public beta copy.
- No claims about features not listed here (no Android, no Mac app, no App Store yet — it is a
  TestFlight beta).
- Don't call Vory an "AI"; Vory is the remote and the mascot; the agents are the AI.
