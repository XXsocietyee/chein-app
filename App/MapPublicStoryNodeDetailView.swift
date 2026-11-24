import SwiftUI

/// Read-only detail screen for a public `story_node` (`MapSourceType.storyNode`).
/// Verifies parent `TopicDetail` (`topicID`), unlocked `TopicChapter` (`chapterID`), and `TopicNode` (`nodeID`)
/// via `TopicReading.detail(id:)` without creating a play Run, auto-registering, or executing node tasks.
@MainActor
struct MapPublicStoryNodeDetailView: View {
    let destination: MapPublicStoryNodeDestination
    let reader: any TopicReading
    var topicDestination: ((Int) -> AnyView)? = nil

    @Environment(\.locale) private var locale

    @State private var detail: TopicDetail?
    @State private var loadedKey: LoadKey?
    @State private var issue: TopicScreenIssue?
    @State private var loading = false
    @State private var generation = 0
    @State private var loads = SignedInContentDetailLoadOwner()

    private struct LoadKey: Hashable {
        let nodeID: Int
        let topicID: Int
        let chapterID: Int
        let scope: UUID
        let configured: Bool
    }

    private var key: LoadKey {
        LoadKey(
            nodeID: destination.nodeID,
            topicID: destination.topicID,
            chapterID: destination.chapterID,
            scope: reader.scope,
            configured: reader.isConfigured
        )
    }

    private var resolvedChapterAndNode: (chapter: TopicChapter, node: TopicNode)? {
        guard let detail, detail.id == destination.topicID,
              let chapter = detail.chapters.first(where: { $0.id == destination.chapterID }),
              let node = chapter.nodes.first(where: { $0.id == destination.nodeID }) else {
            return nil
        }
        return (chapter, node)
    }

    var body: some View {
        Group {
            if !reader.isConfigured {
                statePage {
                    CYEmptyState(systemImage: "network.slash", "topic.notConfigured", kind: .offline)
                        .accessibilityIdentifier("topic.error")
                }
            } else if loading || loadedKey != key {
                statePage {
                    layer("mapPublicLayers.storyNode.loading")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(layer("mapPublicLayers.storyNode.loading"))
                        .accessibilityIdentifier("mapPublicLayers.storyNode.loading")
                }
            } else if let issue {
                statePage {
                    CYErrorState(issue.key, retryTitle: "topic.retry") {
                        loads.start { await load() }
                    }
                    .accessibilityIdentifier("topic.error")
                }
            } else if let detail, let resolved = resolvedChapterAndNode {
                nodeContent(detail: detail, chapter: resolved.chapter, node: resolved.node)
            } else {
                statePage {
                    CYStateLayout(
                        kind: .failure,
                        title: layer("mapPublicLayers.storyNode.unavailable"),
                        detail: layer("mapPublicLayers.storyNode.unavailableDetail")
                    )
                    .accessibilityIdentifier("mapPublicLayers.storyNode.unavailable")
                }
            }
        }
        .cyHeroScreen()
        .themeDomain(.player)
        .task(id: key) { await loads.run { await load() } }
        .onDisappear {
            loads.cancel()
            generation += 1
            loading = false
        }
        .onChange(of: key) { _, _ in
            detail = nil
            issue = nil
        }
    }

