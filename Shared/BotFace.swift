import SwiftUI

/// A bot's look, made in the Creator Studio: a body shape, a pair of eyes and a colour. Drawn the
/// same way in the app, the Live Activity, the notification service and the reply window. The
/// bot itself is the icon: no disc behind it, no circular clip.
public struct BotLookSpec: Hashable, Sendable {
    public var shape: String
    public var eyes: String
    public var hex: String
    /// "flat" (the painted bot) or "glass" (Liquid Glass, like the app icon; beta).
    public var finish: String

    public init(shape: String, eyes: String, hex: String, finish: String = "flat") {
        self.shape = shape
        self.eyes = eyes
        self.hex = hex
        self.finish = finish
    }

    public var isGlass: Bool { finish == "glass" }

    public static let shapes = ["circle", "blob", "square", "pill", "triangle", "hexagon", "cloud", "drop"]
    public static let eyeStyles = ["classic", "tall", "sleepy", "tiny", "round", "wide", "curious", "bold"]
    public static let defaultShape = "blob"
    public static let defaultEyes = "classic"

    /// The avatar choice string the app stores: "studio:<shape>:<eyes>" plus ":glass" for the
    /// glass finish. Older values ("initial", "animated:<style>") map onto a shape so nothing
    /// looks broken after the update.
    public static func from(choice raw: String?, hex: String) -> BotLookSpec {
        let parts = (raw ?? "").split(separator: ":").map(String.init)
        if parts.first == "studio", parts.count == 3 || parts.count == 4, shapes.contains(parts[1]), eyeStyles.contains(parts[2]) {
            return BotLookSpec(shape: parts[1], eyes: parts[2], hex: hex, finish: parts.count == 4 && parts[3] == "glass" ? "glass" : "flat")
        }
        if parts.first == "animated", parts.count == 2 {
            let legacy: [String: (String, String)] = ["nimbus": ("cloud", "classic"), "halo": ("circle", "round"), "pip": ("drop", "tiny"),
                                                      "ember": ("triangle", "bold"), "wisp": ("pill", "wide"), "prism": ("hexagon", "curious")]
            if let (s, e) = legacy[parts[1]] { return BotLookSpec(shape: s, eyes: e, hex: hex) }
        }
        return BotLookSpec(shape: defaultShape, eyes: defaultEyes, hex: hex)
    }

    public var choiceString: String { "studio:\(shape):\(eyes)" + (isGlass ? ":glass" : "") }

    public static func name(ofShape s: String) -> String {
        ["circle": "Circle", "blob": "Blob", "square": "Square", "pill": "Pill", "triangle": "Triangle", "hexagon": "Hex", "cloud": "Cloud", "drop": "Drop"][s] ?? s.capitalized
    }
    public static func name(ofEyes e: String) -> String { e.capitalized }
}

