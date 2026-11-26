import SwiftUI

/// What `FreeExploreTopicCatalogScreen` has read so far (`GET /api/free-explore/bundle/catalog?topicId=`).
/// The screen still owns the read; this file only draws it.
enum NativeFreeExploreBundleState: Equatable {
    case loading
    case signedOut
    case failed(ledgerOff: Bool, message: String?)
    case ready(FreeExploreLaunchCatalog)
}

/// Native r2 自由探索 bundle detail (spec §3, Apple Maps Guide detail): an inset-grouped list with one header image,
/// the bundle facts as `LabeledContent`, one section per chapter listing its stores, and a bottom toolbar with the
/// price and one prominent start button. Read only: start opens the topic page, which keeps the existing
/// purchase / registration gate. No request is added here.
@MainActor struct NativeFreeExploreBundleDetailView: View {
    let state: NativeFreeExploreBundleState
    /// Price text when the host already has it. The catalog read carries none, so nil shows the sale status.
    var priceText: String? = nil
    let onSignIn: () -> Void
    let onReload: () -> Void
    let onStart: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }

    private var title: Text {
        if case .ready(let catalog) = state, let name = catalog.topicName, !name.isEmpty { return Text(verbatim: name) }
        return Text("bundle.receipt.title")
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            placeholderList
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityIdentifier("freeBundle.topicCatalog.loading")
        case .signedOut:
            ContentUnavailableView {
                Label("freeBundle.catalog.signIn", systemImage: "person.crop.circle")
            } actions: {
                Button("mp.common.signIn", action: onSignIn)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("freeBundle.topicCatalog.signIn")
            }
        case .failed(let ledgerOff, let message):
            ContentUnavailableView {
                if let message, !message.isEmpty {
                    Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }
                } else {
                    Label("freeBundle.catalog.loadFailed", systemImage: "exclamationmark.triangle")
                }
            } actions: {
                // R11 F-7: 刷新 is hidden when the server says BUNDLE_LEDGER_OFF.
                if !ledgerOff {
                    Button("刷新", action: onReload)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("freeBundle.topicCatalog.reload")
                }
            }
            .accessibilityIdentifier("freeBundle.topicCatalog.failed")
        case .ready(let catalog):
            list(catalog)
                .refreshable { onReload() }
                .toolbar { bottomBar(catalog) }
                .accessibilityIdentifier("freeBundle.topicCatalog")
        }
    }

    private func list(_ catalog: FreeExploreLaunchCatalog) -> some View {
        List {
            Section {
                MPAsset.BannerCover.coverRoute
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .accessibilityHidden(true)
            }
            Section {
                LabeledContent("nativeR2.freeExplore.bundle.chapters") {
                    Text(verbatim: "\(catalog.items.count)").monospacedDigit()
                }
                LabeledContent("nativeR2.freeExplore.bundle.stores") {
                    Text(verbatim: String(catalog.items.map(\.stores.count).reduce(0, +))).monospacedDigit()
                }
                LabeledContent("nativeR2.freeExplore.bundle.reservation") {
                    Text(LocalizedStringKey(catalog.reservationEnabled ? "nativeR2.freeExplore.bundle.reservation.on" : "nativeR2.freeExplore.bundle.reservation.off"))
                }
                LabeledContent("nativeR2.freeExplore.bundle.sale") {
                    if catalog.saleEnabled {
                        Text("nativeR2.freeExplore.bundle.sale.on")
                    } else {
                        Text("freeBundle.catalog.notOnSale").accessibilityIdentifier("freeBundle.catalog.notOnSale")
                    }
                }
            } footer: {
                Text("nativeR2.freeExplore.bundle.routeNote")
            }
            if catalog.items.isEmpty {
                ContentUnavailableView("bundle.catalog.empty", systemImage: "storefront")
            }
            ForEach(Array(catalog.items.enumerated()), id: \.offset) { _, item in
                Section {
                    ForEach(Array(item.stores.enumerated()), id: \.offset) { _, store in
                        storeRow(store)
                    }
                } header: {
                    Text(verbatim: chapterHeader(item))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func storeRow(_ store: FreeExploreLaunchCatalog.Item.Store) -> some View {
        LabeledContent {
            Text(LocalizedStringKey(store.available ? "nativeR2.freeExplore.bundle.store.available" : "freeBundle.catalog.storeClosed"))
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: store.merchantName ?? "—")
                    if let end = store.validEnd, !end.isEmpty {
                        Text(verbatim: appLocalized("nativeR2.freeExplore.bundle.validEnd", locale: locale) + " " + end)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "storefront")
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// MP `{{name || '章节'}} · 每人N次` (`次数待确认` when the count is not positive), the same keyed copy as before.
    private func chapterHeader(_ item: FreeExploreLaunchCatalog.Item) -> String {
        let chapter = item.name?.isEmpty == false ? item.name! : appLocalized("freeBundle.catalog.chapterFallback", locale: locale)
        let units = item.unitsPerHolder > 0
            ? appLocalized("freeBundle.catalog.unitsPerHolder \(item.unitsPerHolder)", locale: locale)
            : appLocalized("freeBundle.catalog.unitsUnknown", locale: locale)
        return chapter + " · " + units
    }

    @ToolbarContentBuilder private func bottomBar(_ catalog: FreeExploreLaunchCatalog) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Group {
                if let priceText {
                    Text(verbatim: priceText).font(.headline).monospacedDigit()
                } else if catalog.saleEnabled {
                    Text("nativeR2.freeExplore.bundle.sale.on").foregroundStyle(.secondary)
                } else {
                    Text("freeBundle.catalog.notOnSale").foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("nativeR2.freeExplore.bundle.price")
            Spacer()
            // Start = the topic page, which owns purchase and registration (payment gate unchanged).
            Button("nativeR2.freeExplore.bundle.start", action: onStart)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("freeBundle.topicCatalog.openTopic")
        }
    }

    /// Shape-only rows for the redacted loading state; never shown as data.
    private var placeholderList: some View {
        List {
            Section {
                Color.secondary.opacity(0.2).frame(height: 180).listRowInsets(EdgeInsets())
            }
            Section {
                LabeledContent("nativeR2.freeExplore.bundle.chapters") { Text(verbatim: "0") }
                LabeledContent("nativeR2.freeExplore.bundle.stores") { Text(verbatim: "0") }
                LabeledContent("nativeR2.freeExplore.bundle.sale") { Text(verbatim: "————") }
            }
            Section {
                ForEach(0..<3, id: \.self) { _ in
                    Label { Text(verbatim: "————————") } icon: { Image(systemName: "storefront") }
                }
            } header: {
                Text(verbatim: "————")
            }
        }
        .listStyle(.insetGrouped)
    }
}
