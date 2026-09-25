import SwiftUI

/// A bot's look, made in the Creator Studio: a body shape, a pair of eyes and a colour. Drawn the
/// same way in the app, the Live Activity, the notification service and the reply window. The
/// bot itself is the icon: no disc behind it, no circular clip.
public struct BotLookSpec: Hashable, Sendable {
    public var shape: String
    public var eyes: String
    public var hex: String

    public init(shape: String, eyes: String, hex: String) {
        self.shape = shape
        self.eyes = eyes
        self.hex = hex
    }

    public static let shapes = ["circle", "blob", "square", "pill", "triangle", "hexagon", "cloud", "drop"]
    public static let eyeStyles = ["classic", "tall", "sleepy", "tiny", "round", "wide", "curious", "bold"]
    public static let defaultShape = "blob"
    public static let defaultEyes = "classic"

    /// The avatar choice string the app stores: "studio:<shape>:<eyes>". Older values ("initial",
    /// "animated:<style>") map onto a shape so nothing looks broken after the update.
    public static func from(choice raw: String?, hex: String) -> BotLookSpec {
        let parts = (raw ?? "").split(separator: ":").map(String.init)
        if parts.first == "studio", parts.count == 3, shapes.contains(parts[1]), eyeStyles.contains(parts[2]) {
            return BotLookSpec(shape: parts[1], eyes: parts[2], hex: hex)
        }
        if parts.first == "animated", parts.count == 2 {
            let legacy: [String: (String, String)] = ["nimbus": ("cloud", "classic"), "halo": ("circle", "round"), "pip": ("drop", "tiny"),
                                                      "ember": ("triangle", "bold"), "wisp": ("pill", "wide"), "prism": ("hexagon", "curious")]
            if let (s, e) = legacy[parts[1]] { return BotLookSpec(shape: s, eyes: e, hex: hex) }
        }
        return BotLookSpec(shape: defaultShape, eyes: defaultEyes, hex: hex)
    }

