import SwiftUI

/// PORT-6 additions for `pages/template/index`: cover thumbnail with the "封面暂不可用" fallback,
/// the "正在同步最新内容…" refresh line, and the empty-state "刷新试试" action.
struct DiscoveryTopicCoverThumb: View {
    let urlString: String?
    /// Screens r4 · Figma 243:1964 (CF-61): a theme with no cover shows the default art seeded by its name, not a
    /// 图片暂不可用 glyph tile. The unavailable tile is kept for a cover that exists but fails to load.
    var seed: String = ""
    /// The square tracks body type size. The caption is not given a fixed height.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 72

    var body: some View {
        Group {
            if let url = TemplateBrowserPort.coverURL(urlString) {
                PlayerFeedRemoteImage(url: url, maxPixel: 256, placeholder: {
                    CYCoverArt(seed: url.absoluteString, showsDebugLabel: false, cornerRadius: CYRadius.sm)
                        .frame(width: side, height: side)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("discovery.loading"))
                }, failure: {
                    DiscoveryCoverUnavailable(side: side)
                })
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .accessibilityHidden(true)
            } else {
                CYCoverArt(seed: seed.isEmpty ? "discovery.untitledTopic" : seed, showsDebugLabel: false, cornerRadius: CYRadius.sm)
                    .frame(width: side, height: side)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct DiscoveryCoverUnavailable: View {
    let side: CGFloat

    var body: some View {
        VStack(spacing: CYSpacing.xxs) {
            Image(systemName: "photo")
                .cyText(.label)
                .accessibilityHidden(true)
            Text("discovery.coverUnavailable")
                .cyText(.caption)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CYColor.textTertiary)
        .padding(CYSpacing.xs)
        .frame(width: side)
        .frame(minHeight: side)
        .background {
            CYCoverArt(seed: "discovery.coverUnavailable", showsDebugLabel: false, showsGlyph: false, cornerRadius: CYRadius.sm)
                .frame(width: side, height: side)
                .opacity(0.4)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("discovery.coverUnavailable"))
    }
}

/// First load keeps a layout-shaped skeleton; a refresh over loaded rows shows the quiet sync line.
struct DiscoveryTemplateSyncingRow: View {
    let hasLoadedRows: Bool
    var body: some View {
        if TemplateBrowserPort.showsSyncingLine(isLoading: true, hasLoadedRows: hasLoadedRows) {
            Text("discovery.syncing")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            CYSkeleton()
                .accessibilityLabel(Text("discovery.loading"))
        }
    }
}

struct DiscoveryTemplateEmptyRefresh: View {
    let action: () -> Void
    var body: some View {
        CYPillButton("discovery.emptyRefresh", style: .secondary, systemImage: "arrow.clockwise", fullWidth: false, action: action)
            .accessibilityIdentifier("discovery.emptyRefresh")
            .accessibilityLabel(Text("discovery.emptyRefresh"))
    }
}
