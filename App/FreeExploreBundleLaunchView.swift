import SwiftUI

/// Real-data consumer only. No fixture, transport, factory, or production entry is installed here.
@MainActor struct FreeExploreBundleLaunchView: View {
    @Bindable var model: FreeExploreBundleLaunchModel
    @State private var unitID: FreeExploreLaunchID?
    @State private var offerID: FreeExploreLaunchID?
    @State private var date = Date()
    private let table = "FreeExploreBundleLaunch"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    var body: some View {
        Form {
            if !model.current {
                CYEmptyState(systemImage: "clock.arrow.circlepath", LocalizedStringKey("stale"), tableName: table)
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
            else {
                if model.busy { ProgressView { text("loading") } }
                if model.failure != nil {
                    Label { text("error") } icon: { Image(systemName: "exclamationmark.triangle") }
                        .font(CYTypography.body).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("freeBundle.error")
                }
                if model.state == .outcomeUnknown {
                    Section {
                        Label { text("unknown") } icon: { Image(systemName: "clock.badge.questionmark") }
                            .font(CYTypography.body)
                        CYPillButton(LocalizedStringKey("recover"), style: .primary, tableName: table) { Task { await model.recover() } }
                            .disabled(model.busy).listRowBackground(Color.clear)
                        CYPillButton(LocalizedStringKey("retry"), style: .tertiary, tableName: table) { Task { await model.retryOriginal() } }
                            .disabled(!model.canRetry).listRowBackground(Color.clear)
                    }
                }
                if let catalog = model.catalog {
                    Section {
                        if let name = catalog.topicName { Text(verbatim: name).font(CYTypography.sectionTitle) }
                        if catalog.items.isEmpty {
                            CYEmptyState(systemImage: "tray", LocalizedStringKey("empty"), tableName: table)
                                .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                        }
                        ForEach(catalog.items, id: \.chapterId) { item in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                if let name = item.name { Text(verbatim: name).font(CYTypography.cardTitle) }
                                if let terms = item.termsMode { Text(verbatim: terms).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                            }
                            ForEach(item.stores, id: \.offerId) { store in
                                CYListRow(verbatim: store.merchantName ?? store.offerId.text, meta: store.validEnd, trailing: .none) { CYRowIcon(systemImage: "storefront") }
                            }
                        }
                    } header: { text("catalog") }
                }
                if let order = model.order {
                    Section {
                        LabeledContent { Text(verbatim: order.registrationId.text) } label: { text("order") }
                        if let number = order.registrationNo { Text(verbatim: number).textSelection(.enabled) }
                        if let bundle = order.bundle {
                            ForEach(bundle.reservations, id: \.id) { reservation in
                                VStack(alignment: .leading) {
                                    Text(verbatim: reservation.status)
                                    Text(verbatim: reservation.startAt)
                                    Text(verbatim: reservation.id.text).font(.caption)
                                }
                            }
                            Picker(selection: $unitID) {
                                text("choose").tag(Optional<FreeExploreLaunchID>.none)
                                ForEach(bundle.units.filter { $0.status == "AVAILABLE" }, id: \.id) { unit in
                                    Text(verbatim: unit.id.text).tag(Optional(unit.id))
                                }
                            } label: { text("unit") }
                            Picker(selection: $offerID) {
                                text("choose").tag(Optional<FreeExploreLaunchID>.none)
                                if let unit = bundle.units.first(where: { $0.id == unitID }),
                                   let item = model.catalog?.items.first(where: { $0.chapterId == unit.chapterId }) {
                                    ForEach(item.stores, id: \.offerId) { store in
                                        Text(verbatim: store.merchantName ?? store.offerId.text).tag(Optional(store.offerId))
                                    }
                                }
                            } label: { text("offer") }
                            DatePicker(selection: $date) { text("date") }
                            CYPillButton(LocalizedStringKey("review"), style: .primary, tableName: table) {
                                guard let unitID, let offerID else { return }
                                let millis = date.timeIntervalSince1970 * 1_000
                                guard millis.isFinite, millis > 0, millis < Double(Int64.max) else { return }
                                model.prepare(unitID: unitID, offerID: offerID, startAt: Int64(millis))
                            }
                            .disabled(!model.canReserve || unitID == nil || offerID == nil).listRowBackground(Color.clear)
                        } else { text("legacy") }
                        if !model.canReserve { text("disabled").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                    }
                }
                if model.state == .confirmed {
                    Label { text("confirmed") } icon: { Image(systemName: "checkmark.circle") }.font(CYTypography.body)
                }
            }
        }
        .navigationTitle(text("title"))
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
