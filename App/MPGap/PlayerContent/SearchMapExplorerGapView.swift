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
                        // MP map marker art (`pages/searchmap/images/dsmapicon`).
                        MPAsset.MapMarker.pagesSearchmapImagesDSmapicon
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
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea(edges: .bottom)
        // Apple Maps pattern: the system search field in the navigation bar; submitting searches.
        .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("searchMap.placeholder"))
        .onSubmit(of: .search, onSearch)
        .toolbar {
            if !categories.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    // Merchant category filter as a system menu; choosing the active one clears it (MP chip toggle).
                    Menu {
                        ForEach(categories) { cat in
                            let active = selectedCategoryID == cat.id
                            Button {
                                selectedCategoryID = active ? nil : cat.id
                                onSearch()
                            } label: {
                                if active { Label(cat.name, systemImage: "checkmark") } else { Text(verbatim: cat.name) }
                            }
                        }
                    } label: {
                        Label("searchMap.filters", systemImage: selectedCategoryID == nil
                              ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if locationDenied {
                HStack {
                    Label("searchMap.locationDenied", systemImage: "location.slash")
                        .font(.footnote)
                    Spacer()
                    Button("searchMap.openSettings", action: onOpenLocationSettings)
                        .font(.footnote)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showAllResultsSheet = true
            } label: {
                HStack {
                    if isLoading { ProgressView() }
                    Text("附近共 \(places.count) 个结果 · 最近")
                        .font(.headline)
                        .monospacedDigit()
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.footnote)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .cySheet(item: $selectedPlace) { place in
            NavigationStack {
                List {
                    Section {
                        LabeledContent("searchMap.place.kind", value: place.kindLabel)
                        LabeledContent("searchMap.place.address", value: place.address)
                    }
                    Section {
                        Button("searchMap.place.openMaps") { onOpenInMaps(place) }
                        Button("searchMap.place.viewDetail") { onSelectPlace(place) }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(Text(verbatim: place.title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { selectedPlace = nil } label: { Label("action.close", systemImage: "xmark") }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .cySheet(isPresented: $showAllResultsSheet) {
            NavigationStack {
                Group {
                    if places.isEmpty {
                        ContentUnavailableView("searchMap.emptyResults", systemImage: "magnifyingglass")
                    } else {
                        List(places) { place in
                            Button {
                                showAllResultsSheet = false
                                selectedPlace = place
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.title).font(.body).foregroundStyle(.primary)
                                    Text(place.address).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .navigationTitle(Text("searchMap.allResults"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { showAllResultsSheet = false } label: { Label("action.close", systemImage: "xmark") }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .cyPageTitle("searchMap.title")
    }
}
