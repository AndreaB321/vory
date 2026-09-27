# vory.dev — static site, deployment notes for the AWS agent

Everything under `public/` is the site. Upload that folder as-is; nothing needs building to serve
it. It is plain HTML, CSS and JavaScript (one ES module for the page, one for the bots).

```
public/
  index.html                 the whole site (one page, anchored sections)
  assets/
    site.css                 design system + layout (mobile first, desktop from 900 px)
    site.js                  page script: hero, studio, Live Activity stills, reveals
    vory-bot.js              the bot renderer (port of Shared/BotFace.swift)
    img/
      favicon-32.png, apple-touch-icon.png, icon-512.png, icon-dark-512.png, icon-1024.webp
      og.png                 1200×630 share image (referenced by og:image / twitter:image)
      approval-card.webp     crop of the real approval card
      chat-typing-{603,1206}.webp, group-chat-{603,1206}.webp, bots-shapes-{603,1206}.webp,
      chats-list-{603,1206}.webp, bot-states-grid-{603,1206}.webp   app screenshots
tools/
  og.swift                   renders og.png (`swift tools/og.swift <icon.png> <out.png>`, then sips to 1200×630)
  test-bots.html             renderer test sheet (serve the site folder, open /tools/test-bots.html)
DESIGN.md                    sitemap, copy, design system, targets
```

## One thing to fill in before go‑live

The TestFlight public link is a placeholder. Replace `https://testflight.apple.com/join/REPLACE-ME`
(two occurrences in `public/index.html`, both on `<a data-testflight>`) with the real invite URL.

## S3 + CloudFront

- **Bucket:** private, e.g. `vory-dev-site`, in any region. Do not enable static website hosting;
  serve through CloudFront with **Origin Access Control** (OAC) and a bucket policy that allows
  `s3:GetObject` from the distribution only.
- **Upload** the contents of `public/` to the bucket root (so `index.html` is at the root and
  `assets/…` is a prefix). Set `Content-Type` correctly: `.webp` → `image/webp`, `.js` →
  `text/javascript`, `.css` → `text/css`, `.html` → `text/html; charset=utf-8`, `.png` → `image/png`.
- **Cache-Control** (set as object metadata at upload time):
  - `index.html`: `public, max-age=0, must-revalidate`
  - `assets/**`: `public, max-age=31536000, immutable` is fine for images; for `site.css`,
    `site.js` and `vory-bot.js` use `public, max-age=3600, stale-while-revalidate=86400` unless you
    add content hashes to their filenames (they are referenced unhashed today).
  - `assets/img/og.png`: `public, max-age=86400` (social crawlers re-fetch it).
- **CloudFront distribution:**
  - Default root object: `index.html`.
  - Viewer protocol policy: redirect HTTP → HTTPS. HTTP/2 and HTTP/3 on. Compression on (Brotli/gzip).
  - Alternate domain names: `vory.dev` and `www.vory.dev`. Certificate: ACM in **us-east-1**
    covering both names (DNS validation, see DNS below).
  - Cache policy: `CachingOptimized` is fine (the objects carry their own `Cache-Control`).
  - Add a **CloudFront Function** (viewer-request) that (a) 301‑redirects any `www.vory.dev` host to
    `https://vory.dev` + same path, and (b) rewrites a request ending in `/` to `/index.html`
    (only the root needs it today; keeps future subpages working).
  - Response headers policy (custom): `Strict-Transport-Security: max-age=31536000; includeSubDomains`,
    `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`,
    `Permissions-Policy: camera=(), microphone=(), geolocation=()`,
    `Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'none'`.
    The page loads nothing from other origins; no inline scripts, one inline `<script type="application/ld+json">`
    (JSON‑LD is data, not executed, and passes CSP without `unsafe-inline`).
  - Custom error response: 404 → `/index.html` with **404** status is NOT wanted (this is not an SPA);
    leave 404s as 404 or point them at a small `404.html` if one is added later.
- **Invalidate** `/*` after each upload (index.html has max-age=0, but a full invalidation is cheap
  for a site this size).

## DNS: keep the zone on Cloudflare (recommended)

`vory.dev` already has Cloudflare nameservers (`ophelia` / `javier`) and no A/AAAA records. Nothing
is hosted yet. The simplest path is to leave the zone where it is:

1. In ACM (us-east-1) request a certificate for `vory.dev` + `www.vory.dev`, DNS validation. Add the
   two `_acme-challenge`-style CNAME validation records to the Cloudflare zone (**DNS only**, grey
   cloud, not proxied) and wait for "Issued".
2. Add `vory.dev` → the distribution's `dxxxxxxxx.cloudfront.net` as a **CNAME at the apex**
   (Cloudflare flattens apex CNAMEs automatically) and `www` → the same target. Both **DNS only /
   grey cloud** so CloudFront terminates TLS and the ACM cert is what browsers see. (Proxied /
   orange cloud would also work but then two CDNs stack and the CSP/redirect function still has to
   live on CloudFront; not worth it.)
3. Cloudflare › SSL/TLS: irrelevant while records are DNS‑only. Leave "Always use HTTPS" off there
   (CloudFront does the redirect).

### If the zone is moved to Route 53 instead

Create a public hosted zone for `vory.dev`, copy the ACM validation records, then two **alias A
records** (and AAAA) for the apex and `www` pointing at the distribution. Update the registrar's
nameservers to the four Route 53 ones. The site behaves identically; this only adds a migration.

## Checks after deploy

- `curl -I https://vory.dev/` → 200, `content-type: text/html; charset=utf-8`, HSTS header present.
- `curl -I https://www.vory.dev/` → 301 to `https://vory.dev/`.
- `curl -I http://vory.dev/` → 301 to https.
- Share preview: paste the URL into X / Slack; `og.png` should render (1200×630).
- Lighthouse on mobile: the page is ~330 KB total on first load (fonts are the system's; the
  screenshots are lazy and sized), no third‑party requests, no cookies.

## What the site is, in one paragraph

A single responsive page (same URL on phone and desktop, with a deliberate two‑column desktop
layout) introducing Vory, the iPhone remote for a Hermes agent gateway. The mascot and every bot on
the page are drawn live by `vory-bot.js`, a port of the app's own renderer, so the motion matches the
app (blinks, glances, the coin‑turn, the state holds). Light and dark follow the system setting.
Reduced motion is honoured (bodies still, no reveals). No analytics, no cookies, no third parties.
