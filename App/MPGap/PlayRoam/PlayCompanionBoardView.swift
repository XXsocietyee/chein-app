import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-journey r3: MP `pages/play/index` 同行者榜 (升级3, opened from 游玩工具 `openBoardFromTools`). Pushed inside the
/// 游玩工具 sheet, the way 队伍位置 is.
/// Loading skeleton · error + 重试 (a failure is never shown as an empty board) · 这一场还没人上榜，你走一关就是第一名 ·
/// rows (rank, nickname or 同行者, N 关; a star on the first) · my row (rank or —, 我, N 关).
/// MP `openBoard`: a city-orientation round (mode 1) with an orient session reads the orient-scoring board
/// (`/api/orient/scoring/session/{id}/leaderboard`, rows 我 / 同行者 · points or 已到 / 未到结局 · mm:ss or 用时待确认);
/// only `ORIENT_SCORING_DISABLED` / `NOT_APPLICABLE` fall back to the play board, any other failure is the error state.
struct PlayCompanionBoardView: View {
    let model: PlayExperienceCoordinator
    var orientSessionID: Int? = nil
    var orientRead: ((Int) async throws -> OrientSessionLeaderboard)? = nil
    @State private var board: PlayCompanionLeaderboard?
    @State private var orientBoard: OrientSessionLeaderboard?
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
        if loading && board == nil && orientBoard == nil {
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
        } else if let orientBoard {
            orientContent(PlayOrientBoardRow.rows(orientBoard))
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

    @ViewBuilder private func orientContent(_ rows: (list: [PlayOrientBoardRow], me: PlayOrientBoardRow?)) -> some View {
        Section {
            if rows.list.isEmpty {
                CYEmptyState(systemImage: "flag.checkered", "playx.board.empty", messageIdentifier: "playx.board.empty")
            }
            ForEach(rows.list) { row in orientRow(row) }
        }
        if let me = rows.me {
            Section { orientRow(me) }
                .accessibilityIdentifier("playx.board.me")
        }
    }

    private func orientRow(_ row: PlayOrientBoardRow) -> some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                if let score = row.scoreText {
                    Text(verbatim: score).monospacedDigit()
                } else {
                    Text(row.reachedEnding ? LocalizedStringKey("orientScore.board.reached") : LocalizedStringKey("orientScore.board.notReached"))
                }
                if let elapsed = row.elapsed {
                    Text(verbatim: elapsed).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                } else {
                    Text("orientScore.board.elapsedUnknown").font(.caption).foregroundStyle(.secondary)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: String(row.rank)).font(.headline).monospacedDigit()
                Text(row.mine ? LocalizedStringKey("playx.board.me") : LocalizedStringKey("playx.board.anonymous"))
                if row.mine { Image(systemName: "person.fill").foregroundStyle(.tint).accessibilityHidden(true) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        loading = true
        if let orientSessionID, orientSessionID > 0, let orientRead {
            do {
                orientBoard = try await orientRead(orientSessionID)
                failed = false
                loading = false
                return
            } catch {
                if !PlayToolsSessionStats.hidesRows(for: error) {
                    failed = true
                    loading = false
                    return
                }
                orientBoard = nil
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
