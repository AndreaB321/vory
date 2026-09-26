import SwiftUI
import VoryCore

/// Our own tab bar, laid out like Messages: a glass capsule of tabs (icon only, label under the
/// selected one) and a detached glass compose circle to its right. The system TabView cannot draw
/// this on the current iOS, so the tab pages sit in a ZStack behind it instead.
struct VoryTabBar: View {
    @Environment(AppModel.self) private var model
    var tabs: [AppModel.AppTab]
    var compose: () -> Void
    @Namespace private var selection

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                HStack(spacing: 2) {
                    ForEach(tabs, id: \.self) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
                Button(action: compose) {
                    Image(systemName: "square.and.pencil").font(.title3.weight(.semibold))
                        .frame(width: 54, height: 54)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(model.runtime == nil)
                .accessibilityLabel("New Chat")
                .accessibilityIdentifier("chats.new")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder private func tabButton(_ tab: AppModel.AppTab) -> some View {
        let selected = model.selectedTab == tab
        Button {
            withAnimation(.snappy(duration: 0.28)) { model.selectedTab = tab }
        } label: {
            VStack(spacing: 2) {
                icon(for: tab)
                    .frame(height: 26)
                if selected {
                    Text(tab.title).font(.caption2.weight(.semibold))
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
                }
            }
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .padding(.horizontal, selected ? 16 : 12)
            .padding(.vertical, 6)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                if selected {
                    Capsule().fill(Color.primary.opacity(0.08))
                        .matchedGeometryEffect(id: "selected", in: selection)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let b = badge(for: tab) { b.offset(x: 6, y: -4) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder private func icon(for tab: AppModel.AppTab) -> some View {
        if tab == .bots {
            VoryOutlineIcon().frame(width: 26, height: 24)
        } else {
            Image(systemName: tab.symbol).font(.title3.weight(.medium))
        }
    }

    /// Chats counts waiting cards; Settings flags a gateway that needs a restart, or a companion
    /// update waiting under Software Update.
    private func badge(for tab: AppModel.AppTab) -> CountBadge? {
        switch tab {
        case .chats:
            let n = model.runtime?.needsAttention.count ?? 0
            return n > 0 ? CountBadge(n) : nil
        case .settings:
            if model.runtime?.restartRequired != nil { return CountBadge(1) }
            return model.companionUpdateAvailable ? CountBadge(1) : nil
        default:
            return nil
        }
    }
}

/// The Vory cloud as an outline with its two eyes, tilted a little: the Bots tab's icon.
struct VoryOutlineIcon: View {
    var body: some View {
        Canvas { ctx, size in
            // The cloud is several overlapping pieces, so stroking it scribbles; instead fill it,
            // then punch out a slightly smaller cloud, which leaves a clean outline.
            let box = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            ctx.drawLayer { layer in
                layer.fill(BotFace.bodyPath("cloud", in: box, time: 0, active: false), with: .foreground)
                layer.blendMode = .destinationOut
                let inner = CGRect(x: box.midX - box.width * 0.42, y: box.midY - box.height * 0.42, width: box.width * 0.84, height: box.height * 0.84)
                layer.fill(BotFace.bodyPath("cloud", in: inner, time: 0, active: false), with: .color(.black))
            }
            let s = min(size.width, size.height)
            let cy = size.height * 0.60, dx = s * 0.13
            for x in [size.width / 2 - dx, size.width / 2 + dx] {
                ctx.fill(Path(roundedRect: CGRect(x: x - s * 0.05, y: cy - s * 0.11, width: s * 0.10, height: s * 0.22), cornerRadius: s * 0.05), with: .foreground)
            }
        }
        .rotationEffect(.degrees(-10))
        .accessibilityHidden(true)
    }
}

/// Hides the custom tab bar while this view is on screen. On the Chats tab the list's own
/// navigation path hides the bar the instant a push begins and shows it the instant a pop
/// begins, so this only counts on the other tabs.
struct HidesTabBar: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var counted = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !counted, model.selectedTab != .chats else { return }
                counted = true
                model.tabBarHiders += 1
            }
            .onDisappear {
                guard counted else { return }
                counted = false
                model.tabBarHiders = max(0, model.tabBarHiders - 1)
            }
    }
}

extension View {
    func hidesTabBar() -> some View { modifier(HidesTabBar()) }
}
