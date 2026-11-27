import SwiftUI

/// Mini-program pages/roam/index top tabs: 开始漫游 | 漫游护照 (`introTabs`).
enum RoamHomeTab: String, CaseIterable, Hashable { case start, passport
    var titleKey: LocalizedStringKey { LocalizedStringKey("roam.w208.tab." + rawValue) }
}

struct RoamHomeTabPicker: View {
    @Binding var selection: RoamHomeTab
    var body: some View {
        Picker("roam.w208.tab.label", selection: $selection) {
            ForEach(RoamHomeTab.allCases, id: \.self) { tab in Text(tab.titleKey).tag(tab) }
        }
        .cyAdaptiveSegmented()
        .accessibilityIdentifier("roam.home.tabs")
    }
}

/// 开始漫游 intro cards. Each card only navigates; live start stays behind its own dormant destination.
@MainActor struct RoamHomeIntroCards: View {
    let start: () -> AnyView
    let nearby: (() -> AnyView)?
    let myTeams: (() -> AnyView)?
    var officialRoutes: (() -> AnyView)? = nil
    /// ROAM-13 (MP `introTeamsLive`): 附近 N 支队伍在组队 on the map ticket, only from a successful team read; nil/0 hides it.
    var teamsLive: Int? = nil
    private struct Spec: Identifiable {
        let id: String
        let title: LocalizedStringKey, sub: LocalizedStringKey
        let symbol: String
        /// MP `images/roam/intro-ticket-*.svg`; the official-routes ticket has no MP art and keeps its symbol.
        var art: Image? = nil
        let spine: Color
        let destination: () -> AnyView
        var live: Int? = nil
    }
    private var specs: [Spec] {
        var list = [Spec(id: "roam.home.intro.start", title: "roam.w208.intro.start", sub: "roam.w208.intro.start.sub",
                         symbol: "point.topleft.down.to.point.bottomright.curvepath", art: MPAsset.FeatureIcon.introTicketRoute, spine: .green, destination: start)]
        if let nearby { list.append(Spec(id: "roam.home.intro.map", title: "roam.w208.intro.map", sub: "roam.w208.intro.map.sub",
                                         symbol: "map", art: MPAsset.FeatureIcon.introTicketMap, spine: .blue, destination: nearby, live: teamsLive)) }
        if let myTeams { list.append(Spec(id: "roam.home.intro.teams", title: "roam.w208.intro.teams", sub: "roam.w208.intro.teams.sub",
                                          symbol: "person.3", art: MPAsset.FeatureIcon.introTicketTeam, spine: .orange, destination: myTeams)) }
        if let officialRoutes { list.append(Spec(id: "roam.home.intro.officialRoutes", title: "officialRoute.intro", sub: "officialRoute.intro.sub",
                                                 symbol: "signpost.right.and.left", spine: .teal, destination: officialRoutes)) }
        return list
    }
    /// N-ROAM-HOME (r10): the MP intro tickets (pages/roam/index.wxml:186-205) as List rows: a NavigationLink
    /// `Label` with the `MPAsset` thumbnail, title and subtitle. No drawn ticket, white card or shadow.
    var body: some View {
        ForEach(specs) { spec in row(spec) }
    }
    private func row(_ spec: Spec) -> some View {
        NavigationLink { spec.destination() } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.title)
                    Text(spec.sub).font(.footnote).foregroundStyle(.secondary)
                    if let live = spec.live, live > 0 {
                        Text("roam.w208.intro.live \(live)").font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                            .accessibilityIdentifier("roam.home.intro.live")
                    }
                }
            } icon: {
                Group {
                    if let art = spec.art { art.resizable().scaledToFit().frame(width: 36, height: 36) }
                    else { Image(systemName: spec.symbol).foregroundStyle(spec.spine) }
                }
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(spec.id)
    }
}

/// Local journal notice. Check and Continue only open their already-supplied destinations.
@MainActor struct RoamHomeRecoveryBannerView: View {
    let banner: RoamHomeRecoveryBanner
    var onContinue: (() -> Void)? = nil
    let destination: () -> AnyView
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if banner == .needsCheck {
                Label(LocalizedStringKey(banner.titleKey), systemImage: "exclamationmark.circle")
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink { destination() } label: { Text("roam.w208.recovery.check") }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("roam.home.recovery.check")
            } else if let onContinue {
                // ROAM-6 / P-27: the MP dropped the 已找回 banner; an unfinished walk shows 继续漫游 only.
                Button(action: onContinue) { Label("roam.w208.recovery.continue", systemImage: "figure.walk") }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("roam.home.recovery.continue")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(banner.accessibilityID)
    }
}

