import SwiftUI

/// PORT-6 `subpackageRoam/history`: mini-program RunCard `aria-label="{date} {title},{distance}公里"`.
/// Reuses existing keys only (`roamSub.w208.history.zoneTitle`, `roam.experience.cityWalk`, `roamSub.w208.history.km`).
extension RoamHistoryRecord {
    var portRunCardAccessibilityLabel: Text {
        let card = RoamRunCardPresentation(self)
        let date = card.dateShort.map { Text(verbatim: $0 + " ") } ?? Text(verbatim: "")
        let title: Text
        switch card.title {
        case .zone(let zone): title = Text("roamSub.w208.history.zoneTitle \(zone)")
        case .city: title = Text("roam.experience.cityWalk")
        }
        return date + title + Text(verbatim: ", " + card.distanceText + " ") + Text("roamSub.w208.history.km")
    }
}
