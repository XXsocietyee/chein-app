import SwiftUI

// Mini-program subpackageRoam parity pieces (history RunCard, session footprint card, shared
// footprint receiver, POI node card, city voucher, city stamp). Read-only: every write stays
// with its existing dormant coordinator, and no view here samples location or opens a camera.

/// `scene-roam-history` total row under the big km: `{n} 次漫游 · {n} 家店 · {h:mm} 用时`, one column each.
/// A single unknown shop count or duration makes that total unknown ("—"), never a partial sum.
struct RoamHistoryParityStrip: View {
    let records: [RoamHistoryRecord]
    var body: some View {
        let summary = RoamHistoryStripSummary(records)
        HStack(alignment: .top, spacing: CYSpacing.xxl) {
            column(Text(summary.trips, format: .number), "roamSub.w208.history.trips")
            column(Text(verbatim: summary.shopsText), "roamSub.w208.history.shopCount")
            column(Text(verbatim: Self.totalTime(records)), "roamSub.w208.history.duration")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roamSub.w208.history.strip")
    }
    private func column(_ value: Text, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            value.font(.system(.title3, design: .rounded).weight(.heavy).italic()).monospacedDigit()
                .foregroundStyle(CYColor.textPrimary).cyWrapText()
            Text(label).cyText(.caption).foregroundStyle(CYColor.textSecondary)
        }
    }
    /// Mini-program `h:mm` over every record's `durSec`; any record without one makes the total unknown.
    static func totalTime(_ records: [RoamHistoryRecord]) -> String {
        guard !records.isEmpty, records.allSatisfy({ ($0.durSec ?? -1) >= 0 }) else { return "—" }
        let seconds = records.compactMap(\.durSec).reduce(0, +)
        return "\(seconds / 3600):" + String(format: "%02d", seconds % 3600 / 60)
    }
}

/// `monthHead` above the first card of each month (`2026年8月`); nil for an unusable timestamp.
struct RoamHistoryMonthHead: View {
    let date: Date
    var body: some View {
        Text(date, format: .dateTime.year().month(.wide))
            .cyText(.caption, weight: .semibold).foregroundStyle(CYColor.textSecondary)
            .padding(.top, CYSpacing.sm)
            .accessibilityAddTraits(.isHeader)
    }
    static func isNewMonth(_ record: RoamHistoryRecord, after previous: RoamHistoryRecord?, calendar: Calendar = .current) -> Bool {
        guard let date = record.recordedAt else { return false }
        guard let before = previous?.recordedAt else { return true }
        return !calendar.isDate(date, equalTo: before, toGranularity: .month)
    }
}

/// RunCard date `8月9日 周六 · 晚上` (dateCard); the day part follows the record's hour in quarters.
struct RoamRunCardDateText: View {
    let record: RoamHistoryRecord
    private static let daypartKeys = ["roamSub.w208.history.daypart.0", "roamSub.w208.history.daypart.1",
                                      "roamSub.w208.history.daypart.2", "roamSub.w208.history.daypart.3"]
    var body: some View {
        if let date = record.recordedAt {
            let hour = Calendar.current.component(.hour, from: date)
            (Text(date, format: .dateTime.month().day().weekday(.abbreviated)) + Text(verbatim: " · ")
             + Text(LocalizedStringKey(Self.daypartKeys[min(3, max(0, hour / 6))])))
                .cyText(.caption).monospacedDigit().foregroundStyle(CYColor.textSecondary)
        } else {
            Text("roamSub.w208.history.dateUnavailable").cyText(.caption).foregroundStyle(CYColor.textSecondary)
        }
    }
}

