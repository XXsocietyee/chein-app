import SwiftUI

@MainActor
struct DiscoveryTemplateDetailView: View {
    let id: Int
    let reader: any DiscoveryReading
    let authoringFactory: ((DiscoveryPlayTemplate) -> TemplateAuthoringCoordinator)?
    let authoringRevision: UInt64
    let authoringCompletion: TemplateAuthoringCompletionContext?
    let imageReader: any RetainedPublicImageReading
    @StateObject private var detail = DiscoveryLoader<DiscoveryPlayTemplateRead>()
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @State private var galleryScope = UUID()
    @State private var loadedKey: RequestKey?
    @State private var readerChange: UInt64 = 0
    @State private var adoption: Adoption?
    @State private var pendingAdoption: Adoption?
    @State private var showsAdoptLogin = false
    @State private var tab: TemplateDetailTab = .details
    @State private var capabilityPreview: TemplateNodePreviewState?
    @State private var toastMessage: String?
    @State private var rulesExpanded = false
    /// Caller override. Nil uses `PublicContentShareLink.discoveryTemplate` when that path is already parsed.
    var shareURL: URL? = nil
    /// R8-PC-A6-1, MP templatedetail.js:202,465: a `readonly=1` link keeps 应用 visible but answers 当前身份不能编辑模板.
    private(set) var readonly = false
    func readonlyLink(_ value: Bool) -> DiscoveryTemplateDetailView { var copy = self; copy.readonly = value; return copy }
    private struct Adoption: Identifiable, Hashable {
        let id = UUID()
        let source: DiscoveryPlayTemplate
        let key: RequestKey
        nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    private func resumePendingAdoption() {
        guard let pending = pendingAdoption, loadedKey == requestKey, pending.source.id == id,
              (reader as? AppSession)?.isSignedIn == true else { return }
        pendingAdoption = nil
        adoption = Adoption(source: pending.source, key: requestKey)
    }
    private struct RequestKey: Hashable {
        let id: Int
        let reader: ObjectIdentifier
        let scope: String
        let authoringRevision: UInt64
    }
    private var requestKey: RequestKey {
        _ = readerChange // Read-only ObservableObject dependencies must invalidate this view too.
        return .init(id: id, reader: ObjectIdentifier(reader), scope: reader.discoveryPresentationIdentity,
                     authoringRevision: authoringRevision)
    }

    init(id: Int, reader: any DiscoveryReading, authoringFactory: ((DiscoveryPlayTemplate) -> TemplateAuthoringCoordinator)? = nil, authoringRevision: UInt64 = 0, imageReader: (any RetainedPublicImageReading)? = nil, authoringCompletion: TemplateAuthoringCompletionContext? = nil) {
        self.id = id; self.reader = reader; self.authoringFactory = authoringFactory; self.authoringRevision = authoringRevision
        self.imageReader = imageReader ?? RetainedPublicImageReader()
        self.authoringCompletion = authoringCompletion
    }

