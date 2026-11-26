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

/// Native r2: the system redacted placeholder (`.redacted(reason: .placeholder)`) on plain text rows shaped like
/// the content they stand in for. No drawn bars, card chrome or pulse of our own.
public struct CYSkeleton: View {
    private let variant: CYSkeletonVariant

    public init(variant: CYSkeletonVariant = .row) {
        self.variant = variant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            switch variant {
            case .row:
                textRow()
            case .card, .feedCard, .mapCard, .detail:
                ForEach(0..<2, id: \.self) { _ in textRow() }
            case .merchantMetric:
                ForEach(0..<3, id: \.self) { _ in
                    LabeledContent {
                        Text(verbatim: "000")
                    } label: {
                        Text(verbatim: "Placeholder")
                    }
                }
            case .routeTimeline:
                ForEach(0..<3, id: \.self) { _ in
                    Label {
                        Text(verbatim: "Placeholder stop name")
                    } icon: {
                        Image(systemName: "circle")
                    }
                }
            case .formSection, .ticket:
                ForEach(0..<2, id: \.self) { _ in
                    LabeledContent {
                        Text(verbatim: "Placeholder")
                    } label: {
                        Text(verbatim: "Placeholder")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("accountCollection.loading"))
    }

    private func textRow() -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: "Placeholder title text")
                .font(.headline)
            Text(verbatim: "Placeholder secondary line of text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Skeleton") {
    CYSkeleton()
        .padding(CYSpacing.lg)
}
