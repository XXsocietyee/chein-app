import SwiftUI

@MainActor
struct MerchantOrdersView<Reader: MerchantReading>: View {
    @ObservedObject var reader: Reader
    @StateObject private var model = MerchantLoadModel<[MerchantOrder]>()
    @State private var filter = MerchantOrderFilter()
    @State private var draftFilter = MerchantOrderFilter()
    @State private var showFilters = false
    @State private var selection: OrderSelection?
    @State private var visible = false
    @State private var ownedTask: Task<Void, Never>?
    @State private var loadedKey: ReadKey?
    private struct ReadKey: Equatable {
        let reader: ObjectIdentifier
        let revision: UInt64
        let configured: Bool
        let signedIn: Bool
    }
    private var readKey: ReadKey {
        .init(reader: ObjectIdentifier(reader), revision: reader.sessionRevision,
              configured: reader.isConfigured, signedIn: reader.isSignedIn)
    }

    private struct OrderSelection: Identifiable {
        let id = UUID()
        let order: MerchantOrder
        let revision: UInt64
    }

    var body: some View {
        ZStack {
            if !reader.isConfigured {
                CYEmptyState(systemImage: "network.slash", "merchant.orders", detail: "auth.notConfigured")
            } else if !reader.isSignedIn {
                CYEmptyState(systemImage: "lock", "merchant.orders", detail: "merchant.signIn")
            } else if loadedKey == readKey, model.loadedRevision == reader.sessionRevision, let rows = model.value {
                List {
                    Section {
                        if filter.status != nil || filter.aftersaleStatus != nil { filterSummary }
                        if model.isLoading { ProgressView("merchant.refreshing").cyText(.meta) }
                        if let error = model.errorKey {
                            Text("merchant.stale").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            MerchantInlineFailure(errorKey: error, retry: { scheduleReload() })
                        }
                    }
                    if rows.isEmpty {
                        CYEmptyState(systemImage: "receipt", "merchant.orders.empty", messageIdentifier: "merchant.orders.empty")
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, order in
                            Button {
                                if canPresentSummary { selection = OrderSelection(order: order, revision: reader.sessionRevision) }
                            } label: { MerchantOrderRow(order: order) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("merchant.order.row.\(order.id.map(String.init) ?? String(index))")
                        }
                    }
                }.refreshable { await reload() }
            } else if let error = model.errorKey {
                MerchantFailureView(errorKey: error, identifier: "merchant.orders", retry: { scheduleReload() })
            } else {
                CYSkeleton(variant: .row)
                    .padding(CYSpacing.pageHorizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .cyPageTitle("merchant.orders")
        .toolbar {
            if reader.isSignedIn && reader.isConfigured && model.errorKey != "merchant.access.denied" {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { draftFilter = filter; showFilters = true } label: { Label("merchant.filters", systemImage: "line.3.horizontal.decrease.circle") }
                        .accessibilityIdentifier("merchant.orders.filters")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            NavigationStack {
                Form {
                    Picker("merchant.order.status", selection: $draftFilter.status) {
                        Text("merchant.filter.all").tag(nil as MerchantOrderStatus?)
                        ForEach(MerchantOrderStatus.allCases, id: \.rawValue) { status in
                            Text(LocalizedStringKey(status.titleKey)).tag(Optional(status))
                        }
                    }
                    Picker("merchant.order.aftersale", selection: $draftFilter.aftersaleStatus) {
                        Text("merchant.filter.all").tag(nil as MerchantAftersaleStatus?)
                        ForEach(MerchantAftersaleStatus.allCases, id: \.rawValue) { status in
                            Text(LocalizedStringKey(status.titleKey)).tag(Optional(status))
                        }
                    }
                    Button("merchant.filters.reset") { draftFilter = .init() }
                }
                .cyPageTitle("merchant.filters")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("merchant.cancel") { showFilters = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("merchant.filters.apply") {
                            filter = draftFilter; showFilters = false
                            scheduleReload(discardOldValue: true)
                        }.accessibilityIdentifier("merchant.orders.filters.apply")
                    }
                }
            }
            .cyDomainSheet(detents: [.half, .full])
            .themeDomain(.merchant)
        }
        .sheet(item: $selection) { selected in
            NavigationStack {
                if reader.isSignedIn && selected.revision == reader.sessionRevision {
                    MerchantOrderSummary(order: selected.order)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("merchant.done") { selection = nil } } }
                } else { ContentUnavailableView("merchant.signIn", systemImage: "lock") }
            }
            .cyDomainSheet(detents: [.half, .full])
            .themeDomain(.merchant)
        }
        .task(id: readKey) {
            guard !Task.isCancelled else { return }
            visible = true
            await reload(discardOldValue: true)
        }
        .onChange(of: readKey) { _, _ in selection = nil; showFilters = false; ownedTask?.cancel() }
        .onDisappear {
            visible = false; ownedTask?.cancel(); ownedTask = nil
            selection = nil; showFilters = false; loadedKey = nil; model.clear()
        }
    }
    @ViewBuilder private var filterSummary: some View {
        if let status = filter.status { Text(LocalizedStringKey(status.titleKey)) }
        if let aftersale = filter.aftersaleStatus { Text(LocalizedStringKey(aftersale.titleKey)) }
    }
    // A summary is a copy of a list row, not an independently authorized detail response.
    private var canPresentSummary: Bool {
        visible && loadedKey == readKey && reader.isConfigured && reader.isSignedIn && model.loadedRevision == reader.sessionRevision
            && !model.isLoading && model.errorKey == nil && model.value != nil
    }
    private func scheduleReload(discardOldValue: Bool = false) {
        guard visible else { return }
        let key = readKey
        ownedTask?.cancel()
        ownedTask = Task {
            guard visible, key == readKey, !Task.isCancelled else { return }
            await reload(discardOldValue: discardOldValue)
        }
    }
    private func reload(discardOldValue: Bool = false) async {
        guard visible, !Task.isCancelled else { return }
        let key = readKey
        let discard = discardOldValue || loadedKey != key
        loadedKey = key
        // Retire copied rows before refreshing permission or changing filters.
        selection = nil
        let requestedFilter = filter
        let revision = reader.sessionRevision
        await model.load(reader: reader, discardOldValue: discard) {
            try Task.checkCancellation()
            guard visible, key == readKey else { throw CancellationError() }
            let access = try await reader.merchantAccess()
            guard visible, key == readKey, revision == reader.sessionRevision, reader.isSignedIn else { throw CancellationError() }
            guard access.allows(.orders) else { throw MerchantReadError.accessDenied }
            try Task.checkCancellation()
            return try await reader.merchantOrders(access: access, filter: requestedFilter)
        }
    }
}

private struct MerchantOrderRow: View {
    @Environment(\.locale) private var locale
    let order: MerchantOrder
    private var orderNumber: some View {
        Text(order.orderSn.flatMap { $0.isEmpty ? nil : $0 } ?? appLocalized("merchant.orders",locale:locale))
            .cyText(.cardTitle)
            .foregroundStyle(CYColor.textPrimary)
    }
    private var amount: some View {
        Text(MerchantMoney.display(order.payAmount))
            .cyText(.cardTitle, monospacedDigit: true)
            .foregroundStyle(CYColor.textPrimary)
    }
    @ViewBuilder private var orderTime: some View {
        if let time = order.createTime, !time.isEmpty {
            Text(time)
                .cyText(.meta)
                .monospacedDigit()
                .foregroundStyle(CYColor.textSecondary)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            // At accessibility sizes the pairs stack instead of squeezing the order number and the time.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) { orderNumber; Spacer(minLength: 0); amount }
                VStack(alignment: .leading, spacing: CYSpacing.xs) { orderNumber; amount }
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) { MerchantOrderStatusLabel(value: order.status); Spacer(minLength: 0); orderTime }
                VStack(alignment: .leading, spacing: CYSpacing.xs) { MerchantOrderStatusLabel(value: order.status); orderTime }
            }
            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            if let raw = order.aftersaleStatus, raw >= 2 {
                MerchantAftersaleLabel(value: raw).cyText(.meta).foregroundStyle(CYColor.warningText)
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .contentShape(Rectangle())
    }
}

private struct MerchantOrderSummary: View {
    let order: MerchantOrder
    var body: some View {
        Form {
            Section {
                CYBalanceHero(
                    label: "merchant.order.amount",
                    amount: MerchantMoney.display(order.payAmount)
                )
                .listRowBackground(Color.clear)
            }
            Section {
                if let value = order.orderSn, !value.isEmpty { LabeledContent("merchant.order.number", value: value).textSelection(.enabled) }
                if let value = order.id { MerchantCountRow("merchant.recordID", value: value) }
                LabeledContent { MerchantOrderStatusLabel(value: order.status) } label: { Text("merchant.order.status") }
                if let value = order.aftersaleStatus {
                    LabeledContent { MerchantAftersaleLabel(value: value) } label: { Text("merchant.order.aftersale") }
                }
                if let value = order.createTime, !value.isEmpty { LabeledContent("merchant.order.created", value: value) }
            }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .cyPageTitle("merchant.order.summary")
    }
}

private struct MerchantOrderStatusLabel: View {
    let value: Int?
    var body: some View {
        if let value, let known = MerchantOrderStatus(rawValue: value) { Text(LocalizedStringKey(known.titleKey)) }
        else if let value { HStack { Text("merchant.status.unknown"); Text(String(value)) } }
        else { Text("merchant.status.missing").foregroundStyle(CYColor.textSecondary) }
    }
}
private struct MerchantAftersaleLabel: View {
    let value: Int
    var body: some View {
        if let known = MerchantAftersaleStatus(rawValue: value) { Text(LocalizedStringKey(known.titleKey)) }
        else { HStack { Text("merchant.status.unknown"); Text(String(value)) } }
    }
}
