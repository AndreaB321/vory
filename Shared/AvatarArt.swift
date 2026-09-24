import SwiftUI

/// The animated Vory avatars, drawn procedurally so the widget extension can show the same
/// character in a Live Activity (as a still frame: WidgetKit views do not animate).
enum AvatarArt {
    static func zoom(_ style: String) -> CGFloat {
        switch style {
        case "pip": return 1.45
        case "halo": return 1.15
        case "ember": return 1.12
        case "prism": return 1.1
        case "wisp": return 1.0
        default: return 0.88   // nimbus: the cloud otherwise touches the rim
        }
    }

    static func draw(_ style: String, in ctx: inout GraphicsContext, size: CGSize, time t: Double, active: Bool) {
        switch style {
        case "halo": halo(&ctx, size, t)
        case "pip": pip(&ctx, size, t, active)
        case "ember": ember(&ctx, size, t)
        case "wisp": wisp(&ctx, size, t)
        case "prism": prism(&ctx, size, t)
        default: nimbus(&ctx, size, t)
        }
    }

    private static func eyes(_ ctx: inout GraphicsContext, center: CGPoint, spread: CGFloat, radius: CGFloat, t: Double, color: Color = Color(white: 0.12)) {
        // A blink every ~4 s: the eyes squash to a line for a tenth of a second.
        let phase = t.truncatingRemainder(dividingBy: 4)
        let open: CGFloat = phase > 3.85 ? 0.15 : 1
        for dx in [-spread, spread] {
            let rect = CGRect(x: center.x + dx - radius, y: center.y - radius * open, width: radius * 2, height: radius * 2 * open)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    static func nimbus(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double) {
        let w = s.width, h = s.height
        let breathe = 1 + 0.05 * sin(t * 1.6)
        let bob = CGFloat(sin(t * 1.1)) * h * 0.02
        let cy = h * 0.58 + bob
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(0.5, cy / h, 0.30), (0.32, (cy / h) + 0.06, 0.22), (0.68, (cy / h) + 0.05, 0.24), (0.42, (cy / h) - 0.12, 0.2), (0.6, (cy / h) - 0.1, 0.19)]
        var cloud = Path()
        for (px, py, pr) in puffs {
            let rad = w * pr * breathe
            cloud.addEllipse(in: CGRect(x: w * px - rad, y: h * py - rad, width: rad * 2, height: rad * 2))
        }
        ctx.fill(cloud, with: .color(.white.opacity(0.95)))
        eyes(&ctx, center: CGPoint(x: w * 0.5, y: cy), spread: w * 0.09, radius: w * 0.035, t: t)
    }

    static func halo(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double) {
        let w = s.width, h = s.height, c = CGPoint(x: w / 2, y: h / 2)
        let core = w * 0.2
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)), with: .color(.white.opacity(0.95)))
        for (i, tilt) in [0.55, -0.55].enumerated() {
            var ring = ctx
            ring.translateBy(x: c.x, y: c.y)
            ring.rotate(by: .radians(tilt + (i == 0 ? t * 0.8 : -t * 0.6)))
            let rx = w * 0.42, ry = w * 0.14
            ring.stroke(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)), with: .color(.white.opacity(0.85)), lineWidth: max(1.5, w * 0.045))
        }
        eyes(&ctx, center: CGPoint(x: c.x, y: c.y - core * 0.1), spread: w * 0.07, radius: w * 0.03, t: t)
    }

    static func pip(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ active: Bool) {
        let w = s.width, h = s.height
        let bounce = active ? abs(sin(t * 3.2)) : 0
        let squash = 1 - 0.18 * (1 - bounce)
        let rad = w * 0.22
        let cy = h * 0.66 - CGFloat(bounce) * h * 0.22
        // A faint trail under the spark while it is in the air.
        if active {
            for i in 1...3 {
                let a = 0.22 - Double(i) * 0.06
                let rr = rad * (1 - CGFloat(i) * 0.18)
                let ty = cy + CGFloat(i) * h * 0.09
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - rr, y: ty - rr, width: rr * 2, height: rr * 2)), with: .color(.white.opacity(a)))
            }
        }
        let body = CGRect(x: w / 2 - rad / squash, y: cy - rad * squash, width: rad * 2 / squash, height: rad * 2 * squash)
        ctx.fill(Path(ellipseIn: body), with: .color(.white.opacity(0.96)))
        eyes(&ctx, center: CGPoint(x: w / 2, y: cy - rad * 0.05), spread: w * 0.07, radius: w * 0.03, t: t)
    }

    static func ember(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double) {
        let w = s.width, h = s.height
        let flick = CGFloat(0.04 * sin(t * 9) + 0.03 * sin(t * 13.7 + 1))
        func flame(scale: CGFloat, color: Color, lift: CGFloat) {
            var p = Path()
            let base = CGPoint(x: w / 2, y: h * 0.82)
            let tip = CGPoint(x: w / 2 + flick * w * scale, y: h * (0.18 + lift) - flick * h)
            let wd = w * 0.3 * scale
            p.move(to: CGPoint(x: base.x - wd, y: base.y))
            p.addQuadCurve(to: tip, control: CGPoint(x: base.x - wd * 1.1, y: h * 0.42))
            p.addQuadCurve(to: CGPoint(x: base.x + wd, y: base.y), control: CGPoint(x: base.x + wd * 1.1, y: h * 0.42))
            p.addQuadCurve(to: CGPoint(x: base.x - wd, y: base.y), control: CGPoint(x: base.x, y: base.y + wd * 0.5))
            ctx.fill(p, with: .color(color))
        }
        flame(scale: 1, color: .white.opacity(0.55), lift: 0)
        flame(scale: 0.62, color: .white.opacity(0.95), lift: 0.22)
        eyes(&ctx, center: CGPoint(x: w / 2, y: h * 0.62), spread: w * 0.06, radius: w * 0.028, t: t)
    }

    static func wisp(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double) {
        let w = s.width, h = s.height
        for (k, alpha) in [(0.0, 0.9), (0.9, 0.5), (1.8, 0.3)] {
            var p = Path()
            let steps = 24
            for i in 0...steps {
                let x = w * CGFloat(i) / CGFloat(steps)
                let y = h / 2 + sin(Double(x / w) * .pi * 2 + t * 2.2 + k) * h * 0.16 + CGFloat(k) * h * 0.02
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(p, with: .color(.white.opacity(alpha)), style: StrokeStyle(lineWidth: max(1.5, w * 0.06), lineCap: .round))
        }
        eyes(&ctx, center: CGPoint(x: w * 0.5, y: h * 0.5 + sin(t * 2.2 + .pi) * h * 0.16), spread: w * 0.07, radius: w * 0.03, t: t)
    }

    static func prism(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double) {
        let w = s.width, h = s.height, c = CGPoint(x: w / 2, y: h / 2)
        let r = w * 0.36
        let spin = t * 0.7
        var pts: [CGPoint] = []
        for i in 0..<6 {
            let a = spin + Double(i) * .pi / 3
            // Slight horizontal foreshortening so the crystal reads as turning, not just rotating.
            pts.append(CGPoint(x: c.x + cos(a) * r * (0.75 + 0.25 * abs(cos(spin))), y: c.y + sin(a) * r))
        }
        for i in 0..<6 {
            var tri = Path()
            tri.move(to: c); tri.addLine(to: pts[i]); tri.addLine(to: pts[(i + 1) % 6]); tri.closeSubpath()
            let shade = 0.45 + 0.5 * (0.5 + 0.5 * sin(spin + Double(i) * .pi / 3))
            ctx.fill(tri, with: .color(.white.opacity(shade)))
        }
        eyes(&ctx, center: c, spread: w * 0.07, radius: w * 0.03, t: t)
    }
}
