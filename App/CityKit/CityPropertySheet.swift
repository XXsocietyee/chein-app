import SwiftUI
import MapKit
import UserNotifications
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Property sheets N08–N12 (204:23400 … 204:23956): a compact deed at the 420 pt detent with the map
// live under it (`presentationBackgroundInteraction`, no scrim), the full deed on expand (Q3).
// At most one banner, a table of at most two rows, one primary.

struct CitySheetHost: View {
    let route: CitySheetRoute
    @ObservedObject var store: CityBoardStore
    let captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    let photoUploader: CityClaimPhotoUploading?
    var fixtureClaim: CityClaimFixture? = nil
    let onRoute: (CitySheetRoute) -> Void
    let onMoment: (CityMomentRoute) -> Void
    let onDismiss: () -> Void

    @State private var detent: PresentationDetent = .height(CityTokens.propertyDetent)
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Group {
            if let place = store.place(id: route.placeID) {
                switch route {
                case .property:
                    CityPropertySheet(place: place, store: store, expanded: detent == .large, captureFix: captureFix,
                                      onRoute: onRoute, onClose: onDismiss)
                        .presentationDetents([.height(CityTokens.propertyDetent), .large], selection: $detent)
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(CityTokens.propertyDetent)))
                case .claim:
                    CityClaimSheet(place: place, store: store, captureFix: captureFix, uploader: photoUploader, fixture: fixtureClaim,
                                   onMoment: onMoment, onClose: onDismiss)
                        .presentationDetents([.large])
                case .challenge:
                    CityChallengeSheet(place: place, store: store, captureFix: captureFix, onMoment: onMoment, onClose: onDismiss)
                        .presentationDetents([.large])
                case .shield:
                    CityShieldSheet(place: place, store: store, onClose: onDismiss)
                        .presentationDetents([.medium])
                case .upgrade:
                    CityUpgradeSheet(place: place, store: store, captureFix: captureFix, onMoment: onMoment, onClose: onDismiss)
                        .presentationDetents([.medium, .large])
                }
            } else {
                CityEmptyLine(symbol: "mappin.slash", text: ChannelCopy.text("这个地点已经不在地图上了。", "This place is no longer on the map.", locale: .current))
                    .padding().presentationDetents([.height(200)])
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(palette.bgElevated)
        .themeDomain(.player)
    }
}

/// Sheet title row: title (+ tags) left, round ✕ right (player sheet header).
struct CitySheetTitle: View {
    let title: String
    var tags: [String] = []
    var districtIndex = 0
    var district: String? = nil
    let onClose: () -> Void
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: title).font(CYTypography.sheetTitle).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                if !tags.isEmpty || district != nil {
                    HStack(spacing: CYSpacing.xs) {
                        ForEach(tags, id: \.self) { CityStatusTag(text: $0) }
                        if let district { CityDistrictChip(index: districtIndex, text: district) }
                    }
                }
            }
            Spacer(minLength: CYSpacing.sm)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(palette.textSecondary)
                    .frame(width: 30, height: 30).background(palette.bgRaised, in: Circle())
                    .frame(width: 44, height: 44).contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: CityCopy(locale: locale)("关闭", "Close")))
        }
    }
}

/// A grouped table of label / value rows (≤ 2 rows on the property sheets).
struct CityFactTable: View {
    struct Row: Identifiable { let id = UUID(); let label: String; let value: String; var coin = false }
    let rows: [Row]
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(verbatim: row.label).foregroundStyle(palette.textSecondary)
                        Spacer(minLength: CYSpacing.sm)
                        value(row)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.label).foregroundStyle(palette.textSecondary)
                        value(row)
                    }
                }
                .font(Font.body)
                .padding(.horizontal, CYSpacing.md).frame(minHeight: 44)
                .accessibilityElement(children: .combine)
                if index < rows.count - 1 { Divider().overlay(palette.borderSubtle).padding(.leading, CYSpacing.md) }
            }
        }
        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
    private func value(_ row: Row) -> some View {
        HStack(spacing: 4) {
            if row.coin { CityCoin() }
            Text(verbatim: row.value).font(Font.body.weight(.medium).monospacedDigit()).foregroundStyle(palette.textPrimary)
        }
    }
}

struct CityBanner: View {
    let text: String
    var symbol = "info.circle"
    var tone: CityStatusTag.Tone = .neutral
    @Environment(\.cyPalette) private var palette
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            Text(verbatim: text).font(Font.subheadline).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md)
        .background(fill, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    private var tint: Color {
        switch tone { case .ok: return palette.success; case .warning: return palette.warning; case .error: return palette.danger; case .neutral: return palette.textSecondary }
    }
    private var fill: Color {
        switch tone { case .ok: return palette.successSoft; case .warning: return palette.warningSoft; case .error: return palette.dangerSoft; case .neutral: return palette.bgRaised }
    }
}

