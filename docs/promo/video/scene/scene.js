/*
 * The Vory promo, as a function of time. `seek(t)` paints frame `t` (seconds) onto the stage
 * canvas; nothing here depends on wall-clock time, so every frame is reproducible. The bots are
 * drawn by vory-bot.js, the same port of Shared/BotFace.swift the website runs, so their blinks,
 * glances, coin-turns and state holds are the app's. Everything around them (camera, type, cards,
 * bubbles) is this file.
 *
 * ?aspect=916 (1080×1920, the master) · 169 (1920×1080) · 11 (1080×1080)
 */
import { drawBot, motion, stillMotion, VORY, baseline, isLight } from "./vory-bot.js";

const params = new URLSearchParams(location.search);
const ASPECT = params.get("aspect") || "916";
const SIZES = { 916: [1080, 1920], 169: [1920, 1080], 11: [1080, 1080] };
const [W, H] = SIZES[ASPECT];
const canvas = document.getElementById("stage");
canvas.width = W; canvas.height = H;
const ctx = canvas.getContext("2d");
const cues = await (await fetch("../cues.json")).json();

// ---- easing
const clamp01 = (x) => Math.min(1, Math.max(0, x));
const seg = (t, a, b) => clamp01((t - a) / (b - a));
const outExpo = (u) => (u >= 1 ? 1 : 1 - Math.pow(2, -10 * u));
const inExpo = (u) => (u <= 0 ? 0 : Math.pow(2, 10 * (u - 1)));
const inOutCubic = (u) => (u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2);
const smooth = (u) => { u = clamp01(u); return u * u * (3 - 2 * u); };
const lerp = (a, b, k) => a + (b - a) * k;
/** 0→1 entrance from `at` over `dur` (no overshoot), 1→0 exit from `off` over `odur`. */
const inOut = (t, at, off = Infinity, dur = 0.7, odur = 0.45) => {
  if (t < at) return 0;
  if (t >= off) return 1 - inExpo(seg(t, off, off + odur));
  return outExpo(seg(t, at, at + dur));
};

// ---- palette
const BG = "#F2F2F7", INK = "#0A0A0C", MUTED = "#6E6E73", ACCENT = "#0A84FF", GREEN = "#30D158", AMBER = "#F5A524", ORANGE = "#FF9500";
const FONT = (w, s, rounded = false) => `${w} ${s}px ${rounded ? '"SF Rounded", ' : ""}system-ui, -apple-system, sans-serif`;

