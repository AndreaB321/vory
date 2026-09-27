/*
 * vory-bot.js — the Vory bots, drawn on the web.
 *
 * A faithful port of Shared/BotFace.swift (build 45): the eight body shapes, the eight eye
 * styles, the idle life (blink, double blink, glance, the rare slow blink), the working routines
 * (the 360° coin-turn is the hero), the state holds that morph in place (thinking → pebble,
 * using a tool → stem, waiting for approval → "!"), error, reconnecting, streaming and the guide,
 * plus the painted Liquid Glass finish the app uses wherever real glass cannot render.
 *
 * Locks, as in the app: the body never scales, bounces, hops or pops. It yaws (a coin-turn),
 * rolls a few degrees, shifts a percent or two, and its eyes and the light on its rim do the rest.
 */

export const SHAPES = ["circle", "blob", "square", "pill", "triangle", "hexagon", "cloud", "drop"];
export const EYES = ["classic", "tall", "sleepy", "tiny", "round", "wide", "curious", "bold"];
export const PALETTE = ["#7C5CFF", "#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#64D2FF", "#BF5AF2", "#FFD60A", "#FF6B35", "#5AC8FA", "#FFFFFF", "#8E8E93", "#A2845E"];
export const VORY = { shape: "cloud", eyes: "classic", hex: "#3B7BFF", finish: "glass" };

const TAU = Math.PI * 2;
const clamp01 = (x) => Math.min(1, Math.max(0, x));
const smooth = (x) => { const u = clamp01(x); return u * u * (3 - 2 * u); };
/** Slow start, quick middle, slow stop — a whole turn in one stroke. */
export const stroke = (x) => { const u = clamp01(x); return u * u * u * (u * (u * 6 - 15) + 10); };

// ---------------------------------------------------------------------------------------------
// Geometry. A body is a list of pieces; a piece is a closed polygon (array of {x, y}), always
// wound clockwise on screen so overlapping pieces (the cloud's bumps) union under nonzero fill.

function ellipsePts(x, y, w, h, n = 96) {
  const cx = x + w / 2, cy = y + h / 2, rx = w / 2, ry = h / 2, out = [];
  for (let i = 0; i < n; i++) { const a = i / n * TAU; out.push({ x: cx + Math.cos(a) * rx, y: cy + Math.sin(a) * ry }); }
  return out;
}

function roundedRectPts(x, y, w, h, r, per = 24) {
  r = Math.min(r, w / 2, h / 2);
  const out = [];
  const corner = (cx, cy, a0) => { for (let i = 0; i <= per; i++) { const a = a0 + i / per * (Math.PI / 2); out.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r }); } };
  corner(x + w - r, y + r, -Math.PI / 2);      // top-right
  corner(x + w - r, y + h - r, 0);             // bottom-right
  corner(x + r, y + h - r, Math.PI / 2);       // bottom-left
  corner(x + r, y + r, Math.PI);               // top-left
  return out;
}

function roundedPolygonPts(sides, r, rotation, corner, per = 20) {
  const cx = r.x + r.w / 2, cy = r.y + r.h / 2, radius = Math.min(r.w, r.h) / 2;
  const pts = [];
  for (let i = 0; i < sides; i++) { const a = rotation + i / sides * TAU; pts.push({ x: cx + Math.cos(a) * radius, y: cy + Math.sin(a) * radius }); }
  const towards = (a, b, d) => { const dx = b.x - a.x, dy = b.y - a.y, len = Math.max(1, Math.hypot(dx, dy)); return { x: a.x + dx / len * d, y: a.y + dy / len * d }; };
  const out = [];
  for (let i = 0; i < sides; i++) {
    const prev = pts[(i + sides - 1) % sides], cur = pts[i], next = pts[(i + 1) % sides];
    const inPt = towards(cur, prev, corner), outPt = towards(cur, next, corner);
    for (let k = 0; k <= per; k++) { const u = k / per, m = 1 - u; out.push({ x: m * m * inPt.x + 2 * m * u * cur.x + u * u * outPt.x, y: m * m * inPt.y + 2 * m * u * cur.y + u * u * outPt.y }); }
  }
  return out;
}

function cubic(p0, c1, c2, p1, out, n = 28, includeStart = true) {
  for (let i = includeStart ? 0 : 1; i <= n; i++) {
    const u = i / n, m = 1 - u;
    out.push({ x: m * m * m * p0.x + 3 * m * m * u * c1.x + 3 * m * u * u * c2.x + u * u * u * p1.x, y: m * m * m * p0.y + 3 * m * m * u * c1.y + 3 * m * u * u * c2.y + u * u * u * p1.y });
  }
}

/** The blob's radius at angle `a` as a factor of its base radius. */
const blobWobble = (a, phase) => 1 + 0.055 * Math.sin(3 * a + 0.9 + phase) + 0.035 * Math.sin(5 * a - 0.4 - phase * 0.7);

function restPieces(shape, box, blobPhase) {
  const r = { x: box.x + box.w * 0.04, y: box.y + box.h * 0.04, w: box.w * 0.92, h: box.h * 0.92 };
  const c = { x: r.x + r.w / 2, y: r.y + r.h / 2 };
  switch (shape) {
    case "circle": return [ellipsePts(r.x, r.y, r.w, r.h, 144)];
    case "square": return [roundedRectPts(r.x, r.y, r.w, r.h, r.w * 0.28)];
    case "pill": { const h = r.h * 0.64; return [roundedRectPts(r.x, c.y - h / 2, r.w, h, h / 2)]; }
    case "triangle": {
      const d = r.w * 1.16;
      return [roundedPolygonPts(3, { x: c.x - d / 2, y: r.y + r.h * 0.56 - d / 2, w: d, h: d }, -Math.PI / 2, r.w * 0.24)];
    }
    case "hexagon": return [roundedPolygonPts(6, r, -Math.PI / 2, r.w * 0.10)];
    case "cloud": {
      const w = r.w, h = r.h;
      return [
        roundedRectPts(r.x + w * 0.06, r.y + h * 0.45, w * 0.88, h * 0.42, h * 0.21),
        ellipsePts(r.x + w * 0.16, r.y + h * 0.26, w * 0.36, w * 0.36),
        ellipsePts(r.x + w * 0.38, r.y + h * 0.12, w * 0.42, w * 0.42),
        ellipsePts(r.x + w * 0.58, r.y + h * 0.34, w * 0.30, w * 0.30),
      ];
    }
    case "drop": {
      const w = r.w, h = r.h, radius = w * 0.40;
      const centre = { x: c.x, y: r.y + r.h - radius };
      const top = { x: c.x, y: r.y + h * 0.02 };
      const out = [];
      cubic(top, { x: c.x + w * 0.08, y: r.y + h * 0.30 }, { x: centre.x + radius, y: centre.y - radius * 0.65 }, { x: centre.x + radius, y: centre.y }, out);
      for (let i = 1; i < 48; i++) { const a = i / 48 * Math.PI; out.push({ x: centre.x + Math.cos(a) * radius, y: centre.y + Math.sin(a) * radius }); }
      cubic({ x: centre.x - radius, y: centre.y }, { x: centre.x - radius, y: centre.y - radius * 0.65 }, { x: c.x - w * 0.08, y: r.y + h * 0.30 }, top, out, 28, true);
      out.pop();
      return [out];
    }
    default: { // blob
      const base = Math.min(r.w, r.h) / 2, out = [];
      for (let i = 0; i < 96; i++) { const a = i / 96 * TAU, k = blobWobble(a, blobPhase); out.push({ x: c.x + Math.cos(a) * base * k, y: c.y + Math.sin(a) * base * k }); }
      return [out];
    }
  }
}

