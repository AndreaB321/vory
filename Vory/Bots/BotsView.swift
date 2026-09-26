import SwiftUI
import VoryCore

/// Bots are the gateway's profiles: each is an agent with its own instructions, model and
/// sessions. A bot's chats are just sessions filtered to that profile; hosted group rooms
/// (`groups.*`) sit underneath when the gateway offers them.
struct BotsView: View {
    @Environment(AppModel.self) private var model
    @State private var capabilities: GroupsCapabilities?
    @State private var rooms: [Room] = []
    @State private var error: String?
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                if let rt = model.runtime {
                    Section {
                        ForEach(rt.profiles) { p in
                            NavigationLink(value: p) { BotRow(profile: p, isActive: rt.selectedProfile == p.name) }
                        }
                        if rt.profiles.isEmpty { Text("No profiles reported by this gateway.").foregroundStyle(.secondary).font(.footnote) }
                    } header: { Text("Bots") } footer: {
                        Text("Each bot is a Hermes profile: its own SOUL.md, model and sessions. Tap one for its chats.")
                    }
                    if capabilities != nil {
                        Section {
                            if capabilities?.driver == false {
                                Label("The room driver is not running on the gateway; rooms are listed but the agent will not answer in them.", systemImage: "exclamationmark.triangle")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            ForEach(rooms) { room in
                                NavigationLink(value: room) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(room.name).font(.body.weight(.medium))
                                        Text(room.members.compactMap { $0.displayName ?? $0.handle ?? $0.profile }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                            }
                            Button { showCreate = true } label: { Label("New Room", systemImage: "plus") }
                        } header: { Text("Group rooms") } footer: {
                            Text("Hosted group chats where several bots and people talk in one thread.")
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                } else {
                    ContentUnavailableView("No gateway selected", systemImage: "antenna.radiowaves.left.and.right.slash")
                }
            }
            .navigationTitle("Bots")
            .navigationDestination(for: ProfileInfo.self) { BotDetailView(profile: $0) }
            .navigationDestination(for: Room.self) { RoomView(room: $0) }
            .navigationDestination(for: ChatRoute.self) { ConversationView(route: $0) }
            .refreshable { await load() }
            .task(id: model.runtime?.connection.id) { await load() }
            .sheet(isPresented: $showCreate) {
                if let rt = model.runtime { NewRoomSheet(runtime: rt) { await load() } }
            }
        }
    }

    private func load() async {
        guard let rt = model.runtime else { return }
        if rt.profiles.isEmpty { await rt.loadProfiles() }
        capabilities = try? (await rt.rpc("groups.capabilities")).decode()
        guard capabilities != nil else { rooms = []; return }
        do {
            let r: GroupsListResult = try await rt.rpc("groups.list", ["limit": 50]).decode()
            rooms = r.rooms.filter { $0.disbandedAt == nil }
            error = nil
        } catch { self.error = error.localizedDescription }
    }

}

/// "New group" the way Messages does it: a name, then tick the bots (profiles) that take part.
struct NewRoomSheet: View {
    var runtime: GatewayRuntime
    var onCreated: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var members: Set<String> = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Room name", text: $name)
                } footer: { Text("A hosted group chat on this gateway; every bot you add takes part in one shared thread.") }
                Section {
                    ForEach(runtime.profiles) { p in
                        Button {
                            if members.contains(p.name) { members.remove(p.name) } else { members.insert(p.name) }
                        } label: {
                            HStack(spacing: 12) {
                                BotAvatar(profile: p.name, size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.label)
                                    if let d = p.description, !d.isEmpty { Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                                }
                                Spacer()
                                Image(systemName: members.contains(p.name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(members.contains(p.name) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                    if runtime.profiles.isEmpty { Text("No profiles reported by this gateway.").foregroundStyle(.secondary).font(.footnote) }
                } header: { Text("Bots") }
                if let error { Section { Text(error).foregroundStyle(.red).font(.footnote) } }
            }
            .navigationTitle("New Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Creating…" : "Create") { Task { await create() } }
                        .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty || members.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func create() async {
        busy = true; defer { busy = false }
        let list: [JSONValue] = runtime.profiles.filter { members.contains($0.name) }.map {
            .object(["member_id": .string($0.name), "profile": .string($0.name), "display_name": .string($0.label)])
        }
        do {
            _ = try await runtime.rpc("groups.create", ["name": .string(name.trimmingCharacters(in: .whitespaces)), "members": .array(list)])
            await onCreated()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct BotRow: View {
    var profile: ProfileInfo
    var isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            BotAvatar(profile: profile.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.label).font(.body.weight(.medium))
                    if isActive { Text("active").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(.tint.opacity(0.15), in: .capsule).foregroundStyle(.tint) }
                }
                Text([profile.description, profile.model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One bot: its instructions up top, then its sessions. Opening a session switches the app's
/// selected profile to this bot first, because every session RPC is profile-scoped.
struct BotDetailView: View {
    @Environment(AppModel.self) private var model
    var profile: ProfileInfo
    @State private var sessions: [StoredSession] = []
    @State private var error: String?
    @State private var pendingDelete: StoredSession?

    var body: some View {
        List {
            Section {
                NavigationLink { ProfileCardView(profileName: profile.name) } label: {
                    HStack(spacing: 12) {
                        BotAvatar(profile: profile.name, size: 36)
                        Text("Profile")
                    }
                }
            }
            Section {
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                if sessions.isEmpty, error == nil {
                    Text("No chats with this bot yet.").foregroundStyle(.secondary).font(.footnote)
                }
                ForEach(sessions) { s in
                    NavigationLink(value: ChatRoute(storedID: s.id, title: s.displayTitle, profile: profile.name)) {
                        SessionRow(session: s, needsYou: model.runtime?.needsAttention.contains(s.id) ?? false, live: model.runtime?.chatForStored(s.id)?.isRunning ?? false)
                    }
                    .contextMenu { Button(role: .destructive) { pendingDelete = s } label: { Label("Delete", systemImage: "trash") } } preview: { SessionPreview(session: s) }
                }
            } header: { Text("Chats") }
        }
        .navigationTitle(profile.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.composeProfile = profile.name }
        .onDisappear { if model.composeProfile == profile.name { model.composeProfile = nil } }
        .refreshable { await load() }
        .task { await load() }
        .alert("Delete chat?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) { if let s = pendingDelete { Task { await delete(s) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the session and its transcript from the gateway.") }
    }

    private func load() async {
        guard let rt = model.runtime else { return }
        do {
            let r: SessionListResponse = try await rt.api.get("/api/sessions", query: [URLQueryItem(name: "order", value: "recent"), URLQueryItem(name: "limit", value: "100")], profile: profile.name)
            sessions = r.sessions
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func delete(_ s: StoredSession) async {
        guard let rt = model.runtime else { return }
        if let chat = rt.chatForStored(s.id) { rt.closeChat(chat) }
        let _: JSONValue? = try? await rt.api.send("DELETE", "/api/sessions/\(s.id)", profile: profile.name, body: EmptyBody())
        await load()
    }
}

struct RoomView: View {
    @Environment(AppModel.self) private var model
    var room: Room
    @State private var events: [RoomEvent] = []
    @State private var text = ""
    @State private var error: String?
    @State private var cursor = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { ev in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(ev.actor.id).font(.caption.weight(.semibold))
                                Text(ev.kind).font(.caption2).foregroundStyle(.tertiary)
                                Spacer()
                                Text(Date(timeIntervalSince1970: ev.createdAt), style: .time).font(.caption2).foregroundStyle(.tertiary)
                            }
                            MarkdownView(text: ev.payload["text"]?.stringValue ?? ev.payload["content"]?.stringValue ?? ev.payload.displayText)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .id(ev.id)
                    }
                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Message the room", text: $text, axis: .vertical).lineLimit(1...4).padding(.vertical, 6)
                    Button { Task { await send() } } label: { Image(systemName: "arrow.up").font(.body.weight(.bold)) }.buttonStyle(.glassProminent).disabled(text.isEmpty)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(12)
            }
            .onChange(of: events.count) { _, _ in if let l = events.last { proxy.scrollTo(l.id, anchor: .bottom) } }
        }
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(); await poll() }
    }

    private func load() async {
        guard let rt = model.runtime else { return }
        do {
            let r: GroupsLogResult = try await rt.rpc("groups.log", ["room_id": .string(room.roomId), "since_seq": .number(Double(cursor)), "limit": 200]).decode()
            if cursor == 0 { events = r.events } else { events.append(contentsOf: r.events) }
            cursor = r.latestSeq
        } catch { self.error = error.localizedDescription }
    }

    private func poll() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4))
            await load()
        }
    }

    private func send() async {
        guard let rt = model.runtime else { return }
        let t = text; text = ""
        do {
            _ = try await rt.rpc("groups.send", ["room_id": .string(room.roomId), "event_id": .string(UUID().uuidString), "payload": .object(["text": .string(t)])])
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
