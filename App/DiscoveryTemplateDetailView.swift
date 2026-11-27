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
                ContentUnavailableView {
                    Label("discovery.unavailable", systemImage: "network.slash")
                } description: {
                    Text("auth.notConfigured")
                }
            } else if detail.isLoading || loadedKey != requestKey {
                ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("discovery.loading"))
            } else if let error = detail.error {
                DiscoveryErrorView(error: error, failureTitle: "discovery.play.openFailed") { Task { await reload() } }
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
                                    DiscoveryArtPlaceholder(systemImage: "sparkles")
                                }, failure: {
                                    DiscoveryArtPlaceholder(systemImage: "sparkles")
                                })
                                .accessibilityHidden(true)
                            } else {
                                // Round 4 image parity (MP templatedetail.wxml:41): no cover → the first scene's 3D icon, else other.png.
                                TemplateSceneArt.icon(parity?.sceneChips.first).resizable().scaledToFit()
                                    .accessibilityHidden(true)
                                    .padding(CYSpacing.sm)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.quaternary)
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
                        // mp-r3-publish: MP templatedetail.wxml 详情 order — image mosaic, 简介, 审核反馈 + stat cards, 规则,
                        // 怎么验证, 难度 · 时长 · 人数, 分类与适用场景, 所需物料, 创作者说, 评价, then the notice.
                        DiscoveryPlayTemplatePresentationView(presentation: .init(item), scope: galleryScope, imageReader: imageReader, showsPublisher: false, part: .media)
                        textSection(parity?.isTopicTemplate == true ? "u10.template.story" : "discovery.introduction", text: item.description, art: MPAsset.FeatureIcon.book)
                        if let parity { DiscoveryTemplateDetailParitySections(presentation: parity, part: .lead) }
                        if let parity, !parity.ruleSteps.isEmpty {
                            Section {
                                // R7-PC-A6-4 (MP templatedetail.wxml:96-110): the step list clamps (3 steps) with 更多 / 收起.
                                let clampsRules = parity.ruleSteps.count > 3
                                ForEach(Array(parity.ruleSteps.enumerated().prefix(clampsRules && !rulesExpanded ? 3 : parity.ruleSteps.count)), id: \.offset) { index, step in
                                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                                        Image(systemName: index < 50 ? "\(index + 1).circle.fill" : "circle.fill")
                                            .foregroundStyle(.tint).font(.title3).accessibilityHidden(true)
                                        Text(verbatim: step).font(.body)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("discovery.templateDetail.rule.\(index)")
                                }
                                if clampsRules {
                                    Button(rulesExpanded ? "discovery.text.less" : "discovery.text.more") { rulesExpanded.toggle() }
                                        .accessibilityIdentifier("discovery.templateDetail.rules.more")
                                }
                            } header: { DiscoverySectionHeader("discovery.rules", art: MPAsset.FeatureIcon.interaction) }
                                .discoveryCardRow()
                        } else {
                            textSection("discovery.rules", text: item.ruleInstructions, art: MPAsset.FeatureIcon.interaction)
                        }
                        if let parity {
                            DiscoveryTemplateDetailParitySections(presentation: parity, part: .verification)
                            DiscoveryPlayMetadata(item: item).discoveryCardRow()
                            DiscoveryTemplateDetailParitySections(presentation: parity, part: .scenes)
                            if parity.materialChips.isEmpty { textSection("discovery.materials", text: item.requiredMaterials, art: MPAsset.FeatureIcon.flashlight) }
                            DiscoveryPlayTemplatePresentationView(presentation: .init(item), scope: galleryScope, imageReader: imageReader, showsPublisher: false, part: .story)
                            DiscoveryTemplateDetailParitySections(presentation: parity, part: .closing)
                        } else {
                            if let verification = item.verification {
                                Section { Text(verification.label) } header: { DiscoverySectionHeader("discovery.verification") }.discoveryCardRow()
                            }
                            DiscoveryPlayMetadata(item: item).discoveryCardRow()
                            textSection("discovery.location", text: item.usageLocation)
                            textSection("discovery.materials", text: item.requiredMaterials)
                            DiscoveryPlayTemplatePresentationView(presentation: .init(item), scope: galleryScope, imageReader: imageReader, showsPublisher: false, part: .story)
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
                .listStyle(.insetGrouped)
                .refreshable { await reload() }
                .accessibilityIdentifier("discovery.detail.content")
            }
        }
        .appNavigationTitle("discovery.playDetails")
        .navigationBarTitleDisplayMode(.inline)
        .cyToast(verbatimMessage: $toastMessage)
        .cySheet(isPresented: $showsAdoptLogin, onDismiss: {
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
        .cySheet(item: $capabilityPreview) { state in
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
    @Environment(\.locale) private var locale
    @Environment(\.topicTemplateCopiedDestination) private var copiedDestination
    /// Round 4 flow (MP topic-use-flow.js `openDraft`): with no host override the copied draft pushes the topic
    /// editor (`pages/publish/fabu/index?id=&scope=`) through the shared editor destination.
    @Environment(\.topicEditorDestination) private var editorDestination
    /// Summary cards stay on the system text styles. Accessibility sizes stack them instead of squeezing the row.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// a11y-dt r3: node rail column; 150 pt broke node names letter by letter at AX sizes, so it widens (the rail scrolls).
    private var nodeColumnWidth: CGFloat { dynamicTypeSize.isAccessibilitySize ? 260 : 150 }
    @State private var copiedDraft: CopiedTopicDraft?
    @State private var detail: PublicTopicTemplateCoordinator
    @State private var tab: TemplateDetailTab = .details
    @State private var openingExpanded = false
    /// Stop-pill prop art follows Dynamic Type with the caption beside it (MP `cap-card__pill-img`).
    @ScaledMetric(relativeTo: .caption) private var stopMark: CGFloat = 16
    /// The stop index grows with body text. `.label` is a catalog role, not a system text style.
    @ScaledMetric(relativeTo: .body) private var stopIndex: CGFloat = 32
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
                ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("discovery.loading"))
            } else if let error = detail.error {
                DiscoveryErrorView(error: error, failureTitle: "discovery.topicTemplate.openFailed") { Task { await detail.load() } }
            } else if let item = detail.value {
                List {
                    // B78 topic-detail (owner V-24): same chrome as the play detail — head, 应用 + share, 详情 / 能力.
                    Section {
                        TemplateXbHead(title: (item.name ?? "").isEmpty ? Text("discovery.untitledTopic") : Text(verbatim: item.name ?? ""),
                                       publisher: topicAuthor(item), official: item.isOfficial, subtitle: item.subtitle) {
                            // MP topic-detail js:169 `art.topicArt(info.name)`: a known topic name shows its bundled cover.
                            if let art = TemplateShelfArt.topicCover(item.name) {
                                art.resizable().scaledToFill().accessibilityHidden(true)
                            } else if QuestifyCardArtwork.safeURL(item.imgUrl) != nil {
                                DiscoveryArtwork(source: item.imgUrl)
                            } else {
                                // MP asset (topic-detail/index.wxml:31): no cover → the city 3D art `art/cat/city.png`.
                                MPAsset.FeatureIcon.pagesTemplatedetailArtCatCity.resizable().scaledToFit().padding(CYSpacing.sm)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.quaternary)
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
                                    Text("topicTemplate.useCta").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(true)
                                .accessibilityIdentifier("topicTemplate.use.unavailable")
                                if hasShare { TemplateXbShareButton(url: topicShare.url, copyText: topicShare.copyText, label: "u10.template.shareTopic") }
                            }
                            Text("topicTemplate.useUnavailable").font(.footnote).foregroundStyle(.secondary)
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
                            TopicTemplateUseSection(templateID: item.id, scope: scope, readOnly: false,
                                                    plan: TopicTemplateAdoptionPlan(delivery: item.contentDelivery)) { topicID in
                                if let copiedDestination { copiedDestination(topicID) } else { copiedDraft = CopiedTopicDraft(id: topicID) }
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
                .listStyle(.insetGrouped)
                .refreshable { await detail.load() }
                .accessibilityIdentifier("discovery.topicPreview.content")
            } else {
                // P10: the loading words are visible (MP cy-skeleton loading label).
                ProgressView { Text("discovery.loading") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .appNavigationTitle("discovery.topicPreview")
        .navigationBarTitleDisplayMode(.inline)
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
        .cyFullScreenCover(item: $nodeGallery) { selected in
            NativeMediaGallery(snapshot: selected.snapshot, titleKey: "u10.template.nodes", reader: RetainedPublicImageReader())
        }
        .navigationDestination(item: $copiedDraft) { draft in
            if let editorDestination { editorDestination(draft.id, scope) }
        }
        .task { await detail.load() }
        .onDisappear { detail.clear() }
    }
    @ViewBuilder private func optionalText(_ value: String?) -> some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(value).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled) }
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
        // mp-r3-publish: MP topic-detail/index.wxml:55 — with two or more node images, the 详情 tab opens with the
        // image mosaic (tap = the full-screen gallery over the same images), before 剧情.
        let mosaic = item.chapters.flatMap(\.nodes).compactMap { nonempty($0.imgUrl) }.filter { QuestifyCardArtwork.safeURL($0) != nil }
        if mosaic.count > 1 {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(Array(mosaic.enumerated()), id: \.offset) { index, source in
                            Button { nodeGallery = NodeGallerySelection(snapshot: .init(sources: mosaic, selectedIndex: index)) } label: {
                                DiscoveryArtwork(source: source, height: 120)
                                    .frame(width: 160, height: 120)
                                    .clipShape(.rect(cornerRadius: CYRadius.inner))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("media.destination.openImage"))
                            .accessibilityIdentifier("discovery.topicDetail.mosaic.\(index)")
                        }
                    }
                }
            }
            .discoveryCardRow()
        }
        if nonempty(item.description) != nil || !item.chapters.isEmpty {
            Section {
                if let opening = nonempty(item.description) {
                    Text(verbatim: opening).font(.body)
                        .textSelection(.enabled).lineLimit(openingExpanded ? nil : 4)
                    if opening.count > 90 {
                        Button(openingExpanded ? "u10.template.cap.collapse" : "u10.template.cap.expand") {
                            openingExpanded.toggle()
                        }
                        .accessibilityIdentifier("discovery.topicDetail.openingToggle")
                    }
                }
                ForEach(Array(item.chapters.enumerated()), id: \.element.id) { index, chapter in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                            if !TopicXcxFacts.hidesGeneratedChapterOrdinal(chapter.name ?? "") {
                                Text("u10.template.chapterNo \(index + 1)").font(.subheadline).foregroundStyle(.secondary)
                            }
                            DiscoveryTitle(text: chapter.name ?? "", fallback: "discovery.publicChapter").font(.headline)
                        }
                        let guide = TopicXcxFacts.chapterGuide(description: chapter.description)
                        if !guide.isEmpty {
                            Text(verbatim: guide).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        }
                        // PC-A-8-2 (owner 2026-11-14 「太复杂」): a chapter card is number + name + one line; the stop
                        // path and the stop count live only in 能力, grouped by chapter.
                        if let status = chapter.recruitStatus {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("discovery.publicRecruitment").font(.headline)
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
                    // MP `fmtSec`: 0 rounded minutes is `''`, and an empty string is not a card.
                    if Self.fmtSecMinutes(item.totalTime) > 0 {
                        topicStat(TopicXcxDurationText(seconds: item.totalTime), label: "discovery.templateDetail.stat.totalTime")
                    }
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
                                let cover = DiscoveryArtwork(source: node.imgUrl, height: 150)
                                    .frame(width: nodeColumnWidth, height: 150)
                                if let raw = nonempty(node.imgUrl), let galleryIndex = gallery.firstIndex(of: raw) {
                                    Button { nodeGallery = NodeGallerySelection(snapshot: .init(sources: gallery, selectedIndex: galleryIndex)) } label: { cover }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(Text("media.destination.openImage"))
                                        .accessibilityIdentifier("discovery.topicDetail.nodeImage.\(index)")
                                } else {
                                    cover.accessibilityHidden(true)
                                }
                                (nonempty(node.name).map { Text(verbatim: $0) } ?? Text("u10.template.nodeNo \(index + 1)"))
                                    .font(.subheadline).foregroundStyle(.primary).cyWrapText()
                                if let teaser = nonempty(node.hookTeaser) {
                                    Text(verbatim: teaser).font(.footnote).foregroundStyle(.secondary).cyWrapText()
                                }
                                // U02-05: credit for the first 8 node images only (mini _loadCredits).
                                if index < 8, let reference = nonempty(node.imgUrl), TopicTemplateAdoptionFactory.attributionIsLive {
                                    TopicTemplateNodeCredit(reference: reference)
                                }
                            }
                            .frame(width: nodeColumnWidth, alignment: .leading)
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
            Section { Text("discovery.publicEmpty").foregroundStyle(.secondary) }.discoveryCardRow()
        }
        if let medal = item.finishMedalName {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: medal).font(.headline)
                    Text("u10.template.medalHint").font(.subheadline).foregroundStyle(.secondary)
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
    /// MP `fmtSec`: `Math.round(seconds / 60)`. `0` is `''` and is not drawn.
    private static func fmtSecMinutes(_ seconds: Int?) -> Int {
        Int((Double(max(0, seconds ?? 0)) / 60).rounded())
    }
    private func topicStat<V: View>(_ value: V, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            value.font(.headline).monospacedDigit().foregroundStyle(.primary)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
    /// `buildSummary` facts, in source order. A missing list or a 0-minute duration stays out.
    @ViewBuilder private func summaryFacts(
        _ item: PublicTopicTemplateDetail, free: Bool, showChapters: Bool, chapters: Int, stops: [NumberedStop]
    ) -> some View {
        if free {
            topicStat(Text("u10.template.summary.free"), label: "projectEdit.mode")
                .accessibilityIdentifier("discovery.topicDetail.summary.mode")
        } else {
            topicStat(Text("u10.template.summary.city"), label: "projectEdit.mode")
                .accessibilityIdentifier("discovery.topicDetail.summary.mode")
        }
        if free {
            topicStat(Text("u10.template.summary.multiDay"), label: "activityPublishing.review.time")
                .accessibilityIdentifier("discovery.topicDetail.summary.time")
        }
        if showChapters {
            topicStat(Text(verbatim: String(chapters)), label: "discovery.templateDetail.stat.chapters")
                .accessibilityIdentifier("discovery.topicDetail.summary.chapters")
        }
        if !stops.isEmpty {
            topicStat(Text(verbatim: String(stops.count)), label: "discovery.publicStations")
                .accessibilityIdentifier("discovery.topicDetail.summary.stops")
        }
        if item.games.count > 0 {
            topicStat(Text(verbatim: String(item.games.count)), label: "discovery.templateDetail.stat.games")
                .accessibilityIdentifier("discovery.topicDetail.summary.games")
        }
        if Self.fmtSecMinutes(item.totalTime) > 0 {
            topicStat(TopicXcxDurationText(seconds: item.totalTime), label: "discovery.templateDetail.stat.totalTime")
                .accessibilityIdentifier("discovery.topicDetail.summary.totalTime")
        }
    }
    /// 能力: MP `buildSummary` (topic-detail index.js) — 模式 / 时间 / 章节 / 站点 / 玩法 / 总时长, then each stop.
    /// A missing fact is left off the row. 时间 is only 可以跨天 on free exploration. Chapter count is
    /// omitted when free exploration already counts one stop per chapter. 总时长 follows `fmtSec`: a rounded
    /// minute count of 0 is not a card, and a positive count keeps the existing duration text. No 里程 card.
    @ViewBuilder private func topicCapabilities(_ item: PublicTopicTemplateDetail) -> some View {
        let free = item.mode == "FREE_EXPLORE"
        let stops = Self.numberedStops(item.chapters, freeExplore: free)
        let chapters = item.chapters.count
        let showChapters = chapters > 0 && !(free && chapters == stops.count)
        Section {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        summaryFacts(item, free: free, showChapters: showChapters, chapters: chapters, stops: stops)
                    }
                } else {
                    HStack(alignment: .top) {
                        summaryFacts(item, free: free, showChapters: showChapters, chapters: chapters, stops: stops)
                    }
                }
            }
            .accessibilityIdentifier("discovery.topicDetail.stats")
            if stops.isEmpty {
                ContentUnavailableView {
                    Label("template.cap.emptyState", systemImage: "map")
                        .accessibilityIdentifier("template.cap.empty")
                }
            }
            if item.chapters.count > 1 && !stops.isEmpty {
                ForEach(Array(item.chapters.enumerated()), id: \.element.id) { index, chapter in
                    let groupStops = stops.filter { $0.chapterID == chapter.id }
                    if !groupStops.isEmpty {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            DiscoveryTitle(text: chapter.name ?? "", fallback: "discovery.publicChapter")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
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
    /// R7-PC-A8-1b: MP `cap-card` (topic-detail index.wxml:131-140, index.js `buildStopGroups`).
    /// The play pill is shelf art or the play symbol plus `gameTitle` (else `game`). Minutes are `约 N 分钟`.
    private func stopRow(_ stop: NumberedStop) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: stop.number <= 50 ? "\(stop.number).circle.fill" : "circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: stopIndex)
                .accessibilityLabel(Text(verbatim: String(stop.number)))
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                // MP `n.name || '第 ' + no + ' 站'`: a blank stop still names its place in the route.
                (stop.name.map { Text(verbatim: $0) } ?? Text("u10.template.stopNo \(stop.number)"))
                    .font(.body)
                    .cyWrapText()
                if let game = stop.game {
                    HStack(spacing: CYSpacing.xxs) {
                        if let art = TemplateShelfArt.gameProp(game) {
                            art.resizable().scaledToFit()
                                .frame(width: stopMark, height: stopMark)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "play")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        Text(verbatim: game).font(.caption).foregroundStyle(.secondary).cyWrapText()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("discovery.topicDetail.stop.\(stop.number).game")
                } else if let play = stop.interactionType {
                    Text(verbatim: play).font(.caption).foregroundStyle(.secondary)
                }
                if let teaser = stop.hookTeaser {
                    Text(verbatim: teaser).font(.subheadline).foregroundStyle(.secondary)
                }
                if let minutes = stop.duration {
                    HStack(spacing: CYSpacing.xxs) {
                        Image(systemName: "clock")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("topic.chapterCard.minutes \(minutes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("discovery.topicDetail.stop.\(stop.number).duration")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discovery.topicDetail.stop.\(stop.number)")
    }
    private struct NumberedStop {
        let number: Int
        let chapterID: Int
        let name: String?
        let interactionType: String?
        let hookTeaser: String?
        let game: String?
        let duration: Int?
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
                                 interactionType: nil, hookTeaser: guide ?? clean(chapter.description), game: nil, duration: nil))
                continue
            }
            for node in chapter.nodes {
                out.append(.init(number: out.count + 1, chapterID: chapter.id, name: clean(node.name),
                                 interactionType: clean(node.interactionType), hookTeaser: clean(node.hookTeaser),
                                 game: clean(node.game), duration: node.duration))
            }
        }
        return out
    }
}

/// Long template text: 4 lines with 更多, full text with 收起. Short text shows no control.
struct DiscoveryClampedText: View {
    let text: String
    var lineLimit = 4
    @State private var expanded = false
    private var isLong: Bool { text.count > 80 || text.filter { $0 == "\n" }.count >= lineLimit }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(text).font(.body).textSelection(.enabled)
                .lineLimit(expanded || !isLong ? nil : lineLimit)
                .fixedSize(horizontal: false, vertical: true)
            if isLong {
                Button(expanded ? "discovery.text.less" : "discovery.text.more") { expanded.toggle() }
                    .buttonStyle(.borderless)
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
    /// Round 4 flow (MP topic-preview js:216 `useTemplate` → topic-use-flow `adopt`): 用这个模板 copies the template
    /// here and pushes the copied draft into the topic editor; it no longer detours through the detail page.
    @StateObject private var useModel: TopicTemplateUseModel
    @State private var copiedDraft: CopiedTopicDraft?
    @Environment(\.topicTemplateCopiedDestination) private var copiedDestination
    @Environment(\.topicEditorDestination) private var editorDestination
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    let readonly: Bool
    let scope: String?
    let makeDetail: () -> PublicTopicTemplateCoordinator
    init(coordinator: PublicTopicTemplateCoordinator, readonly: Bool, scope: String? = nil,
         makeDetail: @escaping () -> PublicTopicTemplateCoordinator) {
        _detail = State(initialValue: coordinator)
        _useModel = StateObject(wrappedValue: TopicTemplateUseModel(writer: TopicTemplateUseFactory.makeUser(), readOnly: readonly))
        self.readonly = readonly
        self.scope = scope
        self.makeDetail = makeDetail
    }
    private func adopt(_ item: PublicTopicTemplateDetail) {
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/template/topic-template/use"]
            ) {
                await useModel.use(id: item.id, scope: scope, plan: TopicTemplateAdoptionPlan(delivery: item.contentDelivery))
            }
        }
    }
    /// Toast-equivalent line for a refused / unconfirmed copy (MP toasts 使用模板失败 / 网络错误，请重试).
    private var useFailureMessage: String? {
        switch useModel.state {
        case .failed, .unknown, .unavailable, .readOnly: return TopicTemplateUseModel.message(for: useModel.state)
        default: return nil
        }
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
    /// MP topic-preview/intro.js `buildIntro`: only chapters with a name, in order, each with its guide.
    static func introChapters(_ item: PublicTopicTemplateDetail) -> [TopicTemplateIntroChapter] {
        item.chapters.compactMap { chapter in
            let name = (chapter.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TopicTemplateIntroChapter(id: String(chapter.id), name: name, guide: TopicTemplateIntroChapter.guide(chapter.description))
        }
    }
    var body: some View {
        Group {
            if detail.isInvalidated {
                ContentUnavailableView("discovery.templateSessionChanged", systemImage: "person.crop.circle.badge.exclamationmark",
                                       description: Text("discovery.templateReopen"))
            } else if let error = detail.error, detail.value == nil {
                DiscoveryErrorView(error: error, failureTitle: "discovery.topicTemplate.openFailed") { Task { await detail.load() } }
            } else if let item = detail.value {
                TopicTemplateDeckPreviewView(preview: Self.previewData(item, readonly: readonly),
                                             onViewDetail: { showsDetail = true },
                                             onUseTemplate: { adopt(item) },
                                             introChapters: Self.introChapters(item))
                    .accessibilityIdentifier("discovery.topicPreview.deck")
                    .disabled(useModel.state == .using)
                    .safeAreaInset(edge: .bottom) {
                        if let message = useFailureMessage {
                            Label(message, systemImage: "exclamationmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.bar)
                                .accessibilityIdentifier("discovery.topicPreview.useMessage")
                        }
                    }
            } else {
                // MP skeleton, not a centred spinner (R7-PC-A7-2); MP status 正在加载主题模板 (topic-preview/index.wxml:7).
                // P10: the words are visible, not only spoken.
                ProgressView { Text("discovery.topicPreview.loading") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationDestination(isPresented: $showsDetail) {
            DiscoveryTopicTemplatePreview(coordinator: makeDetail()).scopedForAdoption(scope)
        }
        .navigationDestination(item: $copiedDraft) { draft in
            if let editorDestination { editorDestination(draft.id, scope) }
        }
        .onChange(of: useModel.openRequest) { _, request in
            guard let request else { return }
            if let copiedDestination { copiedDestination(request.topicId) } else { copiedDraft = CopiedTopicDraft(id: request.topicId) }
        }
        .task { if detail.value == nil { await detail.load() } }
    }
}

/// A server-confirmed topic draft copied from a template; pushes the topic editor (MP `pages/publish/fabu/index?id=`).
struct CopiedTopicDraft: Identifiable, Hashable { let id: Int }

extension DiscoveryTopicTemplatePreview {
    /// Carries the MP `scope` query into the adoption write and the editor push.
    func scopedForAdoption(_ scope: String?) -> DiscoveryTopicTemplatePreview {
        var copy = self
        copy.scope = scope
        return copy
    }
}
