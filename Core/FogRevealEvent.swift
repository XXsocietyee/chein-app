import Foundation

/// Roam fog spec stage 3 (§1c). A newly accepted fix that adds at least one cell. Carries geometry only: no track,
/// no identity, no timestamps beyond the event time. Pure value type.
public struct FogRevealEvent: Equatable {
    public let cells: [FogRenderCell]
    /// The fix point the radial wipe grows from.
    public let origin: RoamCoordinate
    public let at: Date

    public init(cells: [FogRenderCell], origin: RoamCoordinate, at: Date) {
        self.cells = cells; self.origin = origin; self.at = at
    }
}
