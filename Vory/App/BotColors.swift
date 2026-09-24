import SwiftUI
import UIKit
import VoryCore

/// One accent colour per bot (profile). Stored in UserDefaults as `{profile: "#RRGGBB"}` under
/// `botColors`; profiles without a saved colour get a stable pick from the palette so two bots
/// never look alike by accident. Used by the chat title pill, the Bots list, notifications' tint
/// and the Live Activity.
enum BotColors {
    static let storageKey = "botColors"
    static let palette: [String] = ["#7C5CFF", "#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#64D2FF", "#BF5AF2", "#FFD60A", "#FF6B35", "#5AC8FA"]

    static func stored() -> [String: String] {
        guard let raw = UserDefaults.standard.string(forKey: storageKey), let data = raw.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    static func save(_ map: [String: String]) {
        if let data = try? JSONEncoder().encode(map), let s = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(s, forKey: storageKey)
        }
        BotLooksMirror.mirror()
    }

    static func hex(for profile: String, overrides: [String: String]? = nil) -> String {
        if let h = (overrides ?? stored())[profile], !h.isEmpty { return h }
        return defaultHex(for: profile)
    }

    /// Deterministic palette pick: same name, same colour, on every device.
    static func defaultHex(for profile: String) -> String {
        var hash: UInt64 = 5381
        for b in profile.utf8 { hash = (hash &* 33) &+ UInt64(b) }
        return palette[Int(hash % UInt64(palette.count))]
    }

    static func color(for profile: String, overrides: [String: String]? = nil) -> Color {
        Color(hex: hex(for: profile, overrides: overrides)) ?? .accentColor
    }

    static func set(_ color: Color, for profile: String) {
        var map = stored()
        map[profile] = color.hexString
        save(map)
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

/// A bot's avatar: its initial in its colour, the photo the user chose, or an animated Vory
/// avatar that moves while `active` (the bot is working).
struct BotAvatar: View {
    var profile: String
    var size: CGFloat = 28
    var active: Bool = false
    /// Draw this choice instead of the stored one (the picker's previews).
    var override: BotAvatarChoice? = nil
    @AppStorage(BotColors.storageKey) private var raw = ""
    @AppStorage(BotAvatarStore.storageKey) private var avatarsRaw = ""

    private var overrides: [String: String] {
        guard let d = raw.data(using: .utf8), let m = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return m
    }
    private var choice: BotAvatarChoice {
        if let override { return override }
        guard let d = avatarsRaw.data(using: .utf8), let m = try? JSONDecoder().decode([String: String].self, from: d) else { return .initial }
        return BotAvatarChoice(raw: m[profile] ?? "initial")
    }

    var body: some View {
        let tint = BotColors.color(for: profile, overrides: overrides)
        Group {
            switch choice {
            case .photo:
                if let image = BotAvatarStore.photo(for: profile) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
                } else { initial(tint) }
            case .animated(let style):
                AnimatedAvatar(style: style, tint: tint, size: size, active: active)
            case .initial:
                initial(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func initial(_ tint: Color) -> some View {
        ZStack {
            Circle().fill(tint.gradient)
            Text(String(profile.prefix(1)).uppercased())
                .font(.system(size: size * 0.48, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}


/// Copies the bot colours, avatar choices and photo thumbnails into the shared keychain
/// (`BotLooks`) for the notification extensions.
enum BotLooksMirror {
    static func mirror() {
        let avatars = BotAvatarStore.stored()
        var photos: [String: Data] = [:]
        for (profile, choice) in avatars where choice == "photo" {
            if let image = BotAvatarStore.photo(for: profile), let data = thumbnail(image) { photos[profile] = data }
        }
        BotLooks(colors: BotColors.stored(), avatars: avatars, photos: photos).save()
    }

    private static func thumbnail(_ image: UIImage) -> Data? {
        let side: CGFloat = 128
        let scale = side / max(image.size.width, image.size.height)
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let small = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.jpegData(compressionQuality: 0.75)
    }
}
