// Audit: renders every frame of every aspect headlessly and flags any two text items whose boxes
// intersect while both are visible. Run after editing scene.js:  node tools/audit-text.mjs
// boxes intersect. Uses an instrumented copy of the scene's text() via a page hook.
import { chromium } from "playwright";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url"; import { dirname, join } from "node:path";
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const srv = spawn("python3", ["-m", "http.server", "8772", "--bind", "127.0.0.1", "--directory", root], { stdio: "ignore" });
await new Promise((r) => setTimeout(r, 600));
const b = await chromium.launch();
for (const aspect of ["916", "169", "11", "45"]) {
  const p = await b.newPage({ viewport: { width: 1080, height: 1080 } });
  await p.addInitScript(() => {
    const orig = CanvasRenderingContext2D.prototype.fillText;
    window.__items = [];
    CanvasRenderingContext2D.prototype.fillText = function (s, x, y) {
      const a = this.globalAlpha; if (a > 0.02 && s.trim()) { const w = this.measureText(s).width; const m = this.getTransform(); const size = parseFloat((this.font.match(/(\d+(?:\.\d+)?)px/) || [0, 20])[1]); const left = this.textAlign === "center" ? x - w / 2 : this.textAlign === "right" ? x - w : x; window.__items.push({ s, x: m.a * left + m.e, y: m.d * (y - size / 2) + m.f, w: w * m.a, h: size * m.d, a }); }
      return orig.call(this, s, x, y);
    };
  });
  await p.goto(`http://127.0.0.1:8772/scene/index.html?aspect=${aspect}`); await p.waitForFunction(() => window.sceneReady === true);
  const hits = await p.evaluate(() => {
    const out = [];
    for (let f = 0; f < 24 * 30; f++) { const t = f / 30; window.__items = []; window.seek(t); const it = window.__items;
      for (let i = 0; i < it.length; i++) for (let j = i + 1; j < it.length; j++) { const A = it[i], B = it[j];
        if (A.s === B.s) continue; const ix = Math.min(A.x + A.w, B.x + B.w) - Math.max(A.x, B.x), iy = Math.min(A.y + A.h, B.y + B.h) - Math.max(A.y, B.y);
        if (ix > 4 && iy > 4) out.push(`${t.toFixed(2)}s "${A.s.slice(0, 24)}" × "${B.s.slice(0, 24)}"`); } }
    return out;
  });
  console.log(aspect, hits.length ? hits.slice(0, 12).join("\n  ") : "no overlapping text");
  await p.close();
}
await b.close(); srv.kill();
