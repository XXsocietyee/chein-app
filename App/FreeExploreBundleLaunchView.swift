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
    /// Menu-picker row inside a card: label left, current choice right, 48pt tall.
    private func choice<P: View>(_ label: Text, selected: String?, @ViewBuilder picker: () -> P) -> some View {
        HStack {
            label.font(CYTypography.bodyCompact).foregroundStyle(CYColor.textPrimary)
            Spacer(minLength: CYSpacing.sm)
            picker().labelsHidden().tint(CYColor.textSecondary)
        }.frame(minHeight: 48)
    }
    var body: some View {
        CYCardPage {
            CYArtCoverHeader(title: text("title"), symbol: "shippingbox.fill", seed: "bundle") { EmptyView() }
        } content: {
            if !model.current {
                CYEmptyState(systemImage: "clock.arrow.circlepath", LocalizedStringKey("stale"), tableName: table)
            } else {
                if model.busy { ProgressView { text("loading") }.frame(maxWidth: .infinity).padding(CYSpacing.md) }
                if model.failure != nil {
                    CYNoteBanner(text: text("error"), symbol: "exclamationmark.triangle", tone: .warning).accessibilityIdentifier("freeBundle.error")
                }
                if model.state == .outcomeUnknown {
                    CYInfoCard(title: text("unknown"), symbol: "clock.badge.questionmark") {
                        CYPillButton(LocalizedStringKey("recover"), style: .primary, tableName: table) { Task { await model.recover() } }.disabled(model.busy)
                        CYPillButton(LocalizedStringKey("retry"), style: .tertiary, tableName: table) { Task { await model.retryOriginal() } }.disabled(!model.canRetry)
                    }
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
                        choice(text("unit"), selected: unitID.map { $0.text }) {
                            Picker(selection: $unitID) {
                                text("choose").tag(Optional<FreeExploreLaunchID>.none)
                                ForEach(bundle.units.filter { $0.status == "AVAILABLE" }, id: \.id) { unit in
                                    Text(verbatim: chapterName(unit.chapterId) ?? unit.id.text).tag(Optional(unit.id))
                                }
                            } label: { text("unit") }
                        }
                        choice(text("offer"), selected: offerID.flatMap { id in model.catalog?.items.flatMap(\.stores).first(where: { $0.offerId == id }).map { $0.merchantName ?? id.text } }) {
                            Picker(selection: $offerID) {
                                text("choose").tag(Optional<FreeExploreLaunchID>.none)
                                if let unit = bundle.units.first(where: { $0.id == unitID }),
                                   let item = model.catalog?.items.first(where: { $0.chapterId == unit.chapterId }) {
                                    ForEach(item.stores, id: \.offerId) { store in
                                        Text(verbatim: store.merchantName ?? store.offerId.text).tag(Optional(store.offerId))
                                    }
                                }
                            } label: { text("offer") }
                        }.disabled(unitID == nil)
                        DatePicker(selection: $date) { text("date").font(CYTypography.bodyCompact) }
                        CYPillButton(LocalizedStringKey("review"), style: .primary, tableName: table) {
                            guard let unitID, let offerID else { return }
                            let millis = date.timeIntervalSince1970 * 1_000
                            guard millis.isFinite, millis > 0, millis < Double(Int64.max) else { return }
                            model.prepare(unitID: unitID, offerID: offerID, startAt: Int64(millis))
                        }
                        .disabled(!model.canReserve || unitID == nil || offerID == nil)
                        if !model.canReserve { text("disabled").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                    }
                    if !bundle.reservations.isEmpty {
                        CYInfoCard(title: text("order"), symbol: "ticket.fill") {
                            ForEach(bundle.reservations, id: \.id) { reservation in
                                CYListRow(verbatim: reservation.status, meta: reservation.startAt, trailing: .none) { CYRowIcon(systemImage: "calendar.badge.checkmark") }
                            }
                            if let number = order.registrationNo { Text(verbatim: number).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).textSelection(.enabled) }
                        }
                    }
                } else if model.order != nil { text("legacy").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                if let catalog = model.catalog {
                    CYInfoCard(title: catalog.topicName.map { Text(verbatim: $0) } ?? text("catalog"), symbol: "list.star") {
                        if catalog.items.isEmpty { CYEmptyState(systemImage: "tray", LocalizedStringKey("empty"), tableName: table) }
                        ForEach(catalog.items, id: \.chapterId) { item in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                if let name = item.name { Text(verbatim: name).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                                if let terms = item.termsMode { Text(verbatim: terms).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                                ForEach(item.stores, id: \.offerId) { store in
                                    CYListRow(verbatim: store.merchantName ?? store.offerId.text, meta: store.validEnd, trailing: .none) { CYRowIcon(systemImage: "storefront") }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
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
                    LabeledContent { Text(verbatim: review.command.registrationId.text) } label: { text("order") }
                    LabeledContent { Text(verbatim: review.command.unitId.text) } label: { text("unit") }
                    LabeledContent { Text(verbatim: review.command.offerId.text) } label: { text("offer") }
                    LabeledContent {
                        Text(Date(timeIntervalSince1970: Double(review.command.startAt) / 1_000), style: .date)
                        Text(Date(timeIntervalSince1970: Double(review.command.startAt) / 1_000), style: .time)
                    } label: { text("date") }
                    CYPillButton(LocalizedStringKey("confirm"), style: .primary, tableName: table) { Task { await model.confirm(review) } }
                        .disabled(!model.canReserve).listRowBackground(Color.clear)
                    CYPillButton(LocalizedStringKey("cancel"), style: .tertiary, tableName: table) { model.cancelReview() }
                        .listRowBackground(Color.clear)
                }.navigationTitle(text("review"))
            }
        }
        // A reopened destination must receive a fresh model from its authorized host.
        .onDisappear { model.cancelReview() }
    }
}
