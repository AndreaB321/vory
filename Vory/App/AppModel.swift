import Foundation
import Observation
import UIKit
import UserNotifications
import WidgetKit
import VoryCore

/// A deep-link target (from a push/local notification or a Live Activity tap).
struct PendingRoute: Hashable, Sendable {
    var connectionID: UUID?
    var gateway: String?
    var storedSessionID: String
    var profile: String?
    var kind: String?
    var replyText: String?
    var requestID: String?
    var action: String?
}

@MainActor
@Observable
final class AppModel {
    let store = ConnectionStore()
    let lock = AppLock()
    let push = PushRegistrar()
    private(set) var runtime: GatewayRuntime?
    var pendingRoute: PendingRoute?
    var activationError: String?
    var selectedTab: AppTab = .chats
    /// The gateway's companion plugin is older than the one this build ships: Settings › Notifications ›
    /// Background Notifications carry a badge until it is updated.
    var companionUpdateAvailable = false
    /// Companion version found on the gateway by the last check (About shows it).
    var companionInstalledVersion: String?

    /// Re-reads the companion's manifest on the gateway (cheap: two small file reads) and sets
    /// `companionUpdateAvailable`. Called when the app comes to the foreground.
    func refreshCompanionUpdateFlag() async {
        guard let rt = runtime, push.registeredAt != nil else { companionUpdateAvailable = false; return }
        let probe = PushSetupModel()
        await probe.checkCompanion(runtime: rt)
        companionUpdateAvailable = probe.updateAvailable
        companionInstalledVersion = probe.installedVersion
    }

    enum AppTab: String, Hashable, CaseIterable, Sendable {
        case chats, bots, files, sessions, cron, approvals, system, settings

        var title: String {
            switch self {
            case .chats: return "Chats"
            case .bots: return "Bots"
            case .files: return "Files"
            case .sessions: return "Sessions"
            case .cron: return "Cron"
            case .approvals: return "Approvals"
            case .system: return "System"
            case .settings: return "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .chats: return "bubble.left.and.bubble.right"
            case .bots: return "person.2.wave.2"
            case .files: return "folder"
            case .sessions: return "list.bullet.rectangle"
            case .cron: return "clock"
            case .approvals: return "checkmark.shield"
            case .system: return "server.rack"
            case .settings: return "gear"
            }
        }
    }

    init() {
        NotificationCenter.default.addObserver(forName: .hermesPushRegistrationNeedsSync, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let rt = self.runtime else { return }
                await self.push.syncRegistration(runtime: rt)
            }
        }
    }

    var hasConnections: Bool { !store.connections.isEmpty }

    func activateSavedConnection() async {
        if let c = store.active { await activate(c) }
    }

    func activate(_ connection: GatewayConnection) async {
        if let rt = runtime {
            if rt.connection.id == connection.id { return }
            await rt.stop()
        }
        store.activeConnectionID = connection.id
        let rt = GatewayRuntime(connection: connection, store: store)
        rt.pushRegistrar = push
        rt.cardNotifier = LocalCardNotifier()
        rt.activityReporterFactory = { LiveActivityController() }
        rt.onSnapshotPublished = { _ in WidgetCenter.shared.reloadAllTimelines() }
        runtime = rt
        activationError = nil
        await rt.start()
        await push.registerForRemoteNotificationsIfAuthorized()
        WatchSync.shared.push(store: store)
    }

    /// `vory://chat/<stored id>` from a widget or complication; `vory://chats` just lands on the list.
    func open(_ url: URL) {
        guard url.scheme == "vory" else { return }
        selectedTab = .chats
        if url.host == "chat", let id = url.pathComponents.dropFirst().first {
            pendingRoute = PendingRoute(connectionID: runtime?.connection.id, storedSessionID: id, profile: runtime?.selectedProfile)
        }
    }

    func deactivate() async {
        await runtime?.stop()
        runtime = nil
    }

    func deleteConnection(_ id: UUID) async {
        if runtime?.connection.id == id {
            if let rt = runtime { await push.removeRegistration(runtime: rt) }
            await deactivate()
        }
        store.delete(id: id)
        if let next = store.active { await activate(next) }
        WatchSync.shared.push(store: store)
    }

    // MARK: Notification routing

    func route(from userInfo: [AnyHashable: Any], action: String?, replyText: String? = nil) {
        guard let hermes = userInfo["hermes"] as? [String: Any], let sid = hermes["session_id"] as? String else { return }
        var r = PendingRoute(storedSessionID: sid)
        r.connectionID = (hermes["connection_id"] as? String).flatMap(UUID.init(uuidString:))
        r.gateway = hermes["gateway"] as? String
        r.profile = hermes["profile"] as? String
        r.kind = hermes["kind"] as? String
        r.requestID = hermes["request_id"] as? String
        r.action = action
        r.replyText = replyText
        pendingRoute = r
        selectedTab = .chats
        Task { await ensureConnection(for: r) }
    }

    private func ensureConnection(for r: PendingRoute) async {
        let target: GatewayConnection? = r.connectionID.flatMap { store.connection(id: $0) }
            ?? store.connections.first { c in r.gateway.map { c.gateway.description == $0 } ?? false }
        guard let target else { return }
        if runtime?.connection.id != target.id { await activate(target) }
        if let p = r.profile, !p.isEmpty, runtime?.selectedProfile != p { runtime?.selectedProfile = p }
        if let action = r.action, let rt = runtime {
            // Quick actions from the notification: reply or answer the approval without opening the chat.
            if action == LocalNotifier.replyAction {
                if let text = r.replyText, !text.isEmpty, let chat = try? await rt.openChat(storedID: r.storedSessionID, title: nil) { await chat.send(text) }
                return
            }
            if let chat = try? await rt.openChat(storedID: r.storedSessionID, title: nil) {
                let choice = action == LocalNotifier.approveOnceAction ? "once" : "deny"
                let deadline = Date().addingTimeInterval(8)
                while chat.cards.isEmpty, Date() < deadline { try? await Task.sleep(for: .milliseconds(250)) }
                if let card = chat.cards.first(where: { $0.method == "approval" }) { await chat.respond(card: card, result: ["choice": .string(choice)]) }
            }
        }
    }
}

/// UIKit delegate for APNs registration and notification taps.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static weak var model: AppModel?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        LocalNotifier.registerCategories()
        BotLooksMirror.mirror()   // so the notification extensions show the right bot from the start
        #if DEBUG
        // Simulator testing: `simctl push` only works once the app has asked for notification permission.
        if ProcessInfo.processInfo.arguments.contains("-vory-request-notifications") {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        #endif
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in Self.model?.push.didRegister(token: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in Self.model?.push.didFailToRegister(error) }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        .noData
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        let nonce = (info["hermes"] as? [String: Any])?["nonce"] as? String
        await MainActor.run {
            // The setup's test watches for these: any push counts as arrived, a nonce as decrypted too.
            PushSetupModel.lastPresentedAt = Date()
            if let nonce { PushSetupModel.presentedNonces.insert(nonce) }
        }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier == UNNotificationDefaultActionIdentifier ? nil : response.actionIdentifier
        let reply = (response as? UNTextInputNotificationResponse)?.userText
        await MainActor.run { Self.model?.route(from: info, action: action, replyText: reply) }
    }
}
