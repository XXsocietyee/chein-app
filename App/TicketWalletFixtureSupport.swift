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
        let activities = try JSONDecoder().decode(Envelope.self, from: Data(Self.localized(TicketWalletSyntheticFixtures.activityListJSON).utf8)).data
        return TicketWalletSnapshot(tickets: routes + activities)
    }
    func ticketDetail(id: Int) async throws -> TicketWalletTicket {
        try check()
        if scenario == .unavailable { throw TicketWalletReadFailure.unavailable }
        detailReads += 1
        if scenario == .refreshed, detailReads > 1 {
            return try JSONDecoder().decode(TicketWalletTicket.self, from: Data("{\"id\":\(id),\"registrationStatus\":3,\"verificationStatus\":0,\"cmsTopic\":{\"name\":\"Sample cancelled after refresh\"}}".utf8))
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
    init() {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-ticket-wallet-scenario")
        let raw = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        _reader = State(initialValue: TicketWalletFixtureReader(scenario: raw.flatMap(TicketWalletFixtureReader.Scenario.init(rawValue:)) ?? .content))
    }
    var body: some View {
        VStack(spacing: 0) {
            if reader.scenario == .sessionChange {
                Button("ticketWallet.fixture.signOut") { reader.signOut(); revision += 1 }
                    .accessibilityIdentifier("ticketWallet.fixture.signOut")
            }
            if reader.scenario == .unavailable || reader.scenario == .refreshed {
                NavigationStack { TicketWalletDetailView(id: 901, reader: reader) }
            } else { TicketWalletView(reader: reader) }
        }
        .id(revision)
        .environmentObject(session)
    }
}
#endif
