import SwiftUI
import VoryCore

/// Our own tab bar, drawn to the system Liquid Glass tab bar's measurements: a glass capsule of
/// equal-width tabs (icon over a 10 pt label, a glass pill under the selected one) and a detached
/// glass compose circle to its right. The system TabView cannot draw this on the current iOS
/// (a search-role tab renders inline), so the tab pages sit in a ZStack behind it instead.
///
/// Sizes come from a UITabBar dump on iOS 27 / iPhone 17 Pro: capsule 62 pt tall with 4 pt inset
/// around 54 pt tab slots, 21 pt side margins, bottom edge 21 pt above the screen edge (13 pt
/// into the home-indicator area), compose circle 48 pt, centred on the capsule.
struct VoryTabBar: View {
    @Environment(AppModel.self) private var model
    var tabs: [AppModel.AppTab]
    var compose: () -> Void

    /// Where the finger is along the capsule while it drags the pill; nil when not dragging.
    @State private var dragX: CGFloat?
    @State private var pressStart: Date?

    private let slotHeight: CGFloat = 54
    private let inset: CGFloat = 4
    private let sideMargin: CGFloat = 21
    private let circleSize: CGFloat = 48
    private let circleGap: CGFloat = 12
    private let bottomMargin: CGFloat = 21

    var body: some View {
        GlassEffectContainer(spacing: circleGap) {
            HStack(spacing: circleGap) {
                capsule
                Button(action: compose) {
                    Image(systemName: "square.and.pencil").font(.system(size: 20, weight: .medium))
                        .frame(width: circleSize, height: circleSize)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(model.runtime == nil)
                .accessibilityLabel("New Chat")
                .accessibilityIdentifier("chats.new")
            }
        }
        .padding(.horizontal, sideMargin)
        .padding(.bottom, bottomMargin)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var capsule: some View {
        GeometryReader { geo in
            let slotWidth = max(1, (geo.size.width - inset * 2) / CGFloat(max(1, tabs.count)))
            let selectedIndex = CGFloat(tabs.firstIndex(of: model.selectedTab) ?? 0)
            let dragging = dragX != nil
            let pillX: CGFloat = {
                guard let x = dragX else { return inset + selectedIndex * slotWidth }
                return min(max(inset, x - slotWidth / 2), geo.size.width - inset - slotWidth)
            }()
            ZStack(alignment: .leading) {
                // The selection pill: sits under the selected slot, or wherever the finger holds it.
                Capsule().fill(Color.primary.opacity(dragging ? 0.14 : 0.09))
                    .frame(width: slotWidth, height: slotHeight)
                    .scaleEffect(dragging ? 1.06 : 1)
                    .offset(x: pillX, y: inset)
                    .animation(dragging ? .interactiveSpring(response: 0.18) : .snappy(duration: 0.3), value: pillX)
                    .animation(.snappy(duration: 0.2), value: dragging)
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        slot(tab).frame(width: slotWidth, height: slotHeight)
                    }
                }
                .padding(inset)
            }
            .contentShape(Capsule())
            .gesture(barGesture(slotWidth: slotWidth))
        }
        .frame(height: slotHeight + inset * 2)
        .glassEffect(.regular, in: .capsule)
    }

    /// One tab: icon over its label, like the system bar. Taps and drags are handled by the
    /// capsule's gesture, so this is a plain view with the button's accessibility.
    @ViewBuilder private func slot(_ tab: AppModel.AppTab) -> some View {
        let selected = model.selectedTab == tab
        VStack(spacing: 2) {
            icon(for: tab).frame(height: 28)
            Text(tab.title).font(.system(size: 10, weight: selected ? .semibold : .medium))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.top, 4).padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(selected ? Color.accentColor : Color.primary)
        .animation(.snappy(duration: 0.2), value: selected)
        .overlay(alignment: .top) {
            if let b = badge(for: tab) { b.offset(x: 14, y: 0) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction { select(tab) }
    }

    /// A press moves the pill under the finger once it is held for a moment or slides sideways;
    /// the page switches as the pill passes each tab. A quick press is a tap on that tab.
    private func barGesture(slotWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                if pressStart == nil { pressStart = Date() }
                let held = Date().timeIntervalSince(pressStart ?? Date()) > 0.22
                let slid = abs(v.translation.width) > 8
                guard dragX != nil || held || slid else { return }
                if dragX == nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                dragX = v.location.x
                if let tab = tab(at: v.location.x, slotWidth: slotWidth), tab != model.selectedTab {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy(duration: 0.28)) { model.selectedTab = tab }
                }
            }
            .onEnded { v in
                if dragX == nil, let tab = tab(at: v.location.x, slotWidth: slotWidth) { select(tab) }
                dragX = nil
                pressStart = nil
            }
    }

    private func tab(at x: CGFloat, slotWidth: CGFloat) -> AppModel.AppTab? {
        let i = Int((x - inset) / slotWidth)
        return tabs.indices.contains(i) ? tabs[i] : (x < inset ? tabs.first : tabs.last)
    }

    private func select(_ tab: AppModel.AppTab) {
        withAnimation(.snappy(duration: 0.28)) { model.selectedTab = tab }
    }

    @ViewBuilder private func icon(for tab: AppModel.AppTab) -> some View {
        if tab == .bots {
            VoryOutlineIcon().frame(width: 28, height: 24)
        } else {
            Image(systemName: tab.symbol).font(.system(size: 21, weight: .medium))
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