/// RunCard title: `{zone}漫游`, or 城市漫游 for the placeholder zone.
struct RoamRunCardTitle: View {
    let record: RoamHistoryRecord
    var font: Font = .title3
    /// RHIST-5: a type token wins over `font` (Dynamic Type through `.cyText`).
    var style: CYTextStyle? = nil
    var body: some View {
        switch RoamRunCardPresentation(record).title {
        case .zone(let zone): styled(Text("roamSub.w208.history.zoneTitle \(zone)"))
        case .city: styled(Text("roam.experience.cityWalk"))
        }
    }
    private func styled(_ text: Text) -> Text {
        if let style { return text.cyText(style).bold() }
        return text.font(font).bold()
    }
}

/// RunCard date (M/D/YY), 公里 / 探店 / 用时, medal marks and `{n} 枚邮票`.
struct RoamRunCardParityMeta: View {
    let record: RoamHistoryRecord
    var body: some View {
        let card = RoamRunCardPresentation(record)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                stat(card.distanceText, "roamSub.w208.history.km")
                stat(card.shopsText, "roamSub.w208.history.shops")
                stat(card.timeText, "roamSub.w208.history.duration")
            }
            if !card.medals.isEmpty || card.stamps > 0 {
                Divider().overlay(CYColor.borderSubtle)
                HStack(spacing: 8) {
                    ForEach(Array(card.medals.enumerated()), id: \.offset) { _, medal in
                        Image(systemName: "hexagon.fill").foregroundStyle(CYNight.lantern).accessibilityLabel(Text(verbatim: medal))
                    }
                    if card.stamps > 0 {
                        Label { Text("roamSub.w208.history.stamps \(card.stamps)") } icon: { Image(systemName: "star.fill").foregroundStyle(CYNight.lantern) }
                            .font(.caption).foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
        }.accessibilityElement(children: .combine)
            .accessibilityIdentifier("roamSub.w208.history.runCard")
    }
    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value).font(.system(.headline, design: .rounded).weight(.bold).monospacedDigit())
                .cyWrapText()
            Text(label).cyText(.caption).foregroundStyle(CYColor.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 那年今日 / 月度回顾 / 导出 row inside the history page. Export is listed only with its owner-only tools.
@MainActor struct RoamHistoryToolsRow: View {
    let reader: (any RoamPassportToolsReading)?
    var privateTools: (any RoamPrivateToolsServing)? = nil
    var anniversaryRouteDestination: ((String) -> AnyView)? = nil
    var body: some View {
        HStack(spacing: 12) {
            NavigationLink { RoamAnniversaryView(reader: reader, routeDestination: anniversaryRouteDestination) } label: { tool("roamSub.w208.history.tool.anniversary", "calendar") }
                .accessibilityIdentifier("roamSub.w208.history.tool.anniversary")
            NavigationLink { RoamMonthlyRecapView(reader: reader, routeDestination: anniversaryRouteDestination) } label: { tool("roamSub.w208.history.tool.recap", "list.bullet") }
                .accessibilityIdentifier("roamSub.w208.history.tool.recap")
            if let privateTools {
                NavigationLink { RoamExplorationExportView(tools: privateTools) } label: { tool("roamSub.w208.history.tool.export", "arrow.down.doc") }
                    .accessibilityLabel(Text("roamSub.w208.history.tool.exportLabel"))
                    .accessibilityIdentifier("roamSub.w208.history.tool.export")
            }
        }.buttonStyle(QuestifyCardButtonStyle())
    }
    private func tool(_ key: LocalizedStringKey, _ symbol: String) -> some View {
        VStack(spacing: 6) { Image(systemName: symbol).font(.title3).accessibilityHidden(true); Text(key).font(.caption.weight(.medium)) }
            .foregroundStyle(CYColor.textPrimary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64)
            // N-r11-4: system grouped surface instead of night glass.
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
}

struct RoamExportUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label("roamSub.w208.history.tool.exportLabel", systemImage: "arrow.down.doc")
        } description: { Text("roamSub.w208.history.exportUnavailable") }
            .accessibilityIdentifier("roamSub.w208.history.exportUnavailable")
    }
}

