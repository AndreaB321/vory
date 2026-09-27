import { Bot, SHAPES, EYES, PALETTE, VORY, paintStill, widgetPose, stillMotion, baseline } from "./vory-bot.js";

const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
// The bot sits on its shelf the way the app's header does: its base 9 px into the pill.
const seat = (bot, shelf) => { shelf.style.marginTop = `${-(bot.size * (1 - baseline(bot.spec.shape)) + 9)}px`; };

// ---- every canvas.bot with a data-bot spec
for (const c of $$("canvas.bot[data-bot]")) {
  const spec = JSON.parse(c.dataset.bot);
  const size = Number(c.dataset.size || 56);
  new Bot(c, spec, { size, state: c.dataset.state || "idle", profile: c.dataset.profile || "" });
}

// ---- hero: Vory as the guide, with a typed bubble
const heroSize = () => (innerWidth >= 1200 ? 340 : innerWidth >= 900 ? 300 : 220);
const hero = new Bot($("#hero-bot"), VORY, { size: heroSize(), state: "guide", profile: "vory-hero" });
seat(hero, $(".shelf--hero"));
addEventListener("resize", () => { const s = heroSize(); if (s !== hero.size) { hero.setSize(s); seat(hero, $(".shelf--hero")); } }, { passive: true });
$("#hero-bot").addEventListener("pointerdown", () => hero.tap());

const typed = $("#hero-bubble .typed");
const lines = JSON.parse(typed.dataset.lines);
if (!reduceMotion) {
  let i = 0;
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  (async () => {
    await wait(1400);
    for (;;) {
      i = (i + 1) % lines.length;
      const next = lines[i];
      const cur = typed.textContent;
      for (let k = cur.length; k >= 0; k--) { typed.textContent = cur.slice(0, k); await wait(14); }
      for (let k = 1; k <= next.length; k++) { typed.textContent = next.slice(0, k); await wait(k < 3 ? 60 : 30); }
      if (i === 3) { hero.finishTurn(); }
      await wait(3400);
    }
  })();
}

// ---- beta + footer Vory
const beta = new Bot($("#beta-bot"), VORY, { size: innerWidth >= 900 ? 160 : 128, state: "guide", profile: "vory-beta" });
seat(beta, $(".bot-seat--beta .shelf"));
new Bot($("#footer-bot"), VORY, { size: 40, profile: "vory-footer" });

// ---- Live Activity + notification: still poses painted like the widget
const ada = { shape: "circle", eyes: "classic", hex: "#30D158", finish: "glass" };
paintStill($("#la-bot"), ada, 44, widgetPose("tool", true), false);
paintStill($("#notif-bot"), ada, 38, stillMotion(), true);

// ---- studio
const studioSpec = { ...VORY, hex: "#3B7BFF" };
const studioSize = () => (innerWidth >= 900 ? 220 : 168);
const studio = new Bot($("#studio-bot"), studioSpec, { size: studioSize(), state: "idle", profile: "Ada" });
seat(studio, $(".shelf--studio"));
addEventListener("resize", () => { const s = studioSize(); if (s !== studio.size) { studio.setSize(s); seat(studio, $(".shelf--studio")); } }, { passive: true });
$("#studio-bot").addEventListener("pointerdown", () => studio.tap());

const status = $("#studio-status");
const hints = {
  idle: "Idle bots barely move: a blink every few seconds, a glance to one side, a rare slow blink. Their eyes follow your scroll.",
  working: "While a reply is in progress: every 3 seconds one small routine, then rest. Wait for the coin‑turn.",
  thinking: "Thinking: the body settles into a shorter, heavier pebble and holds. Eyes narrow; blinks come sooner.",
  usingTool: "Using a tool: a small stem grows out of the top, like a key. The eyes glance down toward the tool and stay.",
  awaitingApproval: "Waiting for your yes: the body becomes a bold “!”, leans, and nudges toward you every few seconds. Well?",
  streaming: "Writing: a held squint and a light looping the rim every couple of seconds. Tokens arriving.",
  reconnecting: "Reconnecting: the eyes sweep left and right like a metronome. The body stays still.",
  error: "Error, not sleep: the eyes drop and shut, the body rolls back, the light on the rim dies.",
  finished: "Finished: one full coin‑turn, a blink edge‑on, a glance down at the new bubble.",
};
const statusText = { idle: "idle", working: "working…", thinking: "thinking…", usingTool: "using tools", awaitingApproval: "needs approval", streaming: "writing…", reconnecting: "reconnecting", error: "error" };

