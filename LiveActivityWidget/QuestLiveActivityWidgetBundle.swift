import SwiftUI
import WidgetKit

/// Widget extension entry point: the roam-walk / play-session / story-audio Live Activity, plus (design P1 L9)
/// the next-stop / city passport widget for the Home Screen and Lock Screen, and (components r1, C2) the event
/// countdown, roam streak, city progress and community widgets and the iOS 18 controls.
@main
struct QuestLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuestLiveActivityWidget()
        QuestNextStopWidget()
        QuestEventCountdownWidget()
        QuestRoamStreakWidget()
        QuestCityProgressWidget()
        QuestCommunityWidget()
        // `WidgetBundleBuilder.buildLimitedAvailability`: iOS 17 installs ship without the controls.
        if #available(iOS 18.0, *) {
            QuestStartRoamControl()
            QuestCheckInControl()
        }
    }
}
