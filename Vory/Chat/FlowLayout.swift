import SwiftUI

/// Lays children out left to right and wraps to a new line when the width runs out, like
/// recipient chips in Messages' To: field.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > bounds.width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y + (rowHeight > 0 ? (rowHeight - s.height) / 2 : 0)), proposal: .unspecified)
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
