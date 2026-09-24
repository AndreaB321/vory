import UserNotifications
import VoryCore

/// Decrypts relay-delivered notifications. The relay only carries `enc`; this rewrites the
/// placeholder title/body with the real ones using the key the app minted for this install.
final class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        handler = contentHandler
        let mutable = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        content = mutable
        Keychain.accessGroup = Keychain.sharedGroupFromBundle()
        guard let enc = request.content.userInfo["enc"] as? String else { Self.breadcrumb("plain notification (no enc)"); contentHandler(mutable); return }
        guard let creds = Keychain.getCodable(PushRelay.Credentials.self, account: PushRelay.credentialsAccount) else {
            Self.breadcrumb("no relay credentials readable (group \(Keychain.accessGroup ?? "none"))"); contentHandler(mutable); return
        }
        let payload: [String: JSONValue]
        do { payload = try PushRelay.decrypt(enc, keyBase64: creds.payloadKey) }
        catch { Self.breadcrumb("decrypt failed: \(error.localizedDescription)"); contentHandler(mutable); return }
        Self.breadcrumb("decrypted OK")
        if let t = payload["title"]?.stringValue { mutable.title = t }
        if let s = payload["subtitle"]?.stringValue { mutable.subtitle = s }
        if let b = payload["body"]?.stringValue { mutable.body = b }
        if let c = payload["category"]?.stringValue { mutable.categoryIdentifier = c }
        if let th = payload["thread_id"]?.stringValue, !th.isEmpty { mutable.threadIdentifier = th }
        if payload["interruption"]?.stringValue == "time-sensitive" { mutable.interruptionLevel = .timeSensitive }
        if let hermes = payload["hermes"]?.objectValue {
            var info = mutable.userInfo
            info["hermes"] = hermes.mapValues { $0.foundationValue }
            mutable.userInfo = info
        }
        contentHandler(mutable)
    }

    /// One line the app reads back (Background Notifications page) to show what happened last time.
    static func breadcrumb(_ what: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(what)"
        try? Keychain.set(Data(line.utf8), account: "push.nse.last")
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler, let content { handler(content) }
    }
}
