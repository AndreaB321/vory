# vory.dev/beta → TestFlight

Target (permanent, belongs to the "Public beta" TestFlight group, not to a build):

    https://testflight.apple.com/join/tJ4PyTfc

Use `https://vory.dev/beta` everywhere public (site buttons, X, Reddit, the video). If the
TestFlight code ever has to change, only the redirect changes.

Do BOTH parts: the edge redirect gives a true 302 (fast, works for curl/bots/link previews); the
static page is the fallback that works on any host and before the edge rule exists.

---

## Part 1 — the static site

Add `beta/index.html` to the site output (so `/beta` and `/beta/` both resolve on S3/CloudFront
with the default root object `index.html`):

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Vory beta</title>
<meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0; url=https://testflight.apple.com/join/tJ4PyTfc">
<link rel="canonical" href="https://vory.dev/beta">
<script>location.replace("https://testflight.apple.com/join/tJ4PyTfc");</script>
<style>body{font:17px -apple-system,system-ui;margin:0;min-height:100vh;display:grid;place-items:center;background:#f2f2f7;color:#111}a{color:#0a84ff}</style>
</head>
<body><p>Opening TestFlight… <a href="https://testflight.apple.com/join/tJ4PyTfc">Tap here if nothing happens.</a></p></body>
</html>
```

Every "Join the beta" button on the site links to `/beta` (relative), never to the TestFlight
URL directly.

Note for copy: until Apple approves the first build, the TestFlight page says "not accepting new
testers". Fine to ship the site with the button; hold the announcement post until it's approved.

---

## Part 2 — the edge redirect (AWS or Cloudflare)

Pick the one that matches where `vory.dev` is actually served from.

### A. CloudFront in front of S3 (the expected setup)

Create a **CloudFront Function** (viewer-request) and attach it to the distribution's default
behaviour:

```js
function handler(event) {
    var uri = event.request.uri;
    if (uri === '/beta' || uri === '/beta/') {
        return {
            statusCode: 302,
            statusDescription: 'Found',
            headers: {
                location: { value: 'https://testflight.apple.com/join/tJ4PyTfc' },
                'cache-control': { value: 'no-store' }
            }
        };
    }
    // Serve index.html for directory-style paths (/privacy/ → /privacy/index.html).
    if (uri.endsWith('/')) event.request.uri = uri + 'index.html';
    else if (!uri.includes('.')) event.request.uri = uri + '/index.html';
    return event.request;
}
```

302 (not 301) on purpose: browsers cache 301s forever, and we want to be able to change the
target. Deploy: Functions → Create → paste → Publish → Associate (Distribution, Default (*),
Viewer request). Then `aws cloudfront create-invalidation --paths "/beta*"`.

### B. If `vory.dev` DNS is on Cloudflare AND the record is proxied (orange cloud)

Rules → Redirect Rules → Create:
- Name: `beta → TestFlight`
- When incoming requests match: Custom filter · Hostname equals `vory.dev` AND URI Path is in
  `/beta`, `/beta/`
- Then: Dynamic redirect → URL redirect, expression `"https://testflight.apple.com/join/tJ4PyTfc"`,
  status **302**, preserve query string off.

(If the DNS record is DNS-only / grey cloud, Cloudflare rules do not run; use A.)

### C. Plain S3 website endpoint (no CloudFront)

S3 → bucket → Properties → Static website hosting → Redirection rules:

```json
[{"Condition":{"KeyPrefixEquals":"beta"},
  "Redirect":{"HostName":"testflight.apple.com","Protocol":"https","ReplaceKeyWith":"join/tJ4PyTfc","HttpRedirectCode":"302"}}]
```

---

## Verify

```bash
curl -sI https://vory.dev/beta | grep -i -E '^(HTTP|location)'
```

Expect `HTTP/2 302` and `location: https://testflight.apple.com/join/tJ4PyTfc`. With only Part 1
in place you'll see `200` and the HTML page instead — still works in a browser.
