import SwiftUI
import UIKit
import VoryCore

/// Last known session list per gateway + profile, so the Chats tab draws instantly on launch
/// and refreshes behind it. Small JSON in UserDefaults; Settings › Appearance can clear it.
enum SessionCache {
    static let prefix = "sessions.cache."

    static func key(connection: UUID, profile: String?) -> String { prefix + connection.uuidString + "." + (profile ?? "-") }

    static func load(connection: UUID, profile: String?) -> [StoredSession] {
        guard let data = UserDefaults.standard.data(forKey: key(connection: connection, profile: profile)) else { return [] }
        return (try? JSONDecoder().decode([StoredSession].self, from: data)) ?? []
    }

    static func save(_ sessions: [StoredSession], connection: UUID, profile: String?) {
        if let data = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(data, forKey: key(connection: connection, profile: profile)) }
    }

    static func clearAll() {
        let d = UserDefaults.standard
        for k in d.dictionaryRepresentation().keys where k.hasPrefix(prefix) { d.removeObject(forKey: k) }
    }

    static var approximateBytes: Int {
        let d = UserDefaults.standard
        return d.dictionaryRepresentation().filter { $0.key.hasPrefix(prefix) }.values.compactMap { ($0 as? Data)?.count }.reduce(0, +)
    }
}

/// A bot avatar rendered to a UIImage, for places SwiftUI cannot draw a view — menu item icons.
enum BotAvatarImage {
    @MainActor static func make(profile: String, size: CGFloat = 28) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        if BotAvatarStore.choice(for: profile) == .photo, let photo = BotAvatarStore.photo(for: profile) {
            return renderer.image { ctx in
                ctx.cgContext.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size)); ctx.cgContext.clip()
                photo.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            }.withRenderingMode(.alwaysOriginal)
        }
        // The studio bot itself, painted (glass cannot render offscreen), at 3x for the menu.
        let spec = BotAvatarStore.choice(for: profile).spec(hex: BotColors.hex(for: profile))
        let r = ImageRenderer(content: BotFaceView(spec: spec, size: size, active: false, drawn: true))
        r.scale = 3
        r.isOpaque = false
        return (r.uiImage ?? renderer.image { _ in }).withRenderingMode(.alwaysOriginal)
    }
}

/// Floating glass "↓" that appears once the transcript is scrolled away from the bottom.
struct JumpToBottomButton: View {
    var visible: Bool
    var action: () -> Void
    var body: some View {
        if visible {
            Button(action: action) {
                Image(systemName: "chevron.down").font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to latest")
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// The whole message as plain, selectable text — for copying just a part of it.
struct SelectTextSheet: View {
    var text: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            .navigationTitle("Select Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { UIPasteboard.general.string = text } label: { Label("Copy all", systemImage: "doc.on.doc") } }
            }
        }
    }
}
