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
    @State private var galleryScope = UUID()
    @State private var loadedKey: RequestKey?
    @State private var readerChange: UInt64 = 0
    @State private var adoption: Adoption?
    @State private var tab: TemplateDetailTab = .details
    @State private var capabilityPreview: TemplateNodePreviewState?
    @State private var toastMessage: String?
    /// Caller override. Nil uses `PublicContentShareLink.discoveryTemplate` when that path is already parsed.
    var shareURL: URL? = nil
    private struct Adoption: Identifiable, Hashable {
        let id = UUID()
        let source: DiscoveryPlayTemplate
        let key: RequestKey
        nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
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
                            // PC-A-6-1: the template's own cover first (MP coverUrl), generated art while loading or without one.
                            if let url = TemplateBrowserPort.coverURL(item.imgUrl) {
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
                        textSection(parity?.isTopicTemplate == true ? "u10.template.story" : "discovery.introduction", text: item.description)
                        if let parity, !parity.ruleSteps.isEmpty {
                            Section {
                                ForEach(Array(parity.ruleSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                                        Text(verbatim: String(index + 1)).cyText(.label, monospacedDigit: true)
                                            .frame(width: 28, height: 28).background(CYColor.bgSurfaceStrong, in: Circle())
                                        Text(verbatim: step).cyText(.body).foregroundStyle(palette.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("discovery.templateDetail.rule.\(index)")
                                }
                            } header: { DiscoverySectionHeader("discovery.rules") }
                                .discoveryCardRow()
                        } else {
                            textSection("discovery.rules", text: item.ruleInstructions)
                        }
                        if let parity {
                            // Carries 怎么验证, 分类与适用场景, 所需物料, 评价 and the 不能直接开团 notice.
                            if parity.materialChips.isEmpty { textSection("discovery.materials", text: item.requiredMaterials) }
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
    @ViewBuilder private func textSection(_ title: LocalizedStringKey, text: String?) -> some View {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section { Text(text).cyText(.body).foregroundStyle(palette.textSecondary).textSelection(.enabled) } header: { DiscoverySectionHeader(title) }
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
                ProgressView("discovery.loading")
            } else if let error = detail.error {
                DiscoveryErrorView(error: error) { Task { await detail.load() } }
            } else if let item = detail.value {
                List {
                    // B78 topic-detail (owner V-24): same chrome as the play detail — head, 应用 + share, 详情 / 能力.
                    Section {
                        TemplateXbHead(title: (item.name ?? "").isEmpty ? Text("discovery.untitledTopic") : Text(verbatim: item.name ?? ""),
                                       publisher: topicAuthor(item), official: false, subtitle: item.subtitle) {
                            E1CoverArt(seed: item.name ?? "topic", symbol: "building.2", imageURL: item.imgUrl, debugLabel: false,
                                       symbolPoint: CGPoint(x: 0.5, y: 0.5))
                        }
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: CYSpacing.md, trailing: CYSpacing.lg))
                        let topicShare = topicShareOffer(item.id)
                        if topicShare.url != nil || topicShare.copyText != nil {
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
                    } else {
                        // PC-A-7-3: never hide the page's main action; show it disabled and say why.
                        Section {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Button {} label: {
                                    Text("topicTemplate.useCta").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                                }
                                .buttonStyle(.cyPrimary(fullWidth: true))
                                .disabled(true)
                                .accessibilityIdentifier("topicTemplate.use.unavailable")
                                Text("topicTemplate.useUnavailable").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                        }.discoveryCardRow()
                    }
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
            } else { ProgressView("discovery.loading") }
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
        .task { await detail.load() }
        .onDisappear { detail.clear() }
    }
    @ViewBuilder private func optionalText(_ value: String?) -> some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(value).cyText(.meta).foregroundStyle(palette.textSecondary).textSelection(.enabled) }
    }
    /// Mini-program `author || '城瘾'`.
    private func topicAuthor(_ item: PublicTopicTemplateDetail) -> Text {
        if let author = item.author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty { return Text(verbatim: author) }
        return Text("discovery.templateDetail.publisher.platform")
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
            } header: { TemplateXbSectionTitle(title: "u10.template.story", systemImage: "book") }
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
        TopicTemplateAdoptionConditionsSection(
            delivery: item.contentDelivery,
            canViewEvidence: item.viewerIsPublisher || (scope == "MERCHANT" && item.viewerIsMerchant)
        )
        let nodes = item.chapters.flatMap(\.nodes)
        if !nodes.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                E1CoverArt(seed: (node.name ?? "") + String(index), symbol: "mappin.and.ellipse", imageURL: node.imgUrl, debugLabel: false)
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                                    .accessibilityHidden(true)
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
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: 0))
            } header: { TemplateXbSectionTitle(title: "u10.template.nodes", systemImage: "safari") }
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
            } header: { TemplateXbSectionTitle(title: "u10.template.medal", systemImage: "star") }
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
