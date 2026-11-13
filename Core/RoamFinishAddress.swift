import Foundation

/// Settle-chip address for one live roam. No endpoint: the selected POI name or address,
/// otherwise the local location sentence. Unknown stays an em dash.
public enum RoamFinishAddress: Equatable {
    public static let unknown = "—"

    public enum Location: Equatable {
        case on, off, unknown
    }

    public struct Snapshot: Equatable {
        public var selected: String?
        public var location: Location

        public init(selected: String? = nil, location: Location = .unknown) {
            self.selected = selected
            self.location = location
        }

        public func text(chinese: Bool) -> String {
            if let selected, !selected.isEmpty { return selected }
            switch location {
            case .on: return chinese ? "当前位置" : "Current location"
            case .off: return chinese ? "尚未开启定位" : "Location is off"
            case .unknown: return RoamFinishAddress.unknown
            }
        }
    }

    /// Last confirmed POI that is still in `places`. Name wins over address. An empty pair is not a selection.
    public static func snapshot(phase: RoamLivePhase, places: [RoamPlace], confirmedPOIIDs: [Int]) -> Snapshot {
        Snapshot(selected: selectedText(places: places, confirmedPOIIDs: confirmedPOIIDs), location: location(phase))
    }

    public static func text(phase: RoamLivePhase, places: [RoamPlace], confirmedPOIIDs: [Int], chinese: Bool) -> String {
        snapshot(phase: phase, places: places, confirmedPOIIDs: confirmedPOIIDs).text(chinese: chinese)
    }

    private static func selectedText(places: [RoamPlace], confirmedPOIIDs: [Int]) -> String? {
        guard let id = confirmedPOIIDs.last, let place = places.last(where: { $0.id == id }) else { return nil }
        let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let address = place.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return address.isEmpty ? nil : address
    }

    private static func location(_ phase: RoamLivePhase) -> Location {
        switch phase {
        case .acquiring, .active, .paused, .finishing, .recovering: return .on
        case .ready, .locationDenied: return .off
        case .unavailable, .recoveryRequired, .finished: return .unknown
        }
    }
}
