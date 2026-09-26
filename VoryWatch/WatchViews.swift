import SwiftUI
import VoryCore

struct WatchRootView: View {
    @Environment(WatchModel.self) private var model
    @State private var path = NavigationPath()

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            Group {
                if model.runtime != nil { WatchChatsView(path: $path) }
                else { WatchConnectView() }
            }
            .navigationDestination(for: String.self) { WatchChatView(storedID: $0) }
        }
        .onChange(of: model.pendingChat) { _, id in
            if let id { path.append(id); model.pendingChat = nil }
        }
    }
}

/// Recent sessions, with the ones waiting for you on top.
struct WatchChatsView: View {
    @Environment(WatchModel.self) private var model
    @Binding var path: NavigationPath
    @State private var showPicker = false
    @State private var showSettings = false

    var body: some View {
        List {
            if let rt = model.runtime {
                let merged = model.listProfile == "*"
                let waiting = model.sessions.filter { rt.needsAttention.contains($0.id) }
                if !waiting.isEmpty {
                    Section("Needs you") {
                        ForEach(waiting) { s in NavigationLink(value: s.id) { WatchSessionRow(session: s, badge: "exclamationmark.bubble.fill", dot: merged) } }
                    }
                }
                Section {
                    Button { Task { await newChat() } } label: { Label("New chat", systemImage: "square.and.pencil") }
                    ForEach(model.sessions.filter { !rt.needsAttention.contains($0.id) }) { s in
                        NavigationLink(value: s.id) { WatchSessionRow(session: s, badge: rt.chatForStored(s.id)?.isRunning == true ? "ellipsis.message" : nil, dot: merged) }
                    }
                } header: { Text(merged ? "All bots" : (model.listProfile ?? rt.selectedProfile ?? rt.connection.name)) }
                if let e = model.loadError { Text(e).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Vory")
        .toolbar {
            if model.runtime != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPicker = true } label: { Image(systemName: "person.crop.circle") }.accessibilityLabel("Choose bot")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                }
            }
        }
        .sheet(isPresented: $showPicker) { WatchProfilePicker() }
        .sheet(isPresented: $showSettings) { WatchSettingsView() }
        .refreshable { await model.loadSessions() }
        .task { await model.loadSessions() }
    }

    private func newChat() async {
        guard let rt = model.runtime else { return }
        if model.socketUsable, let chat = try? await rt.newChat() { path.append(chat.storedID); return }
        // No direct socket (Bluetooth to the phone): ask the phone app to create it.
        do {
            let r = try await model.connectivity.request(["op": "new", "profile": model.listProfile == "*" ? "" : (model.listProfile ?? rt.selectedProfile ?? "")])
            if let sid = r["session"] as? String, !sid.isEmpty { path.append(sid) }
            else { model.loadError = r["error"] as? String ?? "The phone could not create a chat." }
        } catch { model.loadError = "New chat needs the iPhone nearby: \(error.localizedDescription)" }
    }
}

