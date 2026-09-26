import Foundation
import Observation
import UIKit
import UserNotifications
import VoryCore

/// Registers this device for APNs and publishes the registration to the gateway so the
/// user's `hermes-push` companion (see server/hermes-push) can deliver background notifications.
@MainActor
@Observable
final class PushRegistrar: PushRegistrationSyncing {
    static let installIDKey = "pushInstallID"

    var deviceToken: String?
    var liveActivityToken: String?
    var liveActivityStartedAt: Double?
    var liveActivitySessionID: String?
    /// When the current activity's push token arrived (nil once the activity ended).
    var liveActivityTokenAt: Date?
    var authorization: UNAuthorizationStatus = .notDetermined
    var lastRegistrationPath: String?
    var lastError: String?
    var registeredAt: Date?
    var registrationFailure: String?

    let installID: String

    init() {
        if let s = UserDefaults.standard.string(forKey: Self.installIDKey) { installID = s }
        else { let s = UUID().uuidString.lowercased(); UserDefaults.standard.set(s, forKey: Self.installIDKey); installID = s }
        NotificationCenter.default.addObserver(forName: .hermesLiveActivityToken, object: nil, queue: .main) { [weak self] n in
            let token = n.userInfo?["token"] as? String
            let started = n.userInfo?["startedAt"] as? Double
            let sid = n.userInfo?["storedID"] as? String
            Task { @MainActor in
                let active = (token?.isEmpty == false)
                // Clearing is per chat: a finished chat's activity going away must not drop the
                // token of the one still running.
                if !active, let sid, let current = self?.liveActivitySessionID, current != sid { return }
                LiveActivityController.note(active ? "publishing token to the gateway" : "token cleared on the gateway")
                self?.liveActivityToken = active ? token : nil
                self?.liveActivityStartedAt = active ? started : nil
                self?.liveActivitySessionID = active ? sid : nil
                self?.liveActivityTokenAt = active ? Date() : nil
                NotificationCenter.default.post(name: .hermesPushRegistrationNeedsSync, object: nil)
                await self?.registerWithRelay()
            }
        }
    }

    var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let ok = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
            await refreshAuthorization()
            if ok { UIApplication.shared.registerForRemoteNotifications() }
            return ok
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func registerForRemoteNotificationsIfAuthorized() async {
        await refreshAuthorization()
        if authorization == .authorized || authorization == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegister(token: Data) {
        deviceToken = token.map { String(format: "%02x", $0) }.joined()
        registrationFailure = nil
        NotificationCenter.default.post(name: .hermesPushRegistrationNeedsSync, object: nil)
        Task { await registerWithRelay() }
    }

    /// With a relay baked into the build, the phone registers itself there; the gateway then only
    /// needs the install id + secret from the device file, never an APNs key.
    func registerWithRelay() async {
        guard PushRelay.isConfigured, let token = deviceToken else { return }
        do {
            try await PushRelay.register(deviceToken: token, platform: "ios", bundleID: Bundle.main.bundleIdentifier ?? "", environment: apnsEnvironment, liveActivityToken: liveActivityToken)
            relayRegisteredAt = Date(); relayError = nil
        } catch { relayError = error.localizedDescription }
    }
    var relayRegisteredAt: Date?
    var relayError: String?

    func didFailToRegister(_ error: Error) {
        registrationFailure = error.localizedDescription
    }

    /// Writes `<profile home>/push/devices/<install id>.json` through the gateway's managed files API.
    func syncRegistration(runtime: GatewayRuntime) async {
        guard let token = deviceToken, let home = runtime.profileHome else { return }
        let path = "\(home)/push/devices/\(installID).json"
        var payload: [String: JSONValue] = [
            "schema": 1,
            "device_id": .string(installID),
            "platform": "ios",
            "app": "Vory",
            "bundle_id": .string(Bundle.main.bundleIdentifier ?? ""),
            "apns_token": .string(token),
            "apns_environment": .string(apnsEnvironment),
            "live_activity_token": liveActivityToken.map { .string($0) } ?? .null,
            "live_activity_started_at": liveActivityStartedAt.map { .number($0) } ?? .null,
            "live_activity_session_id": liveActivitySessionID.map { .string($0) } ?? .null,
            "gateway": .string(runtime.connection.gateway.description),
            "connection_name": .string(runtime.connection.name),
            "profiles": .array(runtime.profiles.map { .string($0.name) }),
            "device_name": .string(UIDevice.current.name),
            "registered_at": .string(ISO8601DateFormatter().string(from: Date())),
        ]
        payload.merge(PushRelay.deviceFileFields()) { $1 }
        do {
            let data = try JSONEncoder().encode(JSONValue.object(payload.compactingNulls))
            let body: JSONValue = ["path": .string(path), "data_url": .string("data:application/json;base64," + data.base64EncodedString()), "overwrite": true]
            let _: ManagedUploadResult = try await runtime.api.send("POST", "/api/files/upload", json: body)
            lastRegistrationPath = path
            registeredAt = Date()
            lastError = nil
            if let sid = liveActivitySessionID { LiveActivityController.note("token published for session \(sid.prefix(12))") }
        } catch {
            lastError = "Could not publish the push registration: \(error.localizedDescription)"
            if liveActivityToken != nil { LiveActivityController.note("token publish FAILED: \(error.localizedDescription)") }
        }
    }

    func removeRegistration(runtime: GatewayRuntime) async {
        await PushRelay.unregister()
        guard let home = runtime.profileHome else { return }
        let path = "\(home)/push/devices/\(installID).json"
        let _: JSONValue? = try? await runtime.api.send("DELETE", "/api/files", json: ["path": .string(path), "recursive": false])
        if lastRegistrationPath == path { lastRegistrationPath = nil; registeredAt = nil }
    }
}

extension Notification.Name {
    static let hermesPushRegistrationNeedsSync = Notification.Name("hermesPushRegistrationNeedsSync")
}

/// Adapter so the core can raise local notifications without importing UserNotifications.
@MainActor
final class LocalCardNotifier: CardNotifying {
    func cardArrived(_ card: PendingCard, chat: ChatSession) { LocalNotifier.cardArrived(card, chat: chat) }
    func turnFinished(chat: ChatSession, error: String?) { LocalNotifier.turnFinished(chat: chat, error: error) }
}

/// Local notifications for cards and finished turns while the app is not in the foreground.
enum LocalNotifier {
    static let approvalCategory = "HERMES_APPROVAL"
    static let clarifyCategory = "HERMES_CLARIFY"
    static let turnCategory = "HERMES_TURN"
    static let errorCategory = "HERMES_ERROR"
    static let approveOnceAction = "HERMES_APPROVE_ONCE"
    static let denyAction = "HERMES_DENY"
    static let replyAction = "HERMES_REPLY"

