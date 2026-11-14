import SwiftUI

/// VoiceOver helpers for the 14 page templates.
/// Spoken labels reuse existing copy. An em dash stays on screen and is spoken as Unknown.
enum PageTemplateVoiceOver {
    static let dash = "\u{2014}"

    static func spoken(_ value: String, locale: Locale) -> Text {
        if value == dash {
            return Text("curA11y.unknown", tableName: "CurA11y")
        }
        if value.contains(dash) {
            let word = String(localized: LocalizedStringResource("curA11y.unknown", table: "CurA11y", locale: locale))
            return Text(verbatim: value.replacingOccurrences(of: dash, with: word))
        }
        return Text(verbatim: value)
    }
}

private struct PageTemplateHint: ViewModifier {
    let hint: Text?

    @ViewBuilder func body(content: Content) -> some View {
        if let hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

extension View {
    /// One VoiceOver element for a grouped card. Layout and bindings stay as they are.
    func pageTemplateGroupedCard(label: Text, hint: Text? = nil, traits: AccessibilityTraits = .isStaticText) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .modifier(PageTemplateHint(hint: hint))
            .accessibilityAddTraits(traits)
    }

    func pageTemplateControl(label: Text, hint: Text? = nil, traits: AccessibilityTraits) -> some View {
        accessibilityLabel(label)
            .modifier(PageTemplateHint(hint: hint))
            .accessibilityAddTraits(traits)
    }

    /// Higher values are read first. Use this when mini-program section order differs from the view tree.
    func pageTemplateReadingOrder(_ priority: Double) -> some View {
        accessibilitySortPriority(priority)
    }
}
