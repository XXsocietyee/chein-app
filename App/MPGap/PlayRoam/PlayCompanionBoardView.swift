import SwiftUI

/// mp-journey r3: MP `pages/play/index` 同行者榜 (升级3, opened from 游玩工具 `openBoardFromTools`). Pushed inside the
/// 游玩工具 sheet, the way 队伍位置 is.
/// Loading skeleton · error + 重试 (a failure is never shown as an empty board) · 这一场还没人上榜，你走一关就是第一名 ·
/// rows (rank, nickname or 同行者, N 关; a star on the first) · my row (rank or —, 我, N 关).
/// mp-journey-b r3: on a city run with an orient session (`orientBoard` set) the MP reads
/// `/api/orient/scoring/session/{id}/leaderboard` first: rows rank · 我 / 同行者 · score (SCORE, N.NN 分) or 已到达结局 /
/// 尚未到达结局 (ROUTE) · 用时 (or 用时待确认). Only scoring off (`ORIENT_SCORING_DISABLED` / `NOT_APPLICABLE`) falls back to
/// `/api/play/leaderboard`; any other failure is the error state.
struct PlayCompanionBoardView: View {
    let model: PlayExperienceCoordinator
    var orientBoard: (() async -> PlayOrientBoardRead)? = nil
    @State private var orient: PlayOrientBoard?
    @State private var board: PlayCompanionLeaderboard?
    @State private var failed = false
    @State private var loading = true

    var body: some View {
        List {
            content
        }
        .navigationTitle(Text("playx.leaderboard"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder private var content: some View {
        if loading && board == nil && orient == nil {
            // MP play/index.wxml:2029 board__loading 正在加载同行者榜.
            Section {
                ProgressView { Text("playx.board.loadingLabel") }
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("playx.board.loading")
        } else if failed {
            // MP :2031 board.error 榜单加载失败 + 重试: one state, retry inside.
            Section {
                CYEmptyState(systemImage: "exclamationmark.triangle", "playx.board.failed",
                             actionTitle: "action.retry", actionIdentifier: "playx.board.retry", kind: .failure) { Task { await load() } }
            }
        } else if let orient {
            orientContent(orient)
        } else if let board {
            Section {
                if board.entries.isEmpty {
                    CYEmptyState(systemImage: "flag.checkered", "playx.board.empty", messageIdentifier: "playx.board.empty")
                }
                ForEach(Array(board.entries.enumerated()), id: \.element.id) { index, row in
                    boardRow(rank: row.rank, name: row.name, score: row.score, first: index == 0)
                }
            }
            Section {
                LabeledContent {
                    Text("playx.board.score \(board.me.score)").monospacedDigit()
                } label: {
                    HStack(spacing: 12) {
                        Text(verbatim: board.me.rank.map(String.init) ?? "—").font(.headline).monospacedDigit()
                        Text("playx.board.me")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("playx.board.me")
            }
        }
    }

    @ViewBuilder private func orientContent(_ orient: PlayOrientBoard) -> some View {
        Section {
            if orient.rows.isEmpty {
                CYEmptyState(systemImage: "flag.checkered", "playx.board.empty", messageIdentifier: "playx.board.empty")
            }
            ForEach(Array(orient.rows.enumerated()), id: \.element.id) { index, row in
                orientRow(row, first: index == 0)
            }
        }
        if let me = orient.me {
            Section {
                orientRow(me, first: false)
                    .accessibilityIdentifier("playx.board.me")
            }
        }
    }

    /// MP `board__row`: rank · placeholder avatar · 我 / 同行者 · scoreText · elapsedText; a star on the first row.
    private func orientRow(_ row: PlayOrientBoard.Row, first: Bool) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                VStack(alignment: .trailing, spacing: 2) {
                    orientScore(row).monospacedDigit()
                    if let elapsed = row.elapsed {
                        Text(verbatim: elapsed).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                    } else {
                        Text("playx.board.orient.elapsedPending").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if first { Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityHidden(true) }
            }
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: String(row.rank)).font(.headline).monospacedDigit()
                Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                Text(LocalizedStringKey(row.mine ? "playx.board.me" : "playx.board.anonymous"))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func orientScore(_ row: PlayOrientBoard.Row) -> Text {
        if let points = row.points { return Text("playx.board.orient.points \(points)") }
        return Text(LocalizedStringKey(row.reachedEnding ? "playx.board.orient.reached" : "playx.board.orient.notReached"))
    }

    private func boardRow(rank: Int?, name: String?, score: Int, first: Bool) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                Text("playx.board.score \(score)").monospacedDigit()
                if first { Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityHidden(true) }
            }
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: rank.map(String.init) ?? "—").font(.headline).monospacedDigit()
                if let name, !name.isEmpty { Text(verbatim: name) } else { Text("playx.board.anonymous") }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        loading = true
        if let orientBoard {
            switch await orientBoard() {
            case .board(let value):
                orient = value; board = nil; failed = false; loading = false
                return
            case .failed:
                orient = nil; failed = true; loading = false
                return
            case .scoringOff:
                orient = nil
            }
        }
        do {
            board = try await model.readLeaderboard()
            failed = false
        } catch {
            failed = true
        }
        loading = false
    }
}