    var body: some View {
        Group {
            if !reader.isConfigured {
                CYEmptyState(systemImage: "network.slash", "discovery.unavailable", detail: "auth.notConfigured", kind: .offline)
            } else if detail.isLoading || loadedKey != requestKey {
                CYSkeleton().padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
            } else if let error = detail.error {
                DiscoveryErrorView(error: error) { Task { await reload() } }
            } else if let read = detail.value {
                let item = read.template
                let parity = read.extras != nil ? DiscoveryPlayTemplateDetailPresentation(read, ownScope: false) : nil
                List {
                    // Mini-program `xb-head` → `xb-cta` → 详情 / 能力 tabs (B57). The head and the tabs are the same on both tabs.
                    Section {
                        TemplateXbHead(title: item.title.isEmpty ? Text("discovery.untitledPlay") : Text(verbatim: item.title),
                                       publisher: publisherText(parity, item: item), official: isOfficial(parity)) {
                            // MP `detailCover` (templatedetail.js:507): a shelf play's bundled cover first, then the template's own
                            // cover (PC-A-6-1), generated art while loading or without one.
                            if let art = TemplateShelfArt.gameCover(item.title) {
                                art.resizable().scaledToFill().accessibilityHidden(true)
                            } else if let url = TemplateBrowserPort.coverURL(item.imgUrl) {
                                PlayerFeedRemoteImage(url: url, maxPixel: 512, placeholder: {
                                    E1CoverArt(seed: item.title, symbol: "sparkles", debugLabel: false, symbolPoint: CGPoint(x: 0.5, y: 0.5))
                                }, failure: {
                                    E1CoverArt(seed: item.title, symbol: "sparkles", debugLabel: false, symbolPoint: CGPoint(x: 0.5, y: 0.5))
                                })
                                .accessibilityHidden(true)
                            } else {
                                E1CoverArt(seed: item.title, symbol: "sparkles", debugLabel: false, symbolPoint: CGPoint(x: 0.5, y: 0.5))
                            }
                        }
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: CYSpacing.md, trailing: CYSpacing.lg))
                        HStack(spacing: CYSpacing.md) {
                            if authoringFactory != nil {
                                Button {
                                    guard loadedKey == requestKey, reader.isConfigured,
                                          authoringCompletion?.isCurrent() != false else { return }
                                    if readonly {
                                        toastMessage = appLocalized("discovery.templateDetail.readonly", locale: locale)
                                        return
                                    }
                                    // R7-PC-A6-2 (r1 PC-A-6-3): MP `ensureLogin` before 应用 — a guest goes to sign-in.
                                    // R7-PC-A6-2 (r8, MP `ensureLoginFor` callback): sign in over this page, then resume 应用.
                                    if (reader as? AppSession)?.isSignedIn == false {
                                        toastMessage = appLocalized("discovery.adopt.signIn", locale: locale)
                                        pendingAdoption = Adoption(source: item, key: requestKey)
                                        showsAdoptLogin = true
                                        return
                                    }
                                    adoption = Adoption(source: item, key: requestKey)
                                } label: { TemplateXbApplyLabel() }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("templateAuthor.adopt")
                            } else {
                                Spacer(minLength: 0)
                            }
                            TemplateXbShareButton(url: shareURL ?? PublicContentShareLink.discoveryTemplate(id: id), label: "u10.template.share")
                        }
                        .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: CYSpacing.lg))
                        TemplateAdoptEntry(sourceTemplateID: id) // server adopt-draft; hidden without the G5 bundle
                        TemplateXbTabs(selection: $tab)
                            .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: 0, trailing: CYSpacing.lg))
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    if tab == .details {
                        DiscoveryPlayMetadata(item: item).discoveryCardRow()
                        DiscoveryPlayTemplatePresentationView(presentation: .init(item), scope: galleryScope, imageReader: imageReader, showsPublisher: false)
                        textSection(parity?.isTopicTemplate == true ? "u10.template.story" : "discovery.introduction", text: item.description, art: MPAsset.FeatureIcon.book)
                        if let parity, !parity.ruleSteps.isEmpty {
                            Section {
                                // R7-PC-A6-4 (MP templatedetail.wxml:96-110): the step list clamps (3 steps) with 更多 / 收起.
                                let clampsRules = parity.ruleSteps.count > 3
                                ForEach(Array(parity.ruleSteps.enumerated().prefix(clampsRules && !rulesExpanded ? 3 : parity.ruleSteps.count)), id: \.offset) { index, step in
                                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                                        Text(verbatim: String(index + 1)).cyText(.label, monospacedDigit: true)
                                            .frame(width: 28, height: 28).background(CYColor.bgSurfaceStrong, in: Circle())
                                        Text(verbatim: step).cyText(.body).foregroundStyle(palette.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("discovery.templateDetail.rule.\(index)")
                                }
                                if clampsRules {
                                    Button(rulesExpanded ? "discovery.text.less" : "discovery.text.more") { rulesExpanded.toggle() }
                                        .cyText(.label).frame(minHeight: CYSpacing.minTouchTarget)
                                        .accessibilityIdentifier("discovery.templateDetail.rules.more")
                                }
                            } header: { DiscoverySectionHeader("discovery.rules", art: MPAsset.FeatureIcon.interaction) }
                                .discoveryCardRow()
                        } else {
                            textSection("discovery.rules", text: item.ruleInstructions, art: MPAsset.FeatureIcon.interaction)
                        }
                        if let parity {
                            // Carries 怎么验证, 分类与适用场景, 所需物料, 评价 and the 不能直接开团 notice.
                            if parity.materialChips.isEmpty { textSection("discovery.materials", text: item.requiredMaterials, art: MPAsset.FeatureIcon.flashlight) }
                            DiscoveryTemplateDetailParitySections(presentation: parity)
                        } else {
                            textSection("discovery.location", text: item.usageLocation)
                            textSection("discovery.materials", text: item.requiredMaterials)
                            if let verification = item.verification {
                                Section { Text(verification.label).cyText(.body) } header: { DiscoverySectionHeader("discovery.verification") }.discoveryCardRow()
                            }
                        }
                    } else {
                        Section {
                            TemplateCapabilityRows(rows: capabilityRows(parity, item: item)) { action in
                                if action == "preview", let node = parity?.nodePreview { capabilityPreview = TemplateNodePreviewState(preview: node) }
                            }
                            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: CYSpacing.lg))
                        }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        if parity != nil { DiscoveryTemplateNoticeSection() }
                    }
                }
                .scrollContentBackground(.hidden)
                .cyDomainPageBackground()
                .refreshable { await reload() }
                .accessibilityIdentifier("discovery.detail.content")
            }
        }
        .appNavigationTitle("discovery.playDetails")
        .navigationBarTitleDisplayMode(.inline)
        .cyToast(verbatimMessage: $toastMessage)
        .sheet(isPresented: $showsAdoptLogin, onDismiss: {
            // Resume once signed in. Signing in changes the read scope, so wait for the re-read of this template if needed.
            guard (reader as? AppSession)?.isSignedIn == true else { pendingAdoption = nil; return }
            resumePendingAdoption()
        }) {
            if let session = reader as? AppSession {
                Group { LoginView(intent: .player).environmentObject(session) }
                    .presentationDetents([.large]).presentationDragIndicator(.visible)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                UGCSafetyMenuButton(
                    presentation: UGCReportPresentationTarget(
                        target: .template(id: id, personal: false),
                        subjectTitle: detail.value?.template.title
                    )
                )
                .accessibilityIdentifier("discovery.template.safetyMenu")
            }
        }
        .cyPushedChrome(domain: .player)
        .task(id: requestKey) { if reader.isConfigured { await reload() } }
        .onReceive(reader.discoveryPresentationChanges) { readerChange &+= 1 }
        .onChange(of: requestKey) { _, _ in adoption = nil; tab = .details }
        .onChange(of: loadedKey) { _, _ in if !showsAdoptLogin { resumePendingAdoption() } }
        .sheet(item: $capabilityPreview) { state in
            TemplateNodePreviewSheet(state: state) { capabilityPreview = nil }
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.player)
        }
        .navigationDestination(item: $adoption) { selected in
            if let authoringFactory {
                DiscoveryTemplateAdoptionDestination(factory: { authoringFactory(selected.source) },
                    sessionRevision: selected.key.authoringRevision, metadataReader: reader, completion: authoringCompletion,
                    isCurrent: { adoption?.id == selected.id && loadedKey == selected.key &&
                        requestKey == selected.key && reader.isConfigured })
                    .id(selected.id)
                    .cyPushedChrome(domain: .topicEditor)
            }
        }
    }
    private func publisherText(_ parity: DiscoveryPlayTemplateDetailPresentation?, item: DiscoveryPlayTemplate) -> Text? {
        guard let parity else {
            if let name = item.publisher?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return Text(verbatim: name) }
            return nil
        }
        switch parity.publisher {
        case .named(let name, _): return Text(verbatim: name)
        case .mine: return Text("discovery.templateDetail.publisher.mine")
        case .creator: return Text("discovery.templateDetail.publisher.creator")
        case .platform: return Text("discovery.templateDetail.publisher.platform")
        }
    }
    private func isOfficial(_ parity: DiscoveryPlayTemplateDetailPresentation?) -> Bool {
        switch parity?.publisher {
        case .named(_, let official)?: return official
        case .platform?: return true
        default: return false
        }
    }
    /// 能力 rows in the mini-program order: 方式 (with 节点预览), 场景, 来源.
    private func capabilityRows(_ parity: DiscoveryPlayTemplateDetailPresentation?, item: DiscoveryPlayTemplate) -> [TemplateCapabilityRow] {
        var rows: [TemplateCapabilityRow] = []
        var way = parity?.verificationMethodText.map(Self.splitChips) ?? []
        if parity?.nodePreview != nil {
            way.append(.init(text: appLocalized("u10.template.cap.preview", locale: locale), action: "preview"))
        }
        if !way.isEmpty { rows.append(.init(key: "way", label: "u10.template.cap.way", chips: way)) }
        let scene = parity?.sceneChips.map { TemplateCapabilityRow.Chip(text: $0) } ?? Self.splitChips(item.usageLocation ?? "")
        if !scene.isEmpty { rows.append(.init(key: "scene", label: "u10.template.cap.scene", chips: scene)) }
        if let name = item.publisher?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            rows.append(.init(key: "from", label: "u10.template.cap.from", chips: [.init(text: name)]))
        }
        return rows
    }
    private static func splitChips(_ value: String) -> [TemplateCapabilityRow.Chip] {
        value.components(separatedBy: CharacterSet(charactersIn: ",，、;；/|\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { TemplateCapabilityRow.Chip(text: $0) }
    }
    @ViewBuilder private func textSection(_ title: LocalizedStringKey, text: String?, art: Image? = nil) -> some View {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // R7-PC-A6-4 (r1 PC-A-6-5): MP clamps 简介 / 规则 to 4 lines with 更多 / 收起.
            Section { DiscoveryClampedText(text: text) } header: { DiscoverySectionHeader(title, art: art) }
                .discoveryCardRow()
        }
    }
    private func reload() async {
        let requested = requestKey
        galleryScope = UUID(); loadedKey = nil
        await detail.load {
            let read = try await reader.discoveryPlayTemplateRead(id: requested.id)
            guard !Task.isCancelled, requested.scope == reader.discoveryPresentationIdentity else { throw CancellationError() }
            let value = read.template
            guard value.id == requested.id else { throw APIError.malformedResponse }
            return read
        }
        guard !Task.isCancelled, requested == requestKey else { return }
        loadedKey = requested
    }
}

