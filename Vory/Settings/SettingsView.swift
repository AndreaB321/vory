import SwiftUI
import VoryCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    /// The first-run "set up notifications" card: shown once, until it is tapped or dismissed.
    @AppStorage("notificationsSetupCardDone") private var setupCardDone = false
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
            Row(id: "update", title: "Software Update", symbol: "arrow.down.circle", color: .gray, destination: AnyView(SoftwareUpdateView())),
            Row(id: "about", title: "About", symbol: "info.circle", color: .blue, destination: AnyView(AboutView())),
        ]
    }

    private func filtered(_ rows: [Row]) -> [Row] { search.isEmpty ? rows : rows.filter { $0.title.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty, !setupCardDone, model.runtime != nil, model.push.registeredAt == nil {
                    Section {
                        NavigationLink { SetupWizardHost() } label: {
                            HStack(spacing: 12) {
                                BotFaceView(spec: BotLookSpec(shape: "cloud", eyes: "classic", hex: "#3B7BFF"), size: 46, active: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set up notifications").font(.headline)
                                    Text("Replies, approvals and Live Activities while Vory is closed.").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { withAnimation(.snappy) { setupCardDone = true } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Dismiss")
                            }
                            .padding(.vertical, 4)
                        }
                        .simultaneousGesture(TapGesture().onEnded { setupCardDone = true })
                    }
                }
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
                        NavigationLink { row.destination.navigationTitle(row.title) } label: {
                            HStack {
                                SettingsLabel(row.title, row.symbol, row.color)
                                Spacer(minLength: 8)
                                if row.id == "update", model.companionUpdateAvailable { CountBadge(1) }
                            }
                        }
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
                NavigationLink {
                    BackgroundNotificationsView()
                } label: {
                    Label("Background Notifications", systemImage: "server.rack")
                }
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

    @AppStorage(ChatStyle.headerShowsTitle) private var headerShowsTitle = false
    var body: some View {
        List {
            Section {
                Picker("Chat header shows", selection: $headerShowsTitle) {
                    Text("Bot name").tag(false)
                    Text("Chat title").tag(true)
                }
            } footer: { Text("What the pill under the bot leads with in a chat; the other is shown beneath it while the bot is idle.") }
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
    @Environment(AppModel.self) private var model
    @State private var taps = 0
    @State private var lastTap = Date.distantPast
    @State private var raining = false
    @State private var lifted = false
    @State private var relieved = false

    private var appVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")" }
    static let voryBot = BotLookSpec(shape: "cloud", eyes: "classic", hex: "#3B7BFF")

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    ZStack(alignment: .top) {
                        if raining {
                            // Falls from under the cloud, not out of its middle.
                            RainOverlay().frame(width: 140, height: 64).offset(y: 118 - 30).allowsHitTesting(false).transition(.opacity)
                        }
                        BotFaceView(spec: Self.voryBot, size: 132, active: true, gaze: CGPoint(x: 0, y: raining ? 1 : 0))
                            .offset(y: lifted ? -30 : 0)
                        if relieved {
                            SpeechBubble(text: "Ahhhh…that's better.")
                                .offset(y: -46)
                                .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(height: 140, alignment: .top)
                    .padding(.top, 50)
                    .contentShape(Rectangle())
                    .onTapGesture { tapped() }
                    Text("Vory").font(.title.weight(.bold))
                    Text("Version \(appVersion)").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            Section {
                LabeledContent("Companion plugin", value: model.companionInstalledVersion.map { "v\($0)" } ?? "not installed")
                LabeledContent("Ships with this build", value: "v\(PushSetupModel.bundledPluginVersion)")
                LabeledContent("Push relay", value: PushRelay.isConfigured ? "configured" : "none")
                LabeledContent("Live Activity", value: appVersion)
                LabeledContent("Notification extensions", value: appVersion)
            } header: { Text("Installed") } footer: {
                Text("What Vory puts on your gateway and inside this app. Updates arrive under Software Update.")
            }
            Section {
                Link("Hermes Agent documentation", destination: URL(string: "https://hermes-agent.nousresearch.com/docs")!)
            }
        }
        .animation(.smooth, value: raining)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: lifted)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: relieved)
        .task { await model.refreshCompanionUpdateFlag() }
    }

    /// Five quick taps on the cloud and it rains for five seconds (and it watches the rain).
    private func tapped() {
        let now = Date()
        taps = now.timeIntervalSince(lastTap) < 1.5 ? taps + 1 : 1
        lastTap = now
        guard taps >= 5, !raining, !lifted else { return }
        taps = 0
        lifted = true
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            raining = true
            try? await Task.sleep(for: .seconds(5))
            raining = false
            try? await Task.sleep(for: .milliseconds(350))
            lifted = false
            try? await Task.sleep(for: .milliseconds(500))
            relieved = true
            try? await Task.sleep(for: .seconds(3))
            relieved = false
        }
    }
}

/// A little speech bubble whose tail (bottom centre) is part of the same shape, pointing down at
/// whoever said it.
struct SpeechBubble: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .padding(.bottom, 8)
            .background(Color(uiColor: .secondarySystemFill), in: SpeechBubbleShape())
            .fixedSize()
    }
}

