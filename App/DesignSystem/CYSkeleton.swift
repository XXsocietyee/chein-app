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

/// Layout-shaped loading placeholder. No spinner.
public struct CYSkeleton: View {
    private let variant: CYSkeletonVariant
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var lineHeight: CGFloat = 12
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 28
    @State private var pulse = false

    public init(variant: CYSkeletonVariant = .row) {
        self.variant = variant
    }

    public var body: some View {
        Group {
            switch variant {
            case .row:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    bar(fraction: 0.42, height: lineHeight, highlight: false)
                    bar(fraction: 0.72, height: heroHeight, highlight: true)
                    bar(fraction: 1, height: lineHeight, highlight: false)
                }
            case .card:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                        .fill(fillColor(highlight: true))
                        .frame(height: 112)
                    bar(fraction: 0.66, height: 18, highlight: false)
                    bar(fraction: 0.44, height: lineHeight, highlight: false)
                }
                .cyDomainCard()
            case .feedCard:
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: CYRadius.xxl, style: .continuous)
                        .fill(palette.skeletonBase)
                        .frame(height: 248)
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        bar(fraction: 0.36, height: 14, highlight: true)
                        bar(fraction: 0.68, height: 24, highlight: true)
                        HStack(spacing: CYSpacing.s2_5) {
                            RoundedRectangle(cornerRadius: CYRadius.pill, style: .continuous)
                                .fill(palette.skeletonHighlight)
                                .frame(width: 96, height: 34)
                            RoundedRectangle(cornerRadius: CYRadius.pill, style: .continuous)
                                .fill(palette.skeletonHighlight)
                                .frame(width: 112, height: 34)
                        }
                    }
                    .padding(CYSpacing.lg)
                }
            case .mapCard:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                        .fill(palette.skeletonBase)
                        .frame(height: 140)
                    HStack(spacing: CYSpacing.md) {
                        Circle().fill(palette.skeletonHighlight).frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            bar(fraction: 0.52, height: 14, highlight: true)
                            bar(fraction: 0.34, height: lineHeight, highlight: false)
                        }
                    }
                }
                .cyDomainCard()
            case .merchantMetric:
                HStack(spacing: CYSpacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            bar(fraction: 0.55, height: lineHeight, highlight: false)
                            bar(fraction: 0.85, height: heroHeight, highlight: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cyDomainCard()
                    }
                }
            case .routeTimeline:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            Circle().fill(palette.skeletonHighlight).frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                bar(fraction: 0.58, height: 16, highlight: true)
                                bar(fraction: 0.82, height: lineHeight, highlight: false)
                            }
                        }
                    }
                }
                .cyDomainCard()
            case .formSection:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    bar(fraction: 0.32, height: lineHeight, highlight: false)
                    RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                        .fill(palette.skeletonHighlight)
                        .frame(height: CYSpacing.minTouchTarget)
                    bar(fraction: 0.42, height: lineHeight, highlight: false)
                    RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                        .fill(palette.skeletonHighlight)
                        .frame(height: CYSpacing.minTouchTarget)
                }
            case .detail:
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
                        .fill(palette.skeletonHighlight)
                        .frame(height: 180)
                    bar(fraction: 0.78, height: 24, highlight: true)
                    bar(fraction: 0.92, height: lineHeight, highlight: false)
                    bar(fraction: 0.65, height: lineHeight, highlight: false)
                }
            case .ticket:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    bar(fraction: 0.45, height: 14, highlight: true)
                    bar(fraction: 0.75, height: 20, highlight: false)
                    Divider().overlay(palette.borderSubtle)
                    HStack {
                        bar(fraction: 0.35, height: lineHeight, highlight: false)
                        Spacer()
                        RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                            .fill(palette.skeletonHighlight)
                            .frame(width: 56, height: 56)
                    }
                }
                .cyDomainCard()
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("accountCollection.loading"))
    }

    private func fillColor(highlight: Bool) -> Color {
        let base = highlight ? palette.skeletonHighlight : palette.skeletonBase
        guard !reduceMotion else { return base }
        return pulse ? base.opacity(0.68) : base
    }

    private func bar(fraction: CGFloat, height: CGFloat, highlight: Bool) -> some View {
        RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
            .fill(fillColor(highlight: highlight))
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
