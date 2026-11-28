import SwiftUI

/// Real-data consumer only. No fixture, transport, factory, or production entry is installed here.
@MainActor struct FreeExploreBundleLaunchView: View {
    @Bindable var model: FreeExploreBundleLaunchModel
    /// MKT-7-3b: the authorized read host. With it the page offers the MP 取消预约 / 更换商家 / 商家评价;
    /// without it (fixtures, the participation-detail mount) the page stays read-only.
    var host: FreeExploreBundleReadHost? = nil
    @State private var bundleAction: FreeExploreBundleAction?
    @Environment(\.bundleCommerceBaseURL) private var bundleBaseURL
    /// Same gate as the 套餐 hub (`BundleCommerceCatalog.shows`): the route must be admitted and not forced off.
    private func offers(_ entry: BundleCommerceEntry) -> Bool {
        host?.current == true && BundleCommerceCatalog.shows(entry, baseURL: bundleBaseURL)
    }
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
    /// NAT-9 (native-r2): MP free-explore/index.wxml as an inset-grouped `List`. Each MP `cy-card` is a `Section`,
    /// chapter / store choices are `Picker`s, the step indicator is the section header and notes are labelled rows.
    var body: some View {
        let screen = self.screen
        return List {
            switch screen {
            case .error(.stale):
                CYEmptyState(systemImage: "clock.arrow.circlepath", LocalizedStringKey("stale"), tableName: table)
            case .loading:
                CYLoadingState(messageIdentifier: "freeBundle.loading")
            case .empty:
                CYEmptyState(systemImage: "tray", LocalizedStringKey("empty"), tableName: table)
                    .accessibilityIdentifier("freeBundle.empty")
            case .error(.load):
                Section {
                    Label { errorText } icon: { Image(systemName: "exclamationmark.triangle") }.accessibilityIdentifier("freeBundle.error")
                    // R7-MEM-7-2 (MP R11 F-7): with the bundle ledger switched off a refresh cannot change anything, so 刷新 is hidden.
                    if !ledgerOff {
                        Button { Task { await model.load() } } label: { text("retry") }
                            .disabled(model.busy).accessibilityIdentifier("freeBundle.reload")
                    }
                }
            case .unknown:
                if model.state == .outcomeUnknown {
                    Section {
                        Button { Task { await model.recover() } } label: { text("recover") }.disabled(model.busy)
                        Button { Task { await model.retryOriginal() } } label: { text("retry") }.disabled(!model.canRetry)
                    } header: {
                        text("unknown")
                    }
                } else {
                    // Nothing has arrived yet: not an empty shelf and not a price of 0.
                    ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
                }
            case .ready(let facts):
                readyContent(facts)
            }
        }
        .listStyle(.insetGrouped)
        .cyPushedChrome(domain: .player)
        .navigationTitle(text("title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task { await model.load() }
        .refreshable { await model.load() }
        .onChange(of: unitID) { _, _ in offerID = nil; model.cancelReview() }
        .onChange(of: offerID) { _, _ in model.cancelReview() }
        .onChange(of: date) { _, _ in model.cancelReview() }
        .cySheet(item: Binding(get: { model.review }, set: { if $0 == nil { model.cancelReview() } })) { review in
            NavigationStack {
                Form {
                    Section {
                        text("notice")
                        LabeledContent { Text(verbatim: model.order?.registrationNo ?? "—").monospacedDigit() } label: { text("order") }
                        LabeledContent { Text(verbatim: unitName(review.command.unitId)) } label: { text("unit") }
                        LabeledContent { Text(verbatim: storeName(review.command.offerId)) } label: { text("offer") }
                        LabeledContent {
                            Text(Date(timeIntervalSince1970: Double(review.command.startAt) / 1_000), style: .date)
                            Text(Date(timeIntervalSince1970: Double(review.command.startAt) / 1_000), style: .time)
                        } label: { text("date") }
                    }
                }
                .navigationTitle(text("review")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { model.cancelReview() } label: { text("cancel") }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { Task { await model.confirm(review) } } label: { text("confirm") }
                            .fontWeight(.semibold)
                            .disabled(!model.canReserve)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // MKT-7-3b: sheets, not pushes, so the read host is not retired while an action is open.
        .cySheet(item: $bundleAction) { action in
            if let host {
                NavigationStack {
                    FreeExploreBundleActionSheet(action: action, host: host, model: model)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("action.done") { bundleAction = nil }
                                    .accessibilityIdentifier("freeBundle.action.done")
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: bundleAction) { old, new in
            // The bundle may have changed (cancel, swap or review); read it again once the sheet closes.
            if old != nil, new == nil { Task { await model.load() } }
        }
        // A reopened destination must receive a fresh model from its authorized host.
        .onDisappear { model.cancelReview() }
    }
    /// NAT-9: the MP step indicator (选章节 → 选商家 → 定时间) as the booking section header.
    private var stepHeader: Text {
        let titles = [ChannelCopy.text("选章节", "Chapter", locale: locale), ChannelCopy.text("选商家", "Store", locale: locale),
                      ChannelCopy.text("定时间", "Time", locale: locale)]
        let current = unitID == nil ? 0 : offerID == nil ? 1 : 2
        return Text(verbatim: "\(current + 1)/\(titles.count) · \(titles[current])")
            .accessibilityLabel(Text("a11y.value.ofTotal \(current + 1) \(titles.count)") + Text(verbatim: ", \(titles[current])"))
    }
    @ViewBuilder private func readyContent(_ facts: FreeExploreBundlePageReady.Facts) -> some View {
        Section {
            if facts.refreshing { ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity) }
            if facts.refreshFailed {
                // A failed refresh keeps the last record on screen instead of zeroing it.
                Label { errorText } icon: { Image(systemName: "exclamationmark.triangle") }.accessibilityIdentifier("freeBundle.error")
            }
            if facts.saleEnabled == nil {
                Label { text("saleUnknown") } icon: { Image(systemName: "questionmark.circle") }
                    .accessibilityIdentifier("freeBundle.saleUnknown")
            }
            if model.state == .confirmed {
                Label { text("confirmed") } icon: { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
            }
        }
        // MP order: the catalog (topic name, 暂未开售, chapter cards with stores) comes before the order.
        if let catalog = model.catalog {
            Section {
                // R7-MEM-7-1: MP `暂未开售` note under the topic when the catalog is not on sale.
                if !catalog.saleEnabled {
                    Text("freeBundle.catalog.notOnSale").font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("freeBundle.catalog.notOnSale")
                }
                if catalog.items.isEmpty { CYEmptyState(systemImage: "tray", LocalizedStringKey("empty"), tableName: table) }
                ForEach(catalog.items, id: \.chapterId) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        if let name = item.name { Text(verbatim: name).font(.headline) }
                        // R7-MEM-7-1: MP `{name} · 每人N次`, 次数待确认 when the server count is not positive.
                        Group {
                            if item.unitsPerHolder > 0 { Text("freeBundle.catalog.unitsPerHolder \(item.unitsPerHolder)") }
                            else { Text("freeBundle.catalog.unitsUnknown") }
                        }
                        .font(.subheadline).foregroundStyle(.secondary)
                        if let terms = item.termsMode { Text(verbatim: terms).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    ForEach(item.stores, id: \.offerId) { store in
                        LabeledContent {
                            if let end = store.validEnd { Text(verbatim: LocaleDisplay.civil(end, locale: locale)).monospacedDigit() }
                        } label: {
                            Label { Text(verbatim: store.merchantName ?? store.offerId.text) } icon: { Image(systemName: "storefront") }
                        }
                    }
                }
            } header: {
                if let name = catalog.topicName { Text(verbatim: name) } else { text("catalog") }
            }
        }
        if let order = model.order, let bundle = order.bundle {
            // MP order: 订单号 · 支付 / 报名 line · refund hold. mp-journey r3 (sweep 21:20): the section is only drawn when it
            // has a row, so a bare 报名记录 header never stands over nothing.
            if Self.orderSectionHasRows(order, paidAmountKnown: facts.paidAmountText != "—") {
            Section {
                if let number = order.registrationNo {
                    Text(verbatim: number).font(.footnote).monospacedDigit().foregroundStyle(.secondary).textSelection(.enabled)
                }
                // mp-journey r3 (sweep 19:15): the MP page has no 实付金额 line; show it only once the amount is known.
                if facts.paidAmountText != "—" {
                    LabeledContent { Text(verbatim: facts.paidAmountText).monospacedDigit() } label: { text("paidAmount") }
                        .accessibilityIdentifier("freeBundle.paidAmount")
                }
                // MKT-7-3: MP `支付：{paymentText} · 报名：{registrationText}` under the order number; mp-journey r3 (sweep 19:15):
                // hidden while neither status has arrived, so "confirming · confirming" never reads as data.
                if order.paymentStatus != nil || order.registrationStatus != nil {
                    Text("freeBundle.order.statusLine \(Self.paymentText(order.paymentStatus)) \(Self.registrationText(order.registrationStatus))")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("freeBundle.order.statusLine")
                }
                // MKT-7-3: refund hold is a status row under the order line (MP order). It does not start a refund.
                if let hold = bundle.refundHold, let title = Self.refundHoldTitle(hold.state) {
                    title.accessibilityIdentifier("freeBundle.refundHold")
                }
            } header: {
                text("order")
            }
            }
            // MKT-7-3: every unit with its MP status (`{chapter} · {statusText}`), chapter content, and 有效期至.
            if !bundle.units.isEmpty {
                Section {
                    ForEach(Array(bundle.units.enumerated()), id: \.element.id) { index, unit in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(verbatim: chapterName(unit.chapterId) ?? appLocalized("freeBundle.unit.fallback \(index + 1)", locale: locale))
                                Text(verbatim: "·")
                                Self.statusText(unit.status)
                            }
                            .accessibilityElement(children: .combine)
                            let content = bundle.chapterContent(chapterID: unit.chapterId).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                Text(verbatim: content)
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .accessibilityIdentifier("freeBundle.unit.content.\(unit.id.text)")
                            }
                            if let validTo = unit.validTo?.trimmingCharacters(in: .whitespacesAndNewlines), !validTo.isEmpty {
                                Text("unit.validTo \(validTo)", tableName: table)
                                    .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                                    .accessibilityIdentifier("freeBundle.unit.validTo.\(unit.id.text)")
                            }
                        }
                        .accessibilityIdentifier("freeBundle.unit.\(unit.id.text)")
                        // MP free-explore/index.wxml:44 更换商家 on RESERVED / AVAILABLE units.
                        if unit.status == "RESERVED" || unit.status == "AVAILABLE", offers(.exitSwap) {
                            Button("freeBundle.action.exitSwap") { bundleAction = .exitSwap }
                                .disabled(model.busy)
                                .accessibilityIdentifier("freeBundle.unit.exitSwap.\(unit.id.text)")
                        }
                    }
                } header: {
                    Text("freeBundle.units.title")
                }
            }
            // MP 预约记录: title, 暂无预约记录 when empty, one card per reservation.
            Section {
                if bundle.reservations.isEmpty {
                    text("reservationsEmpty").foregroundStyle(.secondary)
                        .accessibilityIdentifier("freeBundle.reservations.empty")
                }
                ForEach(bundle.reservations, id: \.id) { reservation in
                    // MP `{shopName || chapterName || 预约} · {statusText}` over the start time.
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "\(reservationHeading(reservation, bundle: bundle)) · \(Self.statusString(reservation.status))")
                            Text(verbatim: Self.startAtText(reservation.startAt, locale: locale))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "calendar.badge.checkmark") }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("freeBundle.reservation.\(reservation.id.text)")
                    // BOOKED only. The cancel goes through the quote → confirm form (BundleCancelView); no refund is sent here.
                    if reservation.canCancel {
                        // MKT-7-3b: MP free-explore/index.wxml:58-61 取消预约 (the waiver is the toggle in the quote form).
                        if offers(.cancel) {
                            Button(role: .destructive) { bundleAction = .cancel(reservation.id) } label: {
                                Text("reservation.cancel", tableName: table)
                            }
                            .disabled(model.busy)
                            .accessibilityIdentifier("freeBundle.reservation.canCancel.\(reservation.id.text)")
                        } else {
                            Text("reservation.cancel", tableName: table)
                                .font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier("freeBundle.reservation.canCancel.\(reservation.id.text)")
                        }
                        Text("reservation.monthlyWaiver", tableName: table)
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("freeBundle.reservation.waiver.\(reservation.id.text)")
                    }
                    // MKT-7-3b: MP free-explore/index.wxml:62 商家评价 (public-home → reviews/public → reviews/create).
                    if offers(.review) {
                        Button("freeBundle.action.review") { bundleAction = .review }
                            .accessibilityIdentifier("freeBundle.reservation.review.\(reservation.id.text)")
                    }
                }
            } header: {
                Text("reservations.title", tableName: table)
            }
            // MP reserve form (after 预约记录): chapter and store pickers (请选择 until chosen), the date, then 确认预约.
            Section {
                Picker(selection: $unitID) {
                    text("choose").tag(FreeExploreLaunchID?.none)
                    ForEach(bundle.units.filter { $0.status == "AVAILABLE" }, id: \.id) { unit in
                        Text(verbatim: chapterName(unit.chapterId) ?? unit.id.text).tag(FreeExploreLaunchID?.some(unit.id))
                    }
                } label: { text("unit") }
                if let unit = bundle.units.first(where: { $0.id == unitID }),
                   let item = model.catalog?.items.first(where: { $0.chapterId == unit.chapterId }) {
                    Picker(selection: $offerID) {
                        text("choose").tag(FreeExploreLaunchID?.none)
                        ForEach(item.stores, id: \.offerId) { store in
                            Text(verbatim: store.merchantName ?? store.offerId.text).tag(FreeExploreLaunchID?.some(store.offerId))
                        }
                    } label: { text("offer") }
                }
                DatePicker(selection: $date, in: Date()...) { text("date") }
                Button {
                    guard let unitID, let offerID else { return }
                    let millis = date.timeIntervalSince1970 * 1_000
                    guard millis.isFinite, millis > 0, millis < Double(Int64.max) else { return }
                    model.prepare(unitID: unitID, offerID: offerID, startAt: Int64(millis))
                } label: { text("review") }
                .disabled(!model.canReserve || unitID == nil || offerID == nil)
            } header: {
                if model.order?.bundle != nil { stepHeader }
            } footer: {
                if !model.canReserve { text("disabled") }
            }
            if bundle.exitCases.contains(where: { Self.exitCaseTitle($0.decision) != nil }) {
                Section {
                    ForEach(bundle.exitCases, id: \.id) { item in
                        if let line = Self.exitCaseTitle(item.decision) {
                            line
                                .accessibilityIdentifier("freeBundle.exitCase.\(item.id.text)")
                        }
                    }
                } header: {
                    Text("exitCases.title", tableName: table)
                }
            }
        } else if model.order != nil {
            Section { text("legacy").foregroundStyle(.secondary) }
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
    static func orderSectionHasRows(_ order: FreeExploreLaunchOrder, paidAmountKnown: Bool) -> Bool {
        if order.registrationNo != nil || paidAmountKnown { return true }
        if order.paymentStatus != nil || order.registrationStatus != nil { return true }
        if let hold = order.bundle?.refundHold, refundHoldTitle(hold.state) != nil { return true }
        return false
    }
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
