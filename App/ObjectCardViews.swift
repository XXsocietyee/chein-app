import SwiftUI
import ImageIO

private struct ObjectCardMediaEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any ObjectCardImageLoading)? = nil
}
extension EnvironmentValues {
    var objectCardMedia: (any ObjectCardImageLoading)? {
        get { self[ObjectCardMediaEnvironmentKey.self] }
        set { self[ObjectCardMediaEnvironmentKey.self] = newValue }
    }
}

/// Host must observe the session revision and mount this destination with .id(reader.scope).
/// Reads the injected media loader or falls back to the environment `objectCardMedia` loader.
@MainActor struct ObjectCardsView: View {
    let reader: any ObjectCardReading
    var media: (any ObjectCardImageLoading)? = nil
    @State private var model = ObjectCardCollectionModel()
    @Environment(\.objectCardMedia) private var envMedia
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    /// OCARDS-2: card opened from the pile (offset into the loaded collection, with the scope it was tapped in).
    @State private var pileSelection: PileSelection?
    private struct PileSelection: Hashable, Identifiable { let id = UUID(); let offset: Int; let scope: UUID }
    @Namespace private var hero
    private var scope: UUID { reader.scope }
    private var effectiveMedia: (any ObjectCardImageLoading)? { media ?? envMedia }
    var body: some View {
        List {
            // OCARDS-4 (signed-out part): 去登录 opens 我的, like the MP access gate.
            if !reader.isAuthenticated {
                CYEmptyState(systemImage: "person.crop.circle", "objects.login",
                             actionTitle: rootTabSwitch.isAvailable ? "auth.signIn" : nil, actionIdentifier: "objects.signIn",
                             action: rootTabSwitch.isAvailable ? { rootTabSwitch(.mine) } : nil)
            }
            else if !reader.isConfigured { CYEmptyState(systemImage: "rectangle.stack", "objects.disabled") }
            else {
                Section {
                    Menu {
                        ForEach(ObjectCardCategory.allCases) { category in
                            Button(LocalizedStringKey(category.localizationKey)) { Task { await model.load(category: category, reader: reader) } }
                                .accessibilityIdentifier("objects.category.\(category.localizationKey)")
                        }
                    } label: {
                        // MP object-cards wxml:15: the filter shows the category's own icon (`cat/*.png`, MP assets).
                        Label {
                            Text(LocalizedStringKey(model.category.localizationKey))
                        } icon: {
                            model.category.mpIcon.resizable().scaledToFit().frame(width: 24, height: 24).accessibilityHidden(true)
                        }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.loading).accessibilityIdentifier("objects.filter")
                    if model.loading { CYSkeleton().accessibilityLabel(Text("objects.loading")) }
                    if model.failed, model.access == .denied {
                        Text("objectCards.denied").accessibilityIdentifier("objects.denied")
                    } else if model.failed {
                        Text(model.collection == nil ? "objects.failed" : "objects.filterFailed")
                            .accessibilityIdentifier("objects.failed")
                        CYPillButton("objects.retry") { Task { await model.load(category: model.category, reader: reader) } }
                    }
                }
                if model.loadedScope == scope, let collection = model.collection {
                    Section {
                        // OCARDS-6: the MP shows no total row; the count is implicit in the pile.
                        if collection.cards.isEmpty {
                            ObjectCardsEmptyTitle(isAllCategories: model.category == .all)
                                .accessibilityIdentifier("objects.empty")
                        }
                    }
                    if !collection.cards.isEmpty, !reduceMotion, !voiceOverEnabled {
                        // OCARDS-2: the MP heap of the latest 40; the grid below stays for VoiceOver and Reduce Motion.
                        Section {
                            ObjectCardPileView(cards: collection.cards) { offset in
                                pileSelection = .init(offset: offset, scope: model.loadedScope ?? scope)
                            }
                            .environment(\.objectCardMedia, effectiveMedia)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        }
                    } else if !collection.cards.isEmpty {
                        Section {
                            // Collection grid (one grid for every collection). Duplicate source rows keep their offset identity.
                            LazyVGrid(columns: CYCollectionGrid.columns(accessibility: dynamicTypeSize.isAccessibilitySize), alignment: .leading, spacing: CYCollectionGrid.spacing) {
                                ForEach(Array(collection.cards.enumerated()), id: \.offset) { offset, card in
                                    let capturedScope = model.loadedScope ?? scope
                                    NavigationLink {
                                        ObjectCardDetailView(card: card, reader: reader, expectedScope: capturedScope, media: effectiveMedia)
                                            .cyHeroDestination(offset, in: hero)
                                    } label: {
                                        ObjectCardTile(card: card, media: effectiveMedia, expectedScope: capturedScope, currentScope: { reader.scope })
                                            .cyHeroSource(offset, in: hero)
                                    }.buttonStyle(QuestifyCardButtonStyle())
                                        .accessibilityIdentifier("objects.card.\(card.id)")
                                }
                            }
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                        }
                    }
                }
            }
        }.cyGroupedSurface()
        .cyAlbumChildTitle("objects.title")
        .themeDomain(.player).privacySensitive()
        .task(id: scope) {
            if model.loadedScope != scope { model.invalidate() }
            if model.collection == nil && reader.isAuthenticated && reader.isConfigured {
                await model.load(category: model.category, reader: reader)
            }
        }
        .refreshable { await model.load(category: model.category, reader: reader) }
        .navigationDestination(item: $pileSelection) { selected in
            if selected.scope == reader.scope, model.loadedScope == selected.scope,
               let cards = model.collection?.cards, cards.indices.contains(selected.offset) {
                ObjectCardDetailView(card: cards[selected.offset], reader: reader, expectedScope: selected.scope, media: effectiveMedia)
            } else { Text("objects.sessionChanged") }
        }
        .onChange(of: scope) { _, _ in pileSelection = nil }
        .onDisappear { model.cancel() }
        .accessibilityIdentifier("objects.collection")
    }
}

