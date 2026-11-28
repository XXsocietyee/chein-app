#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/coop/settlement-detail/index?source=finance`
/// (结算详情 title; organizer perspective, topic name + status badge, 我的分润 amount; 费用明细 lines 总销售额 /
/// 核销销售额 / 平台 / 商家 / 我的分润; 结算进度 timeline; cy-skeleton loading; cy-empty 结算记录不可见 + 返回结算列表;
/// cy-error 结算详情加载失败 + 重试; the organizer-only permission failure; signed out). The page had no design
/// fixture. These mount the same `CoopSettlementDetailView` the 分润明细 page pushes, offline, topic names in the UI
/// language: `t5-coop-settlement`, `-awaiting`, `-unsettled`, `-missing`, `-error`, `-no-permission`,
/// `-signed-out`, `-loading`. Nothing here writes or moves money.
@MainActor final class CoopSettlementDesignFixtureReader: ObservableObject, CoopFlowReading {
    enum Mode { case credited, awaiting, unsettled, missing, failure, noPermission, signedOut, loading }
    let mode: Mode
    @Published var session: CoopFlowSession?

    init(mode: Mode) {
        self.mode = mode
        session = mode == .signedOut ? nil : (try? CoopFlowSession(accountID: 4102, epoch: 1, token: "design-fixture"))
    }

    var recordID: Int {
        switch mode {
        case .awaiting: return 42
        case .unsettled: return 43
        case .missing: return 99
        default: return 41
        }
    }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    private static func stamp(days: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date().addingTimeInterval(days * 24 * 60 * 60))
    }

    private static func topic(_ id: Int, _ name: String, settled: Bool, arrived: Bool, income: Decimal?, total: Decimal, verified: Decimal,
                              platform: Decimal, merchant: Decimal, payable: String?, payout: String?) -> CoopFlowJSON {
        var row: [String: CoopFlowJSON] = [
            "topicId": .id(id), "topicName": .string(name),
            "settled": .bool(settled), "myIncomeArrived": .bool(arrived),
            "totalSales": .number(total), "verifiedSales": .number(verified),
            "platformAmount": .number(platform), "merchantTotal": .number(merchant),
            "myIncome": income.map { CoopFlowJSON.number($0) } ?? .null
        ]
        if let payable { row["merchantPayableTime"] = .string(payable) }
        if let payout { row["merchantPayoutTime"] = .string(payout) }
        return .object(row)
    }

    private static var topics: CoopFlowJSON {
        .object(["topics": .array([
            topic(41, tt("West Lake Lights Night Walk", "西湖灯光夜游"), settled: true, arrived: true, income: Decimal(string: "236.40"),
                  total: 1880, verified: 1640, platform: 164, merchant: Decimal(string: "1239.60") ?? 0,
                  payable: stamp(days: -9), payout: stamp(days: -6)),
            topic(42, tt("Canal Spring Orienteering", "运河春日定向赛"), settled: true, arrived: false, income: Decimal(string: "128.50"),
                  total: 960, verified: 880, platform: 88, merchant: Decimal(string: "663.50") ?? 0,
                  payable: stamp(days: 2), payout: nil),
            topic(43, tt("Old Town Tea Street Chapter", "老城茶街章节"), settled: false, arrived: false, income: nil,
                  total: 420, verified: 300, platform: 30, merchant: 0, payable: nil, payout: nil)
        ])])
    }

    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        switch mode {
        case .loading:
            try await Task.sleep(for: .seconds(600))
            throw CancellationError()
        case .failure:
            throw APIError.httpStatus(503)
        case .noPermission:
            throw CoopFlowFailure.server(403, Self.tt("Only club hosts and co-hosts can see the revenue share.", "仅主理人与联席主理人可查看分润"))
        default:
            return Self.topics
        }
    }

    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement {
        throw CoopFlowFailure.unavailable
    }
}

struct CoopSettlementDesignFixture: View {
    @State private var reader: CoopSettlementDesignFixtureReader

    init(mode: CoopSettlementDesignFixtureReader.Mode) {
        _reader = State(initialValue: CoopSettlementDesignFixtureReader(mode: mode))
    }

    var body: some View {
        NavigationStack {
            CoopSettlementDetailView(reader: reader, source: .finance, id: reader.recordID)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