/// `subpackageRoam/session` page subtitle under the 本次漫游 title: `dateFull · time`.
struct RoamSessionParityHeader: View {
    let record: RoamHistoryRecord
    var body: some View {
        if let date = record.recordedAt {
            HStack(spacing: 4) {
                Text(date, format: .dateTime.year().month().day().weekday(.abbreviated))
                if let time = record.durationText { Text(verbatim: "· " + time) }
            }
            .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
            .accessibilityElement(children: .combine).accessibilityIdentifier("roamSub.w208.session.header")
        }
    }
}

/// `routeName` (session index.js) without inventing a place name.
struct RoamSessionRouteNameText: View {
    let name: RoamSessionRouteName
    var body: some View {
        switch name {
        case .zone(let zone): Text(verbatim: zone)
        case .places(let first, let count): Text("roamSub.w208.session.route.places \(first) \(count)")
        case .place(let place): Text("roamSub.w208.session.route.place \(place)")
        case .date(let month, let day): Text("roamSub.w208.session.route.date \(month) \(day)")
        case .generic: Text("roamSub.w208.session.route.generic")
        }
    }
}

/// Footprint card additions: route name, 已完成本次漫游, 探索度, 点亮 and the brand line.
/// No share link is published from iOS; the card says so with the source's own wording.
struct RoamShareCardParityFooter: View {
    let record: RoamHistoryRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoamSessionRouteNameText(name: RoamSessionRouteName(record)).cyText(.cardTitle)
                .accessibilityIdentifier("roamSub.w208.share.routeName")
            Text("roamSub.w208.session.completeFact").cyText(.body)
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    if let percent = record.explorePct { Text(verbatim: "\(percent)%").cyText(.cardTitle, monospacedDigit: true) }
                    else { Text(verbatim: "--%").cyText(.cardTitle, monospacedDigit: true) }
                    Text("roamSub.w208.share.explore").cyText(.caption).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("roamSub.w208.share.explore")
                VStack(alignment: .leading) {
                    Text(verbatim: record.shops.map(String.init) ?? "—").cyText(.cardTitle, monospacedDigit: true)
                    Text("roamSub.w208.share.lit").cyText(.caption).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("roamSub.w208.share.lit")
                if record.footprintCount > 0 {
                    VStack(alignment: .leading) {
                        Text(verbatim: String(record.footprintCount)).cyText(.cardTitle, monospacedDigit: true)
                        Text("roamSub.w208.share.footprints").cyText(.caption).foregroundStyle(.secondary)
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("roamSub.w208.share.footprints")
                }
            }
            Text("roamSub.w208.share.brand").cyText(.meta, weight: .semibold).foregroundStyle(.secondary)
        }
    }
}

struct RoamShareLinkDormantNotice: View {
    var body: some View {
        Label("roamSub.w208.share.linkNotGenerated", systemImage: "link.badge.plus")
            .cyText(.meta).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("roamSub.w208.share.linkNotGenerated")
    }
}

