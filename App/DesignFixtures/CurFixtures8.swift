#if DEBUG
import SwiftUI

/// DEBUG fixtures for the screens already on ui/cur-rm-01 and ui/h-rm-02.
/// Launch with `--design-fixture cur8-<id>`. Data stays in process. Unknown amounts are an em dash.
/// www.chengyinhub.com keeps money closed and does not draw a price.
enum CurFixtures8 {
    static let token = "synthetic-fixture-token"
    static let fixtureHost = "fixture.example"
    static let productionHost = "www.chengyinhub.com"

    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "cur8-decor": return frame("Store decoration", Cur8DecorHost(closed: false), merchant: true)
        case "cur8-decor-closed": return frame("Store decoration · money closed", Cur8DecorHost(closed: true), merchant: true)
        case "cur8-npc": return frame("Store character", MerchantStoreCharacterFixtureHost(scenario: "normal"), merchant: true)
        case "cur8-npc-failed": return frame("Store character · profile failed", MerchantStoreCharacterFixtureHost(scenario: "error"), merchant: true)
        case "cur8-relation": return frame("Merchant relation", Cur8RelationHost(empty: false), merchant: false)
        case "cur8-relation-empty": return frame("Merchant relation · empty", Cur8RelationHost(empty: true), merchant: false)
        case "cur8-merchant-info": return frame("Merchant info", Cur8MerchantInfoHost(failed: false), merchant: true)
        case "cur8-merchant-info-failed": return frame("Merchant info · read failed", Cur8MerchantInfoHost(failed: true), merchant: true)
        case "cur8-pay": return frame("Registration pay · money closed", Cur8PayHost(unknownAmount: false), merchant: false)
        case "cur8-pay-unknown": return frame("Registration pay · unknown amount", Cur8PayHost(unknownAmount: true), merchant: false)
        case "cur8-team": return frame("Team shared hints", Cur8TeamHost(unknownScore: false), merchant: false)
        case "cur8-team-unknown": return frame("Team shared hints · unknown score", Cur8TeamHost(unknownScore: true), merchant: false)
        case "cur8-request-ref": return frame("Request reference", Cur8ReferenceHost(known: true), merchant: false)
        case "cur8-request-ref-unknown": return frame("Request reference · unknown", Cur8ReferenceHost(known: false), merchant: false)
        case "cur8-opt090": return frame("OPT-090 release audit", UnifiedReleaseAuditHubView(), merchant: false)
        case "cur8-opt090-attention": return frame("OPT-090 release audit · attention", Cur8Opt090Attention(), merchant: false)
        case "cur8-opt091": return frame("OPT-091 device smoke", TestFlightInternalAndExternalSmokeSectionView(), merchant: false)
        case "cur8-opt091-hold": return frame("OPT-091 device smoke · hold", Cur8Opt091Hold(), merchant: false)
        case "cur8-opt092": return frame("OPT-092 release sign-off", FinalThreeDocumentAndSevenDayGoalCompletionView(), merchant: false)
        case "cur8-opt092-incomplete": return frame("OPT-092 release sign-off · incomplete", Cur8Opt092Incomplete(), merchant: false)
        case "cur8-opt-signoff": return frame("OPT-090..092 section", Cur8OptSignoff(), merchant: false)
        case "cur8-opt-signoff-static": return frame("OPT-090..092 section · static", Cur8OptSignoff(), merchant: false)
        default: return nil
        }
    }

    @MainActor private static func frame<V: View>(_ title: String, _ view: V, merchant: Bool) -> AnyView {
        let domain: ThemeDomain = merchant ? .merchant : .player
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                view
                Text(verbatim: "DEBUG fixture · " + title)
                    .cyText(.caption)
                    .foregroundStyle(CYColor.textSecondary)
                    .padding(CYSpacing.md)
                    .accessibilityLabel(Text(verbatim: "DEBUG fixture · " + title))
            }
            .themeDomain(domain)
        )
    }
}

private struct Cur8StaticTransport: HTTPTransport {
    var payload: Data?
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        guard let payload else { throw URLError(.cancelled) }
        return (payload, 200)
    }
}

@MainActor private struct Cur8DecorHost: View {
    let closed: Bool

    var body: some View {
        MerchantOpsWp03Panel(page: .decor)
            .padding(CYSpacing.pageHorizontal)
            .environment(\.merchantOpsWp03Bridge, bridge)
    }

    private var bridge: MerchantOpsWp03Bridge {
        let ready = Data(#"{"code":200,"msg":"ok","data":{"merchantName":"Sample shop","status":"OPEN"}}"#.utf8)
        return MerchantOpsWp03Bridge(
            baseURL: URL(string: "https://fixture.example"),
            token: CurFixtures8.token,
            host: closed ? CurFixtures8.productionHost : CurFixtures8.fixtureHost,
            accountID: 7,
            transport: Cur8StaticTransport(payload: closed ? nil : ready)
        )
    }
}

@MainActor private struct Cur8RelationHost: View {
    @StateObject private var reader: CoopRelationFixtureReader

    init(empty: Bool) {
        _reader = StateObject(wrappedValue: CoopRelationFixtureReader(scenario: empty ? "empty" : "mixed"))
    }

    var body: some View {
        NavigationStack { CoopRelationDiscoveryView(reader: reader) }
    }
}

@MainActor private struct Cur8MerchantInfoHost: View {
    @StateObject private var environment: MerchantContentFixtureEnvironment

