import SwiftUI

/// Large heavy headline with optional subtitle and optional illustration slot (X-style onboarding hero).
/// Role-aware: colours come from `@Environment(\.cyPalette)`.
struct CYHeroHeader<Illustration: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let titleIdentifier: String?
    private let illustration: Illustration

    @Environment(\.cyPalette) private var palette

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        tableName: String? = nil,
        titleIdentifier: String? = nil,
        @ViewBuilder illustration: () -> Illustration
    ) {
        self.title = Text(title, tableName: tableName)
        self.subtitle = subtitle.map { Text($0, tableName: tableName) }
        self.titleIdentifier = titleIdentifier
        self.illustration = illustration()
    }

    /// Server-supplied titles stay verbatim. They are not looked up as catalog keys.
    init(
        verbatim title: String,
        subtitle: String? = nil,
        titleIdentifier: String? = nil,
        @ViewBuilder illustration: () -> Illustration
    ) {
        self.title = Text(verbatim: title)
        self.subtitle = subtitle.map { Text(verbatim: $0) }
        self.titleIdentifier = titleIdentifier
        self.illustration = illustration()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            illustration
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                title
                    .font(.system(.largeTitle, design: .default).weight(.heavy))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .modifier(CYOptionalAccessibilityIdentifier(titleIdentifier))
                if let subtitle {
                    subtitle
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
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, tableName: String? = nil, titleIdentifier: String? = nil) {
        self.init(title, subtitle: subtitle, tableName: tableName, titleIdentifier: titleIdentifier) { EmptyView() }
    }

    init(verbatim title: String, subtitle: String? = nil, titleIdentifier: String? = nil) {
        self.init(verbatim: title, subtitle: subtitle, titleIdentifier: titleIdentifier) { EmptyView() }
    }
}

struct CYOptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier, !identifier.isEmpty {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
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
