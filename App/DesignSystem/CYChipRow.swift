import SwiftUI

/// Standalone filter chip (native r2: system bordered capsule button).
public struct CYFilterChip: View {
    private let titleKey: LocalizedStringKey?
    private let verbatim: String?
    private let systemImage: String?
    private let count: Int?
    private let isSelected: Bool
    private let action: () -> Void

    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.verbatim = nil
        self.systemImage = systemImage
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    public init(
        verbatim title: String,
        systemImage: String? = nil,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.titleKey = nil
        self.verbatim = title
        self.systemImage = systemImage
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    static func tokens(
        isSelected: Bool,
        in palette: CYDomainPalette
    ) -> (foreground: Color, background: Color, countForeground: Color) {
        if isSelected {
            return (palette.actionPrimaryFg, palette.actionPrimaryBg, palette.actionPrimaryFg.opacity(0.85))
        }
        return (palette.textSecondary, palette.bgElevated, palette.textTertiary)
    }

    /// Native r2: a system capsule button (`.borderedProminent` when selected, `.bordered` otherwise), the
    /// filter-chip pattern Apple Maps uses. No colours or heights of our own.
    public var body: some View {
        styled(
            Button(action: action) {
                HStack(spacing: CYSpacing.xs) {
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                    if let verbatim {
                        Text(verbatim: verbatim)
                    } else if let titleKey {
                        Text(titleKey)
                    }
                    if let count {
                        Text(verbatim: "\(count)")
                            .monospacedDigit()
                    }
                }
            }
        )
        .buttonBorderShape(.capsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private func styled<B: View>(_ button: B) -> some View {
        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

/// Horizontal scrollable category/filter chip rail (native r2: system capsule buttons, no fade scrim).
public struct CYChipRow<Item: Identifiable>: View where Item.ID == Int {
    private let allTitle: LocalizedStringKey
    private let items: [Item]
    private let name: (Item) -> String
    @Binding private var selection: Int?

    public init(allTitle: LocalizedStringKey, items: [Item], selection: Binding<Int?>, name: @escaping (Item) -> String) {
        self.allTitle = allTitle
        self.items = items
        self._selection = selection
        self.name = name
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.sm) {
                CYFilterChip(allTitle, isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(items) { item in
                    CYFilterChip(verbatim: name(item), isSelected: selection == item.id) {
                        selection = item.id
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.xs)
        }
    }
}

#if DEBUG
private struct CYChipRowPreviewItem: Identifiable { let id: Int; let name: String }

#Preview("CYChipRow dark") {
    CYChipRow(allTitle: "Recommended", items: [CYChipRowPreviewItem(id: 1, name: "Food"), CYChipRowPreviewItem(id: 2, name: "Art")],
              selection: .constant(1)) { $0.name }

}

#Preview("CYChipRow light") {
    CYChipRow(allTitle: "Recommended", items: [CYChipRowPreviewItem(id: 1, name: "Food")], selection: .constant(nil)) { $0.name }

}
#endif
