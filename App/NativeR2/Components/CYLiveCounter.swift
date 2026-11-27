import SwiftUI

/// A count that rolls its digits when it changes (`.contentTransition(.numericText)`): likes, members, unread,
/// points. `compact` shows `1.2K` / `1.2万` from the locale; `delta` adds a signed `+36` beside it.
/// VoiceOver reads the full number. Reduce Motion drops the roll. Components r1 (C3).
struct CYLiveCounter: View {
    private let value: Int
    private let delta: Int?
    private let style: CYTextStyle
    private let compact: Bool
    private let tint: Color
    private let labelKey: LocalizedStringKey?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ value: Int,
        delta: Int? = nil,
        label: LocalizedStringKey? = nil,
        style: CYTextStyle = .numericBody,
        compact: Bool = false,
        tint: Color = CYColor.textPrimary
    ) {
        self.value = value
        self.delta = delta
        self.labelKey = label
        self.style = style
        self.compact = compact
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
            number
            if let delta, delta != 0 {
                deltaText(delta)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: value)
        .animation(reduceMotion ? nil : .snappy, value: delta)
        .accessibilityElement(children: .ignore)
        .modifier(CYOptionalAccessibilityLabel(key: labelKey))
        .accessibilityValue(Text(value, format: .number))
    }

    private var number: some View {
        Text(verbatim: formatted)
            .cyText(style, monospacedDigit: true)
            .foregroundStyle(tint)
            .lineLimit(1)
            .contentTransition(.numericText(value: Double(value)))
    }

    private func deltaText(_ delta: Int) -> some View {
        Text(delta, format: .number.sign(strategy: .always()))
            .cyText(.micro, monospacedDigit: true)
            .foregroundStyle(delta > 0 ? CYColor.successText : CYColor.dangerText)
            .contentTransition(.numericText(value: Double(delta)))
    }

    private var formatted: String {
        compact ? value.formatted(.number.notation(.compactName)) : value.formatted(.number)
    }
}

/// Applies `.accessibilityLabel` only when a key is given.
struct CYOptionalAccessibilityLabel: ViewModifier {
    let key: LocalizedStringKey?

    func body(content: Content) -> some View {
        if let key {
            content.accessibilityLabel(Text(key))
        } else {
            content
        }
    }
}

private struct CYLiveCounterPreviewBody: View {
    @State private var value = 1_164

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYLiveCounter(value, delta: 36)
            CYLiveCounter(value, compact: true)
            CYLiveCounter(value, style: .dataXL)
            Button {
                value += 36
            } label: {
                Text(verbatim: "+36")
            }
            .buttonStyle(.bordered)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
    }
}
#Preview("LiveCounter · player dark") { CYLiveCounterPreviewBody().themeDomain(.player) }
