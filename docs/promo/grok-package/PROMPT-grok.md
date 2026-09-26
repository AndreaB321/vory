# Prompt for Grok — Vory promo video concept + website

Attach every file in this folder (the `assets/` images and video, `BotFace.swift`, the three
motion briefs and `VORY-PRODUCT-BRIEF.md`), then paste this:

---

You are a senior motion designer and product web designer. I'm giving you a complete package
for **Vory**, an iPhone app that is the remote for a self-hosted Hermes AI-agent gateway. Read
the attached files before you do anything:

- `VORY-PRODUCT-BRIEF.md` — what Vory is, how it works, the benefits, visual language, tone,
  and the public-beta rules (no real gateway/bot/person names; nothing invented).
- `bot-motion-brief.md`, `bot-motion-brief-2.md`, `bots-brief.md` — the bots' motion system
  and its hard locks (never scale, bounce, hop, bloom or pop; eyes near-black; the 360° coin-turn
  is the hero; the state holds: approval → rounded "!", thinking → pebble, tool → stem).
- `BotFace.swift` — the bots are drawn from code. `bodyPath` has the exact 8 body shapes,
  `eyePaths` the 8 eye styles, `BotFace.motion` every routine and state with its timing and
  easing. Reproduce the shapes and easing exactly in whatever you generate; do not redesign the
  characters.
- `assets/icon-Default.png`, `icon-Dark.png`, `icon-ClearLight.png` — the app icon: Vory, a
  blue glass cloud, in Liquid Glass.
- `assets/bot-motion-demo.mp4` and `bot-states-morph-strip.png` — every bot state, live, and a
  frame strip of the shapes morphing into their held silhouettes.
- `assets/screenshot-*.png` — the real app: chats list, a chat with typing bubble and tails, a
  group chat, an attachment card, the bots page with all shapes, the state grid.

Deliver two things, plan first:

## 1. A 15–30 second motion-graphics promo video (X and Reddit)

Treat it as your showreel. Vory — the blue glass cloud — is the star: it introduces itself,
shows what Vory is, how it works (connect → meet your bots → talk → approve from your pocket →
get told via notifications and the Live Activity) and why you'd want it. Craft over
everything: timing, easing, typography, rhythm, sound. Bots on screen obey the motion briefs;
camera, type and transitions around them can be as bold as you like.

Give me:
- Three concept directions in a paragraph each, then pick one and say why.
- A shot list with timecodes: for every shot, what's on screen, what Vory does (name the
  routine or state from the briefs), the on-screen type (exact words), the camera move and
  transition, the sound.
- The storyboard as images — generate a still for each shot in 9:16, using the exact bot
  shapes and the icon from the package. Then a contact sheet.
- If you can generate video: a 9:16 cut, a 16:9 cut and a square, with burned-in captions,
  H.264. If you can't, generate the key frames at 1080×1920 and describe the motion between
  them in easing terms (durations in ms, curves) precisely enough for an animator to build it.
- Music/SFX direction with specific references, and the voice choice (Vory "speaking" in typed
  speech bubbles is the app's own idiom — prefer that to a voiceover).

## 2. A website for vory.dev

Mobile first; a desktop version that is equally good but designed for desktop, same URL. Static
HTML/CSS/JS I can drop on S3 + CloudFront. Vory introduces itself and walks through what it is,
how it works and the benefits; it showcases everything the video touches and more (Creator
Studio, approval cards, Live Activity, group chats, the gateway settings, Vory Summaries). Same
category as "Cadu — Hermes for iPhone", but entirely our own.

Give me:
- Sitemap and the section-by-section content — the real copy, in Vory's voice (confident, warm,
  a little playful, never hype; short sentences; talk to one person).
- Mobile and desktop mockups as images for every section.
- The design system: type scale, colours (from the brief), the Liquid Glass treatment in CSS
  (backdrop-filter, rims, shadows), the motion rules (what animates on scroll, what doesn't,
  reduced-motion fallback).
- The actual files: `index.html`, `styles.css`, `main.js`, an `assets/` list. Performance and
  accessibility targets. A README for the person deploying to AWS.

## Rules

- Public beta: no real names of gateways, bots, hosts or people. Generic sample data only.
- Show only what exists (the brief and screenshots define it). No Android, no Mac app, no App
  Store — it's a TestFlight beta.
- Vory never scales, bounces or pops. Every bot keeps its shape except for the named state
  holds. Eyes stay near-black.
- Plan first: concepts, shot list, sitemap and copy — then ask me for a go before generating the
  final storyboard images, video and site files.

Start by telling me what you found in the package in five lines, then the three concepts.