/// 附近活动 peek. Reads only through an approved, account-scoped reader at the manual roam centre.
@MainActor struct RoamEntryPeekView: View {
    let reader: any RoamEntryNearbyReading
    /// Optional team/nearby read at the same centre; nil result = that layer failed.
    var teams: ((RoamSearchArea) async -> [NearbyTeam]?)? = nil
    var onSignIn: (() -> Void)? = nil
    var onOpenMap: (() -> AnyView)? = nil
    var onChooseArea: (() -> Void)? = nil
    var onBeginRead: (() -> Void)? = nil
    var onOpenSelection: ((RoamNearbyEventsEntrySelection) -> Void)? = nil
    /// Loaded card count (nil while loading / failed / unavailable) for the collapsed sheet line.
    var onCount: ((Int?) -> Void)? = nil
    /// ROAM-13: team count of the last successful team read at this centre (nil = not read / failed).
    var onTeamsLive: ((Int?) -> Void)? = nil
    /// i18n r3: the catalog city name (MP Chinese) resolves through Localizable.xcstrings.
    @Environment(\.locale) private var locale
    /// ROAM-13 本城推荐 (MP `entryCityStrip`): nil hides the second tab.
    var cityStrip: RoamCityGuideStrip? = nil
    /// Places of the current map read; a matching seed tag gives a city card its cover.
    var cityPlaces: [RoamPlace] = []
    var onOpenCityPlace: ((RoamCityGuidePlace) -> Void)? = nil
    let onOpen: (RoamEntryActivityCard) -> Void
    @State private var model = RoamNearbyEventsEntryState()
    /// MP `entryStripTab` ('near' | 'city').
    @State private var showsCityTab = false
    @State private var retryTask: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                if let cityStrip, onOpenCityPlace != nil {
                    // native-r3-b: the MP near/city strip tabs as a system segmented picker (was two plain text buttons).
                    Picker(selection: $showsCityTab) {
                        Text("roam.w208.entry.title").tag(false)
                        cityTabLabel(cityStrip).tag(true)
                    } label: { Text("roam.w208.entry.title") }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("roam.home.peek.tabs")
                } else {
                    Text("roam.w208.entry.title").cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                }
                Spacer()
                // mp-roam r3: MP entry-peek header has only the 附近活动 / 本城推荐 tabs; the extra refresh
                // button is gone. Reloads come from the failed-state 重试 rows (MP cy-error) and .task(id:).
            }
            if showsCityTab, let cityStrip, let onOpenCityPlace {
                RoamCityGuideCards(strip: cityStrip, places: cityPlaces, onOpen: onOpenCityPlace)
            } else if (reader.isSignedIn || reader.allowsPublicEntry), reader.isConfigured, reader.searchArea == nil {
                // Containers like the sibling peek states (73a06a74f): iOS 27 drops a plain stack's identifier.
                RoamStatusView(issue: .areaRequired)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("roam.home.peek.areaRequired")
                if let onChooseArea { Button("roam.area.title", action: onChooseArea) }
            } else { content }
            if !showsCityTab, model.visibleTeamState(reader: reader) == .loading {
                ProgressView { Text("roam.nearbyEvents.teamsLoading", tableName: "RoamNearbyEvents") }
                    .accessibilityIdentifier("roam.home.peek.teamsLoading")
            } else if !showsCityTab, model.visibleTeamState(reader: reader) == .failed {
                VStack(alignment: .leading, spacing: 6) {
                    Label { Text("roam.nearbyEvents.teamsFailed", tableName: "RoamNearbyEvents") } icon: { Image(systemName: "exclamationmark.triangle") }
                        .cyText(.meta).foregroundStyle(.secondary)
                    Button("action.retry", action: refresh).frame(minHeight: 44)

                        .accessibilityIdentifier("roam.home.peek.teamsRetry")
                }.accessibilityElement(children: .contain).accessibilityIdentifier("roam.home.peek.teamsFailed")
            }
        }
        .task(id: reader.readKey) { await load() }
        .onChange(of: loadedCount, initial: true) { _, count in onCount?(count) }
        .onDisappear { retryTask?.cancel(); retryTask = nil; model.cancel() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roam.home.peek")
    }
    /// MP `entryCityLabel`: `<城市> · N 处推荐` when the map faces a catalog city, else 本城推荐.
    private func cityTabLabel(_ strip: RoamCityGuideStrip) -> Text {
        strip.inCity ? Text("roam.cityGuide.tab.inCity \(appLocalized(String.LocalizationValue(strip.city.name), locale: locale)) \(strip.items.count)") : Text("roam.cityGuide.tab.default")
    }
    private var loadedCount: Int? {
        if case .loaded(let cards) = model.visibleState(reader: reader) { return cards.count }
        return nil
    }
    @ViewBuilder private var content: some View {
        switch model.visibleState(reader: reader) {
        case .unavailable:
            Label("roam.w208.entry.unavailable", systemImage: "lock.shield").cyText(.body).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("roam.home.peek.unavailable")
        case .login:
            VStack(alignment: .leading, spacing: 6) {
                Label("roam.w208.entry.login", systemImage: "person.crop.circle.badge.questionmark")
                if let onSignIn { Button("roam.w208.entry.signIn", action: onSignIn).frame(minHeight: 44).accessibilityIdentifier("roam.home.peek.signIn") }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("roam.home.peek.login")
        case .denied:
            Label("roam.w208.entry.denied", systemImage: "hand.raised").accessibilityIdentifier("roam.home.peek.denied")
        case .loading:
            // MP aria 正在读取附近活动.
            ProgressView { Text("roam.w208.entry.loading") }.accessibilityIdentifier("roam.home.peek.loading")
        case .failed:
            VStack(alignment: .leading, spacing: 6) {
                Label("roam.w208.entry.failed", systemImage: "exclamationmark.triangle")
                Button("action.retry", action: refresh).frame(minHeight: 44).accessibilityIdentifier("roam.home.peek.retry")
            }.accessibilityElement(children: .contain).accessibilityIdentifier("roam.home.peek.failed")
        case .empty:
            VStack(alignment: .leading, spacing: 4) {
                Text("roam.w208.entry.empty").cyText(.body)
                if let onOpenMap {
                    NavigationLink { onOpenMap() } label: { Text("roam.w208.entry.emptyHint").cyText(.meta) }
                        .accessibilityIdentifier("roam.home.peek.openMap")
                } else { Text("roam.w208.entry.emptyHint").cyText(.meta).foregroundStyle(.secondary) }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("roam.home.peek.empty")
        case .loaded(let cards):
            let rendered = model.loadedScope
            let readID = model.readID
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cards) { card in
                        Button {
                            guard let selection = model.selection(card: card, rendered: rendered, readID: readID, reader: reader) else { return }
                            if let onOpenSelection { onOpenSelection(selection) } else { onOpen(card) }
                        } label: { RoamEntryCardView(card: card) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("roam.w208.entry.open \(card.activity.title)"))
                            .accessibilityIdentifier("roam.home.peek.card.\(card.id)")
                    }
                }.padding(.vertical, 4)
            }
        }
    }
    private func refresh() {
        retryTask?.cancel(); model.cancel(); onBeginRead?()
        retryTask = Task { await load() }
    }
    private func load() async {
        guard !Task.isCancelled else { return }
        onBeginRead?(); onTeamsLive?(nil)
        var readCount: Int?
        var counted: ((RoamSearchArea) async -> [NearbyTeam]?)? = nil
        if let teams { counted = { area in let rows = await teams(area); readCount = rows?.count; return rows } }
        await model.load(reader: reader, teams: counted)
        guard !Task.isCancelled else { return }
        onTeamsLive?(model.visibleTeamState(reader: reader) == .loaded ? readCount : nil)
    }
}

