#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/coop/invite/index` (发起协作邀请; ① 关联主题 with
/// 选择我发布的主题 and 该主题不在招商期; ③ 邀请对象 + 已选 N, merchant rows with their activity types; cy-empty
/// 还没有可关联的主题 / 还没有可合作的商家; per-section cy-error + 重试; 当前身份不能… refusal; 登录后发起协作邀请 +
/// 去登录; skeleton while loading). The only host was the UI-test workbench (`CoopFlowFixtureHost`: English
/// "Synthetic owned topic / Synthetic merchant" rows, sign-out button and offline line on top). These mount the same
/// `CoopFlowNewInvitationView` the coop list pushes, offline, rows in the UI language: `t5-coop-invite`,
/// `-no-topics`, `-no-targets`, `-error`, `-no-permission`, `-signed-out`, `-loading`. No send leaves the fixture.
@MainActor final class CoopInviteDesignFixtureReader: ObservableObject, CoopFlowReading {
    enum Mode { case content, noTopics, noTargets, failure, noPermission, signedOut, loading }
    let mode: Mode
    @Published var session: CoopFlowSession?

    init(mode: Mode) {
        self.mode = mode
        session = mode == .signedOut ? nil : (try? CoopFlowSession(accountID: 4103, epoch: 1, token: "design-fixture"))
    }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    private static func day(_ days: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date().addingTimeInterval(days * 24 * 60 * 60))
    }

    private static func ownedTopic(_ id: Int, _ name: String, _ place: String, days: Double, open: Bool) -> CoopFlowJSON {
        .object(["id": .id(id), "name": .string(name), "startDate": .string(day(days)), "addressName": .string(place), "inviteWindowOpen": .bool(open)])
    }

    private static func merchant(_ id: Int, _ name: String, _ types: String) -> CoopFlowJSON {
        .object(["id": .id(id + 500), "memberId": .id(id), "name": .string(name), "suitActivityTypes": .string(types)])
    }

    private static var topics: CoopFlowJSON {
        .object(["rows": .array([
            ownedTopic(61, tt("West Lake Lights Night Walk", "西湖灯光夜游"), tt("Broken Bridge east gate", "断桥东入口"), days: 9, open: true),
            ownedTopic(62, tt("Canal Spring Orienteering", "运河春日定向赛"), tt("Gongchen Bridge", "拱宸桥"), days: 21, open: true),
            ownedTopic(63, tt("Old Town Tea Street Chapter", "老城茶街章节"), tt("Hefang Street", "河坊街"), days: 2, open: false)
        ])])
    }

    private static var merchants: CoopFlowJSON {
        .array([
            merchant(7101, tt("Lantern Lane Teahouse", "灯笼巷茶馆"), tt("Tea tasting · Check-in stop", "茶饮品鉴 · 打卡点")),
            merchant(7102, tt("Lakeside Bike Rental", "湖畔单车租赁"), tt("Cycling · Supply station", "骑行 · 补给站")),
            merchant(7103, tt("Old Town Paper Lantern Workshop", "老城纸灯笼工坊"), tt("Craft workshop", "手作体验"))
        ])
    }

    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        switch mode {
        case .loading:
            try await Task.sleep(for: .seconds(600))
            throw CancellationError()
        case .failure:
            throw APIError.httpStatus(503)
        case .noPermission:
            throw CoopFlowFailure.server(403, nil)
        default:
            break
        }
        switch resource {
        case .ownedTopics:
            return mode == .noTopics ? .object(["rows": .array([])]) : Self.topics
        case .merchants:
            return mode == .noTargets ? .array([]) : Self.merchants
        case .clubs:
            return .array([])
        case .inviteRequests:
            return .object(["rows": .array([]), "nextCursor": .null, "hasMore": .bool(false)])
        case .supplyStations:
            return .object(["requiresSupplyStation": .bool(false), "stations": .array([])])
        default:
            throw CoopFlowFailure.unavailable
        }
    }

    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement {
        throw CoopFlowFailure.unavailable
    }
}

struct CoopInviteDesignFixture: View {
    @State private var reader: CoopInviteDesignFixtureReader

    init(mode: CoopInviteDesignFixtureReader.Mode) {
        _reader = State(initialValue: CoopInviteDesignFixtureReader(mode: mode))
    }

    var body: some View {
        NavigationStack {
            CoopFlowNewInvitationView(reader: reader, operationScope: nil)
        }
        .environment(\.merchantOpenSignIn, {})
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
