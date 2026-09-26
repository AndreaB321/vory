import SwiftUI
import VoryCore

struct ChatRoute: Hashable {
    var storedID: String?
    var title: String?
    /// Sessions are profile-scoped on the gateway; when set, the chat screen selects this bot first.
    var profile: String?
    /// Sent as soon as the chat opens: the first message typed in the compose sheet.
    var initialText: String? = nil
}

struct ChatListView: View {
    @Environment(AppModel.self) private var model
    @State private var sessions: [StoredSession] = []
    @State private var searchText = ""
    @State private var searchResults: [StoredSession] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var path = NavigationPath()
    @State private var pendingDelete: StoredSession?
    @State private var lastRouted: PendingRoute?
    /// Every profile's chats in one list, newest first, with the bot's avatar on each row.
    @AppStorage("chats.allBots") private var allBots = false
    @State private var showNewChat = false
    @State private var showNewBot = false
    @State private var rooms: [Room] = []
    // Filters (the funnel button): what to show and in which order.
    @AppStorage("chats.filter.pinned") private var pinnedOnly = false
    @AppStorage("chats.filter.needsYou") private var needsYouOnly = false
    @AppStorage("chats.filter.live") private var liveOnly = false
    @AppStorage("chats.filter.archived") private var showArchived = true
    @AppStorage("chats.sort") private var sortKey = "recent"
    private var filtering: Bool { pinnedOnly || needsYouOnly || liveOnly || !showArchived || sortKey != "recent" }
    /// The profile menu's icons are rendered images; UIKit keeps the built menu, so it is given a
    /// new identity whenever a bot's colour or look changes.
    @AppStorage(BotColors.storageKey) private var botColorsRaw = ""
    @AppStorage(BotAvatarStore.storageKey) private var botAvatarsRaw = ""
    @AppStorage(BotAvatarStore.glassAllKey) private var glassAll = false
    /// Mirrors the tab bar's minimize-on-scroll so the compose circle drops beside the collapsed bar.

