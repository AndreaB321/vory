import FoundationModels
import SwiftUI
import VoryCore

/// Vory Summaries (beta): the on-device Apple Intelligence model turns a chat's recent messages
/// into a short title and a two-line summary for the Chats list. Nothing leaves the phone and
/// nothing is written to the gateway; switching it off shows the gateway's own title and
/// preview again. Results are cached per chat and redone only when the chat changes.
@MainActor @Observable
final class ChatSummarizer {
    static let shared = ChatSummarizer()
    static let enabledKey = "chats.aiSummaries"

    struct Summary: Codable, Equatable { var title: String; var summary: String; var stamp: Double }

    @Generable
    struct Draft {
        @Guide(description: "A title for the conversation in at most six words, no quotes, no trailing period.")
        var title: String
        @Guide(description: "What the conversation is about and where it stands, in one or two short sentences, at most 140 characters.")
        var summary: String
    }

    private(set) var summaries: [String: Summary] = [:]
    private var inFlight: Set<String> = []
    private static let cacheKey = "chats.aiSummaries.cache"

    init() {
        if let d = UserDefaults.standard.data(forKey: Self.cacheKey), let m = try? JSONDecoder().decode([String: Summary].self, from: d) { summaries = m }
    }

    /// Whether the on-device model can run here (Apple Intelligence on, model downloaded).
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.deviceNotEligible): return "This device does not support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in iOS Settings first."
        case .unavailable(.modelNotReady): return "Apple Intelligence is still downloading its model."
        case .unavailable: return "Apple Intelligence is not available right now."
        }
    }

    var enabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    /// The summary for a chat if it is current (same last-activity stamp); nil otherwise.
    func summary(for session: StoredSession) -> Summary? {
        guard enabled, let s = summaries[session.id], s.stamp == (session.lastActive ?? 0) else { return nil }
        return s
    }

    /// Makes (or refreshes) the summary for a chat from its recent messages, in the background.
    func refresh(_ session: StoredSession, runtime: GatewayRuntime, profile: String?) {
        guard enabled, Self.isAvailable, !inFlight.contains(session.id) else { return }
        if let s = summaries[session.id], s.stamp == (session.lastActive ?? 0) { return }
        inFlight.insert(session.id)
        Task {
            defer { inFlight.remove(session.id) }
            let messages = await recentMessages(session, runtime: runtime, profile: profile)
            guard !messages.isEmpty else { return }
            let transcript = messages.map { "\($0.role == "user" ? "User" : "Assistant"): \(($0.text ?? "").prefix(600))" }.joined(separator: "\n")
            do {
                let ai = LanguageModelSession(instructions: "You summarize a conversation between a user and an AI assistant for a chat list. Be concrete and neutral. Do not mention that it is a conversation or a summary.")
                let draft = try await ai.respond(to: "Conversation:\n\(transcript)", generating: Draft.self).content
                let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".\"'"))
                let text = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty || !text.isEmpty else { return }
                summaries[session.id] = Summary(title: title.isEmpty ? session.displayTitle : title, summary: text, stamp: session.lastActive ?? 0)
                save()
            } catch {
                // The model can refuse or time out; the row keeps the gateway's own text.
            }
        }
    }

    private func recentMessages(_ session: StoredSession, runtime: GatewayRuntime, profile: String?) async -> [TranscriptMessage] {
        if let cached = TranscriptCache.load(connection: runtime.connection.id, storedID: session.id), !cached.isEmpty {
            return Array(cached.filter { ($0.role == "user" || $0.role == "assistant") && !($0.text ?? "").isEmpty }.suffix(10))
        }
        guard let r: JSONValue = try? await runtime.api.get("/api/sessions/\(session.id)/messages",
                                                             query: [URLQueryItem(name: "order", value: "latest"), URLQueryItem(name: "limit", value: "14")],
                                                             profile: profile ?? session.profile ?? runtime.selectedProfile) else { return [] }
        let all = (r["messages"]?.arrayValue ?? []).compactMap { try? $0.decode(TranscriptMessage.self) }
        return Array(all.filter { ($0.role == "user" || $0.role == "assistant") && !($0.text ?? "").isEmpty }.suffix(10))
    }

    private func save() {
        // Keep the cache bounded: the newest 300 chats.
        if summaries.count > 300 {
            let keep = summaries.sorted { $0.value.stamp > $1.value.stamp }.prefix(300)
            summaries = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        if let d = try? JSONEncoder().encode(summaries) { UserDefaults.standard.set(d, forKey: Self.cacheKey) }
    }
}
