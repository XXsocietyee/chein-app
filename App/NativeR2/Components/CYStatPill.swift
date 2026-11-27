import SwiftUI

/// Compact capsule stat: SF Symbol + value (+ optional visible title). A count uses `CYLiveCounter` so it rolls
/// when it changes. One VoiceOver element: title, value. Components r1 (C3).
struct CYStatPill: View {
    private enum Value {
        case text(String)
        case count(Int, compact: Bool)
    }

    private let titleKey: LocalizedStringKey
    private let value: Value
    private let systemImage: String
    private let tint: Color
    private let showsTitle: Bool

    /// A text value (`3:51`, `12 km`).
    init(_ titleKey: LocalizedStringKey, value: String, systemImage: String, tint: Color = CYColor.textPrimary, showsTitle: Bool = false) {
        self.titleKey = titleKey
        self.value = .text(value)
        self.systemImage = systemImage
        self.tint = tint
        self.showsTitle = showsTitle
    }

    /// A count that rolls on change (`1.2K` when `compact`).
    init(_ titleKey: LocalizedStringKey, count: Int, compact: Bool = false, systemImage: String, tint: Color = CYColor.textPrimary, showsTitle: Bool = false) {
        self.titleKey = titleKey
        self.value = .count(count, compact: compact)
        self.systemImage = systemImage
        self.tint = tint
        self.showsTitle = showsTitle
    }

    var body: some View {
        // i18n r1: an English title can be twice as wide as the Chinese one. When the titled pill doesn't fit
        // the HUD row, drop the visible title (VoiceOver still reads it) instead of truncating the value.
        Group {
            if showsTitle {
                ViewThatFits(in: .horizontal) {
                    pillContent(showsTitle: true)
                    pillContent(showsTitle: false)
                }
            } else {
                pillContent(showsTitle: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(accessibilityValueText)
    }

    private func pillContent(showsTitle: Bool) -> some View {
        HStack(spacing: CYSpacing.xs) {
            Image(systemName: systemImage)
                .imageScale(.small)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            valueView
                .layoutPriority(1)
            if showsTitle {
                Text(titleKey)
                    .cyText(.caption)
                    .foregroundStyle(CYColor.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.xs)
        .background(Capsule(style: .continuous).fill(CYColor.bgRaised))
    }

    @ViewBuilder
    private var valueView: some View {
        switch value {
        case .text(let text):
            Text(verbatim: text)
                .cyText(.label, monospacedDigit: true)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(1)
                .fixedSize()
        case .count(let count, let compact):
            CYLiveCounter(count, style: .label, compact: compact)
        }
    }

    private var accessibilityValueText: Text {
        switch value {
        case .text(let text): return Text(verbatim: text)
        case .count(let count, _): return Text(count, format: .number)
        }
    }
}

private struct CYStatPillPreviewBody: View {
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            CYStatPill("comp.kit.ring.progress", count: 1_200, compact: true, systemImage: "person.2.fill")
            CYStatPill("comp.kit.ring.progress", value: "3:51", systemImage: "timer", tint: CYColor.gameAccent, showsTitle: true)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
    }
}
#Preview("StatPill · player dark") { CYStatPillPreviewBody().themeDomain(.player) }
