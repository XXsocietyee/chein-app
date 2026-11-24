import SwiftUI

/// First read-only home slice. Caller can route source-backed activity/topic banner destinations.
@MainActor
struct DiscoveryHomeView: View {
    let reader: any DiscoveryReading
    var topicBrowsingEnabled=false
    @State private var showsTopics=false
    private let onBannerDestination: ((DiscoveryBanner.Destination) -> Void)?
    @StateObject private var banners = DiscoveryLoader<[DiscoveryBanner]>()
    @StateObject private var home = DiscoveryLoader<DiscoveryTemplateHome>()
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var stagger = CYStaggerGate()

    init(reader: any DiscoveryReading, topicBrowsingEnabled:Bool=false, onBannerDestination: ((DiscoveryBanner.Destination) -> Void)? = nil) {
        self.reader = reader
        self.topicBrowsingEnabled=topicBrowsingEnabled
        self.onBannerDestination = onBannerDestination
    }

    var body: some View {
        NavigationStack {
            Group {
                if !reader.isConfigured {
                    CYEmptyState(systemImage: "network.slash", "discovery.unavailable", detail: "auth.notConfigured", kind: .offline)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(CYSpacing.pageHorizontal)
                        .cyDomainPageBackground()
                } else {
                    List {
                        entrySection
                        bannerSection
                        if let error = home.error {
                            DiscoveryErrorView(error: error) { Task { await loadHome() } }
                                .discoveryHomeRow()
                        }
                        if home.isLoading {
                            CYSkeleton()
                                .accessibilityLabel(Text("discovery.loading"))
                                .discoveryHomeRow()
                        }
                        if let value = home.value {
                            if value.isEmpty && !home.isLoading && home.error == nil {
                                CYEmptyState(systemImage: "sparkles.rectangle.stack", "discovery.emptyGames")
                                    .discoveryHomeRow()
                            }
                            // Preserve the server's five separate sections without merging/relabeling rows.
                            playSection("discovery.featured", items: value.banner, hero: true)
                            playSection("discovery.latest", items: value.latest)
                            playSection("discovery.recommended", items: value.recommended)
                            playSection("discovery.mustPlay", items: value.mustPlay)
                            playSection("discovery.hot", items: value.hot)
                        }
                    }
                    .cyGroupedSurface()
                    .refreshable { await reload() }
                }
            }
            .sheet(isPresented:$showsTopics) { Group { SessionTopicBrowserView() }.cySheet(detents: [.large]) }
            .cyPageTitle("discovery.title")
            .task { if reader.isConfigured { await reload() } }
        }
        .cyDomainScreen(.player)
    }

    private var entrySection: some View {
        Section {
            if topicBrowsingEnabled {
                Button { showsTopics=true } label: {
                    CYListRow("topic.title", card: false) { CYRowIcon(systemImage: "map") }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("discovery.openRoutes")
            }
            NavigationLink {
                DiscoveryTemplateBrowserView(reader: reader)
            } label: {
                CYPillButtonLabel("discovery.browseTemplates", systemImage: "square.stack.3d.up")
            }
            .buttonStyle(CYPillButtonStyle())
            .accessibilityIdentifier("discovery.openTemplates")
            .e1ActionRow()
            .questifyHidesLinkIndicator()
        }
    }

    @ViewBuilder private var bannerSection: some View {
        if let error = banners.error {
            Section {
                DiscoveryErrorView(error: error) { Task { await loadBanners() } }
            } header: {
                CYSectionHeader("discovery.banners").textCase(nil)
            }
        } else if banners.isLoading && banners.value == nil {
            Section {
                CYSkeleton().accessibilityLabel(Text("discovery.loading"))
            } header: {
                CYSectionHeader("discovery.banners").textCase(nil)
            }
        }
        if let items = banners.value, !items.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, banner in
                            DiscoveryHomeBannerCard(banner: banner, index: index, onOpen: onBannerDestination)
                                .cyStaggeredAppear(index: index, gate: stagger)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } header: {
                CYSectionHeader("discovery.banners").textCase(nil)
            }
        }
    }

    @ViewBuilder private func playSection(_ title: LocalizedStringKey, items: [DiscoveryPlayTemplate], hero: Bool = false) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    NavigationLink {
                        DiscoveryTemplateDetailView(id: item.id, reader: reader)
                    } label: {
                        playLabel(item, hero: hero && index == 0)
                    }
                    .buttonStyle(.plain)
                    .questifyHidesLinkIndicator()
                    .accessibilityIdentifier("discovery.play.\(item.id)")
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .cyStaggeredAppear(index: index, gate: stagger)
                }
            } header: {
                CYSectionHeader(title).textCase(nil)
            }
        }
    }

    @ViewBuilder private func playLabel(_ item: DiscoveryPlayTemplate, hero: Bool) -> some View {
        if hero {
            CYImageCard(title: playTitle(item), meta: playMeta(item), imageURL: TemplateBrowserPort.coverURL(item.imgUrl))
                .cachingFeedImage()
        } else if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                DiscoveryTopicCoverThumb(urlString: item.imgUrl)
                DiscoveryPlayRow(item: item)
            }
            .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
        } else {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                DiscoveryTopicCoverThumb(urlString: item.imgUrl)
                DiscoveryPlayRow(item: item)
            }
            .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
        }
    }

    private func playTitle(_ item: DiscoveryPlayTemplate) -> Text {
        item.title.isEmpty ? Text("discovery.untitledPlay") : Text(verbatim: item.title)
    }

    /// Pack, players, minutes, then the description. Unknown parts are omitted; a real player count of 0 stays visible.
    private func playMeta(_ item: DiscoveryPlayTemplate) -> Text? {
        var parts: [Text] = []
        if let pack = item.pack { parts.append(Text(pack.label)) }
        if let players = item.playersText { parts.append(Text(verbatim: players)) }
        if let minutes = item.durationMinutes { parts.append(Text("discovery.minutes \(minutes)")) }
        if let description = item.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            parts.append(Text(verbatim: description))
        }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(verbatim: " · ") + $1 }
    }

    private func loadBanners() async { await banners.load { try await reader.discoveryBanners() } }
    private func loadHome() async { await home.load { try await reader.discoveryTemplateHome() } }
    private func reload() async {
        async let a: Void = loadBanners()
        async let b: Void = loadHome()
        _ = await (a, b)
    }
}

private struct DiscoveryHomeBannerCard: View {
    let banner: DiscoveryBanner
    let index: Int
    let onOpen: ((DiscoveryBanner.Destination) -> Void)?

    var body: some View {
        let trimmed = banner.contents?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let card = CYImageCard(
            title: trimmed.isEmpty ? Text("discovery.openBanner \(index + 1)") : Text(verbatim: trimmed),
            meta: nil,
            imageURL: TemplateBrowserPort.coverURL(banner.picUrl),
            style: .shelf
        )
        if let destination = banner.destination, let onOpen {
            Button { onOpen(destination) } label: { card }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("discovery.openBanner \(index + 1)"))
        } else {
            card
        }
    }
}

private extension View {
    func discoveryHomeRow() -> some View {
        listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

#if DEBUG
#Preview("Discovery home · player") {
    DiscoveryHomeView(reader: DiscoveryFixtureReader(), topicBrowsingEnabled: true)
        .themeDomain(.player)
}
#Preview("Discovery home · merchant sanity") {
    DiscoveryHomeView(reader: DiscoveryFixtureReader(), topicBrowsingEnabled: true)
        .themeDomain(.merchant)
}
#endif