const mini = (spec) => {
  const b = document.createElement("button");
  b.type = "button"; b.className = "pick"; b.setAttribute("aria-pressed", "false");
  const c = document.createElement("canvas");
  b.append(c);
  paintStill(c, spec, 40);
  b._paint = (s) => paintStill(c, s, 40);
  return b;
};

const shapeRow = $("#pick-shape"), eyesRow = $("#pick-eyes"), colourRow = $("#pick-colour");
const shapeButtons = SHAPES.map((shape) => {
  const b = mini({ ...studioSpec, shape, eyes: "classic" });
  b.setAttribute("aria-label", shape); b.title = shape; b.dataset.shape = shape;
  b.addEventListener("click", () => setSpec({ shape }));
  shapeRow.append(b); return b;
});
const eyeButtons = EYES.map((eyes) => {
  const b = mini({ ...studioSpec, shape: "circle", eyes });
  b.setAttribute("aria-label", eyes); b.title = eyes; b.dataset.eyes = eyes;
  b.addEventListener("click", () => setSpec({ eyes }));
  eyesRow.append(b); return b;
});
const custom = $(".swatch--custom");
const swatchButtons = PALETTE.map((hex) => {
  const b = document.createElement("button");
  b.type = "button"; b.className = "swatch"; b.style.setProperty("--sw", hex);
  b.setAttribute("aria-label", `Colour ${hex}`); b.setAttribute("aria-pressed", "false"); b.dataset.hex = hex;
  b.addEventListener("click", () => setSpec({ hex }));
  colourRow.insertBefore(b, custom); return b;
});
$("#pick-custom").addEventListener("input", (e) => setSpec({ hex: e.target.value.toUpperCase() }));
$$("#pick-finish button").forEach((b) => b.addEventListener("click", () => setSpec({ finish: b.dataset.finish })));

function setSpec(patch) {
  Object.assign(studioSpec, patch);
  studio.setSpec(studioSpec);
  seat(studio, $(".shelf--studio"));
  shapeButtons.forEach((b) => { b.setAttribute("aria-pressed", String(b.dataset.shape === studioSpec.shape)); if (patch.hex || patch.finish) b._paint({ ...studioSpec, shape: b.dataset.shape, eyes: "classic" }); });
  eyeButtons.forEach((b) => { b.setAttribute("aria-pressed", String(b.dataset.eyes === studioSpec.eyes)); if (patch.hex || patch.finish) b._paint({ ...studioSpec, shape: "circle", eyes: b.dataset.eyes }); });
  swatchButtons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.hex === studioSpec.hex)));
  $$("#pick-finish button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.finish === studioSpec.finish)));
}
setSpec({});

const stateButtons = $$("#pick-state button");
let finishTimer = null;
function setState(state) {
  clearTimeout(finishTimer);
  if (state === "finished") {
    studio.state = "idle"; studio.finishTurn();
    stateButtons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.state === "idle")));
    status.textContent = "idle"; $("#state-hint").textContent = hints.finished;
    return;
  }
  studio.state = state;
  stateButtons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.state === state)));
  status.textContent = statusText[state]; $("#state-hint").textContent = hints[state];
}
stateButtons.forEach((b) => b.addEventListener("click", () => setState(b.dataset.state || b.dataset.action)));

// ---- reveal on scroll
if ("IntersectionObserver" in window && !reduceMotion) {
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
  $$(".reveal").forEach((el) => io.observe(el));
} else {
  $$(".reveal").forEach((el) => el.classList.add("in"));
}
