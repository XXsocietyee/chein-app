import SwiftUI

/// PORT-6 `subpackageRoam/history`: mini-program RunCard `aria-label="{date} {title},{distance}公里"`.
/// Reuses existing keys only (`roamSub.w208.history.zoneTitle`, `roam.experience.cityWalk`, `roamSub.w208.history.km`).
extension RoamHistoryRecord {
    /// The spoken date matches the visible card date (`LocaleDisplay.monthDay`: zh 10月19日 / en Oct 19), not the MP `M/D/YY`.
    func portRunCardAccessibilityLabel(locale: Locale) -> Text {
        let card = RoamRunCardPresentation(self)
        let spoken: String? = recordedAt.map { LocaleDisplay.monthDay($0, locale: locale) }
        let date = spoken.map { Text(verbatim: $0 + " ") } ?? Text(verbatim: "")
        let title: Text
        switch card.title {
        case .zone(let zone): title = Text("roamSub.w208.history.zoneTitle \(zone)")
        case .city: title = Text("roam.experience.cityWalk")
        }
        return date + title + Text(verbatim: ", " + card.distanceText + " ") + Text("roamSub.w208.history.km")
    }
}
