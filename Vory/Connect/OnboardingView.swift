import SwiftUI
import VoryCore

/// First launch: Vory itself walks you through what it does. The cloud sits at the top, talks
/// in a speech bubble (typed out), reacts to each page — a turn on arrival, a squint when the
/// page is about waiting — and under it a small live demo of the feature plays by itself. The
/// last page leads to the gateway form. Nothing here touches a server.
struct OnboardingView: View {
    @State private var page = 0
    @State private var showForm = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Page {
        let title: String
        let says: String
        let demo: TourDemoKind
    }

    private let pages: [Page] = [
        Page(title: "Hi, I'm Vory.", says: "I'm your Hermes gateway, on your phone. Every bot you run lives here — swipe to see what we can do together.", demo: .bots),
        Page(title: "Chats that stream.", says: "Replies arrive word by word, code and tool calls render as they happen, and every chat is a real session on your gateway.", demo: .chat),
        Page(title: "A yes from anywhere.", says: "When a bot needs permission, the card lands on your phone. Once, for the session, always, or deny — it waits for you.", demo: .approval),
        Page(title: "I keep you posted.", says: "A Live Activity follows every turn in the Dynamic Island, and the reply comes as a notification you can answer right there.", demo: .island),
        Page(title: "Make each bot yours.", says: "Give every bot its own body, eyes and colour in the Creator Studio. They blink, glance, and move while they work.", demo: .studio),
        Page(title: "Let's connect.", says: "Point me at your Hermes dashboard — on your Wi‑Fi, over Tailscale, or behind Cloudflare. Your credentials stay in the Keychain.", demo: .connect),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Vory, talking. A full turn on every page; a squint on the page about waiting.
                VStack(spacing: 6) {
                    BotFaceView(spec: AboutView.voryBot, size: 108, active: true, gaze: CGPoint(x: 0, y: 0.5),
                                mood: BotFaceView.Mood(thinking: pages[page].demo == .approval, profile: "vory-tour"))
                        .padding(.top, 8)
                    TypedBubble(text: pages[page].says, pageID: page, reduceMotion: reduceMotion)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 6)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                        VStack(spacing: 16) {
                            Text(p.title).font(.title.weight(.bold)).multilineTextAlignment(.center)
                            Spacer(minLength: 0)
                            TourDemo(kind: p.demo, live: page == i, reduceMotion: reduceMotion)
                                .frame(maxWidth: .infinity)
                            Spacer(minLength: 0)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 24).padding(.top, 14)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(reduceMotion ? nil : .snappy, value: page)
                .onChange(of: page) { _, _ in BotAmbient.shared.turnFinished(profile: "vory-tour") }

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
                        Text(" ").font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .navigationTitle("Vory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showForm) { GatewayFormView() }
        }
    }
}

/// The speech bubble, typed out a few characters at a time whenever the text changes.
private struct TypedBubble: View {
    var text: String
    var pageID: Int
    var reduceMotion: Bool
    @State private var shown = ""

    var body: some View {
        // The About page's bubble is one line; this one wraps, and keeps the full text's height
        // so the page does not grow line by line while it types.
        ZStack {
            Text(text).hidden()
            Text(shown)
        }
        .font(.subheadline.weight(.medium))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .padding(.bottom, 8)
        .background(Color(uiColor: .secondarySystemFill), in: SpeechBubbleShape())
        .frame(maxWidth: 340)
        .task(id: pageID) {
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

enum TourDemoKind { case bots, chat, approval, island, studio, connect }

/// One small, self-playing demo per page.
private struct TourDemo: View {
    var kind: TourDemoKind
    var live: Bool
    var reduceMotion: Bool

    var body: some View {
        switch kind {
        case .bots: BotsDemo(live: live)
        case .chat: ChatDemo(live: live, reduceMotion: reduceMotion)
        case .approval: ApprovalDemo(live: live, reduceMotion: reduceMotion)
        case .island: IslandDemo(live: live)
        case .studio: StudioDemo(live: live, reduceMotion: reduceMotion)
        case .connect: ConnectDemo()
        }
    }
}

/// A handful of bots, each its own shape and colour, blinking on their own time.
private struct BotsDemo: View {
    var live: Bool
    private let looks: [BotLookSpec] = [
        BotLookSpec(shape: "blob", eyes: "classic", hex: "#BF5AF2", finish: "glass"),
        BotLookSpec(shape: "triangle", eyes: "bold", hex: "#FF9F0A", finish: "glass"),
        BotLookSpec(shape: "hexagon", eyes: "round", hex: "#30D158", finish: "glass"),
        BotLookSpec(shape: "drop", eyes: "curious", hex: "#64D2FF", finish: "glass"),
    ]
    var body: some View {
        HStack(spacing: 18) {
            ForEach(Array(looks.enumerated()), id: \.offset) { i, l in
                BotFaceView(spec: l, size: 58, active: live && i == 1, mood: BotFaceView.Mood(profile: "tour-bot-\(i)"))
            }
        }
        .padding(.vertical, 18).padding(.horizontal, 22)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

/// A two-line chat: the question, then the answer typing itself, then a tool card ticking done.
private struct ChatDemo: View {
    var live: Bool
    var reduceMotion: Bool
    @State private var reply = ""
    @State private var toolDone = false
    private let full = "Found 4.2 GB of rotated logs older than 90 days. I'll clear them and leave today's alone."

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Spacer(minLength: 60); bubble("Clean up the old logs on the server", user: true) }
            HStack { bubble(reply.isEmpty ? "…" : reply, user: false); Spacer(minLength: 40) }
            HStack(spacing: 8) {
                Image(systemName: toolDone ? "checkmark.circle.fill" : "gear").foregroundStyle(toolDone ? .green : .secondary)
                    .symbolEffect(.rotate, isActive: !toolDone && live)
                Text("terminal").font(.caption.weight(.semibold))
                Text("du -sh /var/log/* | sort -rh").font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
            }
            .padding(10)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .opacity(reply.count > 20 ? 1 : 0)
        }
        .task(id: live) {
            guard live else { return }
            reply = ""; toolDone = false
            if reduceMotion { reply = full; toolDone = true; return }
            try? await Task.sleep(for: .milliseconds(500))
            for ch in full { guard !Task.isCancelled else { return }; reply.append(ch); try? await Task.sleep(for: .milliseconds(24)) }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.snappy) { toolDone = true }
        }
    }

    private func bubble(_ t: String, user: Bool) -> some View {
        Text(t).font(.subheadline)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(user ? .white : .primary)
            .background(user ? Color.accentColor : Color(.systemGray5), in: .rect(cornerRadius: 16))
    }
}

/// The approval card slides in, "Once" gets picked, the card turns green.
private struct ApprovalDemo: View {
    var live: Bool
    var reduceMotion: Bool
    @State private var shown = false
    @State private var picked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: picked ? "checkmark.shield.fill" : "exclamationmark.triangle.fill").foregroundStyle(picked ? .green : .yellow)
                Text(picked ? "Allowed once" : "Approval needed").font(.headline)
            }
            Text("delete rotated log files older than 90 days").font(.subheadline).foregroundStyle(.secondary)
            Text("find /var/log -name '*.log.*' -mtime +90 -delete").font(.caption.monospaced()).lineLimit(1)
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6), in: .rect(cornerRadius: 8))
            HStack(spacing: 8) {
                ForEach(["Once", "Session", "Always", "Deny"], id: \.self) { c in
                    Text(c).font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(picked && c == "Once" ? Color.accentColor : Color(.systemGray5), in: .capsule)
                        .foregroundStyle(picked && c == "Once" ? .white : .primary)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .offset(y: shown ? 0 : 40).opacity(shown ? 1 : 0)
        .task(id: live) {
            guard live else { return }
            shown = false; picked = false
            if reduceMotion { shown = true; picked = true; return }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { shown = true }
            try? await Task.sleep(for: .milliseconds(1800))
            withAnimation(.snappy) { picked = true }
        }
    }
}

