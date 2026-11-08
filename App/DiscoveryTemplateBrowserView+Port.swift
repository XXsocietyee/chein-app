import SwiftUI

/// PORT-6 additions for `pages/template/index`: cover thumbnail with the "封面暂不可用" fallback,
/// the "正在同步最新内容…" refresh line, and the empty-state "刷新试试" action.
struct DiscoveryTopicCoverThumb: View {
    let urlString: String?
    var body: some View {
        Group {
            if let url = TemplateBrowserPort.coverURL(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: DiscoveryCoverUnavailable()
                    default: Color.secondary.opacity(0.1)
                    }
                }
            } else {
                DiscoveryCoverUnavailable()
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(false)
    }
}

private struct DiscoveryCoverUnavailable: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "photo").imageScale(.medium)
            Text("discovery.coverUnavailable").font(.caption2).multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.1))
    }
}

/// First load keeps the plain spinner; a refresh over loaded rows shows the quiet sync line.
struct DiscoveryTemplateSyncingRow: View {
    let hasLoadedRows: Bool
    var body: some View {
        if TemplateBrowserPort.showsSyncingLine(isLoading: true, hasLoadedRows: hasLoadedRows) {
            Text("discovery.syncing").font(.footnote).foregroundStyle(.secondary)
                .accessibilityAddTraits(.updatesFrequently)
        } else {
            ProgressView("discovery.loading")
        }
    }
}

struct DiscoveryTemplateEmptyRefresh: View {
    let action: () -> Void
    var body: some View {
        Button("discovery.emptyRefresh", action: action)
            .accessibilityIdentifier("discovery.emptyRefresh")
    }
}
