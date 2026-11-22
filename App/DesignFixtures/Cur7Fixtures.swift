#if DEBUG
import SwiftUI

/// DEBUG fixtures for the screens that landed on ui/h-offline and ui/h-sweep.
/// Each surface has one normal fixture and one non-happy fixture. Data is synthetic.
/// Unknown values are an em dash. A decoded 0 stays 0. Money stays behind `ReviewedAreaSwitch`.
/// Launch with `--design-fixture cur7-<id>`. Host is `fixture.example`, never `www.chengyinhub.com`.
enum Cur7Fixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "cur7-offline-banner": return frame("Offline banner", Cur7OfflineBannerFixture(stillOffline: false))
        case "cur7-offline-banner-still": return frame("Offline banner · still offline", Cur7OfflineBannerFixture(stillOffline: true))
        case "cur7-sync-status": return frame("Sync status", Cur7SyncStatusFixture(offline: false))
        case "cur7-sync-status-offline": return frame("Sync status · offline", Cur7SyncStatusFixture(offline: true))
        case "cur7-poi-writer": return frame("Challenge POI writer", Cur7POIFixture(live: true))
        case "cur7-poi-writer-blocked": return frame("Challenge POI writer · unavailable", Cur7POIFixture(live: false))
        case "cur7-myproject-mutation": return frame("My-project mutation", Cur7MutationFixture(failed: false))
        case "cur7-myproject-mutation-failed": return frame("My-project mutation · failed", Cur7MutationFixture(failed: true))
        case "cur7-merchant-chip": return frame("Merchant home chip", Cur7MerchantChipFixture(unknown: false), merchant: true)
        case "cur7-merchant-chip-unknown": return frame("Merchant home chip · unknown", Cur7MerchantChipFixture(unknown: true), merchant: true)
        case "cur7-character-sheet": return frame("Character sheet", Cur7CharacterSheetFixture(unknown: false))
        case "cur7-character-sheet-unknown": return frame("Character sheet · unknown", Cur7CharacterSheetFixture(unknown: true))
        default: return nil
        }
    }

    @MainActor private static func frame<V: View>(_ title: String, _ view: V, merchant: Bool = false) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 0) {
                view
                Text(verbatim: "DEBUG fixture · " + title)
                    .cyText(.caption)
                    .foregroundStyle(CYColor.textSecondary)
                    .padding(CYSpacing.md)
                    .accessibilityLabel(Text(verbatim: title))
            }
            .accessibilityElement(children: .contain)
            .themeDomain(merchant ? .merchant : .player)
            .preferredColorScheme(merchant ? .light : .dark)
        )
    }

    static func poiNode() -> RoamNodeDetail? {
        let json = #"{"poiId":7,"name":"闸口","description":"夜航","lat":30.25,"lng":120.16,"radiusM":80,"validationMethod":1,"completed":false}"#
        return try? JSONDecoder().decode(RoamNodeDetail.self, from: Data(json.utf8))
    }
}

@MainActor private struct Cur7OfflineBannerFixture: View {
    let stillOffline: Bool
    private let cachedAt = Date(timeIntervalSince1970: 1_762_000_000)

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYStatusOfflineBanner(cachedAt: cachedAt, stillOffline: stillOffline, serious: stillOffline, onRetry: {})
                .accessibilityIdentifier("cur7.offline.banner")
            SearchMapOfflineBannerView(state: .cached(cachedAt), stillOffline: stillOffline, retry: {})
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(verbatim: stillOffline ? "Search map offline, still offline" : "Search map offline, cached"))
                .accessibilityIdentifier("cur7.offline.search")
        }
        .padding(CYSpacing.md)
        .accessibilityElement(children: .contain)
    }
}

@MainActor private struct Cur7SyncStatusFixture: View {
    let offline: Bool
    private let tracker: RoamSyncStatusTracker

