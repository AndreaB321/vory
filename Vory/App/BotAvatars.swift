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
