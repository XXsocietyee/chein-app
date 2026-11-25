import Foundation

/// Models for `play-roam` MP gaps (`PLAY-6`, `PLAY-8`, `ROAM-9`, `RSTAMP-3`, `OCARDS-3/4`, `JREPORT-2`).

// MARK: - PLAY-6 / PLAY-8: Play Tools Sheet & Captain Lead Tools

public struct PlayLeadSkipRequest: Identifiable, Equatable, Sendable {
    public let id: String
    public let memberID: Int
    public let nodeID: Int
    public let nickname: String
    public let nodeName: String

    public init(memberID: Int, nodeID: Int, nickname: String, nodeName: String) {
        self.id = "\(memberID)-\(nodeID)"
        self.memberID = memberID
        self.nodeID = nodeID
        self.nickname = nickname
        self.nodeName = nodeName
    }
}

public struct PlayLeadToolsState: Equatable, Sendable {
    public let exists: Bool
    public let isLeader: Bool
    public let isDirectorRun: Bool
    public let skipRequests: [PlayLeadSkipRequest]

    public init(
        exists: Bool = false,
        isLeader: Bool = false,
        isDirectorRun: Bool = false,
        skipRequests: [PlayLeadSkipRequest] = []
    ) {
        self.exists = exists
        self.isLeader = isLeader
        self.isDirectorRun = isDirectorRun
        self.skipRequests = skipRequests
    }
}

public struct PlayStoryThoughtItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDone: Bool
    public let progress: Int
    public let needed: Int

    public init(id: String, name: String, isDone: Bool, progress: Int, needed: Int) {
        self.id = id
        self.name = name
        self.isDone = isDone
        self.progress = progress
        self.needed = needed
    }

    public var statusText: String {
        if isDone { return "已应验" }
        if needed > 0 { return "\(progress)/\(needed) 步" }
        return "还没应验"
    }
}

// MARK: - ROAM-9: In-Session Roam Tools & Nearby Runners

public struct RoamRunnerShopPhoto: Equatable, Sendable {
    public let name: String
    public let image: String
    public init(name: String, image: String) {
        self.name = name
        self.image = image
    }
}

/// One nearby runner from `utils/roam-runners.js` `normalizeRunners`.
/// There is no greet request in `pages/roam/index.js`. `greeted` stays a local flag.
public struct RoamNearbyRunner: Identifiable, Equatable, Sendable {
    public static let colors = ["#A78BFA", "#22D3EE", "#F0ABFC", "#FDBA74", "#67E8F9", "#FCA5A5"]
    public let id: Int
    public let nickname: String
    public let avatarURL: String?
    public let distanceMeters: Int?
    public var greeted: Bool
    public let latitude: Double?
    public let longitude: Double?
    public let elapsedLabel: String
    public let sinceLabel: String
    public let colorHex: String
    public let initial: String
    public let explorePercent: Int?
    public let shopCount: Int?
    public let shopPhotos: [RoamRunnerShopPhoto]

    public init(id: Int, nickname: String, avatarURL: String? = nil, distanceMeters: Int? = nil, greeted: Bool = false,
                latitude: Double? = nil, longitude: Double? = nil, elapsedLabel: String = "", sinceLabel: String = "",
                colorHex: String = "", initial: String = "", explorePercent: Int? = nil, shopCount: Int? = nil,
                shopPhotos: [RoamRunnerShopPhoto] = []) {
        self.id = id
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.distanceMeters = distanceMeters
        self.greeted = greeted
        self.latitude = latitude
        self.longitude = longitude
        self.elapsedLabel = elapsedLabel
        self.sinceLabel = sinceLabel
        self.colorHex = colorHex
        self.initial = initial
        self.explorePercent = explorePercent
        self.shopCount = shopCount
        self.shopPhotos = shopPhotos
    }

    /// Drops rows with no positive `memberId` or a non-finite `lat` / `lng`.
    public static func normalized(_ rows: [PlayWireValue]) -> [RoamNearbyRunner] {
        rows.compactMap { row in
            guard let id = row["memberId"].tolerantInteger, id > 0,
                  let lat = Self.finite(row["lat"]), let lng = Self.finite(row["lng"]) else { return nil }
            let nickname = row["nickname"].text.flatMap { $0.isEmpty ? nil : $0 } ?? "漫游者"
            let elapsed = Self.nonNegative(row["elapsedSec"])
            let explore = Self.nonNegative(row["explorePct"]).map { min(99, Int($0)) }
            let shops = Self.nonNegative(row["shops"]).map { Int($0) }
            let photos = (row["shopPhotos"].array ?? []).compactMap { photo -> RoamRunnerShopPhoto? in
                guard let image = photo["image"].text, !image.isEmpty else { return nil }
                return RoamRunnerShopPhoto(name: photo["name"].text ?? "", image: image)
            }
            return RoamNearbyRunner(id: id, nickname: nickname, avatarURL: row["avatar"].text.flatMap { $0.isEmpty ? nil : $0 },
                                    latitude: lat, longitude: lng, elapsedLabel: elapsedLabel(elapsed), sinceLabel: sinceLabel(elapsed),
                                    colorHex: colors[id % colors.count], initial: String(nickname.prefix(1)),
                                    explorePercent: explore, shopCount: shops, shopPhotos: photos)
        }
    }

