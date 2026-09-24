import Foundation

/// The little state every widget and complication draws from. Written by whichever app is
/// running (iPhone or watch) into the shared Keychain group; read by the widget extensions.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public struct Chat: Codable, Sendable, Equatable, Identifiable {
        public var id: String
        public var title: String
        public var profile: String
        public var lastActive: Double?
        public var running: Bool
        public var needsYou: Bool
        public init(id: String, title: String, profile: String, lastActive: Double?, running: Bool, needsYou: Bool) {
            self.id = id; self.title = title; self.profile = profile; self.lastActive = lastActive; self.running = running; self.needsYou = needsYou
        }
    }

    public var gatewayName: String
    public var connectionID: String
    public var profile: String
    public var needsAttention: Int
    public var chats: [Chat]
    public var contextPercent: Int?
    public var updatedAt: Date

    public init(gatewayName: String, connectionID: String, profile: String, needsAttention: Int, chats: [Chat], contextPercent: Int?, updatedAt: Date = Date()) {
        self.gatewayName = gatewayName; self.connectionID = connectionID; self.profile = profile
        self.needsAttention = needsAttention; self.chats = chats; self.contextPercent = contextPercent; self.updatedAt = updatedAt
    }

    public static let account = "widget.snapshot"

    public static func load() -> WidgetSnapshot? { Keychain.getCodable(WidgetSnapshot.self, account: account) }
    public func save() { try? Keychain.setCodable(self, account: Self.account) }

    public var activeChat: Chat? { chats.first { $0.running } }
    public var attentionChat: Chat? { chats.first { $0.needsYou } }
}
