import Foundation

/// Roam fog spec stage 1 (docs/roam-fog-engine.md §1a). Explored cells are stored as one 1024-bit set per geohash-5
/// parent: the two trailing characters of a geohash-7 key are 5 bits each, so a parent has exactly 1024 children.
/// A bitset has no order and no timestamps, so a raw trail cannot be rebuilt from it. Pure value type: no location,
/// network or persistence imports.
public struct FogCellBitmap: Equatable, Codable {
    public struct ParentKey: Hashable, Codable, Comparable {
        public let geohash5: String
        public init(geohash5: String) { self.geohash5 = geohash5 }
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.geohash5 < rhs.geohash5 }
    }

    /// 16 words x 64 bits. Bit `i` is child `v6 * 32 + v7` where v6/v7 are the base-32 values of characters 6 and 7.
    public struct Bits1024: Equatable, Codable {
        public static let wordCount = 16
        public private(set) var words: [UInt64]
        public init() { words = [UInt64](repeating: 0, count: Self.wordCount) }
        public init?(words: [UInt64]) {
            guard words.count == Self.wordCount else { return nil }
            self.words = words
        }
        public var isEmpty: Bool { !words.contains { $0 != 0 } }
        public var popcount: Int { words.reduce(0) { $0 + $1.nonzeroBitCount } }
        public func contains(_ bit: Int) -> Bool {
            guard (0..<1024).contains(bit) else { return false }
            return words[bit >> 6] & (1 << UInt64(bit & 63)) != 0
        }
        public mutating func insert(_ bit: Int) {
            guard (0..<1024).contains(bit) else { return }
            words[bit >> 6] |= 1 << UInt64(bit & 63)
        }
        public mutating func formUnion(_ other: Bits1024) { for i in 0..<Self.wordCount { words[i] |= other.words[i] } }
        public mutating func subtract(_ other: Bits1024) { for i in 0..<Self.wordCount { words[i] &= ~other.words[i] } }
        /// Children revealed under one geohash-6 cell (`v6` in 0...31): a contiguous 32-bit half word.
        public func childCount(v6: Int) -> Int {
            guard (0..<32).contains(v6) else { return 0 }
            return Int((words[v6 >> 1] >> UInt64((v6 & 1) * 32)) & 0xFFFF_FFFF).nonzeroBitCount
        }
        /// 128 bytes, little-endian words.
        public var data: Data {
            var out = Data(capacity: Self.wordCount * 8)
            for word in words { for shift in stride(from: 0, to: 64, by: 8) { out.append(UInt8((word >> UInt64(shift)) & 0xFF)) } }
            return out
        }
        public init?(data: Data) {
            guard data.count == Self.wordCount * 8 else { return nil }
            let bytes = [UInt8](data)
            var parsed = [UInt64](repeating: 0, count: Self.wordCount)
            for w in 0..<Self.wordCount { for b in 0..<8 { parsed[w] |= UInt64(bytes[w * 8 + b]) << UInt64(b * 8) } }
            words = parsed
        }
    }

    public static let alphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    /// Hard cap for the persisted envelope (spec: 2 MB).
    public static let maxEnvelopeBytes = 2 * 1024 * 1024

    public let grid: FogGridVersion
    public private(set) var parents: [ParentKey: Bits1024] = [:]

    public init(grid: FogGridVersion = .legacyRoamTile) { self.grid = grid }

    public static func charValue(_ c: Character) -> Int? { alphabet.firstIndex(of: c) }

    /// Parent + bit for a precision-7 geohash; nil for any other length or a character outside the alphabet.
    public static func index(of geohash7: String) -> (parent: ParentKey, bit: Int)? {
        let chars = Array(geohash7)
        guard chars.count == 7, let v6 = charValue(chars[5]), let v7 = charValue(chars[6]),
              chars[..<5].allSatisfy({ charValue($0) != nil }) else { return nil }
        return (ParentKey(geohash5: String(chars[..<5])), v6 * 32 + v7)
    }

    public static func code(parent: ParentKey, bit: Int) -> String? {
        guard (0..<1024).contains(bit), parent.geohash5.count == 5 else { return nil }
        return parent.geohash5 + String(alphabet[bit / 32]) + String(alphabet[bit % 32])
    }

    public mutating func insert(_ cell: FogCell) throws {
        guard cell.grid == grid, let slot = Self.index(of: cell.code) else { throw PersonalFogFailure.invalidCell }
        parents[slot.parent, default: Bits1024()].insert(slot.bit)
    }

    /// Union only: the merge never removes a cell, and carries no timestamps.
    public mutating func formUnion(_ other: FogCellBitmap) {
        guard other.grid == grid else { return }
        for (key, bits) in other.parents { parents[key, default: Bits1024()].formUnion(bits) }
    }

    public mutating func subtract(_ other: FogCellBitmap) {
        guard other.grid == grid else { return }
        for (key, bits) in other.parents {
            guard var mine = parents[key] else { continue }
            mine.subtract(bits)
            parents[key] = mine.isEmpty ? nil : mine
        }
    }

    public func contains(_ cell: FogCell) -> Bool {
        guard cell.grid == grid, let slot = Self.index(of: cell.code) else { return false }
        return parents[slot.parent]?.contains(slot.bit) ?? false
    }

    public var count: Int { parents.values.reduce(0) { $0 + $1.popcount } }
    public var isEmpty: Bool { count == 0 }

    /// Revealed children (0...32) under a geohash-6 cell; 0 for a malformed code. This is a count of a loaded bitmap,
    /// so "none revealed" is a real zero here; callers with no loaded bitmap must use `FogCoverageReading.unknown`.
    public func coverage(geohash6: String) -> UInt8 {
        let chars = Array(geohash6)
        guard chars.count == 6, let v6 = Self.charValue(chars[5]) else { return 0 }
        return UInt8(parents[ParentKey(geohash5: String(chars[..<5]))]?.childCount(v6: v6) ?? 0)
    }

    /// Every revealed cell as a lat/lng rectangle whose mercator rect intersects `window`, in code order.
    public func cells(in window: FogMercatorWindow, state: PersonalFogLedger.CellState = .confirmed,
                      datum: WalkingCoordinateDatum = .gcj02) -> [FogRenderCell] {
        var out: [FogRenderCell] = []
        for key in parents.keys.sorted() {
            guard let bits = parents[key] else { continue }
            for bit in 0..<1024 where bits.contains(bit) {
                guard let code = Self.code(parent: key, bit: bit), let b = FogGeohash.bounds(of: code) else { continue }
                let rect = FogMercatorWindow.rect(south: b.south, west: b.west, north: b.north, east: b.east)
                guard window.intersects(minX: rect.minX, minY: rect.minY, maxX: rect.maxX, maxY: rect.maxY) else { continue }
                out.append(FogRenderCell(code: code, south: b.south, west: b.west, north: b.north, east: b.east, state: state, datum: datum))
            }
        }
        return out
    }

    // MARK: Persistence envelope (`roam-fog-bitmap-v1-<ownerScope>`)

    private struct Envelope: Codable {
        struct Parent: Codable { let p: String; let bits: String }
        let version: Int
        let grid: String
        let owner: String
        let parents: [Parent]
    }

    public enum EnvelopeFailure: Error, Equatable { case tooLarge, malformed, ownerMismatch, unsupportedVersion, gridMismatch }

    public func envelopeData(owner: String) throws -> Data {
        let list = parents.keys.sorted().compactMap { key in
            parents[key].map { Envelope.Parent(p: key.geohash5, bits: $0.data.base64EncodedString()) }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Envelope(version: 1, grid: grid.id, owner: owner, parents: list))
        guard data.count <= Self.maxEnvelopeBytes else { throw EnvelopeFailure.tooLarge }
        return data
    }

    public static func decode(_ data: Data, owner: String) throws -> FogCellBitmap {
        guard data.count <= maxEnvelopeBytes else { throw EnvelopeFailure.tooLarge }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else { throw EnvelopeFailure.malformed }
        guard env.version == 1 else { throw EnvelopeFailure.unsupportedVersion }
        guard env.owner == owner else { throw EnvelopeFailure.ownerMismatch }
        guard env.grid == FogGridVersion.legacyRoamTile.id else { throw EnvelopeFailure.gridMismatch }
        var out = FogCellBitmap(grid: .legacyRoamTile)
        for entry in env.parents {
            let key = ParentKey(geohash5: entry.p)
            guard entry.p.count == 5, entry.p.allSatisfy({ charValue($0) != nil }),
                  let raw = Data(base64Encoded: entry.bits), let bits = Bits1024(data: raw) else { throw EnvelopeFailure.malformed }
            out.parents[key, default: Bits1024()].formUnion(bits)
        }
        return out
    }
}

