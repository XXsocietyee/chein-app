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
            .frame(height: height)
            .modifier(CYFractionWidth(fraction: fraction))
    }
}

/// Proposes `fraction` of the parent's offered width and left-aligns the child.
private struct CYFractionWidth: ViewModifier {
    let fraction: CGFloat
    func body(content: Content) -> some View {
        CYFractionWidthLayout(fraction: fraction) { content }
    }
}

private struct CYFractionWidthLayout: Layout {
    let fraction: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 200
        let h = subviews.first?.sizeThatFits(ProposedViewSize(width: width * fraction, height: nil)).height ?? 0
        return CGSize(width: width, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width * fraction, height: bounds.height))
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
