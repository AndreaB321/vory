# vory.dev — design notes

The plan and the design system for the site, as built (2026‑09‑26). The video is deferred; the
renderer the site uses (`public/assets/vory-bot.js`) is the same module the video will render with.

## Sitemap (one page, anchored)

| # | id | Section | Job |
|---|----|---------|-----|
| 0 | `#top` | Nav | Brand, four anchors on desktop, "Join the beta" |
| 1 | hero | Vory introduces itself | Live Vory (guide state) on its shelf, typed bubble, tagline, TestFlight CTA |
| 2 | `#what` | A remote, not a cloud | What Hermes is, what Vory is; three benefit cards with a bot each |
| 3 | `#how` | The loop | Eight steps of the brief's "How it works", a bot in the matching state on each |
| 4 | `#bots` | Meet the bots | Interactive Creator Studio (shape / eyes / colour / finish) and the state row; the motion rules |
| 5 | `#approve` | Approve from your pocket | The real approval card; the Live Activity + notification rebuilt in HTML |
| 6 | `#chat` | Chats that feel like Messages | Feature list + two phone screenshots (chat with tool card; group chat) |
| 7 | `#gateway` | Run the gateway | Settings chips + Bots tab screenshot |
| 8 | `#yours` | Yours, all the way down | Self‑hosted, reachability, on‑device summaries, no tracking |
| 9 | `#beta` | Get the beta | Requirements + TestFlight CTA |
| 10 | `#faq` | Questions | Six answers |
| 11 | footer | | Vory, no cookies / analytics |

Every claim traces to `docs/promo/VORY-PRODUCT-BRIEF.md` or to build 45. Nothing on the page names
a real gateway, host, bot or person. The one sample bot name, "Ada", is the app's own tour sample.

## Tagline and voice

- Tagline: **Your agents, in your pocket.**
- Subhead: the brief's one‑liner. Vory speaks in its typed bubble using the tour's lines.
- Tone: confident, warm, a little playful. Short sentences. Talks to one person. Never "AI hype";
  Vory is the remote and the mascot, the agents are the AI.

## Type

System stack (SF Pro on Apple devices, the platform sans elsewhere). Headings use `ui-rounded`
(SF Pro Rounded) where available, matching the bots' friendliness.

| Role | Size | Weight |
|---|---|---|
| h1 | clamp(40px, 10vw, 78px); 84px ≥ 1200px | 800, letter‑spacing −0.02em, line‑height 1.02 |
| h2 | clamp(30px, 6vw, 48px) | 700 |
| h3 | 19px | 700 |
| lede | 19px / 1.45 | 400, muted |
| body | 17px / 1.5 | 400 |
| eyebrow | 13px | 650, accent |
| fineprint / captions | 14px | 400, muted |

## Colour

| Token | Light | Dark |
|---|---|---|
| `--bg` | #F2F2F7 | #000000 |
| `--bg-2` (cards, bubbles) | #FFFFFF | #1C1C1E |
| `--text` | #0A0A0C | #F5F5F7 |
| `--muted` | #6E6E73 | #8E8E93 |
| `--accent` | #0A84FF | #0A84FF |
| `--vory` | #3B7BFF | #3B7BFF |
| `--amber` / `--green` | #F5A524 / #30D158 | same |

Theme follows `prefers-color-scheme`; `:root[data-theme]` overrides exist for tooling.

## Glass in CSS

```css
.glass {
  background: var(--glass);                       /* white 55 % (light) / #1C1C1E 62 % (dark) */
  backdrop-filter: blur(20px) saturate(1.6);
  border: 1px solid var(--glass-rim);             /* white 85 % / white 14 % : the specular rim */
  box-shadow: var(--glass-shadow);                /* soft contact shadow */
  border-radius: 22px;
}
```

Shelves under the bots (the app's header pill) are the same recipe as a capsule; the bot's base sits
9 px into the pill, computed from the shape's baseline like `BotFace.baseline(of:)`.

## Motion rules

- Bots: exactly the app's. Idle = eyes only. Working = one routine per 3.2 s block. State holds
  morph in place. Nothing scales, bounces, hops or pops. Eyes follow page scroll (the app's gaze).
- Page: reveals are a 12 px rise + fade over 0.5 s, once, on entering the viewport. Buttons press
  1 px. Nothing else moves.
- `prefers-reduced-motion`: reveals off, typed bubble static, bot bodies still (eyes may blink),
  held poses jump to their end state.

## Layout

- Mobile first, 16 px gutters, single column, horizontal scroll never.
- ≥ 700 px: three‑up cards, two‑up steps, three‑up rules.
- ≥ 900 px (desktop, designed not stretched): 32 px gutters, nav anchors appear, hero becomes
  copy‑left / Vory‑right at full viewport height, the studio becomes stage‑left / controls‑right with
  the state row below, approvals and chats become two columns with a second phone behind the first.
- ≥ 1200 px: larger h1 and hero Vory.

## Assets

- Icon renditions from `ictool` (Icon Composer's CLI) on `Shared/AppIcon.icon`, resized with `sips`.
- Screenshots converted to WebP at 603 and 1206 px wide (`cwebp -q 82`), delivered with `srcset`.
- Approval card cropped from the chat screenshot (`ffmpeg crop=1150:650:28:1862`).
- OG image rendered by `tools/og.swift` (AppKit, SF Pro) and downscaled to 1200×630.

## Targets

- Performance: no web fonts, no third‑party requests, images lazy and sized, first load ≈ 330 KB.
  Lighthouse mobile performance ≥ 95 expected; the bots render on canvas at device pixel ratio
  (capped at 3) and idle bots redraw only when their eyes have something to do.
- Accessibility: semantic landmarks, skip link, visible focus, `aria-pressed` on every picker,
  canvases `aria-hidden` with text equivalents, alt text on every screenshot, FAQ as native
  `details`, contrast ≥ 4.5:1 for text in both themes, reduced‑motion fallbacks.

## Not on the page, on purpose

Watch app, Files tab, Summaries footage (the simulator has no model), pricing, App Store, Android,
Mac. All either absent from the brief or not capturable honestly.