struct RoamEntryCardView: View {
    @Environment(\.locale) private var locale
    let card: RoamEntryActivityCard
    var body: some View {
        // N-r11-4: a plain Label row with the MP placeholder art (`.entry-card__cover` fallback) instead of the shelf card.
        Label {
            VStack(alignment: .leading, spacing: 2) {
                title.font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                (Text(LocalizedStringKey(card.tagKey)) + Text(verbatim: " · ") + RoamEntryMetaLine(card: card, locale: locale).text)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        } icon: {
            MPAsset.BannerCover.homeRouteCityPlaceholder.resizable().scaledToFill()
                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var title: Text {
        card.activity.title.isEmpty ? Text("roam.w208.entry.untitled") : Text(verbatim: card.activity.title)
    }
}

/// `activityView.meta`: 已结束 · 距你 X km · N 支队伍招募, falling back to the address, then 查看活动详情.
struct RoamEntryMetaLine: View {
    let card: RoamEntryActivityCard
    /// i18n r2: set when `text` is read outside a view body (the environment is not installed there).
    var locale: Locale? = nil
    @Environment(\.locale) private var environmentLocale
    var body: some View { text }
    var text: Text {
        let parts = metaParts
        if parts.isEmpty {
            if let address = card.activity.addressName { return Text(verbatim: address) } else { return Text("roam.w208.entry.viewActivity") }
        } else {
            return parts.dropFirst().reduce(parts[0]) { $0 + Text(verbatim: " · ") + $1 }
        }
    }
    private var metaParts: [Text] {
        var parts: [Text] = []
        if card.ended { parts.append(Text("roam.w208.entry.ended")) }
        if let km = card.distanceKilometers {
            // i18n r2: the unit travels with the number (`距你 1.2 km` zh unchanged, `0.7 mi away` en-US).
            let zhText = km.formatted(.number.precision(.fractionLength(1))) + " km"
            parts.append(Text("roam.w208.entry.away \(LocaleDisplay.distanceArgument(meters: km * 1000, zhText: zhText, locale: locale ?? environmentLocale))"))
        }
        if !card.ended && card.recruitingCount > 0 { parts.append(Text("roam.w208.entry.recruiting \(card.recruitingCount)")) }
        return parts
    }
}

/// Only an absolute https cover is loaded; anything else shows the MP default
/// (`entryActivity.cover || /images/route_city_cover.png`, aspect fill).
struct RoamEntryCover: View {
    let source: String?
    /// MP default for this slot; nearby cards use `/images/home-route-city-placeholder.jpg`.
    var fallbackArt: Image = MPAsset.BannerCover.routeCityCover
    var body: some View {
        ZStack {
            Rectangle().fill(.secondary.opacity(0.12))
            if let source, let url = URL(string: source), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { fallback }
                }
            } else { fallback }
        }
        .clipped()
        .accessibilityHidden(true)
    }
    private var fallback: some View {
        fallbackArt.resizable().scaledToFill()
    }
}

/// Entry activity sheet: navigation only. 去报名 / 查看详情 / 发起组队 open the existing activity or topic
/// detail; a recruiting team opens the nearby team page focused on that team, where any apply is reviewed.
@MainActor struct RoamEntryActivitySheet: View {
    let card: RoamEntryActivityCard
    var eventDestination: ((RoamEventDestination) -> AnyView)? = nil
    var teamDestination: ((NearbyTeamID) -> AnyView)? = nil
    var readOnly = false
    var isCurrent: () -> Bool = { true }
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if !isCurrent() {
                    CYEmptyState(systemImage: "arrow.clockwise", "roamEvent.changed")
                        .accessibilityIdentifier("roam.home.sheet.stale")
                } else {
                    List {
                        Section {
                            RoamEntryCover(source: card.activity.coverURL).frame(height: 160).listRowInsets(EdgeInsets())
                            Text(LocalizedStringKey(card.tagKey)).cyText(.meta, weight: .bold).foregroundStyle(.tint)
                            RoamEntryMetaLine(card: card).cyText(.body).foregroundStyle(.secondary)
                            if readOnly { detailLink("roam.w208.entry.viewDetail", identifier: "roam.home.sheet.primary") }
                            else if let key = card.primaryKey { detailLink(LocalizedStringKey(key), identifier: "roam.home.sheet.primary") }
                            if card.participantCount > 0 {
                                Text("roam.w208.entry.participants \(card.participantCount)").accessibilityIdentifier("roam.home.sheet.participants")
                            }
                        }
                        if !readOnly && !card.teams.isEmpty {
                            Section {
                                ForEach(card.teams) { team in teamRow(team) }
                            } header: { Text("roam.w208.entry.teams \(card.teams.count)") }
                        }
                        if !readOnly && card.registered && !card.ended, card.destination != nil, eventDestination != nil {
                            Section { detailLink("roam.w208.entry.createTeam", identifier: "roam.home.sheet.createTeam") }
                        }
                        if readOnly { Section { Text("roam.readOnlyNotice").cyText(.bodyCompact).foregroundStyle(.secondary) } }
                    }
                }
            }
            // ROAM-11 (native restyle): system inline title + one ✕ close item.
            .navigationTitle(Text(verbatim: card.activity.title)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("action.close", systemImage: "xmark") }
                        .labelStyle(.iconOnly).accessibilityIdentifier("roam.home.sheet.close")
                }
            }
        }
        .cySheet()
        .accessibilityIdentifier("roam.home.sheet")
    }
    @ViewBuilder private func detailLink(_ title: LocalizedStringKey, identifier: String) -> some View {
        if let destination = card.destination, let eventDestination {
            NavigationLink {
                if isCurrent() { eventDestination(destination) }
                else { CYEmptyState(systemImage: "arrow.clockwise", "roamEvent.changed") }
            } label: { Text(title).bold() }.disabled(!isCurrent()).accessibilityIdentifier(identifier)
        } else {
            Text(title).foregroundStyle(.secondary).accessibilityIdentifier(identifier)
        }
    }
    @ViewBuilder private func teamRow(_ team: RoamEntryActivityCard.Team) -> some View {
        let label = VStack(alignment: .leading, spacing: 4) {
            if team.title.isEmpty { Text("roam.w208.entry.teamUntitled").cyText(.cardTitle) } else { Text(verbatim: team.title).cyText(.cardTitle) }
            Text("roam.w208.entry.teamMembers \(team.joinedCount) \(team.maxMembers)").cyText(.meta).foregroundStyle(.secondary)
            // Source: 申请加入 once the viewer holds this activity's ticket, otherwise 报名后申请.
            Text(LocalizedStringKey(card.registered ? "roam.w208.entry.apply" : "roam.w208.entry.applyAfterRegister"))
                .cyText(.meta, weight: .bold).foregroundStyle(card.registered ? Color.accentColor : Color.secondary)
        }
        if team.canApply, let teamDestination {
            NavigationLink { teamDestination(team.teamID) } label: { label }.accessibilityIdentifier("roam.home.sheet.team.\(team.teamID.rawValue)")
        } else if let destination = card.destination, let eventDestination {
            NavigationLink { eventDestination(destination) } label: { label }.accessibilityIdentifier("roam.home.sheet.team.\(team.teamID.rawValue)")
        } else {
            label.accessibilityElement(children: .combine).accessibilityIdentifier("roam.home.sheet.team.\(team.teamID.rawValue)")
        }
    }
}