/// Procedural drawing of a bot: body path, colour, eyes with blink and glance. Everything is a
/// function of `time`, so a still frame is `time: 0` and the same code animates in a TimelineView.
public enum BotFace {
    /// The body, filling the square with a little breathing room.
    public static func bodyPath(_ shape: String, in box: CGRect, time t: Double, active: Bool) -> Path {
        let r = box.insetBy(dx: box.width * 0.04, dy: box.height * 0.04)
        let c = CGPoint(x: r.midX, y: r.midY)
        switch shape {
        case "circle":
            return Path(ellipseIn: r)
        case "square":
            return Path(roundedRect: r, cornerRadius: r.width * 0.28, style: .continuous)
        case "pill":
            let h = r.height * 0.64
            return Path(roundedRect: CGRect(x: r.minX, y: c.y - h / 2, width: r.width, height: h), cornerRadius: h / 2, style: .continuous)
        case "triangle":
            // Inscribed in a circle a triangle sits high and small; centre it lower and larger so
            // the base reaches near the bottom and the eyes have a face to sit in.
            let d = r.width * 1.16
            let box2 = CGRect(x: c.x - d / 2, y: r.minY + r.height * 0.56 - d / 2, width: d, height: d)
            return roundedPolygon(sides: 3, in: box2, rotation: -.pi / 2, corner: r.width * 0.24)
        case "hexagon":
            return roundedPolygon(sides: 6, in: r, rotation: -.pi / 2, corner: r.width * 0.10)
        case "cloud":
            var p = Path()
            let w = r.width, h = r.height
            p.addRoundedRect(in: CGRect(x: r.minX + w * 0.06, y: r.minY + h * 0.45, width: w * 0.88, height: h * 0.42), cornerSize: CGSize(width: h * 0.21, height: h * 0.21))
            p.addEllipse(in: CGRect(x: r.minX + w * 0.16, y: r.minY + h * 0.26, width: w * 0.36, height: w * 0.36))
            p.addEllipse(in: CGRect(x: r.minX + w * 0.38, y: r.minY + h * 0.12, width: w * 0.42, height: w * 0.42))
            p.addEllipse(in: CGRect(x: r.minX + w * 0.58, y: r.minY + h * 0.34, width: w * 0.30, height: w * 0.30))
            return p
        case "drop":
            var p = Path()
            let w = r.width, h = r.height
            let bottom = CGPoint(x: c.x, y: r.maxY)
            let radius = w * 0.40
            let centre = CGPoint(x: c.x, y: r.maxY - radius)
            p.move(to: CGPoint(x: c.x, y: r.minY + h * 0.02))
            p.addCurve(to: CGPoint(x: centre.x + radius, y: centre.y), control1: CGPoint(x: c.x + w * 0.08, y: r.minY + h * 0.30), control2: CGPoint(x: centre.x + radius, y: centre.y - radius * 0.65))
            p.addArc(center: centre, radius: radius, startAngle: .zero, endAngle: .radians(.pi), clockwise: false)
            p.addCurve(to: CGPoint(x: c.x, y: r.minY + h * 0.02), control1: CGPoint(x: centre.x - radius, y: centre.y - radius * 0.65), control2: CGPoint(x: c.x - w * 0.08, y: r.minY + h * 0.30))
            _ = bottom
            p.closeSubpath()
            return p
        default: // blob: a soft, slightly irregular round that slowly morphs while the bot works
            var p = Path()
            let base = min(r.width, r.height) / 2
            // The only shape whose outline moves: a slow creep while working, frozen at rest.
            let phase = active ? t * 0.19 : 0
            let n = 96
            for i in 0...n {
                let a = Double(i) / Double(n) * 2 * .pi
                let wobble = 1 + 0.055 * sin(3 * a + 0.9 + phase) + 0.035 * sin(5 * a - 0.4 - phase * 0.7)
                let pt = CGPoint(x: c.x + cos(a) * base * wobble, y: c.y + sin(a) * base * wobble)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }
    }

    static func roundedPolygon(sides: Int, in r: CGRect, rotation: Double, corner: CGFloat) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) / 2
        let pts: [CGPoint] = (0..<sides).map { i in
            let a = rotation + Double(i) / Double(sides) * 2 * .pi
            return CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
        }
        var p = Path()
        for i in 0..<sides {
            let prev = pts[(i + sides - 1) % sides], cur = pts[i], next = pts[(i + 1) % sides]
            func towards(_ a: CGPoint, _ b: CGPoint, _ d: CGFloat) -> CGPoint {
                let dx = b.x - a.x, dy = b.y - a.y, len = max(1, (dx * dx + dy * dy).squareRoot())
                return CGPoint(x: a.x + dx / len * d, y: a.y + dy / len * d)
            }
            let inPt = towards(cur, prev, corner), outPt = towards(cur, next, corner)
            if i == 0 { p.move(to: inPt) } else { p.addLine(to: inPt) }
            p.addQuadCurve(to: outPt, control: cur)
        }
        p.closeSubpath()
        return p
    }

    /// Where the eyes sit for a shape (fraction of the square), and how far apart.
    static func eyeAnchor(_ shape: String) -> (y: CGFloat, spread: CGFloat) {
        switch shape {
        case "triangle": return (0.64, 0.10)
        case "drop": return (0.62, 0.11)
        case "cloud": return (0.58, 0.11)
        case "pill": return (0.50, 0.13)
        default: return (0.47, 0.13)
        }
    }

    /// Blink (0 open … 1 shut) and glance (−1 … 1) as functions of time, offset per bot so a
    /// list of bots does not blink in unison. `blinkPeriod` shortens while thinking or asking;
    /// `rare` adds the once-in-a-while slow blink or moment's squint that makes an idle bot alive.
    static func liveliness(time t: Double, seed: Int, blinkPeriod: Double = 4.3, blinkLength: Double = 0.15, doubleBlinks: Bool = true, glancePeriod: Double = 7.0, rare: Bool = true) -> (blink: Double, glance: Double, breath: Double) {
        guard t > 0 else { return (0, 0, 0) }
        let offset = Double(seed % 17) * 0.37
        let tt = t + offset
        // A blink every ~4.3 s, 150 ms long, every third one a double blink.
        let phase = tt.truncatingRemainder(dividingBy: blinkPeriod)
        var blink = 0.0
        if phase < blinkLength { blink = sin(phase / blinkLength * .pi) }
        else if doubleBlinks, Int(tt / blinkPeriod) % 3 == 0, phase > blinkLength + 0.09, phase < 2 * blinkLength + 0.09 { blink = sin((phase - blinkLength - 0.09) / blinkLength * .pi) }
        // Once in ~25 s something slower: a long blink (220 ms) or a moment's squint. Eyes only.
        if rare {
            let rp = (tt + Double(seed % 11) * 1.7).truncatingRemainder(dividingBy: 25)
            if rp > 9.0, rp < 9.22 { blink = max(blink, sin((rp - 9.0) / 0.22 * .pi)) }
            else if rp > 17.0, rp < 17.3 { blink = max(blink, 0.3 * sin((rp - 17.0) / 0.3 * .pi)) }
        }
        // A glance to one side every ~7 s, held for a moment, then back.
        let gp = (tt * 0.9).truncatingRemainder(dividingBy: glancePeriod)
        var glance = 0.0
        if gp > 1.2, gp < 2.6 {
            let u = (gp - 1.2) / 1.4
            let ease = u < 0.2 ? u / 0.2 : u > 0.8 ? (1 - u) / 0.2 : 1
            glance = ease * (Int(tt / glancePeriod) % 2 == 0 ? 1 : -1)
        }
        let breath = 0.5 + 0.5 * sin(tt * 2 * .pi / 2.6)
        return (blink, glance, breath)
    }

    /// What a bot is doing beyond idle. Each state is a pose the eyes and body settle into;
    /// `working` is the five-second routine blocks, the rest are one-shots that hold.
    public enum State: Equatable, Sendable { case idle, working, thinking, usingTool, streaming, awaitingApproval, error, reconnecting, guide }

    /// One frame's pose: the body's transforms (small, in place, never scaled) plus what the
    /// eyes and the glass rim are asked to do on top of their own life.
    public struct Motion: Equatable, Sendable {
        public var yaw: Double = 0        // radians about the vertical axis (a 3D turn, like a coin)
        public var roll: Double = 0       // radians about the centre, in the plane
        public var dx: CGFloat = 0        // horizontal offset as a fraction of the size
        public var dy: CGFloat = 0        // vertical offset as a fraction of the size (positive = down)
        /// Cap on how open the eyes are (1 = free; 0.42 is the thinking squint).
        public var eyeOpen: Double = 1
        /// Extra glance, −1…1 on each axis, on top of the eyes' own wandering (scaled like `gaze`).
        public var eyeX: Double = 0
        public var eyeY: Double = 0
        /// The eyes stop wandering on their own (they still blink): the asking pose.
        public var freezeGlance = false
        /// Blink cadence in seconds: 4.3 at rest, 2.8 while thinking or asking.
        public var blinkPeriod: Double = 4.3
        /// Light travelling the rim: strength 0…1 centred at `sheenAngle` degrees (0 = right,
        /// clockwise; −130 is the lit top-left corner).
        public var sheen: Double = 0
        public var sheenAngle: Double = -130
        public static let still = Motion()
        /// The same pose with the body at rest (Reduce Motion): the eyes keep theirs.
        public var bodyStill: Motion { var m = self; m.yaw = 0; m.roll = 0; m.dx = 0; m.dy = 0; m.sheen = 0; return m }
    }

    static func smooth(_ x: Double) -> Double { let u = min(1, max(0, x)); return u * u * (3 - 2 * u) }
    /// Slow start, quick middle, slow stop — a whole turn in one stroke.
    static func stroke(_ x: Double) -> Double { let u = min(1, max(0, x)); return u * u * u * (u * (u * 6 - 15) + 10) }

    /// The pose at time `t` for a bot in `state`. `since`: seconds since the state began (the
    /// one-shots at a state's start count from here). `finishedAt` / `tappedAt`: the reply just
    /// ended / the bot was just tapped — a full turn / a small one, over anything else. `group`:
    /// in a group only one bot moves its body per block, in turn.
    /// Bots share the clock but not the phase: `seed` (shape, eyes and name) offsets each one's
    /// blocks and picks its routine, so a page of bots never moves in unison.
    public static func motion(time t: Double, seed: Int, spec: BotLookSpec, state: State, since: Double = 0, finishedAt: Double? = nil, tappedAt: Double? = nil, group: (index: Int, count: Int)? = nil) -> Motion {
        let sign: Double = seed % 2 == 0 ? 1 : -1
        // Per-shape flavour: the cloud keeps its flat bottom planted, the pill's wide face makes
        // any roll read large, the drop's point should not stab.
        let rollAmp: Double = spec.shape == "cloud" ? 0.75 : 1
        let rollCap: Double = spec.shape == "pill" ? 0.052 : 1
        func roll(_ r: Double) -> Double { max(-rollCap, min(rollCap, r * rollAmp)) }
        var m = Motion()

        // The finish: one full turn, a blink as the face goes edge-on, then a glance down at the
        // new bubble. Plays over anything else.
        if let f = finishedAt, t - f >= 0, t - f < 1.75 {
            let u = t - f
            if u < 1.15 {
                let k = stroke(u / 1.15)
                m.yaw = k * 2 * .pi
                m.sheen = 0.7 * sin(k * .pi); m.sheenAngle = -130 + k * 360
                if abs(u - 0.575) < 0.08 { m.eyeOpen = 0.1 }
            } else {
                m.eyeY = 0.5 * sin((u - 1.15) / 0.6 * .pi)
            }
            return m
        }
        // A tap: a small turn and back with a blink, and a tick of light on the rim — pressing a
        // physical chip, not a button.
        if let tp = tappedAt, t - tp >= 0, t - tp < 0.55 {
            let u = (t - tp) / 0.55
            m.yaw = 0.314 * (u < 0.5 ? stroke(u * 2) : stroke((1 - u) * 2))
            m.sheen = 0.6 * sin(u * .pi); m.sheenAngle = -130 + 90 * u
            if u > 0.42, u < 0.68 { m.eyeOpen = 0.12 }
            return m
        }

        switch state {
        case .idle:
            break
        case .guide:
            // Vory on a guided screen: idle eyes and, once in eight seconds, light across the rim.
            let l = (t + Double(seed % 7)).truncatingRemainder(dividingBy: 8)
            if l > 2.0, l < 2.9 { let u = (l - 2.0) / 0.9; m.sheen = 0.7 * sin(u * .pi); m.sheenAngle = -130 + u * 140 }
        case .streaming:
            // Beside a bubble, too small for the body: a squint and the occasional glance.
            m.eyeOpen = 0.55
        case .thinking:
            // Eyes narrow, a hair of roll, blinks come sooner. No turn: that is for the finish.
            m.eyeOpen = 0.42
            m.roll = roll(0.026 * sign) * smooth(since / 0.3)
            m.blinkPeriod = 2.8
        case .usingTool:
            // A look down toward where the tool is, and one lean that way as it starts: in,
            // hold, back. Never a spin.
            m.eyeX = 0.8; m.eyeY = 0.6
            if spec.eyes == "classic" || spec.eyes == "bold" { m.eyeOpen = 0.92 }
            if since < 0.9 {
                let e = since < 0.25 ? smooth(since / 0.25) : since < 0.65 ? 1 : 1 - smooth((since - 0.65) / 0.25)
                m.roll = roll(0.061 * e)
                m.dx = 0.012 * CGFloat(e)
            }
        case .awaitingApproval:
            // The ask: eyes open and steady, a lean held to one side, and every 2.8 s a blink
            // then a small nudge toward the person. "Well?"
            m.freezeGlance = true
            m.blinkPeriod = 2.8
            m.roll = roll((spec.shape == "drop" ? 0.07 : 0.105) * sign) * smooth(since / 0.35)
            let l = (t + Double(seed % 17) * 0.37).truncatingRemainder(dividingBy: 2.8)
            if l > 0.15, l < 0.6 { m.dx = 0.02 * CGFloat(sin((l - 0.15) / 0.45 * .pi)) * CGFloat(sign) }
        case .error:
            // Eyes low and lowered, one slow blink, then hold. No turn.
            m.eyeOpen = 0.35; m.eyeY = 0.8; m.freezeGlance = true
            if since > 0.3, since < 0.52 { m.eyeOpen = min(m.eyeOpen, 1 - 0.92 * sin((since - 0.3) / 0.22 * .pi)) }
        case .reconnecting:
            // A metronome: the eyes swing left, right, left, 1.1 s a swing. Body still.
            m.eyeX = 0.9 * sin(t * 2 * .pi / 2.2); m.freezeGlance = true
        case .working:
            // Five-second blocks; the first second or so plays one routine, the rest is still.
            // In a group the clock is shared and the bots take turns; alone, each bot's blocks
            // are offset by its seed.
            let block = 5.0
            let tt = group == nil ? t + Double(seed % 47) * 0.31 : t
            let index = Int(tt / block)
            let u = tt.truncatingRemainder(dividingBy: block)
            if let g = group, g.count > 1, index % g.count != g.index { break }
            // Swift's % keeps the sign: fold to 0…9 so a negative seed cannot pin one routine.
            var kind = (((index &+ seed) % 10) + 10) % 10
            if spec.shape == "triangle", kind == 3 { kind = 4 }   // the triangle leans rather than nods
            switch kind {
            case 0: // the full turn on the spot, the light riding the rim with it
                guard u < 1.15 else { break }
                let k = stroke(u / 1.15)
                m.yaw = k * 2 * .pi
                m.sheen = 0.7 * sin(k * .pi); m.sheenAngle = -130 + k * 360
            case 1: // a glance to one side and back: a partial turn, the eyes 60 ms ahead of it
                guard u < 1.0 else { break }
                m.yaw = 0.45 * sin(u * .pi) * sign
                m.eyeX = 0.9 * sin(min(1, u + 0.06) * .pi) * sign
            case 2: // a small tilt of the head, once each way
                guard u < 1.1 else { break }
                m.roll = roll(0.07 * sin(u / 1.1 * 2 * .pi) * (1 - smooth((u - 0.7) / 0.4)))
            case 3: // a nod: two tiny dips (a move, not a squash)
                guard u < 0.8 else { break }
                m.dy = (spec.shape == "drop" ? 0.015 : 0.02) * CGFloat(abs(sin(u / 0.8 * 2 * .pi)))
            case 4: // a lean: a few degrees and a point sideways, then back
                guard u < 0.9 else { break }
                let e = sin(u / 0.9 * .pi)
                m.roll = roll(0.061 * e * sign)
                m.dx = 0.012 * CGFloat(e) * CGFloat(sign)
            case 5: // rest
                break
            case 6: // a squint and settle: narrow, hold, open most of the way
                if u < 0.18 { m.eyeOpen = 1 - 0.58 * smooth(u / 0.18) }
                else if u < 0.58 { m.eyeOpen = 0.42 }
                else if u < 0.8 { m.eyeOpen = 0.42 + 0.5 * smooth((u - 0.58) / 0.22) }
            case 7: // a scan: the eyes sweep one way then the other, the body barely following
                guard u < 1.2 else { break }
                let e = sin(u / 1.2 * 2 * .pi) * sign
                m.eyeX = e
                m.yaw = 0.14 * e
            case 8: // light across the rim, nothing else
                guard u < 0.9 else { break }
                let k = u / 0.9
                m.sheen = 0.7 * sin(k * .pi); m.sheenAngle = -130 + k * 140
            default: // a half turn: round to the other side, a blink there, then round again
                if u < 0.7 {
                    let k = stroke(u / 0.7)
                    m.yaw = k * .pi; m.sheen = 0.6 * sin(k * .pi); m.sheenAngle = -130 + k * 180
                } else if u < 1.25 {
                    m.yaw = .pi
                    if u > 0.85, u < 1.0 { m.eyeOpen = 0.1 }
                } else if u < 1.95 {
                    let k = stroke((u - 1.25) / 0.7)
                    m.yaw = .pi + k * .pi; m.sheen = 0.6 * sin(k * .pi); m.sheenAngle = 50 + k * 180
                }
            }
        }
        return m
    }

    /// A still pose for the widgets, which cannot run a timeline: the squint of a working bot,
    /// the held lean of one asking, the lowered eyes of an error.
    public static func widgetPose(phase: String, attention: Bool) -> Motion {
        var m = Motion()
        if attention { m.roll = 0.105; return m }
        switch phase {
        case "thinking", "streaming", "tool", "working": m.eyeOpen = 0.42
        case "error", "failed": m.eyeOpen = 0.35; m.eyeY = 0.8
        default: break
        }
        return m
    }

    /// Where each shape's bottom edge sits, as a fraction of the square (the blob reaches
    /// 0.985; the pill, cloud and triangle end well above that). Set by hand from the drawing.
    public static func baseline(of shape: String) -> CGFloat {
        switch shape {
        case "blob": return 0.985
        case "pill": return 0.795
        case "cloud": return 0.825
        case "triangle": return 0.815
        default: return 0.96   // circle, square, hexagon, drop
        }
    }

    /// How far down (fraction of the size) to move a bot so its base lands where the blob's does,
    /// so every shape sits on a pill the same way.
    public static func seatDrop(_ shape: String) -> CGFloat { 0.985 - baseline(of: shape) }

    /// Whether the eyes have something to do around `t` (a blink or a glance): idle bots only
    /// redraw during these moments.
    public static func eyesBusy(time t: Double, seed: Int) -> Bool {
        for dt in [0.0, 0.12, 0.24] {
            let l = liveliness(time: t + dt, seed: seed)
            if l.blink > 0.01 || l.glance != 0 { return true }
        }
        return false
    }

    /// Which part of the bot to draw: everything, or just one layer (the app draws a glass bot as
    /// real glass for the body and the eyes, and only needs the eyes' geometry from here).
    public enum Part { case all, body, eyes }

    /// Set by the app: it can draw glass bots with real Liquid Glass (a backdrop exists). The
    /// extensions and offscreen renders keep the painted approximation.
    nonisolated(unsafe) public static var liveGlass = false

    /// The eyes' ink; on a glass bot they are dark glass, drawn a little lighter.
    static let ink = Color(red: 0.05, green: 0.05, blue: 0.07)

    /// The whisper of squash and stretch about the bottom while working.
    static func breathScale(time t: Double, active: Bool, spec: BotLookSpec) -> CGFloat {
        guard active else { return 1 }
        let seed = spec.shape.utf8.reduce(0) { $0 + Int($1) } + spec.eyes.utf8.reduce(0) { $0 + Int($1) }
        return 1 + 0.025 * (liveliness(time: t, seed: seed).breath - 0.5)
    }

    /// Draws body and eyes into `size` (square). `active` animates; otherwise `time` should be 0.
    public static func draw(_ spec: BotLookSpec, in ctx: inout GraphicsContext, size: CGSize, time t: Double, active: Bool, gaze: CGPoint = .zero, part: Part = .all, breathe: Bool = true, idleEyes: Bool = false, move: Bool = true, strain: Bool = false, glanceFree: Bool = true, finishedAt: Double? = nil, light: Bool = false, motion: Motion = .still) {
        let box = CGRect(origin: .zero, size: size)
        let s = min(size.width, size.height)
        let seed = spec.shape.utf8.reduce(0) { $0 + Int($1) } + spec.eyes.utf8.reduce(0) { $0 + Int($1) }
        // Idle bots still blink and glance (`idleEyes`); only a working one moves its body.
        let live = liveliness(time: (active || idleEyes) ? t : 0, seed: seed)
        let tint = Color(botHex: spec.hex) ?? Color(red: 0.49, green: 0.36, blue: 1)

        _ = move; _ = finishedAt   // yaw and offsets are applied by BotFaceView (a 3D turn needs a view)
        // A roll can be painted (the widgets' held lean).
        if motion.roll != 0 {
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: .radians(motion.roll))
            ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
        }
        // Breathing: a whisper of squash and stretch about the bottom while working.
        if active && breathe {
            let sy = 1 + 0.025 * (live.breath - 0.5)
            ctx.translateBy(x: size.width / 2, y: size.height * 0.96)
            ctx.scaleBy(x: 1 / sy, y: sy)
            ctx.translateBy(x: -size.width / 2, y: -size.height * 0.96)
        }

        let body = bodyPath(spec.shape, in: box, time: t, active: active)
        if part != .eyes {
            if spec.isGlass {
                drawGlassBody(body, tint: tint, in: &ctx, box: box, s: s, light: light)
            } else {
                ctx.fill(body, with: .linearGradient(Gradient(colors: [tint.opacity(1), tint.opacity(0.84)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
                // A soft light across the top, clipped to the body so shapes made of several pieces (the
                // cloud) show no seams: just the shape and its colour.
                ctx.drawLayer { layer in
                    layer.clip(to: body)
                    layer.fill(Path(box), with: .linearGradient(Gradient(colors: [.white.opacity(0.22), .white.opacity(0)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.55)))
                }
            }
        }
        if part != .eyes, motion.sheen > 0.01 { drawSheen(body, in: &ctx, box: box, s: s, sheen: motion.sheen, angle: motion.sheenAngle, glass: spec.isGlass) }
        guard part != .body else { return }

        // Eyes: black shapes, blinking by squashing to a line, glancing by sliding.
        let eyes = eyePaths(spec, size: size, time: t, active: active || idleEyes, gaze: gaze, strain: strain, glanceFree: glanceFree, motion: motion)
        let eyeInk = spec.isGlass ? ink.opacity(0.9) : ink
        if eyes.stroked {
            ctx.stroke(eyes.path, with: .color(eyeInk), style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
        } else {
            ctx.fill(eyes.path, with: .color(eyeInk))
            if spec.isGlass {
                // The rim of a dark glass eye: a hair of light along its top edge.
                ctx.drawLayer { layer in
                    layer.clip(to: eyes.path)
                    layer.stroke(eyes.path, with: .linearGradient(Gradient(colors: [.white.opacity(0.55), .white.opacity(0)]), startPoint: CGPoint(x: 0, y: eyes.path.boundingRect.minY), endPoint: CGPoint(x: 0, y: eyes.path.boundingRect.maxY)), lineWidth: s * 0.03)
                }
            }
        }
    }

    /// The painted stand-in for Liquid Glass, for where real glass cannot render (widgets,
    /// notification images, menu icons): a translucent tinted body with a lit rim, a darker
    /// lower edge and a soft highlight across the top, like the app icon.
    /// `light`: match the live glass on a light background — the live version lays the colour
    /// down at 62 % plus a light glass tint, so the painted one stays airy: no dark rim, a
    /// lighter shadow, the colour itself a touch lifted. Dark mode keeps the deeper version.
    static func drawGlassBody(_ body: Path, tint: Color, in ctx: inout GraphicsContext, box: CGRect, s: CGFloat, light: Bool = false) {
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(light ? 0.12 : 0.28), radius: s * 0.05, y: s * 0.03))
            let top = light ? tint.opacity(0.82) : tint.opacity(0.92)
            let bottom = light ? tint.opacity(0.68) : tint.opacity(0.62)
            layer.fill(body, with: .linearGradient(Gradient(colors: [top, bottom]), startPoint: CGPoint(x: 0, y: box.minY), endPoint: CGPoint(x: 0, y: box.maxY)))
        }
        ctx.drawLayer { layer in
            layer.clip(to: body)
            // Specular: light pooling along the top, fading out a third of the way down.
            layer.fill(Path(box), with: .linearGradient(Gradient(colors: [.white.opacity(light ? 0.5 : 0.42), .white.opacity(0.05), .white.opacity(0)]), startPoint: CGPoint(x: 0, y: box.minY), endPoint: CGPoint(x: 0, y: box.maxY * 0.5)))
        }
        let rimDark: Color = light ? .black.opacity(0.10) : .black.opacity(0.28)
        // Rim: bright where the light hits (top-left), dark on the underside. Not a stroke: the
        // cloud is several overlapping pieces and a stroke draws every inner edge (the doubled
        // cloud seen in the profile menu). Fill the body, then punch out the body shrunk a little
        // about its centre, which leaves only the outline.
        ctx.drawLayer { layer in
            layer.fill(body, with: .linearGradient(Gradient(colors: [.white.opacity(0.9), .white.opacity(0.15), rimDark]), startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.maxX, y: box.maxY)))
            layer.blendMode = .destinationOut
            let b = body.boundingRect
            let k = max(0, 1 - (s * 0.045) / max(b.width, 1))
            let inner = body.applying(CGAffineTransform(translationX: b.midX, y: b.midY).scaledBy(x: k, y: k).translatedBy(x: -b.midX, y: -b.midY))
            layer.fill(inner, with: .color(.black))
        }
    }

    /// Light travelling the rim: a short bright arc of the outline at `angle`, the rest of the
    /// ring clear. Built like the glass rim (the body minus the body shrunk) so the cloud's
    /// inner edges do not show. On a flat bot it is fainter, a slide of the painted highlight.
    static func drawSheen(_ body: Path, in ctx: inout GraphicsContext, box: CGRect, s: CGFloat, sheen: Double, angle: Double, glass: Bool) {
        ctx.drawLayer { layer in
            let peak = Color.white.opacity((glass ? 0.95 : 0.55) * sheen)
            let stops: [Gradient.Stop] = [.init(color: .clear, location: 0), .init(color: .clear, location: 0.34), .init(color: peak, location: 0.5), .init(color: .clear, location: 0.66), .init(color: .clear, location: 1)]
            layer.fill(body, with: .conicGradient(Gradient(stops: stops), center: CGPoint(x: box.midX, y: box.midY), angle: .degrees(angle - 180)))
            layer.blendMode = .destinationOut
            let b = body.boundingRect
            let k = max(0, 1 - (s * 0.05) / max(b.width, 1))
            layer.fill(body.applying(CGAffineTransform(translationX: b.midX, y: b.midY).scaledBy(x: k, y: k).translatedBy(x: -b.midX, y: -b.midY)), with: .color(.black))
        }
    }

    /// The eyes' geometry for a frame: one path (both eyes) and whether it is stroked (sleepy
    /// lids) rather than filled. Both eyes move together: a glance or a gaze shifts the pair,
    /// never their spacing.
    /// `strain`: the bot is thinking hard — the eyes narrow to a squint. `glanceFree`: false keeps
    /// the eyes from wandering on their own (they still blink), for when they follow the phone.
    public static func eyePaths(_ spec: BotLookSpec, size: CGSize, time t: Double, active: Bool, gaze: CGPoint = .zero, strain: Bool = false, glanceFree: Bool = true, motion: Motion = .still) -> (path: Path, stroked: Bool) {
        let s = min(size.width, size.height)
        let seed = spec.shape.utf8.reduce(0) { $0 + Int($1) } + spec.eyes.utf8.reduce(0) { $0 + Int($1) }
        // Tiny eyes blink faster (they are already small) and skip the double blink when small.
        let tiny = spec.eyes == "tiny"
        let live = liveliness(time: active ? t : 0, seed: seed, blinkPeriod: motion.blinkPeriod, blinkLength: tiny ? 0.09 : 0.15, doubleBlinks: !(tiny && s < 32), rare: motion.blinkPeriod == 4.3)
        let anchor = eyeAnchor(spec.shape)
        let dx = s * anchor.spread
        let wander = glanceFree && !motion.freezeGlance
        let gx = gaze.x + CGFloat(motion.eyeX), gy = gaze.y + CGFloat(motion.eyeY)
        let cx = size.width / 2 + (wander ? CGFloat(live.glance) * s * 0.06 : 0) + gx * s * 0.06
        let cy = s * anchor.y + gy * s * 0.07
        let open = min(CGFloat(1 - live.blink * 0.92), strain ? 0.42 : 1, CGFloat(motion.eyeOpen))
        var path = Path()
        func eye(at x: CGFloat, w: CGFloat, h: CGFloat, round: Bool) {
            let hh = max(s * 0.025, h * open)
            let rect = CGRect(x: x - w / 2, y: cy - hh / 2, width: w, height: hh)
            path.addPath(round && open > 0.5 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: min(w, hh) / 2, style: .continuous))
        }
        if spec.eyes == "sleepy" {
            // Lids: two soft downward arcs. They never squash to a line; instead the lids get a
            // little heavier and lighter over a couple of seconds.
            let weight = active ? 0.5 + 0.5 * sin(t * .pi / 2.15) : 0
            for x in [cx - dx, cx + dx] {
                path.move(to: CGPoint(x: x - s * 0.075, y: cy - s * 0.01))
                path.addQuadCurve(to: CGPoint(x: x + s * 0.075, y: cy - s * 0.01), control: CGPoint(x: x, y: cy + s * (0.05 + 0.025 * weight)))
            }
            return (path, true)
        }
        switch spec.eyes {
        case "tall":
            eye(at: cx - dx, w: s * 0.085, h: s * 0.30, round: false); eye(at: cx + dx, w: s * 0.085, h: s * 0.30, round: false)
        case "tiny":
            eye(at: cx - dx * 0.8, w: s * 0.07, h: s * 0.07, round: true); eye(at: cx + dx * 0.8, w: s * 0.07, h: s * 0.07, round: true)
        case "round":
            eye(at: cx - dx, w: s * 0.13, h: s * 0.13, round: true); eye(at: cx + dx, w: s * 0.13, h: s * 0.13, round: true)
        case "wide":
            eye(at: cx - dx, w: s * 0.16, h: s * 0.075, round: false); eye(at: cx + dx, w: s * 0.16, h: s * 0.075, round: false)
        case "curious":
            // The tall eye follows a glance 60 ms behind the round one.
            let late = wander ? CGFloat(liveliness(time: active ? t - 0.06 : 0, seed: seed, blinkPeriod: motion.blinkPeriod).glance) * s * 0.06 : 0
            let rx = size.width / 2 + late + gx * s * 0.06 + dx
            eye(at: cx - dx, w: s * 0.09, h: s * 0.09, round: true); eye(at: rx, w: s * 0.085, h: s * 0.20, round: false)
        case "bold":
            eye(at: cx - dx, w: s * 0.13, h: s * 0.27, round: false); eye(at: cx + dx, w: s * 0.13, h: s * 0.27, round: false)
        default: // classic
            eye(at: cx - dx, w: s * 0.10, h: s * 0.22, round: false); eye(at: cx + dx, w: s * 0.10, h: s * 0.22, round: false)
        }
        return (path, false)
    }
}