@MainActor struct ObjectCardDetailView: View {
    let card: ObjectCard
    let reader: any ObjectCardReading
    let expectedScope: UUID
    var media: (any ObjectCardImageLoading)? = nil
    @State private var frame = 0
    @State private var drag: CGFloat = 0
    @State private var flipped = false
    @State private var renamedTitle: String?
    @Environment(\.locale) private var locale
    private var isFoil: Bool { card.cardStyle != "plain" }
    var body: some View {
        List {
            if reader.scope != expectedScope || !reader.isAuthenticated { Text("objects.sessionChanged") }
            else {
                Section {
                    // N-OCARDS (r10): an image row (drag still turns the frames) and the card's facts as a row below;
                    // no flip or foil (MP subpackageP3/object-cards/index/index.wxml detail).
                    artwork
                    Label(card.cardStyle == "plain" ? "objects.plain" : "objects.foil", systemImage: isFoil ? "sparkles" : "rectangle.portrait")
                        .foregroundStyle(.secondary)
                    if let origin = ObjectCardMediaPolicy.origin(card.sourceURL) {
                        LabeledContent { Text(verbatim: origin) } label: { Text("objects.source") }
                    }
                    if card.hasRotationFrames {
                        HStack {
                            Button("objects.previous") { move(-1) }.accessibilityIdentifier("objects.frame.previous")
                            Spacer()
                            Text("\(frame + 1) / \(card.frames.count)").monospacedDigit()
                            Spacer()
                            Button("objects.next") { move(1) }.accessibilityIdentifier("objects.frame.next")
                        }.buttonStyle(.bordered).frame(minHeight: 44)
                    }
                    if !card.caption.isEmpty { Text(verbatim: card.caption) }
                }
                Section("objects.information") {
                    HStack {
                        LabeledContent("objects.name", value: renamedTitle ?? card.title)
                        // BL-79: rename; the server's saved title replaces the shown one.
                        ObjectCardRenameButton(cardID: Int(card.id) ?? 0, title: renamedTitle ?? card.title) { renamedTitle = $0 }
                    }
                    if !card.category.isEmpty {
                        LabeledContent("objects.category") {
                            if let category = ObjectCardCategory(rawValue: card.category) { Text(LocalizedStringKey(category.localizationKey)) }
                            else { Text(verbatim: card.category) }
                        }
                    }
                    if !card.place.isEmpty { LabeledContent("objects.place", value: card.place) }
                    // OCARDS-7 (MP wxml:65-86): 名称 / 分类 / 地点 (+ 3D 生成中) only; style and source sit on the card's back.
                    if card.generating { Label("objects.generating", systemImage: "hourglass") }
                }
            }
        }.cyGroupedSurface().cyPageTitle("objects.item").privacySensitive()
            .accessibilityIdentifier("objects.detail")
    }
    private var artwork: some View {
        ObjectCardArtwork(url: card.frame(at: frame), label: card.title, media: media,
            expectedScope: expectedScope, currentScope: { reader.scope })
            .frame(maxWidth: .infinity, minHeight: 240)
            .accessibilityValue(card.hasRotationFrames ? "\(frame + 1) / \(card.frames.count)" : "")
            .accessibilityAdjustableAction { direction in
                guard card.hasRotationFrames else { return }
                switch direction { case .increment: move(1); case .decrement: move(-1); @unknown default: break }
            }
            .gesture(DragGesture().onChanged { value in
                guard card.hasRotationFrames else { return }
                let delta = value.translation.width - drag
                let steps = Int(delta / 8)
                if steps != 0 { drag += CGFloat(steps * 8); move(steps) }
            }.onEnded { _ in drag = 0 })
    }
    private var facts: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack {
                Text(card.cardStyle == "plain" ? "objects.plain" : "objects.foil").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Spacer(minLength: CYSpacing.sm)
                Image(systemName: isFoil ? "sparkles" : "rectangle.portrait").foregroundStyle(isFoil ? CYAlbumMotion.gold : CYColor.textTertiary).accessibilityHidden(true)
            }
            Divider()
            Text(verbatim: card.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            if !card.category.isEmpty {
                CYFactRow(label: Text("objects.category"), value: card.category)
            }
            if !card.place.isEmpty { CYFactRow(label: Text("objects.place"), value: card.place) }
            if let origin = ObjectCardMediaPolicy.origin(card.sourceURL) { CYFactRow(label: Text("objects.source"), value: origin) }
            if !card.caption.isEmpty {
                Text(verbatim: card.caption).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text("objects.tapToTurnBack")  // OCARDS-5: catalog key
                .cyText(.caption).foregroundStyle(CYColor.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .cyAlbumCard(padding: CYSpacing.lg)
    }
    private func move(_ step: Int) {
        guard card.hasRotationFrames else { return }
        frame = ((frame + step) % card.frames.count + card.frames.count) % card.frames.count
    }
}

/// Collection tile: artwork on a raised plate, title, one state chip, place. Foil cards catch the light; a generating card says so.
@MainActor struct ObjectCardTile: View {
    let card: ObjectCard
    var media: (any ObjectCardImageLoading)? = nil
    let expectedScope: UUID
    let currentScope: () -> UUID
    private var isFoil: Bool { card.cardStyle != "plain" }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised)
                ObjectCardArtwork(url: card.thumbnail, label: card.title, media: media, expectedScope: expectedScope, currentScope: currentScope)
                    .padding(CYSpacing.sm)
            }
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            Text(verbatim: card.title)
                .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            if card.generating { CYStatusChip("objects.generating", tone: .info, systemImage: "hourglass") }
            else if isFoil { CYStatusChip("objects.foil", tone: .info, systemImage: "sparkles") }
            else { CYStatusChip("objects.plain") }
            if !card.place.isEmpty {
                Text(verbatim: card.place).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyAlbumCard()
        .accessibilityElement(children: .combine)
    }
}

