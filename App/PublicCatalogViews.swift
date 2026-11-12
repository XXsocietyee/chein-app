import SwiftUI

/// Layout for mini-program `pages/topic/catalog/index` (city catalog / theme collection) and `catalog/detail`.
/// Data in, intents out: the host feeds `PWaveCatalogCard` / `PWaveCatalogCity` values read by the Core public-catalog
/// reader (`/api/public-catalog/*`, anonymous read-only) and owns paging, filters and navigation. No wiring exists yet
/// (needs logic: PublicCatalogReading host + route), so nothing presents these views in production.
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