/// What every bot on screen reacts to together: where the last scroll went (the eyes follow
/// it) and how the device is tilted (the bot leans with it). Fed by the app; the extensions
/// leave it at rest. `enabled` is the Settings › Bots switch.
@MainActor @Observable
public final class BotAmbient {
    public static let shared = BotAmbient()
    /// −1…1 on each axis; decays back to zero when the scrolling stops.
    public var gaze: CGPoint = .zero
    /// −1…1: roll (x) and pitch (y) away from the resting hold.
    public var tilt: CGPoint = .zero
    public var enabled = true
    /// True while a list is being scrolled (cleared shortly after the last movement); the Bots
    /// page bots play while it is.
    public var scrolling = false
    /// When each bot (by profile name) last finished a turn: it spins once at that moment.
    public var finished: [String: Date] = [:]
    private var decayTask: Task<Void, Never>?
    private var lastGazeAt: Date = .distantPast

    public init() {}

    /// A scroll of `dy` points (positive = content moving up, the finger swiping up). Every bot
    /// on screen observes `gaze`, so it moves at most ~16 times a second and only when the change
    /// is worth a redraw; `scrolling` is set once, not on every tick.
    public func scrolled(dy: CGFloat) {
        guard abs(dy) > 0.5 else { return }
        let now = Date()
        if enabled, now.timeIntervalSince(lastGazeAt) > 0.06 {
            let y = max(-1, min(1, gaze.y * 0.6 + CGFloat(-dy) / 40))
            if abs(y - gaze.y) > 0.03 { gaze = CGPoint(x: gaze.x, y: y) }
            lastGazeAt = now
        }
        if !scrolling { scrolling = true }
        decayTask?.cancel()
        decayTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            self.gaze = .zero
            self.scrolling = false
        }
    }

    public func turnFinished(profile: String) { finished[profile] = Date() }
    /// When each bot was last tapped: a small turn and a blink at that moment.
    public var tapped: [String: Date] = [:]
    public func tap(profile: String) { tapped[profile] = Date() }
}

