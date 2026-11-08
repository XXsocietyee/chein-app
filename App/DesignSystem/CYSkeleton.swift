import SwiftUI

/// Layout-shaped loading placeholder. No spinner.
public struct CYSkeleton: View {
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .caption) private var lineHeight: CGFloat = 12
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 28

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            bar(fraction: 0.42, height: lineHeight, highlight: false)
            bar(fraction: 0.72, height: heroHeight, highlight: true)
            bar(fraction: 1, height: lineHeight, highlight: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("accountCollection.loading"))
    }

    private func bar(fraction: CGFloat, height: CGFloat, highlight: Bool) -> some View {
        RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous)
            .fill(highlight ? palette.skeletonHighlight : palette.skeletonBase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .containerRelativeFrame(.horizontal, alignment: .leading) { length, _ in
                length * fraction
            }
    }
}

#Preview("Player") {
    CYSkeleton()
        .padding(CYSpacing.lg)
        .themeDomain(.player)
}

#Preview("Merchant") {
    CYSkeleton()
        .padding(CYSpacing.lg)
        .themeDomain(.merchant)
}
