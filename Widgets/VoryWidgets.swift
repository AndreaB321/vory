import SwiftUI
import VoryCore
import WidgetKit

// Compiled into both widget extensions: the iPhone one (home-screen + lock-screen families) and
// the watch one (complications). Everything draws from `WidgetSnapshot`, which the running app
// writes into the shared Keychain group; the provider also refreshes the session list itself
// when the snapshot is stale and credentials are available.

struct UncheckedSendable<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: WidgetSnapshot(gatewayName: "Hermes", connectionID: "", profile: "default", needsAttention: 1,
                                                             chats: [.init(id: "1", title: "Disk cleanup on the log host", profile: "default", lastActive: Date().timeIntervalSince1970, running: true, needsYou: true)],
                                                             contextPercent: 42))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: context.isPreview ? placeholder(in: context).snapshot : Self.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // WidgetKit's completion is not Sendable; it is safe to call from the task once.
        let done = UncheckedSendable(completion)
        Task {
            let snap = await Self.loadRefreshing()
            let entry = SnapshotEntry(date: Date(), snapshot: snap)
            done.value(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }

    static func load() -> WidgetSnapshot? {
        Keychain.accessGroup = Keychain.sharedGroupFromBundle()
        return WidgetSnapshot.load()
    }

    /// Snapshot as written by the app, refreshed from the gateway when it is older than ten
    /// minutes and a saved gateway exists. Network failures just keep the last snapshot.
    static func loadRefreshing() async -> WidgetSnapshot? {
        guard var snap = load() else { return nil }
        guard Date().timeIntervalSince(snap.updatedAt) > 600 else { return snap }
        // ConnectionStore is main-actor; read what we need there and hand back plain values.
        let wanted = UUID(uuidString: snap.connectionID)
        let creds: (GatewayConnection, GatewaySecrets)? = await MainActor.run {
            let store = ConnectionStore()
            guard let c = wanted.flatMap({ store.connection(id: $0) }) ?? store.active else { return nil }
            return (c, store.secrets(for: c.id))
        }
        guard let (conn, secrets) = creds else { return snap }
        let api = HermesAPI(gateway: conn.gateway, signer: RequestSigner(authMode: conn.authMode, secrets: secrets))
        if let r: SessionListResponse = try? await api.get("/api/sessions", query: [URLQueryItem(name: "order", value: "recent"), URLQueryItem(name: "limit", value: "8")], profile: snap.profile) {
            let needs = Set(snap.chats.filter(\.needsYou).map(\.id))
            snap.chats = r.sessions.map { s in
                WidgetSnapshot.Chat(id: s.id, title: s.displayTitle, profile: s.profile ?? snap.profile, lastActive: s.lastActive, running: s.isActive ?? false, needsYou: needs.contains(s.id))
            }
            snap.updatedAt = Date()
            snap.save()
        }
        return snap
    }
}

// MARK: Widgets

/// Approvals waiting for you. The one to put on a watch face.
struct AttentionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "vory.attention", provider: SnapshotProvider()) { entry in
            AttentionView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.snapshot?.attentionChat.map { URL(string: "vory://chat/\($0.id)") } ?? URL(string: "vory://chats"))
        }
        .configurationDisplayName("Needs you")
        .description("Approvals and questions waiting for an answer.")
        .supportedFamilies(Self.families)
    }

    static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #else
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall]
        #endif
    }
}

