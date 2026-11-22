import SwiftUI

/// Mini `square/components/cy/popover` (T5 capsule): anchored next to the trigger, never centred,
/// never full width, no dimming, no title, no close button; a tap outside dismisses.
/// Native: a compact-adapted popover anchored to the trigger's bounds, so it stays a capsule on iPhone.
struct CYAnchoredMenuItem: Identifiable, Equatable {
    let id: String
    let title: LocalizedStringKey
    var tableName: String? = nil
    var systemImage: String? = nil
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

private struct CYAnchoredMenuModifier: ViewModifier {
    @Binding var isPresented: Bool
    let items: [CYAnchoredMenuItem]
    let onPick: (String) -> Void

    func body(content: Content) -> some View {
        content.popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().overlay(CYColor.borderSubtle) }
                    Button {
                        isPresented = false
                        onPick(item.id)
                    } label: {
                        HStack(spacing: CYSpacing.sm) {
                            if let symbol = item.systemImage { Image(systemName: symbol).font(CYTypography.label) }
                            Text(item.title, tableName: item.tableName).cyText(.bodyMedium)
                        }
                        .foregroundStyle(CYColor.textPrimary)
                        .padding(.horizontal, CYSpacing.lg)
                        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("cy.anchoredMenu.\(item.id)")
                }
            }
            .padding(.vertical, CYSpacing.xs)
            .fixedSize()
            .background(CYDomainPalette(.player).sheetGlass)
            .presentationCompactAdaptation(.popover)
            .cyPlayerSheetGlass()
        }
    }
}

extension View {
    /// Attach to the trigger itself (the avatar), not to the page; with no items nothing is shown.
    func cyAnchoredMenu(isPresented: Binding<Bool>, items: [CYAnchoredMenuItem], onPick: @escaping (String) -> Void) -> some View {
        modifier(CYAnchoredMenuModifier(isPresented: isPresented, items: items, onPick: onPick))
    }
}
