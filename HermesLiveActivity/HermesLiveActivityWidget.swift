import ActivityKit
import SwiftUI
import WidgetKit

@main
struct HermesLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        HermesTurnLiveActivity()
        AttentionWidget()
        ActivityWidget()
        ContextWidget()
    }
}

/// Lock Screen banner + Dynamic Island for a running agent turn.
struct HermesTurnLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HermesTurnAttributes.self) { context in
            LockScreenTurnView(attributes: context.attributes, state: context.state)
                // Translucent over the wallpaper rather than a flat black slab; the system
                // still guarantees legibility with its own material underneath.
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            // No centre region: the leading and trailing regions sit beside the sensor cut-out and
            // a third column there only leaves the title a few letters. Everything wide goes below.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        PhaseBadge(phase: context.state.phase, attention: context.state.needsAttention, size: 30, botHex: context.attributes.tintHex)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.displayBotName).font(.headline).lineLimit(1)
                            Text(PhaseText.headline(for: context.state)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimer(state: context.state)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing).frame(width: 52)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.sessionTitle).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(context.state.detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        StatsRow(attributes: context.attributes, state: context.state)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                }
            } compactLeading: {
                PhaseGlyph(phase: context.state.phase, attention: context.state.needsAttention, botHex: context.attributes.tintHex)
            } compactTrailing: {
                if context.state.needsAttention {
                    Text("Reply").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                } else {
                    // Ticks while the turn runs; once it ends this is the total time it took.
                    ElapsedTimer(state: context.state).font(.caption2.monospacedDigit())
                        .multilineTextAlignment(.trailing).frame(width: 40).minimumScaleFactor(0.7)
                }
            } minimal: {
                PhaseGlyph(phase: context.state.phase, attention: context.state.needsAttention, botHex: context.attributes.tintHex)
            }
            .keylineTint(context.state.needsAttention ? .orange : PhaseStyle.tint(context.state.phase, bot: context.attributes.tintHex))
        }
    }
}

// MARK: Pieces

extension HermesTurnAttributes {
    /// Bot display name; older activities (or a profile without one) fall back to the profile name.
    var displayBotName: String {
        if let n = botName, !n.isEmpty { return n }
        return profile.isEmpty ? "Hermes" : profile
    }
}

enum PhaseStyle {
    /// The bot's own colour while it works; phase colours take over for done / error / waiting.
    static func tint(_ phase: String, bot hex: String = "") -> Color {
        if !hex.isEmpty, phase == "streaming" || phase == "tool", let c = Color(hexString: hex) { return c }
        switch phase {
        case "tool": return .blue
        case "done": return .green
        case "error": return .red
        case "waiting": return .orange
        default: return .purple
        }
    }

    static func symbol(_ phase: String, attention: Bool) -> String {
        if attention { return "exclamationmark.bubble.fill" }
        switch phase {
        case "tool": return "wrench.and.screwdriver.fill"
        case "done": return "checkmark"
        case "error": return "xmark"
        default: return "ellipsis.message.fill"
        }
    }
}

extension Color {
    init?(hexString: String) {
        var s = hexString; if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

enum PhaseText {
    static func headline(for s: HermesTurnAttributes.ContentState) -> String {
        if s.needsAttention { return "Waiting for you" }
        switch s.phase {
        case "tool": return "Running a tool"
        case "done": return "Finished"
        case "error": return "Failed"
        default: return "Writing"
        }
    }
}

enum Format {
    static func tokens(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1e6) : n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }
}

/// Elapsed time that ticks while the turn runs and freezes when it ends.
struct ElapsedTimer: View {
    var state: HermesTurnAttributes.ContentState
    var body: some View {
        if let end = state.endedAt {
            Text(Duration.seconds(max(0, end.timeIntervalSince(state.startedAt))).formatted(.time(pattern: .minuteSecond)))
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
        }
    }
}

/// Small glyph for the compact/minimal island.
struct PhaseGlyph: View {
    var phase: String
    var attention: Bool
    var botHex: String = ""
    var body: some View {
        Image(systemName: PhaseStyle.symbol(phase, attention: attention))
            .foregroundStyle(attention ? .orange : PhaseStyle.tint(phase, bot: botHex))
            .symbolEffect(.pulse, isActive: !attention && (phase == "streaming" || phase == "tool"))
    }
}

/// Tinted disc with the phase glyph, used at larger sizes.
struct PhaseBadge: View {
    var phase: String
    var attention: Bool
    var size: CGFloat
    var botHex: String = ""
    var body: some View {
        let tint = attention ? Color.orange : PhaseStyle.tint(phase, bot: botHex)
        ZStack {
            Circle().fill(tint.gradient)
            Image(systemName: PhaseStyle.symbol(phase, attention: attention))
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: !attention && (phase == "streaming" || phase == "tool"))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Output tokens · context bar · model, one line, each figure labelled so the bar reads as
/// "how full the context window is" rather than a mystery progress bar.
struct StatsRow: View {
    var attributes: HermesTurnAttributes
    var state: HermesTurnAttributes.ContentState
    var body: some View {
        HStack(spacing: 12) {
            if let end = state.endedAt {
                // Once the turn is over the total time is the figure that matters; the token count
                // the companion knows at that point is often nothing.
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(Duration.seconds(max(0, end.timeIntervalSince(state.startedAt))).formatted(.time(pattern: .minuteSecond)) + " total").monospacedDigit()
                }
                .font(.caption)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "text.word.spacing")
                    Text("\(Format.tokens(state.outputTokens)) tokens").monospacedDigit()
                }
                .font(.caption)
            }
            if let pct = state.contextPercent {
                HStack(spacing: 5) {
                    Text("Context").font(.caption)
                    ProgressView(value: Double(min(max(pct, 0), 100)), total: 100)
                        .progressViewStyle(.linear)
                        .tint(pct >= 85 ? .red : pct >= 60 ? .orange : PhaseStyle.tint(state.phase, bot: attributes.tintHex))
                        .frame(width: 48)
                    Text("\(pct)%").font(.caption.monospacedDigit())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Context \(pct) percent full")
            }
            Spacer(minLength: 0)
            if !attributes.model.isEmpty {
                Text(attributes.model).font(.caption2).lineLimit(1).truncationMode(.middle).layoutPriority(-1)
            }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

struct LockScreenTurnView: View {
    var attributes: HermesTurnAttributes
    var state: HermesTurnAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                PhaseBadge(phase: state.phase, attention: state.needsAttention, size: 40, botHex: attributes.tintHex)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.displayBotName).font(.headline).lineLimit(1)
                    Text(attributes.sessionTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(state.detail).font(.subheadline).lineLimit(2)
                }
                Spacer(minLength: 4)
                // A fixed width: the ticking timer text otherwise claims the whole row and squeezes
                // the title down to a few letters.
                VStack(alignment: .trailing, spacing: 2) {
                    ElapsedTimer(state: state).font(.title3.monospacedDigit().weight(.medium)).multilineTextAlignment(.trailing).minimumScaleFactor(0.7)
                    Text(PhaseText.headline(for: state)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(width: 66, alignment: .trailing)
            }
            StatsRow(attributes: attributes, state: state)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }
}