function bounds(pieces) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const p of pieces) for (const q of p) { if (q.x < x0) x0 = q.x; if (q.y < y0) y0 = q.y; if (q.x > x1) x1 = q.x; if (q.y > y1) y1 = q.y; }
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

function toPath(pieces) {
  const p = new Path2D();
  for (const piece of pieces) { piece.forEach((q, i) => i ? p.lineTo(q.x, q.y) : p.moveTo(q.x, q.y)); p.closePath(); }
  return p;
}

// A scratch context for point-in-path tests (the radial rings).
let probe = null;
function probeCtx() {
  if (!probe) { const c = document.createElement("canvas"); c.width = c.height = 8; probe = c.getContext("2d"); }
  return probe;
}

/** The outline as points on rays from the box's centre (clockwise from the top): march out for
 *  the last inside sample, then bisect. Every rest shape, the pebble and the stemmed body are
 *  star-shaped from there. */
function radialRing(pieces, box, steps = 144) {
  const ctx = probeCtx(), path = toPath(pieces);
  const cx = box.x + box.w / 2, cy = box.y + box.h / 2, reach = Math.hypot(box.w, box.h) / 2, march = 48;
  const out = [];
  for (let i = 0; i < steps; i++) {
    const a = i / steps * TAU - Math.PI / 2, dx = Math.cos(a), dy = Math.sin(a);
    const inside = (r) => ctx.isPointInPath(path, cx + dx * r, cy + dy * r, "nonzero");
    let lastIn = 0;
    for (let k = 1; k <= march; k++) { const r = reach * k / march; if (inside(r)) lastIn = r; }
    let lo = lastIn, hi = Math.min(reach, lastIn + reach / march);
    for (let j = 0; j < 8; j++) { const mid = (lo + hi) / 2; if (inside(mid)) lo = mid; else hi = mid; }
    out.push({ x: cx + dx * lo, y: cy + dy * lo });
  }
  return out;
}

function blobRing(box, phase, steps = 144) {
  const r = { x: box.x + box.w * 0.04, y: box.y + box.h * 0.04, w: box.w * 0.92, h: box.h * 0.92 };
  const cx = r.x + r.w / 2, cy = r.y + r.h / 2, base = Math.min(r.w, r.h) / 2, out = [];
  for (let i = 0; i < steps; i++) { const a = i / steps * TAU - Math.PI / 2, k = blobWobble(a, phase); out.push({ x: cx + Math.cos(a) * base * k, y: cy + Math.sin(a) * base * k }); }
  return out;
}

/** The polygon on one side of a horizontal line. */
function clipY(poly, y, keepAbove) {
  const out = [], inside = (p) => keepAbove ? p.y <= y : p.y >= y;
  for (let i = 0; i < poly.length; i++) {
    const a = poly[i], b = poly[(i + 1) % poly.length], ia = inside(a), ib = inside(b);
    if (ia) out.push(a);
    if (ia !== ib && b.y !== a.y) out.push({ x: a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y), y });
  }
  return out;
}

/** `steps` points at even spacing along the polygon, starting from the point most directly
 *  above its centroid, so two rings pair top to top and never twist while they blend. */
function resample(poly, steps) {
  if (poly.length < 3) return Array.from({ length: steps }, () => poly[0] || { x: 0, y: 0 });
  const lengths = [0];
  for (let i = 0; i < poly.length; i++) { const a = poly[i], b = poly[(i + 1) % poly.length]; lengths.push(lengths[lengths.length - 1] + Math.hypot(b.x - a.x, b.y - a.y)); }
  const total = Math.max(lengths[lengths.length - 1], 0.001);
  const out = []; let seg = 0;
  for (let k = 0; k < steps; k++) {
    const d = total * k / steps;
    while (seg < poly.length - 1 && lengths[seg + 1] < d) seg++;
    const a = poly[seg], b = poly[(seg + 1) % poly.length], u = (d - lengths[seg]) / Math.max(lengths[seg + 1] - lengths[seg], 0.0001);
    out.push({ x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u });
  }
  const cx = out.reduce((s, p) => s + p.x, 0) / out.length, cy = out.reduce((s, p) => s + p.y, 0) / out.length;
  let best = 0, bestAngle = Infinity;
  out.forEach((p, i) => { const ang = Math.abs(Math.atan2(p.x - cx, -(p.y - cy))); if (ang < bestAngle) { bestAngle = ang; best = i; } });
  return out.slice(best).concat(out.slice(0, best));
}

/** Thinking's hold: a shorter, heavier pebble in the rest shape's bounds. */
function pebblePts(b) {
  const ryBottom = b.h * 0.30, ryTop = b.h * 0.44, cx = b.x + b.w / 2, cy = b.y + b.h - ryBottom, rx = b.w * 0.49, out = [];
  for (let i = 0; i < 96; i++) {
    const a = i / 96 * TAU - Math.PI / 2, co = Math.cos(a), si = Math.sin(a), e = si > 0 ? 2 / 2.8 : 2 / 2.15;
    const x = cx + rx * (co < 0 ? -Math.pow(-co, e) : Math.pow(co, e));
    const y = cy + (si > 0 ? ryBottom : ryTop) * (si < 0 ? -Math.pow(-si, e) : Math.pow(si, e));
    out.push({ x, y });
  }
  return out;
}

