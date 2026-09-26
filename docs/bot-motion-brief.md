# FABLE BRIEF — Vory bot motion system
# Translate Grok-style “alive thinking blob” language into Vory’s constrained SwiftUI bots.
# Dual finish: Flat + Liquid Glass. Do not invent a new mascot.

Read this entire brief before drawing a single frame. The attached Grok video is MOTION REFERENCE ONLY — attitude, timing, eye acting, and “one quick stroke” turns. It is NOT a shape-morph target.

---

## 0. HARD LOCKS (break any of these and the work is unusable)

1. A bot is ONE character with a FIXED body shape for the whole clip. Never morph circle → triangle → hex → egg → exclamation → dots.
2. NEVER scale the body. NEVER bounce. NEVER hop. NEVER bloom / materialize / pop-in. NEVER leave the square footprint.
3. No Lottie-style character sheet. No extra limbs, mouth, eyebrows, sparkles, particles that fly off-canvas, comet tails that leave the square, orbiting ribbons that read as a second character.
4. Eyes are always near-black (#111318 or 90% black). Never white cutouts like Grok. Grok’s white “quote” eyes become Vory’s dark capsules sitting ON the body.
5. Two finishes must be designed as twins of the same motion:
   - **Flat** — solid fill of the bot’s hex colour + a soft top highlight (painted, 8–12% white, top 30% of the shape). Thin inner rim on light/white bots so they don’t vanish.
   - **Glass** — the SAME silhouette and the SAME transforms, but the body is a tinted iOS 26 Liquid Glass plate (translucent, refracts a soft grey-to-white field behind it, specular rim, contact shadow). Eyes are a SECOND, darker, smaller glass plate sitting in front of the body — they move independently (openness, x/y) but never leave the face. Glass must look continuous; never “rebuild” or flash-bloom the material.
6. Motion vocabulary is ONLY:
   - yaw (`rotation3DEffect` Y, perspective 0) — the loved 360° coin-turn
   - roll (`rotationEffect` or 3D X/Z, tiny degrees)
   - x/y offset inside the square (max ~1.2–2% of size)
   - eye openness (1.0 open → 0.0 line)
   - eye x/y (glance / gaze)
   - blob outline phase (blob shape only)
   - glass specular rim intensity / highlight angle (glass only; animate the highlight, not the material identity)
7. Idle = eyes only. Body routines play ONLY while working (mid-reply) except: tap, finish-spin, approval ask, error.
8. Every bot has a seeded phase so a grid never moves in unison. Show at least 3 bots with offset timing in any group shot.
9. Reduce Motion variant: body frozen, eyes may still blink.
10. Sizes that must work: 78 pt (bots page), 52 pt (chat header), 40 pt (chat list), 28 pt (beside bubble), 26 pt (toolbar — static or blink-only). Live Activity / Dynamic Island is a painted Canvas fake of glass — no live refraction, no per-frame timers; only 1–2 stepped poses.

---

## 1. WHAT A BOT LOOKS LIKE (draw these exactly)

`BotLookSpec = { shape, eyes, hex, finish }`

**Shapes (8) — rounded, friendly, no sharp corners:**
- `circle` — perfect disc
- `blob` — soft organic 5–6 bump amoeba; silhouette may breathe only while working
- `square` — rounded square, corner radius ~28% of side
- `pill` — wide horizontal capsule
- `triangle` — rounded-corner triangle, point up
- `hexagon` — regular hex, heavily rounded
- `cloud` — three bumps on top, flat bottom. This IS the app mascot “Vory” when coloured blue glass
- `drop` — teardrop, point at TOP

**Eyes (8) — two marks, near-black, upper-middle of the face:**
- `classic` — two upright rounded rectangles (Grok’s “quote” eyes, but dark)
- `tall` — longer uprights
- `tiny` — two dots
- `round` — two circles
- `wide` — short wide capsules
- `curious` — LEFT round, RIGHT tall (asymmetric; this one can glance the tall eye a frame later)
- `bold` — big uprights
- `sleepy` — two closed-lid arcs (strokes). Blink is already “closed”; idle sleepy does a slow lid weight, not a squash-to-line

**Hero cast to design first (then prove the system on the rest):**
1. Vory mascot — `cloud` + `classic` + blue `#4C8DFF` + `glass`
2. Working agent — `circle` + `classic` + black `#111111` + `glass` (closest to the Grok video attitude)
3. Warm bot — `blob` + `curious` + terracotta `#E07A5F` + `flat`
4. Alert bot — `triangle` + `bold` + amber `#F5A524` + `flat`
5. Light bot — `pill` + `wide` + white `#F4F4F5` + `glass` (prove rim/shadow so white glass still reads)
6. Drop — `drop` + `tiny` + teal `#2BB5A0` + `flat`

Artboard: 1:1, bot occupies ~56% of the square, sitting optically on a faint iOS glass pill (the “header / card” shelf). Background: iOS light `#F2F2F7` AND a dark mode `#000000` pair. Design both.

---

## 2. WHAT TO STEAL FROM THE GROK VIDEO (and what to throw away)

Steal:
- The personality: a quiet face that thinks with its eyes, then commits to ONE decisive body stroke.
- Blink acting: full blink, occasional double, squint while concentrating.
- Side-eye / glance as “I’m scanning.”
- The 360° coin-turn as “I just finished a thought” (already loved in Vory — keep the ease: slow start, fast middle, slow stop, ~1.15 s).
- Alert punctuation: Grok becomes an “!” — Vory does NOT change shape. Instead the triangle bot (or any bot) does a short freeze + eyes wide + 3° roll hold, like raising an eyebrow without an eyebrow.
- “Planet + moon”: Grok puts a blue dot on the rim. Vory glass already has a specular rim — treat a single traveling highlight on the glass rim as the moon. Do not add a second circle character.
- “Orbits / rainbow ribbons”: FORBIDDEN as free strokes around the body (leaves the footprint, too busy). Translate to: glass rim sheen sweeping 90–180° once, or a 4% brighter specular tick. Flat finish: the painted top-highlight slides 8–12° around the crown.
- “Collapse to a micro-dot / particle cluster / comet tail”: FORBIDDEN.

Throw away:
- Shape morphing through cube / egg / play-triangle / lollipop / “!”
- White eyes on black body
- Rainbow orbit spaghetti
- Scale pulses
- Anything that would force SwiftUI to destroy and recreate a `glassEffect` view

---

## 3. MOTION SYSTEM — design these as named clips
Each clip is a timeline Fable should output as pose keys + degrees / offsets / eye values so engineering can port to SwiftUI `TimelineView`.

### A. Idle life (eyes only — cheap — every size including 26 pt)
Loop 12–16 s. Seeded phase.

| Beat | What moves | Values | Duration | Easing | How often |
|---|---|---|---|---|---|
| Blink | eye openness | 1.0 → 0.08 → 1.0 | 150 ms | ease-in-out | every 4.3 s ± seed |
| Double blink | same, twice | gap 90 ms | 150+90+150 | same | every 3rd blink |
| Glance | both eyes x | ±18% of eye-span, hold 280 ms, return | 700–900 ms total | ease-out then ease-in | every ~7 s |
| Gaze-follow (list only) | eyes y (and a little x) | follow scroll dir, max 20% of eye slot | 350 ms in, 450 ms back after scroll stops | ease-out | driven by scroll |
| Gyro tilt (BETA) | body roll + yaw few degrees; past 15° phone tilt, eyes lock to device and stop wandering | ±6° body | continuous, damped | spring low | opt-in |
| Rare idle “alive” | eyes only: a slower blink (220 ms) OR a 2-frame micro-squint then open | openness 0.72 | 300 ms | soft | ~1 / 25 s, never on a grid of 12 at once |
| Sleepy eyes exception | lid weight 0.15 then 0.0 | 400 ms | sine | instead of squash blink |

Do NOT add body motion on idle. Do NOT add the 5-second working block on the chats list or toolbar.

### B. Working routines (replace / extend the current 6)
Time is still 5-second blocks. First ~0.9–1.2 s plays a routine, rest is still. Pick by `(block + seed) % N`. Same routine must look correct on every shape.

Keep and refine:

1. **Full turn** (hero). Yaw 360° on Y, perspective 0. 1.15 s. Custom ease: 0–20% time = 0–40° (slow), 20–80% = 40–320° (fast stroke), 80–100% = 320–360° (slow settle). Glass: specular highlight rides around the rim with the yaw so the plate feels physical. Show on 52 pt header and 78 pt grid.

2. **Glance turn.** Yaw ±0.45 rad and back. 1.00 s. Eyes lead by 60 ms in the same direction.

3. **Head tilt.** Roll +4° then −4° then 0. 1.10 s.

4. **Nod.** Y offset −2% of size, twice. 0.80 s. (This is translation, not scale.)

5. **Lean.** Roll ±3.5° + X offset ±1.2%. 0.90 s.

6. **Rest.** Nothing.

Add these Grok-inspired routines (still in-footprint):

7. **Think squint + settle** (Grok frames 3–5). Eyes openness → 0.42 over 180 ms, hold 400 ms, open to 0.92. Body still. Use this BOTH as a working-block routine AND as the continuous “thinking…” state in the chat header.

8. **Scan** (Grok side-eye). Eyes x sweep L then R (or seeded dir), 0.55 s each way, body yaw only ±8°. 1.20 s total. Good on 40 pt list if the row is the active streaming bot.

9. **Rim sheen** (Grok “orbits”, glass-legal). No extra strokes. Animate highlightAngle 0° → 140° and rimIntensity 0.35 → 0.7 → 0.35. 0.90 s. Flat twin: slide the painted crown highlight 12°. Blob may add +0.04 outline phase.

10. **Half-turn check** (smaller than full turn). Yaw 180° and stop facing, 0.70 s, same slow-fast-slow. Then a blink. Feels like “checking the other side of the thought.” Use sparingly (1 in 8 blocks) so the full 360 stays special.

Forbidden working ideas: bounce, squash-stretch body, outline exploding, colour cycling, rainbow strokes.

### C. State-specific moments (these are one-shots, not 5-second blocks)

Design each as a 0.4–1.3 s clip, then hold the end pose until the state ends.

**Thinking** (status: thinking…)
- Eyes openness 0.42, very slight roll 1.5° toward the status text.
- Blink interval shortens to ~2.8 s.
- Blob outline phase creeps.
- No coin-turn while thinking — save the turn for the finish.
- Header 52 pt + Live Activity painted pose (squint).

**Using a tool** (status: using tools)
- Eyes glance 12% toward wherever a wrench/tool glyph would sit (down-right of the header).
- One **lean** toward that corner, hold 0.4 s, return.
- Optional: classic/bold eyes go 8% narrower.
- Do not spin.

**Waiting for approval** (the bot needs a “yes”)
This is the Grok “!” beat without changing shape.
- Eyes openness 1.0 and freeze wandering.
- Body roll to +6° and HOLD (asking). Seeded sign so two bots don’t lean the same way.
- Every 2.8 s: a single blink, then a 2% X nudge toward the user (the pill), back. Like a polite “well?”
- Triangle + bold eyes is the loudest version; sleepy eyes should NOT be used for this state (swap display to classic if needed — mention as a design note, don’t morph sleepy into classic mid-clip).
- Live Activity: painted body already rolled, plus the existing yellow warning triangle glyph outside the bot (glyph is NOT the bot).

**Error / reconnecting**
- Error: eyes openness 0.35, glance down 10%, hold. One slow blink (220 ms). No turn.
- Reconnecting: eyes do a metronomic glance L-R every 1.1 s, body still. Cheap, readable on 28 pt.

**Reply arriving / finish spin**
- The existing full 360° coin-turn, wherever the bot is shown (header, list, Live Activity stepped 0/90/180/270 if the widget timeline can only hold 4 frames).
- Eyes: blink at 50% of the turn (when the face is edge-on the eyes are hidden by yaw anyway — that’s fine).
- After the turn, eyes openness 1.0, one glance at the new bubble, back. 0.4 s.
- Never scale up to celebrate.

**Tapped**
- 0.55 s: yaw +18° and back + a blink. Same ease family as the coin-turn, just smaller.
- Glass: one rim sheen tick.
- Must feel like pressing a physical chip, not a button bounce.

**Streaming tokens (beside 28 pt bubble)**
- Eyes only: squint 0.55 and a glance every ~3 s. Body rest. Too small for yaw.

### D. Group behaviour (2–6 bots)

- Shared clock, per-bot seed. They take turns: only ONE body routine plays in a 5 s window across the group. Others stay idle-eyes.
- If one bot is in approval-ask (rolled +6°), neighbors glance toward it (eyes x), then back. No copy-tilt.
- Empty group-room stack: overlapped bots at 28–40 pt. Front bot gets idle eyes; back bots are static (cheap). When a member speaks, that bot’s finish-spin plays; others glance.
- Never chorus-line the coin-turn.

### E. Per-shape / per-eye flavour (tiny — don’t fork the system)

These are multipliers on the SAME routines, not new choreography.

- `cloud` (Vory): roll routines use 75% amplitude (the flat bottom should stay planted on the pill). Onboarding may loop: blink → glance at the speech bubble → blink. Every ~5 s a rim sheen. No hop off the shelf.
- `drop`: point-up already reads as “alert.” Approval-ask roll is 4° not 6°. Nod is 1.5% not 2% so the tip doesn’t feel like it’s stabbing.
- `triangle`: approval-ask is its signature. Working blocks prefer glance-turn and lean over nod.
- `pill`: yaw reads strongest (wide face). Full turn stays the star. Limit roll to 3°.
- `blob`: only shape allowed to change outline. Working = outline phase +0.0 → +0.15 over the 5 s block, independent of which routine plays. Idle = frozen outline.
- `curious` eyes: on glance, the tall eye delays 50–70 ms. On approval-ask, only the round eye widens.
- `tiny` eyes: blink is 90 ms (they’re already small). Skip double-blink at 28 pt.
- `sleepy`: no squash blink; lid weight only. Do not assign sleepy to approval-ask hero shots.

### F. Vory mascot (tour, setup wizard, Check for updates)

Still `cloud` + `classic` + blue glass. Same locks.

Tour loop (8 s, then repeat):
1. 0.0–0.4 idle
2. Blink
3. Glance toward the typed speech bubble
4. Rim sheen (glass)
5. Hold
6. Optional tiny nod (1.5%) when a step completes — not a finish spin every sentence
7. When “Check for updates” is running: think-squint + outline-still + rim sheen every 5 s
8. When update-found: one full coin-turn, then hold

Onboarding may use 78–96 pt. Still no scale, no bounce off the pill.

---

## 4. GLASS vs FLAT — how Fable should render both

Make every clip twice, same camera, same keys.

**Glass (iOS 26 Liquid Glass look-alike):**
- Body: 18–28% opacity tint of the hex over a blurred light/dark field.
- Specular rim: 1 pt white at 20–35% opacity, stronger on the top-left.
- Contact shadow: soft, 8% black, offset y +4%, blur 8%, does not animate separately (it would look like the bot lifted — forbidden).
- Eyes: darker glass chips, 55–70% opacity black-blue, sitting on the face. They squash for blinks.
- Animate: transforms + eye params + `highlightAngle` / `rimIntensity` only.
- NEVER fade the whole glass view in. NEVER switch shape mid-clip (that rebuilds the material and blooms).

**Flat:**
- Body: solid hex.
- Top highlight: linear white 10% → 0% in the top third.
- White/light hex: 1 px inner stroke #D0D0D5 at 40% plus a hairline outer #000000 at 8%.
- Eyes: solid near-black.
- Animate the highlight’s end-point instead of rimIntensity.

**Painted-glass fallback** (widgets, app switcher, Live Activity, notifications):
- A still or 2-frame illustration that fakes the glass look (tint + rim + shadow baked).
- Allowed stepped poses for Live Activity: idle, squint-think, rolled-ask, 90° edge-on (mid-spin). No interpolation in the widget.

---

## 5. WHAT TO DELIVER

1. A design sheet: the 6 hero bots, flat + glass, light + dark, at 78 / 52 / 28 pt.
2. Named motion clips (A–F above) as 1:1 loops or one-shots, labeled with exact values:
   `yawDeg, rollDeg, offsetXpct, offsetYpct, eyeOpen, eyeXpct, eyeYpct, highlightAngle, rimIntensity, blobPhase, durationMs, easing`.
3. A 12-bot grid shot proving seeded desync and “only eyes while idle.”
4. A chat-header storyboard: idle → thinking squint → using-tool lean → approval-ask hold → finish spin → glance at bubble.
5. Vory cloud tour loop.
6. Reduce Motion pair: same frames, body matrices identity.
7. Notes per clip: which sizes it ships on, and “widget-safe / not widget-safe.”

Export: Fable file + MP4 previews on `#F2F2F7` and `#000000` + a numeric key table (CSV or frame list). Do not export Lottie as the source of truth — engineering will reimplement in SwiftUI Path + `rotation3DEffect`. Lottie is preview-only if you want it.

---

## 6. TONE CHECK (owner taste)

If a clip would make someone say “the bots are dancing,” cut it.
If a clip would make someone say “that one just had a thought,” keep it.
The 360° coin-turn is the only flourish that can be a little showy. Everything else is a glance, a squint, a lean, or a rim of light.

---

## 7. SWIFT CONSIDERATION ONLY — do not treat this as the design

This code is **consideration only**. It is not a spec Fable must match pixel-for-pixel, not a request to emit a Swift project, and not a second source of truth that overrides sections 0–6.

Use it only to:
- see which numbers the app can actually drive (`yaw`, `roll`, `offset`, `eyeOpen`, `eye` x/y, `highlightAngle`, `rimIntensity`, `blobPhase`)
- see the timing the owner already likes (4.3 s blink, 7 s glance, 5 s working blocks, 1.15 s coin-turn, slow–fast–slow ease)
- stay inside those channels when you key the clips

If a clip needs a channel this code does not have, do not invent the motion. Cut the clip.

```swift
import SwiftUI

struct BotLookSpec: Hashable {
    enum Shape: String, CaseIterable { case circle, blob, square, pill, triangle, hexagon, cloud, drop }
    enum Eyes: String, CaseIterable { case classic, tall, tiny, round, wide, curious, bold, sleepy }
    enum Finish: String { case flat, glass }
    var shape: Shape
    var eyes: Eyes
    var hex: Color
    var finish: Finish
}

enum BotRuntimeState: Equatable {
    case idle
    case thinking
    case usingTool
    case awaitingApproval
    case error
    case reconnecting
    case streaming
    case working           // mid-reply, 5s routine blocks
}

struct BotMotion: Equatable {
    var yaw: Double = 0          // radians, Y axis
    var roll: Double = 0         // radians, screen-Z
    var offset: CGSize = .zero   // points, stay tiny
    var eyeOpen: CGFloat = 1     // 1 open, 0 line
    var eye: CGSize = .zero      // -1...1 glance
    var highlightAngle: Double = -40
    var rimIntensity: CGFloat = 0.4
    var blobPhase: CGFloat = 0
}

struct BotSeed {
    let blinkPhase: Double
    let glancePhase: Double
    let routinePhase: Int
    let leanSign: Double

    init(spec: BotLookSpec, name: String) {
        var hasher = Hasher()
        hasher.combine(spec)
        hasher.combine(name)
        let raw = UInt64(bitPattern: Int64(hasher.finalize()))
        blinkPhase = Double(raw % 4300) / 1000.0
        glancePhase = Double((raw >> 8) % 7000) / 1000.0
        routinePhase = Int((raw >> 16) % 10)
        leanSign = (raw & 1 == 0) ? 1 : -1
    }
}

/// Maps state → target pose. Animation lives outside the drawer so glass
/// identity never changes.
func targetMotion(
    state: BotRuntimeState,
    spec: BotLookSpec,
    seed: BotSeed,
    now: TimeInterval,
    size: CGFloat,
    scrollGaze: CGSize = .zero
) -> BotMotion {
    var m = BotMotion()
    let t = now

    // --- eyes: always on, even idle ---
    m.eyeOpen = blinkOpenness(at: t + seed.blinkPhase, style: spec.eyes)
    m.eye = glanceOffset(at: t + seed.glancePhase) + scrollGaze

    switch state {
    case .idle, .streaming:
        if state == .streaming { m.eyeOpen = min(m.eyeOpen, 0.55) }

    case .thinking:
        m.eyeOpen = min(m.eyeOpen, 0.42)
        m.roll = 0.026
        if spec.shape == .blob { m.blobPhase = CGFloat((t * 0.12).truncatingRemainder(dividingBy: 1)) }

    case .usingTool:
        m.eye.width += 0.12
        m.eye.height += 0.10
        m.roll = 0.05 * seed.leanSign
        m.offset = CGSize(width: size * 0.012 * seed.leanSign, height: size * 0.008)

    case .awaitingApproval:
        m.eyeOpen = 1
        m.eye = .zero
        m.roll = 0.105 * seed.leanSign
        let nudge = approvalNudge(at: t)
        m.offset.width = size * 0.02 * nudge

    case .error:
        m.eyeOpen = min(m.eyeOpen, 0.35)
        m.eye.height = 0.10

    case .reconnecting:
        m.eye.width = CGFloat(sin(t * (2 * .pi / 1.1))) * 0.55
        m.eyeOpen = 1

    case .working:
        let block = workingBlock(now: t, seed: seed, size: size, spec: spec)
        m.yaw = block.yaw
        m.roll = block.roll
        m.offset = block.offset
        m.highlightAngle = block.highlightAngle
        m.rimIntensity = block.rimIntensity
        m.blobPhase = block.blobPhase
        if block.squint { m.eyeOpen = min(m.eyeOpen, 0.42) }
        if let lead = block.eyeLead { m.eye.width += lead }
    }
    return m
}

private func blinkOpenness(at t: TimeInterval, style: BotLookSpec.Eyes) -> CGFloat {
    if style == .sleepy {
        let w = (sin(t * .pi / 2.15) + 1) * 0.075
        return 1 - w
    }
    let cycle = 4.3
    let local = t.truncatingRemainder(dividingBy: cycle * 3) // 3 blinks, last is double
    func pulse(_ x: Double, width: Double = 0.15) -> CGFloat {
        guard x >= 0, x <= width else { return 1 }
        let u = x / width
        return CGFloat(1 - sin(u * .pi) * 0.92)
    }
    if local < cycle { return pulse(local) }
    if local < cycle * 2 { return pulse(local - cycle) }
    let d = local - cycle * 2
    return min(pulse(d), pulse(d - 0.24))
}

private func glanceOffset(at t: TimeInterval) -> CGSize {
    let cycle = 7.0
    let local = t.truncatingRemainder(dividingBy: cycle)
    guard local < 0.85 else { return .zero }
    let dir: CGFloat = (Int(t / cycle) % 2 == 0) ? 1 : -1
    let u = local / 0.85
    let hold = smoothstep(0.25, 0.35, u) * (1 - smoothstep(0.65, 0.85, u))
    return CGSize(width: dir * 0.18 * hold, height: 0)
}

private func approvalNudge(at t: TimeInterval) -> CGFloat {
    let local = t.truncatingRemainder(dividingBy: 2.8)
    guard local < 0.45 else { return 0 }
    return CGFloat(sin((local / 0.45) * .pi))
}

private struct WorkingPose {
    var yaw: Double = 0
    var roll: Double = 0
    var offset: CGSize = .zero
    var highlightAngle: Double = -40
    var rimIntensity: CGFloat = 0.4
    var blobPhase: CGFloat = 0
    var squint = false
    var eyeLead: CGFloat? = nil
}

/// 5s blocks. Routine plays in the first ~1.15s, then rests.
private func workingBlock(now: TimeInterval, seed: BotSeed, size: CGFloat, spec: BotLookSpec) -> WorkingPose {
    let blockLen = 5.0
    let blockIndex = Int(now / blockLen)
    let local = now.truncatingRemainder(dividingBy: blockLen)
    let kind = (blockIndex + seed.routinePhase) % 10
    let amp: Double = spec.shape == .cloud ? 0.75 : 1
    var p = WorkingPose()
    if spec.shape == .blob { p.blobPhase = CGFloat((now * 0.15).truncatingRemainder(dividingBy: 1)) }

    func stroke(_ duration: Double) -> Double {
        guard local < duration else { return 1 }
        return coinEase(local / duration)
    }

    switch kind {
    case 0: // full turn — keep this ease
        let u = stroke(1.15)
        p.yaw = u * .pi * 2
        p.highlightAngle = -40 + u * 360
        p.rimIntensity = 0.35 + 0.35 * CGFloat(sin(u * .pi))
    case 1: // glance turn
        let u = local < 1 ? coinEase(local / 1) : 1
        let swing = u < 0.5 ? (u * 2) : (2 - u * 2)
        p.yaw = 0.45 * swing * seed.leanSign
        p.eyeLead = CGFloat(0.16 * swing * seed.leanSign)
    case 2: // head tilt
        let u = local < 1.1 ? sin((local / 1.1) * .pi * 2) : 0
        p.roll = 0.07 * u * amp
    case 3: // nod (translation, not scale)
        let u = local < 0.8 ? abs(sin((local / 0.8) * .pi * 2)) : 0
        p.offset.height = size * 0.02 * CGFloat(u)
    case 4: // lean
        let u = local < 0.9 ? sin((local / 0.9) * .pi) : 0
        p.roll = 0.061 * u * seed.leanSign * amp
        p.offset.width = size * 0.012 * CGFloat(u) * seed.leanSign
    case 5: // rest
        break
    case 6: // think squint
        p.squint = local < 1.0
    case 7: // scan
        if local < 1.2 {
            let u = sin((local / 1.2) * .pi)
            p.yaw = 0.14 * u * seed.leanSign
            p.eyeLead = CGFloat(0.22 * u * seed.leanSign)
        }
    case 8: // rim sheen only
        if local < 0.9 {
            let u = local / 0.9
            p.highlightAngle = -40 + u * 140
            p.rimIntensity = 0.35 + 0.35 * CGFloat(sin(u * .pi))
        }
    default: // half turn
        let u = stroke(0.70)
        p.yaw = u * .pi
        p.highlightAngle = -40 + u * 180
    }
    return p
}

/// Slow start, fast middle, slow stop — the loved coin-turn.
func coinEase(_ t: Double) -> Double {
    let x = min(max(t, 0), 1)
    if x < 0.2 { return 0.20 * (x / 0.2) * (x / 0.2) }
    if x > 0.8 {
        let u = (x - 0.8) / 0.2
        return 0.80 + 0.20 * (1 - (1 - u) * (1 - u))
    }
    return 0.20 + 0.60 * ((x - 0.2) / 0.6)
}

func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> CGFloat {
    let t = min(max((x - e0) / (e1 - e0), 0), 1)
    return CGFloat(t * t * (3 - 2 * t))
}

struct BotView: View {
    let spec: BotLookSpec
    let name: String
    let state: BotRuntimeState
    var size: CGFloat = 52
    var scrollGaze: CGSize = .zero
    var reduceMotion: Bool = false
    var spinToken: Int = 0          // bump to play finish / tap turn

    private var seed: BotSeed { BotSeed(spec: spec, name: name) }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion && state == .idle)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            var motion = targetMotion(
                state: state, spec: spec, seed: seed,
                now: now, size: size, scrollGaze: scrollGaze
            )
            motion = applyOneShotSpin(motion, token: spinToken, now: now, size: size)

            BotFace(spec: spec, motion: motion, size: size)
                .frame(width: size, height: size)
                .offset(motion.offset)
                .rotationEffect(.radians(motion.roll))
                .rotation3DEffect(
                    .radians(motion.yaw),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0
                )
        }
    }
}

/// Finish-spin / tap: latch start time when token changes.
private struct SpinLatch {
    static var start: [Int: TimeInterval] = [:]
}

private func applyOneShotSpin(_ motion: BotMotion, token: Int, now: TimeInterval, size: CGFloat) -> BotMotion {
    guard token != 0 else { return motion }
    if SpinLatch.start[token] == nil { SpinLatch.start[token] = now }
    let t0 = SpinLatch.start[token]!
    let u = (now - t0) / 1.15
    guard u < 1 else { return motion }
    var m = motion
    m.yaw += coinEase(u) * .pi * 2
    m.highlightAngle = -40 + coinEase(u) * 360
    return m
}

struct BotFace: View {
    let spec: BotLookSpec
    let motion: BotMotion
    let size: CGFloat

    var body: some View {
        ZStack {
            bodyShape
                .fill(spec.finish == .flat ? spec.hex : spec.hex.opacity(0.22))
                .overlay { paintedHighlight }
                .modifier(BotGlass(enabled: spec.finish == .glass, spec: spec, motion: motion))

            BotEyes(spec: spec, motion: motion, size: size)
        }
        .shadow(color: spec.finish == .glass ? .black.opacity(0.18) : .clear, radius: size * 0.08, y: size * 0.04)
        .compositingGroup() // keep glass + eyes one layer through the 3D yaw
    }

    private var bodyShape: Path {
        Path.bot(spec.shape, in: CGRect(origin: .zero, size: CGSize(width: size, height: size)), phase: motion.blobPhase)
    }

    @ViewBuilder
    private var paintedHighlight: some View {
        let angle = Angle(degrees: motion.highlightAngle)
        LinearGradient(
            colors: [.white.opacity(spec.finish == .flat ? 0.10 : 0.0), .clear],
            startPoint: .init(x: 0.5 + 0.25 * cos(angle.radians), y: 0.15),
            endPoint: .center
        )
        .clipShape(bodyShape)
        .allowsHitTesting(false)
    }
}

/// iOS 26 glass. Identity of this view must be stable — do not key it on shape/state.
struct BotGlass: ViewModifier {
    let enabled: Bool
    let spec: BotLookSpec
    let motion: BotMotion

    func body(content: Content) -> some View {
        if enabled {
            content
                .glassEffect(.regular.tint(spec.hex.opacity(0.35)), in: .rect)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.18 + 0.25 * motion.rimIntensity), lineWidth: 1)
                        .rotationEffect(.degrees(motion.highlightAngle))
                        .mask(content)
                        .allowsHitTesting(false)
                }
        } else {
            content
        }
    }
}

struct BotEyes: View {
    let spec: BotLookSpec
    let motion: BotMotion
    let size: CGFloat

    var body: some View {
        let slot = size * 0.42
        HStack(spacing: size * 0.08) {
            eye(isLeft: true)
            eye(isLeft: false)
        }
        .offset(
            x: motion.eye.width * slot,
            y: motion.eye.height * slot * 0.35
        )
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func eye(isLeft: Bool) -> some View {
        let open = max(motion.eyeOpen, 0.06)
        Group {
            switch spec.eyes {
            case .tiny:
                Capsule().frame(width: size * 0.07, height: size * 0.07 * open)
            case .round:
                Capsule().frame(width: size * 0.13, height: size * 0.13 * open)
            case .wide:
                Capsule().frame(width: size * 0.16, height: size * 0.08 * open)
            case .tall:
                Capsule().frame(width: size * 0.09, height: size * 0.22 * open)
            case .bold:
                Capsule().frame(width: size * 0.12, height: size * 0.24 * open)
            case .curious:
                if isLeft {
                    Capsule().frame(width: size * 0.12, height: size * 0.12 * open)
                } else {
                    Capsule().frame(width: size * 0.09, height: size * 0.20 * open)
                }
            case .sleepy:
                EyeLid().stroke(style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                    .frame(width: size * 0.14, height: size * 0.06)
                    .opacity(0.85)
            case .classic:
                Capsule().frame(width: size * 0.09, height: size * 0.18 * open)
            }
        }
        .foregroundStyle(eyeFill)
    }

    private var eyeFill: AnyShapeStyle {
        if spec.finish == .glass {
            AnyShapeStyle(.black.opacity(0.72))
        } else {
            AnyShapeStyle(Color(red: 0.07, green: 0.07, blue: 0.09))
        }
    }
}

struct EyeLid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}

extension Path {
    static func bot(_ shape: BotLookSpec.Shape, in r: CGRect, phase: CGFloat) -> Path {
        switch shape {
        case .circle:
            return Path(ellipseIn: r.insetBy(dx: r.width * 0.06, dy: r.height * 0.06))
        case .square:
            return Path(roundedRect: r.insetBy(dx: r.width * 0.08, dy: r.height * 0.08),
                        cornerRadius: r.width * 0.22)
        case .pill:
            let inset = r.insetBy(dx: r.width * 0.04, dy: r.height * 0.22)
            return Path(roundedRect: inset, cornerRadius: inset.height / 2)
        case .blob:
            return blobPath(in: r, phase: phase)
        default:
            return Path(ellipseIn: r.insetBy(dx: r.width * 0.06, dy: r.height * 0.06))
        }
    }

    /// Only the blob is allowed to change silhouette, and only via this phase.
    static func blobPath(in r: CGRect, phase: CGFloat) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let base = min(r.width, r.height) * 0.42
        var pts: [CGPoint] = []
        let n = 6
        for i in 0..<n {
            let a = (Double(i) / Double(n)) * .pi * 2
            let wobble = 1 + 0.07 * sin(a * 2 + Double(phase) * .pi * 2)
            pts.append(CGPoint(x: c.x + cos(a) * base * wobble,
                               y: c.y + sin(a) * base * wobble))
        }
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for i in 0..<n {
            let p = pts[i]
            let q = pts[(i + 1) % n]
            let mid = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            path.addQuadCurve(to: mid, control: p)
        }
        path.closeSubpath()
        return path
    }
}

/// Header usage. Bump `spinToken` when a reply finishes or the bot is tapped.
struct ChatHeaderBot: View {
    let spec: BotLookSpec
    let name: String
    let status: BotRuntimeState
    @State private var spins = 0

    var body: some View {
        VStack(spacing: 6) {
            BotView(spec: spec, name: name, state: status, size: 52, spinToken: spins)
                .onTapGesture { spins += 1 }
            Text(statusLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: status) { _, new in
            if new == .idle { spins += 1 } // finish spin when a working state drops to idle
        }
    }

    private var statusLabel: String {
        switch status {
        case .thinking: "thinking…"
        case .usingTool: "using tools"
        case .awaitingApproval: "needs approval"
        case .reconnecting: "reconnecting"
        case .error: "something broke"
        case .working, .streaming: "working"
        case .idle: name
        }
    }
}

/// Scroll gaze for a list. Attach to the scroll container, pass down.
struct GazePreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ChatList: View {
    @State private var gaze = CGSize.zero
    @State private var settle: Task<Void, Never>?

    var body: some View {
        ScrollView {
            // rows with BotView(..., size: 40, state: .idle, scrollGaze: gaze)
            Color.clear.frame(height: 1)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { old, new in
            let dy = new - old
            gaze = CGSize(width: 0, height: max(-0.2, min(0.2, dy / 18)))
            settle?.cancel()
            settle = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeOut(duration: 0.35)) { gaze = .zero }
            }
        }
    }
}

extension BotView {
    static func widgetPose(_ state: BotRuntimeState) -> BotMotion {
        var m = BotMotion()
        switch state {
        case .thinking, .working, .streaming: m.eyeOpen = 0.42
        case .awaitingApproval: m.roll = 0.10; m.eyeOpen = 1
        case .error: m.eyeOpen = 0.35; m.eye.height = 0.1
        default: break
        }
        return m
    }
}
```

End of consideration. Sections 0–6 still win if anything above disagrees.
