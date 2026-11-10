import SwiftUI

/// PORT-6 additions for `pages/template/index`: cover thumbnail with the "封面暂不可用" fallback,
/// the "正在同步最新内容…" refresh line, and the empty-state "刷新试试" action.
struct DiscoveryTopicCoverThumb: View {
    let urlString: String?
    /// Cover fallback includes caption2 text, so the square grows with that style.
    @ScaledMetric(relativeTo: .caption2) private var side: CGFloat = 72
    var body: some View {
        Group {
            if let url = TemplateBrowserPort.coverURL(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: DiscoveryCoverUnavailable()
                    default: CYColor.bgRaised
                    }
                }
            } else {
                DiscoveryCoverUnavailable()
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityHidden(false)
    }
}

private struct DiscoveryCoverUnavailable: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "photo").imageScale(.medium)
            Text("discovery.coverUnavailable").font(.caption2).multilineTextAlignment(.center)
        }
        .foregroundStyle(CYColor.textTertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CYColor.bgRaised)
    }
}

/// First load keeps the plain spinner; a refresh over loaded rows shows the quiet sync line.
struct DiscoveryTemplateSyncingRow: View {
    let hasLoadedRows: Bool
    var body: some View {
        if TemplateBrowserPort.showsSyncingLine(isLoading: true, hasLoadedRows: hasLoadedRows) {
            Text("discovery.syncing").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            CYSkeletonBlock(height: 18).accessibilityLabel(Text("discovery.loading"))
        }
    }
}

struct DiscoveryTemplateEmptyRefresh: View {
    let action: () -> Void
    var body: some View {
        CYPillButton("discovery.emptyRefresh", style: .secondary, systemImage: "arrow.clockwise", fullWidth: false, action: action)
            .accessibilityIdentifier("discovery.emptyRefresh")
    }
}