/// No AsyncImage bypass: optional loader enforces exact origin, stream size and redirect limits.
/// Retained pixels are never shown after a scope or URL change, including same-account relogin.
@MainActor struct ObjectCardArtwork: View {
    let url: String
    let label: String
    let media: (any ObjectCardImageLoading)?
    let expectedScope: UUID
    let currentScope: () -> UUID
    @State private var image: UIImage?
    @State private var loadedKey: Key?
    @State private var failed = false
    @State private var loading = false
    @State private var generation = UUID()
    private struct Key: Hashable { let url: String; let scope: UUID }
    private var key: Key { Key(url: url, scope: expectedScope) }
    var body: some View {
        VStack(spacing: 8) {
            if currentScope() != expectedScope { Text("objects.sessionChanged") }
            else if let image, loadedKey == key { Image(uiImage: image).resizable().scaledToFit() }
            else {
                Image(systemName: "photo").cyText(.display).accessibilityHidden(true)
                if loading { ProgressView("objects.loading") }
                else { Text(media == nil ? "objects.mediaDisabled" : failed ? "objects.mediaFailed" : "objects.noImage").cyText(.meta) }
            }
        }.accessibilityElement(children: .combine).accessibilityLabel(Text(verbatim: label))
            .accessibilityValue(Text(loading ? "objects.loading" : media == nil ? "objects.mediaDisabled" : failed ? "objects.mediaFailed" : image == nil ? "objects.noImage" : ""))
            .task(id: key) { await load() }
            .onDisappear { generation = UUID(); image = nil; loadedKey = nil; loading = false }
    }
    private func load() async {
        generation = UUID(); let run = generation
        image = nil; loadedKey = nil; failed = false; loading = false
        guard let media, !url.isEmpty, currentScope() == expectedScope else { return }
        let captured = key; loading = true
        defer { if run == generation { loading = false } }
        do {
            let data = try await media.image(url: url)
            try Task.checkCancellation()
            guard data.count <= ObjectCardMediaPolicy.maximumBytes,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  width.doubleValue > 0, height.doubleValue > 0,
                  width.doubleValue * height.doubleValue <= 32_000_000,
                  let decoded = UIImage(data: data) else { throw ObjectCardMediaFailure.unsupportedImage }
            guard !Task.isCancelled, run == generation, captured == key, currentScope() == expectedScope else { return }
            loadedKey = captured; image = decoded
        } catch is CancellationError { }
        catch { if run == generation, captured == key, currentScope() == expectedScope { failed = true } }
    }
}