// ---- primitives
function rr(x, y, w, h, r) { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); }
function text(s, x, y, { size = 40, weight = 600, color = INK, align = "center", alpha = 1, rounded = false, baseline: bl = "middle", spacing = 0 } = {}) {
  if (alpha <= 0.002) return;
  ctx.save(); ctx.globalAlpha = alpha; ctx.fillStyle = color; ctx.font = FONT(weight, size, rounded); ctx.textAlign = align; ctx.textBaseline = bl;
  if (spacing) ctx.letterSpacing = `${spacing}px`;
  ctx.fillText(s, x, y); ctx.restore();
}
function shadow(color, blur, y) { ctx.shadowColor = color; ctx.shadowBlur = blur; ctx.shadowOffsetY = y; }
function glassPlate(x, y, w, h, r, { alpha = 1, fill = "rgba(255,255,255,0.72)" } = {}) {
  ctx.save(); ctx.globalAlpha = alpha;
  shadow("rgba(20,30,60,0.10)", 30, 10); rr(x, y, w, h, r); ctx.fillStyle = fill; ctx.fill();
  shadow("transparent", 0, 0); ctx.lineWidth = 1.5; ctx.strokeStyle = "rgba(255,255,255,0.9)"; rr(x + 0.75, y + 0.75, w - 1.5, h - 1.5, r - 0.75); ctx.stroke();
  ctx.restore();
}
/** The app's header pill: the bot's base sits 9 px (scaled) into it. */
function shelf(cx, cy, size, shape, label, { alpha = 1, status = null, scale = 1 } = {}) {
  const base = cy - size / 2 + size * baseline(shape);
  const h = 66 * scale, pad = 34 * scale, fs = 30 * scale;
  ctx.font = FONT(700, fs); const lw = ctx.measureText(label).width;
  let sw = 0; if (status) { ctx.font = FONT(500, fs * 0.86); sw = ctx.measureText(status).width + 12 * scale; }
  const w = Math.max(lw + sw + pad * 2, label ? 0 : size * 0.62), x = cx - w / 2, y = base - 9 * scale;
  glassPlate(x, y, w, h, h / 2, { alpha });
  text(label, x + pad, y + h / 2, { size: fs, weight: 700, align: "left", alpha });
  if (status) text(status, x + pad + lw + 12 * scale, y + h / 2 + 1, { size: fs * 0.86, weight: 500, color: MUTED, align: "left", alpha });
  return y + h;
}
/** Speech bubble with a tail pointing up (under a bot) or down-left (a chat reply). */
function bubble(cx, top, str, { alpha = 1, tail = "top", size = 34, maxW = 700, fill = "#FFFFFF", color = INK, caret = false, minW = 0, scale = 1 } = {}) {
  if (alpha <= 0.002) return 0;
  ctx.font = FONT(500, size);
  const words = str.split(" "); const lines = []; let cur = "";
  for (const w of words) { const test = cur ? cur + " " + w : w; if (ctx.measureText(test).width > maxW - 64 * scale && cur) { lines.push(cur); cur = w; } else cur = test; }
  lines.push(cur);
  const lh = size * 1.28, padX = 32 * scale, padY = 22 * scale;
  const tw = Math.max(minW, ...lines.map((l) => ctx.measureText(l).width + (caret ? size * 0.35 : 0)));
  const w = tw + padX * 2, h = lines.length * lh + padY * 2, x = cx - w / 2, y = top;
  ctx.save(); ctx.globalAlpha = alpha;
  shadow("rgba(20,30,60,0.12)", 28, 8);
  ctx.fillStyle = fill; rr(x, y, w, h, 28 * scale); ctx.fill();
  ctx.beginPath();
  if (tail === "top") { ctx.moveTo(cx - 16 * scale, y + 1); ctx.lineTo(cx, y - 16 * scale); ctx.lineTo(cx + 16 * scale, y + 1); }
  else if (tail === "left") { ctx.moveTo(x + 2, y + h - 30 * scale); ctx.lineTo(x - 14 * scale, y + h - 2); ctx.lineTo(x + 24 * scale, y + h - 2); }
  else if (tail === "right") { ctx.moveTo(x + w - 2, y + h - 30 * scale); ctx.lineTo(x + w + 14 * scale, y + h - 2); ctx.lineTo(x + w - 24 * scale, y + h - 2); }
  ctx.closePath(); ctx.fill();
  shadow("transparent", 0, 0);
  ctx.fillStyle = color; ctx.font = FONT(500, size); ctx.textAlign = "left"; ctx.textBaseline = "middle";
  lines.forEach((l, i) => ctx.fillText(l, x + padX, y + padY + lh * (i + 0.5)));
  if (caret) { const last = lines[lines.length - 1]; const cw = ctx.measureText(last).width; ctx.globalAlpha = alpha * 0.45; ctx.fillRect(x + padX + cw + 4, y + padY + lh * (lines.length - 0.5) - size * 0.5, 3, size); }
  ctx.restore();
  return h;
}
/** Typed text as a function of time: types at `cps`, erases the previous line in 0.22 s. */
function typedLine(t) {
  const lines = cues.typing; let cur = null, prev = null;
  for (const l of lines) if (t >= l.at) { prev = cur; cur = l; }
  if (!cur) return { str: "", caret: false, show: false };
  const eraseDur = 0.22;
  if (prev && t < cur.at + eraseDur) { const u = 1 - seg(t, cur.at, cur.at + eraseDur); return { str: prev.text.slice(0, Math.floor(prev.text.length * u)), caret: true, show: true }; }
  const start = prev ? cur.at + eraseDur : cur.at;
  const nChars = Math.floor((t - start) * cues.cps);
  return { str: cur.text.slice(0, nChars), caret: nChars < cur.text.length || Math.floor(t * 2) % 2 === 0, show: true };
}

