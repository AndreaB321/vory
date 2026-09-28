#!/usr/bin/env python3
"""One image and one post per TestFlight build.

    xpost.py <build> <notes.txt> [--icon icon.png] [--out dir] [--version 1.1]

Reads the What-to-Test notes (the "Fixed in this build" / "Changed in this build" groups), draws a
1600x900 card with the Vory cloud, "TestFlight build N" and the bullets, and prints a post for X:
a short one that fits 280 characters and a longer one. Needs Pillow. The icon is a 1024 px render
of Shared/AppIcon.icon (ictool --rendition Default); pass --icon to use another.
"""
import argparse, os, re, sys, textwrap
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SITE = "vory.dev"

def font(size, bold=False):
    for path, idx in [("/System/Library/Fonts/SFCompact.ttf", 0), ("/System/Library/Fonts/HelveticaNeue.ttc", 1 if bold else 0),
                      ("/System/Library/Fonts/Supplemental/Arial.ttf", 0)]:
        try:
            f = ImageFont.truetype(path, size, index=idx)
            if path.endswith("SFCompact.ttf"):
                try: f.set_variation_by_name("Bold" if bold else "Regular")
                except Exception: pass
            return f
        except Exception:
            continue
    return ImageFont.load_default()

def sections(notes: str) -> dict:
    """{'Fixed in this build': [bullet, …], 'Changed in this build': [...]}."""
    out, current = {}, None
    for line in notes.splitlines():
        s = line.strip()
        if not s:
            current = None; continue
        if s.startswith("•"):
            if current is not None: out.setdefault(current, []).append(s.lstrip("• ").strip())
        elif current is None:
            current = s
    return out

def short(b: str, limit: int = 120) -> str:
    """The first clause of a bullet, for the card."""
    b = re.split(r"(?<=[a-z0-9)]):\s|;\s", b, maxsplit=1)[0]
    # a trailing aside ("…, for anyone who…", "…, so that…") goes too once the point is made
    m = re.match(r"(.{40,}?),\s(?:for|so|which|instead)\b.*", b)
    if m: b = m.group(1)
    b = re.sub(r"\s*\([^)]*\)", "", b).rstrip(".")
    return b if len(b) <= limit else b[:limit - 1].rsplit(" ", 1)[0] + "…"

def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) <= width: cur = t
        else: lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines

PALETTES = {
    # background, glow 1, glow 2, headline, body, muted, accent, shadow alpha
    "dark":  ((9, 10, 16), (20, 60, 120), (50, 22, 90), (245, 245, 250), (228, 229, 238), (150, 152, 168), (120, 160, 255), 160),
    "light": ((246, 247, 251), (200, 222, 255), (232, 214, 250), (18, 20, 30), (40, 42, 56), (112, 116, 134), (31, 110, 210), 70),
}

def render(build, version, groups, icon_path, out_path, theme="light"):
    """A 4:5 portrait card (1200x1500): what X shows uncropped on a phone, one column, big type."""
    W, H = 1200, 1500
    bg, g1, g2, headline, body, muted, accent, shadow_a = PALETTES[theme]
    img = Image.new("RGB", (W, H), bg)
    glow = Image.new("RGB", (W, H), bg); g = ImageDraw.Draw(glow)
    g.ellipse((-300, -300, 700, 700), fill=g1); g.ellipse((700, 900, 1600, 1900), fill=g2)
    img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(240)), 0.9)
    # the icon tile, centred, floating on a soft shadow
    size, ix, iy = 330, (W - 330) // 2, 96
    if icon_path and os.path.exists(icon_path):
        ic = Image.open(icon_path).convert("RGBA").resize((size, size), Image.LANCZOS)
        sh = Image.new("RGBA", (size + 120, size + 120), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((60, 78, size + 60, size + 78), radius=int(size * 0.22), fill=(0, 0, 0, shadow_a))
        sh = sh.filter(ImageFilter.GaussianBlur(28))
        img.paste(sh, (ix - 60, iy - 60), sh)
        img.paste(ic, (ix, iy), ic)
    d = ImageDraw.Draw(img)
    def centred(text, f, y, fill):
        d.text(((W - d.textlength(text, font=f)) / 2, y), text, font=f, fill=fill)
    centred("Vory", font(64, True), 458, headline)
    centred(f"TestFlight build {build}", font(38), 540, accent)
    centred(f"Public beta {version}", font(28), 592, muted)
    d.line((110, 660, W - 110, 660), fill=tuple(int(c * 0.9 + 128 * 0.1) for c in bg) if theme == "light" else (40, 42, 56), width=2)
    # one column of bullets
    x, y, colw = 110, 700, W - 220
    hf, bf = font(28, True), font(34)
    for title, items in groups.items():
        if not items or y > 1300: continue
        d.text((x, y), title.upper(), font=hf, fill=accent); y += 50
        for b in items:
            lines = wrap(d, short(b), bf, colw - 40)
            if y + 46 * len(lines) > 1360: break
            for i, line in enumerate(lines):
                if i == 0: d.ellipse((x + 4, y + 16, x + 15, y + 27), fill=accent)
                d.text((x + 38, y), line, font=bf, fill=body); y += 46
            y += 10
        y += 30
    centred(SITE, font(34, True), 1408, accent)
    img.save(out_path, optimize=True)

def posts(build, groups):
    fixed = [short(b, 95) for b in groups.get("Fixed in this build", [])]
    changed = [short(b, 95) for b in groups.get("Changed in this build", [])]
    head = f"Vory beta build {build} is on TestFlight."
    parts = []
    if fixed: parts.append("Fixed: " + "; ".join(fixed[:3]) + ".")
    if changed: parts.append("New: " + "; ".join(changed[:2]) + ".")
    short_post = head + " " + " ".join(parts) + " " + SITE
    while len(short_post) > 280 and (fixed or changed):
        if len(fixed) > 1: fixed.pop()
        elif changed: changed.pop()
        else: fixed.pop()
        parts = []
        if fixed: parts.append("Fixed: " + "; ".join(fixed[:3]) + ".")
        if changed: parts.append("New: " + "; ".join(changed[:2]) + ".")
        short_post = head + " " + " ".join(parts) + " " + SITE
    long_post = head + "\n\n" + "\n".join(f"• {short(b, 90)}" for t in groups for b in groups[t][:5]) + "\n\n" + SITE
    return short_post, long_post

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("build"); ap.add_argument("notes"); ap.add_argument("--icon", default=None)
    ap.add_argument("--out", default="."); ap.add_argument("--version", default="1.1")
    ap.add_argument("--theme", choices=("light", "dark"), default="light", help="light (the default, with the light icon) or dark")
    a = ap.parse_args()
    groups = {k: v for k, v in sections(open(a.notes).read()).items() if k in ("Fixed in this build", "Changed in this build")}
    if not groups: sys.exit("no 'Fixed in this build' / 'Changed in this build' bullets found")
    os.makedirs(a.out, exist_ok=True)
    out = os.path.join(a.out, f"vory-build-{a.build}.png")
    icon = a.icon or os.path.join(os.path.dirname(os.path.abspath(__file__)), "vory-icon-1024-light.png" if a.theme == "light" else "vory-icon-1024.png")
    render(a.build, a.version, groups, icon, out, a.theme)
    s, l = posts(a.build, groups)
    print(out); print("\n--- short (%d chars) ---\n%s\n\n--- long ---\n%s" % (len(s), s, l))
