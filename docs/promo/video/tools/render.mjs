// Renders the promo: frames from the scene via headless Chromium, then ffmpeg masters.
//   node tools/render.mjs 916            → frames + H.264 + ProRes + poster + contact sheet
//   node tools/render.mjs 916 stills     → only the storyboard stills (one per shot) for review
//   node tools/render.mjs 916 169 11     → every aspect
// Needs: playwright (npm i playwright; browsers via npx playwright install chromium), ffmpeg,
// and out/music.wav (node tools/music.mjs).
import { chromium } from "playwright";
import { spawn, execSync } from "node:child_process";
import { mkdirSync, writeFileSync, readFileSync, existsSync, copyFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url)), root = join(here, "..");
const cues = JSON.parse(readFileSync(join(root, "cues.json"), "utf8"));
const args = process.argv.slice(2);
const stillsOnly = args.includes("stills");
const aspects = args.filter((a) => ["916", "169", "11", "45"].includes(a));
if (!aspects.length) aspects.push("916");
const FPS = cues.fps, DUR = cues.duration, N = FPS * DUR;
const SIZES = { 916: [1080, 1920], 169: [1920, 1080], 11: [1080, 1080], 45: [1080, 1350] };
const FRAMES = process.env.FRAMES_DIR || join(root, "frames");
const OUT = join(root, "out");
mkdirSync(OUT, { recursive: true });

const port = Number(process.env.PORT || 8766);
const server = spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1", "--directory", root], { stdio: "ignore" });
await new Promise((r) => setTimeout(r, 700));
const browser = await chromium.launch();
try {
  for (const aspect of aspects) {
    const [W, H] = SIZES[aspect];
    const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
    page.on("pageerror", (e) => console.error("page error:", e.message));
    page.on("console", (m) => { if (m.type() === "error") console.error("console:", m.text()); });
    await page.goto(`http://127.0.0.1:${port}/scene/index.html?aspect=${aspect}`);
    await page.waitForFunction(() => window.sceneReady === true, null, { timeout: 30000 });
    const grab = async (t, file) => {
      const data = await page.evaluate((tt) => { window.seek(tt); return window.frameData(); }, t);
      writeFileSync(file, Buffer.from(data.split(",")[1], "base64"));
    };
    if (stillsOnly) {
      const dir = join(OUT, `stills-${aspect}`); mkdirSync(dir, { recursive: true });
      const times = [0.3, 1.2, 2.9, 5.2, 7.0, 9.4, 10.7, 11.6, 13.6, 15.0, 17.2, 18.05, 19.6, 21.6, 23.6];
      for (const t of times) await grab(t, join(dir, `t${t.toFixed(2).replace(".", "_")}.png`));
      const list = times.map((t) => join(dir, `t${t.toFixed(2).replace(".", "_")}.png`));
      const cols = 5, rows = Math.ceil(list.length / cols);
      const inputs = list.map((f) => `-i "${f}"`).join(" ");
      const scaled = list.map((_, i) => `[${i}]scale=${aspect === "169" ? 640 : 360}:-1[s${i}]`).join(";");
      const tileH = aspect === "169" ? 360 : aspect === "11" ? 360 : aspect === "45" ? 450 : 640;
      const tiles = list.map((_, i) => `[s${i}]`).join("");
      execSync(`ffmpeg -v error -y ${inputs} -filter_complex "${scaled};${tiles}xstack=inputs=${list.length}:layout=${layout(list.length, cols, aspect === "169" ? 640 : 360, tileH)}:fill=#F2F2F7[o]" -map "[o]" "${join(OUT, `storyboard-${aspect}.png`)}"`);
      console.log("stills →", dir, "and", `storyboard-${aspect}.png`);
      await page.close(); continue;
    }
    const dir = join(FRAMES, aspect); mkdirSync(dir, { recursive: true });
    const t0 = Date.now();
    for (let i = 0; i < N; i++) {
      await grab(i / FPS, join(dir, `f${String(i).padStart(5, "0")}.png`));
      if (i % 120 === 0) console.log(`${aspect}: frame ${i}/${N} (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
    }
    await page.close();
    const music = join(OUT, "music.wav");
    const name = { 916: "vory-promo-9x16", 169: "vory-promo-16x9", 11: "vory-promo-1x1", 45: "vory-promo-4x5" }[aspect];
    const seq = join(dir, "f%05d.png");
    const audio = existsSync(music) ? `-i "${music}" -shortest -c:a aac -b:a 192k` : "";
    execSync(`ffmpeg -v error -y -framerate ${FPS} -i "${seq}" ${audio} -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart -r ${FPS} "${join(OUT, name + ".mp4")}"`, { stdio: "inherit" });
    execSync(`ffmpeg -v error -y -framerate ${FPS} -i "${seq}" ${existsSync(music) ? `-i "${music}" -shortest -c:a pcm_s16le` : ""} -c:v prores_ks -profile:v 3 -pix_fmt yuv422p10le -r ${FPS} "${join(OUT, name + "-prores.mov")}"`, { stdio: "inherit" });
    // 30 fps H.264 as a lighter upload
    execSync(`ffmpeg -v error -y -i "${join(OUT, name + ".mp4")}" -r 30 -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart -c:a copy "${join(OUT, name + "-30fps.mp4")}"`, { stdio: "inherit" });
    copyFileSync(join(dir, `f${String(Math.round(2.9 * FPS)).padStart(5, "0")}.png`), join(OUT, `${name}-poster.png`));
    // Contact sheet: one frame per second, 6 columns
    const tw = aspect === "169" ? 480 : 270, th = aspect === "169" ? 270 : aspect === "11" ? 270 : aspect === "45" ? 338 : 480;
    execSync(`ffmpeg -v error -y -framerate ${FPS} -i "${seq}" -vf "select='not(mod(n,${FPS}))',scale=${tw}:${th},tile=6x4:padding=6:color=#F2F2F7" -frames:v 1 "${join(OUT, `${name}-contact-sheet.png`)}"`, { stdio: "inherit" });
    console.log(`${aspect}: done →`, name);
  }
} finally {
  await browser.close();
  server.kill();
}

function layout(n, cols, w, h) {
  const parts = [];
  for (let i = 0; i < n; i++) parts.push(`${(i % cols) * w}_${Math.floor(i / cols) * h}`);
  return parts.join("|");
}