// ---- bots with a timeline of states (the app's BotFaceView, offline)
class Track {
  constructor(spec, profile, segs) { this.spec = spec; this.segs = segs.length ? segs : [{ at: -10, state: "idle" }]; this.finishes = []; this.taps = []; this.blinks = []; this.seed = seedOf(spec, profile); }
  segAt(t) { let i = 0; for (let k = 0; k < this.segs.length; k++) if (this.segs[k].at <= t) i = k; return i; }
  raw(t, i, since) { const s = this.segs[i]; const f = this.finishes.find((x) => t - x >= 0 && t - x < 1.75) ?? null; const tp = this.taps.find((x) => t - x >= 0 && t - x < 0.55) ?? null; return motion(t, this.seed, this.spec, s.state, since, f, tp); }
  pose(t) {
    const i = this.segAt(t), s = this.segs[i];
    let ex = null;
    if (i > 0 && t - s.at < 0.4) ex = this.raw(s.at - 1e-4, i - 1, s.at - 1e-4 - this.segs[i - 1].at);
    const delay = ex && ex.morph > 0.01 ? 0.4 : (i > 0 && this.exitHadMorph(i) ? 0.4 : 0);
    let m = this.raw(t, i, t - s.at - delay);
    if (ex) {
      const k = 1 - smooth((t - s.at) / 0.4);
      if (ex.morph > 0.001) { m.morphTarget = ex.morphTarget; m.morph = ex.morph * k; }
      m.roll = lerp(m.roll, ex.roll, k); m.dim = lerp(m.dim, ex.dim, k); m.eyeOpacity = lerp(m.eyeOpacity, ex.eyeOpacity, k);
      m.eyeOpen = lerp(m.eyeOpen, ex.eyeOpen, k); m.eyeX = lerp(m.eyeX, ex.eyeX, k); m.eyeY = lerp(m.eyeY, ex.eyeY, k);
      if (k > 0.5) m.freezeGlance = ex.freezeGlance;
    }
    for (const b of this.blinks) if (t >= b && t < b + 0.16) m.eyeOpen = Math.min(m.eyeOpen, 1 - 0.92 * Math.sin((t - b) / 0.16 * Math.PI));
    m.blobPhase = 0;
    return m;
  }
  exitHadMorph(i) { const prev = this.segs[i - 1]; return ["thinking", "usingTool", "awaitingApproval"].includes(prev.state); }
}
function seedOf(spec, profile) { let h = 0; for (const ch of profile) h = (Math.imul(h, 31) + ch.charCodeAt(0)) | 0; const raw = [...spec.shape].reduce((s, c) => s + c.charCodeAt(0), 0) + [...spec.eyes].reduce((s, c) => s + c.charCodeAt(0), 0) + h; return (raw >>> 0) % 1000003; }
function bot(track, cx, cy, size, t, { alpha = 1, gaze = { x: 0, y: 0 }, dpr = 1, extra = null } = {}) {
  if (alpha <= 0.002) return;
  let m = track.pose(t); if (extra) m = extra(m, t);
  ctx.save(); ctx.globalAlpha = alpha; ctx.translate(cx - size / 2, cy - size / 2);
  drawBot(ctx, track.spec, size, t, { active: track.segs[track.segAt(t)].state === "working", gaze, idleEyes: true, light: true, motion: m, dpr });
  ctx.restore();
}

// ---- cast
const vory = new Track(VORY, "vory-promo", [{ at: -10, state: "guide" }]);
vory.blinks = cues.blinks;
const cast = [
  new Track({ shape: "circle", eyes: "classic", hex: "#111111", finish: "glass" }, "cast-a", [{ at: -10, state: "idle" }]),
  new Track({ shape: "blob", eyes: "curious", hex: "#E07A5F", finish: "flat" }, "cast-b", [{ at: -10, state: "idle" }]),
  new Track({ shape: "triangle", eyes: "bold", hex: "#F5A524", finish: "flat" }, "cast-c", [{ at: -10, state: "idle" }]),
  new Track({ shape: "pill", eyes: "wide", hex: "#F4F4F5", finish: "glass" }, "cast-d", [{ at: -10, state: "idle" }]),
  new Track({ shape: "hexagon", eyes: "round", hex: "#BF5AF2", finish: "glass" }, "cast-e", [{ at: -10, state: "idle" }]),
];
cast[0].finishes = [cues.coin[0]];
cast[2].blinks = [9.9]; cast[4].blinks = [11.2];
const worker = new Track({ shape: "drop", eyes: "tiny", hex: "#2BB5A0", finish: "flat" }, "worker", [
  { at: -10, state: "idle" }, { at: cues.morph[0], state: "thinking" }, { at: cues.morph[1], state: "usingTool" }, { at: 15.5, state: "streaming" },
  { at: cues.morph[2], state: "awaitingApproval" }, { at: cues.tap + 0.25, state: "working" }, { at: 19.4, state: "idle" },
]);
worker.finishes = [cues.coin[1]];