/// Receiver mode of `subpackageRoam/session?shareToken=`: anonymous read of the coarse snapshot.
/// Without a reviewed reader the page states that it cannot open shared footprints.
@MainActor struct RoamSharedFootprintView: View {
    let token: String
    let reader: (any RoamShareSnapshotReading)?
    var onOpenRoam: (() -> Void)? = nil
    @State private var outcome: RoamShareSnapshotOutcome?
    @State private var generation = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch outcome {
                case nil:
                    CYSkeleton().accessibilityLabel(Text("roamSub.w208.shared.loading"))
                        .accessibilityIdentifier("roamSub.w208.shared.loading")
                case .error?:
                    // MP session shared error: 这条足迹无法打开 + 重试, no sub line.
                    CYEmptyState(systemImage: "wifi.exclamationmark", "roamSub.w208.shared.errorTitle",
                                 actionTitle: "roamSub.w208.shared.retry", actionIdentifier: "roamSub.w208.shared.retry",
                                 action: { Task { await load() } })
                        .accessibilityIdentifier("roamSub.w208.shared.error")
                case .gone?:
                    CYEmptyState(systemImage: "eye.slash", "roamSub.w208.shared.goneTitle",
                                 detail: "roamSub.w208.shared.goneHint",
                                 actionTitle: onOpenRoam == nil ? nil : "roamSub.w208.shared.goRoam",
                                 action: onOpenRoam)
                        .accessibilityIdentifier("roamSub.w208.shared.gone")
                case .unavailable?:
                    CYEmptyState(systemImage: "lock", "roamSub.w208.shared.unavailable",
                                 detail: "roamSub.w208.shared.unavailableHint")
                        .accessibilityIdentifier("roamSub.w208.shared.unavailable")
                case .ready(let snapshot)?:
                    snapshotCard(snapshot)
                }
            }.padding()
        }.navigationTitle(Text("roamSub.w208.session.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task(id: token) { await load() }
        .cyDomainScreen(.player)
    }
    private func snapshotCard(_ snapshot: RoamShareSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: snapshot.routeName).cyText(.sheetTitle).accessibilityAddTraits(.isHeader).accessibilityIdentifier("roamSub.w208.shared.routeName")
            Text("roamSub.w208.session.completeFact")
            HStack(spacing: 4) {
                Text(Date(timeIntervalSince1970: Double(snapshot.ts) / 1000), format: .dateTime.month().day().weekday(.abbreviated))
                Text(verbatim: "· " + snapshot.time)
            }.foregroundStyle(.secondary).accessibilityElement(children: .combine)
            HStack(spacing: 20) {
                metric(snapshot.distance.map { String(format: "%.1f", $0) } ?? "—", Text("roamSub.w208.history.km"))
                metric(snapshot.explorePct.map { "\(Int($0))%" } ?? "--%", Text("roamSub.w208.share.explore"))
                metric(snapshot.shops.map(String.init) ?? "—", Text("roamSub.w208.share.lit"))
            }
            if snapshot.track.count < 2 { Text("roamSub.w208.shared.noTrack").cyText(.meta).foregroundStyle(.secondary) }
            ForEach(Array(snapshot.pois.enumerated()), id: \.offset) { _, place in
                Label { Text(verbatim: place.name) } icon: { Image(systemName: place.cat == "merchant" ? "storefront" : "mappin") }
            }
            Text("roamSub.w208.share.brand").cyText(.meta, weight: .semibold).foregroundStyle(.secondary)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("roamSub.w208.shared.card")
    }
    private func metric(_ value: String, _ label: Text) -> some View {
        VStack(alignment: .leading) { Text(verbatim: value).cyText(.cardTitle, monospacedDigit: true); label.cyText(.caption).foregroundStyle(.secondary) }
            .accessibilityElement(children: .combine)
    }
    private func load() async {
        generation += 1; let ticket = generation
        guard let parsed = RoamShareToken(token) else { outcome = .gone; return }
        guard let reader else { outcome = .unavailable; return }
        outcome = nil
        let result = await reader.snapshot(parsed)
        guard ticket == generation, !Task.isCancelled else { return }
        outcome = result
    }
}

