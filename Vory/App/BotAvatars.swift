import PhotosUI
import SwiftUI
import UIKit

/// What stands in for a bot: its initial in a coloured circle, a photo the user picked, or one of
/// the animated Vory avatars. Stored per profile in UserDefaults (`botAvatars`, `{profile: raw}`)
/// with photos under Application Support/BotAvatars; both stay on this device.
enum BotAvatarChoice: Equatable {
    case initial
    case photo
    case animated(String)

    var raw: String {
        switch self {
        case .initial: return "initial"
        case .photo: return "photo"
        case .animated(let id): return "animated:\(id)"
        }
    }

    init(raw: String) {
        if raw == "photo" { self = .photo }
        else if raw.hasPrefix("animated:") { self = .animated(String(raw.dropFirst("animated:".count))) }
        else { self = .initial }
    }
}

enum BotAvatarStore {
    static let storageKey = "botAvatars"
    /// NSCache is thread-safe; the wrapper just says so to the compiler.
    private struct Cache: @unchecked Sendable { let store = NSCache<NSString, UIImage>() }
    private static let cache = Cache()
    private static var photoCache: NSCache<NSString, UIImage> { cache.store }

    static func stored() -> [String: String] {
        guard let raw = UserDefaults.standard.string(forKey: storageKey), let data = raw.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    static func save(_ map: [String: String]) {
        if let data = try? JSONEncoder().encode(map), let s = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(s, forKey: storageKey)
        }
    }

    static func choice(for profile: String, overrides: [String: String]? = nil) -> BotAvatarChoice {
        BotAvatarChoice(raw: (overrides ?? stored())[profile] ?? "initial")
    }

    static func set(_ choice: BotAvatarChoice, for profile: String) {
        var map = stored()
        map[profile] = choice.raw
        save(map)
    }

    static func photoURL(for profile: String) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appending(path: "BotAvatars", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = profile.map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        return dir.appending(path: "\(safe).jpg")
    }

    /// Downscales to 320 px and writes a JPEG; the same profile's cached image is dropped.
    static func savePhoto(_ data: Data, for profile: String) throws {
        guard let url = photoURL(for: profile), let image = UIImage(data: data) else { throw CocoaError(.fileWriteUnknown) }
        let side: CGFloat = 320
        let scale = max(side / image.size.width, side / image.size.height)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let squared = renderer.image { _ in
            image.draw(in: CGRect(x: (side - target.width) / 2, y: (side - target.height) / 2, width: target.width, height: target.height))
        }
        guard let jpeg = squared.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
        try jpeg.write(to: url, options: .atomic)
        photoCache.removeObject(forKey: profile as NSString)
    }

    static func photo(for profile: String) -> UIImage? {
        if let cached = photoCache.object(forKey: profile as NSString) { return cached }
        guard let url = photoURL(for: profile), let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        photoCache.setObject(image, forKey: profile as NSString)
        return image
    }

    static func removePhoto(for profile: String) {
        if let url = photoURL(for: profile) { try? FileManager.default.removeItem(at: url) }
        photoCache.removeObject(forKey: profile as NSString)
    }
}

/// The animated Vory avatars. Each one idles as a still frame and moves while the bot works.
struct AnimatedAvatarStyle: Identifiable, Hashable {
    var id: String
    var name: String
    var tagline: String

    static let all: [AnimatedAvatarStyle] = [
        .init(id: "nimbus", name: "Nimbus", tagline: "A little cloud that breathes while it thinks"),
        .init(id: "halo", name: "Halo", tagline: "Two rings in orbit"),
        .init(id: "pip", name: "Pip", tagline: "A spark that bounces when busy"),
        .init(id: "ember", name: "Ember", tagline: "A flame that flickers as it works"),
        .init(id: "wisp", name: "Wisp", tagline: "A ribbon of light passing through"),
        .init(id: "prism", name: "Prism", tagline: "A slowly turning crystal"),
    ]

    static func named(_ id: String) -> AnimatedAvatarStyle? { all.first { $0.id == id } }
}

/// Canvas-drawn avatar. `active` runs the timeline; otherwise it draws frame zero, so a list of
/// idle bots costs nothing.
struct AnimatedAvatar: View {
    var style: String
    var tint: Color
    var size: CGFloat
    var active: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active)) { timeline in
            let t = active ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas(opaque: false, rendersAsynchronously: false) { ctx, sz in
                let r = CGRect(origin: .zero, size: sz)
                ctx.clip(to: Path(ellipseIn: r))
                ctx.fill(Path(ellipseIn: r), with: .linearGradient(Gradient(colors: [tint.opacity(0.95), tint.opacity(0.65)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: sz.height)))
                // Each character is drawn at its own natural size, then scaled about the centre so
                // none sits tiny in the circle or crowds its edge — the same in every place it appears.
                let z = AvatarArt.zoom(style)
                ctx.translateBy(x: sz.width / 2, y: sz.height / 2)
                ctx.scaleBy(x: z, y: z)
                ctx.translateBy(x: -sz.width / 2, y: -sz.height / 2)
                AvatarArt.draw(style, in: &ctx, size: sz, time: t, active: active)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

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

/// Picker for the profile card: initial, photo, and each animated style, drawn live.
struct AvatarChoiceRow: View {
    var profile: String
    @Binding var choice: BotAvatarChoice
    @State private var photoItem: PhotosPickerItem?
    @State private var photoError: String?
    @State private var photoVersion = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    option(.initial, label: "Initial") { BotAvatar(profile: profile, size: 56, override: .initial) }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 6) {
                            ZStack {
                                if BotAvatarStore.photo(for: profile) != nil {
                                    BotAvatar(profile: profile, size: 56, override: .photo).id(photoVersion)
                                } else {
                                    Circle().fill(Color(.tertiarySystemFill)).frame(width: 56, height: 56)
                                    Image(systemName: "camera").foregroundStyle(.secondary)
                                }
                            }
                            .overlay(Circle().stroke(choice == .photo ? Color.accentColor : .clear, lineWidth: 3).padding(-3))
                            Text("Photo").font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    ForEach(AnimatedAvatarStyle.all) { style in
                        option(.animated(style.id), label: style.name) { BotAvatar(profile: profile, size: 56, active: true, override: .animated(style.id)) }
                    }
                }
                .padding(.vertical, 4)
            }
            if case .animated(let id) = choice, let s = AnimatedAvatarStyle.named(id) {
                Text("\(s.name) — \(s.tagline).").font(.caption).foregroundStyle(.secondary)
            }
            if let photoError { Text(photoError).font(.caption).foregroundStyle(.red) }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { return }
                    try BotAvatarStore.savePhoto(data, for: profile)
                    photoVersion += 1
                    photoError = nil
                    choice = .photo
                } catch { photoError = error.localizedDescription }
                photoItem = nil
            }
        }
    }

    @ViewBuilder private func option<V: View>(_ c: BotAvatarChoice, label: String, @ViewBuilder preview: () -> V) -> some View {
        Button { choice = c } label: {
            VStack(spacing: 6) {
                preview().overlay(Circle().stroke(choice == c ? Color.accentColor : .clear, lineWidth: 3).padding(-3))
                Text(label).font(.caption2)
            }
        }
        .buttonStyle(.plain)
    }
}
