import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/merchant/marketing/ai-insight/index.{wxml,js}` (`MC-G07`):
/// Window selector, trio metrics, 客源主题 (`facts.sources`), 到店时段, 经营解读, and 经营优化 grow tips.
public enum MerchantAIInsightWindow: Int, CaseIterable, Identifiable, Sendable {
    case days7 = 7
    case days30 = 30
    case days90 = 90

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .days7: return "近7天"
        case .days30: return "近30天"
        case .days90: return "近90天"
        }
    }
}

public enum MerchantAIInsightMetricKind: String, CaseIterable, Identifiable, Sendable {
    case visitors
    case checkins
    case redeems

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .visitors: return "到店"
        case .checkins: return "打卡"
        case .redeems: return "核销"
        }
    }

    public var unit: String {
        switch self {
        case .visitors: return "位玩家到店"
        case .checkins: return "次打卡"
        case .redeems: return "单核销"
        }
    }
}

public struct MerchantAIInsightSourceItem: Identifiable, Decodable, Equatable, Sendable {
    public let name: String
    public let count: Int
    public let pct: String
    public let widthPercent: Double

    public var id: String { name }

    public var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "主" : String(trimmed.prefix(1))
    }

    public init(name: String, count: Int, pct: String, widthPercent: Double) {
        self.name = name
        self.count = count
        self.pct = pct
        self.widthPercent = widthPercent
    }
}

public struct MerchantAIInsightGrowTip: Identifiable, Equatable, Sendable {
    public enum Key: String, Sendable {
        case coop
        case citynode
        case coupon
        case aiNpc = "ai-npc"
    }

    public let key: Key
    public let title: String
    public let subtitle: String
    public let cta: String

    public var id: String { key.rawValue }

    public init(key: Key, title: String, subtitle: String, cta: String) {
        self.key = key
        self.title = title
        self.subtitle = subtitle
        self.cta = cta
    }

    public static func visibleTips(
        canCoop: Bool,
        canCityNode: Bool,
        canCoupon: Bool,
        canAINPC: Bool
    ) -> [MerchantAIInsightGrowTip] {
        var result: [MerchantAIInsightGrowTip] = []
        if canCoop {
            result.append(.init(key: .coop, title: "承接热门主题", subtitle: "开放门店档期，吸引玩家到店打卡", cta: "去合作中心"))
        }
        if canCityNode {
            result.append(.init(key: .citynode, title: "设置城市节点", subtitle: "让门店成为城市探索路线的一站", cta: "去设置"))
        }
        if canCoupon {
            result.append(.init(key: .coupon, title: "发放消费券", subtitle: "用核销礼券提升玩家复购率", cta: "去发券"))
        }
        if canAINPC {
            result.append(.init(key: .aiNpc, title: "配置 AI 店铺角色", subtitle: "用你的声音和形象接待到店玩家", cta: "去配置"))
        }
        return result
    }
}

public enum MerchantAIInsightCopy {
    public static let pageTitle = "店铺参谋"
    public static let updatingText = "正在更新经营数据…"
    public static let loadFailedTitle = "店铺数据加载失败"
    public static let incompleteTitle = "店铺数据没加载完整"
    public static let sourceSectionTitle = "客源主题"
    public static let recentVisitorsTitle = "最近到店玩家"
    public static let aiSectionTitle = "经营解读"
    public static let opportunityTag = "机会"
    public static let problemTag = "问题"
    public static let lowSampleNote = "数据还少，以下解读仅供参考"
    public static let growSectionTitle = "经营优化"
}

public struct MerchantAIInsightClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func fetchSources(days: MerchantAIInsightWindow, token: String) async throws -> [MerchantAIInsightSourceItem] {
        struct RawSource: Decodable {
            let topicName: String?
            let name: String?
            let count: Int?
        }
        struct FactsPayload: Decodable {
            let sources: [RawSource]?
        }
        struct InsightEnvelopeData: Decodable {
            let facts: FactsPayload?
        }
        let data: InsightEnvelopeData = try await MPGapHTTP.postForm(
            configuration: configuration,
            transport: transport,
            path: "api/ai/merchant/insight",
            fields: ["days": String(days.rawValue)],
            token: token
        )
        let raw = data.facts?.sources ?? []
        let total = max(1, raw.reduce(0) { $0 + max(0, $1.count ?? 0) })
        let maxCount = max(1, raw.map { max(0, $0.count ?? 0) }.max() ?? 1)
        return raw.map { row in
            let count = max(0, row.count ?? 0)
            let name = (row.topicName ?? row.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let pctValue = Int((Double(count) / Double(total) * 100.0).rounded())
            let width = Double(count) / Double(maxCount) * 100.0
            return MerchantAIInsightSourceItem(
                name: name.isEmpty ? "未知主题" : name,
                count: count,
                pct: "\(pctValue)%",
                widthPercent: width
            )
        }
    }
}
