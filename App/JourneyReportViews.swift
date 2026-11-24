import SwiftUI
import UIKit

// Mini-program `subpackageJourney/pages/report` (P7 battle report + P8 run memory + P9 board sheet),
// `pages/settle` (four steps: overview -> board -> rate -> share) and `components/rank-board`.
// Read-only: opening a report never finishes a run, grants rewards or creates a run. Unknown values are an em dash.

// MARK: - Shared facts

enum JourneyResult: String, Equatable {
    case legitimate = "LEGITIMATE_COMPLETION", assisted = "ASSISTED_COMPLETION", ended = "ENDED"
    case inProgress = "IN_PROGRESS", notStarted = "NOT_STARTED"
    var label: LocalizedStringKey {
        switch self {
        case .legitimate: "mp.report.result.legit"
        case .assisted: "mp.report.result.assisted"
        case .ended: "mp.report.result.ended"
        case .inProgress: "mp.report.result.inProgress"
        case .notStarted: "mp.report.result.notStarted"
        }
    }
    var win: Bool { self == .legitimate }
}

struct JourneyNodeRow: Identifiable, Equatable {
    enum Mode: Equatable { case skipped, revealed }
    let id: String
    let name: String?
    let mode: Mode?
    /// Nil when the node is not scored ("not scored"), never 0.
    let score: Int?
}

struct JourneyReport: Equatable {
    var legacy: Bool
    var result: JourneyResult?
    var dateLabel: String?
    /// "3/5" completed nodes; nil renders an em dash.
    var nodesText: String?
    var elapsedText: String?
    /// Nil: this run is not scored.
    var score: Int?
    var rank: Int?
    /// Rank basis "completed nodes N".
    var rankBasisCount: Int?
    var penaltyText: String?
    var rewardItems: Int?
    var runID: String?
    var topicID: String?
    var activityID: String?
    var coverURL: String?
    var nodes: [JourneyNodeRow]
    var finished: Bool
    var inProgress: Bool
}

struct JourneyMoment: Identifiable, Equatable {
    let id: String
    /// Day label, set only when the day changes.
    let dayText: String?
    let name: String?
    let timeText: String?
    let text: String?
    let pictureURL: URL?
}

struct JourneyMemory: Equatable {
    var participants: Int?
    var moments: [JourneyMoment]
    /// No consent fact from the server: other members' private photos are not shown.
    var peerPhotosHidden: Bool
    var hasPhotos: Bool { moments.contains { $0.pictureURL != nil } }
}

enum JourneyMemoryPhase: Equatable {
    case idle
    case loading
    case failed(String?)
    case empty
    case ready(JourneyMemory)
}

// MARK: - Rank board (components/rank-board)

struct JourneyRankScope: Identifiable, Hashable {
    enum Kind: String { case team, quest, teams, city, country, world, club }
    let kind: Kind
    var id: String { kind.rawValue }
    var label: LocalizedStringKey {
        switch kind {
        case .team: "mp.rank.scope.team"
        case .quest: "mp.rank.scope.quest"
        case .teams: "mp.rank.scope.teams"
        case .city: "mp.rank.scope.city"
        case .country: "mp.rank.scope.country"
        case .world: "mp.rank.scope.world"
        case .club: "mp.rank.scope.club"
        }
    }
}

enum JourneyRankPeriod: String, CaseIterable, Identifiable, Hashable { case all, week; var id: String { rawValue } }

struct JourneyRankEntry: Identifiable, Equatable {
    let id: String
    let rank: Int?
    let name: String?
    let avatarURL: URL?
    let scoreText: String
    let mine: Bool
}

struct JourneyRankStat: Identifiable, Equatable {
    enum Kind: String { case teamDone, activeMembers }
    let kind: Kind
    let value: String
    var id: String { kind.rawValue }
}

struct JourneyRankBoard: Equatable {
    var entries: [JourneyRankEntry]
    enum Basis: Equatable {
        case completedNodes, completedTasks, wholeTeam
        var label: LocalizedStringKey {
            switch self {
            case .completedNodes: "mp.rank.basis.nodes"
            case .completedTasks: "mp.rank.basis.tasks"
            case .wholeTeam: "mp.rank.basis.team"
            }
        }
    }
    /// Nil hides the header.
    var basis: Basis?
    var windowText: String?
    var unattributedRuns: Int?
    /// Runs with completions but no valid paid registration or pass; the server leaves them unranked.
    var unverifiedRuns: Int?
    var stats: [JourneyRankStat]
    /// Hero: my rank and "top N%" (only when the server gave the total and there are 5+ ranked players).
    var heroRank: Int?
    var topPercent: Int?
}

enum JourneyRankPhase: Equatable {
    case loading
    case refreshing(JourneyRankBoard)
    case failed(String?)
    case empty
    case ready(JourneyRankBoard)
}

struct JourneyRankState: Equatable {
    var tabs: [JourneyRankScope] = []
    var more: [JourneyRankScope] = []
    var scope: JourneyRankScope?
    var period: JourneyRankPeriod = .all
    var phase: JourneyRankPhase = .loading
}

struct JourneyRankBoardView: View {
    let state: JourneyRankState
    let onScope: (JourneyRankScope) -> Void
    let onPeriod: (JourneyRankPeriod) -> Void
    let onRetry: () -> Void
    @State private var moreShown = false
    @State private var heroOn = false
    @QuestifyReduceMotion private var reduceMotion

    private var board: JourneyRankBoard? {
        switch state.phase {
        case .ready(let board), .refreshing(let board): board
        default: nil
        }
    }

