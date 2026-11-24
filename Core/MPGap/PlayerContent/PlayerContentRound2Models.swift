import Foundation

/// Round-2 Core models for remaining `player-content` MP gaps:
/// `PC-A-1-6`, `PC-A-2-1/5`, `PC-A-3-3`, `PC-A-4-2`, `PC-A-5-1/2/3`, `PC-A-6-2`,
/// `PC-B-1-11`, `PC-C-1-1/6`, `PC-D-1-6`, `PC-D-3-2`, `PC-D-6-2`, `PC-D-9-1/3/4`.

// MARK: - PC-A-5-1/2/3: Map-First Search Explorer

public struct SearchMapPlaceItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let address: String
    public let latitude: Double
    public let longitude: Double
    public let kindLabel: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        address: String,
        latitude: Double,
        longitude: Double,
        kindLabel: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.kindLabel = kindLabel
    }
}

public struct SearchMapCategoryChip: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - PC-A-2-1 / A-2-5: Paged Play Template Shelf

public struct TemplateShelfPagedItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let groupName: String
    public let previewOnly: Bool

    public init(id: Int, title: String, groupName: String, previewOnly: Bool = false) {
        self.id = id
        self.title = title
        self.groupName = groupName
        self.previewOnly = previewOnly
    }
}

public enum TemplateShelfPagination {
    public static let mpPageSize = 50

    public static func hasMore(loadedInPage: Int, totalLoaded: Int, serverTotal: Int?) -> Bool {
        if loadedInPage < mpPageSize { return false }
        if let serverTotal { return totalLoaded < serverTotal }
        return true
    }

    public static func grouped(_ items: [TemplateShelfPagedItem]) -> [(group: String, items: [TemplateShelfPagedItem])] {
        var order: [String] = []
        var buckets: [String: [TemplateShelfPagedItem]] = [:]
        for item in items {
            let key = item.groupName.isEmpty ? "其他玩法" : item.groupName
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}

// MARK: - PC-A-3-3 / A-4-2: Unified Search & Validation

public enum UnifiedSearchResultKind: String, Equatable, Sendable {
    case topic
    case activity
    case template
    case post
    case club
    case merchant
}

public struct UnifiedSearchResultRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let targetID: Int
    public let kind: UnifiedSearchResultKind
    public let title: String
    public let subtitle: String

    public init(id: String, targetID: Int, kind: UnifiedSearchResultKind, title: String, subtitle: String) {
        self.id = id
        self.targetID = targetID
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
    }
}

public enum UnifiedSearchValidator {
    public static let emptyPrompt = "请输入关键词或选择类别"

    public static func canSubmit(keyword: String, categoryID: Int?) -> Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || categoryID != nil
    }
}

// MARK: - PC-A-6-2 / A-8-3: Template Detail Scope & Stat Cards

public struct TemplateDetailQueryScope: Equatable, Sendable {
    public let templateID: Int
    public let isMyScope: Bool
    public let isMerchantOperationScope: Bool
    public let isReadonly: Bool

    public init(templateID: Int, scope: String?, operationScope: String?, readonly: String?) {
        self.templateID = templateID
        self.isMyScope = (scope == "my")
        self.isMerchantOperationScope = (operationScope == "MERCHANT" || scope == "MERCHANT")
        self.isReadonly = (readonly == "1" || readonly == "true")
    }
}

// MARK: - PC-B-1-11 / C-1-1 / C-1-6: Topic & Activity Detail Gap Models

public struct TopicOwnerReviewChipState: Equatable, Sendable {
    public let label: String
    public let rejectReason: String?
    public let isDanger: Bool

    public static func from(userStatus: Int?, status: Int?, rejectReason: String?) -> TopicOwnerReviewChipState? {
        if userStatus == 0 || status == 0 {
            return TopicOwnerReviewChipState(label: "审核中", rejectReason: nil, isDanger: false)
        }
        if userStatus == 2 || status == 2 {
            return TopicOwnerReviewChipState(label: "未通过", rejectReason: rejectReason, isDanger: true)
        }
        if status == 3 {
            return TopicOwnerReviewChipState(label: "已下架", rejectReason: nil, isDanger: true)
        }
        return nil
    }
}

public struct ActivityTicketWindowInfo: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let windowText: String
    public let deadlineText: String?
    public let isExpiredOrStarted: Bool
    public let lineupNames: [String]

    public init(
        id: Int,
        name: String,
        windowText: String,
        deadlineText: String? = nil,
        isExpiredOrStarted: Bool = false,
        lineupNames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.windowText = windowText
        self.deadlineText = deadlineText
        self.isExpiredOrStarted = isExpiredOrStarted
        self.lineupNames = lineupNames
    }
}

// MARK: - PC-D-3-2 / D-6-2 / D-9-4: Article Rich Blocks, 6-Month Analysis & IM Menu

public enum SocialArticleRichBlock: Identifiable, Equatable, Sendable {
    case text(id: String, content: String)
    case image(id: String, url: String)
    case link(id: String, title: String, url: String)

    public var id: String {
        switch self {
        case .text(let id, _), .image(let id, _), .link(let id, _, _): return id
        }
    }
}

public enum WalletAnalysisPagingPolicy {
    public static let mpPageSize = 200

    public static func shouldContinue(pageItemCount: Int, oldestItemDate: Date?, cutoffDate: Date) -> Bool {
        guard pageItemCount >= mpPageSize else { return false }
        if let oldestItemDate, oldestItemDate < cutoffDate { return false }
        return true
    }
}

public enum IMComposerPlusItem: String, CaseIterable, Identifiable, Sendable {
    case image
    case location
    case route
    case poll

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .image: return "图片"
        case .location: return "位置"
        case .route: return "路线"
        case .poll: return "投票"
        }
    }
    public var systemImage: String {
        switch self {
        case .image: return "photo"
        case .location: return "mappin.and.ellipse"
        case .route: return "map"
        case .poll: return "chart.bar"
        }
    }
}
