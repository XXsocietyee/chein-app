#if DEBUG
import SwiftUI

/// fix/r3-play-roam-b: the states this round added, on the real views with synthetic data (DEBUG only).
/// Reach with `--design-fixture r3prb-<name>`; listed in `docs/port/accept/f-play-roam-b.txt`.
enum FixR3PlayRoamBFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "r3prb-seats-auth":
            // JSEAT-6: signed out is a sign-in state, not 无权限.
            return player(NavigationStack {
                JourneySeatsView(phase: .auth, onRetry: {}, onInvite: {}, onCancel: { _ in }, onStart: {}, onEditMe: {}, onSignIn: {})
            })
        case "r3prb-settle-assisted":
            // JSETTLE-4: 辅助完成 counts the skipped / revealed nodes; JSETTLE-7: topic at `.pageTitle`, no tracking.
            let report = JourneyReport(
                legacy: false, result: .assisted, dateLabel: "2026-11-14", nodesText: "5/5", elapsedText: "48:20",
                score: 820, rank: 4, rankBasisCount: 5, penaltyText: nil, rewardItems: nil,
                runID: "run-1", topicID: "88", activityID: nil, coverURL: nil,
                nodes: [
                    JourneyNodeRow(id: "1", name: "断桥", mode: nil, score: 200),
                    JourneyNodeRow(id: "2", name: "白堤", mode: .skipped, score: nil),
                    JourneyNodeRow(id: "3", name: "孤山", mode: .revealed, score: 120),
                    JourneyNodeRow(id: "4", name: "平湖秋月", mode: nil, score: 250),
                    JourneyNodeRow(id: "5", name: "苏堤", mode: nil, score: 250)
                ],
                finished: true, inProgress: false, assistedCount: 2, startModeText: "桌面完成")
            return player(NavigationStack {
                JourneySettleView(phase: .ready(report), rank: JourneyRankState(), rate: .idle, shareURL: nil,
                                  topicName: "西湖夜游漫步", onRetry: {}, onSignIn: {}, onLoadRank: {},
                                  onRankScope: { _ in }, onRankPeriod: { _ in }, onSubmitRating: { _, _ in }, onDone: {})
            })
        case "r3prb-settle-startmode":
            // Round 2 JSETTLE-4: Core `startModeText` → the 开局 cell (替代站开局).
            var report = sampleReport()
            report.startModeText = "替代站开局"
            return player(NavigationStack {
                JourneySettleView(phase: .ready(report), rank: JourneyRankState(), rate: .idle, shareURL: nil,
                                  topicName: "西湖夜游漫步", onRetry: {}, onSignIn: {}, onLoadRank: {},
                                  onRankScope: { _ in }, onRankPeriod: { _ in }, onSubmitRating: { _, _ in }, onDone: {})
            })
        case "r3prb-report-nodephotos":
            // Round 2 JREPORT-2: node rows with the player's own photo thumb; tap opens the paged preview.
            var report = sampleReport()
            report.nodes = report.nodes.map { node in
                var row = node
                if node.id != "2" { row.photoURL = "https://example.invalid/node-\(node.id).jpg" }
                return row
            }
            return player(NavigationStack {
                JourneyReportView(phase: .ready(report), memory: .idle, rank: JourneyRankState(), shareURL: nil,
                                  topicName: "西湖夜游漫步", hasSeats: false, onRetry: {}, onSignIn: {}, onLoadMemory: {},
                                  onLoadRank: {}, onRankScope: { _ in }, onRankPeriod: { _ in }, onOpenSettle: {}, onOpenSeats: {})
            })
        case "r3prb-promo-unknown":
            // JPROMO-3 section header + strong value; MP 未知 for a count the server did not send.
            let content = JourneyPromoContent(
                buckets: [],
                heldOrders: nil,
                campaigns: [JourneyPromoCampaign(id: "c1", title: "西湖夜游漫步", attributed: nil, paid: 2, refunded: nil)],
                links: [JourneyPromoLink(id: "l1", title: "西湖夜游漫步", active: true, expiresText: "2026-12-31")])
            return player(NavigationStack { JourneyPromoView(phase: .ready(content), onRetry: {}, onSignIn: {}) })
        case "r3prb-stamps-collage":
            // SALBUM-3: inside 收集册 the album is a 4-across, image-only, tilted collage.
            return player(NavigationStack {
                RoamStampAlbumView(reader: AlbumStampFixtureReader(empty: false))
                    .environment(\.collectionAlbumHosted, true)
            })
        default:
            return nil
        }
    }

    private static func sampleReport() -> JourneyReport {
        JourneyReport(
            legacy: false, result: .assisted, dateLabel: "2026-11-14", nodesText: "5/5", elapsedText: "48:20",
            score: 820, rank: 4, rankBasisCount: 5, penaltyText: nil, rewardItems: nil,
            runID: "run-1", topicID: "88", activityID: nil, coverURL: nil,
            nodes: [
                JourneyNodeRow(id: "1", name: "断桥", mode: nil, score: 200),
                JourneyNodeRow(id: "2", name: "白堤", mode: .skipped, score: nil),
                JourneyNodeRow(id: "3", name: "孤山", mode: .revealed, score: 120),
                JourneyNodeRow(id: "4", name: "平湖秋月", mode: nil, score: 250),
                JourneyNodeRow(id: "5", name: "苏堤", mode: nil, score: 250)
            ],
            finished: true, inProgress: false)
    }

    @MainActor private static func player<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().preferredColorScheme(.dark))
    }
}
#endif
