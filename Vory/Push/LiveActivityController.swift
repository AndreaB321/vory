import ActivityKit
import Foundation
import UIKit
import VoryCore

/// ActivityKit's `Activity` is not marked Sendable; Apple documents it as safe to drive from any context.
private final class ActivityHandle: @unchecked Sendable {
    let activity: Activity<HermesTurnAttributes>
    init(_ a: Activity<HermesTurnAttributes>) { activity = a }

    func update(_ state: HermesTurnAttributes.ContentState) {
        Task.detached { await self.activity.update(.init(state: state, staleDate: Date().addingTimeInterval(3600))) }
    }

    func end(_ state: HermesTurnAttributes.ContentState, linger: TimeInterval = 0) {
        // In front of the user the result is on screen already, so the activity goes at once; away
        // from the app it stays on the Lock Screen a while showing "finished".
        let policy: ActivityUIDismissalPolicy = linger > 0 ? .after(Date().addingTimeInterval(linger)) : .immediate
        Task.detached { await self.activity.end(.init(state: state, staleDate: nil), dismissalPolicy: policy) }
    }

    func observeState() -> Task<Void, Never> {
        Task.detached {
            for await st in self.activity.activityStateUpdates { LiveActivityController.note("state → \(st)") }
        }
    }

    func observePushTokens(storedID: String, startedAt: Date) -> Task<Void, Never> {
        Task.detached {
            for await token in self.activity.pushTokenUpdates {
                let hex = token.map { String(format: "%02x", $0) }.joined()
                LiveActivityController.note("push token received")
                NotificationCenter.default.post(name: .hermesLiveActivityToken, object: nil,
                                                userInfo: ["token": hex, "storedID": storedID, "startedAt": startedAt.timeIntervalSince1970])
            }
        }
    }
}

