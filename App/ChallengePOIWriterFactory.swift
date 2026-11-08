import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for the POI challenge writer (POST /api/city/nodes/{id}/complete). Production is gated: nothing
/// is sent and the UI says "Not available yet". Composition may replace `makeWriter` once a write route
/// and grant are approved.
@MainActor enum ChallengePOIWriterFactory {
    static var makeWriter: () -> ChallengePOIWriting = { GatedChallengePOIWriter() }
}