/// StateObject's deferred factory creates exactly one coordinator for this pushed visit.
/// Re-rendering a detail must not reopen the adopted draft or replace a pending request.
@MainActor final class DiscoveryTemplateAdoptionOwner: ObservableObject {
    let coordinator: TemplateAuthoringCoordinator
    init(factory: () -> TemplateAuthoringCoordinator) { coordinator = factory() }
}

@MainActor struct DiscoveryTemplateAdoptionDestination: View {
    let sessionRevision: UInt64
    let metadataReader: any DiscoveryReading
    let completion: TemplateAuthoringCompletionContext?
    let isCurrent: () -> Bool
    @StateObject private var owner: DiscoveryTemplateAdoptionOwner
    init(factory: @escaping () -> TemplateAuthoringCoordinator, sessionRevision: UInt64,
         metadataReader: any DiscoveryReading, completion: TemplateAuthoringCompletionContext?,
         isCurrent: @escaping () -> Bool) {
        self.sessionRevision = sessionRevision; self.metadataReader = metadataReader
        self.completion = completion; self.isCurrent = isCurrent
        _owner = StateObject(wrappedValue: DiscoveryTemplateAdoptionOwner(factory: factory))
    }
    var body: some View {
        Group {
            if isCurrent(), completion?.isCurrent() != false {
                if let completion {
                    TemplateAuthoringSaveFlow(coordinator: owner.coordinator, sessionRevision: sessionRevision,
                        metadataReader: metadataReader, imageSelectionApproved: { false }, library: completion.library)
                        .modifier(TemplateAuthoringPublishCompletion(coordinator: owner.coordinator, library: completion.library))
                } else {
                    // A standalone read/fixture caller has no authority to construct an owned shelf.
                    TemplateAuthoringView(coordinator: owner.coordinator, sessionRevision: sessionRevision, metadataReader: metadataReader)
                }
            } else { Text("discovery.templateSessionChanged") }
        }.accessibilityIdentifier("templateAuthor.adoptionFlow")
    }
}

