import SwiftUI
import VoryCore

/// First launch: a short swipeable tour that ends on "Connect your gateway". Continue steps
/// through the pages by tap; the last page pushes the gateway form. No server data is involved.
struct OnboardingView: View {
    @State private var page = 0
    @State private var showForm = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Page {
        let symbol: String
        let title: String
        let text: String
        let tint: Color
    }

    private let pages: [Page] = [
        Page(symbol: "bubble.left.and.text.bubble.right.fill", title: "Your Hermes, in your pocket",
             text: "Vory is a remote for a Hermes Agent you run yourself. Replies stream in token by token, code blocks and tool calls render as they happen, and every chat is a real Hermes session.", tint: .purple),
        Page(symbol: "checkmark.shield.fill", title: "Approve from anywhere",
             text: "When the agent needs a yes — a shell command, a secret, a question — a card lands on your phone. Once, for the session, always, or deny. It waits for you, and a notification tells you it is waiting.", tint: .green),
        Page(symbol: "slider.horizontal.3", title: "Settings, without the terminal",
             text: "Models, API keys, tools, skills, MCP servers, cron jobs, sessions and system health live in a native Settings screen, scoped to whichever profile you pick.", tint: .blue),
        Page(symbol: "antenna.radiowaves.left.and.right", title: "Connect your gateway",
             text: "Enter the URL of your Hermes dashboard (hermes serve), not a chat-webui or SSH app. LAN, Tailscale, Cloudflare Tunnel and plain HTTPS all work. Credentials stay in the iOS Keychain.", tint: .indigo),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                        VStack(spacing: 22) {
                            Spacer(minLength: 0)
                            ZStack {
                                Circle().fill(p.tint.gradient.opacity(0.18)).frame(width: 148, height: 148)
                                Image(systemName: p.symbol)
                                    .font(.system(size: 64, weight: .medium))
                                    .foregroundStyle(p.tint.gradient)
                                    .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating : .repeat(1), value: page == i)
                            }
                            .glassEffect(.regular, in: .circle)
                            Text(p.title).font(.title.weight(.bold)).multilineTextAlignment(.center)
                            Text(p.text).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 28)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(reduceMotion ? nil : .snappy, value: page)

                VStack(spacing: 10) {
                    Button {
                        if isLast { showForm = true } else { page += 1 }
                    } label: {
                        Text(isLast ? "Connect your gateway" : "Continue")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(isLast ? "onboarding.addGateway" : "onboarding.continue")
                    if !isLast {
                        Button("Skip") { page = pages.count - 1 }
                            .font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("onboarding.skip")
                    } else {
                        // Keeps the button block the same height on every page so nothing jumps.
                        Text(" ").font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .navigationTitle("Vory")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showForm) { GatewayFormView() }
        }
    }
}