    init(offline: Bool) {
        self.offline = offline
        var tracker = RoamSyncStatusTracker()
        if offline {
            tracker.recordOutcome(netFail: true)
            tracker.recordOutcome(netFail: true)
        }
        self.tracker = tracker
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if tracker.isOffline {
                CYStatusOfflineBanner(messageKey: RoamSyncStatusTracker.offlineKey, serious: true, onRetry: {})
                    .accessibilityIdentifier("cur7.sync.banner")
            }
            Text(verbatim: String(tracker.consecutiveFailures))
                .cyText(.numericBody)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityLabel(Text(verbatim: "Sync failures \(tracker.consecutiveFailures)"))
                .accessibilityIdentifier("cur7.sync.failures")
        }
        .padding(CYSpacing.md)
        .accessibilityElement(children: .contain)
    }
}

@MainActor private struct Cur7POIWriter: ChallengePOIWriting {
    func complete(_ request: ChallengePOICompleteRequest) async -> ChallengePOIWriteOutcome { .unavailable }
}

@MainActor private struct Cur7POIFixture: View {
    let live: Bool

    init(live: Bool) {
        self.live = live
        if live {
            ChallengePOIWriterFactory.makeWriter = { Cur7POIWriter() }
        } else {
            ChallengePOIWriterFactory.makeWriter = { GatedChallengePOIWriter() }
        }
    }

