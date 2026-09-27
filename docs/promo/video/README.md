# Vory promo video — "Your agents, in your pocket."

A 24‑second motion‑graphics announcement for the public beta, rendered from code. Vory (the blue
glass cloud) introduces itself, shows what Vory is, how a turn works (ask → thinks → tools →
waits for your yes → done) and where to get it. Every bot on screen is drawn by
`scene/vory-bot.js`, the same port of `Shared/BotFace.swift` the website runs, so the blinks,
glances, coin‑turns and state holds are the app's own. Nothing scales, bounces, hops or pops; the
camera, type and cards do the moving.

## Deliverables (`out/`)

| File | What |
|---|---|
| `vory-promo-9x16.mp4` | Master, 1080×1920, 60 fps, H.264 CRF 17, AAC 192k. For X and Reddit mobile. |
| `vory-promo-9x16-30fps.mp4` | Same, 30 fps, lighter upload. |
| `vory-promo-9x16-prores.mov` | ProRes 422 HQ + PCM. Not committed (size); regenerate with the render script. |
| `vory-promo-16x9.*`, `vory-promo-1x1.*` | The same film re‑laid‑out for 1920×1080 and 1080×1080 (not crops). |
| `*-poster.png` | Poster frame (t = 2.9 s, "Hi, I'm Vory."). |
| `*-contact-sheet.png` | One frame per second, 6×4. |
| `storyboard-*.png`, `stills-*/` | Storyboard stills, one per beat. |
| `music.wav` | The score + sound design, 48 kHz stereo, synthesized (no samples, no licences). |

Captions are burned in: Vory's typed bubbles and the big type carry the whole narration, so the
film reads muted (X autoplays muted).

## Shot list (9:16 master; the other aspects follow the same timecodes)

| Time | On screen | Vory / bots | Type | Camera & transitions | Sound |
|---|---|---|---|---|---|
| 0.0–1.9 | Extreme close‑up on Vory's eyes on a light glass field | Vory in its guide life: blink at 0.7 | — | Pull back (ease in‑out cubic, 1.9 s) to Vory on its shelf | Pad swells in, first plucks |
| 1.4–4.0 | Vory on its "Vory" shelf, bubble under it | Blink at 2.6, guide glance at the bubble, one rim sheen | Bubble types "Hi, I'm Vory." | Bubble rises 12 px + fades in | Typing ticks, blink tick |
| 4.0–8.0 | Headline over Vory | Guide life | "Your agents, / in your pocket." rises line by line (0.8 s, stagger 0.14) · bubble retypes "I'm the iPhone remote for your Hermes gateway." | Lines rise 60 px with expo‑out | Rise whoosh at 4.5 |
| 8.0–12.0 | Vory small at the top; the cast of five arrives on shelves below | Vory: layout tween to the top (0.9 s). Cast on named shelves: Pip (red glass circle), Juno (terracotta blob, curious eyes), Otto (amber triangle, bold eyes), Nova (white glass drop, wide eyes), Remy (purple glass hexagon); idle eyes only, staggered seeds. Circle does one full coin‑turn at 10.2. Triangle blinks 9.9, hexagon 11.2 | Bubble: "Every bot you run lives here." · "Every agent is a character." rises at 9.6 | Headline exits up at 7.9; cast rises 160 px staggered 0.12 s | Chord change at 8, pulse begins, whoosh + glass ping on the coin‑turn |
| 12.0–16.0 | Chat: user bubble, the teal drop bot on its "work" shelf, tool card | Vory exits left (0.5 s). Drop: thinking at 13.0 (pebble morph, 0.55 s, squint), using a tool at 14.2 (stem grows, eyes glance down‑right, one lean), tool card ticks green at 15.4, streaming at 15.5 (squint + rim sheen) | "It thinks." (13.1) → "It uses its tools." (14.4) | Bubble rises at 12.4, bot at 12.6, card at 14.45, card exits 16.05 | Chord change at 12, low morph tones at 13.0 / 14.2 |
| 16.0–20.0 | Approval card; the bot becomes "!" | awaitingApproval at 16.1: bold "!", +8° lean, nudge every 2.8 s. Tap ring on "Once" at 17.9; card turns green "Approved once"; bot back to working at 18.15; finish coin‑turn at 18.6; idle at 19.4 | "And it waits for your yes." (16.5) → "Approve from your pocket." (19.0). Reply bubble "Done — 4.2 GB freed." at 19.0 | Card rises at 16.2; everything exits at 19.95 | Chord change at 16, morph tone 16.1, tap 17.9, whoosh + ping on the turn, success chime 18.9 |
| 20.0–24.0 | End card | Vory returns from the left (0.8 s) to centre on its shelf; blink 22.4; tiny nod 22.9 | Bubble types "Your agents, in your pocket." (20.6); "vory.dev" (20.9); "Public beta · TestFlight coming soon" (21.25) | Rises with expo‑out; hold | Chord resolves at 20, closing ping at 22.6, fade from 23 |

Rules honoured on every frame: bots yaw (the coin‑turn), roll a few degrees, shift ≤ 2 %, blink,
glance and light their rim; state holds morph in place on the same silhouette; nothing scales,
bounces or pops; every entrance is a layout move with an expo‑out ease and no overshoot.

## Pipeline

```
scene/index.html + scene/scene.js   the film as a pure function seek(t) on a 2D canvas
scene/vory-bot.js                   the bot renderer (copy of the site's; keep them in sync)
scene/fonts/SFNSRounded.ttf         the system rounded face for headlines (not committed; copy from /System/Library/Fonts)
cues.json                           timings shared by the scene and the score
tools/music.mjs                     synthesizes out/music.wav (120 BPM, Cmaj7 · Am7 · Fmaj7 · G6 · Cmaj7)
tools/render.mjs                    Playwright/Chromium renders every frame, ffmpeg encodes
```

```bash
cd docs/promo/video
npm i                                     # playwright (browsers: npx playwright install chromium)
cp /System/Library/Fonts/SFNSRounded.ttf scene/fonts/
node tools/music.mjs out/music.wav
node tools/render.mjs 916 stills          # storyboard stills only
node tools/render.mjs 916 169 11          # full renders; frames go to ./frames (or $FRAMES_DIR)
```

Preview any frame in a browser: serve the folder (`python3 -m http.server 8767 --directory .`) and
open `/scene/index.html?aspect=916&t=17.2`.

Render specs: 60 fps, 1440 frames per aspect, PNG frames → libx264 (CRF 17, yuv420p, faststart)
and prores_ks profile 3 (yuv422p10le). Audio 48 kHz. A full aspect renders in about three minutes
on this Mac.

## Risks and what I'd do with more time

- **Real Liquid Glass.** The bots use the app's painted glass (the Live Activity's look), not live
  refraction. A macOS SwiftUI window of `BotFaceView` recorded with `screencapture -v` would give
  true glass for the hero close‑ups; composite those over the same frames.
- **Sound.** The score is synthesized in code and deliberately sparse. A day with a real
  instrument library (or a licensed track) would lift it; the cue sheet is already timed.
- **Voice.** A short voiceover reading Vory's bubbles would help the sound‑on crowd; the bubbles
  stay as captions either way.
- **Second pass on timing.** Each beat is four seconds; a cut‑down 15 s version (drop the cast
  beat, shorten the chat) would suit X's attention curve better as a second asset.
- **Reduce Motion variant.** For the site hero, a still‑body version is trivial (the renderer has
  the switch); not rendered here.
- **Real device footage.** The chats‑list and Bots‑tab screenshots from the simulator could appear
  in a phone frame during the "remote" line; left out to keep the film fully vector and crisp.
