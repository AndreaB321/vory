import SwiftUI
import VoryCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""

    private struct Row: Identifiable { let id: String; let title: String; let symbol: String; let color: Color; let destination: AnyView }

    private var hermesRows: [Row] {
        [
            Row(id: "profile", title: "Profile", symbol: "person.crop.circle", color: .indigo, destination: AnyView(ProfileView())),
            Row(id: "model", title: "Model", symbol: "cpu", color: .blue, destination: AnyView(ModelSettingsView())),
            Row(id: "config", title: "Config", symbol: "slider.horizontal.3", color: .gray, destination: AnyView(ConfigFormView())),
            Row(id: "env", title: "API Keys & Environment", symbol: "key.fill", color: .orange, destination: AnyView(EnvView())),
            Row(id: "tools", title: "Tools", symbol: "wrench.and.screwdriver", color: .teal, destination: AnyView(ToolsView())),
            Row(id: "skills", title: "Skills", symbol: "sparkles", color: .purple, destination: AnyView(SkillsView())),
            Row(id: "mcp", title: "MCP Servers", symbol: "point.3.connected.trianglepath.dotted", color: .mint, destination: AnyView(MCPView())),
            Row(id: "approvals", title: "Approvals", symbol: "checkmark.shield", color: .green, destination: AnyView(ApprovalsView())),
            Row(id: "cron", title: "Cron Jobs", symbol: "clock", color: .pink, destination: AnyView(CronView())),
            Row(id: "sessions", title: "Sessions", symbol: "list.bullet.rectangle", color: .cyan, destination: AnyView(SessionsView())),
            Row(id: "channels", title: "Channels", symbol: "antenna.radiowaves.left.and.right", color: .brown, destination: AnyView(ChannelsView())),
            Row(id: "system", title: "System", symbol: "server.rack", color: .secondary, destination: AnyView(SystemView())),
        ]
    }
    private var appRows: [Row] {
        [
            Row(id: "notifications", title: "Notifications", symbol: "bell.badge", color: .red, destination: AnyView(NotificationsView())),
            Row(id: "security", title: "Security", symbol: "faceid", color: .green, destination: AnyView(SecurityView())),
            Row(id: "appearance", title: "Appearance", symbol: "circle.lefthalf.filled", color: .black, destination: AnyView(AppearanceView())),
            Row(id: "about", title: "About", symbol: "info.circle", color: .blue, destination: AnyView(AboutView())),
        ]
    }

    private func filtered(_ rows: [Row]) -> [Row] { search.isEmpty ? rows : rows.filter { $0.title.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section {
                        NavigationLink { GatewaysView() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "network").font(.title2).foregroundStyle(.tint).frame(width: 36)
                                VStack(alignment: .leading) {
                                    Text(model.runtime?.connection.name ?? "No gateway").font(.headline)
                                    Text(model.runtime?.connection.gateway.description ?? "Add a gateway").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if let s = model.runtime?.socketState { ConnectionPill(state: s) }
                            }
                            .padding(.vertical, 4)
                        }
                        if let rt = model.runtime, !rt.profiles.isEmpty {
                            Picker("Profile", selection: Binding(get: { rt.selectedProfile ?? "" }, set: { rt.selectedProfile = $0 })) {
                                ForEach(rt.profiles) { Text($0.label).tag($0.name) }
                            }
                        }
                    } header: { Text("Gateway") }
                }
                Section("Hermes") {
                    ForEach(filtered(hermesRows)) { row in
                        NavigationLink { row.destination.navigationTitle(row.title) } label: { SettingsLabel(row.title, row.symbol, row.color) }
                    }
                }
                .disabled(model.runtime == nil)
                Section("App") {
                    ForEach(filtered(appRows)) { row in
                        NavigationLink { row.destination.navigationTitle(row.title) } label: { SettingsLabel(row.title, row.symbol, row.color) }
                            .badge(row.id == "notifications" && model.companionUpdateAvailable ? 1 : 0)
                    }
                }
            }
            .navigationTitle("Settings")
            .searchable(text: $search, prompt: "Search settings")
        }
    }
}

struct SettingsLabel: View {
    var title: String; var symbol: String; var color: Color
    init(_ t: String, _ s: String, _ c: Color) { title = t; symbol = s; color = c }
    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.white).frame(width: 28, height: 28).background(color, in: .rect(cornerRadius: 7))
        }
    }
}

// MARK: Gateways

struct GatewaysView: View {
    @Environment(AppModel.self) private var model
    @State private var showAdd = false
    @State private var pendingDelete: GatewayConnection?

