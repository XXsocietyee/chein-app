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
    /// 去看看我的地盘 from a moment opened over the sheet (圈下了).
    var onMine: (() -> Void)? = nil
    let onDismiss: () -> Void

    @State private var detent: PresentationDetent = .height(CityTokens.propertyDetent)
    @State private var fittedHeight: CGFloat = 280
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Over the live map at the 420 pt detent the sheet is the system material, so the map (the product) shows through;
    /// expanded it is opaque (xrefs-1 B.1 / Adopt 11). Reduce Transparency: always opaque. Nothing inside adds a material.
    private var sheetGround: AnyShapeStyle {
        if case .property = route, detent != .large, !reduceTransparency { return AnyShapeStyle(.regularMaterial) }
        return AnyShapeStyle(palette.bgElevated)
    }

    var body: some View {
        Group {
            if let place = store.place(id: route.placeID) {
                switch route {
                case .property:
                    CityPropertySheet(place: place, store: store, expanded: detent == .large, captureFix: captureFix,
                                      onRoute: onRoute, onClose: onDismiss)
                        .presentationDetents([.height(CityTokens.propertyDetent), .large], selection: $detent)
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(CityTokens.propertyDetent)))
                        .cySheetBackdropExempt()
                case .claim:
                    CityClaimSheet(place: place, store: store, captureFix: captureFix, uploader: photoUploader, fixture: fixtureClaim,
                                   onMoment: onMoment, onMine: onMine, onClose: onDismiss)
                        .presentationDetents([.large])
                case .challenge:
                    CityChallengeSheet(place: place, store: store, captureFix: captureFix, onMoment: onMoment, onClose: onDismiss)
                        .presentationDetents([.large])
                case .shield:
                    // One detent that hugs the content (xrefs-1 B.1, N47).
                    CityShieldSheet(place: place, store: store, onClose: onDismiss)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fittedHeight = $0 }
                        .presentationDetents([.height(max(fittedHeight + 24, 220))])
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
        .presentationBackground(sheetGround)
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
                Text(verbatim: title).cyText(.sheetTitle).foregroundStyle(palette.textPrimary)
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
    struct Row: Identifiable {
        let id = UUID(); let label: String; let value: String; var coin = false
        /// A balance shown as one rolling number with a −N chip (xrefs-1 B.1) instead of "1286 → 1166".
        var number: Int64? = nil
        var delta: Int64? = nil
        var holdsDelta = true
    }
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
                .cyText(.body)
                .padding(.horizontal, CYSpacing.md).frame(minHeight: 44)
                .accessibilityElement(children: .combine)
                if index < rows.count - 1 { Divider().overlay(palette.borderSubtle).padding(.leading, CYSpacing.md) }
            }
        }
        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
    @ViewBuilder private func value(_ row: Row) -> some View {
        if let number = row.number {
            CYDeltaNumber(value: number, delta: row.delta, holdsDelta: row.holdsDelta, font: Font.body.weight(.semibold),
                          leading: row.coin ? AnyView(CityCoin()) : nil)
        } else {
            HStack(spacing: 4) {
                if row.coin { CityCoin() }
                Text(verbatim: row.value).cyText(.numericBody).foregroundStyle(palette.textPrimary)
            }
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
            Text(verbatim: text).cyText(.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
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
                         districtIndex: CityDistrictInfo.slot(index: nil, token: card.districtColorToken) ?? place.districtIndex,
                         tier: card.tier ?? place.tier, level: card.lvl ?? place.level,
                         ownership: place.ownership, holderName: card.holder?.maskedName ?? place.holderName,
                         protectedUntil: card.protectedUntil?.date ?? place.protectedUntil, decay: card.decay ?? place.decay,
                         photoURL: card.photoURL ?? place.photoURL, radiusM: place.radiusM, distanceM: place.distanceM,
                         invested: card.invested ?? place.invested,
                         districtName: CityDistrictBook.usable(card.districtName, districtId: place.districtId) ?? place.districtName,
                         deedSerial: card.deedSerial ?? place.deedSerial)
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
                .cyText(.body).foregroundStyle(palette.textSecondary)
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
                        .cyText(.caption).foregroundStyle(palette.textTertiary).frame(maxWidth: .infinity)
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


/// Pin → property (owner continuity pass item 4): the property opens in a drawer over the SAME live map instead of a
/// system sheet, so the tapped pin can carry into it. The deed's photo tile grows out of the pin into the deed's photo
/// slot on `CYMotion.hero` while the drawer rises on `CYMotion.sheet`; the text that exists only at the end fades in
/// after half the move. Closing (✕, a drag down, or tapping another pin) runs it backwards to the pin. The grabber
/// tracks the finger 1:1 and any new touch retargets. Reduce Motion: a 180 ms cross-fade, no movement.
struct CityPropertyDrawer: View {
    let place: CityPlace
    @ObservedObject var store: CityBoardStore
    /// The tapped pin's centre in the window (nil: no flight).
    let origin: CGPoint?
    let captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    let onRoute: (CitySheetRoute) -> Void
    let onClose: () -> Void

    @State private var expanded = false
    @State private var shown = false
    @State private var flown = false
    @State private var contentShown = false
    @State private var closing = false
    @GestureState private var drag: CGFloat = 0
    @Namespace private var flight
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var flies: Bool { origin != nil && !reduceMotion }

    var body: some View {
        GeometryReader { proxy in
            let compact = min(CityTokens.propertyDetent, proxy.size.height * 0.62)
            let full = proxy.size.height * 0.94
            let resting = expanded ? full : compact
            let height = max(compact * 0.5, resting - drag)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    grabber(compact: compact, full: full)
                    CityPropertySheet(place: place, store: store, expanded: expanded, captureFix: captureFix,
                                      onRoute: onRoute, onClose: close)
                        .environment(\.cityDeedPhotoSlot, flies ? CityDeedPhotoSlot(namespace: flight, local: nil, hidesPhoto: !landed) : nil)
                        .opacity(contentShown ? 1 : 0)
                }
                .frame(width: proxy.size.width, height: height, alignment: .top)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                        .fill(reduceTransparency || expanded ? AnyShapeStyle(palette.bgElevated) : AnyShapeStyle(.regularMaterial))
                        .shadow(color: .black.opacity(0.4), radius: 16, y: -2)
                        .ignoresSafeArea(edges: .bottom)
                }
                .offset(y: shown || reduceMotion ? 0 : height + 40)
                .opacity(reduceMotion && !shown ? 0 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .overlay { if flies && !landed { flyingTile } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
        .onAppear(perform: open)
        .onChange(of: place.id) { _, _ in landed = false; flown = false; open() }
    }

    @State private var landed = false
    @State private var sourceReady = false

    /// The lead: the pin's tile, from the pin to the deed's photo slot.
    private var flyingTile: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            ZStack(alignment: .topLeading) {
                if let origin {
                    Color.clear.frame(width: 34, height: 34)
                        .matchedGeometryEffect(id: CityDeedPhotoSlot.sourceID, in: flight, isSource: true)
                        .position(x: origin.x - frame.minX, y: origin.y - frame.minY)
                }
                CityDeedPhoto(url: place.photoURL, corner: flown ? 0 : 17, place: place, cover: .compact)
                    .matchedGeometryEffect(id: flown ? CityDeedPhotoSlot.slotID : CityDeedPhotoSlot.sourceID, in: flight,
                                           properties: .frame, isSource: false)
                    .opacity(sourceReady ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func grabber(compact: CGFloat, full: CGFloat) -> some View {
        Capsule().fill(palette.textTertiary.opacity(0.6)).frame(width: 36, height: 5)
            .frame(minWidth: CYSpacing.minTouchTarget, maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2)
                .updating($drag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let projected = value.translation.height + value.velocity.height * 0.12
                    let spring = reduceMotion ? CYMotion.reduced : CYMotion.sheet
                    if projected > 120 && !expanded { close() }
                    else if projected > 80 { withAnimation(spring) { expanded = false } }
                    else if projected < -80 { withAnimation(spring) { expanded = true } }
                })
            .onTapGesture { withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.sheet) { expanded.toggle() } }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: CityCopy(locale: locale)("地契", "Deed")))
            .accessibilityValue(Text(verbatim: expanded ? CityCopy(locale: locale)("已展开", "Expanded") : CityCopy(locale: locale)("已收起", "Collapsed")))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { withAnimation(CYMotion.reduced) { expanded.toggle() } }
    }

    private func open() {
        closing = false
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.18)) { shown = true; contentShown = true }
            landed = true
        } else {
            withAnimation(CYMotion.sheet) { shown = true }
            if flies {
                // Lay the pin's frame out first (the tile is hidden for that turn), then fly.
                Task { @MainActor in
                    await Task.yield()
                    sourceReady = true
                    try? await Task.sleep(for: .milliseconds(16))
                    withAnimation(CYMotion.hero) { flown = true }
                }
            } else { landed = true }
            // Content that exists only at the end fades in after about half the move.
            withAnimation(.easeOut(duration: CYMotion.Duration.quick).delay(0.22)) { contentShown = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                if !closing { landed = true }
            }
        }
        AccessibilityNotification.LayoutChanged(nil).post()
    }

    private func close() {
        guard !closing else { return }
        closing = true
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.18)) { shown = false; contentShown = false }
        } else {
            landed = false
            withAnimation(CYMotion.hide) { contentShown = false }
            if flies { withAnimation(CYMotion.hero) { flown = false } }
            withAnimation(CYMotion.sheet) { shown = false }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.18 : 0.36))
            onClose()
        }
    }
}