/// Pick which bot's chats the list shows, or all of them merged (watchOS has no Menu).
struct WatchProfilePicker: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Button { model.listProfile = "*"; Task { await model.loadSessions() }; dismiss() } label: {
                Label("All bots", systemImage: "person.2")
            }
            if let rt = model.runtime {
                ForEach(rt.profiles) { p in
                    Button { model.listProfile = p.name; rt.selectedProfile = p.name; Task { await model.loadSessions() }; dismiss() } label: {
                        HStack(spacing: 8) {
                            Circle().fill(WatchBotColor.color(for: p.name)).frame(width: 10, height: 10)
                            Text(p.label)
                            Spacer()
                            if (model.listProfile ?? rt.selectedProfile) == p.name { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }
        .navigationTitle("Bots")
    }
}

/// The same deterministic palette the phone uses when no colour was picked for a bot.
enum WatchBotColor {
    static let palette: [Color] = [Color(red: 0.49, green: 0.36, blue: 1), Color(red: 0.04, green: 0.52, blue: 1), Color(red: 0.19, green: 0.82, blue: 0.35), Color(red: 1, green: 0.62, blue: 0.04), Color(red: 1, green: 0.22, blue: 0.37), Color(red: 0.39, green: 0.82, blue: 1), Color(red: 0.75, green: 0.35, blue: 0.95), Color(red: 1, green: 0.84, blue: 0.04), Color(red: 1, green: 0.42, blue: 0.21), Color(red: 0.35, green: 0.78, blue: 0.98)]
    static func color(for profile: String) -> Color {
        var hash: UInt64 = 5381
        for b in profile.utf8 { hash = (hash &* 33) &+ UInt64(b) }
        return palette[Int(hash % UInt64(palette.count))]
    }
}

struct WatchSessionRow: View {
    var session: StoredSession
    var badge: String?
    var dot = false
    var body: some View {
        HStack(spacing: 8) {
            if dot { Circle().fill(WatchBotColor.color(for: session.profile ?? "?")).frame(width: 8, height: 8) }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayTitle).font(.headline).lineLimit(2)
                Text(session.preview ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let badge { Image(systemName: badge).foregroundStyle(badge.hasPrefix("exclamation") ? .orange : .green) }
        }
    }
}

/// One chat: the tail of the transcript, the approval card when one is waiting, and a dictation
/// composer. The runtime and streaming are the same VoryCore code the phone runs.
struct WatchChatView: View {
    @Environment(WatchModel.self) private var model
    var storedID: String
    @State private var chat: ChatSession?
    @State private var text = ""
    @State private var error: String?
    /// REST-polling fallback state (used when the socket cannot open, e.g. over Bluetooth).
    @State private var proxied = false
    @State private var items: [TranscriptItem] = []
    @State private var cards: [[String: Any]] = []
    @State private var running = false
    @State private var statusText = ""
    @State private var title = "Chat"
    @State private var profile: String?

    var body: some View {
        Group {
            if proxied {
                proxiedBody
            } else if let chat {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(chat.items.suffix(40)) { item in WatchTranscriptRow(item: item).id(item.id) }
                            if let s = chat.statusLine, chat.isRunning { Text(s).font(.caption2).foregroundStyle(.secondary) }
                            if let card = chat.firstCard { WatchCardView(chat: chat, card: card) }
                            HStack(spacing: 6) {
                                TextField("Message", text: $text)
                                Button { Task { let t = text; text = ""; await chat.send(t) } } label: { Image(systemName: "arrow.up.circle.fill").font(.title3) }
                                    .buttonStyle(.plain).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                                    .foregroundStyle(text.isEmpty ? Color.secondary : Color.accentColor)
                            }
                            .padding(.top, 4)
                            Color.clear.frame(height: 1).id("bottom")
                        }
                    }
                    .onChange(of: chat.items.last) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    .defaultScrollAnchor(.bottom)
                }
                .navigationTitle(chat.title)
                .toolbar {
                    if chat.isRunning {
                        ToolbarItem(placement: .topBarTrailing) { Button { Task { await chat.stop() } } label: { Image(systemName: "stop.fill") }.tint(.red) }
                    }
                }
            } else if let error {
                Text(error).foregroundStyle(.red)
            } else { ProgressView() }
        }
        .task {
            guard let rt = model.runtime else { return }
            profile = model.sessions.first { $0.id == storedID }?.profile
            title = model.sessions.first { $0.id == storedID }?.displayTitle ?? "Chat"
            // Give the socket a moment; on the Bluetooth link it never opens, so fall back to REST.
            let deadline = Date().addingTimeInterval(4)
            while !model.socketUsable, Date() < deadline { try? await Task.sleep(for: .milliseconds(300)) }
            if model.socketUsable {
                do { chat = try await rt.openChat(storedID: storedID, title: nil); return } catch { /* fall through */ }
            }
            proxied = true
            await pollLoop(rt)
        }
    }

    // MARK: REST + phone proxy

    private var proxiedBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(items.suffix(40)) { item in WatchTranscriptRow(item: item).id(item.id) }
                    if running { Text(statusText.isEmpty ? "Working…" : statusText).font(.caption2).foregroundStyle(.secondary) }
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, c in proxiedCard(c) }
                    HStack(spacing: 6) {
                        TextField("Message", text: $text)
                        Button { Task { await proxySend() } } label: { Image(systemName: "arrow.up.circle.fill").font(.title3) }
                            .buttonStyle(.plain).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                            .foregroundStyle(text.isEmpty ? Color.secondary : Color.accentColor)
                    }
                    .padding(.top, 4)
                    if let error { Text(error).font(.caption2).foregroundStyle(.red) }
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .onChange(of: items.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .defaultScrollAnchor(.bottom)
        }
        .navigationTitle(title)
        .toolbar {
            if running {
                ToolbarItem(placement: .topBarTrailing) { Button { Task { _ = try? await model.connectivity.request(["op": "stop", "session": storedID, "profile": profile ?? ""]) } } label: { Image(systemName: "stop.fill") }.tint(.red) }
            }
        }
    }

    @ViewBuilder private func proxiedCard(_ c: [String: Any]) -> some View {
        let id = c["id"] as? String ?? ""; let method = c["method"] as? String ?? ""
        VStack(alignment: .leading, spacing: 8) {
            Label(method == "approval" ? "Approval" : "Needs an answer", systemImage: method == "approval" ? "checkmark.shield" : "questionmark.bubble").font(.caption.weight(.semibold))
            Text(c["text"] as? String ?? "").font(.footnote).lineLimit(6)
            if method == "approval" {
                HStack {
                    Button("Once") { Task { await proxyChoice(id, "once") } }.tint(.green)
                    Button("Deny") { Task { await proxyChoice(id, "deny") } }.tint(.red)
                }
                HStack { Button("Session") { Task { await proxyChoice(id, "session") } }; Button("Always") { Task { await proxyChoice(id, "always") } } }.font(.caption)
            } else {
                Button("Answer with the message field") { Task { await proxyAnswer(id) } }.disabled(text.isEmpty)
            }
        }
        .padding(10).background(.orange.opacity(0.15), in: .rect(cornerRadius: 14))
    }

    private func pollLoop(_ rt: GatewayRuntime) async {
        while !Task.isCancelled {
            await refreshProxied(rt)
            try? await Task.sleep(for: .seconds(running ? 2 : 6))
        }
    }

    private func refreshProxied(_ rt: GatewayRuntime) async {
        if let r: JSONValue = try? await rt.api.get("/api/sessions/\(storedID)/messages", query: [URLQueryItem(name: "order", value: "latest"), URLQueryItem(name: "limit", value: "40")], profile: profile ?? rt.selectedProfile) {
            let msgs = (r["messages"]?.arrayValue ?? r.arrayValue ?? []).compactMap { try? $0.decode(TranscriptMessage.self) }
            let built = msgs.enumerated().compactMap { TranscriptItem.fromHistory($1, index: $0) }
            items = built.sorted { $0.timestamp < $1.timestamp }
        }
        if let reply = try? await model.connectivity.request(["op": "cards", "session": storedID, "profile": profile ?? ""]) {
            cards = reply["cards"] as? [[String: Any]] ?? []
            running = reply["running"] as? Bool ?? false
            statusText = reply["status"] as? String ?? ""
            error = nil
        }
    }

    private func proxySend() async {
        let t = text; text = ""
        do {
            let r = try await model.connectivity.request(["op": "prompt", "session": storedID, "profile": profile ?? "", "text": t])
            if r["ok"] as? Bool != true { error = r["error"] as? String ?? "The phone could not send it." } else { running = true; error = nil }
            items.append(TranscriptItem(id: "local-\(UUID().uuidString)", kind: .user(text: t, attachments: [])))
        } catch { self.error = error.localizedDescription }
    }

    private func proxyChoice(_ card: String, _ choice: String) async {
        do { _ = try await model.connectivity.request(["op": "approval", "session": storedID, "profile": profile ?? "", "card": card, "choice": choice]); cards.removeAll { ($0["id"] as? String) == card } }
        catch { self.error = error.localizedDescription }
    }

    private func proxyAnswer(_ card: String) async {
        let t = text; text = ""
        do { _ = try await model.connectivity.request(["op": "answer", "session": storedID, "profile": profile ?? "", "card": card, "text": t]); cards.removeAll { ($0["id"] as? String) == card } }
        catch { self.error = error.localizedDescription }
    }
}

