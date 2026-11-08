import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for free-explore reservation cancel. Production is gated (no quote or cancel is sent, UI says
/// "Not available yet"); a transport-backed canceler is injected by composition when approved.
@MainActor enum FreeExploreCancelFactory {
    static var makeCanceler: () -> FreeExploreReservationCanceling = { GatedFreeExploreReservationCanceler() }
}
