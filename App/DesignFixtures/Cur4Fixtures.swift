#if DEBUG
import SwiftUI

/// Handover 47. DEBUG fixtures for the views added on ui/wp-02 and ui/wp-11.
/// Each screen has one normal fixture and one non-happy fixture. Data is synthetic.
/// Money stays closed on www.chengyinhub.com: that host is the editions non-happy fixture.
/// An unknown value is an em dash. Launch with `--design-fixture cur4-<id>`.
enum Cur4Fixtures {
    static let accountID = GParityFixtures.accountID

    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "cur4-audit-timeline": return audit("Audit timeline", bizID: "992011", timeline: Cur4AuditBodies.rows, seed: .clear)
        case "cur4-audit-timeline-failed": return audit("Audit timeline · load failed", bizID: "992012", timeline: nil, seed: .clear)
        case "cur4-audit-appeal": return audit("Audit appeal", bizID: "992013", timeline: Cur4AuditBodies.canAppeal, seed: .clear)
        case "cur4-audit-appeal-unknown": return audit("Audit appeal · unknown state", bizID: "992014", timeline: Cur4AuditBodies.unknownState, seed: .clear)
        case "cur4-audit-receipt": return audit("Audit receipt", bizID: "992015", timeline: Cur4AuditBodies.rows, seed: .pending, receipt: Cur4AuditBodies.receipt(bizID: "992015"))
        case "cur4-audit-receipt-unreadable": return audit("Audit receipt · unreadable", bizID: "992016", timeline: Cur4AuditBodies.rows, seed: .corrupt)
        case "cur4-guard": return guardSheet("Original-run guard", activity: 41, seeded: false, reference: Cur4AuditBodies.guardReference)
        case "cur4-guard-unconfirmed": return guardSheet("Original-run guard · unconfirmed", activity: 42, seeded: true, reference: Cur4AuditBodies.guardReference)
        case "cur4-unlock-chapter": return frame("Leader unlock chapter", Cur4UnlockChapterFixture(outcome: .ready))
        case "cur4-unlock-chapter-pending": return frame("Leader unlock chapter · receipt pending", Cur4UnlockChapterFixture(outcome: .pending))
        case "cur4-edition-empty": return edition("Edition empty reason", productionHost: false)
        case "cur4-edition-empty-closed": return edition("Edition empty reason · money closed", productionHost: true)
        case "cur4-location-holds": return frame("Session location holds", Cur4LocationHoldsFixture(held: true))
        case "cur4-location-holds-none": return frame("Session location holds · none", Cur4LocationHoldsFixture(held: false))
        case "cur4-request-reference": return frame("Request reference", Cur4RequestReferenceFixture(known: true))
        case "cur4-request-reference-unknown": return frame("Request reference · unknown", Cur4RequestReferenceFixture(known: false))
        default: return nil
        }
    }

    @MainActor private static func audit(_ title: String, bizID: String, timeline: String?, seed: Cur4AuditSeed, receipt: String? = nil) -> AnyView {
        Cur4AuditSeed.apply(seed, bizID: bizID)
        guard let target = CreatorAuditTarget(bizType: "TOPIC", bizID: bizID) else {
            return frame(title, Text(verbatim: "—"))
        }
        var replies: [String: GParityTransport.Reply] = [:]
        if let timeline { replies["api/audit/timeline"] = GParityTransport.ok(timeline) }
        if let receipt { replies["api/audit/appeal/receipt"] = GParityTransport.ok(receipt) }
        let sheet = CreatorAuditSheet(target: target, title: "西湖夜航")
            .environment(\.playerGapService, gap(replies))
        return frame(title, sheet)
    }

    @MainActor private static func guardSheet(_ title: String, activity: Int, seeded: Bool, reference: PlayGuardAppealReference?) -> AnyView {
        if seeded { Cur4GuardSeed.unconfirmed(activity: activity) } else { Cur4GuardSeed.clear(activity: activity) }
        let replies = seeded ? [:] : ["api/audit/guard/reference": GParityTransport.ok(Cur4AuditBodies.guardEligibility)]
        let section = List {
            PlayGuardAppealSection(scope: .activity(activity), nodeID: 34, reference: reference)
        }
        .environment(\.playerGapService, gap(replies))
        return frame(title, section)
    }

    @MainActor private static func edition(_ title: String, productionHost: Bool) -> AnyView {
        let base = productionHost ? "https://www.chengyinhub.com" : "https://fixture.example"
        let replies = productionHost ? [:] : ["api/club-compensation/editions/empty-reason": GParityTransport.ok(#"{"clubId":7001,"reasonCode":"NO_PERMISSION"}"#)]
        let view = ClubEditionEmptyReasonView(clubID: 7001)
            .environment(\.playerGapService, gap(replies, base: base))
        return frame(title, view)
    }

    @MainActor private static func gap(_ replies: [String: GParityTransport.Reply], base: String = "https://fixture.example") -> PlayerGapService {
        PlayerGapService(baseURL: URL(string: base)!, accountID: accountID, token: { "synthetic-fixture-token" }, transport: GParityTransport(replies))
    }

    @MainActor private static func frame<V: View>(_ title: String, _ view: V) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 0) {
                view
                Text(verbatim: "DEBUG fixture · " + title)
                    .font(CYTypography.caption)
                    .foregroundStyle(CYColor.textSecondary)
                    .padding(CYSpacing.md)
            }
            .themeDomain(.player)
            .preferredColorScheme(.dark)
        )
    }
}

