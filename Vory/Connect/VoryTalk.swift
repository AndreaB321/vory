import SwiftUI
import VoryCore

/// Vory's speech bubble, typed out a few characters at a time whenever `text` changes (by
/// `key`). Wraps, and keeps the full text's height so the layout does not grow line by line.
struct VoryTypedBubble: View {
    var text: String
    var key: AnyHashable
    var reduceMotion = false
    var tint: Color = .primary
    var fill: Color = Color(uiColor: .secondarySystemFill)
    @State private var shown = ""

    var body: some View {
        ZStack {
            Text(text).hidden()
            Text(shown)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(tint)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .padding(.bottom, 8)
        .background(fill, in: SpeechBubbleShape())
        .frame(maxWidth: 340)
        .task(id: key) {
            if reduceMotion { shown = text; return }
            shown = ""
            for ch in text {
                guard !Task.isCancelled else { return }
                shown.append(ch)
                try? await Task.sleep(for: .milliseconds(ch == " " ? 12 : 22))
            }
        }
    }
}

/// Vory at the top of a guided screen: the glass cloud, a full turn whenever `turnKey` changes
/// (a new page or a finished step), a squint while `thinking`, and the typed bubble under it.
struct VoryGuide: View {
    var says: String
    var key: AnyHashable
    var turnKey: AnyHashable
    var thinking = false
    var done = false
    var reduceMotion = false
    var size: CGFloat = 96

    var body: some View {
        VStack(spacing: 6) {
            BotFaceView(spec: AboutView.voryBot, size: size, active: true, gaze: CGPoint(x: 0, y: 0.5),
                        mood: BotFaceView.Mood(thinking: thinking, profile: "vory-guide"))
            VoryTypedBubble(text: says, key: key, reduceMotion: reduceMotion,
                            tint: done ? .green : .primary,
                            fill: done ? Color.green.mix(with: Color(uiColor: .secondarySystemFill), by: 0.75) : Color(uiColor: .secondarySystemFill))
                .padding(.horizontal, 24)
        }
        .onChange(of: turnKey) { _, _ in BotAmbient.shared.turnFinished(profile: "vory-guide") }
    }
}
