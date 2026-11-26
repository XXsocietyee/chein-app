import SwiftUI

/// Real-data consumer only. No fixture, transport, factory, or production entry is installed here.
@MainActor struct FreeExploreBundleLaunchView: View {
    @Bindable var model: FreeExploreBundleLaunchModel
    @State private var unitID: FreeExploreLaunchID?
    @State private var offerID: FreeExploreLaunchID?
    @State private var date = Date()
    @Environment(\.locale) private var locale
    private let table = "FreeExploreBundleLaunch"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    private func chapterName(_ id: FreeExploreLaunchID) -> String? { model.catalog?.items.first(where: { $0.chapterId == id })?.name }
    /// MKT-7-7: the review sheet names the chapter and the store; ids stay off screen ("—" when unknown).
    private func unitName(_ id: FreeExploreLaunchID) -> String {
        model.order?.bundle?.units.first(where: { $0.id == id }).flatMap { chapterName($0.chapterId) } ?? "—"
    }
    private func storeName(_ id: FreeExploreLaunchID) -> String {
        model.catalog?.items.lazy.flatMap(\.stores).first(where: { $0.offerId == id })?.merchantName ?? "—"
    }
    /// MP `featureOff`: the read failed with `businessCode == "BUNDLE_LEDGER_OFF"` (free-explore/index.js:97).
    private var ledgerOff: Bool {
        if case .response(_, _, let businessCode, _)? = model.failure { return businessCode == "BUNDLE_LEDGER_OFF" }
        return false
    }
    /// R8-MEM-7-3: MP free-explore/index.js:97 `res.msg || '权益加载失败，请重试'`: the server message first, then the fixed copy.
    private var errorText: Text {
        if case .response(_, _, _, let message)? = model.failure, let message, !message.isEmpty { return Text(verbatim: message) }
        return text("error")
    }
    /// Menu-picker row inside a card: label left, current choice right, 48pt tall.
    private func choice<P: View>(_ label: Text, selected: String?, @ViewBuilder picker: () -> P) -> some View {
        HStack {
            label.cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
            Spacer(minLength: CYSpacing.sm)
            picker().labelsHidden().tint(CYColor.textSecondary)
        }.frame(minHeight: 48)
    }
    /// Page model for `subpackageMember/free-explore/index`. Unknown money is an em dash, never 0.
    private var screen: FreeExploreBundlePageReady.Screen {
        let lane: FreeExploreBundlePageReady.Lane
        switch model.state {
        case .idle: lane = model.busy ? .loading : .idle
        case .loading: lane = .loading
        case .outcomeUnknown: lane = .outcomeUnknown
        case .confirmed: lane = model.busy ? .loading : .confirmed
        case .staleSession: lane = .staleSession
        }
        let kept: FreeExploreBundlePageReady.Snapshot? = (model.catalog == nil && model.order == nil)
            ? nil : .init(catalog: model.catalog, order: model.order)
        return FreeExploreBundlePageReady.screen(state: lane, failed: model.failure != nil, linkMissing: false, kept: kept)
    }
    var body: some View {
        let screen = self.screen
        return CYCardPage {
            CYArtCoverHeader(title: text("title"), symbol: "shippingbox.fill", seed: "bundle") {
                if let units = model.order?.bundle?.units.filter({ $0.status == "AVAILABLE" }).count, units > 0 {
                    Label { Text(verbatim: ChannelCopy.text("\(units) 个章节可预约", "\(units) chapters ready to book", locale: locale)) } icon: { Image(systemName: "ticket.fill") }
                        .cyText(.meta, weight: .semibold).foregroundStyle(.white)
                        .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                        .background(CYColor.bgOverlay, in: Capsule())
                }
            }
        } content: {
            switch screen {
            case .error(.stale):
                CYEmptyState(systemImage: "clock.arrow.circlepath", LocalizedStringKey("stale"), tableName: table)
            case .loading:
                CYLoadingStateView(rows: 2)
                    .accessibilityIdentifier("freeBundle.loading")
            case .empty:
                CYEmptyState(systemImage: "tray", LocalizedStringKey("empty"), tableName: table)
                    .accessibilityIdentifier("freeBundle.empty")
            case .error(.load):
                Label { errorText } icon: { Image(systemName: "exclamationmark.triangle") }.accessibilityIdentifier("freeBundle.error")
                // R7-MEM-7-2 (MP R11 F-7): with the bundle ledger switched off a refresh cannot change anything, so 刷新 is hidden.
                if !ledgerOff {
                    CYPillButton(LocalizedStringKey("retry"), style: .tertiary, tableName: table) { Task { await model.load() } }
                        .disabled(model.busy).accessibilityIdentifier("freeBundle.reload")
                }
            case .unknown:
                if model.state == .outcomeUnknown {
                    CYInfoCard(title: text("unknown"), symbol: "clock.badge.questionmark") {
                        CYPillButton(LocalizedStringKey("recover"), style: .primary, tableName: table) { Task { await model.recover() } }.disabled(model.busy)
                        CYPillButton(LocalizedStringKey("retry"), style: .tertiary, tableName: table) { Task { await model.retryOriginal() } }.disabled(!model.canRetry)
                    }
                } else {
                    // Nothing has arrived yet: not an empty shelf and not a price of 0.
                    CYLoadingStateView(rows: 2)
                }
            case .ready(let facts):
                readyContent(facts)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .cyPushedChrome(domain: .player)
        .navigationTitle(text("title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task { await model.load() }
        .refreshable { await model.load() }
        .onChange(of: unitID) { _, _ in offerID = nil; model.cancelReview() }
        .onChange(of: offerID) { _, _ in model.cancelReview() }
        .onChange(of: date) { _, _ in model.cancelReview() }
        .sheet(item: Binding(get: { model.review }, set: { if $0 == nil { model.cancelReview() } })) { review in
            NavigationStack {
                Form {
                    text("notice")
                    LabeledContent { Text(verbatim: model.order?.registrationNo ?? "—").monospacedDigit() } label: { text("order") }
                    LabeledContent { Text(verbatim: unitName(review.command.unitId)) } label: { text("unit") }
                    LabeledContent { Text(verbatim: storeName(review.command.offerId)) } label: { text("offer") }
                    LabeledContent {
                        Text(Date(timeIntervalSince1970: Double(review.command.startAt) / 1_000), style: .date)
                        Text(Date(timeIntervalSince1970: Double(review.command.startAt) / 1_000), style: .time)
                    } label: { text("date") }
                    CYPillButton(LocalizedStringKey("confirm"), style: .primary, tableName: table) { Task { await model.confirm(review) } }
                        .disabled(!model.canReserve).listRowBackground(Color.clear)
                    CYPillButton(LocalizedStringKey("cancel"), style: .tertiary, tableName: table) { model.cancelReview() }
                        .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .cyDomainScreen(.player)
                .navigationTitle(text("review")).navigationBarTitleDisplayMode(.inline)
            }
            .cyDomainSheet(detents: [.half, .full])
        }
        // A reopened destination must receive a fresh model from its authorized host.
        .onDisappear { model.cancelReview() }
    }
    @ViewBuilder private func readyContent(_ facts: FreeExploreBundlePageReady.Facts) -> some View {
        if facts.refreshing { CYLoadingStateView(rows: 2) }
        if facts.refreshFailed {
            // A failed refresh keeps the last record on screen instead of zeroing it.
            Label { errorText } icon: { Image(systemName: "exclamationmark.triangle") }.accessibilityIdentifier("freeBundle.error")
        }
        if facts.saleEnabled == nil {
            CYNoteBanner(text: text("saleUnknown"), symbol: "questionmark.circle", tone: .info)
                .accessibilityIdentifier("freeBundle.saleUnknown")
        }
        if model.state == .confirmed {
            CYNoteBanner(text: text("confirmed"), symbol: "checkmark.seal.fill", tone: .success)
        }
        if model.order?.bundle != nil {
            CYStepIndicator(titles: [ChannelCopy.text("选章节", "Chapter", locale: locale), ChannelCopy.text("选商家", "Store", locale: locale),
                                     ChannelCopy.text("定时间", "Time", locale: locale)], current: unitID == nil ? 0 : offerID == nil ? 1 : 2)
                .padding(.horizontal, CYSpacing.xs)
        }
        if let order = model.order, let bundle = order.bundle {
            CYInfoCard {
                // Chapters as selectable ticket rows (one tap, haptic) instead of two collapsed menus; the Review pill stays the only primary action.
                Text("unit", tableName: table).cyText(.meta, weight: .semibold).foregroundStyle(CYColor.textSecondary)
                ForEach(bundle.units.filter { $0.status == "AVAILABLE" }, id: \.id) { unit in
                    CYChoiceRow(label: chapterName(unit.chapterId) ?? unit.id.text, selected: unitID == unit.id) {
                        if unitID != unit.id { offerID = nil }
                        unitID = unit.id
                    }
                }
                if let unit = bundle.units.first(where: { $0.id == unitID }),
                   let item = model.catalog?.items.first(where: { $0.chapterId == unit.chapterId }) {
                    Text("offer", tableName: table).cyText(.meta, weight: .semibold).foregroundStyle(CYColor.textSecondary)
                    ForEach(item.stores, id: \.offerId) { store in
                        CYChoiceRow(label: store.merchantName ?? store.offerId.text, selected: offerID == store.offerId) { offerID = store.offerId }
                    }
                }
                DatePicker(selection: $date, in: Date()...) { text("date").cyText(.bodyCompact) }
                CYPillButton(LocalizedStringKey("review"), style: .primary, tableName: table) {
                    guard let unitID, let offerID else { return }
                    let millis = date.timeIntervalSince1970 * 1_000
                    guard millis.isFinite, millis > 0, millis < Double(Int64.max) else { return }
                    model.prepare(unitID: unitID, offerID: offerID, startAt: Int64(millis))
                }
                .disabled(!model.canReserve || unitID == nil || offerID == nil)
                if !model.canReserve { text("disabled").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
            // MKT-7-3: every unit with its MP status (`{chapter} · {statusText}`), chapter content, and 有效期至.
            if !bundle.units.isEmpty {
                CYInfoCard(title: Text("freeBundle.units.title"), symbol: "square.stack.3d.up") {
                    ForEach(Array(bundle.units.enumerated()), id: \.element.id) { index, unit in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            HStack(spacing: CYSpacing.xs) {
                                Text(verbatim: chapterName(unit.chapterId) ?? appLocalized("freeBundle.unit.fallback \(index + 1)", locale: locale))
                                Text(verbatim: "·")
                                Self.statusText(unit.status)
                            }
                            .cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .accessibilityElement(children: .combine)
                            let content = bundle.chapterContent(chapterID: unit.chapterId).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                Text(verbatim: content)
                                    .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityIdentifier("freeBundle.unit.content.\(unit.id.text)")
                            }
                            if let validTo = unit.validTo?.trimmingCharacters(in: .whitespacesAndNewlines), !validTo.isEmpty {
                                Text("unit.validTo \(validTo)", tableName: table)
                                    .cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textSecondary)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .accessibilityIdentifier("freeBundle.unit.validTo.\(unit.id.text)")
                            }
                        }
                        .accessibilityIdentifier("freeBundle.unit.\(unit.id.text)")
                    }
                }
            }
            // MKT-7-3: refund hold is a status card. It does not start a refund.
            if let hold = bundle.refundHold, let title = Self.refundHoldTitle(hold.state) {
                CYInfoCard {
                    title
                        .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .accessibilityIdentifier("freeBundle.refundHold")
                }
            }
            // MKT-7-6: the order card always shows (order number, 实付金额); an empty list reads 暂无预约记录.
            CYInfoCard(title: text("order"), symbol: "ticket.fill") {
                // MKT-7-3: MP `支付：{paymentText} · 报名：{registrationText}` under the order number.
                Text("freeBundle.order.statusLine \(Self.paymentText(order.paymentStatus)) \(Self.registrationText(order.registrationStatus))")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("freeBundle.order.statusLine")
                if bundle.reservations.isEmpty {
                    text("reservationsEmpty").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("freeBundle.reservations.empty")
                }
                ForEach(bundle.reservations, id: \.id) { reservation in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        // MP `{shopName || chapterName || 预约} · {statusText}`.
                        CYListRow(verbatim: "\(reservationHeading(reservation, bundle: bundle)) · \(Self.statusString(reservation.status))", meta: Self.startAtText(reservation.startAt, locale: locale), trailing: .none) { CYRowIcon(systemImage: "calendar.badge.checkmark") }
                            .accessibilityIdentifier("freeBundle.reservation.\(reservation.id.text)")
                        // BOOKED only. The labels are the MP copy; this round does not send a cancel.
                        if reservation.canCancel {
                            Text("reservation.cancel", tableName: table)
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .accessibilityIdentifier("freeBundle.reservation.canCancel.\(reservation.id.text)")
                            Text("reservation.monthlyWaiver", tableName: table)
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .accessibilityIdentifier("freeBundle.reservation.waiver.\(reservation.id.text)")
                        }
                    }
                }
                if let number = order.registrationNo { Text(verbatim: number).cyText(.meta).foregroundStyle(CYColor.textTertiary).textSelection(.enabled) }
                LabeledContent { Text(verbatim: facts.paidAmountText).monospacedDigit() } label: { text("paidAmount") }
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("freeBundle.paidAmount")
            }
            if bundle.exitCases.contains(where: { Self.exitCaseTitle($0.decision) != nil }) {
                CYInfoCard(title: Text("exitCases.title", tableName: table)) {
                    ForEach(bundle.exitCases, id: \.id) { item in
                        if let line = Self.exitCaseTitle(item.decision) {
                            line
                                .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .accessibilityIdentifier("freeBundle.exitCase.\(item.id.text)")
                        }
                    }
                }
            }
        } else if model.order != nil { text("legacy").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
        if let catalog = model.catalog {
            CYInfoCard(title: catalog.topicName.map { Text(verbatim: $0) } ?? text("catalog"), symbol: "list.star") {
                // R7-MEM-7-1: MP `暂未开售` note under the topic when the catalog is not on sale.
                if !catalog.saleEnabled {
                    Text("freeBundle.catalog.notOnSale").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("freeBundle.catalog.notOnSale")
                }
                if catalog.items.isEmpty { CYEmptyState(systemImage: "tray", LocalizedStringKey("empty"), tableName: table) }
                ForEach(catalog.items, id: \.chapterId) { item in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        if let name = item.name { Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                        // R7-MEM-7-1: MP `{name} · 每人N次`, 次数待确认 when the server count is not positive.
                        Group {
                            if item.unitsPerHolder > 0 { Text("freeBundle.catalog.unitsPerHolder \(item.unitsPerHolder)") }
                            else { Text("freeBundle.catalog.unitsUnknown") }
                        }
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        if let terms = item.termsMode { Text(verbatim: terms).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                        ForEach(item.stores, id: \.offerId) { store in
                            CYListRow(verbatim: store.merchantName ?? store.offerId.text, meta: store.validEnd, trailing: .none) { CYRowIcon(systemImage: "storefront") }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// MP reservation title: shop name, otherwise the chapter, otherwise 预约.
    private func reservationHeading(_ reservation: FreeExploreLaunchReservation, bundle: FreeExploreLaunchOrder.Bundle) -> String {
        let chapter = bundle.chapters.first { $0.chapterId == reservation.chapterId }?.name
        return Self.reservationHeading(shopName: bundle.shopName(offerID: reservation.offerId), chapterName: chapter, locale: locale)
    }

    static func reservationHeading(shopName: String, chapterName: String?, locale: Locale) -> String {
        let shop = shopName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !shop.isEmpty { return shop }
        let chapter = chapterName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !chapter.isEmpty { return chapter }
        return String(localized: LocalizedStringResource("reservation.untitled", table: "FreeExploreBundleLaunch", locale: locale))
    }

    /// MP `refundHold.text`. An unknown state stays off the card. Nothing here sends a refund.
    static func refundHoldTitle(_ state: String) -> Text? {
        switch state {
        case "PREPARED": return Text("refundHold.PREPARED", tableName: "FreeExploreBundleLaunch")
        case "BOUND": return Text("refundHold.BOUND", tableName: "FreeExploreBundleLaunch")
        case "APPROVED": return Text("refundHold.APPROVED", tableName: "FreeExploreBundleLaunch")
        case "SUCCEEDED": return Text("refundHold.SUCCEEDED", tableName: "FreeExploreBundleLaunch")
        case "ZERO_CASH_COMPLETED": return Text("refundHold.ZERO_CASH_COMPLETED", tableName: "FreeExploreBundleLaunch")
        case "REJECTED_HELD": return Text("refundHold.REJECTED_HELD", tableName: "FreeExploreBundleLaunch")
        case "MANUAL_REVIEW_HELD": return Text("refundHold.MANUAL_REVIEW_HELD", tableName: "FreeExploreBundleLaunch")
        case "RECONCILIATION_REQUIRED": return Text("refundHold.RECONCILIATION_REQUIRED", tableName: "FreeExploreBundleLaunch")
        default: return nil
        }
    }

    /// MP exit-case line. Unknown decisions stay off the 售后记录 card. Nothing here sends a refund.
    static func exitCaseTitle(_ decision: String) -> Text? {
        switch decision {
        case "SWAP_CONSENTED": return Text("exitCase.SWAP_CONSENTED", tableName: "FreeExploreBundleLaunch")
        case "REFUND_UNFULFILLED": return Text("exitCase.REFUND_UNFULFILLED", tableName: "FreeExploreBundleLaunch")
        default: return nil
        }
    }

    /// MP `free-explore-bundle.js` STATES (units and reservations share one table). Unknown is an em dash.
    private static let knownStatuses: Set<String> = ["AVAILABLE", "RESERVED", "REDEEMED", "FORFEITED", "HELD", "REFUND_PENDING",
        "REFUNDED", "BOOKED", "CANCELLED", "WAIVED", "LATE_CANCELLED", "NO_SHOW", "FULFILLED", "MERCHANT_EXITED"]
    /// MKT-7-3: MP free-explore-bundle.js:20 shows `String(row.startAt)`. Epoch milliseconds become a China-time
    /// date and time; any other text stays as the server sent it.
    static func startAtText(_ raw: String, locale: Locale) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isASCII), trimmed.allSatisfy(\.isNumber),
              let millis = Int64(trimmed), millis > 0 else { return trimmed.isEmpty ? "—" : trimmed }
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)
        if let zone = TimeZone(identifier: "Asia/Shanghai") { style.timeZone = zone }
        return Date(timeIntervalSince1970: Double(millis) / 1_000).formatted(style)
    }
    static func statusString(_ raw: String) -> String {
        knownStatuses.contains(raw) ? String(localized: String.LocalizationValue("freeBundle.status." + raw)) : "—"
    }
    static func statusText(_ raw: String) -> Text { Text(verbatim: statusString(raw)) }
    /// MP `paymentText`: 0 待支付 · 1 支付中 · 2 已支付 · 3 支付失败 · 4 已退款, else 支付状态确认中.
    static func paymentText(_ status: Int?) -> String {
        guard let status, (0...4).contains(status) else { return appLocalized("freeBundle.payment.unknown", locale: Locale.current) }
        return String(localized: String.LocalizationValue("freeBundle.payment." + String(status)))
    }
    /// MP `registrationText`: 1 待支付 · 2 报名成功 · 3 已取消 · 4 已过期, else 报名状态确认中.
    static func registrationText(_ status: Int?) -> String {
        guard let status, (1...4).contains(status) else { return appLocalized("freeBundle.registration.unknown", locale: Locale.current) }
        return String(localized: String.LocalizationValue("freeBundle.registration." + String(status)))
    }
}
