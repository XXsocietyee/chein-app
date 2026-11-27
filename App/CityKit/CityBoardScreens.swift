import SwiftUI
import MapKit
import UserNotifications
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Board home N01 (204:21814), its loading N02 and empty N03; 我的地盘 N46 (205:8376) with its
// sheets; 收租明细 N28 (204:33843) and its notifications-off state N33.

/// N01 城市大富翁: map module → stat strip → 需要你处理 → 我的地盘 · n → 更多.
struct CityBoardView: View {
    @ObservedObject var store: CityBoardStore
    let onOpen: (CityPlace) -> Void
    let onMine: () -> Void
    let onLedger: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var copy: CityCopy { CityCopy(locale: locale) }
    private var attention: [CityPlace] {
        store.mine.filter { $0.isWeathered || ($0.protectedUntil.map { $0 > Date() && $0 < Date().addingTimeInterval(3 * 3600) } ?? false) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if store.phase == .loading && store.places.isEmpty {
                    skeleton
                } else {
                    mapModule
                    statStrip
                    if store.mine.isEmpty {
                        empty
                    } else {
                        if !attention.isEmpty { section(copy("需要你处理", "Needs you")) { ForEach(attention) { row($0, trailing: .status) } } }
                        section(copy("我的地盘 · \(store.mine.count)", "My places · \(store.mine.count)")) {
                            ForEach(store.mine.prefix(5)) { row($0, trailing: .rent) }
                            if store.mine.count > 5 { moreLink(copy("全部 \(store.mine.count) 块", "All \(store.mine.count)"), action: onMine) }
                        }
                    }
                    section(copy("更多", "More")) {
                        menuRow(symbol: "dollarsign.circle", title: copy("收租明细", "Rent ledger"),
                                detail: store.todayRent.map { copy("今天 +\($0) 积分，03:00 核对后入账", "Today +\($0) pts, settled after 03:00") }, action: onLedger)
                        menuRow(symbol: "flag", title: copy("我的地盘", "My places"), detail: store.holdings.map { copy("持有 \($0.count) / \($0.limit)", "Holding \($0.count) / \($0.limit)") }, action: onMine)
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.xxxl)
        }
        .background(palette.bgPage.ignoresSafeArea())
        .navigationTitle(Text(verbatim: copy("城市大富翁", "City Monopoly")))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { if let center = store.center { await store.load(center: center) } }
        .accessibilityIdentifier("city.board")
    }

    private var mapModule: some View {
        let mine = store.places.filter { $0.ownership != .fogged }
        let center = store.center.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return Map(initialPosition: center.map { .region(MKCoordinateRegion(center: $0, latitudinalMeters: 2400, longitudinalMeters: 2400)) } ?? .automatic,
                   interactionModes: []) {
            ForEach(mine) { place in
                MapPolygon(coordinates: place.cell())
                    .foregroundStyle(CityTokens.district(place.districtIndex).opacity(place.ownership == .open ? 0.0 : 0.22))
                    .stroke(place.ownership == .open ? Color.white.opacity(0.4) : CityTokens.district(place.districtIndex), lineWidth: 1.5)
                Annotation("", coordinate: place.clCoordinate) { CityPin(place: place) }.annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if let holdings = store.holdings {
                HStack(spacing: 6) {
                    Image(systemName: "flag").accessibilityHidden(true)
                    Text(verbatim: copy("持有 \(holdings.count) / \(holdings.limit)", "Holding \(holdings.count) / \(holdings.limit)"))
                    if let rent = store.todayRent { Text(verbatim: copy("今天 +\(rent) 积分", "Today +\(rent) pts")) }
                }
                .cyText(.caption, weight: .semibold).foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThinMaterial, in: Capsule()).padding(CYSpacing.md)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: copy("领地缩略图，\(mine.count) 个地点", "Territory preview, \(mine.count) places")))
    }

    /// Stats without a box (xrefs-1 B.1 / Adopt 4): three numbers, two hairlines; 积分 rolls when it changes.
    private var statStrip: some View {
        CYPlainStatRow(stats: [
            CYPlainStat(id: "points", value: store.points?.balance.map(String.init) ?? "—",
                        label: copy("积分", "Points") + (store.points?.pending.map { $0 > 0 ? copy(" · +\($0) 待入账", " · +\($0) pending") : "" } ?? ""),
                        rollValue: store.points?.balance.map(Double.init)),
            CYPlainStat(id: "holding", value: store.holdings.map { "\($0.count) / \($0.limit)" } ?? "—", label: copy("持有", "Holding")),
            CYPlainStat(id: "season", value: seasonLeft ?? "—", label: copy("赛季剩余", "Season left"))
        ])
        .padding(.vertical, CYSpacing.sm)
    }

    private var seasonLeft: String? {
        guard let ends = store.season?.freezesAt ?? store.season?.endsAt else { return nil }
        let days = max(0, Int(ceil(ends.date.timeIntervalSinceNow / 86_400)))
        return copy("\(days) 天", "\(days) d")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYPillButton(verbatim: copy("去圈第一块地", "Claim your first place")) {
                if let first = store.places.first(where: { $0.ownership == .open }) { onOpen(first) }
            }
            .disabled(!store.places.contains { $0.ownership == .open })
            Text(verbatim: copy("走到真实地点，拍一张照片，通过定位校验，就能圈下它。", "Walk to a real place, take a photo, pass the location check, and it is yours."))
                .cyText(.body).foregroundStyle(palette.textSecondary)
        }
    }