/// Tools that exist in the mini-program but have no reviewed iOS read/write contract yet.
struct RoamToolUnavailableView: View {
    let titleKey: String
    var body: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey(titleKey), systemImage: "hourglass")
        } description: {
            Text("roam.w208.tool.unavailable")
        }
        .appNavigationTitle(key: titleKey)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("roam.home.tool.unavailable")
        .cyDomainScreen(.player)
    }
}

/// 漫游护照 tab: four readings (server summary when the owner read exists, else this device's saved records), tiles and two play cards.
@MainActor struct RoamHomePassportView: View {
    let reader: (any RoamExperienceReading)?
    var albumMetadataReader: RoamAlbumMetadataReader? = nil
    var stampDestination: (() -> AnyView)? = nil
    var liveDestination: (() -> AnyView)? = nil
    var toolsReader: (any RoamPassportToolsReading)? = nil
    var discoverDestination: (() -> AnyView)? = nil
    /// MP `_loadOfficialRoutes`: the 官方路线 passport card after 官方活动, only when ≥ 1 route is listed.
    var officialRouteReader: OfficialRouteReader? = nil
    @State private var officialRoutes: [OfficialRoute] = []
    /// Host's existing topic detail for an anniversary card's current route; nil = honestly unavailable.
    var anniversaryRouteDestination: ((String) -> AnyView)? = nil
    /// 探索目标 / 时光胶囊 / 导出 owner-only tools; nil keeps the tiles on their fallback page.
    var privateToolsReader: (any RoamPrivateToolsServing)? = nil
    /// B62 收集册 藏品 segment. Binding stub: nil hides the chip until the host passes its object-cards screen.
    var collectionObjectDestination: (() -> AnyView)? = nil
    @State private var homeScope: RoamPassportReaderScope?
    @State private var home: Result<RoamPassportHome, Error>?
    @State private var openedTile: OpenedTile?
    @State private var isPassportVisible = false
    /// ROAM-1: pages/roam reads `GET /api/roam/passport/summary`; local history is only the fallback when no owner read exists.
    @Environment(\.roamPassportHistoryReader) private var serverReader
    @State private var serverSummary: Result<RoamPassportServerSummary, Error>?
    @State private var serverScope: UUID?
    /// ROAM-5: pages/roam `_loadActiveOfficial` — GET /api/official/active-for-roam decides where 官方活动 goes.
    @Environment(\.playerGapService) private var gapService
    @State private var activeOfficial: OfficialRoamActiveCard?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// MP `_ppExpand` (pages/roam/index.js): a passport tile grows into the page it opens.
    /// Reduce Motion and iOS 17 keep the plain push (`cyHeroSource` / `cyHeroDestination`).
    @Namespace private var passportTileHero
    private struct OpenedTile: Identifiable, Hashable {
        let id = UUID()
        let tile: RoamPassportHome.Tile
    }
    private var readerScope: RoamPassportReaderScope? { reader.map { RoamPassportReaderScope($0) } }
    private var currentHome: Result<RoamPassportHome, Error>? { homeScope == readerScope ? home : nil }
    var body: some View {
        List {
            Section {
                if let reader { stats(reader: reader) } else {
                    Text("roam.notConfigured").foregroundStyle(.secondary).accessibilityIdentifier("roam.home.passport.unavailable")
                }
            }
            Section {
                ForEach(RoamPassportHome.Tile.allCases.filter(tileAvailable)) { tile in tileLink(tile) }
            }
            Section {
                ForEach(RoamPassportHome.Play.allCases) { play in
                    playCard(play)
                    if play == .event { officialRoutesCard }
                }
            }
            .task(id: officialRouteReader == nil) { await loadOfficialRoutes() }
            RoamPassportToolsSection(reader: toolsReader, routeDestination: anniversaryRouteDestination, privateTools: privateToolsReader)
        }
        .roamPassportToolsDestinations(reader: toolsReader, routeDestination: anniversaryRouteDestination, privateTools: privateToolsReader)
        .onAppear { isPassportVisible = true; openedTile = nil; load() }
        .onDisappear { isPassportVisible = false }
        .refreshable { load(); await loadServerSummary() }
        .task(id: serverReader?.scope) { await loadServerSummary() }
        .task { activeOfficial = await gapService?.activeOfficialForRoam() }
        .onChange(of: readerScope) { _, _ in
            openedTile = nil
            home = nil; homeScope = nil
            load()
        }
        .navigationDestination(item: $openedTile) { item in
            tileDestination(item.tile).cyHeroDestination(item.tile, in: passportTileHero)
        }
        .background { RoamHostedAccessibilityGroup(items: passportAccessibilityItems) }
        // A screen-level identifier is only exposed when the screen is an accessibility container (iOS 27 SwiftUI drops
        // it otherwise); `.contain` keeps every child element as it was.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roam.home.passport")
        .cyDomainScreen(.player)
    }
    private var passportAccessibilityItems: [RoamHostedAccessibilityItem] {
        guard isPassportVisible, openedTile == nil else { return [] }
        var items: [RoamHostedAccessibilityItem] = []
        if reader != nil {
            switch currentHome {
            case .none:
                break
            case .failure(let error)?:
                items.append(RoamHostedAccessibilityItem(identifier: "roam.experience.error"))
                if error as? APIError != .unauthorized, error as? APIError != .notConfigured {
                    items.append(RoamHostedAccessibilityItem(identifier: "roam.experience.retry", action: load))
                }
            case .success(let value)?:
                items.append(
                    RoamHostedAccessibilityItem(
                        identifier: "roam.home.passport.stat.trips",
                        label: String(value.summary.trips)
                    )
                )
            }
        } else {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.home.passport.unavailable"))
        }
        for tile in RoamPassportHome.Tile.allCases where tileAvailable(tile) {
            items.append(
                RoamHostedAccessibilityItem(
                    identifier: "roam.home.passport.tile.\(tile.rawValue)",
                    action: { openedTile = OpenedTile(tile: tile) }
                )
            )
        }
        return items
    }
    private func load() {
        guard let reader else { home = nil; homeScope = nil; return }
        let captured = RoamPassportReaderScope(reader)
        let result = Result { try RoamPassportHome(records: try reader.history()) }
        guard captured == readerScope else { return }
        homeScope = captured; home = result
    }
    /// pages/roam/index 护照读数: RoamHomeIndexPassportPresentation owns the four texts. Loading keeps
    /// the same row geometry with an em dash per reading (mini-program R-02); unknown stays `—`, a known 0 stays 0.
    private var configuredServerReader: (any RoamPassportHistoryReading)? {
        guard let serverReader, serverReader.isConfigured else { return nil }
        return serverReader
    }
    private func loadServerSummary() async {
        guard let reader = configuredServerReader else { serverSummary = nil; serverScope = nil; return }
        let scope = reader.scope
        if serverScope != scope { serverSummary = nil }
        let result: Result<RoamPassportServerSummary, Error>
        do { result = .success(try await reader.summary()) } catch is CancellationError { return } catch { result = .failure(error) }
        guard reader.scope == scope else { return }
        serverScope = scope; serverSummary = result
    }
    private var passportPresentation: RoamHomeIndexPassportPresentation {
        if let reader = configuredServerReader {
            guard serverScope == reader.scope, let serverSummary else { return RoamHomeIndexPassportPresentation(phase: .unloaded) }
            switch serverSummary {
            case .success(let summary): return RoamHomeIndexPassportPresentation(server: summary)
            case .failure(let error): return RoamHomeIndexPassportPresentation(phase: .failed(error))
            }
        }
        switch currentHome {
        case .none: return RoamHomeIndexPassportPresentation(phase: .unloaded)
        case .failure(let error)?: return RoamHomeIndexPassportPresentation(phase: .failed(error))
        case .success(let value)?: return RoamHomeIndexPassportPresentation(phase: .loaded(value.summary))
        }
    }
    @ViewBuilder private func stats(reader: any RoamExperienceReading) -> some View {
        let presentation = passportPresentation
        if presentation.read == .error, configuredServerReader != nil, case .failure(let error)? = serverSummary {
            // MP wxml:219 漫游护照读取失败 + 重试.
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("roam.w208.passport.failed").cyText(.bodyMedium)
                RoamExperienceIssue(error: error) { Task { await loadServerSummary() } }
            }
            .accessibilityIdentifier("roam.home.passport.failed")
        } else if presentation.read == .error, case .failure(let error)? = currentHome {
            RoamExperienceIssue(error: error, retry: load)
        } else {
            HStack(spacing: 8) {
                stat("roam.w208.passport.stat.trips", presentation.tripsText, identifier: "trips")
                stat("roam.w208.passport.stat.shops", presentation.shopsText, identifier: "shops")
                stat("roam.w208.passport.stat.days", presentation.daysText, identifier: "days")
                stat("roam.w208.passport.stat.km", presentation.kilometersText, identifier: "km")
            }
            .padding(.vertical, 6)
            .animation(reduceMotion ? nil : .snappy, value: presentation.read)
        }
    }
    private func stat(_ key: LocalizedStringKey, _ value: String, identifier: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value).cyText(.sectionTitle).monospacedDigit()
                .contentTransition(.numericText())
            Text(key).cyText(.meta).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roam.home.passport.stat.\(identifier)")
    }
    private func tileLink(_ tile: RoamPassportHome.Tile) -> some View {
        NavigationLink {
            tileDestination(tile).cyHeroDestination(tile, in: passportTileHero)
        } label: {
            HStack(spacing: 12) {
                tileArt(tile).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(LocalizedStringKey(tile.titleKey)).cyText(.cardTitle)
                        // N-ROAM-HOME (r10): plain tinted caption instead of a drawn capsule badge.
                        if tile.isNew { Text("roam.private.new").font(.caption.bold()).foregroundStyle(.tint) }
                    }
                    caption(tile).cyText(.meta).foregroundStyle(.secondary)
                }
            }
            .cyHeroSource(tile, in: passportTileHero)
        }
        .accessibilityIdentifier("roam.home.passport.tile.\(tile.rawValue)")
    }
    /// MP `cy-roam-photo` 3D icons for 历史 / 印章 / 目标 (`subpackageRoam/assets/icons`); other tiles keep a symbol (MP cy-icon).
    @ViewBuilder private func tileArt(_ tile: RoamPassportHome.Tile) -> some View {
        switch tile {
        // ROAM-8b (MP pages/roam/index.wxml:186-205): newest track / stamp photo when the passport read has one.
        case .history:
            RoamPassportTileThumbnail(source: passportThumbnail(tile)) { MPAsset.FeatureIcon.history.resizable().scaledToFit() }
        case .stamp:
            RoamPassportTileThumbnail(source: passportThumbnail(tile)) { MPAsset.FeatureIcon.stamp.resizable().scaledToFit() }
        case .goals: MPAsset.FeatureIcon.goals.resizable().scaledToFit().frame(width: 36, height: 36)
        default: Image(systemName: tile.symbol).accessibilityHidden(true).foregroundStyle(.tint).frame(width: 36)
        }
    }
    private func passportThumbnail(_ tile: RoamPassportHome.Tile) -> String {
        guard case .success(let value)? = currentHome else { return "" }
        return tile == .history ? value.latestTrackThumbnail : value.latestStampImage
    }
    /// A tile is listed only when it opens something; goals and capsule need the owner-only tools reader
    /// (capability absent => hidden, per the pages/roam/index page-ready note).
    private func tileAvailable(_ tile: RoamPassportHome.Tile) -> Bool {
        switch tile {
        case .history, .badge: return reader != nil
        case .stamp: return reader != nil || albumMetadataReader != nil
        case .goals, .capsule: return privateToolsReader != nil
        }
    }
    private func caption(_ tile: RoamPassportHome.Tile) -> Text {
        if let key = tile.subtitleKey { return Text(LocalizedStringKey(key)) }
        guard case .success(let value)? = currentHome, let count = value.count(tile) else { return Text(verbatim: "—") }
        return tile == .history ? Text("roam.w208.passport.tile.history.count \(count)") : Text("roam.w208.passport.tile.stamp.count \(count)")
    }
    @ViewBuilder private func tileDestination(_ tile: RoamPassportHome.Tile) -> some View {
        switch tile {
        case .history:
            if let reader { RoamHistoryView(reader: reader, liveDestination: liveDestination, toolsReader: toolsReader, privateToolsReader: privateToolsReader, anniversaryRouteDestination: anniversaryRouteDestination) }
        case .stamp, .badge:
            // B62: 邮票 and 勋章 open the same 收集册, on the tapped segment.
            CollectionAlbumView(initial: tile == .stamp ? .stamp : .medal,
                medal: reader.map { reader in { AnyView(RoamBadgeWallDestination(roamReader: reader)) } },
                stamp: albumStampDestination,
                object: collectionObjectDestination)
        case .goals:
            if let privateToolsReader { RoamExplorationGoalsView(tools: privateToolsReader) }
            else { RoamToolUnavailableView(titleKey: tile.titleKey) }
        case .capsule:
            if let privateToolsReader { RoamCapsuleView(tools: privateToolsReader) }
            else { RoamToolUnavailableView(titleKey: tile.titleKey) }
        }
    }
    private var albumStampDestination: (() -> AnyView)? {
        if let albumMetadataReader { return { AnyView(RoamAlbumMetadataDestination(reader: albumMetadataReader, stampDestination: stampDestination).id(albumMetadataReader.scope)) } }
        if let reader { return { AnyView(RoamStampAlbumView(reader: reader, stampDestination: stampDestination)) } }
        return nil
    }
    /// MP passport play `routes`: 官方路线 · N 条路线, art = the first route's previewImg, else the MP goals icon.
    @ViewBuilder private var officialRoutesCard: some View {
        if let officialRouteReader, let first = officialRoutes.first {
            NavigationLink { OfficialRouteListView(reader: officialRouteReader) } label: {
                HStack(spacing: 12) {
                    Color.clear.frame(width: 44, height: 44)
                        .overlay { E1CoverArt(seed: first.name, symbol: "map", imageURL: first.previewImage, debugLabel: false,
                                              fallbackImage: MPAsset.FeatureIcon.goals, fallbackFills: false) }
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("officialRoute.intro").cyText(.cardTitle)
                        Text("roam.passport.play.routes.count \(officialRoutes.count)").cyText(.meta).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityIdentifier("roam.home.passport.play.routes")
        }
    }
    /// Server-only, as in the MP: a failed or empty read shows no card.
    private func loadOfficialRoutes() async {
        guard let officialRouteReader else { officialRoutes = []; return }
        do { officialRoutes = try await officialRouteReader.list() } catch { if !(error is CancellationError) { officialRoutes = [] } }
    }
    /// 官方活动 opens the official roam tasks;
    /// 发现附近店铺 opens the nearby map. A card without a destination is not listed.
    @ViewBuilder private func playCard(_ play: RoamPassportHome.Play) -> some View {
        let label = HStack(spacing: 12) {
            Group {
                // MP 官方活动 card photo (`subpackageRoam/assets/photos/event`); 发现附近店铺 keeps the cy-icon stand-in.
                if play == .event {
                    MPAsset.BannerCover.event.resizable().scaledToFill().frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                } else {
                    Image(systemName: "storefront").foregroundStyle(.tint).frame(width: 44)
                }
            }.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(play.titleKey)).cyText(.cardTitle)
                if play == .event, let activeOfficial {
                    Group {
                        if activeOfficial.count > 1 { Text("playerGap.roamEvents.many \(activeOfficial.firstTitle) \(activeOfficial.count)") }
                        else { Text("playerGap.roamEvents.one \(activeOfficial.firstTitle)") }
                    }
                    .cyText(.meta).foregroundStyle(.secondary).lineLimit(2)
                } else {
                    Text(LocalizedStringKey(play.subtitleKey)).cyText(.meta).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        switch play {
        case .event:
            if let reader {
                // One open event → its detail; several or none → the official roam tasks (MP onPassportPlayTap('event')).
                NavigationLink { RoamActiveOfficialEventDestination(roamReader: reader, eventID: activeOfficial?.count == 1 ? activeOfficial?.eventID : nil) } label: { label }
                    .accessibilityIdentifier("roam.home.passport.play.\(play.rawValue)")
            }
        case .discover:
            if let discoverDestination {
                NavigationLink { discoverDestination() } label: { label }
                    .accessibilityIdentifier("roam.home.passport.play.\(play.rawValue)")
            }
        }
    }
}

/// Volatile presentation identity only; it carries no token, result, permission or event ID.
struct RoamPassportReaderScope: Hashable {
    let readerID: ObjectIdentifier
    let identity: RoamExperienceIdentity?
    @MainActor init(_ reader: any RoamExperienceReading) {
        readerID = ObjectIdentifier(reader); identity = reader.identity
    }
}

/// Local read identity only. Remote read configuration is not permission to read one's local journal.
struct RoamHomeRecoveryOwner: Hashable {
    let readerID: ObjectIdentifier
    let scopeKey: String?
    let epoch: UInt64?
    @MainActor init(reader: any RoamExperienceReading) {
        readerID = ObjectIdentifier(reader)
        let identity = reader.identity
        scopeKey = identity?.scope.storageKey; epoch = identity?.epoch
    }
}

/// Restores the source's show-time local read and navigation-only Continue action.
/// The existing live destination remains the only owner of recovery, consent and location.
@MainActor struct RoamHomeRecoveryEntry {
    struct Target: Hashable {
        let id = UUID()
        let owner: RoamHomeRecoveryOwner
    }
    private var owner: RoamHomeRecoveryOwner?
    private var value: RoamHomeRecoveryBanner?
    private var visible = false
    private var foreground = false
    private(set) var revision = UUID()
    var target: Target?

    mutating func appear(reader: (any RoamExperienceReading)?, foreground: Bool, hasDestination: Bool) {
        visible = true; self.foreground = foreground
        reload(reader: reader, hasDestination: hasDestination)
    }
    mutating func disappear() {
        visible = false; revision = UUID(); owner = nil; value = nil
        // A push hides this origin; the immutable target stays until Back or an owner change.
    }
    mutating func setForeground(_ foreground: Bool, reader: (any RoamExperienceReading)?, hasDestination: Bool) {
        self.foreground = foreground; reload(reader: reader, hasDestination: hasDestination)
    }
    mutating func reload(reader: (any RoamExperienceReading)?, hasDestination: Bool) {
        revision = UUID(); owner = nil; value = nil
        if let target, !matches(target, reader: reader, hasDestination: hasDestination) { self.target = nil }
        guard visible, foreground, let reader else { return }
        let captured = RoamHomeRecoveryOwner(reader: reader)
        guard captured.scopeKey != nil else { return }
        do {
            let status = try reader.localWalkStatus()
            guard captured == RoamHomeRecoveryOwner(reader: reader) else { return }
            owner = captured; value = RoamHomeRecoveryBanner(status: status)
        } catch {
            // Unreadable metadata is not a missing/finished record. Preserve its bytes, show no stale notice.
        }
    }
    func banner(reader: (any RoamExperienceReading)?) -> RoamHomeRecoveryBanner? {
        guard visible, foreground, let reader, owner == RoamHomeRecoveryOwner(reader: reader) else { return nil }
        return value
    }
    mutating func continueToExistingDestination(reader: any RoamExperienceReading,
                                                hasDestination: Bool, rendered: UUID) {
        guard rendered == revision, target == nil, hasDestination,
              banner(reader: reader) == .recovered, let captured = owner else { return }
        // The banner is only metadata. Re-read at the tap; a new pending finish must use Check instead.
        reload(reader: reader, hasDestination: hasDestination)
        guard banner(reader: reader) == .recovered, owner == captured else { return }
        target = Target(owner: captured)
    }
    func matches(_ target: Target, reader: (any RoamExperienceReading)?, hasDestination: Bool) -> Bool {
        guard self.target == target, hasDestination, let reader, target.owner.scopeKey != nil else { return false }
        return target.owner == RoamHomeRecoveryOwner(reader: reader)
    }
}