private enum Cur4AuditSeed { case clear, pending, corrupt
    @MainActor static func apply(_ seed: Cur4AuditSeed, bizID: String) {
        let key = "audit-appeal:\(Cur4Fixtures.accountID):TOPIC:\(bizID)"
        switch seed {
        case .clear:
            UserDefaults.standard.removeObject(forKey: key)
        case .corrupt:
            UserDefaults.standard.set(Data("not-json".utf8), forKey: key)
        case .pending:
            UserDefaults.standard.removeObject(forKey: key)
            guard let target = CreatorAuditTarget(bizType: "TOPIC", bizID: bizID) else { return }
            let command = CreatorAuditAppealCommand(requestID: "appeal-fixture0001", target: target, reason: "图片是原创")
            let draft = CreatorAuditAppealFlow.Draft(reason: "图片是原创", attachments: [], pending: true, confirmed: false, command: command)
            if let data = try? JSONEncoder().encode(draft) { UserDefaults.standard.set(data, forKey: key) }
        }
    }
}

private enum Cur4GuardSeed {
    @MainActor static func clear(activity: Int) {
        UserDefaults.standard.removeObject(forKey: key(activity))
    }
    @MainActor static func unconfirmed(activity: Int) {
        guard let reference = Cur4AuditBodies.guardReference else { return }
        let command = PlayGuardAppealCommand(guardLogID: reference.guardLogID, arrivalRequestID: reference.arrivalRequestID, requestID: "req-fixture-1", reason: "定位跳了")
        let entry = PlayGuardAppealFlow.Entry(owner: Cur4Fixtures.accountID, session: "activityId:\(activity)", reference: reference, state: .unknown, reason: "定位跳了", command: command, eligibility: nil, result: nil, note: nil, serverMessage: nil)
        if let data = try? JSONEncoder().encode(entry) { UserDefaults.standard.set(data, forKey: key(activity)) }
    }
    private static func key(_ activity: Int) -> String { "play-guard-appeal:\(Cur4Fixtures.accountID):activityId:\(activity)" }
}

private enum Cur4AuditBodies {
    static let rows = #"{"bizType":"TOPIC","bizId":992011,"rounds":[{"kind":"SUBMIT","timeline":[{"id":5,"action":"REJECT","reasonLabels":["违规"],"reasonText":"图片不清晰","createTime":"2026-11-13 10:00:00"}],"problems":[{"id":2,"itemType":"NODE","itemId":34,"reasonText":"坐标缺失"}]}],"appeal":{"state":"SUBMITTED"},"canAppeal":false}"#
    static let canAppeal = #"{"rounds":[],"appeal":null,"canAppeal":true}"#
    /// Not one of SUBMITTED / REVIEWING / ACCEPTED / REJECTED / WITHDRAWN, so the sheet draws an em dash.
    static let unknownState = #"{"rounds":[{"kind":"SUBMIT","timeline":[{"id":5,"action":"REJECT","reasonText":"图片不清晰","createTime":"2026-11-13 10:00:00"}],"problems":[]}],"appeal":{"state":"QUEUED"},"canAppeal":false}"#
    static func receipt(bizID: String) -> String {
        let member = String(Cur4Fixtures.accountID)
        return #"{"state":"FOUND","appealId":"77","taskId":"88","appealState":"SUBMITTED","intent":{"version":1,"requestId":"appeal-fixture0001","bizType":"TOPIC","bizId":""#
            + bizID
            + #"","memberId":""#
            + member
            + #"","reason":"图片是原创","evidence":null,"attachments":[]}}"#
    }
    static let guardEligibility = #"{"guardOrigin":{"guardLogId":"41","routeSessionId":"77","nodeId":"34"},"originalRunActive":true,"canSubmit":true}"#
    static let guardReference = PlayGuardAppealReference(guardLogID: "41", routeSessionID: "77", nodeID: 34, arrivalRequestID: "act-9")
}

@MainActor private struct Cur4UnlockChapterFixture: View {
    enum Outcome { case ready, pending }
    let outcome: Outcome
    private let session: PlayExperienceSession?
    private let lead: PlayLeadProgress?
    @State private var boot: Boot = .loading