    private var skeleton: some View {
        CYSkeleton(variant: .detail)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: title).cyText(.sectionTitle).foregroundStyle(palette.textPrimary).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func row(_ place: CityPlace, trailing: CityDeedTrailing) -> some View {
        Button { onOpen(place) } label: { CityDeedCard(place: place, size: .row, trailing: trailing) }.buttonStyle(.plain)
    }

    private func moreLink(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(verbatim: text); Image(systemName: "chevron.right").imageScale(.small) }
                .cyText(.meta).foregroundStyle(palette.textSecondary).frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func menuRow(symbol: String, title: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(palette.textPrimary)
                    .frame(width: 36, height: 36).background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                    if let detail { Text(verbatim: detail).cyText(.caption).foregroundStyle(palette.textSecondary) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            }
            .padding(CYSpacing.md).frame(minHeight: 60)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// N46 我的地盘: one card per place (deed row + its one action line).
struct CityMyPropertiesView: View {
    @ObservedObject var store: CityBoardStore
    let onOpen: (CityPlace) -> Void
    let onShield: (CityPlace) -> Void
    let onUpgrade: (CityPlace) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var copy: CityCopy { CityCopy(locale: locale) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.md) {
                Text(verbatim: subtitle).cyText(.meta).foregroundStyle(palette.textSecondary)
                if store.mine.isEmpty {
                    CityEmptyLine(symbol: "flag", text: copy("还没有地盘。在地图上找一个带 + 的地点，走过去圈下它。", "No places yet. Find a + on the map and walk there to claim it."))
                }
                ForEach(store.mine) { place in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Button { onOpen(place) } label: { CityDeedCard(place: place, size: .row, trailing: .rent) }.buttonStyle(.plain)
                        if let until = place.protectedUntil, until > Date() {
                            CityBanner(text: copy("保护中，到 ", "Protected until ") + copy.clock(until), symbol: "lock")
                        } else if place.isWeathered {
                            CityBanner(text: copy("太久没来，已风化：租金减半，更容易被抢", "Weathered from absence: half rent, easier to take"), symbol: "hourglass", tone: .warning)
                        }
                        HStack(spacing: CYSpacing.sm) {
                            if place.canUpgrade {
                                CYPillButton(verbatim: copy("升级", "Upgrade"), style: .secondary) { onUpgrade(place) }
                            }
                            CYPillButton(verbatim: copy("开护盾", "Shield"), style: .secondary) { onShield(place) }
                        }
                    }
                    .padding(CYSpacing.md)
                    .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal).padding(.bottom, CYSpacing.xxxl)
        }
        .background(palette.bgPage.ignoresSafeArea())
        .navigationTitle(Text(verbatim: copy("我的地盘", "My places")))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("city.mine")
    }

