---
name: icon-composer-cli
description: How to render and author Icon Composer .icon bundles headlessly (ictool) and the icon.json keys that actually validate
metadata:
  node_type: memory
  type: reference
  originSessionId: 1dc8a15b-467b-4467-8278-3551756426ec
  modified: 2026-09-23T06:59:05.114Z
---

Icon Composer ships a CLI: `/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool <doc.icon> --export-image --output-file out.png --platform iOS|macOS|watchOS --rendition Default|Dark|ClearLight|ClearDark|TintedDark|TintedLight --width N --height N --scale 1 [--tint-color 0.6 --tint-strength 0.8]`. It prints `{}` on success; "The data couldn't be read because it is missing" means an invalid key/value in icon.json.

icon.json keys verified 2026-09-23 (Xcode 27): top-level `fill` {solid|linear-gradient [c1,c2] (exactly 2)|automatic-gradient}, `fill-specializations` [{appearance: dark|light|tinted|dark-clear|light-clear, value: {...}}]; colours `srgb:r,g,b,a` or `display-p3:...`. Group: `shadow {kind: neutral|layer-color|none, opacity}`, `translucency {enabled, value}`, `specular` bool, `specular-highlight-placement` "inside"|"outside" (not "automatic"), `blur-material` 0–1, `refractivity-strength` / `refractivity-depth` (flat numbers; a nested `refractivity` object fails), `lighting` individual|combined, `opacity` + `opacity-specializations`. Layer: `image-name`, `name`, `glass` bool, `fill` (omit to keep the SVG's own fill — SVG linearGradient fills are honoured, so multi-stop brand gradients go in the SVG), `position {scale, translation-in-points}`. `blur-material` blurs what is behind a glass layer, not the layer itself (no "glow" that way).

Vory's icon lives at `Vory/Shared/AppIcon.icon` (V + broken ring in the Vorantx brand gradient #3ec4ee→#0b2868, white / #1b1b1e backgrounds). Render rig + contact-sheet tool: session scratchpad `icon/gen.py`, `icon/sheet.swift`. Simulator home screen keeps the Light icon style even in dark mode unless icons are set to Dark/Automatic. See [[hermes-remote-ios-project]].
