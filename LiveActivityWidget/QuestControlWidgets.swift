import AppIntents
import SwiftUI
import WidgetKit

/// Components r1 (C2): iOS 18 Control Center / Lock Screen / Action button controls. Each one opens the app on
/// an MP page through `QuestControlRouteIntent` (开始漫游 → roam home, 签到 → the activities I joined).
@available(iOS 18.0, *)
struct QuestStartRoamControl: ControlWidget {
    static let kind = "QuestStartRoamControl"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuestControlRouteIntent(route: .roam)) {
                Label("widget.control.roam", systemImage: "figure.walk")
            }
        }
        .displayName("widget.control.roam")
        .description("widget.control.roam.description")
    }
}

@available(iOS 18.0, *)
struct QuestCheckInControl: ControlWidget {
    static let kind = "QuestCheckInControl"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuestControlRouteIntent(route: .checkIn)) {
                Label("widget.control.checkIn", systemImage: "checkmark.seal")
            }
        }
        .displayName("widget.control.checkIn")
        .description("widget.control.checkIn.description")
    }
}
