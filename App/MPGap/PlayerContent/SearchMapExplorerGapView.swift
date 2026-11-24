import MapKit
import SwiftUI

/// `PC-A-5-1` / `PC-A-5-2` / `PC-A-5-3` / `PC-A-5-4` / `PC-A-5-5`:
/// Map-first search explorer (`pages/searchmap/index`) with floating search bar,
/// merchant category filter chips, `sort_type: 1` (`最近`), and bottom result sheet.
public struct SearchMapExplorerGapView: View {
    @Binding public var keyword: String
    public let categories: [SearchMapCategoryChip]
    @Binding public var selectedCategoryID: Int?
    public let places: [SearchMapPlaceItem]
    public let isLoading: Bool
    public let locationDenied: Bool

    @State private var selectedPlace: SearchMapPlaceItem?
    @State private var showAllResultsSheet = false

    public var onSearch: () -> Void
    public var onOpenLocationSettings: () -> Void
    public var onOpenInMaps: (SearchMapPlaceItem) -> Void
    public var onSelectPlace: (SearchMapPlaceItem) -> Void

    public init(
        keyword: Binding<String>,
        categories: [SearchMapCategoryChip],
        selectedCategoryID: Binding<Int?>,
        places: [SearchMapPlaceItem],
        isLoading: Bool = false,
        locationDenied: Bool = false,
        onSearch: @escaping () -> Void = {},
        onOpenLocationSettings: @escaping () -> Void = {},
        onOpenInMaps: @escaping (SearchMapPlaceItem) -> Void = { _ in },
        onSelectPlace: @escaping (SearchMapPlaceItem) -> Void = { _ in }
    ) {
        self._keyword = keyword
        self.categories = categories
        self._selectedCategoryID = selectedCategoryID
        self.places = places
        self.isLoading = isLoading
        self.locationDenied = locationDenied
        self.onSearch = onSearch
        self.onOpenLocationSettings = onOpenLocationSettings
        self.onOpenInMaps = onOpenInMaps
        self.onSelectPlace = onSelectPlace
    }

    public var body: some View {
        Map {
            ForEach(places) { place in
                Annotation(
                    place.title,
                    coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                ) {
                    Button {
                        selectedPlace = place
                    } label: {
                        MPAsset.MapMarker.dSmapicon
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: selectedPlace?.id == place.id ? 34 : 28,
                                height: selectedPlace?.id == place.id ? 34 : 28
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .top) {
            VStack(spacing: CYSpacing.xs) {
                HStack(spacing: CYSpacing.xs) {
                    TextField("searchMap.placeholder", text: $keyword)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit(onSearch)
                    Button("searchMap.searchAction", action: onSearch)
                        .buttonStyle(.borderedProminent)
                }
                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CYSpacing.xs) {
                            ForEach(categories) { cat in
                                let active = selectedCategoryID == cat.id
                                Button(cat.name) {
                                    selectedCategoryID = active ? nil : cat.id
                                    onSearch()
                                }
                                .buttonStyle(.bordered)
                                .tint(active ? CYColor.brand : CYColor.textSecondary)
                            }
                        }
                    }
                }
                if locationDenied {
                    HStack {
                        Text("searchMap.locationDenied")
                            .cyText(.meta)
                        Spacer()
                        Button("searchMap.openSettings", action: onOpenLocationSettings)
                            .cyText(.label)
                    }
                    .padding(CYSpacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                }
            }
            .padding(CYSpacing.sm)
            .background(.ultraThinMaterial)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showAllResultsSheet = true
            } label: {
                HStack {
                    if isLoading { ProgressView() }
                    Text("附近共 \(places.count) 个结果 · 最近")
                        .cyText(.cardTitle, monospacedDigit: true)
                    Spacer()
                    Image(systemName: "chevron.up")
                        .cyText(.meta)
                }
                .padding(CYSpacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                .padding(.horizontal, CYSpacing.md)
                .padding(.bottom, CYSpacing.xs)
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $selectedPlace) { place in
            VStack(spacing: 0) {
                CYSheetHeader(title: Text(verbatim: place.title), style: .player) {
                    selectedPlace = nil
                }
                List {
                    Section {
                        LabeledContent("searchMap.place.kind", value: place.kindLabel)
                        LabeledContent("searchMap.place.address", value: place.address)
                    }
                    Section {
                        Button("searchMap.place.openMaps") { onOpenInMaps(place) }
                        Button("searchMap.place.viewDetail") { onSelectPlace(place) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAllResultsSheet) {
            VStack(spacing: 0) {
                CYSheetHeader(title: Text("searchMap.allResults"), style: .player) {
                    showAllResultsSheet = false
                }
                if places.isEmpty {
                    ContentUnavailableView("searchMap.emptyResults", systemImage: "magnifyingglass")
                } else {
                    List(places) { place in
                        Button {
                            showAllResultsSheet = false
                            selectedPlace = place
                        } label: {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(place.title).cyText(.cardTitle)
                                Text(place.address).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .cyPageTitle("searchMap.title")
    }
}
