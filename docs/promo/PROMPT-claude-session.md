# Prompt for a new Claude Code session — Vory promo video + vory.dev website

Paste everything below the line into a fresh Claude Code session started in
`~/claude-sandbox/Vory` (this repo). It reads the repo, asks its questions, then waits for a
`/go` from me before any production work.

---

You are a senior motion designer and product web designer working on **Vory**, the iPhone remote
for a Hermes agent gateway. You have the full repo in front of you. Your job has two
deliverables, in this order, with a **plan approved by me before either is built**:

1. A **15–30 second motion-graphics promo video** to announce the public beta on X and Reddit.
   Treat it as your showreel: this is the piece you would put at the top of your résumé. Go all
   out on craft — timing, easing, typography, rhythm, sound design — while staying true to
   Vory's own motion rules (below). Vory, the blue glass cloud mascot, is the star: it
   introduces itself, shows what Vory is, how it works and why you'd want it.
2. A **website at vory.dev** that showcases everything the video touches and more. Mobile is
   the priority; the desktop version must be equally good but designed specifically for desktop
   (not a stretched phone layout), both on the same URL. Static files only (HTML/CSS/JS/assets)
   — another agent with AWS access will host them; give them a folder they can drop on S3 +
   CloudFront. Vory is the main character here too: the page introduces it, explains what it is,
   how it works and the benefits.

Reference for the site's *category*: "Cadu — Hermes for iPhone" (look it up). Same kind of
product — a phone client for Hermes — but Vory's site must be its own thing: our bots, our
glass, our voice. Do not copy their structure or copy.

## Read first (in this order)

- `docs/promo/VORY-PRODUCT-BRIEF.md` — what Vory is, how it works, the benefits, the visual
  language, tone, and the public-beta rules. Every claim in the video and site must be
  supported by it or by the app.
- `docs/HANDOFF.md` — the full change log and architecture map (what actually exists).
- `docs/bot-motion-brief.md` and `docs/bot-motion-brief-2.md` — the bots' motion system: the
  locks (never scale, bounce, hop, bloom or pop; eyes near-black; the coin-turn is the hero), the
  routines, the state holds (approval → "!", thinking → pebble, tool → stem). Your video must
  obey these when a bot is on screen; it is the brand's motion DNA. Camera moves, type and
  transitions around the bots can be as bold as you like.
- `Shared/BotFace.swift` — the bots are drawn from code. Read `bodyPath`, `eyePaths`,
  `BotFace.motion`, `BotFaceView`. You can reproduce the exact shapes and easing in whatever
  tool you render with.
- `Shared/AppIcon.icon` — the icon (render it with the `ictool` recipe in
  `docs/agent-memory/icon-composer-cli.md`).
- `docs/promo/grok-package/assets/` — renders and screenshots already captured (icon in three
  renditions, a state-morph strip, the demo video, screenshots).

## What you can use to make footage

- **The app in the simulator.** "Hermes iPhone" (UDID `1C5C2D80-B7E5-4995-AF84-13C4AD9CA7DE`),
  built with `xcodebuild -project Vory.xcodeproj -scheme Vory -configuration Debug -destination
  'id=<udid>' -derivedDataPath build/simsigned build`, against the mock gateway
  (`~/.hermes/hermes-agent/venv/bin/python Tools/mock-gateway/mock_gateway.py --port 9119 --token
  mock-token`, then `xcrun simctl spawn <udid> launchctl setenv HERMES_E2E_URL
  http://127.0.0.1:9119` and `HERMES_E2E_TOKEN mock-token`). Record with `xcrun simctl io <udid>
  recordVideo --codec=h264 --force out.mp4`. Debug launch args: `-vory-show-tour`,
  `-vory-motion-demo` (a grid of every bot state with Release/Hold and Finish-spin buttons),
  `-vory-shape-grid`, `-vory-show-setup`. The mock's sample chats and bots are generic — use
  them; never show anything user-specific.
