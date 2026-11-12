import SwiftUI

/// Layout for mini-program `pages/topic/catalog/index` (city catalog / theme collection) and `catalog/detail`.
/// Data in, intents out. `PublicCatalogViews` feeds these types from the list, filters, and info reads.
/// An absent capability does not present them. Unknown prices stay an em dash.
enum PublicCatalogPhase: Equatable {
    case loading
    case failed
    case empty
    case content
}

struct PublicCatalogView: View {
    let phase: PublicCatalogPhase
    let cards: [PWaveCatalogCard]
    /// Empty hides the city title chevron and sheet (mini-program: unreadable cities => non-tappable title).
    let cities: [PWaveCatalogCity]
    let activeCityCode: String?
    let loadingMore: Bool
    let moreFailed: Bool
    let onSelectCity: (String?) -> Void
    let onOpen: (PWaveCatalogCard) -> Void
    let onRetry: () -> Void
    let onLoadMore: () -> Void

    @State private var cityPickerShown = false

    private var title: String {
        cities.first(where: { $0.cityCode == activeCityCode })?.cityName ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                if phase == .failed && !cards.isEmpty {
                    CYErrorStateView(title: "publicCatalog.error", message: "publicCatalog.errorHint", retryTitle: "homeFeed.retry", onRetry: onRetry)
                }
                switch phase {
                case .loading where cards.isEmpty:
                    CYLoadingStateView(rows: 3).accessibilityIdentifier("publicCatalog.loading")
                case .failed where cards.isEmpty:
                    CYErrorStateView(title: "publicCatalog.error", message: "publicCatalog.errorHint", retryTitle: "homeFeed.retry", onRetry: onRetry)
                        .accessibilityIdentifier("publicCatalog.error")
                case .empty:
                    CYEmptyStateView(systemImage: "map", title: "publicCatalog.empty")
                        .accessibilityIdentifier("publicCatalog.empty")
                default:
                    ForEach(cards, id: \.id) { card in
                        Button { onOpen(card) } label: { PublicCatalogCardRow(card: card) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("publicCatalog.card.\(card.id ?? "unknown")")
                    }
                    if loadingMore {
                        ProgressView("publicCatalog.loadingMore").frame(maxWidth: .infinity)
                    } else if moreFailed {
                        Button("publicCatalog.moreRetry", action: onLoadMore)
                            .buttonStyle(.cySecondary(fullWidth: true))
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("publicCatalog.moreRetry")
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .background { CYExploreGround() }
        .navigationTitle(cities.isEmpty || title.isEmpty ? Text("publicCatalog.title") : Text(verbatim: title))
        .toolbar {
            if !cities.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { cityPickerShown = true } label: { Label("publicCatalog.city", systemImage: "chevron.down.circle") }
                        .accessibilityIdentifier("publicCatalog.city")
                }
            }
        }
        .sheet(isPresented: $cityPickerShown) { citySheet }
        .refreshable { onRetry() }
    }

    private var citySheet: some View {
        NavigationStack {
            List {
                cityRow(name: nil, code: nil)
                ForEach(cities, id: \.cityCode) { city in cityRow(name: city.cityName, code: city.cityCode) }
            }
            .navigationTitle("publicCatalog.pickCity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { cityPickerShown = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func cityRow(name: String?, code: String?) -> some View {
        Button {
            onSelectCity(code)
            cityPickerShown = false
        } label: {
            HStack {
                if let name { Text(verbatim: name) } else { Text("publicCatalog.allCities") }
                Spacer()
                if code == activeCityCode { Image(systemName: "checkmark").foregroundStyle(CYColor.accent) }
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityAddTraits(code == activeCityCode ? .isSelected : [])
    }
}

/// Photo card: full-bleed cover with the kind pill, then title / duration meta / eligibility tags below (mini-program `topic-result-card`).
struct PublicCatalogCardRow: View {
    let card: PWaveCatalogCard

    private var meta: String {
        [card.sampleCountText, card.priceText].joined(separator: " · ")
    }

    private var tags: [LocalizedStringKey] {
        var out: [LocalizedStringKey] = []
        if card.freeSelfPlay == true { out.append("publicCatalog.tag.freeSelfPlay") }
        if card.groupEligible == true { out.append("publicCatalog.tag.group") }
        if card.schoolEligible == true { out.append("publicCatalog.tag.school") }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYImageCard(verbatim: card.name ?? "", fallback: "publicCatalog.untitled", meta: meta,
                        imageURL: card.imageURL.flatMap(URL.init(string:)))
            if !tags.isEmpty {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        Text(tag).font(CYTypography.caption)
                            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xs)
                            .background(CYColor.bgSurface, in: Capsule())
                            .foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum PublicCatalogDetailState: Equatable {
    case loading
    case gone
    case failed
    case ok(PWaveCatalogCard)
}

/// Mini-program `pages/topic/catalog/detail`: hero, tags, summary, chapters, more-from-city link, and the sticky "view work" footer.
struct PublicCatalogDetailView: View {
    let state: PublicCatalogDetailState
    let onRetry: () -> Void
    let onOpenWork: (PWaveCatalogCard) -> Void
    let onOpenCity: (PWaveCatalogCity) -> Void

    var body: some View {
        Group {
            switch state {
            case .loading:
                CYLoadingStateView(rows: 2).padding(CYSpacing.pageHorizontal).accessibilityIdentifier("publicCatalog.detail.loading")
            case .gone:
                CYEmptyStateView(systemImage: "map", title: "publicCatalog.detail.gone").accessibilityIdentifier("publicCatalog.detail.gone")
            case .failed:
                CYErrorStateView(title: "publicCatalog.detail.error", message: "publicCatalog.errorHint", retryTitle: "homeFeed.retry", onRetry: onRetry)
                    .accessibilityIdentifier("publicCatalog.detail.error")
            case .ok(let card):
                content(card)
            }
        }
        .background { CYExploreGround() }
        .navigationTitle("publicCatalog.detail.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ card: PWaveCatalogCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                PublicCatalogCardRow(card: card)
                if let summary = card.summary, !summary.isEmpty {
                    Text(verbatim: summary).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                if let chapters = card.chapterNames, !chapters.isEmpty {
                    Text("publicCatalog.detail.chapters").font(CYTypography.sectionTitle).accessibilityAddTraits(.isHeader)
                    ForEach(Array(chapters.enumerated()), id: \.offset) { _, name in
                        Text(verbatim: name).padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
                            .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                }
                if let code = card.cityCode, let name = card.cityName {
                    Button { onOpenCity(PWaveCatalogCity(cityCode: code, cityName: name)) } label: {
                        HStack { Text("publicCatalog.detail.moreInCity \(name)"); Spacer(); Image(systemName: "arrow.right") }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .accessibilityIdentifier("publicCatalog.detail.city")
                }
            }
            .padding(CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.jumbo)
        }
        .safeAreaInset(edge: .bottom) {
            Button("publicCatalog.detail.open") { onOpenWork(card) }
                .buttonStyle(.cyPrimary)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .padding(CYSpacing.pageHorizontal)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("publicCatalog.detail.open")
        }
    }
}

/// Installed by a host that already holds a non-production reader.
/// The shipped session leaves `host` nil, so this screen sends nothing and cannot pay.
enum PublicCatalogHostWiring {
    static let moneyEnabled = false
    static var host: PublicCatalogHost?
    static var scope: PWaveSessionScope?
    static var token: String?
}

/// List, filters, and info on the existing catalog views. Quote, order, and pay stay off.
@MainActor
struct PublicCatalogViews: View {
    static let moneyEnabled = false

    let link: PublicCatalogLink
    let host: PublicCatalogHost?
    let scope: () -> PWaveSessionScope?
    let token: () -> String?

    @State private var hidden = true
    @State private var phase: PublicCatalogPhase = .loading
    @State private var detail: PublicCatalogDetailState = .loading
    @State private var cards: [PWaveCatalogCard] = []
    @State private var cities: [PWaveCatalogCity] = []
    @State private var query: Query?

    private struct Query {
        var screen: PublicCatalogLink.Screen
        var fields: [String: String]
    }

    private var active: PublicCatalogLink {
        if let query, let built = PublicCatalogLink(screen: query.screen, fields: query.fields) {
            return built
        }
        return link
    }

    private var loadID: String {
        let fields = active.fields.keys.sorted().map { "\($0)=\(active.fields[$0] ?? "")" }.joined(separator: "\n")
        return "\(active.screen.rawValue)\n\(fields)"
    }

    var body: some View {
        Group {
            if hidden {
                EmptyView()
            } else if active.screen == .info {
                PublicCatalogDetailView(state: detail, onRetry: { retry() }, onOpenWork: { openWork($0) }, onOpenCity: { openCity($0) })
            } else {
                PublicCatalogView(phase: phase, cards: cards, cities: cities, activeCityCode: active.fields["city_code"],
                                  loadingMore: false, moreFailed: false, onSelectCity: { selectCity($0) }, onOpen: { openCard($0) },
                                  onRetry: { retry() }, onLoadMore: {})
            }
        }
        .task(id: loadID) { await reload() }
    }

    private func retry() { Task { await reload() } }

    /// A city choice reloads list or filters. It does not quote, order, or pay.
    private func selectCity(_ code: String?) {
        var fields = active.fields
        if let code, !code.isEmpty { fields["city_code"] = code } else { fields.removeValue(forKey: "city_code") }
        let screen: PublicCatalogLink.Screen = active.screen == .info ? .list : active.screen
        if screen != .info { fields.removeValue(forKey: "id") }
        adopt(screen: screen, fields: fields)
    }

    /// Opening a card reads info. It does not start a charge.
    private func openCard(_ card: PWaveCatalogCard) {
        guard let id = card.id, !id.isEmpty else { return }
        adopt(screen: .info, fields: ["id": id])
    }

    private func openCity(_ city: PWaveCatalogCity) {
        var fields: [String: String] = [:]
        if let code = city.cityCode, !code.isEmpty { fields["city_code"] = code }
        adopt(screen: .list, fields: fields)
    }

    /// The existing detail footer stays. This host does not quote, order, or pay.
    private func openWork(_ card: PWaveCatalogCard) {
        _ = card
    }

    private func adopt(screen: PublicCatalogLink.Screen, fields: [String: String]) {
        guard PublicCatalogLink(screen: screen, fields: fields) != nil else { return }
        query = Query(screen: screen, fields: fields)
    }

    private func reload() async {
        guard let host, let scope = scope() else {
            conceal()
            return
        }
        let credential = token()
        let requested = active
        if !hidden { revealLoading() }
        do {
            let presented = try await host.load(requested, token: credential, scope: scope, currentScope: { scope })
            guard !Task.isCancelled else { return }
            apply(presented)
        } catch {
            guard !Task.isCancelled else { return }
            showFailure()
        }
    }

    private func apply(_ presented: PWavePresentation<PWaveThemeCollectionFact>) {
        switch PublicCatalogScreen.state(presented) {
        case .unavailable:
            conceal()
        case .loading:
            revealLoading()
        case .empty:
            show(cards: [], cities: [], phase: .empty, detail: .gone)
        case .failed, .unrecognized:
            showFailure()
        case .ready:
            guard case .ready(let fact)? = presented.phase else {
                conceal()
                return
            }
            let nextPhase: PublicCatalogPhase = fact.cards.isEmpty ? .empty : .content
            let nextDetail: PublicCatalogDetailState
            if let card = matchingCard(in: fact) {
                nextDetail = .ok(card)
            } else {
                nextDetail = .gone
            }
            show(cards: fact.cards, cities: fact.cities, phase: nextPhase, detail: nextDetail)
        }
    }

    private func matchingCard(in fact: PWaveThemeCollectionFact) -> PWaveCatalogCard? {
        if let id = active.fields["id"], let match = fact.cards.first(where: { $0.id == id }) {
            return match
        }
        return fact.cards.first
    }

    private func revealLoading() {
        hidden = false
        cards = []
        cities = []
        phase = .loading
        detail = .loading
    }

    private func showFailure() {
        show(cards: [], cities: [], phase: .failed, detail: .failed)
    }

    private func show(cards: [PWaveCatalogCard], cities: [PWaveCatalogCity], phase: PublicCatalogPhase, detail: PublicCatalogDetailState) {
        hidden = false
        self.cards = cards
        self.cities = cities
        self.phase = phase
        self.detail = detail
    }

    /// No host, or a presentation the capability does not reveal: show none of the catalog UI.
    private func conceal() {
        hidden = true
        cards = []
        cities = []
        phase = .empty
        detail = .gone
    }
}