    var body: some View {
        Group {
            if let node = Cur7Fixtures.poiNode() {
                ChallengePOIHostView(node: node)
            } else {
                Text(verbatim: "—")
                    .accessibilityLabel(Text(verbatim: "Challenge POI unknown"))
                    .accessibilityIdentifier("cur7.poi.unknown")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(live ? "cur7.poi.live" : "cur7.poi.blocked")
    }
}

@MainActor private struct Cur7MutationWriter: MyProjectMutating {
    let outcome: MyProjectMutationOutcome
    func perform(_ request: MyProjectMutationRequest) async -> MyProjectMutationOutcome { outcome }
}

@MainActor private struct Cur7MutationFixture: View {
    @StateObject private var model: MyProjectMutationModel
    let failed: Bool

    init(failed: Bool) {
        self.failed = failed
        let outcome: MyProjectMutationOutcome = failed ? .failed(message: "") : .done
        _model = StateObject(wrappedValue: MyProjectMutationModel(writer: Cur7MutationWriter(outcome: outcome), scope: ""))
    }

    var body: some View {
        MyProjectMutationStatusView(model: model)
            .padding(CYSpacing.md)
            .task {
                await model.begin(.toggleOnline(biz: .topic, id: 41, currentlyOnline: false))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(verbatim: failed ? "My project mutation failed" : "My project mutation done"))
            .accessibilityIdentifier(failed ? "cur7.myproject.failed" : "cur7.myproject.done")
    }
}

@MainActor private final class Cur7MerchantReader: MerchantReading {
    let isConfigured = true
    let isSignedIn = true
    let sessionRevision: UInt64 = 1
    /// Nil revenue is unknown and stays an em dash. The string `"0"` is a decoded zero.
    let revenue: String?

    init(revenue: String?) { self.revenue = revenue }

    func merchantAccess() async throws -> MerchantAccess {
        try Self.decode(#"{"active":true,"merchant":{"id":31,"name":"Fixture Store"},"roleCode":"MERCHANT_OWNER","permissions":["merchant:finance:read","merchant:order:read","merchant:project:manage","merchant:basic:read","merchant:profile:write"]}"#)
    }

    func merchantDashboard(access: MerchantAccess) async throws -> MerchantDashboard {
        guard access.canReadDashboard else { throw MerchantReadError.accessDenied }
        if revenue != nil {
            return try Self.decode(#"{"revenue":"0","pendingOrders":0,"revenue7d":[]}"#)
        }
        return try Self.decode(#"{"revenue":null,"pendingOrders":0,"revenue7d":[]}"#)
    }

    func merchantTodo(access: MerchantAccess) async throws -> MerchantTodo {
        guard access.isOwner else { throw MerchantReadError.accessDenied }
        return try Self.decode(#"{"pendingOrders":0,"pendingVerify":0,"verifiedCount":0,"pendingPredict":0}"#)
    }

    func merchantEvents(access: MerchantAccess) async throws -> [MerchantEvent] {
        guard access.isOwner else { throw MerchantReadError.accessDenied }
        return []
    }

    func merchantOrders(access: MerchantAccess, filter: MerchantOrderFilter) async throws -> [MerchantOrder] {
        guard access.allows(.orders) else { throw MerchantReadError.accessDenied }
        return []
    }

    func merchantProjects(access: MerchantAccess) async throws -> MerchantProjectPage {
        guard access.allows(.projects) else { throw MerchantReadError.accessDenied }
        return try Self.decode(#"{"rows":[],"total":0}"#)
    }

    private static func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}

@MainActor private struct Cur7MerchantChipFixture: View {
    let unknown: Bool
    @State private var operations: MerchantOperationsFixtureReader?

    var body: some View {
        Group {
            if let operations {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    if unknown {
                        Text(verbatim: "—")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .accessibilityLabel(Text(verbatim: "Business status unknown"))
                            .accessibilityIdentifier("cur7.merchant.businessStatus.unknown")
                    }
                    MerchantHomeView(reader: Cur7MerchantReader(revenue: unknown ? nil : "0"), operationsReader: operations)
                }
            } else {
                CYLoadingStateView(rows: 3)
            }
        }
        .task {
            guard operations == nil else { return }
            let reader = MerchantOperationsFixtureReader()
            if unknown { reader.failure = .malformedResponse }
            operations = reader
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(unknown ? "cur7.merchant.unknown" : "cur7.merchant.open")
    }
}

private final class Cur7CharacterTransport: HTTPTransport, @unchecked Sendable {
    let payload: String
    init(payload: String) { self.payload = payload }
    func send(_ request: URLRequest) async throws -> (Data, Int) { (Data(payload.utf8), 200) }
}

private enum Cur7CharacterPayload {
    static let ready = #"{"code":200,"data":{"topicId":71,"created":true,"running":true,"attributes":[{"stateKey":"counter.str","label":"Strength","value":0,"min":0,"max":20,"displayType":"bar","persistScope":"run"}],"rpg":{"enabled":true,"momentum":0,"momentumMax":5}}}"#
    static let broken = #"{"code":200,"data":{"topicId":71}}"#
}

@MainActor private struct Cur7CharacterSheetFixture: View {
    @StateObject private var session = AppSession()
    let unknown: Bool
    @State private var boot: Boot = .loading

    private enum Boot { case loading, missing, ready(CharacterCardReadback) }

    var body: some View {
        Group {
            switch boot {
            case .loading:
                CYLoadingStateView(rows: 2)
            case .missing:
                Text(verbatim: "—")
                    .accessibilityLabel(Text(verbatim: "Character sheet unknown"))
                    .accessibilityIdentifier("cur7.character.unknown")
            case .ready(let model):
                CharacterCardReadbackView(session: session, model: model)
            }
        }
        .task { await start() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(unknown ? "cur7.character.unknownHost" : "cur7.character.ready")
    }

    private func start() async {
        guard case .loading = boot else { return }
        guard let base = URL(string: "https://fixture.example/native/") else { boot = .missing; return }
        guard let configuration = try? APIConfiguration(baseURL: base) else { boot = .missing; return }
        guard let play = try? PlayExperienceSession(accountID: GParityFixtures.accountID, epoch: 1, namespace: "synthetic-play-cn", token: "synthetic-fixture-token") else {
            boot = .missing
            return
        }
        let transport = Cur7CharacterTransport(payload: unknown ? Cur7CharacterPayload.broken : Cur7CharacterPayload.ready)
        let service = PlayExperienceService(configuration: configuration, transport: transport, enabled: [.reads])
        guard let model = CharacterCardReadback(topicID: 71, activityID: nil, service: service, currentSession: { play }) else {
            boot = .missing
            return
        }
        boot = .ready(model)
    }
}
#endif
