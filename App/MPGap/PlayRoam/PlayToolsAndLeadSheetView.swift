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
        onClose: @escaping () -> Void = {}
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
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("playTools.title"), style: .player, onClose: onClose)
            List {
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
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text("playTools.lead.releaseStation")
                                        .cyText(.body)
                                    Text("\(req.nickname) · \(req.nodeName)")
                                        .cyText(.meta)
                                        .foregroundStyle(CYColor.textSecondary)
                                }
                            }
                        }
                        Button("playTools.lead.settle", action: onLeadSettle)
                    }
                }

                Section("playTools.content.section") {
                    Button("playTools.cast", action: onOpenCast)
                    if evidenceCount > 0 {
                        Button {
                            onOpenEvidenceCards()
                        } label: {
                            LabeledContent("playTools.evidence", value: "\(evidenceCount) 张")
                        }
                    }
                    Button("playTools.rewards", action: onOpenRewards)
                    Button("playTools.entryCode", action: onOpenEntryCode)
                }

                if !thoughts.isEmpty {
                    Section("playTools.thoughts.section") {
                        ForEach(thoughts) { item in
                            LabeledContent(item.name, value: item.statusText)
                                .cyText(.bodyCompact)
                        }
                    }
                }

                Section("playTools.stats.section") {
                    LabeledContent("playTools.stats.chapters", value: "\(chapterCount)")
                        .cyText(.numericBody, monospacedDigit: true)
                    LabeledContent("playTools.stats.completed", value: "\(completedCount)")
                        .cyText(.numericBody, monospacedDigit: true)
                    LabeledContent("playTools.stats.remainingGames", value: "\(remainingGamesCount)")
                        .cyText(.numericBody, monospacedDigit: true)
                }

                Section("playTools.preferences.section") {
                    Toggle("playTools.pref.bgm", isOn: $bgmEnabled)
                    Toggle("playTools.pref.narration", isOn: $narrationAutoplay)
                    Toggle("playTools.pref.reduceMotion", isOn: $reduceMotionOverride)
                }
            }
            .listStyle(.insetGrouped)
        }
        .presentationDetents([.medium, .large])
    }
}