    private var runtime: GatewayRuntime? { model.runtime }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let runtime {
                    list(runtime)
                } else {
                    ContentUnavailableView("No gateway selected", systemImage: "antenna.radiowaves.left.and.right.slash", description: Text(model.activationError ?? "Choose a gateway in Settings."))
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            // Driven by the stack's own path rather than by the pushed screen: the bar starts
            // coming back the instant a pop begins instead of after the transition settles.
            .onChange(of: path.isEmpty, initial: true) { _, empty in model.chatsPathOpen = !empty; model.tabAtRoot[.chats] = empty }
            .onChange(of: model.popToRoot[.chats]) { _, _ in path = NavigationPath() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { profileMenu }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showNewBot = true } label: { Image(systemName: "plus") }.accessibilityLabel("New bot")
                    filterMenu
                }
            }
            // Compose: the Messages-style sheet (To: bots, first message).
            .onChange(of: model.newChatRequest) { _, r in
                guard r != nil, model.selectedTab == .chats, runtime != nil else { return }
                showNewChat = true
            }
            .sheet(isPresented: $showNewBot) { if let runtime { NewBotSheet(runtime: runtime) } }
            .sheet(isPresented: $showNewChat) {
                if let runtime {
                    NewChatSheet(runtime: runtime) { start in
                        switch start {
                        case .chat(let profile, let text): path.append(ChatRoute(storedID: nil, title: nil, profile: profile, initialText: text))
                        case .group(let room, let text): rooms.insert(room, at: 0); path.append(RoomRoute(room: room, initialText: text))
                        }
                    }
                }
            }
            .navigationDestination(for: ChatRoute.self) { route in ConversationView(route: route) }
            .navigationDestination(for: RoomRoute.self) { r in RoomView(room: r.room, initialText: r.initialText) }
            // Under the title, not docked at the bottom where our tab bar lives.
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
            .onChange(of: searchText) { _, q in Task { await search(q) } }
            .refreshable { await load() }
            .task(id: runtime?.connection.id) { await load() }
            .task(id: runtime?.selectedProfile) { await load() }
            .task(id: allBots) { await load() }
            // The socket coming up is when the gateway becomes reachable; do not wait for a pull.
            .onChange(of: runtime?.socketState) { _, s in if case .open? = s { Task { await load() } } }
            .onReceive(NotificationCenter.default.publisher(for: .hermesSessionsChanged)) { _ in Task { await load() } }
            .onChange(of: model.pendingRoute) { _, r in
                guard let r, r != lastRouted else { return }
                lastRouted = r
                path.append(ChatRoute(storedID: r.storedSessionID, title: nil))
            }
            .alert("Delete chat?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Delete", role: .destructive) { if let s = pendingDelete { Task { await delete(s) } } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This removes the session and its transcript from the gateway.") }
        }
    }

    private var profileMenu: some View {
        Menu {
            if let runtime {
                Picker("Profile", selection: Binding(get: { runtime.selectedProfile ?? "" }, set: { runtime.selectedProfile = $0 })) {
                    ForEach(runtime.profiles) { p in
                        Label { Text(p.label) } icon: { Image(uiImage: BotAvatarImage.make(profile: p.name)) }.tag(p.name)
                    }
                }
                Toggle(isOn: $allBots) { Label("All bots", systemImage: "person.2") }
                Divider()
                Section(runtime.connection.name) {
                    Label(runtime.socketState.label, systemImage: connectionSymbol(runtime.socketState))
                    if case .open = runtime.socketState {} else {
                        Button { Task { await runtime.reconnectNow() } } label: { Label("Reconnect", systemImage: "arrow.clockwise") }
                    }
                }
            }
        } label: {
            // A fixed-size avatar: a text label changed width with each profile name and the bar
            // visibly jumped as it re-laid out.
            // Painted, not glass: this sits on the toolbar's own glass button.
            BotAvatar(profile: runtime?.selectedProfile ?? "?", size: 26, drawn: true)
                .accessibilityLabel("Profile: \(runtime?.selectedProfile ?? "none")")
        }
        .id("\(botColorsRaw)|\(botAvatarsRaw)|\(glassAll)")
    }

    private var filterMenu: some View {
        Menu {
            Section("Show") {
                Toggle(isOn: $pinnedOnly) { Label("Pinned only", systemImage: "pin") }
                Toggle(isOn: $needsYouOnly) { Label("Needs you", systemImage: "exclamationmark.bubble") }
                Toggle(isOn: $liveOnly) { Label("Working now", systemImage: "bolt") }
                Toggle(isOn: $showArchived) { Label("Archived", systemImage: "archivebox") }
            }
            Picker("Sort by", selection: $sortKey) {
                Label("Recent", systemImage: "clock").tag("recent")
                Label("Title", systemImage: "textformat").tag("title")
                Label("Bot", systemImage: "person").tag("bot")
                Label("Model", systemImage: "cpu").tag("model")
            }
            if filtering {
                Button { pinnedOnly = false; needsYouOnly = false; liveOnly = false; showArchived = true; sortKey = "recent" } label: { Label("Clear filters", systemImage: "xmark.circle") }
            }
        } label: {
            Image(systemName: filtering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .accessibilityLabel(filtering ? "Filters (on)" : "Filters")
        }
        .accessibilityIdentifier("chats.filters")
    }

    /// The filters and the sort applied to the loaded (or searched) sessions.
    private func filtered(_ list: [StoredSession], runtime: GatewayRuntime) -> [StoredSession] {
        var out = list
        if pinnedOnly { out = out.filter { $0.pinned == true } }
        if needsYouOnly { out = out.filter { runtime.needsAttention.contains($0.id) } }
        if liveOnly { out = out.filter { runtime.chatForStored($0.id)?.isRunning ?? false } }
        if !showArchived { out = out.filter { $0.archived != true } }
        switch sortKey {
        case "title": out.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case "bot": out.sort { ($0.profile ?? "", $1.lastActive ?? 0) < ($1.profile ?? "", $0.lastActive ?? 0) }
        case "model": out.sort { ($0.model ?? "", $1.lastActive ?? 0) < ($1.model ?? "", $0.lastActive ?? 0) }
        default: break   // recent: pinned first, then newest, as loaded
        }
        return out
    }

    private func connectionSymbol(_ s: SocketState) -> String {
        switch s {
        case .open: return "checkmark.circle.fill"
        case .connecting, .reconnecting: return "arrow.triangle.2.circlepath"
        case .authRejected, .failed: return "xmark.octagon.fill"
        case .idle: return "circle"
        }
    }

    @ViewBuilder private func list(_ runtime: GatewayRuntime) -> some View {
        let rows = filtered(searchText.isEmpty ? sessions : searchResults, runtime: runtime)
        List {
            if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
            if searchText.isEmpty, !rooms.isEmpty, !pinnedOnly, !needsYouOnly, !liveOnly {
                Section("Group chats") {
                    ForEach(rooms) { room in
                        NavigationLink(value: RoomRoute(room: room, initialText: nil)) {
                            HStack(spacing: 12) {
                                HStack(spacing: -12) {
                                    ForEach(Array(room.members.prefix(3).enumerated()), id: \.offset) { _, m in
                                        BotAvatar(profile: m.profile ?? m.handle ?? "?", size: 30)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(room.name).font(.body.weight(.medium)).lineLimit(1)
                                    Text(room.members.compactMap { $0.displayName ?? $0.handle ?? $0.profile }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            if rows.isEmpty && !loading {
                ContentUnavailableView(searchText.isEmpty ? "No chats yet" : "No results", systemImage: "bubble.left.and.bubble.right",
                                       description: Text(searchText.isEmpty ? "Start a new chat with the compose button." : "Try another search."))
                    .listRowSeparator(.hidden)
            }
            ForEach(rows) { s in
                NavigationLink(value: ChatRoute(storedID: s.id, title: s.displayTitle, profile: allBots ? s.profile : nil)) {
                    SessionRow(session: s, needsYou: runtime.needsAttention.contains(s.id), live: runtime.chatForStored(s.id)?.isRunning ?? false, showBot: allBots,
                               thinking: runtime.chatForStored(s.id).map { $0.isRunning && ($0.statusLine ?? "Thinking…") == "Thinking…" } ?? false)
                }
                .contextMenu {
                    Button { path.append(ChatRoute(storedID: s.id, title: s.displayTitle, profile: allBots ? s.profile : nil)) } label: { Label("Open", systemImage: "bubble.left") }
                    Button { Task { await patch(s, ["pinned": .bool(!(s.pinned ?? false))]) } } label: { Label(s.pinned == true ? "Unpin" : "Pin", systemImage: s.pinned == true ? "pin.slash" : "pin") }
                    Button { Task { await patch(s, ["archived": .bool(!(s.archived ?? false))]) } } label: { Label(s.archived == true ? "Unarchive" : "Archive", systemImage: "archivebox") }
                    Divider()
                    Button(role: .destructive) { pendingDelete = s } label: { Label("Delete", systemImage: "trash") }
                } preview: {
                    SessionPreview(session: s, runtime: runtime, profile: allBots ? s.profile : nil)
                }
                // Delete alone on the trailing edge; Archive lives with Pin on the leading edge so
                // the two are never a thumb-width apart.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { pendingDelete = s } label: { Label("Delete", systemImage: "trash") }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button { Task { await patch(s, ["pinned": .bool(!(s.pinned ?? false))]) } } label: { Label(s.pinned == true ? "Unpin" : "Pin", systemImage: s.pinned == true ? "pin.slash" : "pin") }.tint(.yellow)
                    Button { Task { await patch(s, ["archived": .bool(!(s.archived ?? false))]) } } label: { Label(s.archived == true ? "Unarchive" : "Archive", systemImage: "archivebox") }.tint(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
        // The grouped list otherwise leaves a section's worth of empty space under the search bar.
        .contentMargins(.top, 0, for: .scrollContent)
        // The bots in the rows look where the list is going.
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, new in BotAmbient.shared.scrolled(dy: new - old) }
        .overlay { if loading && sessions.isEmpty { ProgressView() } }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let msg = runtime.restartRequired {
                RestartRequiredBanner(runtime: runtime, message: msg)
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: runtime.restartRequired == nil)
    }

    private func load() async {
        guard let runtime else { return }
        let cacheProfile = allBots ? "*" : runtime.selectedProfile
        if sessions.isEmpty { sessions = SessionCache.load(connection: runtime.connection.id, profile: cacheProfile) }
        loading = sessions.isEmpty; defer { loading = false }
        do {
            var all: [StoredSession] = []
            if allBots {
                let profiles = runtime.profiles.map(\.name)
                try await withThrowingTaskGroup(of: [StoredSession].self) { group in
                    for p in profiles {
                        group.addTask {
                            let r: SessionListResponse = try await runtime.api.get("/api/sessions", query: [URLQueryItem(name: "order", value: "recent"), URLQueryItem(name: "limit", value: "50")], profile: p)
                            return r.sessions.map { var s = $0; if s.profile == nil || s.profile!.isEmpty { s.profile = p }; return s }
                        }
                    }
                    for try await part in group { all += part }
                }
            } else {
                let r: SessionListResponse = try await runtime.api.get("/api/sessions", query: [URLQueryItem(name: "order", value: "recent"), URLQueryItem(name: "limit", value: "100")], profile: runtime.selectedProfile)
                all = r.sessions
            }
            sessions = all.sorted { ($0.pinned ?? false ? 1 : 0, $0.lastActive ?? 0) > ($1.pinned ?? false ? 1 : 0, $1.lastActive ?? 0) }
            SessionCache.save(sessions, connection: runtime.connection.id, profile: cacheProfile)
            errorText = nil
            // Group chats live on the gateway's room driver; none when it has no rooms.
            if let r: GroupsListResult = try? await runtime.rpc("groups.list", ["limit": 50], timeout: 10).decode() {
                rooms = r.rooms.filter { $0.disbandedAt == nil }
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func search(_ q: String) async {
        guard let runtime, !q.trimmingCharacters(in: .whitespaces).isEmpty else { searchResults = []; return }
        do {
            let r: JSONValue = try await runtime.api.get("/api/sessions/search", query: [URLQueryItem(name: "q", value: q)], profile: runtime.selectedProfile)
            let arr = r["sessions"]?.arrayValue ?? r["results"]?.arrayValue ?? r.arrayValue ?? []
            searchResults = arr.compactMap { try? $0.decode(StoredSession.self) }
        } catch { errorText = error.localizedDescription }
    }

    private func delete(_ s: StoredSession) async {
        guard let runtime else { return }
        if let chat = runtime.chatForStored(s.id) { runtime.closeChat(chat) }
        let _: JSONValue? = try? await runtime.api.send("DELETE", "/api/sessions/\(s.id)", profile: runtime.selectedProfile, body: EmptyBody())
        await load()
    }

    private func patch(_ s: StoredSession, _ fields: [String: JSONValue]) async {
        guard let runtime else { return }
        var body = fields
        if let p = runtime.selectedProfile { body["profile"] = .string(p) }
        let _: JSONValue? = try? await runtime.api.send("PATCH", "/api/sessions/\(s.id)", json: .object(body))
        await load()
    }
}

struct SessionRow: View {
    var session: StoredSession
    var needsYou: Bool
    var live: Bool
    var showBot = false
    var thinking = false

    var body: some View {
        HStack(spacing: 12) {
            if showBot { BotAvatar(profile: session.profile ?? "?", size: 34, active: live, mood: BotFaceView.Mood(thinking: thinking)) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if session.pinned == true { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.secondary) }
                    Text(session.displayTitle).font(.body.weight(.medium)).lineLimit(1)
                }
                Text(session.preview ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 8) {
                    if let m = session.model, !m.isEmpty { Text(m).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) }
                    if let d = session.lastDate { Text(d, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.tertiary) }
                }
            }
            Spacer(minLength: 0)
            if needsYou {
                Text("Needs you").font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.red.opacity(0.15), in: .capsule).foregroundStyle(.red)
            } else if live {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}


/// The long-press peek for a chat row: the tail of the conversation as small bubbles, like
/// peeking a thread in Messages. Open stays in the menu; SwiftUI previews cannot be tapped through.
struct SessionPreview: View {
    var session: StoredSession
    var runtime: GatewayRuntime?
    var profile: String?
    @State private var messages: [TranscriptMessage] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                BotAvatar(profile: session.profile ?? profile ?? runtime?.selectedProfile ?? "?", size: 24)
                Text(session.displayTitle).font(.headline).lineLimit(1)
                Spacer(minLength: 0)
            }
            if messages.isEmpty {
                if let p = session.preview, !p.isEmpty {
                    Text(p).font(.subheadline).foregroundStyle(.secondary).lineLimit(6)
                }
                if !loaded { ProgressView().controlSize(.small).frame(maxWidth: .infinity) }
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, m in
                        HStack {
                            if m.role == "user" { Spacer(minLength: 40) }
                            Text(m.text ?? "").font(.footnote).lineLimit(4)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .foregroundStyle(m.role == "user" ? .white : .primary)
                                .background(m.role == "user" ? Color.accentColor : Color(.systemGray5), in: .rect(cornerRadius: 12))
                            if m.role != "user" { Spacer(minLength: 40) }
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                if let n = session.messageCount { Label("\(n) messages", systemImage: "text.bubble") }
                if let m = session.model, !m.isEmpty { Label(m.split(separator: "/").last.map(String.init) ?? m, systemImage: "cpu").lineLimit(1) }
                if let d = session.lastDate { Text(d, format: .relative(presentation: .named)) }
            }
            .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
        .task {
            defer { loaded = true }
            if let cached = runtime.flatMap({ TranscriptCache.load(connection: $0.connection.id, storedID: session.id) }), !cached.isEmpty {
                messages = Array(cached.filter { $0.role == "user" || $0.role == "assistant" }.suffix(6)); return
            }
            guard let runtime, let r: JSONValue = try? await runtime.api.get("/api/sessions/\(session.id)/messages",
                                                                             query: [URLQueryItem(name: "order", value: "latest"), URLQueryItem(name: "limit", value: "12")],
                                                                             profile: profile ?? session.profile ?? runtime.selectedProfile) else { return }
            let all = (r["messages"]?.arrayValue ?? []).compactMap { try? $0.decode(TranscriptMessage.self) }
            messages = Array(all.filter { ($0.role == "user" || $0.role == "assistant") && !($0.text ?? "").isEmpty }.suffix(6))
        }
    }
}

/// A group chat as a navigation value, with the first message when it was just started.
struct RoomRoute: Hashable {
    var room: Room
    var initialText: String?
}
