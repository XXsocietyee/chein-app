import MapKit
import PhotosUI
import SwiftUI

/// Round-4 SwiftUI views for `player-content` Gemini items:
/// `R7-PC-B3-2` (Map + PhotosPicker for merchant apply), `R7-PC-B1-12` (Post-purchase pass reveal + consent),
/// `R7-PC-B2-2` (`联系主办` button), `R7-PC-B1-22` (Share poster card).

// MARK: - R7-PC-B3-2: Merchant Apply Map & Photo Pickers

public struct MerchantApplyPickerGapView: View {
    @Binding public var location: MerchantApplyLocationSelection?
    @Binding public var ruleInstructions: String
    @Binding public var uploadedPicURLs: [String]
    public let writesEnabled: Bool

    @State private var showMapPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    public var onSelectPhotos: ([PhotosPickerItem]) -> Void = { _ in }
    public var onSubmit: () -> Void = {}

    private let maxRuleChars = 500
    private let maxImages = 9

    public init(
        location: Binding<MerchantApplyLocationSelection?>,
        ruleInstructions: Binding<String>,
        uploadedPicURLs: Binding<[String]>,
        writesEnabled: Bool = false,
        onSelectPhotos: @escaping ([PhotosPickerItem]) -> Void = { _ in },
        onSubmit: @escaping () -> Void = {}
    ) {
        self._location = location
        self._ruleInstructions = ruleInstructions
        self._uploadedPicURLs = uploadedPicURLs
        self.writesEnabled = writesEnabled
        self.onSelectPhotos = onSelectPhotos
        self.onSubmit = onSubmit
    }