    private enum Boot { case loading, failed, ready(PlayExperienceCoordinator) }

    init(outcome: Outcome) {
        self.outcome = outcome
        session = try? PlayExperienceSession(accountID: 9001, epoch: 1, namespace: "synthetic-play-cn", token: "synthetic-token")
        lead = Self.decodedLead()
    }

    var body: some View {
        Group {
            switch boot {
            case .loading:
                CYLoadingStateView(rows: 2)
            case .failed:
                Text(verbatim: "—").accessibilityIdentifier("playx.lead.unlock.unknown")
            case .ready(let model):
                if let lead {
                    List { PlayLeadChapterTools(model: model, lead: lead, context: model.interactionContext) }
                } else {
                    Text(verbatim: "—")
                }
            }
        }
        .task { await start() }
    }

    private static func decodedLead() -> PlayLeadProgress? {
        guard let raw = try? PlayExperienceSyntheticFixtures.wire(Cur4UnlockPayload.lead) else { return nil }
        return try? PlayLeadProgress(raw)
    }

    private func start() async {
        guard let session, lead != nil else { boot = .failed; return }
        guard let base = URL(string: "https://fixture.example/native/"),
              let configuration = try? APIConfiguration(baseURL: base) else { boot = .failed; return }
        let service = PlayExperienceService(configuration: configuration, transport: Cur4UnlockTransport(), enabled: [.reads, .leader])
        let model = PlayExperienceCoordinator(scope: .activity(41), service: service, recovery: PlayMemoryCompletionRecovery(), pausedStorage: PlayMemoryPausedStorage(), currentSession: { session })
        await model.load()
        if let context = model.interactionContext { await model.loadLead(context: context) }
        if outcome == .pending {
            if let context = model.interactionContext { await model.unlockChapter(context: context) }
            guard model.pendingUnlock?.receiptOnly == true else { boot = .failed; return }
        } else {
            guard case .ready = model.phase, model.lead?.allArrived == true else { boot = .failed; return }
        }
        boot = .ready(model)
    }
}

private final class Cur4UnlockTransport: HTTPTransport, @unchecked Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        if path.hasSuffix("api/play/nodes") {
            return (PlayExperienceSyntheticFixtures.envelope(Cur4UnlockPayload.nodes), 200)
        }
        if path.hasSuffix("api/club/lead/team-progress") {
            return (PlayExperienceSyntheticFixtures.envelope(Cur4UnlockPayload.lead), 200)
        }
        if path.hasSuffix("api/club/lead/unlock-chapter") || path.hasSuffix("api/club/lead/unlock-chapter-receipt") {
            return (Data(#"{"code":500,"msg":"章节命令结果待确认"}"#.utf8), 500)
        }
        throw URLError(.notConnectedToInternet)
    }
}

private enum Cur4UnlockPayload {
    static let nodes = #"{"topicId":71,"topicName":"Synthetic journey","mode":1,"registered":true,"playable":true,"total":1,"doneCount":0,"nodes":[{"nodeId":34,"name":"闸口","done":false,"arrived":true,"validationMethod":1}]}"#
    static let lead = #"{"exists":true,"isLeader":true,"leaderMemberId":9001,"status":2,"chapterName":"Synthetic chapter","currentChapterId":50,"nextChapterId":51,"arrived":2,"meArrived":true,"members":[{"memberId":9001,"nickname":"Synthetic leader","done":1,"arrived":true,"isLeader":true},{"memberId":9004,"nickname":"阿青","done":0,"arrived":true,"isLeader":false}],"skipRequests":[{"memberId":9004,"nickname":"阿青","nodeId":34}]}"#
}

@MainActor private struct Cur4LocationHoldsFixture: View {
    @StateObject private var tracker: SessionBackgroundLocationTracker

    init(held: Bool) {
        let tracker = SessionBackgroundLocationTracker()
        if held {
            _ = tracker.ledger.acquire("roam", foregroundOnly: false)
            _ = tracker.ledger.acquire("play:41:990001:1", foregroundOnly: true)
        }
        _tracker = StateObject(wrappedValue: tracker)
    }

    var body: some View {
        List { SessionLocationHoldsSection(tracker: tracker) }
    }
}

@MainActor private struct Cur4RequestReferenceFixture: View {
    let known: Bool

    init(known: Bool) {
        self.known = known
        let ledger = RequestReferenceLedger.shared
        ledger.clear()
        if known {
            ledger.record(path: "/api/play/nodes", headerValue: "d81d7c38d3bc4ede9ca68a6191299c6e")
        }
    }

    var body: some View {
        List {
            PlayExperienceIssueView(issue: .unknownResult)
            if !known {
                Text(verbatim: "—").accessibilityIdentifier("requestReference.unknown")
            }
        }
    }
}
#endif