// ---- layout per aspect
const L = {
  916: {
    vory: { x: 540, y: 900, s: 600 }, voryTop: { x: 540, y: 400, s: 260 }, voryEnd: { x: 540, y: 720, s: 520 },
    head: { x: 540, y: 270, size: 108, align: "center", lh: 122 },
    bots: [[240, 1000], [540, 1000], [840, 1000], [390, 1340], [690, 1340]], botS: 230, botLabel: { x: 540, y: 1640, size: 60 },
    chat: { x: 540, w: 960, userY: 600, botY: 1060, botS: 320, cardY: 1400, replyY: 790, subY: 300, subSize: 64 },
    end: { urlY: 1340, betaY: 1450 },
  },
  169: {
    vory: { x: 560, y: 540, s: 560 }, voryTop: { x: 300, y: 540, s: 260 }, voryEnd: { x: 560, y: 520, s: 500 },
    head: { x: 1120, y: 420, size: 104, align: "left", lh: 116 },
    bots: [[700, 560], [930, 560], [1160, 560], [1390, 560], [1620, 560]], botS: 200, botLabel: { x: 1160, y: 860, size: 50 },
    chat: { x: 1300, w: 960, userY: 110, botY: 470, botS: 240, cardY: 870, replyY: 250, subY: 500, subSize: 64, subX: 470 },
    end: { urlY: 470, betaY: 580, x: 1400 },
  },
  11: {
    vory: { x: 540, y: 600, s: 460 }, voryTop: { x: 540, y: 220, s: 180 }, voryEnd: { x: 540, y: 440, s: 380 },
    head: { x: 540, y: 150, size: 78, align: "center", lh: 88 },
    bots: [[150, 680], [345, 680], [540, 680], [735, 680], [930, 680]], botS: 170, botLabel: { x: 540, y: 960, size: 44 },
    chat: { x: 540, w: 960, userY: 150, botY: 500, botS: 210, cardY: 830, replyY: 280, subY: 70, subSize: 48 },
    end: { urlY: 820, betaY: 920 },
  },
}[ASPECT];

// ---- the film
function background(t) {
  ctx.fillStyle = BG; ctx.fillRect(0, 0, W, H);
  const g1 = ctx.createRadialGradient(W * 0.55, H * 0.42, 0, W * 0.55, H * 0.42, Math.max(W, H) * 0.42);
  g1.addColorStop(0, "rgba(62,196,238,0.30)"); g1.addColorStop(1, "rgba(62,196,238,0)");
  const g2 = ctx.createRadialGradient(W * 0.3, H * 0.7, 0, W * 0.3, H * 0.7, Math.max(W, H) * 0.38);
  g2.addColorStop(0, "rgba(59,123,255,0.22)"); g2.addColorStop(1, "rgba(59,123,255,0)");
  ctx.fillStyle = g1; ctx.fillRect(0, 0, W, H); ctx.fillStyle = g2; ctx.fillRect(0, 0, W, H);
}

