import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI
import VoryCore

/// The expanded (long-press) view of a finished-turn notification, laid out like a message
/// thread: the bot's avatar and name, the chat it came from, and the reply as a bubble. The
/// "Reply" text field underneath is the system's, from the notification category's text action.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<ReplyCard>?

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let hermes = content.userInfo["hermes"] as? [String: Any] ?? [:]
        Keychain.accessGroup = Keychain.sharedGroupFromBundle()
        let looks = BotLooks.load()
        let profile = hermes["profile"] as? String ?? ""
        let model = ReplyCard.Model(
            bot: content.title.isEmpty ? (profile.isEmpty ? "Hermes" : profile) : content.title,
            chatTitle: (hermes["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? content.subtitle,
            text: (hermes["text"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.stripTitle(content.body),
            tintHex: looks.colors[profile] ?? "",
            avatar: looks.avatars[profile] ?? "initial",
            failed: content.categoryIdentifier == "HERMES_ERROR")
        let card = ReplyCard(model: model)
        if let host {
            host.rootView = card
        } else {
            let h = UIHostingController(rootView: card)
            h.view.backgroundColor = .clear
            addChild(h)
            h.view.frame = view.bounds
            h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(h.view)
            h.didMove(toParent: self)
            host = h
        }
        view.layoutIfNeeded()
        let width = view.bounds.width > 0 ? view.bounds.width : 360
        let height = host?.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height ?? 120
        preferredContentSize = CGSize(width: width, height: min(max(height, 96), 520))
    }

    /// The banner body is "chat title: reply"; older companions send no separate text.
    private static func stripTitle(_ body: String) -> String {
        if let r = body.range(of: ": ") , body.distance(from: body.startIndex, to: r.lowerBound) < 80 { return String(body[r.upperBound...]) }
        return body
    }
}

/// Bot colours and avatar choices, mirrored by the app into the shared keychain so the
/// extension can draw the same bot the app shows.
struct BotLooks: Codable {
    var colors: [String: String] = [:]
    var avatars: [String: String] = [:]
    static let account = "botLooks"
    static func load() -> BotLooks { Keychain.getCodable(BotLooks.self, account: account) ?? BotLooks() }
}

struct ReplyCard: View {
    struct Model {
        var bot: String
        var chatTitle: String
        var text: String
        var tintHex: String
        var avatar: String
        var failed: Bool
    }
    var model: Model

    private var tint: Color { Color(hexString: model.tintHex) ?? .purple }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LookAvatar(avatar: model.avatar, initial: String(model.bot.prefix(1)).uppercased(), tint: tint, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.bot).font(.headline)
                    Text(model.chatTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if model.failed {
                    Label("Failed", systemImage: "xmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.red)
                }
            }
            HStack(alignment: .bottom, spacing: 0) {
                Text(model.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemFill), in: BubbleShape())
                    .frame(maxWidth: 320, alignment: .leading)
                Spacer(minLength: 24)
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A received-message bubble: rounded, with a small tail at the bottom-left like Messages.
struct BubbleShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: 18)
        let tail = CGRect(x: r.minX - 5, y: r.maxY - 16, width: 12, height: 16)
        p.move(to: CGPoint(x: tail.minX, y: tail.maxY))
        p.addQuadCurve(to: CGPoint(x: tail.maxX + 2, y: tail.minY), control: CGPoint(x: tail.minX + 3, y: tail.maxY - 6))
        p.addLine(to: CGPoint(x: tail.maxX + 2, y: tail.maxY))
        p.closeSubpath()
        return p
    }
}

/// The bot's avatar; animated styles move here because this is a real view, not a widget.
struct LookAvatar: View {
    var avatar: String
    var initial: String
    var tint: Color
    var size: CGFloat

    var body: some View {
        Group {
            if avatar.hasPrefix("animated:") {
                let style = String(avatar.dropFirst("animated:".count))
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas(opaque: false, rendersAsynchronously: false) { ctx, sz in
                        let r = CGRect(origin: .zero, size: sz)
                        ctx.clip(to: Path(ellipseIn: r))
                        ctx.fill(Path(ellipseIn: r), with: .linearGradient(Gradient(colors: [tint.opacity(0.95), tint.opacity(0.65)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: sz.height)))
                        let z = AvatarArt.zoom(style)
                        ctx.translateBy(x: sz.width / 2, y: sz.height / 2)
                        ctx.scaleBy(x: z, y: z)
                        ctx.translateBy(x: -sz.width / 2, y: -sz.height / 2)
                        AvatarArt.draw(style, in: &ctx, size: sz, time: t, active: true)
                    }
                }
            } else {
                ZStack {
                    Circle().fill(tint.gradient)
                    Text(initial).font(.system(size: size * 0.48, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension Color {
    init?(hexString: String) {
        var s = hexString; if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