    public var body: some View {
        Form {
            Section("merchantApply.location.title") {
                Button {
                    showMapPicker = true
                } label: {
                    LabeledContent {
                        if let address = location?.address {
                            Text(verbatim: address)
                        } else {
                            Text("merchantApply.location.choose")
                        }
                    } label: {
                        Text("merchantApply.location.field")
                    }
                }
            }

            Section {
                TextEditor(text: $ruleInstructions)
                    .frame(minHeight: 110)
                    .onChange(of: ruleInstructions) { _, newValue in
                        if newValue.count > maxRuleChars {
                            ruleInstructions = String(newValue.prefix(maxRuleChars))
                        }
                    }
            } header: {
                Text("merchantApply.rule.title")
            } footer: {
                HStack {
                    Text("merchantApply.rule.placeholder")
                        .cyText(.meta)
                    Spacer()
                    Text("\(ruleInstructions.count)/\(maxRuleChars)")
                        .cyText(.meta, monospacedDigit: true)
                }
            }

            Section {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: maxImages,
                    matching: .images
                ) {
                    Label("merchantApply.pic.upload", systemImage: "photo.on.rectangle.angled")
                        .cyText(.bodyCompact)
                }
                .onChange(of: pickerItems) { _, items in
                    onSelectPhotos(items)
                }

                if !uploadedPicURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CYSpacing.sm) {
                            ForEach(Array(uploadedPicURLs.enumerated()), id: \.offset) { idx, urlStr in
                                ZStack(alignment: .topTrailing) {
                                    CYCachedAsyncImage(urlStr, role: .shelf)
                                        .frame(width: 120, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                                    Button {
                                        uploadedPicURLs.remove(at: idx)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .cyText(.meta)
                                    }
                                    .accessibilityLabel(Text("删除场地照片 \(idx + 1)"))
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("merchantApply.pic.title")
            }

            Section {
                Button("common.submit", action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!writesEnabled || location == nil || ruleInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || uploadedPicURLs.isEmpty)
            } footer: {
                if !writesEnabled {
                    Text("merchantHost.workbench.gatedFooter")
                        .cyText(.meta)
                }
            }
        }
        .sheet(isPresented: $showMapPicker) {
            MerchantLocationMapPickerSheet(selection: $location) {
                showMapPicker = false
            }
        }
    }
}

/// R7-PC-B3-2 (fix-r9): MP `choosePoiForNode` → `pickLocation` (wx.chooseLocation) returns the chosen POI's
/// name / address / latitude / longitude (pages/topic/merchantapply/index.js:468-483). The pin follows a map tap
/// or a place-search result; 保存 stays disabled until a real point is chosen and no default coordinate is written.
private struct MerchantLocationMapPickerSheet: View {
    @Binding var selection: MerchantApplyLocationSelection?
    var onClose: () -> Void
    @State private var addressInput = ""
    @State private var picked: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition = .automatic
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var searchFailed = false

    init(selection: Binding<MerchantApplyLocationSelection?>, onClose: @escaping () -> Void) {
        self._selection = selection
        self.onClose = onClose
        if let current = selection.wrappedValue {
            let coordinate = CLLocationCoordinate2D(latitude: current.latitude, longitude: current.longitude)
            self._picked = State(initialValue: coordinate)
            self._addressInput = State(initialValue: current.address)
            self._position = State(initialValue: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        }
    }

    private var trimmedAddress: String {
        addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        picked != nil && !trimmedAddress.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MapReader { proxy in
                        Map(position: $position, interactionModes: [.pan, .zoom]) {
                            if let picked {
                                Marker(addressInput, coordinate: picked)
                            }
                        }
                        .frame(height: 240)
                        .onTapGesture { point in
                            guard let coordinate = proxy.convert(point, from: .local),
                                  CLLocationCoordinate2DIsValid(coordinate) else { return }
                            picked = coordinate
                        }
                        .accessibilityLabel(Text("merchantApply.location.mapHint"))
                        .accessibilityAddTraits(.allowsDirectInteraction)
                    }
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text(picked == nil ? LocalizedStringKey("merchantApply.location.mapHint") : LocalizedStringKey("merchantApply.location.pinned"))
                }

                if searching {
                    Section { ProgressView() }
                } else if searchFailed {
                    Section { Text("merchantApply.location.noResults").foregroundStyle(.secondary) }
                } else if !results.isEmpty {
                    Section("merchantApply.location.results") {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                            Button {
                                choose(item)
                            } label: {
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(verbatim: item.name ?? "")
                                        .foregroundStyle(.primary)
                                    if let line = item.placemark.title, !line.isEmpty {
                                        Text(verbatim: line)
                                            .cyText(.meta)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("merchantApply.location.addressDetail") {
                    TextField("merchantApply.location.choose", text: $addressInput, axis: .vertical)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("merchantApply.location.searchPrompt"))
            .onSubmit(of: .search) { Task { await runSearch() } }
            .navigationTitle(Text("merchantApply.location.choose"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        guard let picked, !trimmedAddress.isEmpty else { return }
                        selection = MerchantApplyLocationSelection(
                            address: trimmedAddress,
                            latitude: picked.latitude,
                            longitude: picked.longitude
                        )
                        onClose()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func choose(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        picked = coordinate
        let name = item.name ?? ""
        let line = item.placemark.title ?? ""
        addressInput = line.isEmpty || line == name ? name : (name.isEmpty ? line : name + " · " + line)
        position = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        results = []
    }

    @MainActor
    private func runSearch() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searching = true
        searchFailed = false
        defer { searching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = Array(response.mapItems.prefix(20))
            searchFailed = results.isEmpty
        } catch {
            results = []
            searchFailed = true
        }
    }
}

// MARK: - R7-PC-B1-12: Post-Purchase Pass Reveal & Marketing Consent

public struct TopicPostPurchaseRevealView: View {
    public let model: TopicPurchaseRevealCardModel
    @Binding public var marketingOptIn: Bool
    public var onWallet: () -> Void
    public var onPlay: () -> Void

    public init(
        model: TopicPurchaseRevealCardModel,
        marketingOptIn: Binding<Bool> = .constant(false),
        onWallet: @escaping () -> Void,
        onPlay: @escaping () -> Void
    ) {
        self.model = model
        self._marketingOptIn = marketingOptIn
        self.onWallet = onWallet
        self.onPlay = onPlay
    }

    public var body: some View {
        VStack(spacing: CYSpacing.lg) {
            if let cover = model.coverURL, !cover.isEmpty {
                CYCachedAsyncImage(cover, role: .cover)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            }

            VStack(spacing: CYSpacing.xs) {
                Text(model.kindText)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.brand)
                Text(model.topicName)
                    .cyText(.pageTitle)
                    .foregroundStyle(CYColor.textPrimary)
                Text("\(model.untilText) · \(model.daysText)")
                    .cyText(.bodyCompact, monospacedDigit: true)
                    .foregroundStyle(CYColor.textSecondary)
                if let line = model.durationLine, !line.isEmpty {
                    Text(line)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }

            if model.merchantRowID != nil {
                Toggle("topicReveal.marketingConsent", isOn: $marketingOptIn)
                    .cyText(.bodyCompact)
                    .padding(.horizontal, CYSpacing.md)
            }

            HStack(spacing: CYSpacing.sm) {
                Button("topicReveal.addToWallet", action: onWallet)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("topicReveal.startGame", action: onPlay)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(CYSpacing.lg)
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
    }
}

// MARK: - R7-PC-B2-2: Contact Host Button

public struct MerchantJoinContactHostButton: View {
    public let isBusy: Bool
    public var onTap: () -> Void

    public init(isBusy: Bool = false, onTap: @escaping () -> Void) {
        self.isBusy = isBusy
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack {
                if isBusy { ProgressView() }
                Label("merchantJoin.contactHost", systemImage: "message")
                    .cyText(.bodyMedium)
            }
        }
        .buttonStyle(.bordered)
        .disabled(isBusy)
    }
}

// MARK: - R7-PC-B1-22: Share Poster Card

public struct TopicSharePosterCardView: View {
    public let coverURL: String?
    public let topicName: String
    public let subtitle: String?
    public let shareURLString: String

    public init(coverURL: String?, topicName: String, subtitle: String? = nil, shareURLString: String) {
        self.coverURL = coverURL
        self.topicName = topicName
        self.subtitle = subtitle
        self.shareURLString = shareURLString
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if let coverURL, !coverURL.isEmpty {
                CYCachedAsyncImage(coverURL, role: .cover)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(topicName)
                        .cyText(.sectionTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                }
                Spacer()
                MPAsset.BrandLogo.cyLogoMark
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(Text("topicShare.qrCode"))
            }
        }
        .padding(CYSpacing.md)
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }
}