struct WatchTranscriptRow: View {
    var item: TranscriptItem
    var body: some View {
        switch item.kind {
        case .user(let t, _):
            HStack { Spacer(minLength: 24); Text(t).font(.footnote).padding(8).background(Color.accentColor, in: .rect(cornerRadius: 12)).foregroundStyle(.white) }
        case .assistant(let t, _, let streaming):
            HStack {
                Text(t.isEmpty && streaming ? "…" : t).font(.footnote).padding(8).background(Color.gray.opacity(0.25), in: .rect(cornerRadius: 12))
                Spacer(minLength: 16)
            }
        case .tool(let a):
            Label("\(a.displayName)\(a.summary.map { " · \($0)" } ?? "")", systemImage: a.status == .done ? "checkmark.circle" : a.status == .failed ? "xmark.circle" : "gear")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        case .system(let t, let sym):
            Label(t, systemImage: sym).font(.caption2).foregroundStyle(.secondary)
        case .error(let t):
            Label(t, systemImage: "exclamationmark.triangle").font(.caption2).foregroundStyle(.red)
        case .subagent(let g, let s):
            Label("\(g) · \(s)", systemImage: "person.2").font(.caption2).foregroundStyle(.secondary)
        case .steer(let t, _):
            Text(t).font(.caption).padding(6).background(Color.gray.opacity(0.3), in: .rect(cornerRadius: 10))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// Approval / clarify / secret cards, sized for a wrist.
struct WatchCardView: View {
    var chat: ChatSession
    var card: PendingCard
    @State private var answer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let a = card.approval {
                Label("Approval", systemImage: "checkmark.shield").font(.caption.weight(.semibold))
                Text(a.description?.isEmpty == false ? a.description! : (a.command ?? "")).font(.footnote).lineLimit(6)
                HStack {
                    Button("Once") { Task { await chat.respond(card: card, result: ["choice": "once"]) } }.tint(.green)
                    Button("Deny") { Task { await chat.respond(card: card, result: ["choice": "deny"]) } }.tint(.red)
                }
                HStack {
                    Button("Session") { Task { await chat.respond(card: card, result: ["choice": "session"]) } }
                    Button("Always") { Task { await chat.respond(card: card, result: ["choice": "always"]) } }
                }
                .font(.caption)
            } else if let c = card.clarify {
                Label("Question", systemImage: "questionmark.bubble").font(.caption.weight(.semibold))
                Text(c.question ?? c.questions?.first?.question ?? "").font(.footnote)
                TextField("Answer", text: $answer)
                Button("Send") { Task { await chat.respond(card: card, result: ["answer": .string(answer)]) } }.disabled(answer.isEmpty)
            } else {
                Label("Input needed", systemImage: "key").font(.caption.weight(.semibold))
                Text(card.valuePrompt?.prompt ?? card.method).font(.footnote)
                SecureField("Value", text: $answer)
                Button("Send") { Task { await chat.respond(card: card, result: ["value": .string(answer)]) } }.disabled(answer.isEmpty)
            }
        }
        .padding(10)
        .background(.orange.opacity(0.15), in: .rect(cornerRadius: 14))
    }
}

/// Before a gateway is known: normally the phone pushes it over; a token can be typed if not.
struct WatchConnectView: View {
    @Environment(WatchModel.self) private var model
    @State private var url = ""
    @State private var token = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "iphone.and.applewatch").font(.largeTitle).foregroundStyle(.tint)
                Text("Open Vory on your iPhone").font(.headline)
                Text(model.syncStatus).font(.caption2).foregroundStyle(.secondary)
                Text("Your gateways sync here automatically. Or enter one by hand:").font(.caption2).foregroundStyle(.secondary)
                TextField("https://hermes.example.com", text: $url).textContentType(.URL)
                SecureField("Session token", text: $token)
                Button(busy ? "Connecting…" : "Connect") { Task { await connect() } }.disabled(busy || url.isEmpty || token.isEmpty)
                if let error { Text(error).font(.caption2).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Vory")
    }