/// `scene-roam-poi-detail` node card. Favorite, interaction and completion are writes and stay
/// read-only labels here; 出示核销码 only opens the existing approval-gated voucher view.
@MainActor struct RoamPOINodeParityCard: View {
    let node: RoamNodeDetail
    var stampDestination: (() -> AnyView)? = nil
    /// RPOI-2: false when the 我的进度 action row already carries the favorite toggle, so the state shows once.
    var showsFavorite = true
    var body: some View {
        let card = RoamPOINodePresentation(node)
        VStack(alignment: .leading, spacing: 10) {
            Text("roamSub.w208.poi.badge").cyText(.meta, weight: .semibold).foregroundStyle(.tint)
            if let title = node.templateTitle { Text(verbatim: title).cyText(.cardTitle) }
            else if !node.name.isEmpty { Text(verbatim: node.name).cyText(.cardTitle) }
            else { Text("roamSub.w208.poi.taskUnknown").cyText(.cardTitle) }
            if card.offline {
                Text(LocalizedStringKey(card.offlineKeepsVoucher ? "roamSub.w208.poi.offlineVoucher" : "roamSub.w208.poi.offline"))
                    .cyText(.bodyCompact).foregroundStyle(.secondary).accessibilityIdentifier("roamSub.w208.poi.offline")
            }
            HStack(spacing: 0) {
                Text(LocalizedStringKey(card.validationKey))
                if card.grantsCoupon { Text("roamSub.w208.poi.coupon") }
            }.cyText(.bodyCompact).accessibilityElement(children: .combine).accessibilityIdentifier("roamSub.w208.poi.method")
            if showsFavorite {
                Label(LocalizedStringKey(node.favorited ? "roamSub.w208.poi.favorited" : "roamSub.w208.poi.favorite"), systemImage: node.favorited ? "heart.fill" : "heart")
                    .cyText(.bodyCompact).foregroundStyle(.secondary).accessibilityIdentifier("roamSub.w208.poi.favoriteState")
            }
            if node.coordinate == nil { Label("roamSub.w208.poi.noNavigation", systemImage: "location.slash").cyText(.bodyCompact).foregroundStyle(.secondary) }
            // 投一张 is hidden: this card has no stamp-exchange coordinator to send with, so the
            // flow could only end on a disabled send button.
            if card.primary == .showVoucher {
                NavigationLink { RoamCityVoucherCodeView(poiID: node.poiId, name: node.name) } label: {
                    Label(LocalizedStringKey(card.primaryKey), systemImage: "qrcode")
                }.buttonStyle(.questifyPrimary).frame(minHeight: 44)
                    .accessibilityIdentifier("roamSub.w208.poi.primary")
            } else if card.primary != .interact {
                // Completed / pending states are status, not an action.
                Label(LocalizedStringKey(card.primaryKey), systemImage: card.primary == .completed ? "checkmark.seal" : "lock")
                    .cyText(.bodyMedium).foregroundStyle(.secondary)
                    .accessibilityIdentifier("roamSub.w208.poi.primary")
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("roamSub.w208.poi.node")
    }
}

/// 据点未开放或已下线 (HTTP/business 410). Not retryable.
struct RoamPOIUnavailableView: View {
    var onBack: (() -> Void)? = nil
    var body: some View {
        // MP scene-roam-poi-detail `unavailable`: 节点未开放或已下线 + 返回地图, no sub line.
        CYEmptyState(systemImage: "mappin.slash", "roamSub.w208.poi.unavailable",
                     actionTitle: onBack == nil ? nil : "roamSub.w208.poi.backToMap", action: onBack)
            .accessibilityIdentifier("roamSub.w208.poi.unavailable")
    }
}

/// 找不到这个据点: the entry carried no poiId, so a retry cannot help.
struct RoamPOIMissingView: View {
    var onBack: (() -> Void)? = nil
    var body: some View {
        // MP scene-roam-poi-detail `empty`: missing-param (info glyph), 找不到这个节点 + 返回地图, no sub line.
        CYEmptyState(systemImage: "info.circle", "roamSub.w208.poi.missing",
                     actionTitle: onBack == nil ? nil : "roamSub.w208.poi.backToMap", action: onBack)
            .accessibilityIdentifier("roamSub.w208.poi.missing")
    }
}

/// `subpackageRoam/citynode-code`: opened from a known city node, the code is requested on appear
/// (still behind the existing VerificationCodeApproval). A missing poiId has no retry.
@MainActor struct RoamCityVoucherCodeView: View {
    let poiID: Int?
    var name: String? = nil
    @Environment(\.verificationCodeFactory) private var codeFactory
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        if let poiID, poiID > 0 {
            if let codeFactory {
                VerificationCodeView(model: codeFactory(.init(kind: .cityVoucher, id: poiID)),
                                     title: RoamCityVoucherCopy.displayName(name), autoIssue: true)
            } else {
                CYEmptyState(systemImage: "lock", "roamSub.w208.voucher.disabled",
                             detail: "roamSub.w208.voucher.desc")
                    .accessibilityIdentifier("roamSub.w208.voucher.disabled")
            }
        } else {
            // Mini-program missing-param shell: one line and 返回, no extra hint.
            CYEmptyState(systemImage: "info.circle", "roamSub.w208.voucher.missing",
                         actionTitle: "roamSub.w208.voucher.back", actionIdentifier: "roamSub.w208.voucher.back",
                         action: { dismiss() })
                .accessibilityIdentifier("roamSub.w208.voucher.missing")
        }
    }
}

/// `subpackageRoam/citystamp` write step. The photo comes from the existing stamp camera; posting
/// and exchanging run only through RoamStampExchangeCoordinator, which stays dormant until its
/// executor is approved. A receipt (live or DEBUG fixture) moves to the print slip.
@MainActor struct RoamCityStampFlowView: View {
    let kind: String?
    let place: String?
    var cameraDestination: (() -> AnyView)? = nil
    var exchange: RoamStampExchangeCoordinator? = nil
    var draft: RoamStampExchangeDraft? = nil
    var fixtureReceipt: RoamStampExchangeReceipt? = nil
    @State private var note = ""
    @State private var receipt: RoamStampExchangeReceipt?
    @State private var working = false
    @State private var failed = false
    private let openedAt = Date()
    private var placeText: Text { place.map { Text(verbatim: $0) } ?? Text("roamSub.w208.stamp.defaultPlace") }
    private var canSend: Bool { exchange != nil && draft != nil && !working }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // RSTAMP-5: the kind title is the inline nav title only; the content keeps the `date · place` line.
                HStack(spacing: 4) { Text(verbatim: RoamStampSlip.dateLabel(openedAt) + " ·"); placeText }
                    .cyText(.meta).foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("roamSub.w208.stamp.header")
                if let receipt { RoamStampSlipView(slip: RoamStampSlip(receipt), place: placeText, openedAt: openedAt) }
                else { writeStep }
            }.padding()
        }.navigationTitle(Text(LocalizedStringKey(RoamStampSlip.titleKey(kind: kind))))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("roamSub.w208.stamp.flow")
        .cyDomainScreen(.player)
    }
    private var writeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("roamSub.w208.stamp.noteHeader").cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                Spacer()
                Text(verbatim: "\(note.count)/\(RoamStampSlip.captionLimit)").cyText(.meta, monospacedDigit: true)
                    .accessibilityIdentifier("roamSub.w208.stamp.counter")
            }
            TextField("roamSub.w208.stamp.placeholder", text: $note, axis: .vertical)
                .lineLimit(2...4).textFieldStyle(.roundedBorder)
                .onChange(of: note) { _, value in if value.count > RoamStampSlip.captionLimit { note = String(value.prefix(RoamStampSlip.captionLimit)) } }
                .accessibilityIdentifier("roamSub.w208.stamp.note")
            NavigationLink { if let cameraDestination { cameraDestination() } else { RoamStampCameraView() } } label: {
                Label("roamSub.w208.stamp.takePhoto", systemImage: "camera")
            }.frame(minHeight: 44).accessibilityIdentifier("roamSub.w208.stamp.takePhoto")
            // MP citystamp send step: the mailbox photo (`subpackageRoam/citystamp/mailbox.png`) above 投进信箱.
            MPAsset.Other.mailbox.resizable().scaledToFit().frame(maxWidth: 200)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            Button {
                Task { await send() }
            } label: { Text(LocalizedStringKey(working ? "roamSub.w208.stamp.sending" : "roamSub.w208.stamp.send")).frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.questifyPrimary).disabled(!canSend && fixtureReceipt == nil)
                .accessibilityIdentifier("roamSub.w208.stamp.send")
            if failed { Text("roamSub.w208.stamp.retry").cyText(.bodyCompact).foregroundStyle(.red).accessibilityIdentifier("roamSub.w208.stamp.failed") }
            if exchange == nil && fixtureReceipt == nil && !RoamExperienceCapabilities.stampExchange {
                Text("roamSub.w208.stamp.dormant").cyText(.meta).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("roamSub.w208.stamp.dormant")
            }
        }
    }
    private func send() async {
        if let fixtureReceipt { receipt = fixtureReceipt; return }
        guard let exchange, let draft, !working else { return }
        working = true; failed = false
        defer { working = false }
        await exchange.submitOrRetry(draft)
        switch exchange.phase {
        case .exchanged, .noExchange: receipt = exchange.receipt
        case .unavailable: failed = false
        default: failed = true
        }
    }
}

