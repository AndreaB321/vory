import Foundation

/// Bot colours, avatar choices and small photo thumbnails, mirrored by the app into the shared
/// keychain so the notification extensions (which cannot read the app's UserDefaults or its
/// container) can draw the same bot the app shows.
public struct BotLooks: Codable, Sendable {
    /// `{profile: "#RRGGBB"}`
    public var colors: [String: String]
    /// `{profile: "initial" | "photo" | "animated:<style>"}`
    public var avatars: [String: String]
    /// `{profile: JPEG}` for photo avatars, kept small (about 128 px).
    public var photos: [String: Data]

    public static let account = "botLooks"

    public init(colors: [String: String] = [:], avatars: [String: String] = [:], photos: [String: Data] = [:]) {
        self.colors = colors
        self.avatars = avatars
        self.photos = photos
    }

    public static func load() -> BotLooks { Keychain.getCodable(BotLooks.self, account: account) ?? BotLooks() }
    public func save() { try? Keychain.setCodable(self, account: Self.account) }
}