// MARK: - Geometry

/// Geohash cell bounds in degrees. Pure math; same alphabet and bit order as `RoamExperienceMath.tileKey`.
enum FogGeohash {
    static func bounds(of code: String) -> (south: Double, west: Double, north: Double, east: Double)? {
        guard !code.isEmpty else { return nil }
        var lat = (-90.0, 90.0), lng = (-180.0, 180.0), even = true
        for ch in code {
            guard let v = FogCellBitmap.charValue(ch) else { return nil }
            for shift in stride(from: 4, through: 0, by: -1) {
                let upper = (v >> shift) & 1 == 1
                if even { let mid = (lng.0 + lng.1) / 2; if upper { lng.0 = mid } else { lng.1 = mid } }
                else { let mid = (lat.0 + lat.1) / 2; if upper { lat.0 = mid } else { lat.1 = mid } }
                even.toggle()
            }
        }
        return (lat.0, lng.0, lat.1, lng.1)
    }
}

public struct FogRenderCell: Equatable {
    public let code: String
    public let south, west, north, east: Double
    public let state: PersonalFogLedger.CellState
    /// Cells are keyed in the server datum (GCJ-02); the overlay must not silently re-project (spec §1a).
    public let datum: WalkingCoordinateDatum
}

/// Axis-aligned window in spherical Web Mercator meters (x east, y north) plus the scale it is drawn at.
public struct FogMercatorWindow: Equatable {
    public static let earthRadius = 6_378_137.0
    public let minX, minY, maxX, maxY: Double
    public let metersPerPixel: Double
    public init(minX: Double, minY: Double, maxX: Double, maxY: Double, metersPerPixel: Double) {
        self.minX = minX; self.minY = minY; self.maxX = maxX; self.maxY = maxY; self.metersPerPixel = metersPerPixel
    }
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }

    public static func x(longitude: Double) -> Double { earthRadius * longitude * .pi / 180 }
    public static func y(latitude: Double) -> Double {
        let clamped = min(max(latitude, -85.05112878), 85.05112878)
        return earthRadius * log(tan(.pi / 4 + clamped * .pi / 360))
    }
    public static func rect(south: Double, west: Double, north: Double, east: Double) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        (x(longitude: west), y(latitude: south), x(longitude: east), y(latitude: north))
    }
    /// Window around a lat/lng box.
    public init(south: Double, west: Double, north: Double, east: Double, metersPerPixel: Double) {
        let r = Self.rect(south: south, west: west, north: north, east: east)
        self.init(minX: r.minX, minY: r.minY, maxX: r.maxX, maxY: r.maxY, metersPerPixel: metersPerPixel)
    }
    public func intersects(minX: Double, minY: Double, maxX: Double, maxY: Double) -> Bool {
        minX < self.maxX && maxX > self.minX && minY < self.maxY && maxY > self.minY
    }
    public func contains(_ other: FogMercatorWindow) -> Bool {
        other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
    }
    /// `fraction` of each side added on every edge (0.25 = the spec's 25 % margin).
    public func expanded(by fraction: Double) -> FogMercatorWindow {
        let dx = width * fraction, dy = height * fraction
        return FogMercatorWindow(minX: minX - dx, minY: minY - dy, maxX: maxX + dx, maxY: maxY + dy, metersPerPixel: metersPerPixel)
    }
}
