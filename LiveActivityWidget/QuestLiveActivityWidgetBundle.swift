import SwiftUI
import WidgetKit

/// Widget extension entry point. Only the roam-walk / play-session Live Activity; no Home Screen widgets.
@main
struct QuestLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuestLiveActivityWidget()
    }
}