extension AppSession {
    func makeObjectCardImageLoader() -> ObjectCardBoundedImageLoader? {
        var origins = Set<String>()
        if let baseURL = regionalConfiguration?.apiConfiguration?.baseURL {
            origins.formUnion(RetainedImageOrigin.configured(
                apiBase: baseURL,
                extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String
            ))
        }
        for host in playKitArtworkHosts where !host.isEmpty {
            if let origin = ObjectCardMediaPolicy.origin("https://" + host) {
                origins.insert(origin)
            }
        }
        guard !origins.isEmpty else { return nil }
        return ObjectCardBoundedImageLoader(policy: .init(approvedOrigins: origins))
    }
}



/// MP object-cards `CAT_ICON` (index.js:18-22): one Fluent 3D icon per category, shipped as MP assets.
extension ObjectCardCategory {
    var mpIcon: Image {
        switch self {
        case .all: MPAsset.FeatureIcon.all
        case .electronics: MPAsset.FeatureIcon.electronics
        case .clothing: MPAsset.FeatureIcon.clothing
        case .bags: MPAsset.FeatureIcon.bags
        case .food: MPAsset.FeatureIcon.subpackageP3ImagesCatFood
        case .books: MPAsset.FeatureIcon.books
        case .toys: MPAsset.FeatureIcon.toys
        case .household: MPAsset.FeatureIcon.daily
        case .other: MPAsset.FeatureIcon.subpackageP3ImagesCatOther
        }
    }
}
