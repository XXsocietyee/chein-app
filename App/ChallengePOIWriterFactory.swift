import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for the POI challenge writer (POST /api/city/nodes/{id}/complete). Defaults to `GatedChallengePOIWriter`
/// until root composition installs the live writer backed by the signed-in China session.
@MainActor enum ChallengePOIWriterFactory {
    static var makeWriter: () -> ChallengePOIWriting = { GatedChallengePOIWriter() }

    /// True once composition replaced the gated writer.
    static var isLive: Bool { !(makeWriter() is GatedChallengePOIWriter) }
}
