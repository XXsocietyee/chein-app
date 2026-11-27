import SwiftUI

/// Skeleton variants matching real page/card/metric/timeline geometry (`--cy-color-skeleton-base` / `--highlight`).
public enum CYSkeletonVariant: Sendable, Hashable {
    case row
    case card
    case feedCard
    case mapCard
    case merchantMetric
    case routeTimeline
    case formSection
    case detail
    case ticket
}

/// mp-states r3: the ONE loading pattern on every screen — a system `ProgressView` whose label carries the MP loading
/// words (cy-empty kind="loading" / cy-loading-mask 加载中 → 加载中… / Loading…), centred in the space the content
/// will take. `variant` is kept for call sites; it no longer draws a redacted shape of its own.
public struct CYSkeleton: View {
    private let variant: CYSkeletonVariant
    private let label: LocalizedStringKey

    /// `label` is the page's own loading words (default 加载中…); shown on screen and read by VoiceOver.
    public init(variant: CYSkeletonVariant = .row, label: LocalizedStringKey = "accountCollection.loading") {
        self.variant = variant
        self.label = label
    }

    public var body: some View {
        ProgressView {
            Text(label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.lg)
    }
}

#Preview("Skeleton") {
    CYSkeleton()
        .padding(CYSpacing.lg)
}
