// Synthesized score + sound design for the Vory promo. Pure JavaScript, no samples, no licences.
// 120 BPM, warm pad (Cmaj7 · Am7 · Fmaj7 · G6 · Cmaj7), a plucked 8th-note arpeggio, a soft pulse
// from the second beat on, and glass ticks cued to blinks, turns, typing, the tap and the finish.
//   node tools/music.mjs out/music.wav
import { writeFileSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const cues = JSON.parse(readFileSync(join(here, "..", "cues.json"), "utf8"));
const out = process.argv[2] || join(here, "..", "out", "music.wav");

const SR = 48000, DUR = cues.duration + 0.6, N = Math.floor(SR * DUR);
const L = new Float64Array(N), R = new Float64Array(N);
const TAU = Math.PI * 2;
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));

function add(at, dur, fn, pan = 0) {
  const s0 = Math.floor(at * SR), n = Math.floor(dur * SR);
  const gl = Math.cos((pan + 1) * Math.PI / 4), gr = Math.sin((pan + 1) * Math.PI / 4);
  for (let i = 0; i < n; i++) { const k = s0 + i; if (k < 0 || k >= N) continue; const v = fn(i / SR, i / n); L[k] += v * gl; R[k] += v * gr; }
}
const env = (t, a, d, s, r, dur) => t < a ? t / a : t < a + d ? 1 - (1 - s) * (t - a) / d : t < dur - r ? s : s * Math.max(0, (dur - t) / r);

// ---- harmony (Hz)
const n = (name) => { const m = name.match(/^([A-G])(#?)(\d)$/); const idx = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]] + (m[2] ? 1 : 0); return 440 * Math.pow(2, (idx - 9) / 12 + (Number(m[3]) - 4)); };
const chords = [
  { at: 0, notes: ["C3", "E3", "G3", "B3"] },
  { at: 8, notes: ["A2", "C3", "E3", "G3"] },
  { at: 12, notes: ["F2", "A2", "C3", "E3"] },
  { at: 16, notes: ["G2", "B2", "D3", "E3"] },
  { at: 20, notes: ["C3", "E3", "G3", "B3"] },
];
const chordAt = (t) => { let c = chords[0]; for (const x of chords) if (x.at <= t) c = x; return c; };

// ---- pad: two slightly detuned voices per note, slow attack, soft harmonics
for (let i = 0; i < chords.length; i++) {
  const c = chords[i], end = i + 1 < chords.length ? chords[i + 1].at : cues.duration, dur = end - c.at + 1.2;
  c.notes.forEach((name, j) => {
    const f = n(name);
    add(c.at - 0.2, dur, (t) => {
      const e = env(t, 1.4, 0.5, 0.85, 1.2, dur);
      const v = Math.sin(TAU * f * t) * 0.55 + Math.sin(TAU * (f + 0.35) * t) * 0.45 + Math.sin(TAU * 2 * f * t) * 0.12 + Math.sin(TAU * 3 * f * t) * 0.03;
      return v * e * 0.045;
    }, (j - 1.5) * 0.25);
  });
}

// ---- plucks: 8th notes, chord tones climbing two octaves up, alternating pan
const step = 0.25;
for (let t = 0.5, k = 0; t < cues.duration - 0.6; t += step, k++) {
  const c = chordAt(t), tones = c.notes.map(n);
  const pattern = [0, 1, 2, 3, 2, 1, 3, 2];
  const f = tones[pattern[k % pattern.length]] * (k % 16 < 8 ? 2 : 4);
  const swell = t < 4 ? 0.5 + 0.5 * (t / 4) : 1;
  add(t, 0.6, (tt) => { const e = Math.exp(-tt / 0.22) * (1 - Math.exp(-tt / 0.004)); return (Math.sin(TAU * f * tt) * 0.7 + Math.sin(TAU * 2 * f * tt) * 0.25 * Math.exp(-tt / 0.08) + Math.sin(TAU * 3 * f * tt) * 0.08) * e * 0.11 * swell; }, k % 2 ? 0.35 : -0.35);
}

// ---- pulse: a soft low thump on beats 1 and 3 from the second beat of the film (8 s) on
for (let t = 8; t < cues.duration - 1.5; t += 1) {
  add(t, 0.25, (tt) => { const f = 52 + 40 * Math.exp(-tt / 0.03); return Math.sin(TAU * f * tt) * Math.exp(-tt / 0.09) * 0.32; });
}

// ---- sound design
let seed = 7; const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff * 2 - 1; };
const tick = (at, f = 2200, amp = 0.07, dur = 0.05) => add(at, dur, (t) => (Math.sin(TAU * f * t) * 0.8 + rnd() * 0.2) * Math.exp(-t / 0.012) * amp);
const glassPing = (at, f = 1760, amp = 0.09) => add(at, 0.5, (t) => (Math.sin(TAU * f * t) + 0.4 * Math.sin(TAU * f * 2.01 * t) + 0.15 * Math.sin(TAU * f * 3.02 * t)) * Math.exp(-t / 0.13) * amp);
const whoosh = (at, dur = 0.7, amp = 0.05) => { let lp = 0; add(at, dur, (t, u) => { lp += (rnd() - lp) * 0.08; const e = Math.sin(Math.PI * u) ** 2; return lp * e * amp * 4; }); };

for (const b of cues.blinks) tick(b, 2400, 0.05, 0.04);
for (const line of cues.typing) for (let i = 0; i < line.text.length; i++) if (line.text[i] !== " ") tick(line.at + i / cues.cps, 1500 + (i % 3) * 120, 0.018, 0.02);
for (const c of cues.coin) { whoosh(c, 0.9, 0.045); glassPing(c + 0.95, 2093, 0.07); }
for (const m of cues.morph) add(m, 0.5, (t) => Math.sin(TAU * 196 * t) * Math.exp(-t / 0.18) * (1 - Math.exp(-t / 0.02)) * 0.07);
for (const r of cues.rises) whoosh(r - 0.05, 0.45, 0.02);
add(cues.tap, 0.12, (t) => Math.sin(TAU * 880 * t) * Math.exp(-t / 0.03) * 0.12);
add(cues.success, 0.35, (t) => Math.sin(TAU * 659.25 * t) * Math.exp(-t / 0.12) * 0.1);
add(cues.success + 0.13, 0.5, (t) => Math.sin(TAU * 987.77 * t) * Math.exp(-t / 0.16) * 0.1);
glassPing(cues.duration - 1.4, 1046.5, 0.06);

// ---- master: gentle fade at the end, normalise
for (let i = 0; i < N; i++) { const t = i / SR; const fade = t > cues.duration - 1.0 ? clamp((cues.duration + 0.5 - t) / 1.5, 0, 1) : 1; L[i] *= fade; R[i] *= fade; }
let peak = 0; for (let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
const g = 0.89 / peak;
const buf = Buffer.alloc(44 + N * 4);
buf.write("RIFF", 0); buf.writeUInt32LE(36 + N * 4, 4); buf.write("WAVE", 8); buf.write("fmt ", 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34); buf.write("data", 36); buf.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) { buf.writeInt16LE(Math.round(clamp(L[i] * g, -1, 1) * 32767), 44 + i * 4); buf.writeInt16LE(Math.round(clamp(R[i] * g, -1, 1) * 32767), 46 + i * 4); }
writeFileSync(out, buf);
console.log("wrote", out, `${DUR.toFixed(1)} s, peak gain ${g.toFixed(2)}`);
