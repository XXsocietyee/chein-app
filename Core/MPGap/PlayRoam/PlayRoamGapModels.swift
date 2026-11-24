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

public struct RoamNearbyRunner: Identifiable, Equatable, Sendable {
    public let id: Int
    public let nickname: String
    public let avatarURL: String?
    public let distanceMeters: Int?
    public var greeted: Bool

    public init(id: Int, nickname: String, avatarURL: String? = nil, distanceMeters: Int? = nil, greeted: Bool = false) {
        self.id = id
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.distanceMeters = distanceMeters
        self.greeted = greeted
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