/// The bot's body as a Shape, so the app can give it real Liquid Glass.
public struct BotBodyShape: Shape {
    public var spec: BotLookSpec
    public var time: Double
    public var active: Bool
    public init(spec: BotLookSpec, time: Double, active: Bool) { self.spec = spec; self.time = time; self.active = active }
    public func path(in rect: CGRect) -> Path { BotFace.bodyPath(spec.shape, in: rect, time: time, active: active) }
}

/// The bot's eyes as a Shape (filled styles only; sleepy lids stay painted).
public struct BotEyesShape: Shape {
    public var spec: BotLookSpec
    public var time: Double
    public var active: Bool
    public var gaze: CGPoint
    public var strain = false
    public var glanceFree = true
    public var motion: BotFace.Motion = .still
    public init(spec: BotLookSpec, time: Double, active: Bool, gaze: CGPoint, strain: Bool = false, glanceFree: Bool = true, motion: BotFace.Motion = .still) {
        self.spec = spec; self.time = time; self.active = active; self.gaze = gaze; self.strain = strain; self.glanceFree = glanceFree; self.motion = motion
    }
    public func path(in rect: CGRect) -> Path { BotFace.eyePaths(spec, size: rect.size, time: time, active: active, gaze: gaze, strain: strain, glanceFree: glanceFree, motion: motion).path.offsetBy(dx: rect.minX, dy: rect.minY) }
}