    var body: some View {
        List {
            Section {
                ForEach(model.store.connections) { c in
                    HStack {
                        Button { Task { await model.activate(c) } } label: {
                            HStack {
                                Image(systemName: model.store.activeConnectionID == c.id ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(.body)
                                    Text(c.gateway.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(c.authMode.title).font(.caption2).foregroundStyle(.tertiary)
                                        if c.hasAccessHeaders { Text("· Cloudflare Access").font(.caption2).foregroundStyle(.tertiary) }
                                        if let v = c.lastVersion { Text("· Hermes \(v)").font(.caption2).foregroundStyle(.tertiary) }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        NavigationLink { GatewayFormView(existing: c) } label: { EmptyView() }.frame(width: 20)
                    }
                    .swipeActions { Button(role: .destructive) { pendingDelete = c } label: { Label("Delete", systemImage: "trash") } }
                }
            } footer: {
                Text("One saved gateway covers every profile on that machine; switch profiles from the Chats or Settings tab. Approvals always go to the gateway that owns the session.")
            }
            Section {
                Button { showAdd = true } label: { Label("Add Gateway", systemImage: "plus") }
                if let rt = model.runtime {
                    Button { Task { await rt.reconnectNow() } } label: { Label("Reconnect", systemImage: "arrow.clockwise") }
                    if case .authRejected(let why) = rt.socketState {
                        Text(why).font(.footnote).foregroundStyle(.red)
                        NavigationLink("Sign in again") { GatewayFormView(existing: rt.connection) }
                    }
                }
            }
        }
        .navigationTitle("Gateways")
        .sheet(isPresented: $showAdd) { NavigationStack { GatewayFormView() } }
        .alert("Remove gateway?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Remove", role: .destructive) { if let c = pendingDelete { Task { await model.deleteConnection(c.id) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Saved credentials for this gateway are deleted from the Keychain.") }
    }
}

// MARK: Profile

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var showCreate = false
    @State private var newName = ""
    @State private var cloneFrom = ""
    @State private var error: String?

    var body: some View {
        List {
            if let rt = model.runtime {
                Section("Active profile in this app") {
                    ForEach(rt.profiles) { p in
                        Button { rt.selectedProfile = p.name } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.label)
                                    Text([p.model, p.description].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if rt.selectedProfile == p.name { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                        .tint(.primary)
                    }
                }
                Section {
                    Button { showCreate = true } label: { Label("Create Profile", systemImage: "plus") }
                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                } footer: { Text("Profiles are separate Hermes homes on the gateway machine (config, skills, sessions). Settings screens read and write the profile selected here.") }
            }
        }
        .refreshable { await model.runtime?.loadProfiles() }
        .alert("New profile", isPresented: $showCreate) {
            TextField("Name", text: $newName)
            TextField("Clone from (optional)", text: $cloneFrom)
            Button("Create") { Task { await create() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func create() async {
        guard let rt = model.runtime else { return }
        var body: [String: JSONValue] = ["name": .string(newName)]
        if !cloneFrom.isEmpty { body["clone_from"] = .string(cloneFrom) }
        do {
            let _: JSONValue = try await rt.api.send("POST", "/api/profiles", json: .object(body))
            await rt.loadProfiles()
            newName = ""; cloneFrom = ""; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: Notifications / Security / Appearance / About

struct NotificationsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("liveActivitiesEnabled") private var liveActivities = true
    @AppStorage("hapticsEnabled") private var haptics = true

    var body: some View {
        let push = model.push
        List {
            Section("Permission") {
                LabeledContent("Status", value: statusText(push.authorization))
                if push.authorization == .notDetermined {
                    Button("Allow Notifications") { Task { _ = await push.requestAuthorization() } }
                } else if push.authorization == .denied {
                    Link("Open iOS Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                Toggle("Live Activity", isOn: $liveActivities)
                Toggle("Haptics", isOn: $haptics)
            }
            Section {
                NavigationLink { BackgroundNotificationsView() } label: { Label("Background Notifications", systemImage: "server.rack") }
                    .badge(model.companionUpdateAvailable ? 1 : 0)
                    .disabled(model.runtime == nil)
            } footer: {
                Text("Approvals, questions, finished turns and errors while Vory is closed — delivered by the companion plugin on your gateway. Foreground and just-backgrounded events are delivered locally without it.")
            }
        }
        .task { await push.refreshAuthorization() }
    }

    private func statusText(_ s: UNAuthorizationStatus) -> String {
        switch s { case .authorized: return "Allowed"; case .denied: return "Denied"; case .provisional: return "Provisional"; case .ephemeral: return "Ephemeral"; default: return "Not asked" }
    }
}

struct SecurityView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        List {
            Section {
                Toggle("Require \(model.lock.biometryName)", isOn: Binding(get: { model.lock.isEnabled }, set: { model.lock.isEnabled = $0 }))
            } footer: { Text("Locks the app after it has been in the background. Gateway credentials are stored in the iOS Keychain (device-only).") }
        }
    }
}

struct AppearanceView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("colorSchemePreference") private var scheme = "system"
    @AppStorage(TabLayout.storageKey) private var layoutRaw = ""
    @AppStorage(ChatStyle.showToolCalls) private var showToolCalls = true
    @AppStorage(ChatStyle.showReasoning) private var showReasoning = true
    @AppStorage(ChatStyle.showTurnStats) private var showTurnStats = true
    @AppStorage(ChatStyle.showSystemNotes) private var showSystemNotes = true
    @Environment(\.editMode) private var editMode

    private var layout: TabLayout { TabLayout.parse(layoutRaw) }

    var body: some View {
        List {
            Section {
                Picker("Theme", selection: $scheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            } header: { Text("Appearance") } footer: {
                Text("Liquid Glass intensity, Reduce Transparency, Increase Contrast, Bold Text, Dynamic Type and Reduce Motion follow your iOS settings.")
            }
            Section {
                ForEach(layout.tabs, id: \.self) { tab in
                    HStack {
                        Label(tab.title, systemImage: tab.symbol)
                        if TabLayout.required.contains(tab) { Spacer(); Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary) }
                    }
                    .deleteDisabled(TabLayout.required.contains(tab))
                }
                .onMove { from, to in var l = layout; l.move(fromOffsets: from, toOffset: to); layoutRaw = l.encoded }
                .onDelete { offsets in
                    var l = layout
                    for i in offsets.sorted(by: >) { l.set(l.tabs[i], enabled: false) }
                    layoutRaw = l.encoded
                }
            } header: {
                HStack { Text("Tab bar · \(layout.tabs.count) of \(TabLayout.maxTabs)"); Spacer(); EditButton().font(.caption) }
            } footer: {
                Text(editMode?.wrappedValue.isEditing == true
                     ? "Drag to reorder, swipe or − to remove. Chats and Settings stay."
                     : "Tap Edit to reorder or add tabs. Four fit on the bar; New Chat floats beside it.")
            }
            // Hidden tabs only appear while editing, like the Messages/Music tab editors.
            if editMode?.wrappedValue.isEditing == true {
                Section {
                    let missing = AppModel.AppTab.allCases.filter { !layout.contains($0) }
                    if missing.isEmpty { Text("Everything is on the bar.").foregroundStyle(.secondary).font(.footnote) }
                    ForEach(missing, id: \.self) { tab in
                        Button { var l = layout; l.set(tab, enabled: true); layoutRaw = l.encoded } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill").foregroundStyle(layout.isFull ? .gray : .green)
                                Label(tab.title, systemImage: tab.symbol)
                            }
                        }
                        .tint(.primary)
                        .disabled(layout.isFull)
                    }
                } header: { Text("Not on the bar") } footer: {
                    if layout.isFull { Text("Remove one to add another.") }
                }
            }
            if let rt = model.runtime, !rt.profiles.isEmpty {
                Section {
                    ForEach(rt.profiles) { p in
                        BotColorRow(profile: p.name, label: p.label)
                    }
                } header: { Text("Bot colors") } footer: { Text("Shown in chat headers, the Bots list and each bot's Live Activity. Stored on this device.") }
            }
            Section {
                Toggle("Show tool calls", isOn: $showToolCalls)
                Toggle("Show reasoning", isOn: $showReasoning)
                Toggle("Show tokens per second", isOn: $showTurnStats)
                Toggle("Show system notes", isOn: $showSystemNotes)
            } header: { Text("Chat") } footer: {
                Text("Hidden rows are still received and kept; this only changes what the transcript draws. Approval cards are always shown.")
            }
            Section {
                Button("Clear chat list cache") { SessionCache.clearAll() }
                Button("Reset to default") { layoutRaw = ""; scheme = "system"; showToolCalls = true; showReasoning = true; showTurnStats = true; showSystemNotes = true }
            } footer: { Text("The Chats tab remembers its last list so it opens instantly; clearing it just forces a fresh fetch.") }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            LabeledContent("Version", value: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")")
            LabeledContent("Protocol", value: "Hermes dashboard REST + JSON-RPC over /api/ws")
            Link("Hermes Agent documentation", destination: URL(string: "https://hermes-agent.nousresearch.com/docs")!)
        }
    }
}


struct BotColorRow: View {
    var profile: String
    var label: String
    @AppStorage(BotColors.storageKey) private var raw = ""
    @State private var color: Color = .accentColor

    var body: some View {
        ColorPicker(selection: $color, supportsOpacity: false) {
            HStack(spacing: 10) { BotAvatar(profile: profile, size: 26); Text(label) }
        }
        .onAppear { color = BotColors.color(for: profile) }
        .onChange(of: color) { _, c in
            BotColors.set(c, for: profile)
            raw = String(data: (try? JSONEncoder().encode(BotColors.stored())) ?? Data(), encoding: .utf8) ?? raw
        }
    }
}