function voryPlace(t) {
  // Where Vory is: centre (A–B), small at the top (C), off left (D–E), centre again (F). Layout
  // moves, not body moves: the bot itself only blinks, glances and nods.
  const a = L.vory, b = L.voryTop, c = L.voryEnd;
  let x = a.x, y = a.y, s = a.s, alpha = 1;
  if (t >= 8) { const k = inOutCubic(seg(t, 8.0, 8.9)); x = lerp(a.x, b.x, k); y = lerp(a.y, b.y, k); s = lerp(a.s, b.s, k); }
  if (t >= 12) { const k = inExpo(seg(t, 12.0, 12.5)); x = lerp(b.x, -b.s, k); alpha = 1 - k; y = b.y; s = b.s; }
  if (t >= 20) { const k = outExpo(seg(t, 20.2, 21.0)); x = lerp(-c.s, c.x, k); y = c.y; s = c.s; alpha = k > 0 ? 1 : 0; }
  return { x, y, s, alpha };
}

function shotVory(t) {
  const p = voryPlace(t);
  if (p.alpha <= 0) return;
  // Camera for the opening: tight on the eyes, pulling back to the whole bot on its shelf.
  const k = inOutCubic(seg(t, 0.0, 1.9));
  const eyeY = p.y - p.s / 2 + p.s * 0.58;
  const scale = lerp(2.4, 1, k), fx = lerp(p.x, W / 2, k), fy = lerp(eyeY, H / 2, k);
  ctx.save();
  ctx.translate(W / 2, H / 2); ctx.scale(scale, scale); ctx.translate(-fx, -fy);
  const extra = (m, tt) => { if (tt > 22.9 && tt < 23.5) m.dy += 0.015 * Math.sin((tt - 22.9) / 0.6 * Math.PI); return m; };
  const shelfBottom = shelf(p.x, p.y, p.s, "cloud", "Vory", { alpha: p.alpha, scale: p.s / 440 });
  bot(vory, p.x, p.y, p.s, t, { alpha: p.alpha, dpr: Math.ceil(scale), extra });
  // The typed bubble under the shelf.
  const ty = typedLine(t);
  const bubbleA = Math.min(p.alpha, t >= 20 ? inOut(t, 20.4, Infinity, 0.6) : inOut(t, 1.35, 12.0, 0.6, 0.4));
  if (ty.show || t >= 20.4) bubble(p.x, shelfBottom + 30 * (p.s / 440), ty.str, { alpha: bubbleA, size: 34 * Math.max(0.78, p.s / 440), caret: ty.caret, minW: 220 * (p.s / 440), scale: Math.max(0.78, p.s / 440) });
  ctx.restore();
}

function shotHeadline(t) {
  const lines = ["Your agents,", "in your pocket."];
  lines.forEach((s, i) => {
    const a = inOut(t, 4.5 + i * 0.14, 7.9 + i * 0.06, 0.8, 0.4);
    if (a <= 0) return;
    const dy = (1 - a) * 60;
    text(s, L.head.x, L.head.y + i * L.head.lh + dy, { size: L.head.size, weight: 800, align: L.head.align, alpha: a, rounded: true, spacing: -2 });
  });
}

function shotBots(t) {
  cast.forEach((tr, i) => {
    const a = inOut(t, 8.7 + i * 0.12, 11.95 + i * 0.03, 0.8, 0.4);
    if (a <= 0) return;
    const [x, y0] = L.bots[i]; const y = y0 + (1 - a) * 160;
    shelf(x, y, L.botS, tr.spec.shape, "", { alpha: a, scale: 0.7 });
    bot(tr, x, y, L.botS, t, { alpha: a });
  });
  const a = inOut(t, 9.6, 11.9, 0.8, 0.4);
  text("Every agent is a character.", L.botLabel.x, L.botLabel.y + (1 - a) * 40, { size: L.botLabel.size, weight: 700, alpha: a, rounded: true, color: INK });
}

function card(x, y, w, h, alpha, draw) {
  if (alpha <= 0.002) return;
  ctx.save(); ctx.globalAlpha = alpha;
  glassPlate(x, y, w, h, 34, { fill: "rgba(255,255,255,0.86)" });
  draw(); ctx.restore();
}
function button(x, y, w, h, label, { fill = "rgba(0,0,0,0.05)", color = INK, alpha = 1 } = {}) {
  ctx.save(); ctx.globalAlpha = alpha; rr(x, y, w, h, h / 2); ctx.fillStyle = fill; ctx.fill();
  if (fill === "rgba(0,0,0,0.05)") { ctx.strokeStyle = "rgba(0,0,0,0.08)"; ctx.lineWidth = 1.5; ctx.stroke(); }
  text(label, x + w / 2, y + h / 2 + 1, { size: 30, weight: 600, color }); ctx.restore();
}

