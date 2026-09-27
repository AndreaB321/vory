# Prompt for the deployment agent — put vory.dev live on AWS

Paste everything below the line to an agent with AWS CLI access. Attach `vory-site.zip`.

---

You are deploying a finished static website to AWS. The site is in the attached `vory-site.zip`;
inside, the folder `public/` is the site root. **Do not edit any file in it.** Serve it from S3
through CloudFront with HTTPS on `vory.dev` and `www.vory.dev`. The domain's DNS is on Cloudflare
(nameservers `ophelia.ns.cloudflare.com` / `javier.ns.cloudflare.com`); the zone stays there and
will point at CloudFront. Nothing is hosted for this domain yet, so there is nothing to migrate or
preserve.

Work in `us-east-1` for the certificate (CloudFront requires it). The bucket can be in any region;
use `us-east-1` unless told otherwise. Report every resource id you create at the end.

## 1. Bucket

- Create a **private** bucket, e.g. `vory-dev-site`. Block all public access. Do **not** enable
  static website hosting.
- Upload the **contents** of `public/` to the bucket root, so `index.html` is at the root and
  `assets/...` is a prefix. Set the right `Content-Type` and `Cache-Control` per file:

| Files | Content-Type | Cache-Control |
|---|---|---|
| `index.html` | `text/html; charset=utf-8` | `public, max-age=0, must-revalidate` |
| `assets/*.css` | `text/css; charset=utf-8` | `public, max-age=3600, stale-while-revalidate=86400` |
| `assets/*.js` | `text/javascript; charset=utf-8` | `public, max-age=3600, stale-while-revalidate=86400` |
| `assets/img/*.webp` | `image/webp` | `public, max-age=31536000, immutable` |
| `assets/img/og.png` | `image/png` | `public, max-age=86400` |
| other `assets/img/*.png` | `image/png` | `public, max-age=31536000, immutable` |

The AWS CLI does not set these from a single `sync`; run one `aws s3 cp --recursive` per group with
`--exclude "*" --include "<pattern>" --content-type ... --cache-control ... --metadata-directive REPLACE`,
or `aws s3 sync` per group with the same flags. Verify with `aws s3api head-object` on
`index.html`, one `.js`, one `.webp`.

## 2. Certificate (ACM, us-east-1)

- Request a public certificate for `vory.dev` with the additional name `www.vory.dev`, **DNS
  validation**.
- ACM gives two CNAME validation records (one per name; they may be identical). These must be
  added in the **Cloudflare** zone for vory.dev as **DNS-only (grey cloud, not proxied)** records.
  If you have Cloudflare API access, add them; otherwise print them exactly (name, type, value) and
  ask the owner to add them, then wait until the certificate status is `ISSUED`.

## 3. CloudFront distribution

- Origin: the S3 bucket via **Origin Access Control** (OAC, SigV4, always sign). Attach the
  generated bucket policy that allows `s3:GetObject` to the distribution's ARN only.
- Default root object: `index.html`.
- Alternate domain names (CNAMEs): `vory.dev`, `www.vory.dev`. Certificate: the ACM cert from step 2.
  TLS 1.2_2021 minimum. SNI.
- Viewer protocol policy: **redirect HTTP to HTTPS**. Allowed methods: GET, HEAD. Compress objects
  automatically: on. HTTP/2 and HTTP/3: on. IPv6: on. Price class: all edges (or 100 if cost matters).
- Cache policy: `CachingOptimized` (managed). Origin request policy: none needed.
- **Viewer-request CloudFront Function** (JavaScript runtime 2.0), associated with the default
  behaviour. It must (a) redirect any request whose `Host` is `www.vory.dev` to
  `https://vory.dev` + the same URI and query string with a 301, and (b) append `index.html` to
  any URI that ends in `/` (or has no file extension and is a directory-style path):

```js
function handler(event) {
  var req = event.request;
  var host = req.headers.host && req.headers.host.value;
  if (host === 'www.vory.dev') {
    var qs = '';
    var keys = Object.keys(req.querystring || {});
    if (keys.length) {
      qs = '?' + keys.map(function (k) { return k + '=' + req.querystring[k].value; }).join('&');
    }
    return { statusCode: 301, statusDescription: 'Moved Permanently',
             headers: { location: { value: 'https://vory.dev' + req.uri + qs } } };
  }
  if (req.uri.endsWith('/')) req.uri += 'index.html';
  else if (!req.uri.includes('.')) req.uri += '/index.html';
  return req;
}
```

- **Response headers policy** (custom), attached to the default behaviour:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains`
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: camera=(), microphone=(), geolocation=()`
  - `Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'none'`
  - `X-Frame-Options: DENY`

  The page loads nothing from other origins and has no inline scripts (one inline
  `application/ld+json` block, which CSP does not execute), so this policy is safe as written.
- Custom error responses: none. This is not a single‑page app; leave 404s as 404.
- Wait for the distribution to deploy, then note its domain (`dXXXXXXXXXXXXX.cloudfront.net`).

## 4. DNS on Cloudflare

Add two records, both **DNS-only (grey cloud, proxy OFF)**, TTL auto:

| Type | Name | Target |
|---|---|---|
| CNAME | `vory.dev` (the apex, `@`) | `dXXXXXXXXXXXXX.cloudfront.net` |
| CNAME | `www` | `dXXXXXXXXXXXXX.cloudfront.net` |

Cloudflare flattens the apex CNAME automatically. Keep the proxy off so CloudFront terminates TLS
with the ACM certificate and the security headers and the www redirect come from CloudFront.
Do not enable Cloudflare's "Always use HTTPS" or any page rules; CloudFront handles the redirect.
If you cannot edit Cloudflare, print these two records exactly and ask the owner to add them.

Leave the ACM validation records in place; ACM renews the certificate through them.

## 5. Verify, then report

Run and paste the results:

```bash
curl -sI https://vory.dev/ | head -20          # 200, text/html; charset=utf-8, HSTS + CSP headers present
curl -sI https://www.vory.dev/ | head -5       # 301 → https://vory.dev/
curl -sI http://vory.dev/ | head -5            # 301 → https://vory.dev/
curl -sI https://vory.dev/assets/vory-bot.js | grep -i "content-type\|cache-control\|content-encoding"
curl -sI https://vory.dev/assets/img/og.png | grep -i "content-type\|content-length"   # image/png, ~1200×630
curl -s https://vory.dev/ | grep -c "Your agents"  # 1
```

Open https://vory.dev/ in a browser: the blue cloud mascot should be animating in the hero, and the
"Meet the bots" section should let you change its shape. Check on a phone too (same URL; the layout
is responsive). Then report: bucket name and region, distribution id and domain, certificate ARN,
function name, response headers policy id, the DNS records added, and the output of the checks.

## Later updates

To publish a new version: upload the new `public/` contents with the same content types and
cache headers, then invalidate `/*` on the distribution. `index.html` is never cached by browsers
(max-age=0), so a new deploy shows up as soon as the invalidation completes.