/// Print step: slip fields, deterministic bars, tear (drag ≥ 80 pt) and scratch reveal. Reduce
/// Motion and VoiceOver get plain buttons; 收下，出发 stays locked until the caption is revealed.
@MainActor struct RoamStampSlipView: View {
    let slip: RoamStampSlip
    let place: Text
    let openedAt: Date
    @Environment(\.dismiss) private var dismiss
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var torn = false
    @State private var pull: CGFloat = 0
    @State private var scratched: CGFloat = 0
    @State private var revealed = false
    private static let tearDistance: CGFloat = 80
    private static let scratchNeeded: CGFloat = 600
    private var plainControls: Bool { reduceMotion || voiceOver }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // N-r11-4: no printer art over the slip; the stamp photo stays.
            if !slip.got {
                VStack(alignment: .leading, spacing: 6) {
                    if let reason = slip.reason { Text(verbatim: reason).cyText(.cardTitle) }
                    else { Text("roamSub.w208.stamp.noTicket").cyText(.cardTitle) }
                    Text("roamSub.w208.stamp.noTicketHint").foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("roamSub.w208.stamp.noExchange")
            } else {
                paper.offset(y: torn ? 0 : pull)
                    .gesture(DragGesture().onChanged { value in
                        guard !torn, !plainControls else { return }
                        pull = max(0, value.translation.height)
                    }.onEnded { _ in
                        guard !torn else { return }
                        if pull >= Self.tearDistance { torn = true }
                        withAnimation(reduceMotion ? nil : .spring) { pull = 0 }
                    })
                if !torn {
                    Text("roamSub.w208.stamp.tearHint").cyText(.bodyCompact).foregroundStyle(.secondary)
                    if plainControls {
                        Button("roamSub.w208.stamp.tear") { torn = true }.accessibilityIdentifier("roamSub.w208.stamp.tear")
                    }
                } else if !revealed {
                    Text("roamSub.w208.stamp.scratchHint").cyText(.bodyCompact).foregroundStyle(.secondary)
                    Button("roamSub.w208.stamp.scratch") { revealed = true }.accessibilityIdentifier("roamSub.w208.stamp.scratch")
                } else {
                    Text("roamSub.w208.stamp.takeHint").cyText(.bodyCompact).foregroundStyle(.secondary)
                }
            }
            Button {
                dismiss()
            } label: { Text("roamSub.w208.stamp.done").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.questifyPrimary).disabled(slip.got && !revealed)
                .accessibilityIdentifier("roamSub.w208.stamp.done")
            if slip.got && !revealed { Text("roamSub.w208.stamp.revealFirst").cyText(.meta).foregroundStyle(.secondary) }
        }
    }
    private var paper: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("roamSub.w208.stamp.departure").cyText(.caption).foregroundStyle(.secondary)
                    place.cyText(.cardTitle)
                    Text(openedAt, format: .dateTime.hour().minute()).cyText(.meta)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("roamSub.w208.stamp.serialLabel").cyText(.caption).foregroundStyle(.secondary)
                    // MP .sgslip__od-r: 签号 + the number only.
                    Text(verbatim: slip.serial).cyText(.sectionTitle, monospacedDigit: true).accessibilityIdentifier("roamSub.w208.stamp.serial")
                }
            }
            Divider()
            HStack {
                VStack(alignment: .leading) { Text("roamSub.w208.stamp.leftBy").cyText(.caption).foregroundStyle(.secondary); Text("roamSub.w208.stamp.someone").cyText(.meta) }
                Spacer()
                VStack(alignment: .leading) {
                    Text("roamSub.w208.stamp.leftAt").cyText(.caption).foregroundStyle(.secondary)
                    Text(verbatim: slip.leftAt ?? "—").cyText(.meta, monospacedDigit: true)
                }
            }
            Divider()
            if RoamStampSlipPhotoPort.shouldShowPhotoBlock(got: slip.got) {
                RoamStampSlipPhotoView(pictureURL: slip.pictureURL)
                RoamStampSlipSaveRow(torn: torn, pictureURL: slip.pictureURL)
                Divider()
            }
            Text("roamSub.w208.stamp.forYou").cyText(.caption).foregroundStyle(.secondary)
            ZStack {
                Group {
                    if let caption = slip.caption { Text(verbatim: caption) } else { Text("roamSub.w208.stamp.noCaption") }
                }.cyText(.body).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityHidden(!revealed)
                    .accessibilityIdentifier("roamSub.w208.stamp.caption")
                if !revealed {
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(max(0.15, 1 - Double(scratched / Self.scratchNeeded))))
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            guard torn, !plainControls else { return }
                            scratched += abs(value.translation.width) / 8 + abs(value.translation.height) / 8
                            if scratched >= Self.scratchNeeded * 0.6 { revealed = true }
                        })
                        .accessibilityHidden(true)
                }
            }
            // N-r11-4: the decorative barcode strip is gone (`RoamStampSlip.bars` stays for the slip model).
        }.padding().background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain).accessibilityIdentifier("roamSub.w208.stamp.slip")
    }
}

