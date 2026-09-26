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
            return roundedPolygon(sides: 3, in: box2, rotation: -.pi / 2, corner: r.width * 0.13)
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
        case "triangle": return (0.64, 0.10)
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
    public static func draw(_ spec: BotLookSpec, in ctx: inout GraphicsContext, size: CGSize, time t: Double, active: Bool, gaze: CGPoint = .zero, part: Part = .all, breathe: Bool = true) {
        let box = CGRect(origin: .zero, size: size)
        let s = min(size.width, size.height)
        let seed = spec.shape.utf8.reduce(0) { $0 + Int($1) } + spec.eyes.utf8.reduce(0) { $0 + Int($1) }
        let live = liveliness(time: active ? t : 0, seed: seed)
        let tint = Color(botHex: spec.hex) ?? Color(red: 0.49, green: 0.36, blue: 1)

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
                drawGlassBody(body, tint: tint, in: &ctx, box: box, s: s)
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
        guard part != .body else { return }

        // Eyes: black shapes, blinking by squashing to a line, glancing by sliding.
        let eyes = eyePaths(spec, size: size, time: t, active: active, gaze: gaze)
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
    static func drawGlassBody(_ body: Path, tint: Color, in ctx: inout GraphicsContext, box: CGRect, s: CGFloat) {
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.28), radius: s * 0.05, y: s * 0.03))
            layer.fill(body, with: .linearGradient(Gradient(colors: [tint.opacity(0.92), tint.opacity(0.62)]), startPoint: CGPoint(x: 0, y: box.minY), endPoint: CGPoint(x: 0, y: box.maxY)))
        }
        ctx.drawLayer { layer in
            layer.clip(to: body)
            // Specular: light pooling along the top, fading out a third of the way down.
            layer.fill(Path(box), with: .linearGradient(Gradient(colors: [.white.opacity(0.42), .white.opacity(0.05), .white.opacity(0)]), startPoint: CGPoint(x: 0, y: box.minY), endPoint: CGPoint(x: 0, y: box.maxY * 0.5)))
        }
        // Rim: bright where the light hits (top-left), dark on the underside. Not a stroke: the
        // cloud is several overlapping pieces and a stroke draws every inner edge (the doubled
        // cloud seen in the profile menu). Fill the body, then punch out the body shrunk a little
        // about its centre, which leaves only the outline.
        ctx.drawLayer { layer in
            layer.fill(body, with: .linearGradient(Gradient(colors: [.white.opacity(0.9), .white.opacity(0.15), .black.opacity(0.28)]), startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.maxX, y: box.maxY)))
            layer.blendMode = .destinationOut
            let b = body.boundingRect
            let k = max(0, 1 - (s * 0.045) / max(b.width, 1))
            let inner = body.applying(CGAffineTransform(translationX: b.midX, y: b.midY).scaledBy(x: k, y: k).translatedBy(x: -b.midX, y: -b.midY))
            layer.fill(inner, with: .color(.black))
        }
    }

    /// The eyes' geometry for a frame: one path (both eyes) and whether it is stroked (sleepy
    /// lids) rather than filled. Both eyes move together: a glance or a gaze shifts the pair,
    /// never their spacing.
    public static func eyePaths(_ spec: BotLookSpec, size: CGSize, time t: Double, active: Bool, gaze: CGPoint = .zero) -> (path: Path, stroked: Bool) {
        let s = min(size.width, size.height)
        let seed = spec.shape.utf8.reduce(0) { $0 + Int($1) } + spec.eyes.utf8.reduce(0) { $0 + Int($1) }
        let live = liveliness(time: active ? t : 0, seed: seed)
        let anchor = eyeAnchor(spec.shape)
        let dx = s * anchor.spread
        let cx = size.width / 2 + CGFloat(live.glance) * s * 0.06 + gaze.x * s * 0.06
        let cy = s * anchor.y + gaze.y * s * 0.07
        let open = CGFloat(1 - live.blink * 0.92)
        var path = Path()
        func eye(at x: CGFloat, w: CGFloat, h: CGFloat, round: Bool) {
            let hh = max(s * 0.025, h * open)
            let rect = CGRect(x: x - w / 2, y: cy - hh / 2, width: w, height: hh)
            path.addPath(round && open > 0.5 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: min(w, hh) / 2, style: .continuous))
        }
        if spec.eyes == "sleepy" {
            // Lids: two soft downward arcs.
            for x in [cx - dx, cx + dx] {
                path.move(to: CGPoint(x: x - s * 0.075, y: cy - s * 0.01))
                path.addQuadCurve(to: CGPoint(x: x + s * 0.075, y: cy - s * 0.01), control: CGPoint(x: x, y: cy + s * 0.05))
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
            eye(at: cx - dx, w: s * 0.09, h: s * 0.09, round: true); eye(at: cx + dx, w: s * 0.085, h: s * 0.20, round: false)
        case "bold":
            eye(at: cx - dx, w: s * 0.13, h: s * 0.27, round: false); eye(at: cx + dx, w: s * 0.13, h: s * 0.27, round: false)
        default: // classic
            eye(at: cx - dx, w: s * 0.10, h: s * 0.22, round: false); eye(at: cx + dx, w: s * 0.10, h: s * 0.22, round: false)
        }
        return (path, false)
    }
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
    public init(spec: BotLookSpec, time: Double, active: Bool, gaze: CGPoint) { self.spec = spec; self.time = time; self.active = active; self.gaze = gaze }
    public func path(in rect: CGRect) -> Path { BotFace.eyePaths(spec, size: rect.size, time: time, active: active, gaze: gaze).path.offsetBy(dx: rect.minX, dy: rect.minY) }
}

