#if DEBUG
import SwiftUI

@MainActor final class TicketWalletFixtureReader: TicketWalletReading {
    enum Scenario: String { case content, empty, partial, partialEmpty, failure, unauthorized, unconfigured, unavailable, guest, refreshed, sessionChange }
    let scenario: Scenario
    private(set) var scope = UUID()
    private(set) var isAuthenticated: Bool
    var isConfigured: Bool { scenario != .unconfigured }
    var isOfflineExample: Bool { true }
    private var detailReads = 0
    init(scenario: Scenario = .content) { self.scenario = scenario; isAuthenticated = scenario != .guest }
    func signOut() { isAuthenticated = false; scope = UUID() }
    /// 20:25 sweep: fixture ticket names follow the launch language (Core keeps the English synthetic names for its tests).
    private static let zhTicketNames: [(String, String)] = [
        ("Sample exploration ticket", "示例探索票"), ("Sample activity ticket", "示例活动票"),
        ("Sample expired ticket", "示例已过期票"), ("Sample unknown ticket", "示例未知状态票"), ("Sample unpaid ticket", "示例待支付票")
    ]
    private static func localized(_ json: String) -> String {
        guard Locale.preferredLanguages.first?.hasPrefix("zh") == true else { return json }
        var out = json
        for (en, zh) in zhTicketNames { out = out.replacingOccurrences(of: "\"name\":\"\(en)\"", with: "\"name\":\"\(zh)\"") }
        return out
    }
    /// mp-mine r3: the session ticket carries a start time and place, so the sweep shows the MP P-27 card line
    /// (「5月1日 19:30 · 西湖文化广场」) instead of a bare 场次.
    private static func withSession(_ json: String) -> String {
        let zh = Locale.preferredLanguages.first?.hasPrefix("zh") == true
        let place = zh ? "西湖文化广场" : "West Lake Culture Square"
        return json.replacingOccurrences(of: "\"productType\":1}", with: "\"productType\":1,\"startDate\":\"2030-05-01 19:30:00\",\"addressName\":\"\(place)\"}")
    }
    private func check() throws {
        guard isAuthenticated else { throw APIError.unauthorized }
        switch scenario {
        case .failure: throw APIError.httpStatus(503)
        case .unauthorized: throw APIError.unauthorized
        case .unconfigured: throw APIError.notConfigured
        default: break
        }
    }
    func ticketWallet() async throws -> TicketWalletSnapshot {
        try check()
        if scenario == .empty { return TicketWalletSnapshot(tickets: []) }
        if scenario == .partialEmpty { return TicketWalletSnapshot(tickets: [], partialFailure: .init(lane: .activity, issue: .network)) }
        struct Envelope: Decodable { let data: [TicketWalletTicket] }
        let routes = try JSONDecoder().decode(Envelope.self, from: Data(Self.localized(TicketWalletSyntheticFixtures.routeListJSON).utf8)).data
        if scenario == .partial { return TicketWalletSnapshot(tickets: routes, partialFailure: .init(lane: .activity, issue: .failure)) }
        let activities = try JSONDecoder().decode(Envelope.self, from: Data(Self.withSession(Self.localized(TicketWalletSyntheticFixtures.activityListJSON)).utf8)).data
        return TicketWalletSnapshot(tickets: routes + activities)
    }
    func ticketDetail(id: Int) async throws -> TicketWalletTicket {
        try check()
        if scenario == .unavailable { throw TicketWalletReadFailure.unavailable }
        detailReads += 1
        if scenario == .refreshed, detailReads > 1 {
            return try JSONDecoder().decode(TicketWalletTicket.self, from: Data("{\"id\":\(id),\"registrationStatus\":3,\"verificationStatus\":0,\"cmsTopic\":{\"name\":\"Sample canceled after refresh\"}}".utf8))
        }
        let json = Self.localized(TicketWalletSyntheticFixtures.detailJSON).replacingOccurrences(of: "\"id\":901", with: "\"id\":\(id)")
        return try JSONDecoder().decode(TicketWalletTicket.self, from: Data(json.utf8))
    }
}

@MainActor struct TicketWalletFixtureHostView: View {
    /// TicketWalletView and its detail read `@EnvironmentObject AppSession`; without one the fixture quit at launch (18:15 sweep, e4-tickets).
    @StateObject private var session = AppSession()
    @State private var reader: TicketWalletFixtureReader
    @State private var revision = 0
    /// mp-mine r3 (Next round 3): design fixtures e4-tickets-empty / -error / -guest pass their state here so the
    /// sweep shows the MP 还没有票 / 票夹没能打开 / 登录后查看票夹 shells. Nil keeps the UI-test launch argument.
    private let showsStateActions: Bool
    init(scenario: TicketWalletFixtureReader.Scenario? = nil) {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-ticket-wallet-scenario")
        let raw = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        let resolved = scenario ?? raw.flatMap(TicketWalletFixtureReader.Scenario.init(rawValue:)) ?? .content
        _reader = State(initialValue: TicketWalletFixtureReader(scenario: resolved))
        showsStateActions = scenario != nil
    }
    var body: some View {
        VStack(spacing: 0) {
            if reader.scenario == .sessionChange {
                Button("ticketWallet.fixture.signOut") { reader.signOut(); revision += 1 }
                    .accessibilityIdentifier("ticketWallet.fixture.signOut")
            }
            if reader.scenario == .unavailable || reader.scenario == .refreshed {
                NavigationStack { TicketWalletDetailView(id: 901, reader: reader) }
            } else if showsStateActions {
                TicketWalletView(reader: reader, onSignIn: {}, onExplore: {})
            } else { TicketWalletView(reader: reader) }
        }
        .id(revision)
        .environmentObject(session)
    }
}
#endif
