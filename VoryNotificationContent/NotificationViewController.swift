import Combine
import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI
import VoryCore

/// The expanded (long-press) view of a finished-turn notification, laid out like a message
/// thread: the bot's avatar and name, the chat it came from, and the reply as a bubble. The
/// "Reply" text field underneath is the system's, from the notification category's text action.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<ReplyPane>?
    /// Which page shows; shared with the pane so a UIKit tap (which the platter delivers when a
    /// SwiftUI button tap or a swipe does not) can flip it.
    private let pager = ReplyPager()

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func tapped() {
        guard pager.hasThread else { return }
        withAnimation { pager.page = pager.page == 0 ? 1 : 0 }
    }
    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let hermes = content.userInfo["hermes"] as? [String: Any] ?? [:]
        Keychain.accessGroup = Keychain.sharedGroupFromBundle()
        let looks = BotLooks.load()
        let profile = hermes["profile"] as? String ?? ""
        // Earlier exchanges the companion sent along (user and bot, shortened), oldest first.
        let thread = (hermes["thread"] as? [[String: Any]] ?? []).compactMap { m -> ReplyCard.Line? in
            guard let role = m["role"] as? String, let text = m["text"] as? String, !text.isEmpty else { return nil }
            return ReplyCard.Line(fromUser: role == "user", text: text)
        }
        let model = ReplyCard.Model(
            bot: content.title.isEmpty ? (profile.isEmpty ? "Hermes" : profile) : content.title,
            chatTitle: (hermes["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? content.subtitle,
            text: (hermes["text"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.stripTitle(content.body),
            thread: thread,
            tintHex: looks.colors[profile] ?? "",
            avatar: looks.avatars[profile] ?? "initial",
            failed: content.categoryIdentifier == "HERMES_ERROR")
        measured = UIHostingController(rootView: ReplyCard(model: model, page: .reply))
        measuredThread = model.thread.isEmpty ? nil : UIHostingController(rootView: ReplyCard(model: model, page: .thread))
        page = 1
        pager.page = 1
        pager.hasThread = !model.thread.isEmpty
        let card = ReplyPane(model: model, pager: pager, onPage: { [weak self] p in
            guard let self else { return }
            self.page = p
            let w = self.view.bounds.width > 0 ? self.view.bounds.width : UIScreen.main.bounds.width - 16
            self.preferredContentSize = CGSize(width: w, height: self.fittedHeight(width: w))
        })
        if let host {
            host.rootView = card
        } else {
            let h = UIHostingController(rootView: card)
            h.view.backgroundColor = .clear
            addChild(h)
            view.addSubview(h.view)
            // Pinned with constraints: the view's bounds are still zero when this runs, and an
            // autoresizing mask scaled from zero stays zero (a blank window).
            h.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                h.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                h.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                h.view.topAnchor.constraint(equalTo: view.topAnchor),
                h.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            h.didMove(toParent: self)
            host = h
        }
        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width - 16
        preferredContentSize = CGSize(width: width, height: fittedHeight(width: width))
    }

    /// The card's natural height, measured on the plain card (a scroll view would claim any height),
    /// capped at what fits above the keyboard and the reply field: the system clips a taller view
    /// rather than shrinking it, so the cap is what makes the pane scroll instead of being cut off.
    private var measured: UIHostingController<ReplyCard>?
    private var measuredThread: UIHostingController<ReplyCard>?
    private var page = 1
    /// The showing page's own height (plus the page dots when there are two pages).
    private func fittedHeight(width: CGFloat) -> CGFloat {
        let a = measured?.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height ?? 120
        let b = measuredThread?.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height ?? 0
        let h = (page == 0 && measuredThread != nil ? b : a) + (measuredThread == nil ? 0 : 26)
        // iOS fixes the expanded notification's height while the keyboard is up and clips anything
        // taller; the Lock Screen (clock and widgets above) gives less room than the Home Screen.
        let cap = max(200, UIScreen.main.bounds.height * 0.29)
        return min(max(h, 96), cap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Re-measure once the real width is known so the bubbles never get clipped.
        guard view.bounds.width > 0 else { return }
        let size = CGSize(width: view.bounds.width, height: fittedHeight(width: view.bounds.width))
        if abs(size.height - preferredContentSize.height) > 1 { preferredContentSize = size }
    }

    /// The banner body is "chat title: reply"; older companions send no separate text.
    private static func stripTitle(_ body: String) -> String {
        if let r = body.range(of: ": ") , body.distance(from: body.startIndex, to: r.lowerBound) < 80 { return String(body[r.upperBound...]) }
        return body
    }
}

/// Two pages side by side: the earlier exchanges, then the reply (shown first). Vertical drags
/// inside a notification belong to the system's pull-to-dismiss, so the pane pages sideways instead.
/// The showing page, owned by the controller so UIKit and SwiftUI both drive it.
final class ReplyPager: ObservableObject {
    @Published var page = 1
    var hasThread = false
}

struct ReplyPane: View {
    var model: ReplyCard.Model
    @ObservedObject var pager: ReplyPager
    /// Tells the controller which page is showing, so the window takes that page's height.
    var onPage: (Int) -> Void = { _ in }

    var body: some View {
        if model.thread.isEmpty {
            ReplyCard(model: model, page: .reply)
        } else {
            TabView(selection: $pager.page) {
                ReplyCard(model: model, page: .thread, switchPage: { withAnimation { pager.page = 1 } }).frame(maxHeight: .infinity, alignment: .top).tag(0)
                ReplyCard(model: model, page: .reply, switchPage: { withAnimation { pager.page = 0 } }).frame(maxHeight: .infinity, alignment: .top).tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .onChange(of: pager.page) { _, p in onPage(p) }
        }
    }
}

struct ReplyCard: View {
    enum Page { case thread, reply }
    var page: Page = .reply
    /// Tapping the hint switches pages too: on the Home Screen the platter can swallow swipes.
    var switchPage: () -> Void = {}
    struct Line: Identifiable {
        var fromUser: Bool
        var text: String
        var id: String { (fromUser ? "u:" : "a:") + text }
    }
    struct Model {
        var bot: String
        var chatTitle: String
        var text: String
        var thread: [Line] = []
        var tintHex: String
        var avatar: String
        var failed: Bool
    }
    var model: Model

    init(model: Model, page: Page = .reply, switchPage: @escaping () -> Void = {}) { self.model = model; self.page = page; self.switchPage = switchPage }

    private var tint: Color { Color(hexString: model.tintHex) ?? .purple }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LookAvatar(avatar: model.avatar, initial: String(model.bot.prefix(1)).uppercased(), tintHex: model.tintHex, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.bot).font(.headline)
                    Text(model.chatTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if model.failed {
                    Label("Failed", systemImage: "xmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.red)
                }
            }
            ForEach(page == .thread ? model.thread : []) { line in
                if line.fromUser {
                    HStack(alignment: .bottom, spacing: 0) {
                        Spacer(minLength: 48)
                        Text(line.text)
                            .font(.subheadline).lineLimit(3)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(Color.accentColor, in: BubbleShape(tailOnRight: true))
                            .frame(maxWidth: 280, alignment: .trailing)
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text(line.text)
                            .font(.subheadline).lineLimit(3)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(Color(uiColor: .secondarySystemFill), in: BubbleShape())
                            .frame(maxWidth: 280, alignment: .leading)
                        Spacer(minLength: 48)
                    }
                }
            }
            if page == .reply {
                HStack(alignment: .bottom, spacing: 0) {
                    Text(model.text.replacingOccurrences(of: "\n\n", with: "\n"))
                        .font(.subheadline)
                        .lineLimit(6)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(Color(uiColor: .secondarySystemFill), in: BubbleShape())
                        .frame(maxWidth: 280, alignment: .leading)
                    Spacer(minLength: 40)
                }
                if !model.thread.isEmpty {
                    Text("Tap or swipe for what came before").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            } else {
                Text("Tap or swipe back for the reply").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A message bubble like Messages: rounded, with a small curled tail at the bottom corner (left
/// for received, right for the user's own). The tail is a short curl, not a wedge.
struct BubbleShape: Shape {
    var tailOnRight = false
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: 17, style: .continuous)
        var tail = Path()
        if tailOnRight {
            tail.move(to: CGPoint(x: r.maxX - 12, y: r.maxY))
            tail.addQuadCurve(to: CGPoint(x: r.maxX + 5, y: r.maxY), control: CGPoint(x: r.maxX - 3, y: r.maxY - 1))
            tail.addQuadCurve(to: CGPoint(x: r.maxX - 1, y: r.maxY - 12), control: CGPoint(x: r.maxX + 1, y: r.maxY - 5))
        } else {
            tail.move(to: CGPoint(x: r.minX + 12, y: r.maxY))
            tail.addQuadCurve(to: CGPoint(x: r.minX - 5, y: r.maxY), control: CGPoint(x: r.minX + 3, y: r.maxY - 1))
            tail.addQuadCurve(to: CGPoint(x: r.minX + 1, y: r.maxY - 12), control: CGPoint(x: r.minX - 1, y: r.maxY - 5))
        }
        tail.closeSubpath()
        p.addPath(tail)
        return p
    }
}

/// The bot's avatar; it animates here because this is a real view, not a widget.
struct LookAvatar: View {
    var avatar: String
    var initial: String
    var tintHex: String
    var size: CGFloat

    var body: some View {
        BotFaceView(spec: BotLookSpec.from(choice: avatar, hex: tintHex), size: size, active: true)
    }
}

extension Color {
    init?(hexString: String) {
        var s = hexString; if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
