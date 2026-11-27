import SwiftUI

// i18n r1 (layout lane): helpers that keep player and club layouts readable when a string is longer in
// English than in Chinese, and at accessibility Dynamic Type sizes. None of them draw anything custom;
// they only pick between native layouts.

/// Shows a segmented `Picker` while every segment's title fits in the row, and the system menu picker
/// otherwise (a long English title, or an accessibility text size). Apply it in place of
/// `.pickerStyle(.segmented)`.
struct CYAdaptiveSegmentedPickerStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.pickerStyle(.menu)
        } else {
            ViewThatFits(in: .horizontal) {
                content.pickerStyle(.segmented)
                content.pickerStyle(.menu)
            }
        }
    }
}

extension View {
    /// Segmented when it fits, menu when an English title or a large text size would truncate a segment.
    func cyAdaptiveSegmented() -> some View {
        modifier(CYAdaptiveSegmentedPickerStyle())
    }
}

/// A row that keeps a label and a value side by side while both fit, and stacks them (label above value)
/// when they don't, so neither side truncates in English or at large text sizes.
struct CYAdaptiveLabelValueRow<LabelContent: View, ValueContent: View>: View {
    private let spacing: CGFloat
    private let label: () -> LabelContent
    private let value: () -> ValueContent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        spacing: CGFloat = CYSpacing.sm,
        @ViewBuilder label: @escaping () -> LabelContent,
        @ViewBuilder value: @escaping () -> ValueContent
    ) {
        self.spacing = spacing
        self.label = label
        self.value = value
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: spacing) {
                    label()
                    Spacer(minLength: spacing)
                    value()
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 2) {
            label()
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row of equal-width action buttons that stacks vertically when the titles don't fit side by side on one
/// line each (long English titles such as "Add to ticket wallet"), and always at accessibility text sizes.
/// Pass the buttons with `.frame(maxWidth: .infinity)` on their labels, as for a plain `HStack`.
struct CYAdaptiveButtonRow<Content: View>: View {
    private let spacing: CGFloat
    private let content: () -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(spacing: CGFloat = CYSpacing.sm, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: spacing) { content() }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing) { content() }
                VStack(spacing: spacing) { content() }
            }
        }
    }
}