    private static func finite(_ value: PlayWireValue) -> Double? {
        switch value {
        case .integer(let n): return Double(n)
        case .number(let n) where n.isFinite: return n
        case .string(let s):
            guard let n = Double(s), n.isFinite else { return nil }
            return n
        default: return nil
        }
    }

    private static func nonNegative(_ value: PlayWireValue) -> Double? {
        switch value {
        case .integer(let n) where n >= 0: return Double(n)
        case .number(let n) where n.isFinite && n >= 0: return n
        case .string(let raw):
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil, let n = Double(text), n.isFinite, n >= 0 else { return nil }
            return n
        default: return nil
        }
    }

    public static func elapsedLabel(_ seconds: Double?) -> String {
        guard let seconds else { return "" }
        let s = max(0, Int(seconds.rounded(.down)))
        let h = s / 3600, m = (s % 3600) / 60, ss = s % 60
        func pad(_ v: Int) -> String { v < 10 ? "0\(v)" : String(v) }
        return h > 0 ? "\(h):\(pad(m)):\(pad(ss))" : "\(pad(m)):\(pad(ss))"
    }

    public static func sinceLabel(_ seconds: Double?) -> String {
        guard let seconds else { return "" }
        let s = max(0, Int(seconds.rounded(.down)))
        if s < 600 { return "刚出发" }
        if s < 3600 { return "走了半小时上下" }
        return "走了一个多小时"
    }
}

/// `utils/roam-fog-preference.js`. Stored true means the fog layer is off. Missing is fog on. Not uploaded.
public enum RoamFogPreference {
    public static let storageKey = "roam_fog_off"
    public static func fogOff(in defaults: UserDefaults) -> Bool {
        (defaults.object(forKey: storageKey) as? Bool) == true
    }
    public static func setFogOff(_ off: Bool, in defaults: UserDefaults) -> Bool {
        let stored = off == true
        defaults.set(stored, forKey: storageKey)
        return stored
    }
}

/// `utils/map-style.js` free-map kind. Key `cy_map_kind`. Missing or unknown is black.
/// This is not the standard / satellite / dark picker.
public enum FreeMapKind: String, CaseIterable, Sendable {
    case white
    case black
    case paper
    case year2077 = "2077"
    public static let storageKey = "cy_map_kind"
    public var label: String {
        switch self {
        case .white: return "白"
        case .black: return "黑"
        case .paper: return "纸本"
        case .year2077: return "2077"
        }
    }
    public static func read(in defaults: UserDefaults) -> Self {
        guard let raw = defaults.string(forKey: storageKey), let kind = Self(rawValue: raw) else { return .black }
        return kind
    }
    public static func save(_ kind: Self, in defaults: UserDefaults) -> Bool {
        defaults.set(kind.rawValue, forKey: storageKey)
        return true
    }
}

public enum RoamMapStyleOption: String, CaseIterable, Identifiable, Sendable {
    case standard
    case satellite
    case dark

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .standard: return "标准"
        case .satellite: return "卫星"
        case .dark: return "夜间"
        }
    }
}

// MARK: - RSTAMP-3: Citystamp Tear & Scratch Slip

public struct CityStampSlipData: Equatable, Sendable {
    public let place: String
    public let timeLabel: String
    public let serial: String
    public let senderTime: String
    public let photoURL: String?
    public let caption: String?

    public init(
        place: String,
        timeLabel: String,
        serial: String,
        senderTime: String,
        photoURL: String? = nil,
        caption: String? = nil
    ) {
        self.place = place
        self.timeLabel = timeLabel
        self.serial = serial
        self.senderTime = senderTime
        self.photoURL = photoURL
        self.caption = caption
    }
}

// MARK: - OCARDS-3 / OCARDS-4: Object Cards Category & Rename

public struct ObjectCardCategoryOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

public enum ObjectCardRenameValidator {
    public static let maxLength = 64

    public static func clamped(_ text: String) -> String {
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength))
    }

    public static func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxLength
    }
}

// MARK: - JREPORT-2: Journey Report Node Photo

public struct JourneyReportNodePhotoItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let nodeName: String
    public let photoURL: String

    public init(id: String, nodeName: String, photoURL: String) {
        self.id = id
        self.nodeName = nodeName
        self.photoURL = photoURL
    }
}
