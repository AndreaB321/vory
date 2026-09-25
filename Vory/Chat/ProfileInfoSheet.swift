import SwiftUI
import VoryCore

/// Tapping the title pill in a chat opens this: what the chat is, one row into the bot's profile
/// card, and one row into its instructions. Both of those edit through the dashboard API
/// (`PUT /api/profiles/{name}/description|model|soul`) and come back here on Back.
struct ProfileInfoSheet: View {
    var chat: ChatSession?
    var profileName: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Opens tall; the medium detent stays reachable by pulling it down.
    @State private var detent: PresentationDetent = .large
    @State private var titleDraft = ""
    @State private var titleStatus: String?

    private var profile: ProfileInfo? { model.runtime?.profiles.first { $0.name == profileName } }

    var body: some View {
        NavigationStack {
            List {
                if let chat {
                    Section {
                        HStack {
                            Text("Title")
                            TextField("Chat title", text: $titleDraft)
                                .multilineTextAlignment(.trailing).submitLabel(.done)
                                .onSubmit { Task { await saveTitle(chat) } }
                            if titleDraft != chat.title, !titleDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                                Button { Task { await saveTitle(chat) } } label: { Image(systemName: "checkmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.tint)
                            }
                        }
                        Menu { ModelMenuContent(chat: chat) } label: {
                            LabeledContent("Model", value: chat.modelName.isEmpty ? "Choose…" : (chat.modelName.split(separator: "/").last.map(String.init) ?? chat.modelName))
                        }
                        .tint(.primary)
                        if let u = chat.usage, let pct = u.computedContextPercent {
                            LabeledContent("Context", value: "\(pct)% of \((u.contextMax ?? 0).formatted())")
                        }
                        if let e = chat.info?.reasoningEffort, !e.isEmpty { LabeledContent("Reasoning", value: e) }
                    } header: { Text("This chat") } footer: { if let titleStatus { Text(titleStatus) } }
                }
                Section {
                    NavigationLink { ProfileCardView(profileName: profileName) } label: {
                        HStack(spacing: 12) {
                            BotAvatar(profile: profileName, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile?.label ?? profileName).font(.body.weight(.medium))
                                Text([profile?.description, profile?.model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                } header: { Text("Profile") }
                Section {
                    NavigationLink { SoulEditorView(profileName: profileName) } label: {
                        Label("Instructions (SOUL.md)", systemImage: "doc.text")
                    }
                } footer: { Text("The bot's standing instructions. Edits are written to the gateway when you tap the check mark.") }
            }
            .navigationTitle(chat?.title ?? (profile?.label ?? profileName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { titleDraft = chat?.title ?? "" }
        }
        .presentationDetents([.medium, .large], selection: $detent)
    }

    /// `PATCH /api/sessions/{id}` with `title`; the gateway echoes the stored title back.
    private func saveTitle(_ chat: ChatSession) async {
        guard let rt = model.runtime else { return }
        let t = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t != chat.title else { return }
        do {
            var body: [String: JSONValue] = ["title": .string(t)]
            if let p = rt.selectedProfile { body["profile"] = .string(p) }
            let r: JSONValue = try await rt.api.send("PATCH", "/api/sessions/\(chat.storedID)", json: .object(body))
            chat.title = r["title"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? t
            titleStatus = "Title saved."
            NotificationCenter.default.post(name: .hermesSessionsChanged, object: nil)
        } catch { titleStatus = error.localizedDescription }
    }
}

/// The bot's card: colour, description and default model, each saved as it is changed.
struct ProfileCardView: View {
    var profileName: String
    @Environment(AppModel.self) private var model
    @AppStorage(BotColors.storageKey) private var colorsRaw = ""
    @State private var description = ""
    @State private var tint: Color = .accentColor
    @State private var avatar: BotAvatarChoice = .default
    @AppStorage(BotAvatarStore.storageKey) private var avatarsRaw = ""
    @State private var options: ModelOptionsResult?
    @State private var status: String?
    @State private var loaded = false

    private var rt: GatewayRuntime? { model.runtime }
    private var profile: ProfileInfo? { rt?.profiles.first { $0.name == profileName } }
    private var modelLabel: String {
        let s = [profile?.provider, profile?.model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "/")
        return s.isEmpty ? "not set" : s
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    BotAvatar(profile: profileName, size: 110, active: true)
                    Text(profile?.label ?? profileName).font(.title2.weight(.semibold))
                    if let m = profile?.model, !m.isEmpty { Text(m).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            Section {
                CreatorStudio(profile: profileName, choice: $avatar)
                    .onChange(of: avatar) { _, c in
                        BotAvatarStore.set(c, for: profileName)
                        avatarsRaw = String(data: (try? JSONEncoder().encode(BotAvatarStore.stored())) ?? Data(), encoding: .utf8) ?? avatarsRaw
                    }
            } header: { Text("Creator Studio") } footer: { Text("How this bot looks everywhere: chats, the Island, notifications. Stored on this device.") }
            Section {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(1...4)
                    .onSubmit { Task { await saveDescription() } }
                Button("Save description") { Task { await saveDescription() } }
                    .disabled(description == (profile?.description ?? ""))
            } header: { Text("Profile") } footer: { Text("The description is what other Hermes surfaces show for this bot (and what kanban routing reads).") }
            Section {
                if let o = options {
                    Menu { modelMenuItems(o.providers) } label: { LabeledContent("Default model", value: modelLabel) }
                } else { ProgressView() }
            } header: { Text("Model") } footer: { Text("Writes this profile's config.yaml. Running chats keep their own model.") }
            if let p = profile?.path { Section { Text(p).font(.caption.monospaced()).foregroundStyle(.tertiary) } header: { Text("Home") } }
            if let status { Section { Text(status).font(.footnote).foregroundStyle(status.hasPrefix("Saved") ? Color.secondary : Color.red) } }
        }
        .navigationTitle(profile?.label ?? profileName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded else { return }
            loaded = true
            description = profile?.description ?? ""
            tint = BotColors.color(for: profileName)
            avatar = BotAvatarStore.choice(for: profileName)
            if let rt { options = try? await rt.api.get("/api/model/options", profile: profileName) }
        }
    }

    @ViewBuilder private func modelMenuItems(_ providers: [ModelProvider]) -> some View {
        ForEach(providers) { p in
            Section(p.name) {
                ForEach(p.models ?? [], id: \.self) { m in
                    Button(m) { Task { await saveModel(provider: p.slug, model: m) } }
                }
            }
        }
    }

    private func saveDescription() async {
        guard let rt else { return }
        do {
            let _: JSONValue = try await rt.api.send("PUT", "/api/profiles/\(profileName)/description", json: .object(["description": .string(description)]))
            await rt.loadProfiles()
            status = "Saved description."
        } catch { status = error.localizedDescription }
    }

    private func saveModel(provider: String, model: String) async {
        guard let rt else { return }
        do {
            let _: JSONValue = try await rt.api.send("PUT", "/api/profiles/\(profileName)/model", json: .object(["provider": .string(provider), "model": .string(model)]))
            await rt.loadProfiles()
            status = "Saved model \(model)."
        } catch { status = error.localizedDescription }
    }
}

/// Full-screen editor for SOUL.md; the check mark writes it back.
struct SoulEditorView: View {
    var profileName: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var original = ""
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading { ProgressView("Loading SOUL.md…") }
            else {
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty { Text("Write the bot's instructions in Markdown…").foregroundStyle(.tertiary).padding(.horizontal, 13).padding(.top, 8).allowsHitTesting(false) }
                    }
            }
        }
        .navigationTitle("SOUL.md")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { Task { await save() } } label: { if saving { ProgressView() } else { Image(systemName: "checkmark") } }
                    .disabled(saving || text == original)
                    .accessibilityLabel("Save instructions")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let error { Text(error).font(.footnote).foregroundStyle(.red).padding(8) }
        }
        .task {
            guard let rt = model.runtime else { loading = false; return }
            do {
                let r: JSONValue = try await rt.api.get("/api/profiles/\(profileName)/soul")
                text = r["content"]?.stringValue ?? ""; original = text
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }

    private func save() async {
        guard let rt = model.runtime else { return }
        saving = true; defer { saving = false }
        do {
            let _: JSONValue = try await rt.api.send("PUT", "/api/profiles/\(profileName)/soul", json: .object(["content": .string(text)]))
            original = text
            error = nil
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