/// The bot as a view. `active` runs the animation (blink, glance, the blob's morph and the
/// working routines); otherwise it is a still frame, so a list of idle bots costs nothing.
public struct BotFaceView: View {
    public var spec: BotLookSpec
    public var size: CGFloat
    public var active: Bool
    /// Where the eyes look, −1…1 on each axis (0,0 straight ahead); eased over a third of a second.
    public var gaze: CGPoint
    @State private var shownGaze: CGPoint = .zero
    @State private var gazeFrom: CGPoint = .zero
    @State private var gazeChangedAt: Date = .distantPast
    /// Idle bots redraw only while the eyes have something to do (a blink, a glance).
    @State private var eyesBusy = false
    @State private var spinTick = 0
    /// When the current state began: the one-shots at a state's start (the lean as a tool
    /// starts, the slow blink of an error) count from here.
    @State private var stateSince: Date = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var ambient: BotAmbient { BotAmbient.shared }
    /// Per-bot phase: shape, eyes and name, folded to a small non-negative number (the name's
    /// hash wraps, and a negative seed would skew every `%` below it).
    private var seed: Int {
        let raw = spec.shape.utf8.reduce(0) { $0 + Int($1) } + spec.eyes.utf8.reduce(0) { $0 + Int($1) }
            + (mood.profile ?? "").utf8.reduce(0) { $0 &* 31 &+ Int($1) }
        return Int(UInt(bitPattern: raw) % 1_000_003)
    }

