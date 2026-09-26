import SwiftUI
import VoryCore

/// Our own tab bar, drawn to the system Liquid Glass tab bar on iOS 27: a glass capsule of
/// equal-width, icon-only tabs, a clear glass lens over the selected one (its label shows under
/// the icon only there), and a detached glass compose circle the full height of the capsule.
/// The system TabView cannot draw this on the current iOS (a search-role tab renders inline),
/// so the tab pages sit in a ZStack behind it instead.
///
/// Measurements from a UITabBar dump on iOS 27 / iPhone 17 Pro: capsule 62 pt with 4 pt inset
/// around 54 pt slots, 21 pt side margins, the bar group 49 pt above the home-indicator area with
/// the capsule overflowing 13 pt into it.
struct VoryTabBar: View {
    @Environment(AppModel.self) private var model
    var tabs: [AppModel.AppTab]
    var compose: () -> Void

    /// Where the finger is along the capsule while it drags the lens; nil when not dragging.
    @State private var dragX: CGFloat?
    @State private var pressStart: Date?

    private let barHeight: CGFloat = 62
    private let inset: CGFloat = 4
    private let sideMargin: CGFloat = 21
    private let circleGap: CGFloat = 12
    /// How far the capsule hangs into the home-indicator area.
    private let overhang: CGFloat = 13
    /// What the bar reserves above the home-indicator area (the system bar group's 49 pt); the
    /// capsule is drawn overflowing below it.
    static let reservedHeight: CGFloat = 49

    var body: some View {
        GlassEffectContainer(spacing: circleGap) {
            HStack(spacing: circleGap) {
                capsule
                Button(action: compose) {
                    // The glyph's ink sits about a point up and right of its layout box (measured
                    // from its alpha bounds), so centre the ink rather than the box.
                    Image(systemName: "square.and.pencil").font(.system(size: 24, weight: .medium))
                        .offset(x: -1, y: 1)
                        .frame(width: barHeight, height: barHeight)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(model.runtime == nil)
                .accessibilityLabel("New Chat")
                .accessibilityIdentifier("chats.new")
            }
        }
        .padding(.horizontal, sideMargin)
        // Reserve only the part above the home-indicator area, like the system bar group; the
        // capsule itself is drawn overflowing into it.
        .frame(height: Self.reservedHeight, alignment: .top)
    }

    private var capsule: some View {
        GeometryReader { geo in
            let slotWidth = max(1, (geo.size.width - inset * 2) / CGFloat(max(1, tabs.count)))
            let slotHeight = geo.size.height - inset * 2
            let selectedIndex = CGFloat(tabs.firstIndex(of: model.selectedTab) ?? 0)
            let dragging = dragX != nil
            let lensX: CGFloat = {
                guard let x = dragX else { return inset + selectedIndex * slotWidth }
                return min(max(inset, x - slotWidth / 2), geo.size.width - inset - slotWidth)
            }()
            ZStack(alignment: .topLeading) {
                // The lens: clear glass under the selected slot, or wherever the finger holds it
                // (grown a little while lifted). Under the icons so they stay crisp.
                GlassEffectContainer {
                    Capsule().fill(.clear)
                        .frame(width: slotWidth, height: slotHeight)
                        .glassEffect(.clear.interactive(), in: .capsule)
                }
                .scaleEffect(dragging ? 1.12 : 1)
                .offset(x: lensX, y: inset)
                .animation(dragging ? .interactiveSpring(response: 0.18) : .snappy(duration: 0.32), value: lensX)
                .animation(.snappy(duration: 0.22), value: dragging)
                .allowsHitTesting(false)
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        slot(tab, dragging: dragging).frame(width: slotWidth, height: slotHeight)
                    }
                }
                .padding(inset)
            }
            .contentShape(Capsule())
            .gesture(barGesture(slotWidth: slotWidth))
        }
        .frame(height: barHeight)
        .glassEffect(.regular, in: .capsule)
    }

    /// One tab: a large icon on its own, or a smaller icon over its label when it is selected
    /// (no labels at all while the lens is being dragged, like the system bar).
    @ViewBuilder private func slot(_ tab: AppModel.AppTab, dragging: Bool) -> some View {
        let selected = model.selectedTab == tab
        let labelled = selected && !dragging
        VStack(spacing: 2) {
            icon(for: tab, size: labelled ? 22 : 27)
                .frame(height: labelled ? 26 : 32)
            if labelled {
                Text(tab.title).font(.system(size: 10, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(selected ? Color.accentColor : Color.primary)
        .animation(.snappy(duration: 0.24), value: labelled)
        .overlay(alignment: .top) {
            if let b = badge(for: tab) { b.offset(x: 14, y: 4) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction { select(tab) }
    }

    /// A press moves the lens under the finger once it is held for a moment or slides sideways;
    /// the page switches as the lens passes each tab. A quick press is a tap on that tab.
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

    @ViewBuilder private func icon(for tab: AppModel.AppTab, size: CGFloat) -> some View {
        if tab == .bots {
            VoryOutlineIcon().frame(width: size * 1.3, height: size * 1.1)
        } else {
            Image(systemName: tab.symbol).font(.system(size: size, weight: .medium))
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
