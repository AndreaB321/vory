// Stills of the site for review: phone and desktop, light and dark. Run the local server first
// (python3 -m http.server 8765 --directory public), then: node tools/shoot.mjs
import { chromium } from "playwright";
const base = process.env.SITE_URL || "http://127.0.0.1:8765/";
const out = process.env.OUT_DIR ? process.env.OUT_DIR.replace(/\/?$/, "/") : new URL("../stills/", import.meta.url).pathname;
const browser = await chromium.launch();
const shots = [
  { name: "phone-light", viewport: { width: 393, height: 852 }, scale: 3, mobile: true, scheme: "light" },
  { name: "phone-dark", viewport: { width: 393, height: 852 }, scale: 3, mobile: true, scheme: "dark" },
  { name: "desktop-light", viewport: { width: 1440, height: 900 }, scale: 2, mobile: false, scheme: "light" },
  { name: "desktop-dark", viewport: { width: 1440, height: 900 }, scale: 2, mobile: false, scheme: "dark" },
];
for (const s of shots) {
  const ctx = await browser.newContext({ viewport: s.viewport, deviceScaleFactor: s.scale, isMobile: s.mobile, hasTouch: s.mobile, colorScheme: s.scheme, reducedMotion: "no-preference" });
  const page = await ctx.newPage();
  await page.goto(base, { waitUntil: "networkidle" });
  await page.waitForTimeout(1800);
  await page.screenshot({ path: `${out}${s.name}-hero.png` });
  // Reveal everything, then a full-page still.
  await page.evaluate(() => { document.querySelectorAll(".reveal").forEach((e) => e.classList.add("in")); document.querySelectorAll("img[loading=lazy]").forEach((i) => { i.loading = "eager"; }); scrollTo(0, 0); });
  await page.waitForLoadState("networkidle");
  await page.waitForTimeout(900);
  await page.screenshot({ path: `${out}${s.name}-full.png`, fullPage: true });
  await ctx.close();
}
await browser.close();
console.log("stills written to", out);