/// `citynode-code` title (node name, default 据点). 出示给商家扫码,即可领取优惠券 sits under the code in VerificationCodeView.
/// Exchanged stamp photo on the city-stamp print slip (mini-program `sgslip__photo`).
/// Reuses the album card's remote-image rule; strings are existing keys.
/// MP citystamp `.sgprinter`: brushed-silver body (`printer-body.jpg`) with the paper slot (`printer-slot.jpg`);
/// after the tear a stub of paper stays in the slot. Sizes are the MP rpx values at 750 rpx = 375 pt. Decoration only.
struct RoamStampPrinterView: View {
    let torn: Bool
    var body: some View {
        ZStack(alignment: .top) {
            MPAsset.Other.printerBody.resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: 63.5).clipped()
            MPAsset.Other.printerSlot.resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: 14.5).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.horizontal, 15.5).padding(.top, 24)
            if torn {
                Rectangle().fill(Color.white).frame(height: 6.5)
                    .padding(.horizontal, 19).padding(.top, 31.5)
            }
        }
        .frame(height: 63.5)
        .clipShape(RoundedRectangle(cornerRadius: 12.5, style: .continuous))
        // N-RSTAMP (r10): no drop shadow under the printer art.
        .accessibilityHidden(true)
    }
}

struct RoamStampSlipPhotoView: View {
    let pictureURL: String?
    var body: some View {
        Group {
            if let url = RoamStampSlipPhotoPort.displayURL(pictureURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else if phase.error != nil { Label("roam.experience.imageUnavailable", systemImage: "photo.badge.exclamationmark") }
                    else { CYSkeleton().accessibilityLabel(Text("roam.loading")) }
                }
            } else {
                Label("roam.experience.imageUnavailable", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(Text("roam.experience.stampImage"))
        .accessibilityIdentifier("roamSub.w208.stamp.photo")
    }
}
