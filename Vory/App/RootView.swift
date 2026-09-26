import SwiftUI
import VoryCore

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if !model.hasConnections {
                OnboardingView()
            } else {
                MainTabView()
            }
            if model.lock.isLocked {
                LockScreenView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: model.lock.isLocked)
    }
}

struct LockScreenView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.secondary)
                Text("Vory is locked").font(.title2.weight(.semibold))
                if let e = model.lock.lastError { Text(e).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                Button("Unlock with \(model.lock.biometryName)") { Task { await model.lock.unlock() } }
                    .buttonStyle(.glassProminent)
            }
            .padding()
        }
        .task { await model.lock.unlock() }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(TabLayout.storageKey) private var layoutRaw = ""

    var body: some View {
        let tabs = TabLayout.parse(layoutRaw).visible()
        ZStack {
            // Every page stays alive (its navigation stack, scroll position, drafts); only the
            // selected one is visible and touchable, which is what the system TabView does too.
            ForEach(tabs, id: \.self) { tab in
                content(for: tab)
                    .opacity(model.selectedTab == tab ? 1 : 0)
                    .allowsHitTesting(model.selectedTab == tab)
                    .accessibilityHidden(model.selectedTab != tab)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Reserves the bar's height so lists end above it; the bar itself is hidden (slid down)
            // inside a chat and the setup wizard, and the pages then use the full height.
            if !model.tabBarHidden {
                VoryTabBar(tabs: tabs) { compose() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Lists inside the pages' navigation stacks do not pick up the inset above on this iOS
        // (their last rows ended under the bar), so their scroll content gets the same margin.
        .contentMargins(.bottom, model.tabBarHidden ? 0 : VoryTabBar.reservedHeight, for: .scrollContent)
        .animation(.snappy(duration: 0.3), value: model.tabBarHidden)
        .onChange(of: tabs) { _, now in
            // The selected tab was removed from the layout: fall back to Chats instead of a blank pane.
            if !now.contains(model.selectedTab) { model.selectedTab = .chats }
        }
    }

    /// The compose circle: a chat with the bot whose page is in front, otherwise a new chat on Chats.
    private func compose() {
        if model.selectedTab != .bots || model.composeProfile == nil { model.selectedTab = .chats }
        model.newChatRequest = UUID()
    }

    @ViewBuilder private func content(for tab: AppModel.AppTab) -> some View {
        switch tab {
        case .chats: ChatListView()
        case .bots: BotsView()
        case .files: FilesView()
        case .settings: SettingsView()
        case .sessions: NavigationStack { SessionsView().navigationTitle("Sessions") }
        case .cron: NavigationStack { CronView().navigationTitle("Cron Jobs") }
        case .approvals: NavigationStack { ApprovalsView().navigationTitle("Approvals") }
        case .system: NavigationStack { SystemView().navigationTitle("System") }
        }
    }
}

/// Small glass status pill used in navigation bars.
struct ConnectionPill: View {
    var state: SocketState
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(state.label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel("Connection: \(state.label)")
    }
    private var color: Color {
        switch state {
        case .open: return .green
        case .connecting, .reconnecting: return .orange
        case .authRejected, .failed: return .red
        case .idle: return .gray
        }
    }
}
