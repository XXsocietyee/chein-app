import SwiftUI

/// Accessibility pass for screens added since 04b244ff9.
/// Hit targets, VoiceOver, and Dynamic Type live here so each screen stays small.
enum CurA11y {
    static let hit: CGFloat = 44
    static let dash = "\u{2014}"
}

struct CurA11yID: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let name = identifier {
            content.accessibilityIdentifier(name)
        } else {
            content
        }
    }
}

struct CurA11yTextButton: View {
    let title: Text
    let hint: Text
    var identifier: String?
    var expands: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            title
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: CurA11y.hit, alignment: .leading)
                .frame(minWidth: CurA11y.hit)
        }
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
        .modifier(CurA11yID(identifier: identifier))
    }
}

struct CurA11yLink<Destination: View>: View {
    let title: Text
    let hint: Text
    var identifier: String?
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            title
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: CurA11y.hit, alignment: .leading)
        }
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
        .modifier(CurA11yID(identifier: identifier))
    }
}

struct CurA11yField: View {
    let title: Text
    let hint: Text
    @Binding var text: String
    var identifier: String?

    var body: some View {
        TextField("", text: $text)
            .cyText(.body)
            .foregroundStyle(CYColor.textPrimary)
            .frame(minHeight: CurA11y.hit)
            .accessibilityLabel(title)
            .accessibilityHint(hint)
            .modifier(CurA11yID(identifier: identifier))
    }
}

struct CurA11yNotice: View {
    let text: Text
    let hint: Text
    var identifier: String?
    var heading: Bool = false
    var tone: Color = CYColor.textPrimary

    var body: some View {
        text
            .font(heading ? CYTypography.body : CYTypography.meta)
            .foregroundStyle(tone)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: CurA11y.hit, alignment: .leading)
            .accessibilityLabel(text)
            .accessibilityHint(hint)
            .accessibilityAddTraits(heading ? .isHeader : .isStaticText)
            .modifier(CurA11yID(identifier: identifier))
    }
}

struct CurA11yDashText: View {
    let shown: String
    var font: Font = CYTypography.body
    var color: Color = CYColor.textPrimary
    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: shown)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(spoken)
    }

    private var spoken: Text {
        if shown == CurA11y.dash {
            return Text("curA11y.unknown", tableName: "CurA11y")
        }
        if shown.contains(CurA11y.dash) {
            let word = String(localized: LocalizedStringResource("curA11y.unknown", table: "CurA11y", locale: locale))
            return Text(verbatim: shown.replacingOccurrences(of: CurA11y.dash, with: word))
        }
        return Text(verbatim: shown)
    }
}

struct CurA11yLabeled: View {
    let title: Text
    let value: Text
    var spokenValue: Text?
    let hint: Text
    var selected: Bool = false
    var identifier: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        stack
            .frame(maxWidth: .infinity, minHeight: CurA11y.hit, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(spokenValue ?? value)
            .accessibilityHint(hint)
            .accessibilityAddTraits(selected ? [.isSelected, .isStaticText] : [.isStaticText])
            .modifier(CurA11yID(identifier: identifier))
    }

    @ViewBuilder private var stack: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                titleLine
                valueLine
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                titleLine
                Spacer(minLength: CYSpacing.sm)
                valueLine
            }
        }
    }

    private var titleLine: some View {
        title
            .cyText(.body)
            .foregroundStyle(CYColor.textPrimary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueLine: some View {
        value
            .cyText(.body)
            .foregroundStyle(CYColor.textSecondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct CurA11yPair<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var leading: Leading
    var trailing: Trailing

    var body: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                leading
                trailing
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                leading
                Spacer(minLength: CYSpacing.sm)
                trailing
            }
        }
    }
}

struct CurA11yActions<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: CYSpacing.sm, content: content)
        } else {
            HStack(alignment: .center, spacing: CYSpacing.sm, content: content)
        }
    }
}