    /// Paint the glass finish even in the app (for offscreen renders such as menu icons).
    public var drawn: Bool
    /// What the bot is up to, beyond `active`.
    public struct Mood: Equatable, Sendable {
        /// Thinking hard: the eyes squint. (Same as `state: .thinking`.)
        public var thinking = false
        /// Which profile this is, so a finished turn (`BotAmbient.finished`) spins it once.
        public var profile: String? = nil
        /// Bots page: past a few degrees of tilt the eyes stop wandering and follow the phone.
        public var followsTilt = false
        /// What the bot is doing. `.idle` with `active` on means the working routines.
        public var state: BotFace.State = .idle
        /// In a group only one bot moves its body per five-second block: this bot's slot.
        public var groupIndex = 0
        public var groupCount = 1
        /// No eye life at all: the bots behind the front one in a stack.
        public var still = false
        public init(thinking: Bool = false, profile: String? = nil, followsTilt: Bool = false, state: BotFace.State = .idle, groupIndex: Int = 0, groupCount: Int = 1, still: Bool = false) {
            self.thinking = thinking; self.profile = profile; self.followsTilt = followsTilt
            self.state = state; self.groupIndex = groupIndex; self.groupCount = groupCount; self.still = still
        }
    }
    public var mood: Mood
    @Environment(\.colorScheme) private var colorScheme
    /// The app switcher's snapshot is taken with the glass effects stripped (the bots went
    /// grey), so once the scene is no longer active the painted glass stands in.
    @Environment(\.scenePhase) private var scenePhase