/** Using a tool: the crown comes down (the base stays) and a rounded stem rises to the top. */
function stemmedPieces(rest, box) {
  const b = bounds(rest);
  const lowered = rest.map((piece) => piece.map((p) => ({ x: p.x, y: b.y + b.h + (p.y - (b.y + b.h)) * 0.86 })));
  const top = bounds(lowered).y, w = box.w * 0.15, stemTop = box.y + box.h * 0.03;
  lowered.push(roundedRectPts(box.x + box.w / 2 - w / 2, stemTop, w, Math.max(w, top + box.h * 0.14 - stemTop), w / 2));
  return lowered;
}

function exclamationRects(b) {
  const stem = { x: b.x + b.w / 2 - b.w * 0.12, y: b.y + b.h * 0.05, w: b.w * 0.24, h: b.h * 0.52 };
  const d = Math.min(b.w * 0.24, b.h * 0.26);
  return { stem, dot: { x: b.x + b.w / 2 - d / 2, y: b.y + b.h - d, w: d, h: d } };
}

const ringCache = new Map();
function morphRings(shape, box, target) {
  const key = `${shape}|${Math.round(box.w)}|${Math.round(box.h)}|${target}`;
  if (ringCache.has(key)) return ringCache.get(key);
  const origin = { x: 0, y: 0, w: box.w, h: box.h };
  const rest = restPieces(shape, origin, 0), b = bounds(rest);
  const restRing = shape === "blob" ? blobRing(origin, 0) : radialRing(rest, origin);
  let pairs;
  if (target === "pebble") pairs = [[restRing, radialRing([pebblePts(b)], origin)]];
  else if (target === "stem") pairs = [[restRing, radialRing(stemmedPieces(rest, origin), origin)]];
  else if (target === "exclamation") {
    const split = b.y + b.h * 0.66, n = restRing.length;
    const top = resample(clipY(restRing, split, true), n), bottom = resample(clipY(restRing, split, false), n);
    let mark = b;
    if (mark.h < origin.h * 0.72) { const h = origin.h * 0.72; mark = { x: mark.x, y: Math.min(Math.max(origin.y, mark.y + mark.h / 2 - h / 2), origin.y + origin.h - h), w: mark.w, h }; }
    const { stem, dot } = exclamationRects(mark);
    const stemRing = resample(radialRing([roundedRectPts(stem.x, stem.y, stem.w, stem.h, stem.w / 2)], stem), n);
    const dotRing = resample(radialRing([ellipsePts(dot.x, dot.y, dot.w, dot.h)], dot), n);
    pairs = [[top, stemRing], [bottom, dotRing]];
  } else pairs = [[restRing, restRing]];
  ringCache.set(key, pairs);
  return pairs;
}

/** The rest silhouette blended `amount` of the way to `target`: one path that only changes shape. */
function morphedPieces(shape, box, target, amount, blobPhase) {
  let rings = morphRings(shape, box, target).map(([a, b]) => [a, b]);
  if (shape === "blob") {
    const live = blobRing({ x: 0, y: 0, w: box.w, h: box.h }, blobPhase);
    if (target === "exclamation" && rings.length === 2) {
      const split = box.h * 0.66, n = rings[0][0].length;
      rings[0][0] = resample(clipY(live, split, true), n);
      rings[1][0] = resample(clipY(live, split, false), n);
    } else rings[0][0] = live;
  }
  const k = clamp01(amount);
  return rings.map(([a, b]) => a.map((p, i) => ({ x: box.x + p.x + (b[i].x - p.x) * k, y: box.y + p.y + (b[i].y - p.y) * k })));
}

export function bodyPieces(shape, box, t, active, morph = 0, target = "none", phase = null) {
  const blobPhase = phase ?? (active ? t * 0.19 : 0);
  if (target !== "none" && morph > 0.001) return morphedPieces(shape, box, target, morph, blobPhase);
  return restPieces(shape, box, blobPhase);
}

/** Each disjoint piece inset by `d` toward its own centre; overlapping pieces shrink together. */
function rimInner(pieces, d) {
  const groups = [];
  const overlaps = (a, b) => {
    const x0 = Math.max(a.x, b.x), y0 = Math.max(a.y, b.y), x1 = Math.min(a.x + a.w, b.x + b.w), y1 = Math.min(a.y + a.h, b.y + b.h);
    if (x1 <= x0 || y1 <= y0) return false;
    return (x1 - x0) * (y1 - y0) >= 0.2 * Math.min(a.w * a.h, b.w * b.h);
  };
  for (const piece of pieces) {
    const b = bounds([piece]);
    const g = groups.find((g) => overlaps(g.box, b));
    if (g) { const x0 = Math.min(g.box.x, b.x), y0 = Math.min(g.box.y, b.y), x1 = Math.max(g.box.x + g.box.w, b.x + b.w), y1 = Math.max(g.box.y + g.box.h, b.y + b.h); g.box = { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }; g.pieces.push(piece); }
    else groups.push({ box: b, pieces: [piece] });
  }
  const out = [];
  for (const g of groups) {
    const sx = Math.max(0, 1 - 2 * d / Math.max(g.box.w, 1)), sy = Math.max(0, 1 - 2 * d / Math.max(g.box.h, 1));
    const cx = g.box.x + g.box.w / 2, cy = g.box.y + g.box.h / 2;
    for (const piece of g.pieces) out.push(piece.map((p) => ({ x: cx + (p.x - cx) * sx, y: cy + (p.y - cy) * sy })));
  }
  return out;
}

/** Where each shape's bottom edge sits, as a fraction of the square. */
export function baseline(shape) { return { blob: 0.985, pill: 0.795, cloud: 0.825, triangle: 0.815 }[shape] ?? 0.96; }
export function seatDrop(shape) { return 0.985 - baseline(shape); }

const eyeAnchor = (shape) => ({ triangle: [0.64, 0.10], drop: [0.62, 0.11], cloud: [0.58, 0.11], pill: [0.50, 0.13] }[shape] ?? [0.47, 0.13]);

// ---------------------------------------------------------------------------------------------
// Life.

