import SwiftUI
import WidgetKit

/// Watch-face complications: the same widgets the iPhone shows on its lock screen.
@main
struct VoryComplicationsBundle: WidgetBundle {
    var body: some Widget {
        AttentionWidget()
        ActivityWidget()
        ContextWidget()
    }
}