    public init(spec: BotLookSpec, size: CGFloat, active: Bool = false, gaze: CGPoint = .zero, drawn: Bool = false, mood: Mood = Mood()) {
        self.spec = spec
        self.size = size
        self.active = active
        self.gaze = gaze
        self.drawn = drawn
        self.mood = mood
    }

    private var state: BotFace.State {
        if mood.thinking { return .thinking }
        if mood.state == .idle, active { return .working }
        return mood.state
    }

    /// Seconds since the reference date when this bot's turn last finished, while the spin plays.
    private var finishedAt: Double? {
        guard let p = mood.profile, let d = ambient.finished[p], Date().timeIntervalSince(d) < 1.8 else { return nil }
        return d.timeIntervalSinceReferenceDate
    }
    private var tappedAt: Double? {
        guard let p = mood.profile, let d = ambient.tapped[p], Date().timeIntervalSince(d) < 0.6 else { return nil }
        return d.timeIntervalSinceReferenceDate
    }

    /// The frame's pose. Reduce Motion and painted renders keep the body still; the eyes act.
    private func pose(time t: Double, since: Double, finished: Double?, tapped: Double?) -> BotFace.Motion {
        let group: (index: Int, count: Int)? = mood.groupCount > 1 ? (mood.groupIndex, mood.groupCount) : nil
        let m = BotFace.motion(time: t, seed: seed, spec: spec, state: state, since: since, finishedAt: finished, tappedAt: tapped, group: group)
        return (reduceMotion || drawn) ? m.bodyStill : m
    }