/// Uses only the server's public template projection. Included games are inert previews.
@MainActor
struct DiscoveryTopicTemplatePreview: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.topicTemplateCopiedDestination) private var copiedDestination
    @State private var detail: PublicTopicTemplateCoordinator
    @State private var tab: TemplateDetailTab = .details
    @State private var openingExpanded = false
    /// R7-PC-A8-2 (MP topic-detail js:281 `previewNode`): a node image opens the full-screen gallery over all node images.
    @State private var nodeGallery: NodeGallerySelection?
    private struct NodeGallerySelection: Identifiable { let id = UUID(); let snapshot: MediaGallerySnapshot }
    /// Caller override. Nil asks the existing parsers; an unparsed topic path copies its mini-program path and has no public URL.
    var shareURL: URL? = nil
    var scope: String? = nil
    init(coordinator: PublicTopicTemplateCoordinator) { _detail = State(initialValue: coordinator) }
    /// A parsed topic path would be a universal link. This path is not parsed, so the share key copies the mini-program path.
    private func topicShareOffer(_ id: Int) -> (url: URL?, copyText: String?) {
        if let shareURL { return (shareURL, nil) }
        if let url = PublicContentShareLink.topicTemplate(id: id) { return (url, nil) }
        return (nil, PublicContentShareLink.topicTemplateCopyText(id: id))
    }
    var body: some View {
        Group {
            if detail.isInvalidated {
                ContentUnavailableView("discovery.templateSessionChanged", systemImage: "person.crop.circle.badge.exclamationmark",
                                       description: Text("discovery.templateReopen"))
            } else if detail.isLoading {
                // R7-PC-A7-2 (r1 PC-A-7-4): MP skeleton, not a centred spinner.
                CYSkeleton().padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel(Text("discovery.loading"))
            } else if let error = detail.error {
                DiscoveryErrorView(error: error) { Task { await detail.load() } }
            } else if let item = detail.value {
                List {
                    // B78 topic-detail (owner V-24): same chrome as the play detail — head, 应用 + share, 详情 / 能力.
                    Section {
                        TemplateXbHead(title: (item.name ?? "").isEmpty ? Text("discovery.untitledTopic") : Text(verbatim: item.name ?? ""),
                                       publisher: topicAuthor(item), official: false, subtitle: item.subtitle) {
                            // MP topic-detail js:169 `art.topicArt(info.name)`: a known topic name shows its bundled cover.
                            if let art = TemplateShelfArt.topicCover(item.name) {
                                art.resizable().scaledToFill().accessibilityHidden(true)
                            } else if QuestifyCardArtwork.safeURL(item.imgUrl) != nil {
                                E1CoverArt(seed: item.name ?? "topic", symbol: "building.2", imageURL: item.imgUrl, debugLabel: false,
                                           symbolPoint: CGPoint(x: 0.5, y: 0.5))
                            } else {
                                // MP asset (topic-detail/index.wxml:31): no cover → the city 3D art `art/cat/city.png`.
                                MPAsset.FeatureIcon.pagesTemplatedetailArtCatCity.resizable().scaledToFit().padding(CYSpacing.sm)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(CYColor.bgRaised)
                                    .accessibilityHidden(true)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: CYSpacing.md, trailing: CYSpacing.lg))
                        let topicShare = topicShareOffer(item.id)
                        let hasShare = topicShare.url != nil || topicShare.copyText != nil
                        // R7-PC-A8-5 (owner V-24, MP `xb-cta`): 用这个模板 and share sit in one head row. The live adoption
                        // flow keeps its own section below (it carries plan + progress state).
                        if !TopicTemplateUseFactory.isLive {
                            HStack(spacing: CYSpacing.sm) {
                                Button {} label: {
                                    Text("topicTemplate.useCta").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                                }
                                .buttonStyle(.cyPrimary(fullWidth: true))
                                .disabled(true)
                                .accessibilityIdentifier("topicTemplate.use.unavailable")
                                if hasShare { TemplateXbShareButton(url: topicShare.url, copyText: topicShare.copyText, label: "u10.template.shareTopic") }
                            }
                            Text("topicTemplate.useUnavailable").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        } else if hasShare {
                            HStack { Spacer(minLength: 0); TemplateXbShareButton(url: topicShare.url, copyText: topicShare.copyText, label: "u10.template.shareTopic") }
                        }
                        TemplateXbTabs(selection: $tab)
                            .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: 0, trailing: CYSpacing.lg))
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    // Mini topic-detail "应用". Hidden while the write is gated.
                    if TopicTemplateUseFactory.isLive {
                        Section {
                            TopicTemplateUseSection(templateID: item.id, scope: nil, readOnly: false,
                                                    plan: TopicTemplateAdoptionPlan(delivery: item.contentDelivery)) { topicID in
                                copiedDestination?(topicID)
                            }
                        }.discoveryCardRow()
                    }
                    // PC-A-7-3: when the write is gated the main action is never hidden; it is the disabled head-row CTA above.
                    if tab == .details {
                        topicDetails(item)
                    } else {
                        topicCapabilities(item)
                    }
                }
                .scrollContentBackground(.hidden)
                .cyDomainPageBackground()
                .refreshable { await detail.load() }
                .accessibilityIdentifier("discovery.topicPreview.content")
            } else {
                CYSkeleton().padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel(Text("discovery.loading"))
            }
        }
        .appNavigationTitle("discovery.topicPreview")
        .toolbar {
            if let item = detail.value {
                ToolbarItem(placement: .topBarTrailing) {
                    UGCSafetyMenuButton(
                        presentation: UGCReportPresentationTarget(
                            target: .template(id: item.id, personal: true),
                            subjectTitle: item.name
                        )
                    )
                    .accessibilityIdentifier("discovery.topicTemplate.safetyMenu")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $nodeGallery) { selected in
            NativeMediaGallery(snapshot: selected.snapshot, titleKey: "u10.template.nodes", reader: RetainedPublicImageReader())
        }
        .task { await detail.load() }
        .onDisappear { detail.clear() }
    }
    @ViewBuilder private func optionalText(_ value: String?) -> some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(value).cyText(.meta).foregroundStyle(palette.textSecondary).textSelection(.enabled) }
    }
    /// R8-PC-A8-1, MP topic-detail index.js:182 `author || '创作者'` (PG-012: a missing author never poses as official).
    private func topicAuthor(_ item: PublicTopicTemplateDetail) -> Text {
        if let author = item.author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty { return Text(verbatim: author) }
        return Text("discovery.templateDetail.publisher.creator")
    }
    private func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
    /// 详情: 剧情 (opening + each chapter: number, name, one line), stats, 节点 cards, recruitment (merchant viewers only).
    @ViewBuilder private func topicDetails(_ item: PublicTopicTemplateDetail) -> some View {
        if nonempty(item.description) != nil || !item.chapters.isEmpty {
            Section {
                if let opening = nonempty(item.description) {
                    Text(verbatim: opening).cyText(.body).foregroundStyle(palette.textSecondary)
                        .textSelection(.enabled).lineLimit(openingExpanded ? nil : 4)
                    if opening.count > 90 {
                        Button(openingExpanded ? "u10.template.cap.collapse" : "u10.template.cap.expand") {
                            openingExpanded.toggle()
                        }
                        .cyText(.meta, weight: .semibold)
                        .foregroundStyle(palette.brand)
                        .accessibilityIdentifier("discovery.topicDetail.openingToggle")
                    }
                }
                ForEach(Array(item.chapters.enumerated()), id: \.element.id) { index, chapter in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                            if !TopicXcxFacts.hidesGeneratedChapterOrdinal(chapter.name ?? "") {
                                Text("u10.template.chapterNo \(index + 1)").cyText(.meta).foregroundStyle(palette.textSecondary)
                            }
                            DiscoveryTitle(text: chapter.name ?? "", fallback: "discovery.publicChapter").cyText(.cardTitle)
                        }
                        let guide = TopicXcxFacts.chapterGuide(description: chapter.description)
                        if !guide.isEmpty {
                            Text(verbatim: guide).cyText(.meta).foregroundStyle(palette.textSecondary).lineLimit(2)
                        }
                        // PC-A-8-2 (owner 2026-11-14 「太复杂」): a chapter card is number + name + one line; the stop
                        // path and the stop count live only in 能力, grouped by chapter.
                        if let status = chapter.recruitStatus {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("discovery.publicRecruitment").cyText(.cardTitle)
                                optionalText(status.state)
                                if let count = status.remainingMerchantCount {
                                    LabeledContent("discovery.publicRemaining", value: String(count))
                                }
                            }.accessibilityIdentifier("discovery.publicRecruitment")
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            } header: { TemplateXbSectionTitle(title: "u10.template.story", systemImage: "book", art: MPAsset.FeatureIcon.book) }
                .discoveryCardRow()
        }
        let free = item.mode == "FREE_EXPLORE"
        Section {
            if !free {
                HStack(alignment: .top) {
                    topicStat(Text(verbatim: String(item.chapters.count)), label: "discovery.templateDetail.stat.chapters")
                    topicStat(TopicXcxDurationText(seconds: item.totalTime), label: "discovery.templateDetail.stat.totalTime")
                }
            }
            TopicTotalStops(count: item.locationCount, identifier: "discovery.publicTotalStops")
        }.discoveryCardRow()
        let nodes = item.chapters.flatMap(\.nodes)
        if !nodes.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        let gallery = nodes.compactMap { nonempty($0.imgUrl) }.filter { QuestifyCardArtwork.safeURL($0) != nil }
                        ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                let cover = E1CoverArt(seed: (node.name ?? "") + String(index), symbol: "mappin.and.ellipse", imageURL: node.imgUrl, debugLabel: false)
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                                if let raw = nonempty(node.imgUrl), let galleryIndex = gallery.firstIndex(of: raw) {
                                    Button { nodeGallery = NodeGallerySelection(snapshot: .init(sources: gallery, selectedIndex: galleryIndex)) } label: { cover }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(Text("media.destination.openImage"))
                                        .accessibilityIdentifier("discovery.topicDetail.nodeImage.\(index)")
                                } else {
                                    cover.accessibilityHidden(true)
                                }
                                (nonempty(node.name).map { Text(verbatim: $0) } ?? Text("u10.template.nodeNo \(index + 1)"))
                                    .cyText(.label).foregroundStyle(palette.textPrimary).cyWrapText()
                                if let teaser = nonempty(node.hookTeaser) {
                                    Text(verbatim: teaser).cyText(.meta).foregroundStyle(palette.textSecondary).cyWrapText()
                                }
                                // U02-05: credit for the first 8 node images only (mini _loadCredits).
                                if index < 8, let reference = nonempty(node.imgUrl), TopicTemplateAdoptionFactory.attributionIsLive {
                                    TopicTemplateNodeCredit(reference: reference)
                                }
                            }
                            .frame(width: 150, alignment: .leading)
                            .accessibilityElement(children: .contain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: 0))
            } header: { TemplateXbSectionTitle(title: "u10.template.nodes", systemImage: "safari", art: MPAsset.FeatureIcon.explore) }
                .discoveryCardRow()
                .accessibilityIdentifier("discovery.topicDetail.nodes")
        }
        if item.chapters.isEmpty && item.games.isEmpty {
            Section { Text("discovery.publicEmpty").cyText(.body).foregroundStyle(palette.textSecondary) }.discoveryCardRow()
        }
        if let medal = item.finishMedalName {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: medal).cyText(.cardTitle)
                    Text("u10.template.medalHint").cyText(.meta).foregroundStyle(palette.textSecondary)
                }.accessibilityElement(children: .combine)
            } header: { TemplateXbSectionTitle(title: "u10.template.medal", systemImage: "star", art: MPAsset.FeatureIcon.star) }
                .discoveryCardRow()
                .accessibilityIdentifier("discovery.topicDetail.medal")
        }
        if let coverRef = nonempty(item.imgUrl), TopicTemplateAdoptionFactory.attributionIsLive {
            Section { TopicTemplateNodeCredit(reference: coverRef) }
                .discoveryCardRow()
                .accessibilityIdentifier("discovery.topicDetail.coverCredit")
        }
    }
    private func topicStat<V: View>(_ value: V, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            value.cyText(.numericBody).foregroundStyle(palette.textPrimary)
            Text(label).cyText(.caption).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
    /// 能力: one summary chip line, then each stop (grouped by chapter for multi-chapter / FREE_EXPLORE routes)
    /// with its play, teaser and duration; an empty state when there are none.
    @ViewBuilder private func topicCapabilities(_ item: PublicTopicTemplateDetail) -> some View {
        let free = item.mode == "FREE_EXPLORE"
        let stops = Self.numberedStops(item.chapters, freeExplore: free)
        Section {
            TemplateChipFlow(spacing: CYSpacing.sm) {
                ForEach(topicSummary(item, stopCount: stops.count), id: \.self) { chip in
                    Text(verbatim: chip).modifier(TemplateChipStyle())
                }
            }
            .accessibilityIdentifier("discovery.topicDetail.summary")
            // R7-PC-A8-1 (r1 PC-A-8-3): MP `xb-stat` cards — 节点 / 玩法 / 总时长.
            HStack(alignment: .top) {
                topicStat(Text(verbatim: String(stops.count)), label: "discovery.templateDetail.stat.nodes")
                if !item.games.isEmpty {
                    topicStat(Text(verbatim: String(item.games.count)), label: "discovery.templateDetail.stat.games")
                }
                topicStat(TopicXcxDurationText(seconds: item.totalTime), label: "discovery.templateDetail.stat.totalTime")
            }
            .accessibilityIdentifier("discovery.topicDetail.stats")
            if stops.isEmpty {
                CYEmptyState(systemImage: "map", "template.cap.emptyState", messageIdentifier: "template.cap.empty")
            }
            if item.chapters.count > 1 && !stops.isEmpty {
                ForEach(Array(item.chapters.enumerated()), id: \.element.id) { index, chapter in
                    let groupStops = stops.filter { $0.chapterID == chapter.id }
                    if !groupStops.isEmpty {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            DiscoveryTitle(text: chapter.name ?? "", fallback: "discovery.publicChapter")
                                .cyText(.meta, weight: .semibold)
                                .foregroundStyle(palette.textSecondary)
                            ForEach(groupStops, id: \.number) { stopRow($0) }
                        }
                    }
                }
            } else {
                ForEach(stops, id: \.number) { stopRow($0) }
            }
        }.discoveryCardRow()
        // R7-PC-A8-4 (r1 PC-A-8-4): MP 采用条件 sits under 能力, after the stops.
        TopicTemplateAdoptionConditionsSection(
            delivery: item.contentDelivery,
            canViewEvidence: item.viewerIsPublisher || (scope == "MERCHANT" && item.viewerIsMerchant)
        )
    }
    private func stopRow(_ stop: NumberedStop) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Text(verbatim: String(stop.number)).cyText(.label, monospacedDigit: true)
                .frame(width: 32, height: 32).background(CYNight.ink0, in: Circle())
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                if let name = stop.name { Text(verbatim: name).cyText(.label).cyWrapText() }
                if let play = stop.interactionType {
                    Text(verbatim: play).cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                }
                if let teaser = stop.hookTeaser {
                    Text(verbatim: teaser).cyText(.meta).foregroundStyle(palette.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discovery.topicDetail.stop.\(stop.number)")
    }
    private func topicSummary(_ item: PublicTopicTemplateDetail, stopCount: Int) -> [String] {
        let free = item.mode == "FREE_EXPLORE"
        var chips = [free ? appLocalized("u10.template.summary.free", locale: locale) : appLocalized("u10.template.summary.city", locale: locale)]
        if free { chips.append(appLocalized("u10.template.summary.multiDay", locale: locale)) }
        if !item.games.isEmpty { chips.append(appLocalized("u10.template.summary.games \(item.games.count)", locale: locale)) }
        if stopCount > 0 { chips.append(appLocalized("u10.template.summary.stops \(stopCount)", locale: locale)) }
        return chips
    }
    private struct NumberedStop {
        let number: Int; let chapterID: Int; let name: String?; let interactionType: String?; let hookTeaser: String?
    }
    private static func numberedStops(_ chapters: [PublicTemplateChapter], freeExplore: Bool = false) -> [NumberedStop] {
        func clean(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return trimmed
        }
        var out: [NumberedStop] = []
        for chapter in chapters {
            if chapter.nodes.isEmpty, freeExplore {
                let guide = clean(TopicXcxFacts.chapterGuide(description: chapter.description))
                out.append(.init(number: out.count + 1, chapterID: chapter.id, name: clean(chapter.name),
                                 interactionType: nil, hookTeaser: guide ?? clean(chapter.description)))
                continue
            }
            for node in chapter.nodes {
                out.append(.init(number: out.count + 1, chapterID: chapter.id, name: clean(node.name),
                                 interactionType: clean(node.interactionType), hookTeaser: clean(node.hookTeaser)))
            }
        }
        return out
    }
}