struct SpeechBubbleShape: Shape {
    func path(in r: CGRect) -> Path {
        let body = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height - 8)
        var p = Path(roundedRect: body, cornerRadius: 16, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: r.midX - 9, y: body.maxY - 1))
        tail.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.midX - 4, y: body.maxY + 3))
        tail.addQuadCurve(to: CGPoint(x: r.midX + 9, y: body.maxY - 1), control: CGPoint(x: r.midX + 4, y: body.maxY + 3))
        tail.closeSubpath()
        p.addPath(tail)
        return p
    }
}

/// Rain drops falling from the cloud: a couple of dozen streaks with their own speed and phase.
struct RainOverlay: View {
    struct Drop { var x: Double; var speed: Double; var phase: Double; var len: Double }
    private static let drops: [Drop] = (0..<28).map { (i: Int) -> Drop in
        let col: Double = Double(i % 9) / 9.0
        let jitter: Double = Double((i * 7) % 5) * 0.012
        let speed: Double = 0.9 + Double((i * 13) % 7) / 7.0 * 0.8
        let phase: Double = Double((i * 31) % 100) / 100.0
        let len: Double = 10.0 + Double((i * 5) % 4) * 4.0
        return Drop(x: 0.18 + col * 0.64 + jitter, speed: speed, phase: phase, len: len)
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for d in Self.drops {
                    let u = ((t * d.speed) + d.phase).truncatingRemainder(dividingBy: 1)
                    let y = u * size.height
                    let x = size.width * d.x
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - 2, y: y + d.len))
                    ctx.stroke(p, with: .color(Color(red: 0.45, green: 0.7, blue: 1).opacity(0.85 * (1 - u * 0.6))), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }
}

/// Settings › Software Update: the companion plugin on the gateway, updated in place like an iOS update.
struct SoftwareUpdateView: View {
    @Environment(AppModel.self) private var model
    @State private var setup = PushSetupModel()

    var body: some View {
        List {
            if let rt = model.runtime {
                Section {
                    if setup.companionCheckedAt == nil {
                        Label { Text("Checking for updates…") } icon: { ProgressView() }.foregroundStyle(.secondary)
                    } else if setup.installedVersion == nil {
                        Label("The companion is not installed yet. Set up notifications first.", systemImage: "info.circle").foregroundStyle(.secondary)
                    } else if setup.updateAvailable || setup.updating || setup.showUpdateConsole || setup.updateOutcome != nil {
                        CompanionUpdateRows(setup: setup, runtime: rt)
                    } else {
                        VStack(spacing: 8) {
                            BotFaceView(spec: AboutView.voryBot, size: 56, active: false)
                            Text("Vory Companion \(PushSetupModel.bundledPluginVersion)").font(.headline)
                            Text("Your gateway is up to date.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                } header: { sectionHeader("Vory Companion") } footer: {
                    Text("The plugin on your gateway that delivers notifications and Live Activity updates. Installs in place; no restart unless it says so.")
                }
                Section {
                    LabeledContent("On the gateway", value: setup.installedVersion.map { "v\($0)" } ?? "—")
                    if let hb = setup.heartbeat { LabeledContent("Running", value: "v\(hb.version)") }
                    LabeledContent("This build ships", value: "v\(PushSetupModel.bundledPluginVersion)")
                    Button { Task { await setup.checkCompanion(runtime: rt) } } label: {
                        Label("Check again\(setup.companionCheckedAt.map { " (last \($0.formatted(date: .omitted, time: .shortened)))" } ?? "")", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(setup.checkingCompanion)
                }
            } else {
                Text("Connect a gateway first.").foregroundStyle(.secondary)
            }
        }
        .listSectionSpacing(28)
        .animation(.smooth, value: setup.updateOutcome == nil)
        .task { if let rt = model.runtime { await setup.prepare(runtime: rt) } }
        .refreshable { if let rt = model.runtime { await setup.checkCompanion(runtime: rt) } }
        .onChange(of: setup.companionCheckedAt) { _, _ in
            model.companionUpdateAvailable = setup.updateAvailable
            model.companionInstalledVersion = setup.installedVersion
        }
    }
}

/// The notifications wizard, opened straight from the first-run card in Settings.
struct SetupWizardHost: View {
    @Environment(AppModel.self) private var model
    @State private var setup = PushSetupModel()
    var body: some View {
        PushSetupView(setup: setup)
            .task { if let rt = model.runtime { await setup.prepare(runtime: rt) } }
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


/// The red count circle the tab bar uses, for rows on the way to whatever needs attention.
struct CountBadge: View {
    var count: Int
    init(_ count: Int) { self.count = count }
    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold)).monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, count > 9 ? 6 : 0)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(.red))
            .accessibilityLabel("\(count) waiting")
    }
}
