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
    /// Player photo (`PostGameRunReport.Node.photoURL`). Empty stays nil. The viewer mounts only for https.
    var photoURL: String? = nil
}

struct JourneyNodePhoto: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
    static func url(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }
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
    /// Nodes finished SKIPPED or REVEALED. The settle cell shows only when this is above 0.
    var assistedCount: Int = 0
    /// 桌面完成 / 替代站开局. Nil hides the start-mode cell.
    var startModeText: String? = nil
    var showsAssistedCount: Bool { assistedCount > 0 }
    var showsStartMode: Bool { startModeText != nil }
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
    /// `JourneyRankBoardContract.Tab.scopeID`. Empty for world and for the team-to-team board.
    var scopeID: String = ""
    var id: String { kind.rawValue }

    init(kind: Kind, scopeID: String = "") {
        self.kind = kind
        self.scopeID = scopeID
    }

    init(_ tab: JourneyRankBoardContract.Tab) {
        switch tab.kind {
        case .quest: self.init(kind: .quest, scopeID: tab.scopeID)
        case .city: self.init(kind: .city, scopeID: tab.scopeID)
        case .country: self.init(kind: .country, scopeID: tab.scopeID)
        case .world: self.init(kind: .world, scopeID: tab.scopeID)
        case .club: self.init(kind: .club, scopeID: tab.scopeID)
        case .team: self.init(kind: .team, scopeID: tab.scopeID)
        }
    }
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
        .cySheet(isPresented: $moreShown) {
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
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { moreShown = false } label: { Label("action.close", systemImage: "xmark") }.labelStyle(.iconOnly) } }
            }
            .cySheet(detents: [.medium])
        }
        .cyDomainScreen(.player)
    }

    /// Laurel hero: wreath springs from 0.6 to 1, the number rolls up, then "top N%" rises.
    private func hero(rank: Int, board: JourneyRankBoard) -> some View {
        VStack(spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.sm) {
                // MP rank-board wxml:12/:20: the shipped `laurel.svg`, the right branch mirrored (MP assets).
                MPAsset.BadgeMedal.laurel.resizable().scaledToFit().frame(width: 48, height: 110).accessibilityHidden(true)
                Text(verbatim: String(heroOn ? rank : 0))
                    .cyText(.data2XL).monospacedDigit()
                    .contentTransition(.numericText(value: Double(heroOn ? rank : 0)))
                MPAsset.BadgeMedal.laurel.resizable().scaledToFit().frame(width: 48, height: 110)
                    .scaleEffect(x: -1, y: 1).accessibilityHidden(true)
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
    /// JREPORT-2: the station photo opened from a node row. https only.
    @State private var nodePhoto: JourneyNodePhoto?

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
        .cySheet(isPresented: $rankShown) {
            NavigationStack {
                ScrollView { JourneyRankBoardView(state: rank, onScope: onRankScope, onPeriod: onRankPeriod, onRetry: onLoadRank).padding(CYSpacing.pageHorizontal) }
                    .background(CYNight.ink0)
                    .navigationTitle(Text("mp.rank.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button { rankShown = false } label: { Label("action.close", systemImage: "xmark") }.labelStyle(.iconOnly) } }
            }
            .cySheet()
            .onAppear(perform: onLoadRank)
        }
        .cySheet(isPresented: $memoryShown) {
            NavigationStack {
                ScrollView { JourneyMemoryTimeline(phase: memory, onRetry: onLoadMemory).padding(CYSpacing.pageHorizontal) }
                    .background(CYNight.ink0)
                    .navigationTitle(Text("mp.report.memory"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button { memoryShown = false } label: { Label("action.close", systemImage: "xmark") }.labelStyle(.iconOnly) } }
            }
            .cySheet()
            .onAppear(perform: onLoadMemory)
        }
        .cySheet(isPresented: $feedbackShown) { Group {
            if case .ready(let report) = phase {
                JourneyFeedbackSheet(nodes: report.nodes, state: feedback, onSubmit: onSubmitFeedback,
                                     onRecheck: onRecheckFeedback, onReset: onResetFeedback, onClose: { feedbackShown = false })
            }
        }.cySheet(detents: [.large]) }
        .cySheet(item: $nodePhoto) { photo in
            // JREPORT-2 (MP `previewNodePhoto` → wx.previewImage over every node photo): paged, opened on the tapped one.
            JourneyNodePhotoPages(photos: nodePhotos, selected: photo.id, onClose: { nodePhoto = nil })
                .cySheet()
        }
        .cyDomainScreen(.player)
    }

    /// Every https node photo of this run, in node order (the pager's pages).
    private var nodePhotos: [JourneyNodePhoto] {
        guard case .ready(let report) = phase else { return [] }
        return report.nodes.compactMap { JourneyNodePhoto.url($0.photoURL).map(JourneyNodePhoto.init(url:)) }
    }

    /// N-JOURNEY-3 (r10): the 战报 as an inset-grouped List; each MP card is a Section with LabeledContent rows
    /// (MP subpackageJourney/pages/report/index.wxml). Requests, strings and identifiers are unchanged.
    private func ready(_ report: JourneyReport) -> some View {
        List {
            Section {
                VStack(spacing: CYSpacing.sm) {
                    let eyebrow = [report.dateLabel, topicName].compactMap { $0 }.joined(separator: " · ")
                    if !eyebrow.isEmpty { Text(verbatim: eyebrow).font(.footnote).foregroundStyle(.secondary) }
                    if let result = report.result {
                        Label { Text(result.label) } icon: { Image(systemName: result.win ? "trophy.fill" : "flag.checkered") }
                            .font(.headline)
                            .foregroundStyle(result.win ? Color.accentColor : Color.primary)
                    }
                    // 战报 (204:15044, skill-r2 SR2-07): 本局不计分 is said once, as the subtitle, never again as a tile.
                    if report.score == nil {
                        Text("mp.report.notScored").font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("journeyReport.notScored")
                    }
                    // A number the report cannot read is left out (SR1-43), so the row holds one to three stats.
                    let stats = Self.stats(report)
                    if !stats.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(Array(stats.enumerated()), id: \.offset) { _, item in
                                stat(Text(verbatim: item.value), item.label)
                            }
                        }
                        .padding(.top, CYSpacing.sm)
                        .accessibilityIdentifier("journeyReport.stats")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Section {
                Button { rankShown = true } label: {
                    Self.chevronRow(Text("mp.report.rankRow"), sub: report.rankBasisCount.map { Text("mp.report.rankBasis \($0)") },
                                    value: report.rank.map { Text("mp.report.rank \($0)") } ?? Text("mp.report.noRank"))
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("mp.report.rank.hint"))  // JREPORT-9: says it opens the board
                .accessibilityIdentifier("journeyReport.rank")
                if let penalty = report.penaltyText {
                    LabeledContent { Text(verbatim: penalty) } label: { Text("mp.report.penalty") }
                }
                if let items = report.rewardItems, items > 0 {
                    LabeledContent { Text("mp.report.items \(items)") } label: { Text("mp.report.backpack") }
                }
                if !report.legacy && report.runID != nil {
                    Button { memoryShown = true } label: { Self.chevronRow(Text("mp.report.memory")) }
                        .buttonStyle(.plain).accessibilityIdentifier("journeyReport.memory")
                }
                if hasSeats {
                    Button(action: onOpenSeats) { Self.chevronRow(Text("mp.report.seats")) }
                        .buttonStyle(.plain).accessibilityIdentifier("journeyReport.seats")
                }
                if feedbackAvailable {
                    Button { feedbackShown = true } label: { Self.chevronRow(Text("mp.feedback.entry")) }
                        .buttonStyle(.plain).accessibilityIdentifier("journeyReport.feedback")
                }
            }
            if !report.nodes.isEmpty {
                Section("mp.report.nodes") {
                    ForEach(report.nodes) { node in
                        nodeRow(node)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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

    /// A List row that opens something: title (+ sub) on the left, value and a disclosure chevron on the right.
    static func chevronRow(_ title: Text, sub: Text? = nil, value: Text? = nil) -> some View {
        HStack(spacing: CYSpacing.sm) {
            LabeledContent {
                if let value { value.monospacedDigit() }
            } label: {
                title
                if let sub { sub }
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private func nodeRow(_ node: JourneyNodeRow) -> some View {
        let photo = JourneyNodePhoto.url(node.photoURL)
        let row = HStack(spacing: CYSpacing.md) {
            if let photo { Self.nodeThumb(photo) }
            LabeledContent {
                (node.score.map { Text(verbatim: String($0)) } ?? Text("mp.report.node.notScored")).monospacedDigit()
            } label: {
                node.name.map { Text(verbatim: $0) } ?? Text("mp.report.node")
                if let mode = node.mode { mode == .skipped ? Text("mp.report.node.skipped") : Text("mp.report.node.revealed") }
            }
            if photo != nil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        if let photo {
            Button { nodePhoto = JourneyNodePhoto(url: photo) } label: { row }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("mp.report.node.photo \(node.name ?? "")"))
                .accessibilityIdentifier("journeyReport.node.photo." + node.id)
        } else {
            row.accessibilityElement(children: .combine)
        }
    }

    /// JREPORT-2 (MP report wxml:53-54): a 44 pt thumb of the player's own photo; the row button opens the viewer.
    static func nodeThumb(_ url: URL) -> some View {
        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { CYNight.ink2 }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
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
            // JREPORT-8: a long 用时 (1天 3小时 12分) in a third of the width stays one line and scales down.
            value.cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6).multilineTextAlignment(.center)
            Text(label).cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// JREPORT-2: the station-photo viewer. One page per photo; swipe moves between them; system close item.
struct JourneyNodePhotoPages: View {
    let photos: [JourneyNodePhoto]
    @State var selected: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            TabView(selection: $selected) {
                ForEach(photos) { photo in
                    AsyncImage(url: photo.url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        case .failure: CYEmptyState(systemImage: "photo", "mp.report.photos.empty")
                        default: ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .background(CYNight.ink0)
            .navigationTitle(Text("mp.report.photos.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) { Label("action.close", systemImage: "xmark") }.labelStyle(.iconOnly)
                }
            }
        }
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
            CYEmptyState(systemImage: "tray", "mp.report.memory.empty", messageIdentifier: "journeyMemory.empty")
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
                                    // JREPORT-7: cached, with the shared placeholder / failure tile; 16:10 instead of a fixed 180 pt crop.
                                    CYCachedAsyncImage(url.absoluteString, role: .cover)
                                        .frame(maxWidth: .infinity)
                                        // JREPORT-9: the photo is described, not silently hidden.
                                        .accessibilityLabel(Text("mp.report.memory.photo \(moment.name ?? "")"))
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
    /// JSETTLE-r7-1 完局优惠卡; nil hides it.
    var finishOffer: JourneyFinishOffer? { get }
    func load()
    func signIn()
    func loadRank()
    func selectRankScope(_ scope: JourneyRankScope)
    func selectRankPeriod(_ period: JourneyRankPeriod)
    func submitRating(stars: Int, text: String)
    func leave()
}

extension JourneySettleBinding {
    var finishOffer: JourneyFinishOffer? { nil }
}

@MainActor struct JourneySettleHost: View {
    let binding: any JourneySettleBinding
    let scope: JourneyRunScope
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    /// JSETTLE-r7-1: MP `openOffer` navigateTo(offer.url) — membership for the month pass, pass detail for a product.
    @State private var offerRoute: MPParityRoute?
    var body: some View {
        JourneySettleView(phase: binding.phase, rank: binding.rank, rate: binding.rate, shareURL: binding.shareURL,
                          topicName: binding.topicName ?? scope.topicName,
                          onRetry: { binding.load() }, onSignIn: { binding.signIn() }, onLoadRank: { binding.loadRank() },
                          onRankScope: { binding.selectRankScope($0) }, onRankPeriod: { binding.selectRankPeriod($0) },
                          onSubmitRating: { binding.submitRating(stars: $0, text: $1) }, onDone: { binding.leave(); dismiss() },
                          finishOffer: binding.finishOffer,
                          onOpenOffer: { offer in offerRoute = offer.kind == .pass ? .membership : .pass(productID: offer.id) },
                          onTrackOffer: { offer, event in
                              let payload = offer.trackPayload(topicID: scope.topicID)
                              MiniProgramAnalytics.track(session.analyticsEventClient, event, bizType: payload.bizType, bizID: payload.bizID,
                                                         pagePath: "subpackageJourney/settle/index", properties: payload.properties)
                          })
            .mpParityRouteDestination($offerRoute)
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
    /// JSETTLE-r7-1 (MP settle wxml:32): the 完局优惠卡 under the overview, only when the server has one on sale.
    var finishOffer: JourneyFinishOffer? = nil
    var onOpenOffer: (JourneyFinishOffer) -> Void = { _ in }
    /// `finish_offer_shown` / `finish_offer_click`. Does not turn `PlayStageAnalyticsGate` on.
    var onTrackOffer: (JourneyFinishOffer, String) -> Void = { _, _ in }

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
        // (each has its own next or skip; an earlier progress dot steps back, JSETTLE-8), and back leaves 结算 as it does on every pushed page.
        .cyDomainScreen(.player)
    }

    private func flow(_ report: JourneyReport) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: CYSpacing.xs) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule().fill(item.rawValue <= step.rawValue ? CYColor.selection : CYColor.borderSubtle).frame(height: 4)
                        // JSETTLE-8 (MP onBack = previous step): an earlier dot steps back; the system back still leaves 结算.
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                        .onTapGesture { if item.rawValue < step.rawValue { go(item) } }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("mp.settle.progress \(step.rawValue + 1)"))
            .accessibilityAdjustableAction { direction in
                if direction == .decrement, let previous = Step(rawValue: step.rawValue - 1) { go(previous) }
            }
            .cyAnimation(value: step)
            ZStack {
                switch step {
                case .overview: overview(report).transition(.opacity)
                case .rank:
                    ScrollView {
                        // N-JOURNEY-3 (r10): a system GroupBox instead of the drawn sheet card.
                        GroupBox {
                            JourneyRankBoardView(state: rank, onScope: onRankScope, onPeriod: onRankPeriod, onRetry: onLoadRank)
                        } label: {
                            // JSETTLE-9: MP `st-h` (32 rpx) is a card title.
                            (topicName.map { Text(verbatim: $0) } ?? Text("mp.settle.thisStage")).font(.headline)
                                .accessibilityAddTraits(.isHeader)
                        }
                        .padding(.horizontal, CYSpacing.pageHorizontal)
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

    /// Core hands the MP label (`RUN_START_MODE_LABEL`); the two known labels read from the catalog, anything else as sent.
    static func startModeLabel(_ text: String) -> Text {
        switch text {
        case "桌面完成": Text("mp.settle.startMode.desk")
        case "替代站开局": Text("mp.settle.startMode.alt")
        default: Text(verbatim: text)
        }
    }

    // 1 overview (204:15096): the seal, result, topic, rank, then score / stops. The score counts up once the text is
    // in; nothing redraws. Beats follow the moment table (seal from 0, text +950 ms, chips 0 / 50 / 90).
    private func overview(_ report: JourneyReport) -> some View {
        VStack(spacing: CYSpacing.md) {
            Spacer()
            // 结算 (204:15096, skill-r2 SR2-07): the `Moment/Art` seal at 96 pt lands over the stop count (6 / 6),
            // in place of the trophy and the row of ticks. No glow behind it (AGENTS 删减: no 发光).
            // N-JOURNEY-3 (r10): an SF Symbol seal instead of the drawn moment art (MP subpackageJourney/pages/settle).
            Label { Text("playx.completed") } icon: { Image(systemName: "checkmark.seal.fill").imageScale(.large) }
                .labelStyle(.iconOnly)
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            if let result = report.result {
                Text(result.label).font(.headline).foregroundStyle(Color.accentColor)
                    .settleRise(overviewOn, 0, skipped: skipped, reduceMotion: reduceMotion)
            }
            (topicName.map { Text(verbatim: $0) } ?? Text("mp.settle.thisRun")).cyText(.pageTitle).multilineTextAlignment(.center)
                .settleRise(overviewOn, 1, skipped: skipped, reduceMotion: reduceMotion)
            if let rank = report.rank, report.rankBasisCount != nil {
                Text("mp.settle.rank \(rank)").cyText(.sectionTitle).foregroundStyle(CYColor.textSecondary)
                    .settleRise(overviewOn, 2, skipped: skipped, reduceMotion: reduceMotion)
            }
            HStack(spacing: CYSpacing.xxxl) {
                if let score = report.score {
                    VStack(spacing: CYSpacing.xxs) {
                        Text(verbatim: String(shownScore)).cyText(.data2XL).lineLimit(1).minimumScaleFactor(0.7)
                            .cyNumericRoll(Double(shownScore))
                        // MP settle wxml:26 labels this cell 分数 (the report's stat is 解谜分).
                        Text("mp.settle.score").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("mp.settle.score") + Text(verbatim: " \(score)"))
                    .accessibilityIdentifier("journeySettle.score")
                    .task(id: skipped) { await countUp(to: score) }
                }
                // The stop count under the seal (6 / 6); unknown is a dash, never 0.
                VStack(spacing: CYSpacing.xxs) {
                    Text(verbatim: MPText.orDash(report.nodesText)).cyText(.data2XL).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    Text("mp.settle.nodes").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                // JSETTLE-4: assisted cell only when `showsAssistedCount`; start mode only when `showsStartMode`.
                // The words are the report's own labels (桌面完成 / 替代站开局).
                if report.showsAssistedCount {
                    VStack(spacing: CYSpacing.xxs) {
                        Text(verbatim: String(report.assistedCount)).cyText(.data2XL).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        Text("mp.settle.assisted").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("journeySettle.assisted")
                }
                // JSETTLE-4 (MP settle wxml:29): 开局 cell, catalog words for the two known labels.
                if report.showsStartMode, let start = report.startModeText {
                    VStack(spacing: CYSpacing.xxs) {
                        Self.startModeLabel(start).cyText(.cardTitle).multilineTextAlignment(.center)
                        Text("mp.settle.startMode").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("journeySettle.startMode")
                }
            }
            .settleRise(overviewOn, 3, skipped: skipped, reduceMotion: reduceMotion)
            // JSETTLE-r7-1: name and price as the server sent them; purchase stays gated (money TEST-only, owner #12).
            if let offer = finishOffer {
                JourneyFinishOfferCardView(offer: offer, purchaseGated: !PlatformPass.writesReachable,
                                           onAppearTrack: { onTrackOffer(offer, JourneyFinishOfferAnalytics.shown) },
                                           onTapOffer: {
                                               onTrackOffer(offer, JourneyFinishOfferAnalytics.click)
                                               onOpenOffer(offer)
                                           })
                    .accessibilityIdentifier("journeySettle.finishOffer")
                    .settleRise(overviewOn, 4, skipped: skipped, reduceMotion: reduceMotion)
            }
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
                                .font(.title)
                                .foregroundStyle(value <= stars ? Color.yellow : Color.secondary)
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
                            Label { Text(Self.tagKeys[index]) } icon: { if on { Image(systemName: "checkmark") } }
                        }
                        // N-JOURNEY-3 (r10): system bordered capsule buttons; selected = accent tint + checkmark.
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large)
                        .tint(on ? Color.accentColor : Color.secondary)
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                        .accessibilityIdentifier("journeySettle.tag.\(index)")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                    TextField(text: $review, axis: .vertical) { Text("mp.settle.rate.placeholder") }
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)  // N-JOURNEY-3 (r10): system field, no drawn box
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
    @MainActor private func cardImage(_ report: JourneyReport) -> (Image) {
        let card = JourneyShareCard(report: report, topicName: topicName, story: shareKind == .story)
            .frame(width: shareKind == .story ? 270 : 360)
            .environment(\.locale, locale)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:)) ?? journeySharePhotoFallback()
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
                if report.result?.win == true { Text("mp.report.result.legit").cyText(.label).foregroundStyle(CYNight.lanternHot) }
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

/// ShareLink item fallback. Kept outside a `View` so the symbol is a value, not a focusable element.
private func journeySharePhotoFallback() -> Image {
    Image(systemName: "photo")
}
