#if DEBUG
import SwiftUI

/// Offline hosts for the cur-uitests-3 journeys. Each one mounts a screen that already
/// exists on this branch. Nothing here opens a money switch for www.chengyinhub.com.
enum Cur3Fixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "cur3-team-play": return AnyView(Cur3TeamPlayFixture())
        case "cur3-payout-closed": return AnyView(Cur3PayoutFixture(open: false))
        case "cur3-payout-open": return AnyView(Cur3PayoutFixture(open: true))
        default: return nil
        }
    }
}

@MainActor struct Cur3TeamPlayFixture: View {
    @State private var model: TeamPoolHintModel?

    var body: some View {
        List {
            if let model {
                TeamPoolRunStatusSection(model: model)
                TeamPoolHintSection(model: model)
            } else {
                Text(verbatim: "—").accessibilityIdentifier("cur3.team.booting")
            }
        }
        .accessibilityIdentifier("cur3.team.screen")
        .task { await boot() }
    }

    private func boot() async {
        guard model == nil, let base = URL(string: "https://fixture.example"),
              let configuration = try? APIConfiguration(baseURL: base) else { return }
        let service = TeamPoolService(configuration: configuration, transport: GParityTransport(route: Cur3TeamReplies.route),
                                      token: { "synthetic-fixture-token" })
        let next = TeamPoolHintModel(service: service, nodeID: 34, resolveTeam: { 7 })
        model = next
        await next.load()
    }
}

enum Cur3TeamReplies {
    static func route(_ request: URLRequest) -> GParityTransport.Reply? {
        let path = request.url?.path ?? ""
        if path.hasSuffix("/api/team/pool/hint") { return consume(request, kind: "HINT", hintsLeft: 1, skipsLeft: 1, score: nil, expired: false, hint: true) }
        if path.hasSuffix("/api/team/pool/skip") { return consume(request, kind: "SKIP", hintsLeft: 1, skipsLeft: 0, score: 42, expired: true, hint: false) }
        if path.hasSuffix("/api/team/pool") { return GParityTransport.ok(pool(hintsLeft: 2, skipsLeft: 1, score: nil, expired: false)) }
        return nil
    }

    private static func consume(_ request: URLRequest, kind: String, hintsLeft: Int, skipsLeft: Int, score: Int?, expired: Bool, hint: Bool) -> GParityTransport.Reply? {
        let body = GParityTransport.json(request)
        let node = (body["nodeId"] as? Int) ?? (body["nodeId"] as? Double).map(Int.init) ?? 0
        guard let requestID = body["requestId"] as? String, !requestID.isEmpty, node == 34 else { return nil }
        let hintJSON = hint ? #","hint":{"level":1,"type":"TEXT","content":"Shared fixture hint"}"# : ""
        let data = #"{"requestId":"\#(requestID)","kind":"\#(kind)","nodeId":34,"consumed":true,"pool":\#(pool(hintsLeft: hintsLeft, skipsLeft: skipsLeft, score: score, expired: expired))\#(hintJSON)}"#
        return GParityTransport.ok(data)
    }

    private static func pool(hintsLeft: Int, skipsLeft: Int, score: Int?, expired: Bool) -> String {
        let scoreJSON = score.map { ",\"teamScore\":\($0)" } ?? ""
        let expiredJSON = expired ? ",\"timerExpired\":true" : ""
        let solved = expired ? "[34]" : "[]"
        return #"{"teamId":7,"enabled":true,"hintsTotal":2,"hintsUsed":\#(2 - hintsLeft),"hintsLeft":\#(hintsLeft),"skipsTotal":1,"skipsUsed":\#(1 - skipsLeft),"skipsLeft":\#(skipsLeft),"timerLimitSec":60\#(expiredJSON)\#(scoreJSON),"scoreBasis":"TEAM_FIRST_SOLVE_NODES","solvedNodeIds":\#(solved)}"#
    }
}

@MainActor struct Cur3PayoutFixture: View {
    let open: Bool
    @State private var session: AppSession?
    @State private var ready = false

    var body: some View {
        Group {
            if ready, let session {
                NavigationStack { ClubPayoutReceiverView(clubID: 8120) }.environmentObject(session)
            } else if ready {
                Text(verbatim: "—").accessibilityIdentifier("cur3.payout.unknown")
            } else {
                ProgressView().accessibilityIdentifier("cur3.payout.booting")
            }
        }
        .task { await prepare() }
    }

    private func prepare() async {
        if session == nil { session = Cur3PayoutSession.make(open: open) }
        if open, let session { await session.bootstrap() }
        ready = true
    }
}

@MainActor enum Cur3PayoutSession {
    static let productionHost = "https://www.chengyinhub.com"
    static let testHost = "https://8120.example.test"

    static func make(open: Bool) -> AppSession? {
        let base = open ? testHost : productionHost
        let box = Cur3MemoryToken()
        if open { box.saved = "synthetic-fixture-token" }
        guard let defaults = UserDefaults(suiteName: open ? "cur3-payout-open" : "cur3-payout-closed"),
              let deployment = try? ReviewedAppDeployment(
                market: .china, baseURL: base, approvedBaseURLs: [.china: [base]],
                verifiedCapabilities: open ? [.domesticChinaPhone] : [],
                bundleIdentifier: "com.chengyin.fixture.cur3", realm: open ? "cur3-open" : "cur3-closed") else { return nil }
        let storage = AppScopedStorageFactory(defaults: defaults, tokenStore: { _ in box })
        let composition = AppCompositionRoot(deployment: .reviewed(deployment), storage: storage, makeTransport: { Cur3OfflineTransport() })
        return AppSession(composition: composition)
    }
}

@MainActor final class Cur3MemoryToken: AppTokenStorage {
    var saved: String?
    func read() throws -> String? { saved }
    func write(_ token: String) throws { saved = token }
    func clear() throws { saved = nil }
}

/// In-memory answers only. Bind and unbind throw before any body is returned.
struct Cur3OfflineTransport: HTTPTransport, Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        if path.contains("personal-receiver/bind") || path.contains("personal-receiver/unbind") || path.contains("payout-account") {
            throw APIError.notConfigured
        }
        if path.hasSuffix("/api/userInfo") {
            let body = #"{"code":200,"appUser":{"id":990001,"nickName":"Fixture","role":"player","userType":1,"point":0}}"#
            return (Data(body.utf8), 200)
        }
        if path.hasSuffix("/api/club/personal-receiver/status") {
            let body = #"{"code":200,"data":{"available":true,"receiverState":"UNBOUND","payoutEnabled":false,"paused":false,"canUnbind":false}}"#
            return (Data(body.utf8), 200)
        }
        throw URLError(.notConnectedToInternet)
    }
}
#endif
