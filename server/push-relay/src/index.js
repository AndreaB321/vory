// Vory push relay. Devices register (install id + a secret the phone made up); the user's own
// Hermes gateway then posts *encrypted* notification payloads for that install id. The relay only
// ever sees device tokens and ciphertext; the app's Notification Service Extension decrypts.
//
// POST /v1/register   {install_id, secret, device_token, platform, bundle_id, environment, live_activity_token?}
// POST /v1/push       {install_id, secret, enc, collapse_id?, thread_id?, interruption?,
//                      push_type?: "alert"|"liveactivity"|"complication", token?, content_state?, event?, dismissal_date?, alert?}
// DELETE /v1/register {install_id, secret}
// GET  /v1/health

const JSON_HEADERS = { "content-type": "application/json" };
const reply = (status, body) => new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    try {
      if (url.pathname === "/v1/health") return reply(200, { ok: true });
      if (url.pathname === "/v1/register" && request.method === "POST") return await register(request, env);
      if (url.pathname === "/v1/register" && request.method === "DELETE") return await unregister(request, env);
      if (url.pathname === "/v1/push" && request.method === "POST") return await push(request, env);
      return reply(404, { error: "not found" });
    } catch (e) {
      return reply(500, { error: String(e?.message || e) });
    }
  },
};

const SECRET_RE = /^[A-Za-z0-9_-]{32,128}$/;
const ID_RE = /^[a-z0-9-]{8,80}$/;

async function readJSON(request) {
  const text = await request.text();
  if (text.length > 16384) throw new Error("payload too large");
  return JSON.parse(text || "{}");
}

function timingSafeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

async function loadDevice(env, installId, secret) {
  if (!ID_RE.test(installId || "") || !SECRET_RE.test(secret || "")) return null;
  const raw = await env.DEVICES.get("dev:" + installId);
  if (!raw) return null;
  const dev = JSON.parse(raw);
  return timingSafeEqual(dev.secret, secret) ? dev : null;
}

async function register(request, env) {
  const b = await readJSON(request);
  const { install_id, secret, device_token, platform, bundle_id, environment } = b;
  if (!ID_RE.test(install_id || "") || !SECRET_RE.test(secret || "")) return reply(400, { error: "bad install_id or secret" });
  if (!/^[0-9a-f]{32,200}$/.test(device_token || "")) return reply(400, { error: "bad device_token" });
  if (!["ios", "macos", "watchos"].includes(platform)) return reply(400, { error: "bad platform" });
  if (!/^[A-Za-z0-9.-]{3,120}$/.test(bundle_id || "")) return reply(400, { error: "bad bundle_id" });
  const existing = await env.DEVICES.get("dev:" + install_id);
  if (existing && !timingSafeEqual(JSON.parse(existing).secret, secret)) return reply(403, { error: "install_id is taken" });
  const dev = {
    secret, device_token, platform, bundle_id,
    environment: environment === "development" ? "development" : "production",
    live_activity_token: b.live_activity_token || null,
    updated_at: Date.now(),
  };
  await env.DEVICES.put("dev:" + install_id, JSON.stringify(dev));
  return reply(200, { ok: true });
}

async function unregister(request, env) {
  const b = await readJSON(request);
  const dev = await loadDevice(env, b.install_id, b.secret);
  if (!dev) return reply(403, { error: "unknown device" });
  await env.DEVICES.delete("dev:" + b.install_id);
  return reply(200, { ok: true });
}

async function push(request, env) {
  const b = await readJSON(request);
  const dev = await loadDevice(env, b.install_id, b.secret);
  if (!dev) return reply(403, { error: "unknown device" });
  const type = b.push_type || "alert";
  let topic = dev.bundle_id, token = dev.device_token, payload;
  // Store-and-forward for an hour: with expiration 0 Apple discards a push the instant the phone's
  // push connection is down, which the sandbox service (Debug builds) does often.
  const headers = { "apns-push-type": type, "apns-priority": "10", "apns-expiration": String(Math.floor(Date.now() / 1000) + 3600) };
  if (type === "alert") {
    if (typeof b.enc !== "string" || b.enc.length > 8192) return reply(400, { error: "enc required" });
    // Placeholder text: the extension replaces it after decrypting `enc`.
    payload = {
      aps: { "mutable-content": 1, alert: { title: "Vory", body: "New activity" }, sound: "default",
             category: "HERMES_ENC", "thread-id": b.thread_id || "",
             "interruption-level": b.interruption === "time-sensitive" ? "time-sensitive" : "active" },
      enc: b.enc,
    };
    if (b.collapse_id) headers["apns-collapse-id"] = String(b.collapse_id).slice(0, 64);
  } else if (type === "liveactivity") {
    token = b.token || dev.live_activity_token;
    if (!token) return reply(400, { error: "no live activity token" });
    topic = dev.bundle_id + ".push-type.liveactivity";
    const now = Math.floor(Date.now() / 1000);
    payload = { aps: { timestamp: now, event: b.event === "end" ? "end" : "update", "content-state": b.content_state || {} } };
    if (b.event === "end") payload.aps["dismissal-date"] = b.dismissal_date || now + 60;
    // An alerting update: the Island expands and the phone buzzes. Plain words only, by design.
    if (b.alert && typeof b.alert === "object") {
      payload.aps.alert = { title: String(b.alert.title || "Vory").slice(0, 80), body: String(b.alert.body || "").slice(0, 160), sound: "default" };
    }
  } else if (type === "complication") {
    if (dev.platform !== "watchos") return reply(400, { error: "complication pushes are for watches" });
    topic = dev.bundle_id + ".complication";
    payload = { aps: { "content-available": 1 } };
    headers["apns-priority"] = "5";
  } else {
    return reply(400, { error: "bad push_type" });
  }
  headers["apns-topic"] = topic;
  headers["authorization"] = "bearer " + (await apnsJWT(env));
  headers["content-type"] = "application/json";
  const host = dev.environment === "development" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const res = await fetch(`https://${host}/3/device/${token}`, { method: "POST", headers, body: JSON.stringify(payload) });
  const text = await res.text();
  if (res.status === 410 || (res.status === 400 && text.includes("BadDeviceToken"))) {
    await env.DEVICES.delete("dev:" + b.install_id);   // token is dead; let the app re-register
  }
  return reply(res.ok ? 200 : 502, { ok: res.ok, apns_status: res.status, apns: text.slice(0, 200) });
}

// ── APNs provider token (ES256), cached for 50 minutes per isolate ───────────────────────────
let cachedJWT = { value: "", at: 0 };

async function apnsJWT(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT.value && now - cachedJWT.at < 50 * 60) return cachedJWT.value;
  const key = await importP8(env.APNS_KEY_P8);
  const b64 = (obj) => btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const unsigned = `${b64({ alg: "ES256", kid: env.APNS_KEY_ID })}.${b64({ iss: env.APNS_TEAM_ID, iat: now })}`;
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(unsigned));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  cachedJWT = { value: `${unsigned}.${sigB64}`, at: now };
  return cachedJWT.value;
}

async function importP8(pem) {
  const body = pem.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}