    @MainActor static var isForeground = true
    /// Once this phone is registered with the gateway, the companion sends these; a local copy
    /// would arrive as a duplicate.
    @MainActor static var companionDelivers: Bool { AppDelegate.model?.push.registeredAt != nil && PushRelay.isConfigured }
    @MainActor private static func botName(_ chat: ChatSession) -> String {
        chat.runtime.profiles.first { $0.name == chat.profileName }?.label ?? chat.profileName
    }

    static func registerCategories() {
        let approve = UNNotificationAction(identifier: approveOnceAction, title: "Approve once", options: [.authenticationRequired])
        let deny = UNNotificationAction(identifier: denyAction, title: "Deny", options: [.destructive, .authenticationRequired])
        let approval = UNNotificationCategory(identifier: approvalCategory, actions: [approve, deny], intentIdentifiers: [], options: [])
        let clarify = UNNotificationCategory(identifier: clarifyCategory, actions: [], intentIdentifiers: [], options: [])
        let reply = UNTextInputNotificationAction(identifier: replyAction, title: "Reply", options: [], textInputButtonTitle: "Send", textInputPlaceholder: "Message")
        let turn = UNNotificationCategory(identifier: turnCategory, actions: [reply], intentIdentifiers: [], options: [])
        let err = UNNotificationCategory(identifier: errorCategory, actions: [], intentIdentifiers: [], options: [])
        let enc = UNNotificationCategory(identifier: "HERMES_ENC", actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([approval, clarify, turn, err, enc])
    }

    @MainActor
    static func cardArrived(_ card: PendingCard, chat: ChatSession) {
        // In front of the user the card is on screen: a buzz, nothing more.
        if isForeground { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        guard !isForeground, !companionDelivers else { return }
        let bot = botName(chat)
        let content = UNMutableNotificationContent()
        content.threadIdentifier = chat.storedID
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        // The bot (profile) is the sender; the chat title rides in the subtitle, like a thread name.
        content.subtitle = chat.title
        if let a = card.approval {
            content.title = "\(bot) · approval needed"
            content.body = a.description?.isEmpty == false ? a.description! : (a.command ?? "A command is waiting for your decision")
            content.categoryIdentifier = approvalCategory
        } else if let c = card.clarify {
            content.title = "\(bot) · question"
            content.body = c.question ?? c.questions?.first?.question ?? "Hermes needs an answer"
            content.categoryIdentifier = clarifyCategory
        } else {
            content.title = "\(bot) · input needed"
            content.body = card.valuePrompt?.prompt ?? "Hermes is asking for a value"
            content.categoryIdentifier = clarifyCategory
        }
        content.userInfo = userInfo(chat: chat, kind: card.method, requestID: card.id)
        schedule(content, id: "card-\(card.id)")
    }

    @MainActor
    static func turnFinished(chat: ChatSession, error: String?) {
        guard !isForeground, !companionDelivers else { return }
        let bot = botName(chat)
        let content = UNMutableNotificationContent()
        content.threadIdentifier = chat.storedID
        content.sound = .default
        content.subtitle = chat.title
        if let error, !error.isEmpty {
            content.title = "\(bot) · turn failed"
            content.body = error
            content.categoryIdentifier = errorCategory
        } else {
            content.title = bot
            let last = chat.items.last(where: { if case .assistant = $0.kind { return true }; return false })
            if case .assistant(let text, _, _)? = last?.kind { content.body = String(text.prefix(180)) } else { content.body = "Turn finished" }
            content.categoryIdentifier = turnCategory
        }
        content.userInfo = userInfo(chat: chat, kind: "turn", requestID: nil)
        schedule(content, id: "turn-\(chat.storedID)-\(Int(Date().timeIntervalSince1970))")
    }

    @MainActor
    private static func userInfo(chat: ChatSession, kind: String, requestID: String?) -> [String: Any] {
        var hermes: [String: Any] = ["connection_id": chat.runtime.connection.id.uuidString,
                                     "gateway": chat.runtime.connection.gateway.description,
                                     "session_id": chat.storedID,
                                     "profile": chat.profileName,
                                     "kind": kind]
        if let requestID { hermes["request_id"] = requestID }
        return ["hermes": hermes]
    }

    private static func schedule(_ content: UNMutableNotificationContent, id: String) {
        let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
