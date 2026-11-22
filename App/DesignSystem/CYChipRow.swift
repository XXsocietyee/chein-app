import SwiftUI

/// Standalone filter chip (`32pt` capsule pill inside `44pt` hit box; unselected `bgElevated`,
/// selected `actionPrimaryBg` + `actionPrimaryFg`, zero outer border).
public struct CYFilterChip: View {
    private let titleKey: LocalizedStringKey?
    private let verbatim: String?
    private let systemImage: String?
    private let count: Int?
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    public var body: some View {
        let resolved = Self.tokens(isSelected: isSelected, in: palette)
        Button(action: action) {
            HStack(spacing: CYSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(CYTypography.caption.weight(.semibold))
                }
                if let verbatim {
                    Text(verbatim: verbatim)
                } else if let titleKey {
                    Text(titleKey)
                }
                if let count {
                    Text(verbatim: "\(count)")
                        .cyText(.micro, monospacedDigit: true)
                        .foregroundStyle(resolved.countForeground)
                }
            }
            .font(isSelected ? CYTypography.label.weight(.semibold) : CYTypography.label)
            .foregroundStyle(resolved.foreground)
            .padding(.horizontal, CYSpacing.lg)
            .frame(minHeight: Theme.length("--cy-btn-h-sm"))
            .background(
                Capsule(style: .continuous)
                    .fill(resolved.background)
            )
            .frame(minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isSelected)
    }
}

/// Horizontal scrollable category/filter chip rail (`32pt` capsule pills, right fade scrim,
/// selected chip uses solid `actionPrimaryBg` + heavier weight; no perimeter border).
public struct CYChipRow<Item: Identifiable>: View where Item.ID == Int {
    private let allTitle: LocalizedStringKey
    private let items: [Item]
    private let name: (Item) -> String
    @Binding private var selection: Int?
    @Environment(\.cyPalette) private var palette

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
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [palette.bgPage.opacity(0), palette.bgPage],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 24)
            .allowsHitTesting(false)
        }
    }
}

#if DEBUG
private struct CYChipRowPreviewItem: Identifiable { let id: Int; let name: String }

#Preview("CYChipRow dark") {
    CYChipRow(allTitle: "Recommended", items: [CYChipRowPreviewItem(id: 1, name: "Food"), CYChipRowPreviewItem(id: 2, name: "Art")],
              selection: .constant(1)) { $0.name }
        .background(CYColor.bgPage)
        .preferredColorScheme(.dark)
}

#Preview("CYChipRow light") {
    CYChipRow(allTitle: "Recommended", items: [CYChipRowPreviewItem(id: 1, name: "Food")], selection: .constant(nil)) { $0.name }
        .background(CYColor.bgPage)
        .preferredColorScheme(.light)
}
#endif
