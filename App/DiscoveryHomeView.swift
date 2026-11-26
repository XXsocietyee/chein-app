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

    init(reader: any DiscoveryReading, topicBrowsingEnabled:Bool=false, onBannerDestination: ((DiscoveryBanner.Destination) -> Void)? = nil) {
        self.reader = reader
        self.topicBrowsingEnabled=topicBrowsingEnabled
        self.onBannerDestination = onBannerDestination
    }

    var body: some View {
        NavigationStack {
            Group {
                if !reader.isConfigured {
                    ContentUnavailableView {
                        Label("discovery.unavailable", systemImage: "network.slash")
                    } description: {
                        Text("auth.notConfigured")
                    }
                } else {
                    List {
                        entrySection
                        bannerSection
                        if let error = home.error {
                            Section {
                                DiscoveryErrorView(error: error) { Task { await loadHome() } }
                            }
                        }
                        if home.isLoading {
                            Section {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel(Text("discovery.loading"))
                            }
                        }
                        if let value = home.value {
                            if value.isEmpty && !home.isLoading && home.error == nil {
                                Section {
                                    ContentUnavailableView("discovery.emptyGames", systemImage: "sparkles.rectangle.stack")
                                }
                            }
                            // Preserve the server's five separate sections without merging/relabeling rows.
                            playSection("discovery.featured", items: value.banner, hero: true)
                            playSection("discovery.latest", items: value.latest)
                            playSection("discovery.recommended", items: value.recommended)
                            playSection("discovery.mustPlay", items: value.mustPlay)
                            playSection("discovery.hot", items: value.hot)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await reload() }
                }
            }
            .cySheet(isPresented:$showsTopics) { Group { SessionTopicBrowserView() }.cySheet(detents: [.large]) }
            .cyPageTitle("discovery.title")
            .task { if reader.isConfigured { await reload() } }
        }
        .cyDomainScreen(.player)
    }

    private var entrySection: some View {
        Section {
            if topicBrowsingEnabled {
                Button { showsTopics=true } label: {
                    Label("topic.title", systemImage: "map")
                }
                .accessibilityIdentifier("discovery.openRoutes")
            }
            NavigationLink {
                DiscoveryTemplateBrowserView(reader: reader)
            } label: {
                Label("discovery.browseTemplates", systemImage: "square.stack.3d.up")
            }
            .accessibilityIdentifier("discovery.openTemplates")
        }
    }

    @ViewBuilder private var bannerSection: some View {
        if let error = banners.error {
            Section {
                DiscoveryErrorView(error: error) { Task { await loadBanners() } }
            } header: {
                Text("discovery.banners")
            }
        } else if banners.isLoading && banners.value == nil {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("discovery.loading"))
            } header: {
                Text("discovery.banners")
            }
        }
        if let items = banners.value, !items.isEmpty {
            Section {
                // A horizontal shelf of banner images (App Store "shelf" pattern); plain images, no card chrome.
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, banner in
                            DiscoveryHomeBannerCard(banner: banner, index: index, onOpen: onBannerDestination)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("discovery.banners")
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
                    .accessibilityIdentifier("discovery.play.\(item.id)")
                }
            } header: {
                Text(title)
            }
        }
    }

    /// The featured first item keeps its cover as one plain header image above the row text.
    @ViewBuilder private func playLabel(_ item: DiscoveryPlayTemplate, hero: Bool) -> some View {
        if hero {
            VStack(alignment: .leading, spacing: 8) {
                DiscoveryArtwork(source: item.imgUrl, height: 180)
                DiscoveryPlayRow(item: item)
            }
        } else if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                DiscoveryTopicCoverThumb(urlString: item.imgUrl)
                DiscoveryPlayRow(item: item)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                DiscoveryTopicCoverThumb(urlString: item.imgUrl)
                DiscoveryPlayRow(item: item)
            }
        }
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
        let tile = VStack(alignment: .leading, spacing: 6) {
            DiscoveryArtwork(source: banner.picUrl, height: 160)
            (trimmed.isEmpty ? Text("discovery.openBanner \(index + 1)") : Text(verbatim: trimmed))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .frame(width: 260)
        .accessibilityElement(children: .combine)
        if let destination = banner.destination, let onOpen {
            Button { onOpen(destination) } label: { tile }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("discovery.openBanner \(index + 1)"))
        } else {
            tile
        }
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
