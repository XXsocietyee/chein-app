import SwiftUI
import WidgetKit

/// Widget extension entry point: the roam-walk / play-session / story-audio Live Activity, plus (design P1 L9)
/// the next-stop / city passport widget for the Home Screen and Lock Screen.
@main
struct QuestLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuestLiveActivityWidget()
        QuestNextStopWidget()
    }
}
