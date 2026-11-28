import Foundation

/// Gap #24 (1128 plan, R-02d; OWNER RULE 3 level-A signature surface): the live roam walk draws the fog lifting
/// where the player walked. This projects the walk's own durable record (`RoamLiveRecord.allTiles`, geohash-7 cells
/// in the server datum GCJ-02) into the two bitmaps the fog layer draws. Server-acknowledged cells are confirmed;
/// cells still in `pendingTiles` (not yet acknowledged by POST /api/roam/reveal) are pending. Pure value code: no
/// location, network or persistence. The coverage area is the set of geohash-6 blocks this walk touched (32 cells
/// each), so the badge reads "how much of the blocks you walked in is clear", never an invented city total.
public struct RoamLiveFogProjection: Equatable {
    public let confirmed: FogCellBitmap
    public let pending: FogCellBitmap
    public let revision: Int
    public let coverage: FogCoverageReading

    public static func make(record: RoamLiveRecord?, owner: String?) -> RoamLiveFogProjection? {
        guard PersonalFogFeature.liveRevealEnabled, let record, !record.allTiles.isEmpty else { return nil }
        let pendingSet = Set(record.pendingTiles)
        var confirmed = FogCellBitmap(), pending = FogCellBitmap()
        var blocks = Set<String>()
        for code in record.allTiles {
            guard let cell = try? FogCell(grid: .legacyRoamTile, code: code) else { continue }
            if pendingSet.contains(code) { try? pending.insert(cell) } else { try? confirmed.insert(cell) }
            blocks.insert(String(code.prefix(6)))
        }
        var area = Set<String>()
        for block in blocks where block.count == 6 {
            for child in FogCellBitmap.alphabet { area.insert(block + String(child)) }
        }
        let coverage = FogCoverageReader.reading(confirmed: confirmed, pending: pending, areaCells: area,
                                                 owner: owner, permissionGranted: true)
        // The mask cache rebuilds only on a revision bump: any new cell or any acknowledgement changes it.
        let revision = record.allTiles.count &* 65_537 &+ record.pendingTiles.count
        return .init(confirmed: confirmed, pending: pending, revision: revision, coverage: coverage)
    }
}
