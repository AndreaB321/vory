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

LINK = "testflight.apple.com/join/tJ4PyTfc"

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
    # background, glow 1, glow 2, headline, body, muted, accent, shadow alpha, tile outline
    "dark":  ((9, 10, 16), (20, 60, 120), (50, 22, 90), (245, 245, 250), (228, 229, 238), (150, 152, 168), (120, 160, 255), 160),
    "light": ((246, 247, 251), (200, 222, 255), (232, 214, 250), (18, 20, 30), (40, 42, 56), (112, 116, 134), (31, 110, 210), 70),
}

def render(build, version, groups, icon_path, out_path, theme="light"):
    W, H = 1600, 900
    bg, g1, g2, headline, body, muted, accent, shadow_a = PALETTES[theme]
    img = Image.new("RGB", (W, H), bg)
    glow = Image.new("RGB", (W, H), bg); g = ImageDraw.Draw(glow)
    g.ellipse((-200, -250, 760, 760), fill=g1); g.ellipse((1150, 450, 1950, 1250), fill=g2)
    img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(230)), 0.9)
    d = ImageDraw.Draw(img)
    # the cloud, floating with a soft shadow
    if icon_path and os.path.exists(icon_path):
        ic = Image.open(icon_path).convert("RGBA").resize((400, 400), Image.LANCZOS)
        sh = Image.new("RGBA", (520, 520), (0, 0, 0, 0)); ImageDraw.Draw(sh).rounded_rectangle((60, 80, 460, 480), radius=90, fill=(0, 0, 0, shadow_a))
        img.paste(sh.filter(ImageFilter.GaussianBlur(30)), (80, 130), sh.filter(ImageFilter.GaussianBlur(30)))
        img.paste(ic, (140, 170), ic)
    d = ImageDraw.Draw(img)
    d.text((140, 610), "Vory", font=font(44, True), fill=headline)
    d.text((140, 664), f"TestFlight build {build}", font=font(30), fill=accent)
    d.text((140, 706), f"Public beta {version}", font=font(24), fill=muted)
    d.text((140, 800), LINK, font=font(24), fill=accent)
    # the bullets
    x, y, colw = 660, 120, 860
    hf, bf = font(26, True), font(28)
    for title, items in groups.items():
        if not items: continue
        d.text((x, y), title.upper(), font=hf, fill=accent); y += 44
        for b in items[:6]:
            for i, line in enumerate(wrap(d, short(b), bf, colw - 30)):
                if i == 0: d.ellipse((x + 2, y + 13, x + 11, y + 22), fill=accent)
                d.text((x + 28, y), line, font=bf, fill=body); y += 38
            y += 8
        y += 22
        if y > 760: break
    img.save(out_path, optimize=True)

def posts(build, groups):
    fixed = [short(b, 95) for b in groups.get("Fixed in this build", [])]
    changed = [short(b, 95) for b in groups.get("Changed in this build", [])]
    head = f"Vory beta build {build} is on TestFlight."
    parts = []
    if fixed: parts.append("Fixed: " + "; ".join(fixed[:3]) + ".")
    if changed: parts.append("New: " + "; ".join(changed[:2]) + ".")
    short_post = head + " " + " ".join(parts) + " " + LINK
    while len(short_post) > 280 and (fixed or changed):
        if len(fixed) > 1: fixed.pop()
        elif changed: changed.pop()
        else: fixed.pop()
        parts = []
        if fixed: parts.append("Fixed: " + "; ".join(fixed[:3]) + ".")
        if changed: parts.append("New: " + "; ".join(changed[:2]) + ".")
        short_post = head + " " + " ".join(parts) + " " + LINK
    long_post = head + "\n\n" + "\n".join(f"• {short(b, 90)}" for t in groups for b in groups[t][:5]) + "\n\n" + LINK
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