    private var subtitle: String {
        let holding = store.holdings.map { copy("持有 \($0.count) / \($0.limit)", "Holding \($0.count) / \($0.limit)") } ?? ""
        return holding + copy(" · 到场一次就能刷新地盘状态", " · one visit refreshes a place")
    }
}

/// N28 收租明细: one leading image, visitor · time, the amount over its state tag.
struct CityRentLedgerView: View {
    @ObservedObject var store: CityBoardStore
    @State private var notificationsOff = false
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var copy: CityCopy { CityCopy(locale: locale) }

    var body: some View {
        List {
            if notificationsOff {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CityBanner(text: copy("通知没开：收租汇总、保护快结束和被抢都不会提醒你。", "Notifications are off: no rent summary, protection or takeover alerts."),
                                   symbol: "bell.slash", tone: .warning)
                        CYPillButton(verbatim: copy("去设置打开", "Open Settings"), style: .secondary, fullWidth: false) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                HStack(spacing: 0) {
                    total(store.revenue?.todayPending, copy("今天待入账", "Pending today"))
                    total(store.revenue?.todayAvailable, copy("今天已入账", "Settled today"))
                    total(store.revenue?.threshold, copy("每日上限", "Daily threshold"))
                }
                .listRowBackground(palette.bgElevated)
            }
            Section {
                let events = store.revenue?.events ?? []
                if events.isEmpty {
                    Text(verbatim: copy("今天还没有人来你的地盘打卡。", "Nobody has checked in at your places today."))
                        .cyText(.body).foregroundStyle(palette.textSecondary).listRowBackground(palette.bgElevated)
                }
                ForEach(events) { event in
                    let place = store.place(id: event.propertyId)
                    HStack(spacing: CYSpacing.md) {
                        CityDeedPhoto(url: place?.photoURL, corner: 10).frame(width: 44, height: 44)
                            .overlay(alignment: .leading) { Rectangle().fill(CityTokens.district(place?.districtIndex ?? 0)).frame(width: 3) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: place.map { copy.title($0) } ?? copy("我的地盘", "My place")).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                            Text(verbatim: [event.visitorMasked, event.createdAt.map { copy.clock($0.date) }].compactMap { $0 }.joined(separator: " · "))
                                .cyText(.caption).foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(verbatim: "+\(event.granted)").cyText(.cardTitle, monospacedDigit: true).foregroundStyle(palette.textPrimary)
                            CityStatusTag(text: stateLabel(event.yieldState), tone: event.yieldState == .void ? .error : .neutral)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .listRowBackground(palette.bgElevated)
                }
            } footer: {
                Text(verbatim: copy("租金实时记为待入账，每天 03:00 核对后可以使用。", "Rent shows as pending at once and becomes usable after the 03:00 check."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bgPage.ignoresSafeArea())
        .navigationTitle(Text(verbatim: copy("收租明细", "Rent ledger")))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadRevenue()
            notificationsOff = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
        }
        .refreshable { await store.loadRevenue() }
        .accessibilityIdentifier("city.ledger")
    }

    private func total(_ value: Int64?, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value.map { "\($0)" } ?? "—").cyText(.dataXL).foregroundStyle(palette.textPrimary)
                .contentTransition(.numericText(value: Double(value ?? 0)))
            Text(verbatim: label).cyText(.caption).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func stateLabel(_ state: CityYieldState?) -> String {
        switch state {
        case .pending: return copy("待入账", "Pending")
        case .available: return copy("已入账", "Settled")
        case .void: return copy("已作废", "Voided")
        case nil: return "—"
        }
    }
}