/// Route silhouette from the public projection (normalised 0...1 points, no coordinates): a quiet street-grid
/// backdrop, the route with start / end markers. Debug builds label it so it is never mistaken for a live map.
private struct PublicTemplateSilhouette: View {
    let points: [PublicTemplateShapePoint]
    @Environment(\.cyPalette) private var palette
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.bgSurfaceSubtle)
            Canvas { context, size in
                var streets = Path()
                let step: CGFloat = 28
                var x = step / 2
                while x < size.width { streets.move(to: CGPoint(x: x, y: 0)); streets.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y = step / 2
                while y < size.height { streets.move(to: CGPoint(x: 0, y: y)); streets.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                context.stroke(streets, with: .color(palette.borderSubtle), lineWidth: 1)
                let inset: CGFloat = 20
                let mapped = points.map { CGPoint(x: inset + $0.x * max(0, size.width - inset * 2), y: inset + $0.y * max(0, size.height - inset * 2)) }
                var route = Path()
                for (index, position) in mapped.enumerated() { if index == 0 { route.move(to: position) } else { route.addLine(to: position) } }
                context.stroke(route, with: .color(palette.textPrimary), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                if let first = mapped.first {
                    context.fill(Path(ellipseIn: CGRect(x: first.x - 6, y: first.y - 6, width: 12, height: 12)), with: .color(palette.success))
                }
                if mapped.count > 1, let last = mapped.last {
                    context.fill(Path(ellipseIn: CGRect(x: last.x - 6, y: last.y - 6, width: 12, height: 12)), with: .color(palette.info))
                }
            }
            #if DEBUG
            Text(verbatim: "ROUTE SHAPE · DEBUG")
                .cyText(.micro).foregroundStyle(palette.textSecondary)
                .padding(CYSpacing.sm)
            #endif
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
    }
}

/// Long template text: 4 lines with 更多, full text with 收起. Short text shows no control.
struct DiscoveryClampedText: View {
    let text: String
    var lineLimit = 4
    @State private var expanded = false
    @Environment(\.cyPalette) private var palette
    private var isLong: Bool { text.count > 80 || text.filter { $0 == "\n" }.count >= lineLimit }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(text).cyText(.body).foregroundStyle(palette.textSecondary).textSelection(.enabled)
                .lineLimit(expanded || !isLong ? nil : lineLimit)
                .fixedSize(horizontal: false, vertical: true)
            if isLong {
                Button(expanded ? "discovery.text.less" : "discovery.text.more") { expanded.toggle() }
                    .cyText(.label).buttonStyle(.borderless).frame(minHeight: 44)
                    .accessibilityIdentifier("discovery.clampedText.toggle")
            }
        }
    }
}

