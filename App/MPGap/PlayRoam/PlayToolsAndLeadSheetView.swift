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
    /// PLAY-r11-2: 证据卡 (station name + passText of finished stations); empty hides the row.
    public var evidenceCards: [PlayEvidenceCard] = []
    /// mp-journey r3: MP 游玩工具 city rows 自动记录足迹 / 到点提醒 follow the location permission (`gpsOk`).
    /// nil hides both rows; tapping an off row asks for location (MP `onLocationRowTap`).
    public var locationOn: Bool? = nil
    public var onLocationRow: () -> Void = {}
    /// mp-journey r3: MP 游玩工具 队伍位置 (`lead.exists`, value arrived/total). Nil or not started hides the row.
    public var teamLead: PlayLeadProgress? = nil
    /// mp-journey r3: MP 游玩工具 旅程手记 (`buildJournal`). Nil hides the row.
    public var journalRows: [PlayJournalRow]? = nil
    /// mp-journey r3: MP mode-2 我的权益 (`merchantCount` 家 · 已核销 `merchantDoneCount` 家). Nil hides the row.
    public var rights: PlayToolsRights? = nil
    public var onRights: () -> Void = {}
    /// mp-journey r3: MP mode 2 lists only 自动记录足迹, after 旅程手记, with its own copy. Non-nil switches to that row
    /// (true = perk-only topic: 走过的路会记下来). Needs `locationOn`.
    public var freeTrackPerkOnly: Bool? = nil
    /// mp-journey r3: MP 同行者榜 row (mode != 2), pushed; nil hides the row.
    public var boardDestination: (() -> AnyView)? = nil
    /// mp-journey r3: MP 游玩工具 本局用时 · 当前得分 (`sessStats`, mode 1 with an orient `routeState.sessionId`; both open
    /// 本局成绩), pushed right before 同行者榜. Nil hides the row.
    public var scoreDestination: (() -> AnyView)? = nil
    /// mp-journey r3: MP 游玩工具 入场码 (`wx:if="{{regId && !isPreview && !isMock}}"`, `openTicketFromTools` →
    /// `scene-qr-ticket`). The run's ticket registration id; nil or 0 hides the row.
    public var entryCodeRegistrationID: Int? = nil

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
        showsContentRows: Bool = true,
        evidenceCards: [PlayEvidenceCard] = [],
        locationOn: Bool? = nil,
        onLocationRow: @escaping () -> Void = {},
        teamLead: PlayLeadProgress? = nil,
        journalRows: [PlayJournalRow]? = nil,
        boardDestination: (() -> AnyView)? = nil,
        scoreDestination: (() -> AnyView)? = nil,
        rights: PlayToolsRights? = nil,
        onRights: @escaping () -> Void = {},
        freeTrackPerkOnly: Bool? = nil,
        entryCodeRegistrationID: Int? = nil
    ) {
        self.entryCodeRegistrationID = entryCodeRegistrationID
        self.freeTrackPerkOnly = freeTrackPerkOnly
        self.rights = rights
        self.onRights = onRights
        self.teamLead = teamLead
        self.journalRows = journalRows
        self.boardDestination = boardDestination
        self.scoreDestination = scoreDestination
        self.locationOn = locationOn
        self.onLocationRow = onLocationRow
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
        self.evidenceCards = evidenceCards
    }

    private var entryRegistration: Int? {
        guard let id = entryCodeRegistrationID, id > 0 else { return nil }
        return id
    }

    public var body: some View {
        NavigationStack {
            Form {
                leadSection
                contentSection
                evidenceSection
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
                if scoreDestination != nil || boardDestination != nil {
                    Section {
                        if let scoreDestination {
                            NavigationLink {
                                scoreDestination()
                            } label: {
                                Label("playTools.sessionScore", systemImage: "clock")
                            }
                            .accessibilityIdentifier("playTools.sessionScore")
                        }
                        if let boardDestination {
                            NavigationLink {
                                boardDestination()
                            } label: {
                                Label("playx.leaderboard", systemImage: "person.3")
                            }
                            .accessibilityIdentifier("playTools.board")
                        }
                    }
                }
                teamPositionSection
                if let locationOn, freeTrackPerkOnly == nil {
                    // mp-journey r3 (MP pages/play/index.wxml 游玩工具, city orientation): 自动记录足迹, 到点提醒.
                    // Both follow the location permission; an off row reads dimmed and asks for location on tap.
                    Section {
                        locationRow("playTools.loc.track", on: locationOn,
                                    detail: locationOn ? "playTools.loc.track.on" : "playTools.loc.track.off",
                                    symbol: "point.topleft.down.to.point.bottomright.curvepath", identifier: "playTools.loc.track")
                        locationRow("playTools.loc.remind", on: locationOn,
                                    detail: locationOn ? "playTools.loc.remind.on" : "playTools.loc.remind.off",
                                    symbol: "bell", identifier: "playTools.loc.remind")
                    }
                }
                // mp-journey r3: MP 游玩工具 lists 入场码 then 旅程手记 after 本局读数 / 扫码到达 / 切换章节 / 队伍位置,
                // just above the preferences.
                if showsContentRows || journalRows != nil || rights != nil || entryRegistration != nil {
                    Section {
                        if let rights {
                            Button(action: onRights) {
                                LabeledContent {
                                    Text("playTools.rights.value \(rights.total) \(rights.redeemed)").monospacedDigit()
                                } label: {
                                    Label("playTools.rights", systemImage: "gift")
                                }
                            }
                            .accessibilityIdentifier("playTools.rights")
                        }
                        if let entryRegistration {
                            NavigationLink {
                                PlayEntryCodeDestination(registrationID: entryRegistration)
                            } label: {
                                Label("playTools.entryCode", systemImage: "ticket")
                            }
                            .accessibilityIdentifier("playTools.entryCode")
                        } else if showsContentRows {
                            Button("playTools.entryCode", action: onOpenEntryCode)
                                .accessibilityIdentifier("playTools.entryCode")
                        }
                        if let journalRows {
                            NavigationLink {
                                PlayJournalListView(rows: journalRows)
                            } label: {
                                Label("playTools.journal", systemImage: "book.pages")
                            }
                            .accessibilityIdentifier("playTools.journal")
                        }
                    }
                }
                if let locationOn, let perkOnly = freeTrackPerkOnly {
                    Section {
                        locationRow("playTools.loc.track", on: locationOn,
                                    detail: locationOn ? (perkOnly ? "playTools.loc.free.on.perk" : "playTools.loc.free.on") : "playTools.loc.free.off",
                                    symbol: "point.topleft.down.to.point.bottomright.curvepath", identifier: "playTools.loc.track")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done", action: onClose)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("playTools.sheet")
    }

    private func locationRow(_ title: LocalizedStringKey, on: Bool, detail: LocalizedStringKey, symbol: String,
                             identifier: String) -> some View {
        Button { if !on { onLocationRow() } } label: {
            LabeledContent {
                Text(on ? "playTools.loc.state.on" : "playTools.loc.state.off")
            } label: {
                Label { Text(title); Text(detail) } icon: { Image(systemName: symbol) }
            }
        }
        .foregroundStyle(on ? Color.primary : Color.secondary)
        .accessibilityIdentifier(identifier)
    }

    /// MP 队伍位置: the arrived count on the right; the pushed page lists who has arrived (positions stay private).
    @ViewBuilder private var teamPositionSection: some View {
        if let teamLead, teamLead.exists {
            Section {
                NavigationLink {
                    List {
                        if let broadcast = teamLead.broadcast, !broadcast.isEmpty {
                            Section("playTools.team.broadcast") { Text(verbatim: broadcast) }
                        }
                        Section {
                            ForEach(teamLead.members) { member in
                                Label {
                                    if let name = member.name, !name.isEmpty { Text(verbatim: name) } else { Text("playx.player.unnamed") }
                                } icon: {
                                    Image(systemName: member.arrived ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(member.arrived ? Color.green : Color.secondary)
                                }
                                .accessibilityValue(Text(LocalizedStringKey(member.arrived ? "playTools.team.arrived" : "playTools.team.notArrived")))
                            }
                        }
                    }
                    .navigationTitle(Text("playTools.team"))
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    LabeledContent("playTools.team") {
                        Text(verbatim: "\(teamLead.arrived ?? 0)/\(teamLead.members.count)").monospacedDigit().accessibilityLabel(Text("a11y.value.ofTotal \(Int(teamLead.arrived ?? 0)) \(Int(teamLead.members.count))"))
                    }
                }
                .accessibilityIdentifier("playTools.team")
            }
        }
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

    /// PLAY-r11-2: MP play-help.wxml:58-66 证据卡 sheet, as a pushed system list.
    @ViewBuilder private var evidenceSection: some View {
        if !evidenceCards.isEmpty {
            Section {
                NavigationLink {
                    List(evidenceCards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            if let title = card.title { Text(verbatim: title).font(.headline) }
                            Text(verbatim: card.text).textSelection(.enabled)
                        }
                        .accessibilityIdentifier("playTools.evidence.\(card.id)")
                    }
                    .navigationTitle(Text("playTools.evidence"))
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    LabeledContent("playTools.evidence") { Text(verbatim: "\(evidenceCards.count)").monospacedDigit() }
                }
                .accessibilityIdentifier("playTools.evidence.list")
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
            }
        }
    }
}

/// mp-journey r3: MP 旅程手记 sheet — one row per station: key (第 N 站 / 此刻 / 前路未知), title, first line.
/// Rows ahead of the next station stay closed and show a placeholder instead of their text (no spoilers).
struct PlayJournalListView: View {
    let rows: [PlayJournalRow]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            if rows.isEmpty {
                ContentUnavailableView("playTools.journal.empty", systemImage: "book.pages")
            }
            ForEach(rows) { row in
                if let head = row.chapterHead, !head.isEmpty {
                    Text(verbatim: head).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }
                if row.opensStory {
                    NavigationLink {
                        PlayJournalStoryView(row: row)
                    } label: {
                        rowLabel(row)
                    }
                    .accessibilityIdentifier("playTools.journal.\(row.id)")
                } else {
                    rowLabel(row)
                        .accessibilityIdentifier("playTools.journal.\(row.id)")
                }
            }
        }
        .navigationTitle(Text("playTools.journal"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rowLabel(_ row: PlayJournalRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            keyText(row.key)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(row.key == .now ? Color.accentColor : Color.secondary)
                .frame(minWidth: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.title).font(.body)
                if row.redacted {
                    Text(verbatim: "xxxxxxxxx xxxxx xxxxxxxx xxxx").font(.subheadline)
                        .redacted(reason: .placeholder)
                        .accessibilityHidden(true)
                } else if let excerpt = row.excerpt {
                    Text(verbatim: excerpt).font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                }
            }
        }
        .foregroundStyle(row.opensStory ? Color.primary : Color.secondary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func keyText(_ key: PlayJournalRow.Key) -> some View {
        switch key {
        case .station(let number):
            Text("playTools.journal.station \(number)")
        case .step(let number):
            Text("playTools.journal.step \(number)")
        case .now:
            Text("playTools.journal.now")
        case .ahead:
            Text("playTools.journal.ahead")
        case .notYet:
            Text("playTools.journal.notYet")
        }
    }
}

/// MP `openStory`: the station's full text with its cover.
struct PlayJournalStoryView: View {
    let row: PlayJournalRow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let cover = row.coverURL, let url = URL(string: cover) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(.fill.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: CYRadius.card))
                    .accessibilityHidden(true)
                }
                Text(verbatim: row.story ?? "")
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle(Text(verbatim: row.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// mp-journey r3: the 我的权益 counts for the free-exploration 游玩工具 row.
public struct PlayToolsRights: Equatable {
    public let total: Int
    public let redeemed: Int
    public init(total: Int, redeemed: Int) {
        self.total = total
        self.redeemed = redeemed
    }
}
