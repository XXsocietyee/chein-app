#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/coop/nearby/index` (purpose + consent, 找附近商家,
/// skeleton → venue cards with address and distance, unregistered leads with 电话联系, cy-empty 附近暂无商家 + 刷新附近商家,
/// cy-error 附近商家加载失败 + 重试, kind=permission 当前无法查看附近商家 + 去设置, and the refused-account state).
/// The only fixtures were `core-nearby-merchant(-empty)`: English "Synthetic cafe" rows in both languages and the
/// page left on the consent step, so the sweep never showed a result or an error. These mount the same
/// `NearbyMerchantView` the coop list pushes, offline, consent given and the search already run, rows in the UI
/// language: `t5-coop-nearby`, `-empty`, `-error`, `-location-denied`, `-no-permission`.
@MainActor final class CoopNearbyDesignFixtureReader: CoopFlowReading {
    enum Mode { case content, empty, failure, locationDenied, noPermission }
    let mode: Mode
    let session: CoopFlowSession? = try? CoopFlowSession(accountID: 101, epoch: 1, token: "design-fixture-nearby")

    init(mode: Mode) {
        self.mode = mode
    }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        switch mode {
        case .failure: throw CoopFlowFailure.unavailable
        case .noPermission: throw CoopFlowFailure.permission
        case .empty: return .array([])
        default: break
        }
        let tea: CoopFlowJSON = .object([
            "id": .id(1), "memberId": .id(41), "name": .string(Self.tt("Lantern Lane Tea House", "灯笼巷茶馆")),
            "address": .string(Self.tt("12 Hefang Street, Shangcheng", "上城区河坊街 12 号")), "distance": .string("350")
        ])
        let bikes: CoopFlowJSON = .object([
            "id": .id(2), "memberId": .id(42), "name": .string(Self.tt("Lakeside Bike Rental", "湖畔单车租赁")),
            "address": .string(Self.tt("3 Nanshan Road, Xihu", "西湖区南山路 3 号")), "distance": .string("1200")
        ])
        let lead: CoopFlowJSON = .object([
            "id": .id(3), "name": .string(Self.tt("Old Town Paper Lantern Studio", "老城纸灯笼工坊")),
            "address": .string(Self.tt("8 Zhongshan Middle Road, Shangcheng", "上城区中山中路 8 号")), "distance": .string("2600"),
            "phone": .string("0571 8000 0000"), "canCall": .bool(true)
        ])
        return .array([tea, bikes, lead])
    }

    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement {
        throw CoopFlowFailure.unavailable
    }
}

@MainActor final class CoopNearbyDesignFixtureLocation: RoamDeviceLocationProviding {
    let denied: Bool

    init(denied: Bool) {
        self.denied = denied
    }

    func currentFix() async throws -> RoamDeviceFix {
        if denied { throw PlayExperienceError.disabled }
        guard let point = RoamCoordinate(latitude: 30.2462, longitude: 120.1551) else { throw APIError.invalidRequest }
        return try RoamDeviceFix(coordinate: point, accuracyMeters: 10, measuredAt: Date(), datum: .wgs84)
    }

    func stop() {}
}

/// Pushed page inside a stack, consent given and the search run once on appear, like a player who tapped 找附近商家.
struct CoopNearbyDesignFixture: View {
    @State private var model: NearbyMerchantCoordinator

    init(mode: CoopNearbyDesignFixtureReader.Mode) {
        let reader = CoopNearbyDesignFixtureReader(mode: mode)
        let location = CoopNearbyDesignFixtureLocation(denied: mode == .locationDenied)
        _model = State(initialValue: NearbyMerchantCoordinator(reader: reader, location: location, approved: { true }))
    }

    var body: some View {
        NavigationStack {
            NearbyMerchantView(model: model, startsConsented: true)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
        .task { await model.search(purposeAccepted: true) }
    }
}
#endif