struct AttentionView: View {
    var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var count: Int { entry.snapshot?.needsAttention ?? 0 }
    private var chat: WidgetSnapshot.Chat? { entry.snapshot?.attentionChat }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(count == 0 ? "Hermes: nothing waiting" : "\(count) waiting · \(chat?.title ?? "")", systemImage: count == 0 ? "checkmark.circle" : "exclamationmark.bubble.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: count == 0 ? "checkmark" : "exclamationmark.bubble.fill").font(.system(size: 14, weight: .semibold))
                    Text(count == 0 ? "OK" : "\(count)").font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .widgetAccentable()
        #if os(watchOS)
        case .accessoryCorner:
            Text(count == 0 ? "✓" : "\(count)").font(.title3.weight(.bold))
                .widgetLabel { Text(count == 0 ? "Hermes" : (chat?.profile ?? "Hermes")) }
                .widgetAccentable()
        #endif
        default:
            VStack(alignment: .leading, spacing: 3) {
                Label(count == 0 ? "Nothing waiting" : "\(count) need\(count == 1 ? "s" : "") you", systemImage: count == 0 ? "checkmark.circle" : "exclamationmark.bubble.fill")
                    .font(.headline).widgetAccentable()
                if let chat {
                    Text(chat.title).font(.caption).lineLimit(2)
                    Text(chat.profile).font(.caption2).foregroundStyle(.secondary)
                } else if let g = entry.snapshot?.gatewayName {
                    Text(g).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Open Vory to connect").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

/// The chat the agent is working in right now, or the most recent one.
struct ActivityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "vory.activity", provider: SnapshotProvider()) { entry in
            ActivityView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL((entry.snapshot?.activeChat ?? entry.snapshot?.chats.first).map { URL(string: "vory://chat/\($0.id)") } ?? URL(string: "vory://chats"))
        }
        .configurationDisplayName("Current chat")
        .description("What the agent is working on, or the last chat.")
        .supportedFamilies(AttentionWidget.families.filter { $0 != .accessoryCircular } + Self.homeFamilies)
    }
    static var homeFamilies: [WidgetFamily] {
        #if os(watchOS)
        []
        #else
        [.systemMedium]
        #endif
    }
}

struct ActivityView: View {
    var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var chat: WidgetSnapshot.Chat? { entry.snapshot?.activeChat ?? entry.snapshot?.chats.first }
    private var isMedium: Bool {
        #if os(watchOS)
        false
        #else
        family == .systemMedium
        #endif
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            if let chat { Label(chat.running ? "Working: \(chat.title)" : chat.title, systemImage: chat.running ? "ellipsis.message.fill" : "bubble.left") }
            else { Label("Hermes", systemImage: "bubble.left") }
        #if os(watchOS)
        case .accessoryCorner:
            Image(systemName: chat?.running == true ? "ellipsis.message.fill" : "bubble.left").font(.title3)
                .widgetLabel { Text(chat?.title ?? "Hermes") }
                .widgetAccentable()
        #endif
        default:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: chat?.running == true ? "ellipsis.message.fill" : "bubble.left").widgetAccentable()
                    Text(chat?.running == true ? "Working" : "Last chat").font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    if let p = entry.snapshot?.contextPercent { Text("\(p)%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
                }
                Text(chat?.title ?? "No chats yet").font(.headline).lineLimit(isMedium ? 2 : 1)
                if let chat {
                    HStack(spacing: 6) {
                        Text(chat.profile).font(.caption2).foregroundStyle(.secondary)
                        if let t = chat.lastActive { Text(Date(timeIntervalSince1970: t), style: .relative).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                if isMedium, let more = entry.snapshot?.chats.dropFirst().prefix(3), !more.isEmpty {
                    Divider()
                    ForEach(Array(more)) { c in
                        HStack(spacing: 6) {
                            Circle().fill(c.needsYou ? Color.orange : (c.running ? Color.green : Color.secondary)).frame(width: 6, height: 6)
                            Text(c.title).font(.caption).lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

/// Context-window fill of the active chat as a gauge.
struct ContextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "vory.context", provider: SnapshotProvider()) { entry in
            ContextView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "vory://chats"))
        }
        .configurationDisplayName("Context")
        .description("How full the current chat's context window is.")
        .supportedFamilies([.accessoryCircular, .accessoryInline] + Self.corner)
    }
    static var corner: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCorner]
        #else
        []
        #endif
    }
}

struct ContextView: View {
    var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family
    private var pct: Int? { entry.snapshot?.contextPercent }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(pct.map { "Context \($0)%" } ?? "Context —", systemImage: "gauge.with.dots.needle.33percent")
        #if os(watchOS)
        case .accessoryCorner:
            Text(pct.map { "\($0)%" } ?? "—").font(.title3.weight(.semibold))
                .widgetCurvesContent()
                .widgetLabel { ProgressView(value: Double(pct ?? 0), total: 100) }
                .widgetAccentable()
        #endif
        default:
            Gauge(value: Double(pct ?? 0), in: 0...100) {
                Image(systemName: "text.word.spacing")
            } currentValueLabel: {
                Text(pct.map { "\($0)" } ?? "—").font(.system(.caption, design: .rounded).weight(.bold))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        }
    }
}
