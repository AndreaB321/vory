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
        @Bindable var model = model
        let tabs = TabLayout.parse(layoutRaw).visible()
        TabView(selection: $model.selectedTab) {
            ForEach(tabs, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.symbol, value: tab) {
                    content(for: tab)
                }
                .badge(badge(for: tab))
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: tabs) { _, now in
            // The selected tab was removed from the layout: fall back to Chats instead of a blank pane.
            if !now.contains(model.selectedTab) { model.selectedTab = .chats }
        }
    }

    /// Chats counts waiting cards; Settings flags a gateway that needs a restart, or a companion
    /// update waiting under Notifications › Background Notifications.
    private func badge(for tab: AppModel.AppTab) -> Text? {
        switch tab {
        case .chats:
            let n = model.runtime?.needsAttention.count ?? 0
            return n > 0 ? Text("\(n)") : nil
        case .settings:
            if model.runtime?.restartRequired != nil { return Text("!") }
            return model.companionUpdateAvailable ? Text("1") : nil
        default:
            return nil
        }
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