/// Flow gap PC-A-7-2 (MP `pages/templatedetail/topic-preview/index`): the card deck over the same public read.
/// 查看详情 pushes the topic-template detail (MP `topic-detail/index`). 用这个模板 appears only while the adoption write is
/// live, and also lands on the detail, which owns the adoption flow. `readonly=1` hides it, as in the MP.
@MainActor
struct DiscoveryTopicTemplateDeckHost: View {
    @State private var detail: PublicTopicTemplateCoordinator
    @State private var showsDetail = false
    let readonly: Bool
    let makeDetail: () -> PublicTopicTemplateCoordinator
    init(coordinator: PublicTopicTemplateCoordinator, readonly: Bool, makeDetail: @escaping () -> PublicTopicTemplateCoordinator) {
        _detail = State(initialValue: coordinator)
        self.readonly = readonly
        self.makeDetail = makeDetail
    }
    /// The MP deck reads the raw template JSON; the app re-projects the allowlisted public fields it already decoded.
    static func previewData(_ item: PublicTopicTemplateDetail, readonly: Bool) -> TopicTemplatePreviewData {
        var object: [String: PlayWireValue] = [:]
        if let name = item.name { object["name"] = .string(name) }
        if let cover = item.imgUrl { object["imgUrl"] = .string(cover) }
        if let description = item.description { object["description"] = .string(description) }
        if let total = item.totalTime { object["totalTime"] = .integer(Int64(total)) }
        if let medal = item.finishMedalName { object["finishMedalName"] = .string(medal) }
        object["games"] = .array(item.games.map { game in
            var g: [String: PlayWireValue] = ["title": .string(game.title ?? "")]
            if let duration = game.duration { g["duration"] = .integer(Int64(duration)) }
            return .object(g)
        })
        object["chapters"] = .array(item.chapters.map { chapter in
            var c: [String: PlayWireValue] = ["nodeCount": .integer(Int64(chapter.nodeCount ?? chapter.nodes.count))]
            if let name = chapter.name { c["name"] = .string(name) }
            return .object(c)
        })
        return TopicTemplatePreviewData.fromWire(.object(object), templateID: item.id,
                                                 isReadonly: readonly || !TopicTemplateUseFactory.isLive)
    }
    var body: some View {
        Group {
            if detail.isInvalidated {
                ContentUnavailableView("discovery.templateSessionChanged", systemImage: "person.crop.circle.badge.exclamationmark",
                                       description: Text("discovery.templateReopen"))
            } else if let error = detail.error, detail.value == nil {
                DiscoveryErrorView(error: error) { Task { await detail.load() } }
            } else if let item = detail.value {
                TopicTemplateDeckPreviewView(preview: Self.previewData(item, readonly: readonly),
                                             onViewDetail: { showsDetail = true },
                                             onUseTemplate: { showsDetail = true })
                    .accessibilityIdentifier("discovery.topicPreview.deck")
            } else {
                // MP skeleton, not a centred spinner (R7-PC-A7-2).
                CYSkeleton().padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel(Text("discovery.loading"))
            }
        }
        .navigationDestination(isPresented: $showsDetail) {
            DiscoveryTopicTemplatePreview(coordinator: makeDetail())
        }
        .task { if detail.value == nil { await detail.load() } }
    }
}