/** Blink (0 open … 1 shut), glance (−1 … 1) and breath as functions of time, offset per bot. */
function liveliness(t, seed, blinkPeriod = 4.3, blinkLength = 0.15, doubleBlinks = true, glancePeriod = 7.0, rare = true) {
  if (!(t > 0)) return { blink: 0, glance: 0, breath: 0 };
  const tt = t + (seed % 17) * 0.37;
  const phase = tt % blinkPeriod;
  let blink = 0;
  if (phase < blinkLength) blink = Math.sin(phase / blinkLength * Math.PI);
  else if (doubleBlinks && Math.floor(tt / blinkPeriod) % 3 === 0 && phase > blinkLength + 0.09 && phase < 2 * blinkLength + 0.09) blink = Math.sin((phase - blinkLength - 0.09) / blinkLength * Math.PI);
  if (rare) {
    const rp = (tt + (seed % 11) * 1.7) % 25;
    if (rp > 9.0 && rp < 9.22) blink = Math.max(blink, Math.sin((rp - 9.0) / 0.22 * Math.PI));
    else if (rp > 17.0 && rp < 17.3) blink = Math.max(blink, 0.3 * Math.sin((rp - 17.0) / 0.3 * Math.PI));
  }
  const gp = (tt * 0.9) % glancePeriod;
  let glance = 0;
  if (gp > 1.2 && gp < 2.6) {
    const u = (gp - 1.2) / 1.4, ease = u < 0.2 ? u / 0.2 : u > 0.8 ? (1 - u) / 0.2 : 1;
    glance = ease * (Math.floor(tt / glancePeriod) % 2 === 0 ? 1 : -1);
  }
  return { blink, glance, breath: 0.5 + 0.5 * Math.sin(tt * TAU / 2.6) };
}

export function stillMotion() {
  return { yaw: 0, roll: 0, dx: 0, dy: 0, eyeOpen: 1, eyeX: 0, eyeY: 0, freezeGlance: false, blinkPeriod: 4.3, blinkLength: 0.15, blobPhase: null, sheen: 0, sheenAngle: -130, morph: 0, morphTarget: "none", eyeOpacity: 1, dim: 0 };
}

export function morphTargetFor(state) { return { awaitingApproval: "exclamation", thinking: "pebble", usingTool: "stem" }[state] ?? "none"; }

/** The pose at time `t` for a bot in `state` (seconds since the state began in `since`). */
export function motion(t, seed, spec, state, since = 0, finishedAt = null, tappedAt = null, group = null) {
  const sign = seed % 2 === 0 ? 1 : -1;
  const rollAmp = spec.shape === "cloud" ? 0.75 : 1, rollCap = spec.shape === "pill" ? 0.052 : 1;
  const roll = (r) => Math.max(-rollCap, Math.min(rollCap, r * rollAmp));
  const m = stillMotion();
  let finishing = null, tapping = null;
  if (finishedAt != null && t - finishedAt >= 0 && t - finishedAt < 1.75) finishing = t - finishedAt;
  else if (tappedAt != null && t - tappedAt >= 0 && t - tappedAt < 0.55) tapping = (t - tappedAt) / 0.55;
  const overlay = () => {
    if (finishing != null) {
      const u = finishing;
      if (u < 1.15) {
        const k = stroke(u / 1.15);
        m.yaw = k * TAU; m.sheen = 0.7 * Math.sin(k * Math.PI); m.sheenAngle = -130 + k * 360;
        if (Math.abs(u - 0.575) < 0.08) m.eyeOpen = Math.min(m.eyeOpen, 0.1);
      } else if (!m.freezeGlance) m.eyeY += 0.5 * Math.sin((u - 1.15) / 0.6 * Math.PI);
    } else if (tapping != null) {
      const u = tapping;
      m.yaw = 0.314 * (u < 0.5 ? stroke(u * 2) : stroke((1 - u) * 2));
      m.sheen = 0.6 * Math.sin(u * Math.PI); m.sheenAngle = -130 + 90 * u;
      if (u > 0.42 && u < 0.68) m.eyeOpen = Math.min(m.eyeOpen, 0.12);
    }
    return m;
  };
  if ((finishing != null || tapping != null) && state === "working") return overlay();

  switch (state) {
    case "idle": break;
    case "guide": {
      const l = (t + (seed % 7)) % 8;
      if (l > 1.0 && l < 2.6) m.eyeY = 0.7 * (l < 1.3 ? smooth((l - 1.0) / 0.3) : l > 2.3 ? 1 - smooth((l - 2.3) / 0.3) : 1);
      if (l > 3.4 && l < 4.3) { const u = (l - 3.4) / 0.9; m.sheen = 0.7 * Math.sin(u * Math.PI); m.sheenAngle = -130 + u * 140; }
      if (l > 5.6 && l < 6.2) m.dy = 0.015 * Math.sin((l - 5.6) / 0.6 * Math.PI);
      break;
    }
    case "streaming": {
      m.eyeOpen = 0.55;
      const u = (t % 2.2) / 2.2;
      m.sheen = 0.7 * Math.sin(u * Math.PI); m.sheenAngle = -130 + u * 160;
      break;
    }
    case "thinking":
      m.morphTarget = "pebble"; m.morph = smooth(since / 0.55);
      m.eyeOpen = 0.42;
      m.roll = roll(0.026 * sign) * smooth(since / 0.3);
      m.blinkPeriod = 2.8; m.blinkLength = 0.22;
      break;
    case "usingTool": {
      m.morphTarget = "stem"; m.morph = smooth(since / 0.6);
      m.eyeX = 0.8; m.eyeY = 0.6; m.freezeGlance = true;
      if (spec.eyes === "classic" || spec.eyes === "bold") m.eyeOpen = 0.92;
      if (since < 0.9) {
        const e = since < 0.25 ? smooth(since / 0.25) : since < 0.65 ? 1 : 1 - smooth((since - 0.65) / 0.25);
        m.roll = roll(0.061 * e); m.dx = 0.012 * e;
      }
      break;
    }
    case "awaitingApproval": {
      m.morphTarget = "exclamation"; m.morph = smooth(since / 0.6);
      m.eyeOpacity = 1 - m.morph; m.freezeGlance = true;
      m.roll = 0.14 * sign * rollAmp * smooth(since / 0.5);
      const l = (t + (seed % 17) * 0.37) % 2.8;
      if (l > 0.15 && l < 0.6) m.dx = 0.02 * Math.sin((l - 0.15) / 0.45 * Math.PI) * sign;
      break;
    }
    case "error":
      m.eyeOpen = 0.08; m.eyeY = 1.0; m.freezeGlance = true;
      m.roll = roll(-0.07) * smooth(since / 0.5);
      m.dim = smooth(since / 0.6);
      break;
    case "reconnecting":
      m.eyeX = 1.8 * Math.sin(t * TAU / 2.2) * smooth(since / 0.4); m.freezeGlance = true;
      break;
    case "working": {
      const block = 3.2;
      const tt = group ? t : t + (seed % 47) * 0.31;
      const index = Math.floor(tt / block), u = tt % block;
      if (group && group.count > 1 && index % group.count !== group.index) break;
      const order = [0, 5, 1, 8, 2, 6, 3, 7, 4, 9];
      let kind = order[(((index + seed) % 10) + 10) % 10];
      if (spec.shape === "triangle" && kind === 3) kind = 4;
      switch (kind) {
        case 0: if (u < 1.15) { const k = stroke(u / 1.15); m.yaw = k * TAU; m.sheen = 0.7 * Math.sin(k * Math.PI); m.sheenAngle = -130 + k * 360; } break;
        case 1: if (u < 1.0) { m.yaw = 0.45 * Math.sin(u * Math.PI) * sign; m.eyeX = 0.9 * Math.sin(Math.min(1, u + 0.06) * Math.PI) * sign; } break;
        case 2: if (u < 1.1) m.roll = roll(0.07 * Math.sin(u / 1.1 * TAU) * (1 - smooth((u - 0.7) / 0.4))); break;
        case 3: if (u < 0.8) m.dy = (spec.shape === "drop" ? 0.015 : 0.02) * Math.abs(Math.sin(u / 0.8 * TAU)); break;
        case 4: if (u < 0.9) { const e = Math.sin(u / 0.9 * Math.PI); m.roll = roll(0.061 * e * sign); m.dx = 0.012 * e * sign; } break;
        case 5: if (u < 0.9) m.eyeY = -0.7 * Math.sin(u / 0.9 * Math.PI); break;
        case 6:
          if (u < 0.18) m.eyeOpen = 1 - 0.58 * smooth(u / 0.18);
          else if (u < 0.58) m.eyeOpen = 0.42;
          else if (u < 0.8) m.eyeOpen = 0.42 + 0.5 * smooth((u - 0.58) / 0.22);
          break;
        case 7: if (u < 1.2) { const e = Math.sin(u / 1.2 * TAU) * sign; m.eyeX = e; m.yaw = 0.14 * e; } break;
        case 8: if (u < 0.9) { const k = u / 0.9; m.sheen = 0.7 * Math.sin(k * Math.PI); m.sheenAngle = -130 + k * 140; } break;
        default:
          if (u < 0.7) { const k = stroke(u / 0.7); m.yaw = k * Math.PI; m.sheen = 0.6 * Math.sin(k * Math.PI); m.sheenAngle = -130 + k * 180; }
          else if (u < 1.25) { m.yaw = Math.PI; if (u > 0.85 && u < 1.0) m.eyeOpen = 0.1; }
          else if (u < 1.95) { const k = stroke((u - 1.25) / 0.7); m.yaw = Math.PI + k * Math.PI; m.sheen = 0.6 * Math.sin(k * Math.PI); m.sheenAngle = 50 + k * 180; }
      }
      break;
    }
  }
  return overlay();
}