    init(failed: Bool) {
        let environment = MerchantContentFixtureEnvironment()
        environment.transport.failReads = failed
        _environment = StateObject(wrappedValue: environment)
    }

    var body: some View {
        NavigationStack { MerchantContentHomeView(service: environment.service, topicID: 70) }
    }
}

@MainActor private struct Cur8PayHost: View {
    /// Closed money draws the lock sentence and no amount. An unknown amount draws an em dash and does not send.
    let unknownAmount: Bool

    var body: some View {
        List {
            RegistrationPaySection(
                registrationID: 41,
                payableAmount: nil,
                consented: true,
                requiresFreshQuote: false
            )
        }
        .environment(\.registrationPayExecutor, unknownAmount ? refuse : nil)
    }

    private var refuse: RegistrationPayExecutor {
        { _, _, _ in .blocked(.moneyPaymentsClosed) }
    }
}

@MainActor private struct Cur8TeamHost: View {
    let unknownScore: Bool
    @State private var model: TeamPoolHintModel?

    var body: some View {
        Group {
            if let model {
                TeamPoolHintSection(model: model)
                TeamPoolRunStatusSection(model: model)
            } else {
                Text(verbatim: "—")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityLabel(Text("teamPool.unknown"))
                    .accessibilityValue(Text(verbatim: "—"))
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard model == nil, let base = URL(string: "https://fixture.example"),
              let configuration = try? APIConfiguration(baseURL: base) else { return }
        let service = TeamPoolService(
            configuration: configuration,
            transport: Cur8TeamTransport(unknownScore: unknownScore),
            token: { CurFixtures8.token }
        )
        let next = TeamPoolHintModel(service: service, nodeID: 34) { 7 }
        await next.load()
        model = next
    }
}

private struct Cur8TeamTransport: HTTPTransport {
    let unknownScore: Bool

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        guard request.httpMethod == "GET", path.hasSuffix("api/team/pool") else {
            return (Data(#"{"code":400,"errorCode":"TEAM_POOL_DISABLED"}"#.utf8), 400)
        }
        return (Data(body.utf8), 200)
    }

    private var body: String {
        let score = unknownScore ? "null" : "4"
        let expired = unknownScore ? "true" : "false"
        let clock = unknownScore ? "" : timerFields
        return #"{"code":200,"data":{"teamId":7,"enabled":true,"hintsTotal":3,"hintsUsed":1,"hintsLeft":2,"skipsTotal":2,"skipsUsed":0,"skipsLeft":2,"timerLimitSec":180,"timerExpired":"#
            + expired + clock
            + #","teamScore":"# + score
            + #","scoreBasis":"TEAM_FIRST_SOLVE_NODES","solvedNodeIds":[34]}}"#
    }

    private var timerFields: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let started = iso.string(from: Date().addingTimeInterval(-30))
        let deadline = iso.string(from: Date().addingTimeInterval(150))
        return #","timerStartedAt":"\#(started)","timerDeadline":"\#(deadline)""#
    }
}

@MainActor private struct Cur8ReferenceHost: View {
    let known: Bool
    private let ledger = RequestReferenceLedger()

    init(known: Bool) {
        self.known = known
        if known {
            ledger.record(path: "/api/registration/pay", headerValue: "d81d7c38d3bc4ede9ca68a6191299c6e")
        }
    }

    var body: some View {
        Group {
            if known, let row = RequestReferenceRow(pathFragment: "/api/registration/pay", ledger: ledger) {
                row
            } else {
                Text(verbatim: "—")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityLabel(Text("requestReference.label"))
                    .accessibilityValue(Text(verbatim: "—"))
                    .accessibilityHint(Text("requestReference.copy"))
            }
        }
        .padding(CYSpacing.md)
    }
}

@MainActor private struct Cur8Opt090Attention: View {
    var body: some View {
        UnifiedReleaseAuditHubView(snapshot: UnifiedReleaseAuditHubSnapshot(domainCards: cards))
    }

    private var cards: [ReleaseAuditHubDomainCard] {
        UnifiedReleaseAuditHubSnapshot.defaultDomainCards.enumerated().map { index, card in
            guard index == 0 else { return card }
            return ReleaseAuditHubDomainCard(
                id: card.id, title: card.title, metricSummary: "—",
                invariantSummary: card.invariantSummary, isVerified: false
            )
        }
    }
}

@MainActor private struct Cur8Opt091Hold: View {
    var body: some View {
        TestFlightInternalAndExternalSmokeSectionView(snapshot: snapshot)
    }

    private var snapshot: TestFlightSmokeMatrixSnapshot {
        let rows = TestFlightSmokeMatrixSnapshot.defaultRows.map { row in
            TestFlightSmokeJourneyRow(
                id: row.id, journeyCode: row.journeyCode, title: row.title,
                verificationSteps: row.verificationSteps, isSmokePassed: false, isFailClosedVerified: false
            )
        }
        return TestFlightSmokeMatrixSnapshot(rows: rows, internalTrackCleared: false, externalBetaReviewReady: false)
    }
}

@MainActor private struct Cur8Opt092Incomplete: View {
    var body: some View {
        FinalThreeDocumentAndSevenDayGoalCompletionView(
            snapshot: GoalCompletionGateSnapshot(sevenDayGoalAchieved: false, nativeSupersetPolicyEnforced: false)
        )
    }
}

@MainActor private struct Cur8OptSignoff: View {
    var body: some View {
        List { UnifiedOPT090To092AndEXT01To11SectionView() }
    }
}
#endif
