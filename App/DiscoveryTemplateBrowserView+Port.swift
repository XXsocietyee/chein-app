import SwiftUI

/// PORT-6 additions for `pages/template/index`: cover thumbnail with the "封面暂不可用" fallback,
/// the "正在同步最新内容…" refresh line, and the empty-state "刷新试试" action.
struct DiscoveryTopicCoverThumb: View {
    let urlString: String?
    /// A theme with no cover shows the system artwork placeholder; the unavailable tile is kept for a cover that
    /// exists but fails to load. `seed` is kept for call-site compatibility.
    var seed: String = ""
    /// The square tracks body type size. The caption is not given a fixed height.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 60

    var body: some View {
        Group {
            if let url = TemplateBrowserPort.coverURL(urlString) {
                PlayerFeedRemoteImage(url: url, maxPixel: 256, placeholder: {
                    DiscoveryArtPlaceholder()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("discovery.loading"))
                }, failure: {
                    DiscoveryCoverUnavailable(side: side)
                })
                .accessibilityHidden(true)
            } else {
                DiscoveryArtPlaceholder()
                    .accessibilityHidden(true)
            }
        }
        .frame(width: side, height: side)
        // Artwork clip only (as Music/Podcasts draw list artwork); no card chrome.
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct DiscoveryCoverUnavailable: View {
    let side: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "photo")
                .font(.body)
                .accessibilityHidden(true)
            Text("discovery.coverUnavailable")
                .font(.caption)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .padding(4)
        .frame(width: side)
        .frame(minHeight: side)
        .background(.quaternary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("discovery.coverUnavailable"))
    }
}

/// First load shows a system spinner; a refresh over loaded rows shows the quiet sync line.
struct DiscoveryTemplateSyncingRow: View {
    let hasLoadedRows: Bool
    var body: some View {
        if TemplateBrowserPort.showsSyncingLine(isLoading: true, hasLoadedRows: hasLoadedRows) {
            Text("discovery.syncing")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            ProgressView { Text("discovery.loading") }
                .frame(maxWidth: .infinity)
        }
    }
}

struct DiscoveryTemplateEmptyRefresh: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("discovery.emptyRefresh", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("discovery.emptyRefresh")
        .accessibilityLabel(Text("discovery.emptyRefresh"))
    }
}