    private var scopeInMore: Bool { state.scope.map { state.more.contains($0) } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(spacing: CYSpacing.sm) {
                if state.tabs.count > 1 || scopeInMore {
                    Picker(selection: Binding(get: { scopeInMore ? nil : state.scope }, set: { if let new = $0 { onScope(new) } })) {
                        ForEach(state.tabs) { Text($0.label).tag(Optional($0)) }
                    } label: { Text("mp.rank.title") }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("rankBoard.scope")
                }
                if !state.more.isEmpty {
                    Button { moreShown = true } label: {
                        HStack(spacing: CYSpacing.xxs) {
                            if scopeInMore, let scope = state.scope { Text(scope.label) } else { Text("mp.rank.more") }
                            Image(systemName: "chevron.down")
                        }
                        .cyText(.label)
                        .padding(.horizontal, CYSpacing.md).frame(minHeight: CYSpacing.minTouchTarget)
                        .background(scopeInMore ? CYColor.selection.opacity(0.2) : CYNight.ink2, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("rankBoard.more")
                }
            }
            if let board, let rank = board.heroRank { hero(rank: rank, board: board) }
            if state.scope?.kind != .teams {
                Picker(selection: Binding(get: { state.period }, set: onPeriod)) {
                    Text("mp.rank.period.all").tag(JourneyRankPeriod.all)
                    Text("mp.rank.period.week").tag(JourneyRankPeriod.week)
                } label: { Text("mp.rank.period") }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("rankBoard.period")
            }
            switch state.phase {
            case .loading:
                CYLoadingStateView(rows: 3).accessibilityIdentifier("rankBoard.loading")
            case .failed(let message):
                CYStateLayout(kind: .failure, title: message.map { Text(verbatim: $0) } ?? Text("mp.rank.error"),
                              primary: (title: "action.retry", action: onRetry), primaryStyle: .secondary, primaryIdentifier: "rankBoard.retry", artSize: 96)
            case .empty:
                CYEmptyState(systemImage: "list.number", state.scope?.kind == .team ? "mp.rank.empty.team" : "mp.rank.empty", messageIdentifier: "rankBoard.empty")
            case .ready(let board), .refreshing(let board):
                list(board).opacity(state.phase == .ready(board) ? 1 : 0.55)
            }
        }
        .sheet(isPresented: $moreShown) {
            NavigationStack {
                List(state.more) { scope in
                    Button {
                        onScope(scope); moreShown = false
                    } label: {
                        HStack { Text(scope.label); Spacer(); if scope == state.scope { Image(systemName: "checkmark").foregroundStyle(CYColor.selection) } }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .accessibilityIdentifier("rankBoard.more.\(scope.id)")
                }
                .navigationTitle(Text("mp.rank.moreTitle"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { moreShown = false } } }
            }
            .cySheet(detents: [.medium])
        }
        .cyDomainScreen(.player)
    }

    /// Laurel hero: wreath springs from 0.6 to 1, the number rolls up, then "top N%" rises.
    private func hero(rank: Int, board: JourneyRankBoard) -> some View {
        VStack(spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: "laurel.leading").font(CYTypography.data2XL)
                Text(verbatim: String(heroOn ? rank : 0))
                    .cyText(.data2XL).monospacedDigit()
                    .contentTransition(.numericText(value: Double(heroOn ? rank : 0)))
                Image(systemName: "laurel.trailing").font(CYTypography.data2XL)
            }
            .foregroundStyle(CYNight.lanternHot)
            .scaleEffect(heroOn ? 1 : 0.6)
            .background { Circle().fill(CYNight.glow(radius: 70)).frame(width: 220, height: 220) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("mp.report.rank \(rank)"))
            if let pct = board.topPercent {
                Text("mp.rank.top \(pct)").cyText(.bodyMedium).foregroundStyle(CYColor.textSecondary)
                    .opacity(heroOn ? 1 : 0).offset(y: heroOn ? 0 : 8)
            }
            if !board.stats.isEmpty {
                HStack(spacing: CYSpacing.xl) {
                    ForEach(board.stats) { stat in
                        VStack(spacing: CYSpacing.xxs) {
                            (stat.kind == .teamDone ? Text("mp.rank.stat.teamDone") : Text("mp.rank.stat.active")).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            Text(verbatim: stat.value).cyText(.cardTitle).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.md)
        .onAppear {
            withAnimation(CYMotion.resolve(.spring(response: 0.5, dampingFraction: 0.6).delay(0.12), reduceMotion: reduceMotion)) { heroOn = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: heroOn) { _, on in on && !reduceMotion }
    }

    private func list(_ board: JourneyRankBoard) -> some View {
        MPCard {
            if board.basis != nil || board.windowText != nil {
                HStack {
                    if let basis = board.basis { Text(basis.label).cyText(.label) }
                    Spacer()
                    if let window = board.windowText { Text(verbatim: window).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                }
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                MPDivider()
            }
            ForEach(Array(board.entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { MPDivider() }
                HStack(spacing: CYSpacing.md) {
                    Text(verbatim: entry.rank.map(String.init) ?? MPText.unknown)
                        .cyText(.cardTitle).monospacedDigit()
                        .foregroundStyle((entry.rank ?? 99) <= 3 ? CYNight.lantern : CYColor.textSecondary)
                        .frame(width: 32)
                    MPAvatar(url: entry.avatarURL, initial: String((entry.name ?? "").prefix(1)), size: 32)
                    (entry.name.map { Text(verbatim: $0) } ?? Text("mp.rank.player")).cyText(.bodyMedium).cyWrapText()
                    Spacer()
                    Text(verbatim: entry.scoreText).cyText(.bodyMedium).monospacedDigit()
                }
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                .background(entry.mine ? CYColor.selection.opacity(0.16) : .clear)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("rankBoard.entry.\(entry.id)")
            }
            if let runs = board.unattributedRuns {
                MPDivider()
                Text("mp.rank.unattributed \(runs)").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
            }
            if let runs = board.unverifiedRuns {
                MPDivider()
                Text("mp.rank.unverified \(runs)").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                    .accessibilityIdentifier("rankBoard.unverified")
            }
        }
    }
}

// MARK: - Report

enum JourneyReportPhase: Equatable {
    case loading
    case missing
    case auth
    case gone
    case denied(String?)
    case failed
    case ready(JourneyReport)
}

/// Logic stub for Cursor: Core `PWaveReader.battleReport` (P7), P8 memory, P9 boards, choices (team tab); share issues a referral.
@MainActor protocol JourneyReportBinding: AnyObject, Observable {
    var phase: JourneyReportPhase { get }
    var memory: JourneyMemoryPhase { get }
    var rank: JourneyRankState { get }
    /// Landing link from an issued referral, or the public topic link; nil hides Share.
    var shareURL: URL? { get }
    func load()
    func signIn()
    func loadMemory()
    func loadRank()
    func selectRankScope(_ scope: JourneyRankScope)
    func selectRankPeriod(_ period: JourneyRankPeriod)
    /// U08-02 problem feedback for this run. False hides the entry.
    var feedbackAvailable: Bool { get }
    var feedback: JourneyFeedbackState { get }
    func submitFeedback(category: PostGameFeedbackCategory, nodeID: String?, text: String)
    /// Same request id, same text: reads the original receipt back.
    func recheckFeedback()
    func resetFeedback()
}

/// U08-02. Only `received` says sent; `unconfirmed` keeps the text locked and offers the same-request check.
enum JourneyFeedbackState: Equatable {
    case editing(PostGameFeedbackDraft.Problem?)
    case sending
    case unconfirmed
    case received(PostGameFeedbackReceipt)
    case refused(String?)
}

@MainActor struct JourneyReportHost: View {
    let binding: any JourneyReportBinding
    let scope: JourneyRunScope
    @State private var route: MPParityRoute?
    @Environment(\.mpParity) private var bindings

    var body: some View {
        JourneyReportView(
            phase: binding.phase, memory: binding.memory, rank: binding.rank, shareURL: binding.shareURL,
            topicName: scope.topicName, hasSeats: scope.registrationID != nil && bindings.journeySeats != nil,
            onRetry: { binding.load() }, onSignIn: { binding.signIn() }, onLoadMemory: { binding.loadMemory() }, onLoadRank: { binding.loadRank() },
            onRankScope: { binding.selectRankScope($0) }, onRankPeriod: { binding.selectRankPeriod($0) },
            feedbackAvailable: binding.feedbackAvailable, feedback: binding.feedback,
            onSubmitFeedback: { binding.submitFeedback(category: $0, nodeID: $1, text: $2) },
            onRecheckFeedback: { binding.recheckFeedback() }, onResetFeedback: { binding.resetFeedback() },
            onOpenSettle: bindings.journeySettle == nil ? nil : {
                var settle = scope
                if case .ready(let report) = binding.phase { settle.runID = report.runID ?? scope.runID }
                route = .journeySettle(settle)
            },
            onOpenSeats: { if let id = scope.registrationID { route = .journeySeats(registrationID: id) } })
            .task { binding.load() }
            // Reload once the shared sign-in sheet closes (MP onShow re-reads after login).
            .onChange(of: PlayerJourneySignInBridge.shared.presented) { was, now in if was && !now { binding.load() } }
            .mpParityRouteDestination($route)
    }
}

struct JourneyReportView: View {
    @Environment(\.dismiss) private var backFromMissing
    /// MP missing link: navigateBack (the sheet / push closes).
    private func missingBack() { backFromMissing() }
    let phase: JourneyReportPhase
    let memory: JourneyMemoryPhase
    let rank: JourneyRankState
    let shareURL: URL?
    let topicName: String?
    let hasSeats: Bool
    let onRetry: () -> Void
    let onSignIn: () -> Void
    let onLoadMemory: () -> Void
    let onLoadRank: () -> Void
    let onRankScope: (JourneyRankScope) -> Void
    let onRankPeriod: (JourneyRankPeriod) -> Void
    var feedbackAvailable = false
    var feedback: JourneyFeedbackState = .editing(nil)
    var onSubmitFeedback: (PostGameFeedbackCategory, String?, String) -> Void = { _, _, _ in }
    var onRecheckFeedback: () -> Void = {}
    var onResetFeedback: () -> Void = {}
    let onOpenSettle: (() -> Void)?
    let onOpenSeats: () -> Void
    @State private var rankShown = false
    @State private var memoryShown = false
    @State private var feedbackShown = false

    private var title: LocalizedStringKey {
        if case .ready(let report) = phase, report.legacy { return "mp.report.legacyTitle" }
        return "mp.report.title"
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 3).padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("journeyReport.loading")
            case .missing:
                CYEmptyState(systemImage: "map", "mp.common.linkExpired", messageIdentifier: "journeyReport.missing",
                             actionTitle: "action.back", actionIdentifier: "journeyReport.back", action: { missingBack() }).frame(maxHeight: .infinity)
            case .auth:
                CYEmptyState(systemImage: "person.crop.circle", "mp.report.auth", messageIdentifier: "journeyReport.auth",
                             actionTitle: "mp.common.signIn", actionIdentifier: "journeyReport.signIn", action: onSignIn).frame(maxHeight: .infinity)
            case .gone:
                CYEmptyState(systemImage: "map", "mp.report.gone", messageIdentifier: "journeyReport.gone").frame(maxHeight: .infinity)
            case .denied(let message):
                CYStateLayout(kind: .generic, title: message.map { Text(verbatim: $0) } ?? Text("mp.report.denied"))
                    .frame(maxHeight: .infinity).accessibilityIdentifier("journeyReport.denied")
            case .failed:
                CYErrorState("mp.report.error", retryTitle: "mp.common.reload", onRetry: onRetry).frame(maxHeight: .infinity)
                    .accessibilityIdentifier("journeyReport.error")
            case .ready(let report):
                ready(report)
            }
        }
        .background { MPNightGround() }
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $rankShown) {
            NavigationStack {
                ScrollView { JourneyRankBoardView(state: rank, onScope: onRankScope, onPeriod: onRankPeriod, onRetry: onLoadRank).padding(CYSpacing.pageHorizontal) }
                    .background(CYNight.ink0)
                    .navigationTitle(Text("mp.rank.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { rankShown = false } } }
            }
            .cySheet()
            .onAppear(perform: onLoadRank)
        }
        .sheet(isPresented: $memoryShown) {
            NavigationStack {
                ScrollView { JourneyMemoryTimeline(phase: memory, onRetry: onLoadMemory).padding(CYSpacing.pageHorizontal) }
                    .background(CYNight.ink0)
                    .navigationTitle(Text("mp.report.memory"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { memoryShown = false } } }
            }
            .cySheet()
            .onAppear(perform: onLoadMemory)
        }
        .sheet(isPresented: $feedbackShown) { Group {
            if case .ready(let report) = phase {
                JourneyFeedbackSheet(nodes: report.nodes, state: feedback, onSubmit: onSubmitFeedback,
                                     onRecheck: onRecheckFeedback, onReset: onResetFeedback, onClose: { feedbackShown = false })
            }
        }.cySheet(detents: [.large]) }
        .cyDomainScreen(.player)
    }

    private func ready(_ report: JourneyReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                VStack(spacing: CYSpacing.sm) {
                    let eyebrow = [report.dateLabel, topicName].compactMap { $0 }.joined(separator: " · ")
                    if !eyebrow.isEmpty { Text(verbatim: eyebrow).cyText(.caption).tracking(0.6).foregroundStyle(CYColor.textSecondary) }
                    if let result = report.result {
                        Text(result.label).cyText(.label)
                            .foregroundStyle(result.win ? CYNight.ink0 : CYColor.textPrimary)
                            .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                            .background(result.win ? AnyShapeStyle(CYNight.lantern) : AnyShapeStyle(CYNight.ink2), in: Capsule())
                    }
                    // 战报 (204:15044, skill-r2 SR2-07): 本局不计分 is said once, as the subtitle, never again as a tile.
                    if report.score == nil {
                        Text("mp.report.notScored").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("journeyReport.notScored")
                    }
                }
                .frame(maxWidth: .infinity)
                // 战报 (204:15044, xrefs-1 Adopt 4): the numbers with hairline dividers, no tile. A number the report
                // cannot read is left out (SR1-43: no 0 / 6 or — tiles), so the row holds one to three stats.
                let stats = Self.stats(report)
                if !stats.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { index, item in
                            if index > 0 { statDivider }
                            stat(Text(verbatim: item.value), item.label)
                        }
                    }
                    .padding(.vertical, CYSpacing.sm)
                    .accessibilityIdentifier("journeyReport.stats")
                }
                MPCard {
                    Button { rankShown = true } label: {
                        MPRow(title: Text("mp.report.rankRow"), sub: report.rankBasisCount.map { Text("mp.report.rankBasis \($0)") },
                              value: report.rank.map { Text("mp.report.rank \($0)") } ?? Text("mp.report.noRank"), strong: report.rank != nil, chevron: true)
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("journeyReport.rank")
                    if let penalty = report.penaltyText {
                        MPDivider()
                        MPRow(title: Text("mp.report.penalty"), value: Text(verbatim: penalty))
                    }
                    if let items = report.rewardItems, items > 0 {
                        MPDivider()
                        MPRow(title: Text("mp.report.backpack"), value: Text("mp.report.items \(items)"))
                    }
                    if !report.legacy && report.runID != nil {
                        MPDivider()
                        Button { memoryShown = true } label: { MPRow(title: Text("mp.report.memory"), chevron: true) }
                            .buttonStyle(.plain).accessibilityIdentifier("journeyReport.memory")
                    }
                    if hasSeats {
                        MPDivider()
                        Button(action: onOpenSeats) { MPRow(title: Text("mp.report.seats"), chevron: true) }
                            .buttonStyle(.plain).accessibilityIdentifier("journeyReport.seats")
                    }
                    if feedbackAvailable {
                        MPDivider()
                        Button { feedbackShown = true } label: { MPRow(title: Text("mp.feedback.entry"), chevron: true) }
                            .buttonStyle(.plain).accessibilityIdentifier("journeyReport.feedback")
                    }
                }
                if !report.nodes.isEmpty {
                    MPSectionHeader(title: "mp.report.nodes")
                    MPRows(items: report.nodes) { node in
                        MPRow(title: node.name.map { Text(verbatim: $0) } ?? Text("mp.report.node"),
                              sub: node.mode.map { $0 == .skipped ? Text("mp.report.node.skipped") : Text("mp.report.node.revealed") },
                              value: node.score.map { Text(verbatim: String($0)) } ?? Text("mp.report.node.notScored"))
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .refreshable { onRetry() }
        .safeAreaInset(edge: .bottom) {
            if report.finished {
                MPBottomBar {
                    HStack(spacing: CYSpacing.md) {
                        if let onOpenSettle { CYPillButton("mp.report.settle", style: .secondary, action: onOpenSettle).accessibilityIdentifier("journeyReport.settle") }
                        if let shareURL {
                            ShareLink(item: shareURL) { Text("mp.common.share").frame(maxWidth: .infinity) }
                                .buttonStyle(.cyPrimary).accessibilityIdentifier("journeyReport.share")
                        }
                    }
                }
            } else if report.inProgress {
                MPBottomBar { CYPillButton("mp.report.refresh", style: .secondary, action: onRetry).accessibilityIdentifier("journeyReport.refresh") }
            }
        }
    }

    private var statDivider: some View {
        Rectangle().fill(CYColor.borderSubtle).frame(width: 1, height: 28).accessibilityHidden(true)
    }

    /// The 战报 stats the report can actually read, in the frame's order: 完成站点, 用时, 得分.
    static func stats(_ report: JourneyReport) -> [(label: LocalizedStringKey, value: String)] {
        var rows: [(label: LocalizedStringKey, value: String)] = []
        if let nodes = report.nodesText, !nodes.isEmpty { rows.append(("mp.report.stat.nodes", nodes)) }
        if let elapsed = report.elapsedText, !elapsed.isEmpty { rows.append(("mp.report.stat.time", elapsed)) }
        if let score = report.score { rows.append(("mp.report.stat.score", String(score))) }
        return rows
    }

    private func stat(_ value: Text, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: CYSpacing.xxs) {
            value.cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                .cyWrapText(alignment: .center)
            Text(label).cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// P8 memory as one timeline: the day is written once per change, one dot per stop, photo under its stop.
struct JourneyMemoryTimeline: View {
    let phase: JourneyMemoryPhase
    let onRetry: () -> Void

    var body: some View {
        switch phase {
        case .idle, .loading:
            CYLoadingStateView(rows: 3).accessibilityIdentifier("journeyMemory.loading")
        case .failed(let message):
            CYStateLayout(kind: .failure, title: message.map { Text(verbatim: $0) } ?? Text("mp.report.memory.error"),
                          primary: (title: "action.retry", action: onRetry), primaryStyle: .secondary, primaryIdentifier: "journeyMemory.retry", artSize: 96)
        case .empty:
            CYEmptyState(systemImage: "photo.on.rectangle", "mp.report.memory.empty", messageIdentifier: "journeyMemory.empty")
        case .ready(let memory):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let count = memory.participants, count > 1 {
                    Text("mp.report.memory.together \(count)").cyText(.label).foregroundStyle(CYColor.textSecondary)
                }
                if memory.hasPhotos {
                    Label("mp.report.memory.private", systemImage: "lock")
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("journeyMemory.private")
                }
                if memory.peerPhotosHidden, (memory.participants ?? 0) > 1 {
                    Text("mp.report.memory.peerHidden").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        .accessibilityIdentifier("journeyMemory.peerHidden")
                }
                ForEach(memory.moments) { moment in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        if let day = moment.dayText { Text(verbatim: day).cyText(.label).foregroundStyle(CYNight.lantern).padding(.top, CYSpacing.sm) }
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            VStack(spacing: 0) {
                                Circle().fill(CYNight.lantern).frame(width: 10, height: 10).padding(.top, 5)
                                Rectangle().fill(CYColor.borderSubtle).frame(width: 2)
                            }
                            .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                HStack {
                                    (moment.name.map { Text(verbatim: $0) } ?? Text("mp.report.node")).cyText(.bodyMedium)
                                    Spacer()
                                    if let time = moment.timeText { Text(verbatim: time).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                                }
                                if let text = moment.text { Text(verbatim: text).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                                if let url = moment.pictureURL {
                                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { CYNight.ink2 }
                                        .frame(height: 180).frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.bottom, CYSpacing.md)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Settle

enum JourneySettlePhase: Equatable {
    case loading
    case missing
    case auth
    case failed(gone: Bool)
    case notFinished
    case ready(JourneyReport)
}

enum JourneyRateState: Equatable {
    case idle
    case busy
    /// Server sentence (content safety, rate limit) or the network message; stars and text stay.
    case error(String)
    case thanks
}

/// Logic stub for Cursor: battle report + `/api/comment/add` (owner type 1 topic / 2 session) + referral issue on share.
@MainActor protocol JourneySettleBinding: AnyObject, Observable {
    var phase: JourneySettlePhase { get }
    var rank: JourneyRankState { get }
    var rate: JourneyRateState { get }
    var shareURL: URL? { get }
    /// Topic name filled from `/api/topic/info-to-user` when the link did not carry it.
    var topicName: String? { get }
    func load()
    func signIn()
    func loadRank()
    func selectRankScope(_ scope: JourneyRankScope)
    func selectRankPeriod(_ period: JourneyRankPeriod)
    func submitRating(stars: Int, text: String)
    func leave()
}

@MainActor struct JourneySettleHost: View {
    let binding: any JourneySettleBinding
    let scope: JourneyRunScope
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        JourneySettleView(phase: binding.phase, rank: binding.rank, rate: binding.rate, shareURL: binding.shareURL,
                          topicName: binding.topicName ?? scope.topicName,
                          onRetry: { binding.load() }, onSignIn: { binding.signIn() }, onLoadRank: { binding.loadRank() },
                          onRankScope: { binding.selectRankScope($0) }, onRankPeriod: { binding.selectRankPeriod($0) },
                          onSubmitRating: { binding.submitRating(stars: $0, text: $1) }, onDone: { binding.leave(); dismiss() })
            .task { binding.load() }
            // Reload once the shared sign-in sheet closes (MP onShow re-reads after login).
            .onChange(of: PlayerJourneySignInBridge.shared.presented) { was, now in if was && !now { binding.load() } }
    }
}

struct JourneySettleView: View {
    @Environment(\.dismiss) private var backFromMissing
    /// MP missing link: navigateBack (the sheet / push closes).
    private func missingBack() { backFromMissing() }
    let phase: JourneySettlePhase
    let rank: JourneyRankState
    let rate: JourneyRateState
    let shareURL: URL?
    let topicName: String?
    let onRetry: () -> Void
    let onSignIn: () -> Void
    let onLoadRank: () -> Void
    let onRankScope: (JourneyRankScope) -> Void
    let onRankPeriod: (JourneyRankPeriod) -> Void
    let onSubmitRating: (Int, String) -> Void
    let onDone: () -> Void

    enum Step: Int, CaseIterable { case overview, rank, rate, share }
    enum ShareKind: String, CaseIterable, Identifiable { case post, story; var id: String { rawValue } }

    /// Rating chips (submitted ahead of the text, joined by the server-side format the mini-program uses).
    static let tagKeys: [LocalizedStringKey] = ["mp.settle.tag.story", "mp.settle.tag.places", "mp.settle.tag.puzzles", "mp.settle.tag.far", "mp.settle.tag.hints", "mp.settle.tag.hard"]
    static let reviewMax = 500

    @State private var step: Step = .overview
    @State private var stars = 0
    @State private var tags: Set<Int> = []
    @State private var review = ""
    @State private var localError: LocalizedStringKey?
    @State private var shareKind: ShareKind = .post
    @State private var overviewOn = false
    @State private var shownScore = 0
    /// A tap on the overview jumps every beat to its settled frame (SR2-49: every moment is skippable).
    @State private var skipped = false
    /// The success haptic 150 ms after the seal's contact (skill-r2 SR2-49 "Seal lands").
    @State private var sealSuccess = false
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        Group {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 3).padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("journeySettle.loading")
            case .missing:
                CYEmptyState(systemImage: "map", "mp.common.linkExpired", messageIdentifier: "journeySettle.missing",
                             actionTitle: "action.back", actionIdentifier: "journeySettle.back", action: { missingBack() }).frame(maxHeight: .infinity)
            case .auth:
                CYEmptyState(systemImage: "person.crop.circle", "mp.settle.auth", messageIdentifier: "journeySettle.auth",
                             actionTitle: "mp.common.signIn", actionIdentifier: "journeySettle.signIn", action: onSignIn).frame(maxHeight: .infinity)
            case .failed(let gone):
                if gone {
                    CYEmptyState(systemImage: "map", "mp.report.gone", messageIdentifier: "journeySettle.gone").frame(maxHeight: .infinity)
                } else {
                    CYErrorState("mp.settle.error", retryTitle: "mp.common.reload", onRetry: onRetry).frame(maxHeight: .infinity)
                        .accessibilityIdentifier("journeySettle.error")
                }
            case .notFinished:
                CYEmptyState(systemImage: "figure.walk", "mp.settle.notFinished", messageIdentifier: "journeySettle.notFinished").frame(maxHeight: .infinity)
            case .ready(let report):
                flow(report)
            }
        }
        .cyPushedChrome(domain: .player)
        .navigationTitle(Text("mp.settle.title"))
        .navigationBarTitleDisplayMode(.inline)
        // consist-1 type-and-chrome: the system back stays; no custom chevron replaces it. The steps only go forward
        // (each has its own next or skip), and back leaves 结算 as it does on every pushed page.
        .cyDomainScreen(.player)
    }

    private func flow(_ report: JourneyReport) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: CYSpacing.xs) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule().fill(item.rawValue <= step.rawValue ? CYColor.selection : CYColor.borderSubtle).frame(height: 4)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.sm)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("mp.settle.progress \(step.rawValue + 1)"))
            .cyAnimation(value: step)
            ZStack {
                switch step {
                case .overview: overview(report).transition(.opacity)
                case .rank:
                    ScrollView {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            (topicName.map { Text(verbatim: $0) } ?? Text("mp.settle.thisStage")).cyText(.sectionTitle)
                            JourneyRankBoardView(state: rank, onScope: onRankScope, onPeriod: onRankPeriod, onRetry: onLoadRank)
                        }
                        .padding(CYSpacing.lg)
                        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))
                        .padding(.horizontal, CYSpacing.sm)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .onAppear(perform: onLoadRank)
                case .rate: rateStep.transition(.opacity)
                case .share: shareStep(report).transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity)
            footer(report)
        }
        .task(id: rate) {
            guard rate == .thanks, step == .rate else { return }
            try? await Task.sleep(for: .seconds(CYMotion.Delay.sheetDismiss))
            guard !Task.isCancelled, step == .rate else { return }
            go(.share)
        }
    }

    private var ratePhase: CYResultPhase {
        switch rate {
        case .busy: return .loading
        case .thanks: return .done
        case .idle, .error: return .idle
        }
    }

    // 1 overview (204:15096): the seal, result, topic, rank, then score / stops. The score counts up once the text is
    // in; nothing redraws. Beats follow the moment table (seal from 0, text +950 ms, chips 0 / 50 / 90).
    private func overview(_ report: JourneyReport) -> some View {
        VStack(spacing: CYSpacing.md) {
            Spacer()
            // 结算 (204:15096, skill-r2 SR2-07): the `Moment/Art` seal at 96 pt lands over the stop count (6 / 6),
            // in place of the trophy and the row of ticks. No glow behind it (AGENTS 删减: no 发光).
            CYMomentSeal(text: Text("playx.completed"), landed: overviewOn)
                .frame(height: 160)
                .accessibilityHidden(true)
            if let result = report.result {
                Text(result.label).cyText(.label).tracking(0.6).foregroundStyle(CYNight.lanternHot)
                    .settleRise(overviewOn, 0, skipped: skipped, reduceMotion: reduceMotion)
            }
            (topicName.map { Text(verbatim: $0) } ?? Text("mp.settle.thisRun")).cyText(.display).multilineTextAlignment(.center)
                .settleRise(overviewOn, 1, skipped: skipped, reduceMotion: reduceMotion)
            if let rank = report.rank, report.rankBasisCount != nil {
                Text("mp.settle.rank \(rank)").cyText(.sectionTitle).foregroundStyle(CYColor.textSecondary)
                    .settleRise(overviewOn, 2, skipped: skipped, reduceMotion: reduceMotion)
            }
            HStack(spacing: CYSpacing.xxxl) {
                if let score = report.score {
                    VStack(spacing: CYSpacing.xxs) {
                        Text(verbatim: String(shownScore)).cyText(.data2XL)
                            .cyNumericRoll(Double(shownScore))
                        Text("mp.report.stat.score").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("mp.report.stat.score") + Text(verbatim: " \(score)"))
                    .accessibilityIdentifier("journeySettle.score")
                    .task(id: skipped) { await countUp(to: score) }
                }
                // The stop count under the seal (6 / 6); unknown is a dash, never 0.
                VStack(spacing: CYSpacing.xxs) {
                    Text(verbatim: MPText.orDash(report.nodesText)).cyText(.data2XL).monospacedDigit()
                    Text("mp.settle.nodes").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            .settleRise(overviewOn, 3, skipped: skipped, reduceMotion: reduceMotion)
            Spacer()
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .contentShape(Rectangle())
        .onTapGesture { if !skipped { skipped = true } }
        .cyHaptic(.success, trigger: sealSuccess) { _, new in new }
        .onAppear {
            // The seal owns its spring (`CYMotion.seal`) and its heavy impact at contact.
            overviewOn = true
        }
        .task {
            // Seal contact ≈ 180 ms after it starts; success follows 150 ms later. Haptics stay under Reduce Motion.
            try? await Task.sleep(for: .milliseconds(330))
            guard !Task.isCancelled else { return }
            sealSuccess = true
        }
    }

    /// The score counts up from 0 once the text beat is in (`cyNumericRoll`: tabular digits, numericText, one roll).
    /// Reduce Motion cross-fades the digits; a skip lands on the value at once.
    private func countUp(to score: Int) async {
        guard shownScore != score else { return }
        if !(reduceMotion || skipped) {
            try? await Task.sleep(for: .seconds(CYMotion.Delay.momentText + CYMotion.Stagger.delay(3)))
            guard !Task.isCancelled else { return }
        }
        shownScore = score
    }

    // 3 rate: five gold stars light in order, chips after a star, one line, errors under the field.
    private var rateStep: some View {
        ScrollView {
            VStack(spacing: CYSpacing.lg) {
                Text("mp.settle.rate.title").cyText(.pageTitle).padding(.top, CYSpacing.xl)
                HStack(spacing: CYSpacing.md) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            stars = value; localError = nil
                        } label: {
                            Image(systemName: value <= stars ? "star.fill" : "star")
                                .cyText(.dataXL)
                                .foregroundStyle(value <= stars ? CYNight.lantern : CYColor.textTertiary)
                                .scaleEffect(value <= stars && !reduceMotion ? 1.08 : 1)
                                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5).delay(Double(value) * 0.04), value: stars)
                                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("mp.settle.stars \(value)"))
                        .accessibilityAddTraits(value <= stars ? [.isSelected] : [])
                        .accessibilityIdentifier("journeySettle.star.\(value)")
                    }
                }
                .cyHaptic(.impactLight, trigger: stars)
                if stars > 0 {
                    FlowChips(count: Self.tagKeys.count) { index in
                        let on = tags.contains(index)
                        Button {
                            if on { tags.remove(index) } else { tags.insert(index) }
                            localError = nil
                        } label: {
                            Text(Self.tagKeys[index]).cyText(.label)
                                .foregroundStyle(on ? CYColor.textOnAccent : CYColor.textSecondary)
                                .padding(.horizontal, CYSpacing.md).frame(minHeight: 36)
                                .background(on ? AnyShapeStyle(CYColor.selection) : AnyShapeStyle(CYColor.bgRaised), in: Capsule())
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                        .accessibilityIdentifier("journeySettle.tag.\(index)")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                    TextField(text: $review, axis: .vertical) { Text("mp.settle.rate.placeholder") }
                        .lineLimit(3...6)
                        .padding(CYSpacing.lg)
                        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .onChange(of: review) { _, value in
                            if value.count > Self.reviewMax { review = String(value.prefix(Self.reviewMax)) }
                            localError = nil
                        }
                        .accessibilityIdentifier("journeySettle.review")
                    Text(verbatim: "\(review.count) / \(Self.reviewMax)").cyText(.caption).monospacedDigit().foregroundStyle(CYColor.textTertiary)
                }
                if let localError { MPInlineError(text: Text(localError)) }
                else if case .error(let message) = rate { MPInlineError(text: Text(verbatim: message)) }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .cyAnimation(value: stars > 0)
        }
    }

    // 4 share: post / story card, then one row: share + done.
    private func shareStep(_ report: JourneyReport) -> some View {
        VStack(spacing: CYSpacing.lg) {
            Picker(selection: $shareKind) {
                Text("mp.settle.share.post").tag(ShareKind.post)
                Text("mp.settle.share.story").tag(ShareKind.story)
            } label: { Text("mp.settle.share.kind") }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("journeySettle.shareKind")
            JourneyShareCard(report: report, topicName: topicName, story: shareKind == .story)
                .frame(maxWidth: shareKind == .story ? 260 : .infinity)
                .cyAnimation(value: shareKind)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.top, CYSpacing.md)
    }

    @ViewBuilder private func footer(_ report: JourneyReport) -> some View {
        MPBottomBar {
            switch step {
            case .overview:
                // Design hand-off r1 PL-12: 完成 is the primary on the result screen; 看排行榜 is the secondary pill.
                CYPillButton("action.done", size: .moment, action: onDone).accessibilityIdentifier("journeySettle.done")
                CYPillButton("mp.settle.toRank", style: .secondary) { go(.rank) }.accessibilityIdentifier("journeySettle.toRank")
            case .rank:
                CYPillButton("mp.settle.toRate") { go(.rate) }.accessibilityIdentifier("journeySettle.toRate")
            case .rate:
                // The rating result lands in the button that sent it (xrefs-1 B.0 "in place"): 提交 → 正在提交 → 已提交,
                // then the flow moves on to 分享 after the hold. No thank-you card over the page.
                CYResultButton("mp.settle.rate.submit", loading: "mp.settle.rate.submitting", done: "mp.settle.rate.submitted",
                               phase: ratePhase, action: submit)
                    .identifier("journeySettle.submitRate")
                Button("mp.settle.skip") { go(.share) }.cyText(.label).foregroundStyle(CYColor.textSecondary)
                    .frame(minHeight: CYSpacing.minTouchTarget).accessibilityIdentifier("journeySettle.skip")
            case .share:
                HStack(spacing: CYSpacing.md) {
                    if let shareURL {
                        // JSETTLE-1: the link travels with the rendered card as its preview (mini-program share imageUrl).
                        ShareLink(item: shareURL,
                                  preview: SharePreview(topicName.map { Text(verbatim: $0) } ?? Text("mp.settle.thisRun"), image: cardImage(report))) {
                            Text("mp.common.share").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.cyPrimary).accessibilityIdentifier("journeySettle.share")
                    }
                    CYPillButton("action.done", style: .secondary, action: onDone).accessibilityIdentifier("journeySettle.finish")
                }
            }
        }
    }

    /// The share card as an image (post or story size), the same face the step shows.
    @MainActor private func cardImage(_ report: JourneyReport) -> Image {
        let card = JourneyShareCard(report: report, topicName: topicName, story: shareKind == .story)
            .frame(width: shareKind == .story ? 270 : 360)
            .environment(\.locale, locale)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:)) ?? Image(systemName: "photo")
    }

    private func go(_ next: Step) {
        withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { step = next }
    }

    private func submit() {
        guard stars > 0 else { localError = "mp.settle.rate.needStars"; return }
        let picked = Self.tagKeys.indices.filter { tags.contains($0) }.map { String(localized: Self.tagResource[$0], locale: locale) }
        let text = review.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = [picked.joined(separator: "，"), text].filter { !$0.isEmpty }.joined(separator: "。")
        guard !joined.isEmpty else { localError = "mp.settle.rate.needText"; return }
        onSubmitRating(stars, String(joined.prefix(Self.reviewMax)))
    }

    private static let tagResource: [String.LocalizationValue] = ["mp.settle.tag.story", "mp.settle.tag.places", "mp.settle.tag.puzzles", "mp.settle.tag.far", "mp.settle.tag.hints", "mp.settle.tag.hard"]
}

private extension View {
    /// 结算 text beats: headline offset 12 → 0 with opacity on `CYMotion.moment` from +950 ms, the following lines
    /// 0 / 50 / 90 ms after it. Reduce Motion: opacity only (200 ms). A skip lands them at once.
    func settleRise(_ on: Bool, _ index: Int, skipped: Bool, reduceMotion: Bool) -> some View {
        let delay = CYMotion.Delay.momentText + CYMotion.Stagger.delay(index)
        let animation: Animation? = skipped ? nil : (reduceMotion ? CYMotion.reduced.delay(delay) : CYMotion.moment.delay(delay))
        return opacity(on || skipped ? 1 : 0).offset(y: on || skipped || reduceMotion ? 0 : 12)
            .animation(animation, value: on)
            .animation(nil, value: skipped)
    }
}

/// Wrapping chip row.
private struct FlowChips<Chip: View>: View {
    let count: Int
    @ViewBuilder let chip: (Int) -> Chip
    var body: some View {
        FlowLayoutMP(spacing: CYSpacing.sm) { ForEach(0..<count, id: \.self) { chip($0) } }
    }
}

private struct FlowLayoutMP: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing; row = max(row, size.height); maxX = max(maxX, x - spacing)
        }
        return CGSize(width: maxX, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}

/// Share card: cover wash, badge, "cleared", topic, nodes / score / rank line, the 城瘾 mark.
struct JourneyShareCard: View {
    let report: JourneyReport
    let topicName: String?
    let story: Bool

    var body: some View {
        ZStack {
            if report.coverURL != nil {
                CYCachedAsyncImage(report.coverURL, role: .cover).scaledToFill().opacity(0.35).accessibilityHidden(true)
            }
            LinearGradient(colors: [CYNight.indigo, CYNight.ink0], startPoint: .top, endPoint: .bottom).opacity(0.85)
            VStack(spacing: CYSpacing.md) {
                Image(systemName: "rosette").font(CYTypography.display).foregroundStyle(CYNight.lanternHot)
                    .background { Circle().fill(CYNight.glow(radius: 40)).frame(width: 140, height: 140) }
                if report.result?.win == true { Text("mp.report.result.legit").cyText(.label).tracking(0.6).foregroundStyle(CYNight.lanternHot) }
                (topicName.map { Text(verbatim: $0) } ?? Text("mp.settle.thisRun")).cyText(.sectionTitle).multilineTextAlignment(.center)
                HStack(spacing: CYSpacing.xs) {
                    Text("mp.settle.share.nodes \(MPText.orDash(report.nodesText))")
                    if let score = report.score { Text(verbatim: "·"); Text("mp.settle.share.score \(score)") }
                    if let rank = report.rank { Text(verbatim: "·"); Text("mp.report.rank \(rank)") }
                }
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            .padding(CYSpacing.xl)
            VStack { Spacer(); Text("mp.brand").cyText(.label).foregroundStyle(CYColor.textTertiary).padding(.bottom, CYSpacing.md) }
        }
        .aspectRatio(story ? 9.0 / 16.0 : 4.0 / 5.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .cyFoil(cornerRadius: CYRadius.lg, strength: 0.4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("journeySettle.card")
    }
}