/// Starts/updates/ends the Live Activity for one chat's running turn.
@MainActor
final class LiveActivityController: TurnActivityReporting {
    private var handle: ActivityHandle?
    private var tokenTask: Task<Void, Never>?
    private var startedAt = Date()

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: "liveActivitiesEnabled") as? Bool ?? true }
    /// Activities being ended right now: `Activity.activities` still lists them for a moment, and a
    /// new turn must not adopt one instead of starting its own.
    nonisolated(unsafe) static var endingIDs: Set<String> = []
    /// The last reason `Activity.request` refused, for the diagnostics page.
    static var lastStartError: String?
    static var lastStartedAt: Date?
    /// The last dozen things that happened to activities, newest last, for the diagnostics page.
    nonisolated(unsafe) static var log: [String] = []
    nonisolated static func note(_ what: String) {
        let stamp = Date().formatted(.dateTime.hour().minute().second())
        log.append("\(stamp) \(what)")
        if log.count > 12 { log.removeFirst(log.count - 12) }
    }
    private var stateTask: Task<Void, Never>?

    /// Ends activities nobody is driving any more: ones whose turn already ended, or that belong to
    /// a chat this app has open and knows is idle. Called when the app comes to the foreground.
    static func endOrphans(runningStoredIDs: Set<String>, knownStoredIDs: Set<String>) {
        for a in Activity<HermesTurnAttributes>.activities {
            let sid = a.attributes.storedSessionID
            let finished = a.content.state.endedAt != nil
            let idleHere = knownStoredIDs.contains(sid) && !runningStoredIDs.contains(sid)
            let ancient = Date().timeIntervalSince(a.content.state.startedAt) > 3 * 3600
            guard finished || idleHere || ancient else { continue }
            let h = ActivityHandle(a)
            var st = a.content.state
            st.endedAtUnix = st.endedAtUnix ?? Date().timeIntervalSince1970
            h.end(st)
        }
    }

    func start(for chat: ChatSession) {
        guard Self.isEnabled, handle == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { Self.lastStartError = "Live Activities are turned off for Vory in iOS Settings"; return }
        // After a relaunch the system may still show this chat's activity: adopt it instead of stacking a second one.
        if let existing = Activity<HermesTurnAttributes>.activities.first(where: {
            $0.attributes.storedSessionID == chat.storedID && $0.content.state.endedAt == nil && $0.activityState == .active && !Self.endingIDs.contains($0.id)
        }) {
            startedAt = existing.content.state.startedAt
            let h = ActivityHandle(existing)
            handle = h
            tokenTask = h.observePushTokens(storedID: chat.storedID, startedAt: startedAt)
            // `pushTokenUpdates` only reports changes; the token this activity already holds must
            // reach the gateway too, or the companion cannot end it.
            if let token = existing.pushToken {
                let hex = token.map { String(format: "%02x", $0) }.joined()
                NotificationCenter.default.post(name: .hermesLiveActivityToken, object: nil,
                                                userInfo: ["token": hex, "storedID": chat.storedID, "startedAt": startedAt.timeIntervalSince1970])
            }
            return
        }
        startedAt = Date()
        let shortModel = chat.modelName.split(separator: "/").last.map(String.init) ?? chat.modelName
        let botName = chat.runtime.profiles.first { $0.name == chat.profileName }?.label ?? chat.profileName
        let attributes = HermesTurnAttributes(sessionTitle: chat.title, storedSessionID: chat.storedID,
                                              connectionID: chat.runtime.connection.id.uuidString, profile: chat.profileName,
                                              model: shortModel, tintHex: BotColors.hex(for: chat.profileName), botName: botName)
        let state = HermesTurnAttributes.ContentState(phase: "streaming", detail: "Thinking…", outputTokens: chat.usage?.output ?? 0,
                                                       contextPercent: chat.usage?.contextPercent, needsAttention: false, startedAt: startedAt)
        do {
            let a = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: Date().addingTimeInterval(3600)), pushType: .token)
            let h = ActivityHandle(a)
            handle = h
            tokenTask = h.observePushTokens(storedID: chat.storedID, startedAt: startedAt)
            stateTask = h.observeState()
            Self.lastStartError = nil; Self.lastStartedAt = Date()
            Self.note("started for “\(chat.title.prefix(24))”")
        } catch {
            handle = nil
            Self.lastStartError = error.localizedDescription
            Self.note("start refused: \(error.localizedDescription)")
        }
    }

    func update(for chat: ChatSession, attention: Bool, detail: String?) {
        guard let handle else { return }
        let phase = attention ? "waiting" : (detail?.hasPrefix("Running") == true ? "tool" : "streaming")
        let text = detail ?? (attention ? (chat.firstCard?.approval?.description ?? "Needs your answer") : (chat.statusLine ?? "Thinking…"))
        handle.update(HermesTurnAttributes.ContentState(phase: phase, detail: text, outputTokens: chat.usage?.output ?? 0,
                                                         contextPercent: chat.usage?.contextPercent, needsAttention: attention, startedAt: startedAt))
    }

    func end(for chat: ChatSession, phase: String) {
        tokenTask?.cancel()
        tokenTask = nil
        stateTask?.cancel()
        stateTask = nil
        let inFront = UIApplication.shared.applicationState == .active
        let linger: TimeInterval = inFront ? 0 : 45
        if handle != nil || Activity<HermesTurnAttributes>.activities.contains(where: { $0.attributes.storedSessionID == chat.storedID }) {
            Self.note("end (\(phase)) \(inFront ? "now, app in front" : "lingers 45 s, app in background")")
        }
        let state = HermesTurnAttributes.ContentState(phase: phase, detail: phase == "error" ? "The turn failed" : "Turn finished",
                                                      outputTokens: chat.usage?.output ?? 0, contextPercent: chat.usage?.contextPercent, needsAttention: false,
                                                      startedAt: startedAt, endedAt: Date())
        if let handle { Self.endingIDs.insert(handle.activity.id); self.handle = nil; handle.end(state, linger: linger) }
        // The companion routes finish/approval alerts through an active activity; tell it there is none now.
        NotificationCenter.default.post(name: .hermesLiveActivityToken, object: nil, userInfo: ["token": "", "storedID": chat.storedID, "startedAt": 0.0])
        // Whatever the system still shows for this chat (an activity from before a relaunch, or one whose
        // end push never arrived) goes with it.
        for a in Activity<HermesTurnAttributes>.activities where a.attributes.storedSessionID == chat.storedID {
            Self.endingIDs.insert(a.id)
            ActivityHandle(a).end(state, linger: linger)
        }
    }
}

extension Notification.Name {
    static let hermesLiveActivityToken = Notification.Name("hermesLiveActivityToken")
}
