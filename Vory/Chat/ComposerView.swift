import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VoryCore

struct ComposerView: View {
    @Bindable var chat: ChatSession
    @Binding var text: String
    /// The dock's morph namespace: the text capsule (alone, not the whole stack — the steer strip
    /// and the command list come and go under it) is what an approval card morphs from.
    var namespace: Namespace.ID
    @FocusState private var focused: Bool
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var showFiles = false
    @State private var showRecorder = false
    @State private var showHistory = false
    @State private var historyCursor: Int?
    @State private var catalog: CommandsCatalog?
    @State private var dictation = DictationController()
    /// Re-created after a send: with a pending autocorrect suggestion the vertical TextField keeps
    /// drawing the old text even though the binding is empty; a fresh identity forces the redraw.
    @State private var fieldID = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Every command the gateway lists, narrowed by what follows the "/" (a bare "/" shows all).
    private var slashSuggestions: [(name: String, description: String)] {
        guard text.hasPrefix("/"), !text.contains(" "), let catalog else { return [] }
        let q = text.dropFirst().lowercased()
        return catalog.allPairs
            .filter { q.isEmpty || $0.name.lowercased().hasPrefix(q) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// The command list scrolls inside a cap: about 30 % of the screen, so with the keyboard up
    /// it stops well short of the bot header at the top.
    private var commandListCap: CGFloat { max(120, min(280, UIScreen.main.bounds.height * 0.30)) }

    var body: some View {
        VStack(spacing: 8) {
            if !slashSuggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(slashSuggestions, id: \.name) { s in
                            Button { text = "/" + s.name + " " } label: {
                                HStack(spacing: 10) {
                                    Text("/" + s.name).font(.subheadline.monospaced().weight(.medium))
                                    Text(s.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("composer.command.\(s.name)")
                            if s.name != slashSuggestions.last?.name { Divider() }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                }
                .scrollIndicators(.visible)
                .frame(maxHeight: min(commandListCap, CGFloat(slashSuggestions.count) * 38 + 8))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !chat.staged.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chat.staged) { a in
                            HStack(spacing: 4) {
                                Image(systemName: a.kind == .image ? "photo" : a.kind == .pdf ? "doc.richtext" : a.kind == .audio ? "waveform" : a.kind == .video ? "video" : "doc")
                                Text(a.name).lineLimit(1).font(.caption)
                                Button { chat.removeStaged(a.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                        }
                    }
                }
            }
            // Same shape as the Messages app: a round attach button outside the field, and one
            // thin capsule holding the text with the mic or send control inside its trailing edge.
            HStack(alignment: .bottom, spacing: 8) {
                attachMenu
                HStack(alignment: .bottom, spacing: 6) {
                    TextField("Type / for commands", text: $text, axis: .vertical)
                        .id(fieldID)
                        .lineLimit(1...6)
                        .focused($focused)
                        .accessibilityIdentifier("composer.text")
                        .textFieldStyle(.plain)
                        .padding(.leading, 14).padding(.vertical, 7)
                        .onKeyPress(.upArrow) { recallHistory(-1) ? .handled : .ignored }
                        .onKeyPress(.downArrow) { recallHistory(1) ? .handled : .ignored }
                        .onSubmit { Task { await send() } }
                        .task { catalog = await chat.commandsCatalog() }
                    trailingControl
                        .padding(.trailing, 4).padding(.bottom, 4)
                }
                .frame(minHeight: 36)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                .glassEffectID("dock", in: namespace)
            }
            if chat.isRunning, !text.isEmpty {
                HStack {
                    Text("Agent is working. Send queues the message.").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Steer now") { let t = text; text = ""; Task { await chat.steer(t) } }.font(.caption2)
                }
                .padding(.horizontal, 8)
            }
        }
        .animation(.snappy(duration: 0.25), value: slashSuggestions.map(\.name))
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 6, matching: .any(of: [.images, .videos]))
        .onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
        .fullScreenCover(isPresented: $showCamera) { CameraPicker { data, name in chat.stageAttachment(data: data, name: name, kind: .image) }.ignoresSafeArea() }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { for u in urls { importFile(u) } }
        }
        .sheet(isPresented: $showRecorder) { AudioRecorderSheet { url in importFile(url, kind: .audio) } }
        .sheet(isPresented: $showHistory) { HistorySheet(history: chat.composerHistory) { text = $0 } }
    }

    /// Mic when the field is empty, send otherwise, stop while a turn runs — one 28pt slot.
    @ViewBuilder private var trailingControl: some View {
        if chat.isRunning, text.isEmpty {
            Button { Task { await chat.stop() } } label: {
                Image(systemName: "stop.fill").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(.red, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop")
        } else if text.isEmpty && chat.staged.isEmpty {
            HoldToTalkButton(dictation: dictation) { transcript in text = transcript }
        } else {
            let disabled = text.trimmingCharacters(in: .whitespaces).isEmpty && chat.staged.isEmpty
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up").font(.body.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.accentColor), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .accessibilityLabel(chat.isRunning ? "Queue message" : "Send")
            .accessibilityIdentifier("composer.send")
        }
    }

    private var attachMenu: some View {
        Menu {
            Button { showPhotos = true } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
            Button { showCamera = true } label: { Label("Camera", systemImage: "camera") }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            Button { showFiles = true } label: { Label("Files", systemImage: "folder") }
            Button { showRecorder = true } label: { Label("Record Audio", systemImage: "waveform") }
            Button { paste() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
            Divider()
            Button { showHistory = true } label: { Label("Message History", systemImage: "clock.arrow.circlepath") }
                .disabled(chat.composerHistory.isEmpty)
        } label: {
            // Same 36pt as the single-line capsule; a glass *button* style added its own padding
            // and grew past the bar.
            Image(systemName: "plus").font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Attach")
    }

    private func send() async {
        let t = text
        text = ""
        fieldID = UUID()
        focused = true
        historyCursor = nil
        if let prefill = await chat.send(t) { text = prefill }
    }

    private func recallHistory(_ delta: Int) -> Bool {
        let h = chat.composerHistory
        guard !h.isEmpty, text.isEmpty || historyCursor != nil else { return false }
        let next = (historyCursor ?? h.count) + delta
        guard next >= 0, next < h.count else { if next >= h.count { historyCursor = nil; text = "" ; return true }; return false }
        historyCursor = next
        text = h[next]
        return true
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? (isVideo ? "mov" : "jpg")
            chat.stageAttachment(data: data, name: "\(isVideo ? "video" : "photo")-\(Int(Date().timeIntervalSince1970)).\(ext)", kind: isVideo ? .video : .image)
        }
        photoItems = []
    }

    private func importFile(_ url: URL, kind: AttachmentPreview.Kind? = nil) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { chat.banner = "Could not read \(url.lastPathComponent)"; return }
        if data.count > 200 * 1024 * 1024 { chat.banner = "\(url.lastPathComponent) is larger than 200 MB."; return }
        let type = UTType(filenameExtension: url.pathExtension)
        let k: AttachmentPreview.Kind = kind ?? (type?.conforms(to: .image) == true ? .image : type?.conforms(to: .pdf) == true ? .pdf : type?.conforms(to: .audio) == true ? .audio : type?.conforms(to: .movie) == true ? .video : .file)
        chat.stageAttachment(data: data, name: url.lastPathComponent, kind: k)
    }

    private func paste() {
        let pb = UIPasteboard.general
        if let img = pb.image, let data = img.jpegData(compressionQuality: 0.9) {
            chat.stageAttachment(data: data, name: "pasted-\(Int(Date().timeIntervalSince1970)).jpg", kind: .image)
        } else if let s = pb.string {
            text += s
        } else if let items = pb.items.first, let (type, value) = items.first, let data = value as? Data {
            let ext = UTType(type)?.preferredFilenameExtension ?? "bin"
            chat.stageAttachment(data: data, name: "pasted.\(ext)", kind: .file)
        } else {
            chat.banner = "Nothing to paste."
        }
    }
}

struct HistorySheet: View {
    var history: [String]
    var pick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(Array(history.reversed().enumerated()), id: \.offset) { _, h in
                Button { pick(h); dismiss() } label: { Text(h).lineLimit(3) }
            }
            .navigationTitle("Message History")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