    private func connect() async {
        busy = true; defer { busy = false }
        do {
            let g = try GatewayURL.normalize(url, pathPrefix: nil)
            let conn = GatewayConnection(name: g.host, gateway: g, authMode: .sessionToken)
            try model.store.upsert(conn, secrets: GatewaySecrets(sessionToken: token))
            await model.activate(conn)
        } catch { self.error = error.localizedDescription }
    }
}

/// A small settings pane: which gateway, how the watch reaches it, and a way to re-pull the
/// credentials from the phone.
struct WatchSettingsView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let rt = model.runtime {
                    Section("Gateway") {
                        LabeledContent("Name", value: rt.connection.name)
                        LabeledContent("Link", value: model.socketUsable ? "Direct (Wi-Fi)" : "Through iPhone")
                        LabeledContent("Status", value: rt.socketState.label)
                        LabeledContent("Bot", value: model.listProfile == "*" ? "All bots" : (model.listProfile ?? rt.selectedProfile ?? "—"))
                    }
                    Section {
                        Button { Task { await rt.reconnectNow() } } label: { Label("Reconnect", systemImage: "arrow.clockwise") }
                    } footer: { Text("Chats always load over HTTP. Sending and approving go through the iPhone unless the watch has its own Wi-Fi route to the gateway.") }
                } else {
                    Section { Text("Open Vory on the iPhone once; it hands the gateway to the watch.").font(.footnote) }
                }
                Section {
                    LabeledContent("Version", value: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