function shotChat(t) {
  const C = L.chat, x0 = C.x - C.w / 2, sc = ASPECT === "916" ? 1 : 0.9;
  // User bubble
  const ua = inOut(t, 12.4, 19.95, 0.7, 0.4);
  if (ua > 0) bubble(C.x + C.w * 0.22, C.userY + (1 - ua) * 50, "Clean up the old logs on the server.", { alpha: ua, tail: "right", fill: ACCENT, color: "#fff", size: 34 * sc, maxW: 620 * sc, scale: sc });
  // The worker bot on its shelf with its status
  const ba = inOut(t, 12.6, 19.95, 0.8, 0.4);
  const by = C.botY + (1 - ba) * 120;
  const status = t < cues.morph[0] ? "idle" : t < cues.morph[1] ? "Thinking…" : t < 15.5 ? "Using tools" : t < cues.morph[2] ? "Writing…" : t < cues.tap + 0.25 ? "Needs approval" : t < 19.4 ? "Working…" : "Done";
  if (ba > 0) { shelf(C.x, by, C.botS, "drop", "work", { alpha: ba, status, scale: 0.9 * sc }); bot(worker, C.x, by, C.botS, t, { alpha: ba }); }
  // Sub-captions
  const subs = [["It thinks.", 13.1, 14.3], ["It uses its tools.", 14.4, 16.2], ["And it waits for your yes.", 16.5, 18.9], ["Approve from your pocket.", 19.0, 19.95]];
  for (const [s, a0, a1] of subs) { const a = inOut(t, a0, a1, 0.6, 0.3); if (a > 0) text(s, C.subX ?? C.x, C.subY + (1 - a) * 40, { size: C.subSize, weight: 800, alpha: a, rounded: true, align: C.subX ? "left" : "center", spacing: -1 }); }
  // Tool card
  const ta = inOut(t, 14.45, 16.05, 0.7, 0.35);
  const cw = C.w, ch = 170 * sc, cx = x0, cy = C.cardY + (1 - ta) * 80;
  card(cx, cy, cw, ch, ta, () => {
    const done = t > 15.4;
    ctx.save(); ctx.beginPath(); ctx.arc(cx + 56 * sc, cy + 56 * sc, 20 * sc, 0, Math.PI * 2); ctx.fillStyle = done ? GREEN : "rgba(0,0,0,0.12)"; ctx.fill();
    if (done) { ctx.strokeStyle = "#fff"; ctx.lineWidth = 4 * sc; ctx.lineCap = "round"; ctx.beginPath(); ctx.moveTo(cx + 46 * sc, cy + 57 * sc); ctx.lineTo(cx + 53 * sc, cy + 64 * sc); ctx.lineTo(cx + 67 * sc, cy + 48 * sc); ctx.stroke(); }
    else { const a = (t * 6) % (Math.PI * 2); ctx.strokeStyle = "rgba(0,0,0,0.5)"; ctx.lineWidth = 4 * sc; ctx.beginPath(); ctx.arc(cx + 56 * sc, cy + 56 * sc, 12 * sc, a, a + 4); ctx.stroke(); }
    ctx.restore();
    text("terminal", cx + 96 * sc, cy + 56 * sc, { size: 34 * sc, weight: 700, align: "left" });
    text(done ? "1.4s" : "running", cx + cw - 40 * sc, cy + 56 * sc, { size: 26 * sc, weight: 500, color: MUTED, align: "right" });
    ctx.save(); ctx.font = `${26 * sc}px ui-monospace, Menlo, monospace`; ctx.fillStyle = MUTED; ctx.textAlign = "left"; ctx.textBaseline = "middle"; ctx.fillText("du -sh /var/log/* | sort -rh | head", cx + 40 * sc, cy + 112 * sc); ctx.restore();
    if (done) text("10 entries, 4.2 GB total", cx + 40 * sc, cy + 146 * sc, { size: 24 * sc, weight: 500, align: "left" });
  });
  // Approval card
  const aa = inOut(t, 16.2, 19.95, 0.8, 0.4);
  const ah = 330 * sc, ay = C.cardY - (ah - ch) + (1 - aa) * 90;
  const approved = t >= cues.tap + 0.25;
  card(cx, ay, cw, ah, aa, () => {
    // shield + title
    ctx.save(); ctx.fillStyle = approved ? GREEN : ORANGE; rr(cx + 40 * sc, ay + 34 * sc, 34 * sc, 40 * sc, 10 * sc); ctx.fill(); ctx.restore();
    text(approved ? "!" : "!", cx + 57 * sc, ay + 55 * sc, { size: 30 * sc, weight: 800, color: "#fff" });
    text(approved ? "Approved once" : "Approval needed", cx + 92 * sc, ay + 54 * sc, { size: 36 * sc, weight: 700, color: approved ? GREEN : ORANGE, align: "left" });
    text("Delete 34 rotated log files older than 90 days (4.2 GB)", cx + 40 * sc, ay + 118 * sc, { size: 27 * sc, weight: 500, align: "left" });
    ctx.save(); rr(cx + 40 * sc, ay + 150 * sc, cw - 80 * sc, 56 * sc, 14 * sc); ctx.fillStyle = "rgba(0,0,0,0.05)"; ctx.fill();
    ctx.font = `${24 * sc}px ui-monospace, Menlo, monospace`; ctx.fillStyle = INK; ctx.textAlign = "left"; ctx.textBaseline = "middle"; ctx.fillText("find /var/log -name '*.log.*' -mtime +90 -delete", cx + 58 * sc, ay + 178 * sc); ctx.restore();
    const labels = ["Once", "Session", "Always", "Deny"], bw = (cw - 80 * sc - 3 * 16 * sc) / 4, bh = 66 * sc, byy = ay + ah - bh - 34 * sc;
    labels.forEach((l, i) => {
      const bx = cx + 40 * sc + i * (bw + 16 * sc);
      const primary = i === 0;
      button(bx, byy, bw, bh, l, { fill: primary ? (approved ? GREEN : ACCENT) : "rgba(0,0,0,0.05)", color: primary ? "#fff" : INK });
      if (primary && t >= cues.tap && t < cues.tap + 0.6) { // tap ring
        const u = seg(t, cues.tap, cues.tap + 0.6); ctx.save(); ctx.globalAlpha = 1 - u; ctx.strokeStyle = ACCENT; ctx.lineWidth = 6 * (1 - u) + 1;
        rr(bx - 10 * u * 3, byy - 10 * u * 3, bw + 20 * u * 3, bh + 20 * u * 3, bh / 2 + 10 * u * 3); ctx.stroke(); ctx.restore();
      }
    });
  });
  // Reply bubble
  const ra = inOut(t, 19.0, 19.95, 0.7, 0.35);
  if (ra > 0) bubble(C.x - C.w * 0.2, C.replyY + (1 - ra) * 40, "Done — 4.2 GB freed.", { alpha: ra, tail: "left", fill: "#E9E9EB", size: 34 * sc, scale: sc });
}

function shotEnd(t) {
  const ua = inOut(t, 20.9, Infinity, 0.8);
  if (ua > 0) text("vory.dev", L.end.x ?? W / 2, L.end.urlY + (1 - ua) * 50, { size: ASPECT === "11" ? 76 : 92, weight: 800, alpha: ua, rounded: true, align: "center", spacing: -2 });
  const ba = inOut(t, 21.25, Infinity, 0.8);
  if (ba > 0) text("Public beta · TestFlight coming soon", L.end.x ?? W / 2, L.end.betaY + (1 - ba) * 40, { size: ASPECT === "11" ? 34 : 40, weight: 500, color: MUTED, alpha: ba, align: "center" });
}

export function seek(t) {
  background(t);
  shotHeadline(t);
  if (t < 12.6) shotBots(t);
  if (t >= 12 && t < 20.4) shotChat(t);
  shotEnd(t);
  shotVory(t);
}
window.seek = seek;
window.frameData = () => canvas.toDataURL("image/png");
await document.fonts.load('800 40px "SF Rounded"').catch(() => {});
await document.fonts.ready;
window.sceneReady = true;
seek(Number(params.get("t") || 2.9));