/// The bot as a view. `active` runs the animation (blink, glance, breathing, the blob's morph);
/// otherwise it is a still frame, so a list of idle bots costs nothing.
public struct BotFaceView: View {
    public var spec: BotLookSpec
    public var size: CGFloat
    public var active: Bool
    /// Where the eyes look, −1…1 on each axis (0,0 straight ahead); eased over a third of a second.
    public var gaze: CGPoint
    @State private var shownGaze: CGPoint = .zero
    @State private var gazeFrom: CGPoint = .zero
    @State private var gazeChangedAt: Date = .distantPast

    /// Paint the glass finish even in the app (for offscreen renders such as menu icons).
    public var drawn: Bool
    /// The app switcher's snapshot is taken with the glass effects stripped (the bots went
    /// grey), so once the scene is no longer active the painted glass stands in.
    @Environment(\.scenePhase) private var scenePhase

    public init(spec: BotLookSpec, size: CGFloat, active: Bool = false, gaze: CGPoint = .zero, drawn: Bool = false) {
        self.spec = spec
        self.size = size
        self.active = active
        self.gaze = gaze
        self.drawn = drawn
    }

    /// The glass bot as the icon is built: the body a tinted piece of glass, the eyes a darker
    /// piece in front, each in its own container (in one container they would merge into a
    /// single shape). Sleepy lids are strokes, so they stay painted.
    @ViewBuilder private func liveGlass(time t: Double, gaze g: CGPoint) -> some View {
        let tint = Color(botHex: spec.hex) ?? Color(red: 0.49, green: 0.36, blue: 1)
        let sy = BotFace.breathScale(time: t, active: active, spec: spec)
        ZStack {
            GlassEffectContainer {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.72)), in: BotBodyShape(spec: spec, time: t, active: active))
            }
            if spec.eyes == "sleepy" {
                Canvas(opaque: false, rendersAsynchronously: false) { ctx, sz in
                    BotFace.draw(spec, in: &ctx, size: sz, time: t, active: active, gaze: g, part: .eyes, breathe: false)
                }
            } else {
                GlassEffectContainer {
                    Color.clear
                        .glassEffect(.clear.tint(BotFace.ink.opacity(0.92)), in: BotEyesShape(spec: spec, time: t, active: active, gaze: g))
                }
            }
        }
        .scaleEffect(x: 1 / sy, y: sy, anchor: UnitPoint(x: 0.5, y: 0.96))
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active && gaze == shownGaze)) { timeline in
            let t = active ? timeline.date.timeIntervalSinceReferenceDate : 0
            let u = min(1, max(0, timeline.date.timeIntervalSince(gazeChangedAt) / 0.35))
            let ease = u * u * (3 - 2 * u)
            let g = CGPoint(x: gazeFrom.x + (gaze.x - gazeFrom.x) * ease, y: gazeFrom.y + (gaze.y - gazeFrom.y) * ease)
            if spec.isGlass && BotFace.liveGlass && !drawn && scenePhase == .active {
                liveGlass(time: t, gaze: g)
            } else {
                Canvas(opaque: false, rendersAsynchronously: false) { ctx, sz in
                    BotFace.draw(spec, in: &ctx, size: sz, time: t, active: active, gaze: g)
                }
            }
        }
        .onChange(of: gaze) { old, new in
            gazeFrom = old; shownGaze = new; gazeChangedAt = Date()
        }
        .frame(width: size, height: size)
        // A paused TimelineView does not redraw for a changed spec (a bot switched to glass kept
        // its painted look until something else re-created the row); a new identity does.
        .id(spec)
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
