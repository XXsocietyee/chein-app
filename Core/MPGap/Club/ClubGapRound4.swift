import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/club/detail/index` (`CLB-detail-09`, `CLB-r7-A-04`):
/// Managed projects with 活动导演台 (`gameModuleEnabled`) + 选择导演场次 + 场次工具.
public struct ClubManagedDirectorSession: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let timeLabel: String?

    public init(id: Int, title: String, timeLabel: String? = nil) {
        self.id = id
        self.title = title
        self.timeLabel = timeLabel
    }
}

public struct ClubManagedProjectDirectorItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let gameModuleEnabled: Bool
    public let sessions: [ClubManagedDirectorSession]

    public init(
        id: Int,
        title: String,
        gameModuleEnabled: Bool,
        sessions: [ClubManagedDirectorSession] = []
    ) {
        self.id = id
        self.title = title
        self.gameModuleEnabled = gameModuleEnabled
        self.sessions = sessions
    }
}

public enum ClubSessionToolChoice: String, CaseIterable, Identifiable, Sendable {
    case rosterAndVerify
    case assignLeader
    case notifySessionMembers

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rosterAndVerify: return "名册与核销"
        case .assignLeader: return "分配领队"
        case .notifySessionMembers: return "通知本场成员"
        }
    }

    public var systemImage: String {
        switch self {
        case .rosterAndVerify: return "checklist"
        case .assignLeader: return "person.badge.key"
        case .notifySessionMembers: return "bell.badge"
        }
    }
}

/// MP `pages/club/topic-story/index` (`CLB-topic-story-04`):
/// Station location with optional coordinates for opening in Apple Maps (`MKMapItem`).
public struct ClubStoryStopLocation: Equatable, Sendable {
    public let name: String
    public let address: String
    public let latitude: Double?
    public let longitude: Double?

    public var hasCoordinates: Bool {
        guard let latitude, let longitude else { return false }
        return latitude.isFinite && longitude.isFinite && !(latitude == 0 && longitude == 0)
    }

    public var mapActionTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "在地图中打开" : "在地图中打开 \(trimmed)"
    }

    public init(name: String, address: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// MP `pages/club/apply/index` (`CLB-apply-05`):
/// Up to 9 `certImages` URLs with upload/error slot tracking.
public struct ClubApplyCertImagesDraft: Equatable, Sendable {
    public static let maxCount = 9
    public var uploadedURLs: [String]
    public var failedIndices: Set<Int>

    public var remainingCapacity: Int {
        max(0, Self.maxCount - uploadedURLs.count)
    }

    public init(uploadedURLs: [String] = [], failedIndices: Set<Int> = []) {
        self.uploadedURLs = Array(uploadedURLs.prefix(Self.maxCount))
        self.failedIndices = failedIndices
    }
}

/// MP `components/cy/fe-reference-range` (`CLB-r7-D-01`):
/// Date range filter + export client for `/api/fe/reference-settlement/payer/export`.
public struct FEReferenceRangeFilter: Equatable, Sendable {
    public var fromDate: String
    public var toDate: String

    public var isActive: Bool {
        !fromDate.isEmpty || !toDate.isEmpty
    }

    public mutating func clear() {
        fromDate = ""
        toDate = ""
    }

    public init(fromDate: String = "", toDate: String = "") {
        self.fromDate = fromDate
        self.toDate = toDate
    }

    /// CLB-r10-nat-detail-12: the MP `picker mode="date"` value, `YYYY-MM-DD` on the Beijing calendar.
    public static func date(_ text: String) -> Date? {
        text.isEmpty ? nil : dayFormatter.date(from: text)
    }
    public static func text(_ date: Date) -> String { dayFormatter.string(from: date) }
    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

public struct ClubFEReferenceExportClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func exportPayerCSV(range: FEReferenceRangeFilter, token: String) async throws -> String {
        var items: [URLQueryItem] = []
        if !range.fromDate.isEmpty { items.append(URLQueryItem(name: "from", value: range.fromDate)) }
        if !range.toDate.isEmpty { items.append(URLQueryItem(name: "to", value: range.toDate)) }
        struct ExportPayload: Decodable { let url: String? }
        let payload: ExportPayload = try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: "api/fe/reference-settlement/payer/export",
            queryItems: items,
            token: token
        )
        return payload.url ?? ""
    }

    public func exportMerchantCSV(range: FEReferenceRangeFilter, token: String) async throws -> String {
        var items: [URLQueryItem] = []
        if !range.fromDate.isEmpty { items.append(URLQueryItem(name: "from", value: range.fromDate)) }
        if !range.toDate.isEmpty { items.append(URLQueryItem(name: "to", value: range.toDate)) }
        struct ExportPayload: Decodable { let url: String? }
        let payload: ExportPayload = try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: "api/fe/reference-settlement/merchant/export",
            queryItems: items,
            token: token
        )
        return payload.url ?? ""
    }
}

/// MP `pages/club/group-code/index` (`CLB-group-code-05`):
/// Session picker state machine (selecting / empty / invalid / noPermission).
public enum ClubGroupCodeStepState: Equatable, Sendable {
    case selecting([ClubManagedDirectorSession])
    case empty
    case invalid
    case noPermission
}

public enum ClubRound4Copy {
    public static let directorRowTitle = "活动导演台"
    public static let noSessionsToast = "还没有可管理的活动场次"
    public static let sessionToolsTitle = "场次工具"
    public static let certSectionTitle = "资质 / 案例图片"
    public static let certMaxReached = "最多9张"
    public static let rangeStartPlaceholder = "开始日期"
    public static let rangeEndPlaceholder = "结束日期"
    public static let rangeClear = "清除"
    public static let rangeUnset = "未设置"
    public static let rangeExport = "导出"
    public static let groupCodeSelectTitle = "选择场次"
    public static let groupCodeEmptyTitle = "暂无可带队的场次"
    public static let groupCodeInvalidTitle = "缺少路线或场次信息"
    public static let groupCodeNoPermission = "当前身份不能出码"
    public static let groupCodeEnterManage = "进入俱乐部管理"
}