    private func statePage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        List {
            Section {
                CYHeroHeader(verbatim: layerString("mapPublicLayers.storyNode.navigationTitle")).e1HeroRow()
                VStack(alignment: .leading, spacing: CYSpacing.md) { content() }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
    }

    private func nodeContent(detail: TopicDetail, chapter: TopicChapter, node: TopicNode) -> some View {
        let name = display(node.name.isEmpty ? destination.nodeName : node.name)
        return List {
            Section {
                CYHeroHeader(verbatim: name, titleIdentifier: "mapPublicLayers.storyNode.title") {
                    storyCover(seed: name, rawURL: node.images.first)
                }
                .e1HeroRow()
                CYStatusChip(verbatim: layerString("mapPublicLayers.source.story_node"), tone: .info, systemImage: "book.pages")
                Text(verbatim: "node #\(node.id) · topic #\(detail.id) · chapter #\(chapter.id)")
                    .cyText(.meta)
                    .monospacedDigit()
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("mapPublicLayers.storyNode.domainIDs")
                if let address = node.address ?? destination.address {
                    let shown = address.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !shown.isEmpty {
                        CYListRow(verbatim: shown, trailing: .none) { CYRowIcon(systemImage: "mappin.and.ellipse") }
                            .accessibilityIdentifier("mapPublicLayers.storyNode.address")
                    }
                }
                if let hours = node.businessTime {
                    let shown = hours.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !shown.isEmpty {
                        CYListRow(verbatim: layerString("mapPublicLayers.storyNode.businessHours"), trailing: .value(shown)) {
                            CYRowIcon(systemImage: "clock")
                        }
                    }
                }
            }

            Section {
                parentBlock(detail: detail, chapter: chapter)
                if let openParent = topicDestination {
                    NavigationLink { openParent(detail.id) } label: {
                        HStack(spacing: CYSpacing.sm) {
                            Image(systemName: "sparkles")
                            layer("mapPublicLayers.storyNode.openParentTheme")
                        }
                    }
                    .buttonStyle(CYPillButtonStyle())
                    .accessibilityIdentifier("mapPublicLayers.storyNode.openParentTheme")
                    .accessibilityLabel(layer("mapPublicLayers.storyNode.openParentTheme"))
                    .e1ActionRow()
                }
            } header: {
                layer("mapPublicLayers.storyNode.parentSection").sectionHeading()
            }

            if let narrative = node.description ?? destination.summary {
                let shown = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
                if !shown.isEmpty {
                    Section {
                        Text(verbatim: shown)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("mapPublicLayers.storyNode.narrative")
                    } header: {
                        layer("mapPublicLayers.storyNode.narrativeSection").sectionHeading()
                    }
                }
            }

            if let template = node.template {
                Section {
                    templateBlock(template)
                } header: {
                    layer("mapPublicLayers.storyNode.templateSection").sectionHeading()
                }
            }

            if !node.merchants.isEmpty {
                Section {
                    ForEach(Array(node.merchants.enumerated()), id: \.offset) { _, merchant in
                        let hours = merchant.businessTime?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        CYListRow(verbatim: merchant.name, meta: hours.isEmpty ? nil : hours, trailing: .none) {
                            CYRowIcon(systemImage: "storefront")
                        }
                    }
                } header: {
                    layer("mapPublicLayers.storyNode.merchantsSection").sectionHeading()
                }
            }

            Section {
                Label {
                    layer("mapPublicLayers.storyNode.readOnlyNotice")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "eye").accessibilityHidden(true)
                }
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("mapPublicLayers.storyNode.readOnlyNotice")
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .accessibilityIdentifier("mapPublicLayers.storyNode.detailList")
    }

    private func parentBlock(detail: TopicDetail, chapter: TopicChapter) -> some View {
        let theme = detail.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let chapterTitle = display(chapter.title)
        return VStack(alignment: .leading, spacing: CYSpacing.md) {
            if theme.isEmpty {
                Text(verbatim: "—")
                    .cyText(.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("mapPublicLayers.storyNode.parentThemeName")
            } else {
                CYImageCard(verbatim: theme, fallback: "mapPublicLayers.storyNode.parentSection", imageURL: httpsURL(detail.imageURL))
                    .accessibilityIdentifier("mapPublicLayers.storyNode.parentThemeName")
            }
            Text(verbatim: chapterTitle)
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("mapPublicLayers.storyNode.parentChapterTitle")
            if let chapterDesc = chapter.description?.trimmingCharacters(in: .whitespacesAndNewlines), !chapterDesc.isEmpty {
                Text(verbatim: chapterDesc)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func templateBlock(_ template: TopicTemplate) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: display(template.title))
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let duration = template.duration {
                fact("mapPublicLayers.storyNode.templateDuration", systemImage: "clock", value: "\(duration) min")
            }
            if let players = template.players?.trimmingCharacters(in: .whitespacesAndNewlines), !players.isEmpty {
                fact("mapPublicLayers.storyNode.templatePlayers", systemImage: "person.2", value: players)
            }
            if let difficulty = template.difficulty?.trimmingCharacters(in: .whitespacesAndNewlines), !difficulty.isEmpty {
                fact("mapPublicLayers.storyNode.templateDifficulty", systemImage: "chart.bar", value: difficulty)
            }
        }
        .accessibilityIdentifier("mapPublicLayers.storyNode.template")
    }

    private func fact(_ key: String.LocalizationValue, systemImage: String, value: String) -> some View {
        CYListRow(verbatim: layerString(key), trailing: .value(value)) { CYRowIcon(systemImage: systemImage) }
    }

    private func storyCover(seed: String, rawURL: String?) -> some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay {
                if let url = httpsURL(rawURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { CYCoverArt(seed: seed, symbol: "book.pages") }
                    }
                } else {
                    CYCoverArt(seed: seed, symbol: "book.pages")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }

    private func httpsURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
    private func display(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func layer(_ key: String.LocalizationValue) -> Text {
        Text(LocalizedStringResource(key, table: "MapPublicLayers", locale: locale))
    }
    private func layerString(_ key: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, table: "MapPublicLayers", locale: locale))
    }

    private func load() async {
        guard reader.isConfigured else { return }
        let requestedKey = key
        generation += 1
        let currentGen = generation
        loading = true
        issue = nil
        do {
            let value = try await reader.topicDetail(id: destination.topicID)
            guard !Task.isCancelled, currentGen == generation, requestedKey == key else { return }
            detail = value
            loadedKey = requestedKey
            loading = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, currentGen == generation, requestedKey == key else { return }
            detail = nil
            issue = TopicScreenIssue(error)
            loadedKey = requestedKey
            loading = false
        }
    }
}

private extension Text {
    func sectionHeading() -> some View {
        cyText(.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}
