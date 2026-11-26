import SwiftUI

/// `PLAY-6` / `PLAY-8`: Play tools sheet (`游玩工具`) with captain lead actions at the top
/// (matching MP `pages/play/index.wxml:289-340`).
public struct PlayToolsAndLeadSheetView: View {
    public let lead: PlayLeadToolsState
    public let evidenceCount: Int
    public let thoughts: [PlayStoryThoughtItem]
    public let chapterCount: Int
    public let completedCount: Int
    public let remainingGamesCount: Int
    @Binding public var bgmEnabled: Bool
    @Binding public var narrationAutoplay: Bool
    @Binding public var reduceMotionOverride: Bool

    public var onVerifyMemberTicket: () -> Void = {}
    public var onShowGroupCode: () -> Void = {}
    public var onUnlockNextChapter: () -> Void = {}
    public var onReleaseStation: (PlayLeadSkipRequest) -> Void = { _ in }
    public var onLeadSettle: () -> Void = {}
    public var onOpenCast: () -> Void = {}
    public var onOpenEvidenceCards: () -> Void = {}
    public var onOpenRewards: () -> Void = {}
    public var onOpenEntryCode: () -> Void = {}
    public var onClose: () -> Void = {}
    /// PLAY-6a: false hides 内容 (cast / evidence / rewards / entry code) when the host has no destinations for them.
    public var showsContentRows: Bool = true

    public init(
        lead: PlayLeadToolsState = PlayLeadToolsState(),
        evidenceCount: Int = 0,
        thoughts: [PlayStoryThoughtItem] = [],
        chapterCount: Int = 0,
        completedCount: Int = 0,
        remainingGamesCount: Int = 0,
        bgmEnabled: Binding<Bool> = .constant(true),
        narrationAutoplay: Binding<Bool> = .constant(false),
        reduceMotionOverride: Binding<Bool> = .constant(false),
        onVerifyMemberTicket: @escaping () -> Void = {},
        onShowGroupCode: @escaping () -> Void = {},
        onUnlockNextChapter: @escaping () -> Void = {},
        onReleaseStation: @escaping (PlayLeadSkipRequest) -> Void = { _ in },
        onLeadSettle: @escaping () -> Void = {},
        onOpenCast: @escaping () -> Void = {},
        onOpenEvidenceCards: @escaping () -> Void = {},
        onOpenRewards: @escaping () -> Void = {},
        onOpenEntryCode: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        showsContentRows: Bool = true
    ) {
        self.lead = lead
        self.evidenceCount = evidenceCount
        self.thoughts = thoughts
        self.chapterCount = chapterCount
        self.completedCount = completedCount
        self.remainingGamesCount = remainingGamesCount
        self._bgmEnabled = bgmEnabled
        self._narrationAutoplay = narrationAutoplay
        self._reduceMotionOverride = reduceMotionOverride
        self.onVerifyMemberTicket = onVerifyMemberTicket
        self.onShowGroupCode = onShowGroupCode
        self.onUnlockNextChapter = onUnlockNextChapter
        self.onReleaseStation = onReleaseStation
        self.onLeadSettle = onLeadSettle
        self.onOpenCast = onOpenCast
        self.onOpenEvidenceCards = onOpenEvidenceCards
        self.onOpenRewards = onOpenRewards
        self.onOpenEntryCode = onOpenEntryCode
        self.onClose = onClose
        self.showsContentRows = showsContentRows
    }

    public var body: some View {
        NavigationStack {
            Form {
                leadSection
                contentSection
                if !thoughts.isEmpty {
                    Section("playTools.thoughts.section") {
                        ForEach(thoughts) { item in
                            LabeledContent(item.name, value: item.statusText)
                        }
                    }
                }
                if chapterCount > 0 {
                    Section("playTools.stats.section") {
                        LabeledContent("playTools.stats.chapters") { Text(verbatim: "\(chapterCount)").monospacedDigit() }
                        LabeledContent("playTools.stats.completed") { Text(verbatim: "\(completedCount)").monospacedDigit() }
                        if remainingGamesCount > 0 {
                            LabeledContent("playTools.stats.remainingGames") { Text(verbatim: "\(remainingGamesCount)").monospacedDigit() }
                        }
                    }
                }
                // MP pages/play/index.wxml 游玩工具 sheet: 背景音乐 / 到站自动播放 / 减少动态效果.
                Section("playTools.preferences.section") {
                    Toggle("playTools.pref.bgm", isOn: $bgmEnabled)
                        .accessibilityIdentifier("playTools.pref.bgm")
                    Toggle("playTools.pref.narration", isOn: $narrationAutoplay)
                        .accessibilityIdentifier("playTools.pref.narration")
                    Toggle("playTools.pref.reduceMotion", isOn: $reduceMotionOverride)
                        .accessibilityIdentifier("playTools.pref.reduceMotion")
                }
            }
            .navigationTitle(Text("playTools.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.done", action: onClose)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("playTools.sheet")
    }

    @ViewBuilder private var leadSection: some View {
        if lead.exists && lead.isLeader {
            Section("playTools.lead.section") {
                Button("playTools.lead.scanMemberTicket", action: onVerifyMemberTicket)
                Button("playTools.lead.showGroupCode", action: onShowGroupCode)
                if !lead.isDirectorRun {
                    Button("playTools.lead.unlockNext", action: onUnlockNextChapter)
                }
                ForEach(lead.skipRequests) { req in
                    Button {
                        onReleaseStation(req)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("playTools.lead.releaseStation")
                            Text(verbatim: "\(req.nickname) · \(req.nodeName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("playTools.lead.settle", action: onLeadSettle)
            }
        }
    }

    /// Content rows show only when the host wires them (a no-op default would be a dead button).
    @ViewBuilder private var contentSection: some View {
        if showsContentRows {
            Section("playTools.content.section") {
                Button("playTools.cast", action: onOpenCast)
                if evidenceCount > 0 {
                    Button {
                        onOpenEvidenceCards()
                    } label: {
                        LabeledContent("playTools.evidence") { Text(verbatim: "\(evidenceCount)").monospacedDigit() }
                    }
                }
                Button("playTools.rewards", action: onOpenRewards)
                Button("playTools.entryCode", action: onOpenEntryCode)
            }
        }
    }
}