    public var choiceString: String { "studio:\(shape):\(eyes)" }

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
            return roundedPolygon(sides: 3, in: r.insetBy(dx: -r.width * 0.04, dy: 0), rotation: -.pi / 2, corner: r.width * 0.14)
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
            let phase = active ? t * 0.6 : 0
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
        case "triangle": return (0.62, 0.11)
        case "drop": return (0.62, 0.11)
        case "cloud": return (0.58, 0.11)
        case "pill": return (0.50, 0.13)
        default: return (0.47, 0.13)
        }
    }

    /// Blink (0 open … 1 shut) and glance (−1 … 1) as functions of time, offset per bot so a
    /// list of bots does not blink in unison.
    static func liveliness(time t: Double, seed: Int) -> (blink: Double, glance: Double, breath: Double) {
        guard t > 0 else { return (0, 0, 0) }
        let offset = Double(seed % 17) * 0.37
        let tt = t + offset
        // A blink every ~4.3 s, 150 ms long, occasionally a double blink.
        let period = 4.3
        let phase = tt.truncatingRemainder(dividingBy: period)
        var blink = 0.0
        if phase < 0.15 { blink = sin(phase / 0.15 * .pi) }
        else if Int(tt / period) % 3 == 0, phase > 0.28, phase < 0.43 { blink = sin((phase - 0.28) / 0.15 * .pi) }
        // A glance to one side every ~7 s, held for a moment, then back.
        let gp = (tt * 0.9).truncatingRemainder(dividingBy: 7.0)
        var glance = 0.0
        if gp > 1.2, gp < 2.6 {
            let u = (gp - 1.2) / 1.4
            let ease = u < 0.2 ? u / 0.2 : u > 0.8 ? (1 - u) / 0.2 : 1
            glance = ease * (Int(tt / 7.0) % 2 == 0 ? 1 : -1)
        }
        let breath = 0.5 + 0.5 * sin(tt * 2 * .pi / 2.6)
        return (blink, glance, breath)
    }

    /// Draws body and eyes into `size` (square). `active` animates; otherwise `time` should be 0.
    public static func draw(_ spec: BotLookSpec, in ctx: inout GraphicsContext, size: CGSize, time t: Double, active: Bool) {
        let box = CGRect(origin: .zero, size: size)
        let s = min(size.width, size.height)
        let seed = spec.shape.utf8.reduce(0) { $0 + Int($1) } + spec.eyes.utf8.reduce(0) { $0 + Int($1) }
        let live = liveliness(time: active ? t : 0, seed: seed)
        let tint = Color(botHex: spec.hex) ?? Color(red: 0.49, green: 0.36, blue: 1)

        // Breathing: a whisper of squash and stretch about the bottom while working.
        if active {
            let sy = 1 + 0.025 * (live.breath - 0.5)
            ctx.translateBy(x: size.width / 2, y: size.height * 0.96)
            ctx.scaleBy(x: 1 / sy, y: sy)
            ctx.translateBy(x: -size.width / 2, y: -size.height * 0.96)
        }

        let body = bodyPath(spec.shape, in: box, time: t, active: active)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [tint.opacity(1), tint.opacity(0.82)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
        // A soft rim light along the top so the flat colour reads as a form, not a sticker.
        ctx.stroke(body, with: .linearGradient(Gradient(colors: [.white.opacity(0.35), .white.opacity(0)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.7)), lineWidth: max(1, s * 0.03))

        // Eyes: black shapes, blinking by squashing to a line, glancing by sliding.
        let anchor = eyeAnchor(spec.shape)
        let cy = s * anchor.y
        let dx = s * anchor.spread + CGFloat(live.glance) * s * 0.035
        let cx = size.width / 2 + CGFloat(live.glance) * s * 0.045
        let open = CGFloat(1 - live.blink * 0.92)
        let ink = Color(red: 0.05, green: 0.05, blue: 0.07)
        func eye(at x: CGFloat, w: CGFloat, h: CGFloat, round: Bool) {
            let hh = max(s * 0.025, h * open)
            let rect = CGRect(x: x - w / 2, y: cy - hh / 2, width: w, height: hh)
            let path = round && open > 0.5 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: min(w, hh) / 2, style: .continuous)
            ctx.fill(path, with: .color(ink))
        }
        switch spec.eyes {
        case "tall":
            eye(at: cx - dx, w: s * 0.085, h: s * 0.30, round: false); eye(at: cx + dx, w: s * 0.085, h: s * 0.30, round: false)
        case "sleepy":
            // Lids: two soft downward arcs.
            for x in [cx - dx, cx + dx] {
                var p = Path()
                p.move(to: CGPoint(x: x - s * 0.075, y: cy - s * 0.01))
                p.addQuadCurve(to: CGPoint(x: x + s * 0.075, y: cy - s * 0.01), control: CGPoint(x: x, y: cy + s * 0.05))
                ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
            }
        case "tiny":
            eye(at: cx - dx * 0.8, w: s * 0.07, h: s * 0.07, round: true); eye(at: cx + dx * 0.8, w: s * 0.07, h: s * 0.07, round: true)
        case "round":
            eye(at: cx - dx, w: s * 0.13, h: s * 0.13, round: true); eye(at: cx + dx, w: s * 0.13, h: s * 0.13, round: true)
        case "wide":
            eye(at: cx - dx, w: s * 0.16, h: s * 0.075, round: false); eye(at: cx + dx, w: s * 0.16, h: s * 0.075, round: false)
        case "curious":
            eye(at: cx - dx, w: s * 0.09, h: s * 0.09, round: true); eye(at: cx + dx, w: s * 0.085, h: s * 0.20, round: false)
        case "bold":
            eye(at: cx - dx, w: s * 0.13, h: s * 0.27, round: false); eye(at: cx + dx, w: s * 0.13, h: s * 0.27, round: false)
        default: // classic
            eye(at: cx - dx, w: s * 0.10, h: s * 0.22, round: false); eye(at: cx + dx, w: s * 0.10, h: s * 0.22, round: false)
        }
    }
}

/// The bot as a view. `active` runs the animation (blink, glance, breathing, the blob's morph);
/// otherwise it is a still frame, so a list of idle bots costs nothing.
public struct BotFaceView: View {
    public var spec: BotLookSpec
    public var size: CGFloat
    public var active: Bool

    public init(spec: BotLookSpec, size: CGFloat, active: Bool = false) {
        self.spec = spec
        self.size = size
        self.active = active
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active)) { timeline in
            let t = active ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas(opaque: false, rendersAsynchronously: false) { ctx, sz in
                BotFace.draw(spec, in: &ctx, size: sz, time: t, active: active)
            }
        }
        .frame(width: size, height: size)
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