/** A still pose for a widget-style render: the squint, the held lean, the lowered eyes. */
export function widgetPose(phase, attention = false) {
  const m = stillMotion();
  if (attention) { m.morphTarget = "exclamation"; m.morph = 1; m.eyeOpacity = 0; m.roll = 0.14; return m; }
  switch (phase) {
    case "thinking": case "working": m.morphTarget = "pebble"; m.morph = 1; m.eyeOpen = 0.42; break;
    case "streaming": m.eyeOpen = 0.55; break;
    case "tool": m.morphTarget = "stem"; m.morph = 1; m.eyeX = 0.8; m.eyeY = 0.6; break;
    case "error": case "failed": m.eyeOpen = 0.08; m.eyeY = 1.0; m.roll = -0.07; m.dim = 1; break;
  }
  return m;
}

// ---------------------------------------------------------------------------------------------
// Painting.

export function isLight(hex) {
  const v = parseInt(hex.replace("#", ""), 16); if (Number.isNaN(v)) return false;
  const r = ((v >> 16) & 255) / 255, g = ((v >> 8) & 255) / 255, b = (v & 255) / 255;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.82;
}
function rgb(hex) { const v = parseInt(hex.replace("#", ""), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; }
const rgba = (hex, a) => { const [r, g, b] = rgb(hex); return `rgba(${r},${g},${b},${a})`; };
const white = (a) => `rgba(255,255,255,${a})`;
const black = (a) => `rgba(0,0,0,${a})`;
const INK = "rgba(13,13,18,";
const COOL = "rgba(184,194,219,";

const specSeed = (spec) => [...spec.shape].reduce((s, c) => s + c.charCodeAt(0), 0) + [...spec.eyes].reduce((s, c) => s + c.charCodeAt(0), 0);

/** The eyes for a frame: one path (both eyes) and whether it is stroked (sleepy lids). */
export function eyePath(spec, size, t, active, gaze = { x: 0, y: 0 }, strain = false, glanceFree = true, m = stillMotion()) {
  const s = size, seed = specSeed(spec), tiny = spec.eyes === "tiny";
  const live = liveliness(active ? t : 0, seed, m.blinkPeriod, tiny ? 0.09 : m.blinkLength, !(tiny && s < 32), 7.0, m.blinkPeriod === 4.3);
  const [ay, spread] = eyeAnchor(spec.shape);
  const dx = s * spread, wander = glanceFree && !m.freezeGlance;
  const gx = gaze.x + m.eyeX, gy = gaze.y + m.eyeY;
  const cx = size / 2 + (wander ? live.glance * s * 0.06 : 0) + gx * s * 0.06;
  const cy = s * ay + gy * s * 0.07;
  const open = Math.min(1 - live.blink * 0.92, strain ? 0.42 : 1, m.eyeOpen);
  const path = new Path2D();
  const eye = (x, w, h, round) => {
    const hh = Math.max(s * 0.025, h * open);
    if (round && open > 0.5) path.ellipse(x, cy, w / 2, hh / 2, 0, 0, TAU);
    else { const r = Math.min(w, hh) / 2; path.roundRect(x - w / 2, cy - hh / 2, w, hh, r); }
  };
  if (spec.eyes === "sleepy") {
    const weight = active ? 0.5 + 0.5 * Math.sin(t * Math.PI / 2.15) : 0;
    for (const x of [cx - dx, cx + dx]) {
      path.moveTo(x - s * 0.075, cy - s * 0.01);
      path.quadraticCurveTo(x, cy + s * (0.05 + 0.025 * weight), x + s * 0.075, cy - s * 0.01);
    }
    return { path, stroked: true, cy };
  }
  switch (spec.eyes) {
    case "tall": eye(cx - dx, s * 0.085, s * 0.30, false); eye(cx + dx, s * 0.085, s * 0.30, false); break;
    case "tiny": eye(cx - dx * 0.8, s * 0.07, s * 0.07, true); eye(cx + dx * 0.8, s * 0.07, s * 0.07, true); break;
    case "round": eye(cx - dx, s * 0.13, s * 0.13, true); eye(cx + dx, s * 0.13, s * 0.13, true); break;
    case "wide": eye(cx - dx, s * 0.16, s * 0.075, false); eye(cx + dx, s * 0.16, s * 0.075, false); break;
    case "curious": {
      const late = wander ? liveliness(active ? t - 0.06 : 0, seed, m.blinkPeriod).glance * s * 0.06 : 0;
      const rx = size / 2 + late + gx * s * 0.06 + dx;
      eye(cx - dx, s * 0.09, s * 0.09, true); eye(rx, s * 0.085, s * 0.20, false); break;
    }
    case "bold": eye(cx - dx, s * 0.13, s * 0.27, false); eye(cx + dx, s * 0.13, s * 0.27, false); break;
    default: eye(cx - dx, s * 0.10, s * 0.22, false); eye(cx + dx, s * 0.10, s * 0.22, false);
  }
  return { path, stroked: false, cy };
}

// Offscreen layers (the app's drawLayer): reused per size.
const layerPool = new Map();
function layer(size, dpr) {
  const key = `${size}|${dpr}`;
  let l = layerPool.get(key);
  if (!l) { l = document.createElement("canvas"); l.width = l.height = Math.ceil(size * dpr); l._ctx = l.getContext("2d"); layerPool.set(key, l); }
  const c = l._ctx; c.setTransform(1, 0, 0, 1, 0, 0); c.clearRect(0, 0, l.width, l.height); c.globalCompositeOperation = "source-over"; c.globalAlpha = 1; c.setTransform(dpr, 0, 0, dpr, 0, 0);
  return l;
}

function fillPieces(ctx, pieces, style) { ctx.fillStyle = style; ctx.fill(toPath(pieces), "nonzero"); }

function drawGlassBody(ctx, pieces, hex, size, dpr, light, dim, pale) {
  const lit = 1 - dim, s = size, box = { x: 0, y: 0, w: size, h: size };
  // Shadow + the tinted plate.
  ctx.save();
  ctx.shadowColor = black(light ? 0.12 : 0.28); ctx.shadowBlur = s * 0.05 * dpr; ctx.shadowOffsetY = s * 0.03 * dpr;
  const g = ctx.createLinearGradient(0, box.y, 0, box.y + box.h);
  g.addColorStop(0, rgba(hex, light ? 0.82 : 0.92)); g.addColorStop(1, rgba(hex, light ? 0.68 : 0.62));
  fillPieces(ctx, pieces, g);
  ctx.restore();
  // Specular crown.
  ctx.save(); ctx.clip(toPath(pieces), "nonzero");
  const crown = pale ? `${COOL}${0.5 * lit})` : white((light ? 0.5 : 0.42) * lit);
  const cg = ctx.createLinearGradient(0, box.y, 0, box.h * 0.5);
  cg.addColorStop(0, crown); cg.addColorStop(0.5, pale ? `${COOL}${0.05 * lit})` : white((light ? 0.05 : 0.042) * lit)); cg.addColorStop(1, white(0));
  ctx.fillStyle = cg; ctx.fillRect(0, 0, size, size); ctx.restore();
  // Rim: the body minus the body inset, lit top-left, dark underneath.
  const L = layer(size, dpr), lc = L._ctx;
  const rg = lc.createLinearGradient(0, 0, size, size);
  rg.addColorStop(0, white(0.9 * lit)); rg.addColorStop(0.5, white(0.15 * lit)); rg.addColorStop(1, black(light ? 0.10 : 0.28));
  fillPieces(lc, pieces, rg);
  lc.globalCompositeOperation = "destination-out"; fillPieces(lc, rimInner(pieces, s * 0.0225), "#000");
  ctx.drawImage(L, 0, 0, size, size);
}

function drawInnerStroke(ctx, pieces, size, dpr) {
  const L = layer(size, dpr), lc = L._ctx;
  fillPieces(lc, pieces, "rgba(208,208,213,0.4)");
  lc.globalCompositeOperation = "destination-out"; fillPieces(lc, rimInner(pieces, 1), "#000");
  ctx.drawImage(L, 0, 0, size, size);
}

function drawSheen(ctx, pieces, size, dpr, sheen, angle, glass) {
  const L = layer(size, dpr), lc = L._ctx, s = size;
  const a = angle * Math.PI / 180, px = s / 2 + Math.cos(a) * s * 0.47, py = s / 2 + Math.sin(a) * s * 0.47;
  const g = lc.createRadialGradient(px, py, 0, px, py, s * 0.55);
  const peak = (glass ? 0.95 : 0.55) * sheen;
  g.addColorStop(0, white(peak)); g.addColorStop(0.4, white(peak * 0.45)); g.addColorStop(1, white(0));
  fillPieces(lc, pieces, g);
  lc.globalCompositeOperation = "destination-out"; fillPieces(lc, rimInner(pieces, s * 0.025), "#000");
  ctx.drawImage(L, 0, 0, size, size);
}

/**
 * Draw a bot into a square canvas context of `size` CSS pixels (already scaled by `dpr`).
 * Applies the view's transforms (yaw as a coin-turn, roll, the small offsets) itself.
 */
export function drawBot(ctx, spec, size, t, { active = false, gaze = { x: 0, y: 0 }, idleEyes = true, glanceFree = true, light = true, motion: m = stillMotion(), dpr = 1, strain = false } = {}) {
  const s = size, c = size / 2;
  ctx.save();
  ctx.translate(m.dx * s, m.dy * s);
  ctx.translate(c, c); ctx.rotate(m.roll); ctx.scale(Math.cos(m.yaw), 1); ctx.translate(-c, -c);
  const box = { x: 0, y: 0, w: s, h: s };
  const pieces = bodyPieces(spec.shape, box, t, active, m.morph, m.morphTarget, m.blobPhase);
  const pale = isLight(spec.hex), glass = spec.finish === "glass";
  if (glass) drawGlassBody(ctx, pieces, spec.hex, s, dpr, light, m.dim, pale);
  else {
    const g = ctx.createLinearGradient(0, 0, 0, s); g.addColorStop(0, rgba(spec.hex, 1)); g.addColorStop(1, rgba(spec.hex, 0.84));
    fillPieces(ctx, pieces, g);
    ctx.save(); ctx.clip(toPath(pieces), "nonzero");
    const crown = pale ? `${COOL}${0.5 * (1 - m.dim)})` : white(0.22 * (1 - m.dim));
    const cg = ctx.createLinearGradient(0, 0, 0, s * 0.55); cg.addColorStop(0, crown); cg.addColorStop(1, white(0));
    ctx.fillStyle = cg; ctx.fillRect(0, 0, s, s); ctx.restore();
  }
  if (pale) drawInnerStroke(ctx, pieces, s, dpr);
  if (m.dim > 0.01) { ctx.save(); ctx.clip(toPath(pieces), "nonzero"); ctx.fillStyle = black(0.22 * m.dim); ctx.fillRect(0, 0, s, s); ctx.restore(); }
  if (m.sheen > 0.01) drawSheen(ctx, pieces, s, dpr, m.sheen * (1 - m.dim), m.sheenAngle, glass);

  // Eyes, in their own layer so the "!"'s fade never leaks.
  const eyes = eyePath(spec, s, t, active || idleEyes, gaze, strain, glanceFree, m);
  if (m.eyeOpacity > 0.005) {
    const L = layer(s, dpr), lc = L._ctx;
    const ink = `${INK}${glass ? 0.9 : 1})`;
    if (eyes.stroked) { lc.strokeStyle = ink; lc.lineWidth = s * 0.045; lc.lineCap = "round"; lc.stroke(eyes.path); }
    else {
      lc.fillStyle = ink; lc.fill(eyes.path);
      if (glass) {
        lc.save(); lc.clip(eyes.path);
        const eg = lc.createLinearGradient(0, eyes.cy - s * 0.15, 0, eyes.cy + s * 0.15);
        eg.addColorStop(0, white(0.55)); eg.addColorStop(1, white(0));
        lc.strokeStyle = eg; lc.lineWidth = s * 0.03; lc.stroke(eyes.path); lc.restore();
      }
    }
    ctx.save(); ctx.globalAlpha = m.eyeOpacity; ctx.drawImage(L, 0, 0, s, s); ctx.restore();
  }
  ctx.restore();
}

// ---------------------------------------------------------------------------------------------
// The bot as a live element (BotFaceView).

const reduceMotionQuery = typeof matchMedia === "function" ? matchMedia("(prefers-reduced-motion: reduce)") : { matches: false, addEventListener() {} };
const darkQuery = typeof matchMedia === "function" ? matchMedia("(prefers-color-scheme: dark)") : { matches: false, addEventListener() {} };

/** What every bot on the page reacts to together: the last scroll (the eyes follow it). */
export const ambient = {
  gaze: { x: 0, y: 0 }, enabled: true, scrolling: false, _lastAt: 0, _decay: null,
  scrolled(dy) {
    if (Math.abs(dy) <= 0.5) return;
    const now = performance.now();
    if (this.enabled && now - this._lastAt > 60) {
      const y = Math.max(-1, Math.min(1, this.gaze.y * 0.6 + (-dy) / 40));
      if (Math.abs(y - this.gaze.y) > 0.03) this.gaze = { x: this.gaze.x, y };
      this._lastAt = now;
    }
    this.scrolling = true;
    clearTimeout(this._decay);
    this._decay = setTimeout(() => { this.gaze = { x: 0, y: 0 }; this.scrolling = false; }, 450);
  },
};

const bots = new Set();
let ticking = false;
function tick() {
  const now = performance.now() / 1000;
  for (const b of bots) b._frame(now);
  requestAnimationFrame(tick);
}

export class Bot {
  /**
   * @param {HTMLCanvasElement} canvas  square; sized to `size` CSS px
   * @param {object} spec  {shape, eyes, hex, finish}
   * @param {object} opts  {size, state, profile, light: "auto"|true|false, group: {index,count}, still}
   */
  constructor(canvas, spec, { size = 78, state = "idle", profile = "", light = "auto", group = null, still = false, active = false } = {}) {
    this.canvas = canvas; this.spec = { ...spec }; this.size = size; this.profile = profile; this.light = light; this.group = group; this.still = still;
    this._state = active && state === "idle" ? "working" : state;
    this.gaze = { x: 0, y: 0 }; this._gazeFrom = { x: 0, y: 0 }; this._gazeShown = { x: 0, y: 0 }; this._gazeAt = -1;
    this._stateSince = performance.now() / 1000; this._exitPose = stillMotion(); this._exitAt = -1; this._shown = stillMotion();
    this._finishedAt = null; this._tappedAt = null;
    this._blobOffset = 0; this._blobFrozen = 0; this._blobRunning = false;
    this._visible = true; this._lastDraw = -1; this._eyesBusy = false; this._eyesCheckAt = 0;
    this._pointerGaze = { x: 0, y: 0 };
    this.squint = false; this.thinking = false;
    this._resize();
    if (typeof IntersectionObserver === "function") { this._io = new IntersectionObserver((es) => { this._visible = es[0].isIntersecting; }, { rootMargin: "80px" }); this._io.observe(canvas); }
    bots.add(this);
    if (!ticking) { ticking = true; requestAnimationFrame(tick); }
    this._blobSync(true);
    this._frame(performance.now() / 1000, true);
  }

  destroy() { bots.delete(this); this._io?.disconnect(); }

  get seed() {
    let h = 0; for (const ch of this.profile) h = (Math.imul(h, 31) + ch.charCodeAt(0)) | 0;
    const raw = specSeed(this.spec) + h;
    return (raw >>> 0) % 1000003;
  }
  get state() { return this.thinking ? "thinking" : this._state; }
  set state(s) { if (s === this._state) return; this._state = s; this._changed(); }
  setSpec(spec) { this.spec = { ...this.spec, ...spec }; this._lastDraw = -1; }
  setSize(size) { this.size = size; this._resize(); this._lastDraw = -1; }
  finishTurn() { this._finishedAt = performance.now() / 1000; }
  tap() { this._tappedAt = performance.now() / 1000; }
  setGaze(g) { this._gazeFrom = this._gazeShown; this.gaze = g; this._gazeAt = performance.now() / 1000; }

  _changed() {
    const now = performance.now() / 1000;
    this._exitPose = { ...this._shown }; this._exitAt = now;
    this._stateSince = this._exitPose.morph > 0.01 ? now + 0.4 : now;
    this._blobSync();
  }
  _blobSync(initial = false) {
    const running = this.state === "working" && !reduceMotionQuery.matches;
    const now = performance.now() / 1000 * 0.19;
    if (running && (!this._blobRunning || initial)) this._blobOffset = this._blobFrozen - now;
    else if (!running && this._blobRunning) this._blobFrozen = now + this._blobOffset;
    this._blobRunning = running;
  }
  _resize() {
    const dpr = Math.min(3, window.devicePixelRatio || 1);
    this._dpr = dpr;
    this.canvas.width = Math.round(this.size * dpr); this.canvas.height = Math.round(this.size * dpr);
    this.canvas.style.width = `${this.size}px`; this.canvas.style.height = `${this.size}px`;
  }

  /** The frame's pose: the state's motion, blended for 0.4 s from the pose on screen at the last change. */
  _pose(t, now) {
    const since = now - this._stateSince, state = this.state;
    const finished = this._finishedAt != null && now - this._finishedAt < 1.8 ? this._finishedAt : null;
    const tapped = this._tappedAt != null && now - this._tappedAt < 0.6 ? this._tappedAt : null;
    const group = this.group && this.group.count > 1 ? this.group : null;
    let m = motion(t, this.seed, this.spec, state, since, finished, tapped, group);
    const back = now - this._exitAt;
    const rm = reduceMotionQuery.matches;
    if (back < 0.4 && !rm) {
      const ex = this._exitPose, k = 1 - smooth(back / 0.4), lerp = (a, b) => a + (b - a) * k;
      if (ex.morph > 0.001) { m.morphTarget = ex.morphTarget; m.morph = ex.morph * k; }
      m.roll = lerp(m.roll, ex.roll); m.dim = lerp(m.dim, ex.dim); m.eyeOpacity = lerp(m.eyeOpacity, ex.eyeOpacity);
      m.eyeOpen = lerp(m.eyeOpen, ex.eyeOpen); m.eyeX = lerp(m.eyeX, ex.eyeX); m.eyeY = lerp(m.eyeY, ex.eyeY);
      if (k > 0.5) m.freezeGlance = ex.freezeGlance;
    }
    if (this.squint) { m.eyeOpen = Math.min(m.eyeOpen, 0.42); m.blinkPeriod = 2.8; m.blinkLength = 0.22; }
    this._blobSync();
    m.blobPhase = this._blobRunning ? t * 0.19 + this._blobOffset : this._blobFrozen;
    if (rm) {
      const end = motion(t, this.seed, this.spec, state, 10, null, null, group);
      m.yaw = 0; m.roll = end.roll; m.dx = 0; m.dy = 0; m.sheen = 0;
      m.morphTarget = end.morphTarget; m.morph = end.morphTarget === "none" ? 0 : 1;
      m.eyeOpacity = end.morphTarget === "exclamation" ? 0 : 1;
      m.dim = state === "error" ? 1 : 0;
    }
    if (this.size < 32) { m.yaw = 0; m.dy = 0; m.morph = 0; m.morphTarget = "none"; m.eyeOpacity = 1; }
    return m;
  }

  _frame(now, force = false) {
    if (!this._visible && !force) return;
    const state = this.state;
    const finished = this._finishedAt != null && now - this._finishedAt < 1.8;
    const tapped = this._tappedAt != null && now - this._tappedAt < 0.6;
    const leaving = now - this._exitAt < 0.5;
    const gazeMoving = now - this._gazeAt < 0.4;
    const animating = state !== "idle" || finished || tapped || leaving;
    // Idle bots redraw only while the eyes have something to do.
    if (!animating && !this.still && !gazeMoving && !force && ambient.gaze.y === 0) {
      if (now - this._eyesCheckAt > (this._eyesBusy ? 0.12 : 0.25)) {
        this._eyesCheckAt = now;
        const seed = specSeed(this.spec);
        this._eyesBusy = [0, 0.12, 0.24].some((dt) => { const l = liveliness(now + dt, seed); return l.blink > 0.01 || l.glance !== 0; });
      }
      if (!this._eyesBusy) return;
    } else if (!animating && this.still && !force && this._lastDraw > 0) return;
    if (now - this._lastDraw < 1 / 61 && !force) return;
    this._lastDraw = now;

    const u = clamp01((now - this._gazeAt) / 0.35), ease = u * u * (3 - 2 * u);
    const g0 = { x: this._gazeFrom.x + (this.gaze.x - this._gazeFrom.x) * ease, y: this._gazeFrom.y + (this.gaze.y - this._gazeFrom.y) * ease };
    this._gazeShown = g0;
    const listens = this.size >= 32 && ambient.enabled;
    const g = { x: Math.max(-1, Math.min(1, g0.x + (listens ? ambient.gaze.x : 0))), y: Math.max(-1, Math.min(1, g0.y + (listens ? ambient.gaze.y : 0))) };
    const m = this._pose(now, now);
    this._shown = m;
    const ctx = this.canvas.getContext("2d"), dpr = this._dpr;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const light = this.light === "auto" ? !darkQuery.matches : !!this.light;
    drawBot(ctx, this.spec, this.size, now, { active: state === "working", gaze: g, idleEyes: !this.still, glanceFree: true, light, motion: m, dpr });
  }
}

/** Paint one still frame of a bot (a widget pose, a thumbnail) into a canvas. */
export function paintStill(canvas, spec, size, m = stillMotion(), light = "auto") {
  const dpr = Math.min(3, window.devicePixelRatio || 1);
  canvas.width = Math.round(size * dpr); canvas.height = Math.round(size * dpr);
  canvas.style.width = `${size}px`; canvas.style.height = `${size}px`;
  const ctx = canvas.getContext("2d"); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  drawBot(ctx, spec, size, 0, { active: false, idleEyes: false, light: light === "auto" ? !darkQuery.matches : !!light, motion: m, dpr });
}

// Scroll gaze for every bot on the page, like the app's lists.
if (typeof window !== "undefined") {
  let lastY = window.scrollY;
  window.addEventListener("scroll", () => { const y = window.scrollY; ambient.scrolled(y - lastY); lastY = y; }, { passive: true });
  darkQuery.addEventListener?.("change", () => { for (const b of bots) b._lastDraw = -1; });
}