- **Native rendering of the bots outside the app.** `Shared/BotFace.swift` compiles standalone
  with `xcrun -sdk macosx swiftc` (SwiftUI on macOS): you can write a small macOS harness that
  renders bot frames with `ImageRenderer` at any size and frame rate to PNG sequences — exact
  shapes, exact easing — and composite them. Painted glass (`drawn: true`) renders offscreen;
  live Liquid Glass needs an on-screen window (a macOS SwiftUI window recorded with
  `screencapture -v` also works).
- **Your own motion-graphics pipeline.** Anything you can drive from this machine: an HTML/CSS/
  WebGL or Canvas scene recorded headlessly (Playwright/Chromium is fine to install), Remotion
  (Node), Manim, ffmpeg compositing, Core Animation/SwiftUI rendered to frames, Blender if
  present. Pick what gives you the most control over easing and typography. Deliver
  1080×1920 (9:16) and 1920×1080 (16:9) masters plus a 1080×1080 square, H.264 + a
  high-quality ProRes or lossless, and a poster frame. Music/SFX: royalty-free or synthesised;
  say what you used. Captions burned in (X autoplays muted).
- The Cadu site and any Apple product page for Liquid Glass are fair reference for feel, not
  for copying.

## Hard rules

- Public beta: no real gateway/bot/host/person names anywhere. Generic sample data only.
- Everything shown must exist in the app as of build 45. Nothing invented.
- Bots on screen follow the motion briefs. Vory never scales, bounces or pops. The coin-turn is
  allowed to be showy; everything else is a glance, a squint, a lean, a light on the rim.
- The site is static, no build step required to serve it (a build step to *produce* it is fine
  — commit the output). Mobile first; desktop deliberately designed; same URL (responsive, not
  m.-subdomain). Fast: no multi-megabyte hero video on mobile without a poster + lazy load.
  Accessible: reduced-motion fallbacks, alt text, contrast.
- Don't touch the app's code. Work in `docs/promo/video/` and `docs/promo/site/` (create them).
  Commit as you go on a branch `promo`; do not push to `master`.

## Process — this is important

1. **Ask me your questions first.** Before any plan, ask everything you need in one batch, with
   your recommended answer for each: e.g. length (15 / 20 / 30 s), aspect priority (9:16 for X
   mobile vs 16:9), voice (Vory "speaking" in typed bubbles vs a voiceover vs none), music mood,
   how much UI vs how much pure motion graphics, whether the tour and the Live Activity get
   screen time, the site's sections and CTA (TestFlight link? waitlist email? GitHub?), domain
   details (vory.dev — is there an existing DNS/hosting or is this the first deploy?), whether
   the site should embed the video, analytics or none, dark/light themes, the tagline. Also
   confirm what you found in the repo that you intend to use as footage.
2. **Then write the full plan** and stop. The plan must include:
   - Video: a shot list with timecodes (every shot: what's on screen, what Vory does, the type,
     the camera/transition, the sound), the storyboard as a contact sheet of stills you render,
     the tool/pipeline you'll use, the render specs, and the risks.
   - Website: sitemap and section-by-section content (the actual copy, not lorem), wireframes
     for mobile AND desktop (as rendered images, not ASCII), the design system (type scale,
     colours, glass treatment in CSS, motion rules), the tech (plain HTML/CSS/JS or a static
     generator), the asset list, the file/folder layout the AWS agent will receive, and
     performance/accessibility targets.
   - A schedule of the steps you'll take, so I can check progress.
   Present it in the terminal AND as an artifact page I can read on my phone. Then wait.
3. I'll answer, adjust, and say **`/go`**. Only then build. Build the video first (it defines
   the assets), then the site. Show me stills and cuts as you go; don't disappear for an hour.
4. When both are done: a final contact sheet of the video, the video files, the site folder, a
   README for the AWS agent (bucket layout, cache headers, redirects, the CloudFront/Route 53
   notes), and a short "how I'd make it better with more time" list.

Start by confirming you've read the brief and the motion briefs, then ask your questions.
