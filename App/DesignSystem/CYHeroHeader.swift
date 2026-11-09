import SwiftUI

/// Large heavy headline with optional subtitle and optional illustration slot (X-style onboarding hero).
/// Role-aware: colours come from `@Environment(\.cyPalette)`.
struct CYHeroHeader<Illustration: View>: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let illustration: Illustration

    @Environment(\.cyPalette) private var palette

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder illustration: () -> Illustration
    ) {
        self.title = title
        self.subtitle = subtitle
        self.illustration = illustration()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            illustration
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(title)
                    .font(.system(.largeTitle, design: .default).weight(.heavy))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension CYHeroHeader where Illustration == EmptyView {
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview("Hero · player dark") {
    CYHeroHeader("Find your next quest", subtitle: "Real places, real rewards.") {
        RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
            .fill(.gray.opacity(0.3)).frame(height: 120)
    }
    .padding(CYSpacing.pageHorizontal)
    .frame(maxHeight: .infinity, alignment: .top)
    .cyDomainPageBackground()
    .themeDomain(.player)
}

#Preview("Hero · merchant light") {
    CYHeroHeader("Run your shop", subtitle: "Orders, tickets and coupons in one place.")
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.merchant)
}