/// A Dynamic Island with a bot working in it, then the reply as a notification.
private struct IslandDemo: View {
    var live: Bool
    @State private var seconds = 0
    @State private var replied = false
    private let bot = BotLookSpec(shape: "blob", eyes: "classic", hex: "#BF5AF2", finish: "glass")

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                BotFaceView(spec: bot, size: 30, active: live && !replied, mood: BotFaceView.Mood(profile: "tour-island"))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ada").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(replied ? "Finished" : "Writing").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text(String(format: "0:%02d", seconds)).font(.subheadline.monospacedDigit()).foregroundStyle(.white)
                Image(systemName: replied ? "checkmark" : "ellipsis.message.fill").foregroundStyle(replied ? .green : Color(botHex: bot.hex) ?? .purple)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.black, in: .capsule)
            .frame(maxWidth: 300)
            HStack(spacing: 10) {
                BotFaceView(spec: bot, size: 34, active: false, mood: BotFaceView.Mood(profile: "tour-note"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ada").font(.subheadline.weight(.semibold))
                    Text("Done — 4.2 GB freed. Want me to set up log rotation?").font(.caption).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .opacity(replied ? 1 : 0).offset(y: replied ? 0 : -12)
        }
        .task(id: live) {
            guard live else { return }
            seconds = 0; replied = false
            for i in 1...4 { try? await Task.sleep(for: .milliseconds(650)); guard !Task.isCancelled else { return }; seconds = i }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { replied = true }
        }
    }
}

/// One bot changing body, eyes and colour, as the Creator Studio would.
private struct StudioDemo: View {
    var live: Bool
    var reduceMotion: Bool
    @State private var index = 0
    private let looks: [BotLookSpec] = [
        BotLookSpec(shape: "blob", eyes: "classic", hex: "#7C5CFF", finish: "glass"),
        BotLookSpec(shape: "cloud", eyes: "round", hex: "#0A84FF", finish: "glass"),
        BotLookSpec(shape: "square", eyes: "wide", hex: "#FF375F", finish: "glass"),
        BotLookSpec(shape: "hexagon", eyes: "tall", hex: "#30D158", finish: "glass"),
        BotLookSpec(shape: "drop", eyes: "tiny", hex: "#FFD60A", finish: "glass"),
        BotLookSpec(shape: "pill", eyes: "sleepy", hex: "#FF9F0A", finish: "glass"),
    ]
    var body: some View {
        VStack(spacing: 12) {
            BotFaceView(spec: looks[index], size: 96, active: false, mood: BotFaceView.Mood(profile: "tour-studio"))
                .id(index)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            HStack(spacing: 8) {
                ForEach(Array(looks.enumerated()), id: \.offset) { i, l in
                    Circle().fill(Color(botHex: l.hex) ?? .gray).frame(width: i == index ? 14 : 10, height: i == index ? 14 : 10)
                }
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 22)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .task(id: live) {
            guard live, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1400))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) { index = (index + 1) % looks.count }
            }
        }
    }
}

/// The ways to reach a gateway, in one glance.
private struct ConnectDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("wifi", "Local network", "Same Wi‑Fi as the gateway machine.")
            row("point.3.connected.trianglepath.dotted", "Tailscale", "From anywhere, over your tailnet.")
            row("cloud", "Cloudflare Access", "A public hostname with a service token.")
            row("globe", "Other", "Any https address that reaches the dashboard.")
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
    private func row(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 28, height: 28).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
