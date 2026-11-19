import SwiftUI

// Code r3 · Merchant/Root Header (Figma 182:7328, 182:8065, 233:12260; review skill-r2 SR2-16): one header for the
// merchant tab roots, on the anatomy of Player/Root Header — a large leading title (28 Bold), an optional one-line
// subtitle, and up to two trailing glass circles. It sits as the first row of the root's list; the bar title is hidden
// so the page does not say its name twice.

struct MerchantRootHeader<Subtitle: View, Trailing: View>: View {
    let title: Text
    @ViewBuilder var subtitle: () -> Subtitle
    @ViewBuilder var trailing: () -> Trailing
    var titleIdentifier: String? = nil
    private var palette: CYDomainPalette { CYDomainPalette(.merchant) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ title: Text, id titleIdentifier: String? = nil,
         @ViewBuilder subtitle: @escaping () -> Subtitle,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.titleIdentifier = titleIdentifier
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.sm))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.title.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                    .modifier(MerchantRootHeaderIdentifier(identifier: titleIdentifier))
                subtitle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: CYSpacing.xs) { trailing() }
        }
        .padding(.top, CYSpacing.xs)
    }
}

extension MerchantRootHeader where Subtitle == EmptyView {
    init(_ title: Text, id titleIdentifier: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(title, id: titleIdentifier, subtitle: { EmptyView() }, trailing: trailing)
    }
}

extension MerchantRootHeader where Subtitle == EmptyView, Trailing == EmptyView {
    init(_ title: Text, id titleIdentifier: String? = nil) {
        self.init(title, id: titleIdentifier, subtitle: { EmptyView() }, trailing: { EmptyView() })
    }
}

private struct MerchantRootHeaderIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier { content.accessibilityIdentifier(identifier) } else { content }
    }
}

extension View {
    /// The header row's list placement: no background, no separator, page-edge insets.
    func merchantRootHeaderRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
    }

    /// Hides the inline bar title on a merchant root that shows `MerchantRootHeader` (iOS 18+; earlier keeps it).
    @ViewBuilder func merchantRootHidesBarTitle() -> some View {
        if #available(iOS 18, *) { toolbar(removing: .title) } else { self }
    }
}
