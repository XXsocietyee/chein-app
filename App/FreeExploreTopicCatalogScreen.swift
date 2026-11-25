import SwiftUI

/// MKT-7-1 / flows-g1 `free-explore?topicId=`: the MP page reads `GET /api/free-explore/bundle/catalog?topicId=`
/// (`free-explore/index.js` `loadEntry`) and lists the bundle's chapters and stores before purchase. It does not
/// open the topic page. Signed out shows 请登录后查看 (index.js:37); a failed read shows the server message or
/// 加载失败，请稍后重试 with 刷新, which is hidden when the server says `BUNDLE_LEDGER_OFF` (R11 F-7).
/// Read only: the catalog never enables a reservation or a purchase here.
@MainActor struct FreeExploreTopicCatalogScreen: View {
    let topicID: Int
    @ObservedObject var session: AppSession
    var onSignIn: () -> Void = {}

    private enum Phase: Equatable {
        case loading, signedOut
        case failed(ledgerOff: Bool)
        case ready(FreeExploreLaunchCatalog)
    }
    @State private var phase: Phase = .loading
    @State private var openingTopic = false

    var body: some View {
        content
            .cyPageTitle("bundle.receipt.title")
            .task(id: reloadKey) { await load() }
            .navigationDestination(isPresented: $openingTopic) {
                SessionTopicDetailView(id: topicID, session: session)
            }
    }

    /// A new account or session epoch re-reads, as MP `onShow` does after an identity change.
    private var reloadKey: String {
        guard let context = session.currentRuntimeDependencyContext else { return "signedOut" }
        return "\(context.session.accountID)|\(context.session.epoch)|\(topicID)"
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            CYLoadingStateView(rows: 3)
                .accessibilityIdentifier("freeBundle.topicCatalog.loading")
        case .signedOut:
            CYStateLayout(kind: .generic, title: Text("freeBundle.catalog.signIn"),
                          primary: (title: "mp.common.signIn", action: onSignIn),
                          primaryIdentifier: "freeBundle.topicCatalog.signIn")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let ledgerOff):
            CYStateLayout(kind: .failure, title: Text("freeBundle.catalog.loadFailed"),
                          primary: ledgerOff ? nil : reloadAction,
                          primaryIdentifier: "freeBundle.topicCatalog.reload")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("freeBundle.topicCatalog.failed")
        case .ready(let catalog):
            FreeExploreCatalogBundleView(topicTitle: catalog.topicName ?? "",
                                         items: Self.rows(catalog),
                                         onOpenTopic: { openingTopic = true })
                .safeAreaInset(edge: .top, spacing: 0) { header(catalog) }
                .accessibilityIdentifier("freeBundle.topicCatalog")
        }
    }

    private var reloadAction: (title: LocalizedStringKey, action: () -> Void) {
        (title: LocalizedStringKey("刷新"), action: { Task { await load() } })
    }

    /// MP `bundle-title` (topic name) and the `暂未开售` note above the chapter cards.
    @ViewBuilder private func header(_ catalog: FreeExploreLaunchCatalog) -> some View {
        if catalog.topicName?.isEmpty == false || !catalog.saleEnabled {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let name = catalog.topicName, !name.isEmpty {
                    Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                if !catalog.saleEnabled {
                    Text("freeBundle.catalog.notOnSale").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("freeBundle.catalog.notOnSale")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.sm)
            .background(.bar)
        }
    }

    /// One row per store, as the MP prints `{{merchantName}}` under `{{chapter}} · 每人N次`.
    static func rows(_ catalog: FreeExploreLaunchCatalog) -> [FreeExploreCatalogMerchantItem] {
        catalog.items.flatMap { item in
            item.stores.compactMap { store -> FreeExploreCatalogMerchantItem? in
                guard let id = Int(exactly: store.offerId.value) else { return nil }
                // R8-MEM-7-2: keyed copy (MP `name || '章节'`, `每人N次`, `次数待确认` when the count is not positive).
                let chapter = item.name?.isEmpty == false ? item.name! : appLocalized("freeBundle.catalog.chapterFallback", locale: Locale.current)
                let units = item.unitsPerHolder > 0
                    ? appLocalized("freeBundle.catalog.unitsPerHolder \(item.unitsPerHolder)", locale: Locale.current)
                    : appLocalized("freeBundle.catalog.unitsUnknown", locale: Locale.current)
                return FreeExploreCatalogMerchantItem(id: id, merchantName: store.merchantName ?? "—",
                                                     chapterName: "\(chapter) · \(units)")
            }
        }
    }

    private func load() async {
        guard let context = session.currentRuntimeDependencyContext else { phase = .signedOut; return }
        guard let topic = try? FreeExploreLaunchID(Int64(topicID)),
              let launch = try? FreeExploreLaunchSession(baseURL: context.baseURL, accountID: Int64(context.session.accountID),
                                                          market: context.market.rawValue, namespace: context.session.namespace,
                                                          role: context.role, epoch: context.session.epoch, token: context.session.token)
        else { phase = .failed(ledgerOff: false); return }
        phase = .loading
        let owner = session
        let service = FreeExploreLaunchService(session: launch, transport: session.runtimeHTTPTransport,
            currentSession: { [weak owner] in
                guard let now = owner?.currentRuntimeDependencyContext, now.session.epoch == context.session.epoch,
                      now.session.accountID == context.session.accountID else { return nil }
                return launch
            })
        do {
            let catalog = try await service.catalog(topicID: topic)
            guard !Task.isCancelled else { return }
            phase = .ready(catalog)
        } catch FreeExploreLaunchFailure.response(_, _, let businessCode) {
            guard !Task.isCancelled else { return }
            phase = .failed(ledgerOff: businessCode == "BUNDLE_LEDGER_OFF")
        } catch {
            guard !Task.isCancelled else { return }
            phase = session.currentRuntimeDependencyContext == nil ? .signedOut : .failed(ledgerOff: false)
        }
    }
}
