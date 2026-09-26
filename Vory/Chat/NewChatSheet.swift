import SwiftUI
import VoryCore

/// Compose, the way Messages does it: a To: field that takes bots, the matching bots listed as
/// cards underneath, and the first message typed at the bottom. One bot starts a chat with it;
/// more than one starts a group chat with all of them.
struct NewChatSheet: View {
    enum Start {
        case chat(profile: String, text: String)
        case group(room: Room, text: String)
    }
    var runtime: GatewayRuntime
    var onStart: (Start) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var chosen: [ProfileInfo] = []
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Field?
    enum Field { case to, message }

    private var candidates: [ProfileInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return runtime.profiles.filter { p in
            !chosen.contains(where: { $0.name == p.name }) &&
            (q.isEmpty || p.label.lowercased().contains(q) || p.name.lowercased().contains(q))
        }
    }
    private var canSend: Bool { !chosen.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(chosen.count > 1 ? "New Group Chat" : "New Message").font(.headline)
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold))
                            .frame(width: 40, height: 40).glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Close")
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            // To: the chosen bots as chips, then the search text.
            HStack(alignment: .center, spacing: 8) {
                Text("To:").foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 6) {
                        ForEach(chosen) { p in
                            HStack(spacing: 5) {
                                BotAvatar(profile: p.name, size: 20)
                                Text(p.label).font(.subheadline).lineLimit(1).fixedSize()
                            }
                            .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15), in: .capsule)
                            .onTapGesture { remove(p) }
                            .accessibilityLabel("\(p.label), tap to remove")
                        }
                        TextField(chosen.isEmpty ? "Bot name" : "", text: $query)
                            .focused($focus, equals: .to)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .frame(minWidth: 60, maxWidth: .infinity)
                            .onSubmit { if let first = candidates.first { add(first) } }
                            .onKeyPress(.delete) { if query.isEmpty, let last = chosen.last { remove(last); return .handled }; return .ignored }
                  }
                }
                .frame(height: 30)
                .defaultScrollAnchor(.trailing)
                Button { focus = .to } label: {
                    Image(systemName: "plus").font(.body.weight(.semibold))
                        .frame(width: 32, height: 32).glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain).accessibilityLabel("Add a bot")
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .padding(.horizontal, 16)

            // The bots that match, as cards; a tap adds one to To:.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(candidates) { p in
                        Button { add(p) } label: {
                            HStack(spacing: 12) {
                                BotAvatar(profile: p.name, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(highlighted(p.label)).font(.body)
                                    Text([p.description, p.model.map { $0.split(separator: "/").last.map(String.init) ?? $0 }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 72)
                    }
                    if candidates.isEmpty, !chosen.isEmpty, query.isEmpty {
                        Text(chosen.count > 1 ? "These bots will share one group chat." : "Add another bot to make it a group chat.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 24)
                    }
                    if let error { Text(error).font(.footnote).foregroundStyle(.red).padding() }
                }
                .padding(.top, 6)
            }
            .scrollDismissesKeyboard(.interactively)

            // The first message.
            HStack(alignment: .bottom, spacing: 8) {
                HStack(alignment: .bottom, spacing: 6) {
                    TextField(chosen.isEmpty ? "Choose a bot first" : "Message", text: $text, axis: .vertical)
                        .lineLimit(1...6)
                        .focused($focus, equals: .message)
                        .padding(.leading, 14).padding(.vertical, 7)
                        .disabled(chosen.isEmpty)
                    Button { Task { await start() } } label: {
                        Image(systemName: busy ? "ellipsis" : "arrow.up").font(.body.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 28, height: 28).background(canSend ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary), in: .circle)
                    }
                    .buttonStyle(.plain).disabled(!canSend)
                    .padding(.trailing, 4).padding(.bottom, 4)
                    .accessibilityLabel("Send")
                }
                .frame(minHeight: 36)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear { focus = .to }
    }

    private func highlighted(_ label: String) -> AttributedString {
        var a = AttributedString(label)
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty, let r = a.range(of: q, options: .caseInsensitive) { a[r].font = .body.weight(.semibold); a[r].foregroundColor = .accentColor }
        return a
    }

    private func add(_ p: ProfileInfo) {
        withAnimation(.snappy) { chosen.append(p) }
        query = ""
        focus = .message
    }

    private func remove(_ p: ProfileInfo) {
        withAnimation(.snappy) { chosen.removeAll { $0.name == p.name } }
    }

    private func start() async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chosen.isEmpty, !t.isEmpty else { return }
        if chosen.count == 1 {
            onStart(.chat(profile: chosen[0].name, text: t))
            dismiss()
            return
        }
        busy = true; defer { busy = false }
        do {
            let room = try await GroupChats.create(runtime: runtime, name: chosen.map(\.label).joined(separator: ", "), profiles: chosen)
            onStart(.group(room: room, text: t))
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
