import SwiftUI

/// mp-club r3 pass 50 (P42; MP `components/cy/skeleton`): the first load of a club read draws the page's own shape
/// instead of a centred spinner. `talent/list` wxml:67 uses `cy-skeleton type="card" count=3`, `club/detail` wxml:27
/// `type="detail"` (hero + title + lines). Shapes are system redacted text and fills, no shimmer of our own; VoiceOver
/// reads the MP loading words once (`aria-label` loading-label).
enum ClubReadSkeletonStyle: Equatable {
    case rows(Int)
    case detail
}

struct ClubReadSkeleton: View {
    let style: ClubReadSkeletonStyle
    let label: LocalizedStringKey
    let identifier: String

    var body: some View {
        Group {
            switch style {
            case .rows(let count):
                List {
                    Section {
                        ForEach(0..<max(1, count), id: \.self) { _ in
                            rowPlaceholder
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDisabled(true)
            case .detail:
                ScrollView {
                    detailPlaceholder
                }
                .scrollDisabled(true)
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier(identifier)
    }

    private var rowPlaceholder: some View {
        HStack(spacing: CYSpacing.md) {
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                .fill(.fill.tertiary)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Placeholder club name")
                    .font(.headline)
                Text(verbatim: "Placeholder member count line")
                    .font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var detailPlaceholder: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                .fill(.fill.tertiary)
                .frame(height: 160)
            Text(verbatim: "Placeholder club name")
                .font(.title3.weight(.semibold))
            Text(verbatim: "Placeholder meta")
                .font(.subheadline)
            Text(verbatim: "Placeholder introduction line placeholder introduction line")
                .font(.body)
                .padding(.top, CYSpacing.md)
            Text(verbatim: "Placeholder introduction line placeholder introduction")
                .font(.body)
            Text(verbatim: "Placeholder introduction line")
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.top, CYSpacing.md)
    }
}
