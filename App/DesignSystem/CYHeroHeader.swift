import SwiftUI

/// Native r2: an optional image (the illustration slot) above a plain system title (`.title` bold) and a
/// `.secondary` body subtitle. No gradient, no custom colours.
struct CYHeroHeader<Illustration: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let titleIdentifier: String?
    private let illustration: Illustration

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
                    .cyText(.pageTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .modifier(CYOptionalAccessibilityIdentifier(identifier: titleIdentifier))
                if let subtitle {
                    subtitle
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyHeroScreen()
    }
}

extension View {
    /// A screen that shows its title in `CYHeroHeader` must not repeat it in the bar: one visible title per screen.
    func cyHeroScreen() -> some View {
        navigationTitle("").navigationBarTitleDisplayMode(.inline)
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

#Preview("Hero") {
    CYHeroHeader("Find your next quest", subtitle: "Real places, real rewards.")
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
}
