#if DEBUG
import SwiftUI

/// `--design-fixture r3-inplace` (and `r3-inplace-light`): the shared in-place result kit in every state, side by side,
/// so the receipt can show Player/Button Default · Loading · Done and Player/Toast Progress · Done without a server.
/// Synthetic copy, labelled FIXTURE in the shots.
struct R3InPlaceKitFixture: View {
    var domain: ThemeDomain = .player
    @State private var livePhase: CYResultPhase = .idle
    @State private var toast: CYResultToastState? = CYResultToastState(.done, "报名成功", actionTitle: "查看")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    label("Player/Button · Default · Loading · Done")
                    CYResultButton(verbatim: "确认圈地 · 120 积分", loading: "正在确认", done: "已圈下", phase: .idle) {}
                    CYResultButton(verbatim: "确认圈地 · 120 积分", loading: "正在确认", done: "已圈下", phase: .loading) {}
                    CYResultButton(verbatim: "确认圈地 · 120 积分", loading: "正在确认", done: "已圈下", phase: .done) {}
                    HStack {
                        CYResultButton(verbatim: "报名", loading: "正在报名", done: "已报名", phase: livePhase, fullWidth: false) {
                            Task { _ = await CYResultRunner.run($livePhase) { try await Task.sleep(for: .seconds(1)) } }
                        }
                        .identifier("r3.inplace.live")
                        Button("重置") { livePhase = .idle }.frame(minHeight: 44)
                    }
                    label("Player/Toast · Progress")
                    CYResultToast(state: CYResultToastState(.progress, "正在报名…"))
                    label("积分 · one number with a −N chip")
                    CYDeltaNumber(value: 1286, delta: -120, font: .title2.weight(.bold))
                    label("Player/Stat Tile Emphasis=Plain")
                    CYPlainStatRow(stats: [
                        CYPlainStat(id: "a", value: "1286", label: "积分", rollValue: 1286),
                        CYPlainStat(id: "b", value: "2 / 9", label: "持有"),
                        CYPlainStat(id: "c", value: "12 天", label: "赛季剩余")
                    ])
                    label("Player/Streak Row (3 days)")
                    CYStreakRow(streakDays: 3)
                    label("Designed cover (no photo)")
                    CYDesignedCover(title: "陆家嘴天际线 · 未来都市观察局").aspectRatio(16 / 9, contentMode: .fit)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.bottom, 120)
            }
            .navigationTitle(Text(verbatim: "In-place kit · FIXTURE")).navigationBarTitleDisplayMode(.inline)
            .cyResultToast($toast, dwell: 600)
        }
        .cyDomainScreen(domain)
    }

    private func label(_ text: String) -> some View {
        Text(verbatim: text).cyText(.caption).foregroundStyle(.secondary)
    }
}
#endif