    /// The glass bot as the icon is built: the body a tinted piece of glass, the eyes a darker
    /// piece in front, each in its own container (in one container they would merge into a
    /// single shape). Sleepy lids are strokes, so they stay painted. The rim sheen is a ring
    /// (the body minus the body shrunk) lit along a short arc.
    @ViewBuilder private func liveGlass(time t: Double, gaze g: CGPoint, glanceFree: Bool, motion m: BotFace.Motion, morph: Bool) -> some View {
        let tint = Color(botHex: spec.hex) ?? Color(red: 0.49, green: 0.36, blue: 1)
        ZStack {
            // The colour itself under the glass: tinted glass alone reads dark on a light
            // background (a sky-blue bot came out navy), so the hue is laid down first and the
            // glass adds its rim and refraction on top.
            BotBodyShape(spec: spec, time: t, active: morph)
                .fill(tint.opacity(colorScheme == .light ? 0.62 : 0.28))
            GlassEffectContainer {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(colorScheme == .light ? 0.45 : 0.72)), in: BotBodyShape(spec: spec, time: t, active: morph))
                    // No materialize bloom when a glass bot appears or changes look.
                    .glassEffectTransition(.identity)
            }
            if m.sheen > 0.01 {
                let stops: [Gradient.Stop] = [.init(color: .clear, location: 0), .init(color: .clear, location: 0.34), .init(color: .white.opacity(m.sheen), location: 0.5), .init(color: .clear, location: 0.66), .init(color: .clear, location: 1)]
                BotBodyShape(spec: spec, time: t, active: morph)
                    .fill(AngularGradient(gradient: Gradient(stops: stops), center: .center, angle: .degrees(m.sheenAngle - 180)))
                    .mask {
                        ZStack {
                            BotBodyShape(spec: spec, time: t, active: morph).fill(.white)
                            BotBodyShape(spec: spec, time: t, active: morph).fill(.black).scaleEffect(0.95).blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                    .allowsHitTesting(false)
            }
            if spec.eyes == "sleepy" {
                Canvas(opaque: false, rendersAsynchronously: false) { ctx, sz in
                    BotFace.draw(spec, in: &ctx, size: sz, time: t, active: morph, gaze: g, part: .eyes, breathe: false, idleEyes: !mood.still, move: false, glanceFree: glanceFree, motion: m)
                }
            } else {
                GlassEffectContainer {
                    Color.clear
                        .glassEffect(.clear.tint(BotFace.ink.opacity(0.92)), in: BotEyesShape(spec: spec, time: t, active: !mood.still, gaze: g, glanceFree: glanceFree, motion: m))
                        .glassEffectTransition(.identity)
                }
            }
        }
    }

    public var body: some View {
        // Tilted well past level (Bots page), the eyes stop wandering and follow the phone; within
        // a few degrees they add a little of the tilt to their own glances.
        // Small bots (beside a bubble, on the toolbar) do not follow scrolls or tilt: a long
        // thread has dozens of them and each would redraw on every scroll tick.
        let listens = size >= 32 && ambient.enabled
        let tilt = listens ? ambient.tilt : .zero
        let tiltMag = hypot(tilt.x, tilt.y)
        let held = mood.followsTilt && listens && tiltMag > 0.3
        let tiltWeight: CGFloat = held ? 1.0 : 0.5
        let ambientGaze = listens ? CGPoint(x: ambient.gaze.x + tilt.x * tiltWeight, y: ambient.gaze.y + tilt.y * tiltWeight) : .zero
        let finished = finishedAt
        let tapped = tappedAt
        let state = state
        // Any state but idle keeps the clock running: the poses are functions of time.
        let animating = (active || state != .idle || finished != nil || tapped != nil) && !drawn
        let morph = state == .working || state == .thinking
        let _ = spinTick
        TimelineView(.animation(minimumInterval: animating ? 1 / 30 : 1 / 24, paused: !animating && !eyesBusy && gaze == shownGaze)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let u = min(1, max(0, timeline.date.timeIntervalSince(gazeChangedAt) / 0.35))
            let ease = u * u * (3 - 2 * u)
            let g0 = CGPoint(x: gazeFrom.x + (gaze.x - gazeFrom.x) * ease, y: gazeFrom.y + (gaze.y - gazeFrom.y) * ease)
            let g = CGPoint(x: max(-1, min(1, g0.x + ambientGaze.x)), y: max(-1, min(1, g0.y + ambientGaze.y)))
            let m = pose(time: t, since: timeline.date.timeIntervalSince(stateSince), finished: finished, tapped: tapped)
            Group {
                if spec.isGlass && BotFace.liveGlass && !drawn && scenePhase == .active {
                    liveGlass(time: t, gaze: g, glanceFree: !held, motion: m, morph: morph)
                } else {
                    Canvas(opaque: false, rendersAsynchronously: false) { ctx, sz in
                        BotFace.draw(spec, in: &ctx, size: sz, time: t, active: morph, gaze: g, breathe: false, idleEyes: !drawn && !mood.still, move: false, glanceFree: !held, light: colorScheme == .light, motion: m.bodyStill)
                    }
                }
            }
            // The routines: a turn about the vertical axis (3D, on the spot), a small roll, a
            // tiny nod or lean. Nothing scales and nothing leaves the bot's footprint.
            .rotation3DEffect(.radians(m.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0)
            .rotationEffect(.radians(m.roll))
            .offset(x: m.dx * size, y: m.dy * size)
        }
        .animation(.interactiveSpring(response: 0.3), value: ambientGaze)
        // The bot leans with the phone: a few degrees, about the centre.
        .rotation3DEffect(.degrees(Double(tilt.y) * -7), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(Double(tilt.x) * 7), axis: (x: 0, y: 1, z: 0))
        .onChange(of: gaze) { old, new in
            gazeFrom = old; shownGaze = new; gazeChangedAt = Date()
        }
        .onChange(of: state) { _, _ in stateSince = Date() }
        // A tap on the bot: the small turn. Simultaneous, so the row or link it sits in still gets it.
        .simultaneousGesture(TapGesture().onEnded { if let p = mood.profile, !drawn { ambient.tap(profile: p) } })
        // Once a finish spin or a tap has played, a nudge re-evaluates the body so the timeline
        // pauses again (nothing else changes afterwards and it would keep running otherwise).
        .task(id: "\(finished ?? 0)-\(tapped ?? 0)") {
            guard finished != nil || tapped != nil else { return }
            try? await Task.sleep(for: .milliseconds(1900))
            spinTick += 1
        }
        // A quarter-second poll decides whether an idle bot has a blink or a glance coming up;
        // between those it costs nothing.
        .task(id: "\(animating)-\(drawn)-\(mood.still)") {
            guard !animating, !drawn, !mood.still else { return }
            while !Task.isCancelled {
                eyesBusy = BotFace.eyesBusy(time: Date().timeIntervalSinceReferenceDate, seed: seed)
                try? await Task.sleep(for: .milliseconds(eyesBusy ? 120 : 250))
            }
        }
        .frame(width: size, height: size)
        // A paused TimelineView does not redraw for a changed spec (a bot switched to glass kept
        // its painted look until something else re-created the row): un-pause it for a moment.
        // Not a new identity — re-creating a glass view makes it "materialize" (bloom in), which
        // is exactly the pop the studio must not do on every tap.
        .onChange(of: spec) { _, _ in
            eyesBusy = true
            Task { try? await Task.sleep(for: .milliseconds(350)); eyesBusy = false }
        }
        .accessibilityHidden(true)
    }
}

extension Color {
    /// "#RRGGBB" → Color; nil when the string is not a colour.
    public init?(botHex: String) {
        var s = botHex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
