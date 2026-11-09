import SwiftUI

/// Mini-program `tpl-chips` (L2 category chips): one horizontally scrolling row, first chip is the
/// unfiltered "recommended" choice, selected chip is solid + heavier weight (two cues, not colour alone).
/// Presentation only: the caller owns the selection binding.
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
                chip(isSelected: selection == nil) { selection = nil } label: { Text(allTitle) }
                ForEach(items) { item in
                    chip(isSelected: selection == item.id) { selection = item.id } label: { Text(verbatim: name(item)) }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.xs)
        }
    }

    private func chip<Label: View>(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .font(isSelected ? CYTypography.label.weight(.semibold) : CYTypography.label)
                .foregroundStyle(isSelected ? CYColor.textInverse : CYColor.textPrimary)
                .padding(.horizontal, CYSpacing.lg)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .background(isSelected ? CYColor.textPrimary : Color.clear, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).strokeBorder(CYColor.borderStrong, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
