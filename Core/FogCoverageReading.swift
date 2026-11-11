import Foundation

/// Roam fog spec §1d. Unknown is a first-class case: it prints an em dash, never `0` or `0 %`.
public enum FogCoverageReading: Equatable {
    public enum UnknownReason: Equatable, CaseIterable { case notLoaded, readFailed, noIdentity, permissionMissing, noAreaSelected }

    /// Denominator is the selected search-area grid, never "the city". Pending cells are counted apart ("unconfirmed").
    case known(confirmed: Int, pending: Int, areaCells: Int)
    case unknown(UnknownReason)

    public static let unknownText = "—"

    /// Whole percent of confirmed cells over the area, clamped to 100; nil when unknown or the area has no cells.
    public var percent: Int? {
        guard case let .known(confirmed, _, area) = self, area > 0, confirmed >= 0 else { return nil }
        return min(100, confirmed * 100 / area)
    }
    /// nil for unknown (and for an empty area) so the caller must choose to print `unknownText`.
    public var percentText: String? { percent.map { "\($0)%" } }
    public var displayText: String { percentText ?? Self.unknownText }
    public var pendingCount: Int? { if case let .known(_, pending, _) = self { return pending } else { return nil } }
}

/// Where a `FogCoverageReading` comes from. Nothing here is a fixture: with no loaded bitmap the answer is unknown.
public enum FogCoverageReader {
    public static func reading(confirmed: FogCellBitmap?, pending: FogCellBitmap?, areaCells: Set<String>?,
                               owner: String?, permissionGranted: Bool) -> FogCoverageReading {
        guard owner != nil else { return .unknown(.noIdentity) }
        guard permissionGranted else { return .unknown(.permissionMissing) }
        guard let areaCells, !areaCells.isEmpty else { return .unknown(.noAreaSelected) }
        guard let confirmed else { return .unknown(.notLoaded) }
        var confirmedCount = 0, pendingCount = 0
        for code in areaCells {
            guard let cell = try? FogCell(grid: confirmed.grid, code: code) else { continue }
            if confirmed.contains(cell) { confirmedCount += 1 } else if pending?.contains(cell) == true { pendingCount += 1 }
        }
        return .known(confirmed: confirmedCount, pending: pendingCount, areaCells: areaCells.count)
    }
}