struct CityPropertySheet: View {
    let place: CityPlace
    @ObservedObject var store: CityBoardStore
    let expanded: Bool
    let captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    let onRoute: (CitySheetRoute) -> Void
    let onClose: () -> Void

    @State private var card: CityTerritoryPropertyCard?
    @State private var fix: RoamDeviceFix?
    @State private var scoutedDC: Int?
    @State private var reminderSet = false
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.openURL) private var openURL

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var display: CityPlace {
        guard let card else { return place }
        return CityPlace(id: place.id, title: card.title ?? place.title, coordinate: place.coordinate, territoryId: place.territoryId,
                         poiId: place.poiId, boardId: place.boardId, pointId: place.pointId, districtId: place.districtId,
                         districtIndex: place.districtIndex, tier: card.tier ?? place.tier, level: card.lvl ?? place.level,
                         ownership: place.ownership, holderName: card.holder?.maskedName ?? place.holderName,
                         protectedUntil: card.protectedUntil?.date ?? place.protectedUntil, decay: card.decay ?? place.decay,
                         photoURL: card.photoURL ?? place.photoURL, radiusM: place.radiusM, distanceM: place.distanceM,
                         invested: card.invested ?? place.invested)
    }
    private var distance: Double? { display.distance(from: fix?.coordinate ?? store.center) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                HStack { Spacer(); closeButton }.padding(.bottom, -CYSpacing.md)
                CityDeedCard(place: display, size: expanded ? .full : .sheet)
                    .animation(CityTokens.sheetSpring, value: expanded)
                banner
                table
                if let issue = store.issueCode {
                    CityBanner(text: CityReasonCopy.text(issue, chinese: copy.chinese), symbol: "exclamationmark.circle", tone: .error)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        // The one primary stays in reach at the 420 pt detent; the table scrolls under it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.top, CYSpacing.sm).padding(.bottom, CYSpacing.md)
                .background(palette.bgElevated)
        }
        .task(id: place.id) {
            card = await store.card(for: place)
            if let captureFix { fix = try? await captureFix() }
        }
        .accessibilityIdentifier("city.property.sheet")
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(palette.textSecondary)
                .frame(width: 30, height: 30).background(palette.bgRaised, in: Circle())
                .frame(width: 44, height: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: copy("关闭", "Close")))
    }

    @ViewBuilder private var banner: some View {
        switch display.ownership {
        case .open:
            if let distance {
                if distance <= CityPresencePreflight.claimRadiusM {
                    CityBanner(text: copy("距你 \(Int(distance)) m，可以圈地", "\(Int(distance)) m away: you can claim"), symbol: "location.fill", tone: .ok)
                } else {
                    CityBanner(text: copy("距你 \(copy.distance(distance) ?? "")，走到 40 m 内才能圈地", "\(copy.distance(distance) ?? "") away: get within 40 m to claim"), symbol: "location")
                }
            }
        case .other:
            if let until = display.protectedUntil, until > Date() {
                CityBanner(text: copy("保护到 ", "Protected until ") + copy.clock(until), symbol: "lock")
            } else if display.isWeathered {
                CityBanner(text: copy("TA 很久没来，地盘已风化，更容易拿下", "The holder has been away: weathered and easier to take"), symbol: "hourglass", tone: .warning)
            }
        case .mine:
            if let until = display.protectedUntil, until > Date() {
                CityBanner(text: copy("保护到 ", "Protected until ") + copy.clock(until), symbol: "lock")
            } else if display.isWeathered {
                CityBanner(text: copy("太久没来，已风化：租金减半。到场一次就能恢复。", "Weathered from absence: rent halved. One visit restores it."), symbol: "hourglass", tone: .warning)
            }
        case .fogged:
            Text(verbatim: copy("走近这片迷雾，才能看到这里是谁的、什么等级。", "Walk into this fog to see who holds it and at what level."))
                .font(Font.body).foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder private var table: some View {
        switch display.ownership {
        case .open:
            CityFactTable(rows: [
                .init(label: copy("占领价", "Claim price"), value: display.claimPrice.map(String.init) ?? copy("报价后可见", "Shown in the quote"), coin: display.claimPrice != nil),
                .init(label: copy("别人每次到访，你收", "Each visit pays you"), value: display.tier.map { copy("\(CityMonopolyRules.rent(tier: $0, level: 0)) 积分起", "from \(CityMonopolyRules.rent(tier: $0, level: 0)) pts") } ?? copy("按地点等级", "By place tier"))
            ])
        case .other:
            if display.isProtected(now: Date()) {
                CityFactTable(rows: [
                    .init(label: copy("别人每次到访，TA 收", "Each visit pays them"), value: copy.points(display.rentPerVisit ?? 0)),
                    .init(label: copy("本周到访", "Visits this week"), value: card?.visits.map { copy("\($0) 次", "\($0)") } ?? "—")
                ])
            } else {
                CityFactTable(rows: [
                    .init(label: copy("挑战费", "Challenge fee"), value: display.challengeFeePreview.map(String.init) ?? "—", coin: true),
                    .init(label: copy("难度", "Difficulty"), value: (scoutedDC ?? card?.dc).map { "DC \($0)" } ?? copy("侦察后可见", "Scout to see"))
                ])
            }
        case .mine:
            if display.canUpgrade {
                let next = display.level + 1
                CityFactTable(rows: [
                    .init(label: copy("升到 ", "Up to ") + copy.level(next), value: copy("租金 ", "Rent ") + CityMonopolyFormat.multiplier(CityMonopolyRules.levelMultiplier(display.level)) + " → " + CityMonopolyFormat.multiplier(CityMonopolyRules.levelMultiplier(next))),
                    .init(label: copy("护盾", "Shield"), value: copy("保护 +12 小时", "+12 h protection"))
                ])
            } else {
                CityFactTable(rows: [.init(label: copy("护盾", "Shield"), value: copy("保护 +12 小时", "+12 h protection"))])
            }
        case .fogged:
            CityFactTable(rows: [.init(label: copy("距你", "Distance"), value: copy.distance(distance).map { copy("约 ", "about ") + $0 } ?? "—")])
        }
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: CYSpacing.sm) {
            switch display.ownership {
            case .open:
                CYPillButton(verbatim: display.claimPrice.map { copy("拍照圈地 · \($0) 积分", "Photo claim · \($0) pts") } ?? copy("拍照圈地", "Photo claim")) { onRoute(.claim(place.id)) }
                    .accessibilityIdentifier("city.property.claim")
                if let holdings = store.holdings {
                    Text(verbatim: copy("持有 \(holdings.count) / \(holdings.limit)", "Holding \(holdings.count) / \(holdings.limit)"))
                        .font(CYTypography.caption).foregroundStyle(palette.textTertiary).frame(maxWidth: .infinity)
                }
            case .other:
                if let until = display.protectedUntil, until > Date() {
                    CYPillButton(verbatim: reminderSet ? copy("已设提醒", "Reminder set") : copy("保护结束时提醒我", "Remind me when protection ends")) {
                        Task { reminderSet = await CityNotifications.remindProtectionEnd(place: display, at: until, locale: locale) }
                    }
                    .disabled(reminderSet)
                } else {
                    CYPillButton(verbatim: copy("发起挑战 · \(display.challengeFeePreview ?? 0) 积分", "Challenge · \(display.challengeFeePreview ?? 0) pts")) { onRoute(.challenge(place.id)) }
                        .accessibilityIdentifier("city.property.challenge")
                    if scoutedDC == nil && card?.dc == nil {
                        CYPillButton(verbatim: copy("先侦察难度 · \(CityMonopolyRules.scoutCost) 积分", "Scout first · \(CityMonopolyRules.scoutCost) pts"), style: .secondary) {
                            Task { scoutedDC = await store.scout(display) }
                        }
                        .disabled(store.busy)
                    }
                }
            case .mine:
                if display.canUpgrade {
                    let cost = CityMonopolyRules.upgradeCost(tier: display.tier ?? .t1, fromLevel: display.level) ?? 0
                    CYPillButton(verbatim: copy("升级 · \(cost) 积分", "Upgrade · \(cost) pts")) { onRoute(.upgrade(place.id)) }
                }
                CYPillButton(verbatim: copy("开护盾 · \(CityMonopolyRules.shieldCost) 积分", "Shield · \(CityMonopolyRules.shieldCost) pts"), style: display.canUpgrade ? .secondary : .primary) {
                    onRoute(.shield(place.id))
                }
            case .fogged:
                CYPillButton(verbatim: copy("带我过去", "Take me there")) {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: place.clCoordinate))
                    item.name = copy("未点亮的地点", "Unlit place")
                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                }
            }
        }
    }
}
