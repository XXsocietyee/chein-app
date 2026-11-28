#if DEBUG
import SwiftUI

@MainActor final class RoamExperienceFixtureReader: RoamExperienceReading {
    enum Scenario: String { case content, empty, failure, historyCorrupt, active, incomplete, missing, unauthorized, unconfigured, pageFailure, sessionChange, captionDraft, liveSession, liveUnknown }
    let scenario: Scenario
    private var signedOut = false
    private var epoch: UInt64 = 1
    private let scope = try! RoamHistoryScope(market: "cn", deployment: URL(string: "https://example.com/synthetic-roam")!, accountID: 900)
    var identity: RoamExperienceIdentity? { signedOut || scenario == .unauthorized ? nil : RoamExperienceIdentity(scope: scope, epoch: epoch) }
    var isConfigured: Bool { scenario != .unconfigured }
    var isOfflineExample: Bool { true }
    init(scenario: Scenario = .content) { self.scenario = scenario }
    func signOut() { signedOut = true; epoch += 1 }
    private func check() throws {
        guard identity != nil else { throw APIError.unauthorized }
        if !isConfigured { throw APIError.notConfigured }
        if scenario == .failure { throw APIError.httpStatus(503) }
    }
    private static var prefersChinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T { try JSONDecoder().decode(type, from: Data(json.utf8)) }
    func history() throws -> [RoamHistoryRecord] {
        try check()
        if scenario == .historyCorrupt { throw RoamExperienceFailure.historyUnreadable }
        return try decode([RoamHistoryRecord].self, scenario == .empty ? "[]" : RoamExperienceSyntheticFixtures.history)
    }
    func sessionFact(_ query: RoamRecoveryQuery) async throws -> RoamSessionFact {
        try check()
        let json: String
        switch scenario {
        case .active: json = RoamExperienceSyntheticFixtures.active
        case .incomplete: json = RoamExperienceSyntheticFixtures.incomplete
        case .missing, .empty: json = RoamExperienceSyntheticFixtures.missing
        default: json = RoamExperienceSyntheticFixtures.settled
        }
        return try decode(RoamSessionFact.self, json)
    }
    func album(page: Int, pageSize: Int) async throws -> RoamAlbumPage {
        try check()
        if scenario == .pageFailure && page > 1 { throw APIError.httpStatus(503) }
        if scenario == .empty { return try decode(RoamAlbumPage.self, "{\"list\":[],\"total\":0,\"pageNum\":\(page),\"pageSize\":\(pageSize)}") }
        var json = RoamExperienceSyntheticFixtures.album
        // Sweep 18:54 zh-Hans: fixture captions follow the UI language (like the badge-wall fixture); en stays as UI tests pin it.
        // mp-roam r3 (sweep 01:10 `e2-stamp-album`): design fixtures render the real page, so the stamps carry
        // place names, not "Synthetic …" labels; UI tests (no `--design-fixture`) keep the pinned captions.
        if ProcessInfo.processInfo.arguments.contains("--design-fixture") {
            json = json.replacingOccurrences(of: "Synthetic city stamp", with: Self.prefersChinese ? "外滩夜色" : "The Bund at night")
            json = json.replacingOccurrences(of: "Synthetic reviewed stamp", with: Self.prefersChinese ? "老街霓虹" : "Old street neon")
        } else if Self.prefersChinese {
            json = json.replacingOccurrences(of: "Synthetic city stamp", with: "示例城市邮票")
            json = json.replacingOccurrences(of: "Synthetic reviewed stamp", with: "示例已审核邮票")
        }
        json = json.replacingOccurrences(of: "\"pageNum\":1", with: "\"pageNum\":\(page)")
        json = json.replacingOccurrences(of: "\"pageSize\":20", with: "\"pageSize\":\(pageSize)")
        // One row past this page, so the last tile still has a next page to ask for.
        if scenario == .pageFailure { json = json.replacingOccurrences(of: "\"total\":3", with: "\"total\":\(pageSize + 1)") }
        return try decode(RoamAlbumPage.self, json)
    }
    func tilePage(afterID: Int, limit: Int) async throws -> RoamTileMemoryPage {
        try check(); return try decode(RoamTileMemoryPage.self, scenario == .empty ? #"{"tiles":[],"nextAfterId":0,"hasMore":false}"# : RoamExperienceSyntheticFixtures.tiles)
    }
    func shopBadge() async throws -> RoamShopBadge? {
        try check(); return scenario == .empty ? nil : try decode(RoamShopBadge.self, Self.prefersChinese ? RoamExperienceSyntheticFixtures.badge.replacingOccurrences(of: "Synthetic shop badge", with: "示例探店徽章") : RoamExperienceSyntheticFixtures.badge)
    }
}
@MainActor struct RoamExperienceFixtureHostView: View {
    static var selected: Bool { ProcessInfo.processInfo.arguments.contains("--uitesting-roam-experience") }
    @State private var reader: RoamExperienceFixtureReader
    @State private var revision = 0
    @State private var liveFixture: RoamLiveFixture
    @State private var toolsReader: RoamPassportToolsFixtureReader
    @State private var privateTools: RoamPrivateToolsFixture
    init() {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-roam-experience-scenario")
        let raw = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        let tools: RoamPassportToolsFixtureReader.Scenario = raw == "empty" ? .empty : raw == "failure" ? .failure : raw == "unauthorized" ? .unauthorized : .content
        _toolsReader = State(initialValue: RoamPassportToolsFixtureReader(scenario: tools))
        let privateScenario: RoamPrivateToolsFixture.Scenario = raw == "privateReadOnly" ? .readOnly : raw == "privateUnknown" ? .unknownCreate
            : RoamPrivateToolsFixture.Scenario(rawValue: raw ?? "") ?? .content
        _privateTools = State(initialValue: RoamPrivateToolsFixture(scenario: privateScenario))
        _liveFixture = State(initialValue: RoamLiveFixture(failReveal: raw == "liveUnknown"))
        _reader = State(initialValue: RoamExperienceFixtureReader(scenario: raw.flatMap(RoamExperienceFixtureReader.Scenario.init(rawValue:)) ?? .content))
    }
    private var stampDestination: (() -> AnyView)? {
        guard reader.scenario == .captionDraft else { return nil }
        return { AnyView(RoamCityStampDraftView(offline: true)) }
    }
    private var liveDestination: (() -> AnyView)? {
        guard reader.scenario == .liveSession || reader.scenario == .liveUnknown else { return nil }
        return { AnyView(RoamLiveSessionView(controller: liveFixture.controller, offlineExample: true)) }
    }
    var body: some View {
        VStack(spacing: 0) {
            if reader.scenario == .sessionChange {
                Button("roam.experience.fixtureSignOut") { reader.signOut(); revision += 1 }
                    .accessibilityIdentifier("roam.experience.fixture.signOut")
            }
            NavigationStack { RoamExperienceHubView(reader: reader, stampDestination: stampDestination, liveDestination: liveDestination, toolsReader: toolsReader, privateToolsReader: privateTools) }.id(revision)
        }
    }
}
#endif
