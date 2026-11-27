import SwiftUI

/// Countdown to a date, or count-up from one, drawn with the system timer text (`Text(timerInterval:)`), so it
/// ticks without a timer and matches the Live Activity clock. When a countdown reaches its date it swaps to
/// `endedKey` (a `TimelineView(.explicit)` wakes exactly once, at the target).
/// `style` / `tint` nil inherit the caller's font and foreground (inline in a `Label` or a footnote line).
/// Components r1 (C3). Use it for event start times, deadlines and run clocks.
struct CYCountdown: View {
    enum Direction { case down, up }

    private let date: Date
    private let direction: Direction
    private let style: CYTextStyle?
    private let tint: Color?
    private let endedKey: LocalizedStringKey

    /// Counts down to `target`; shows `endedKey` once it has passed.
    init(
        until target: Date,
        style: CYTextStyle? = .numericBody,
        tint: Color? = CYColor.textPrimary,
        endedKey: LocalizedStringKey = "comp.kit.countdown.ended"
    ) {
        self.date = target
        self.direction = .down
        self.style = style
        self.tint = tint
        self.endedKey = endedKey
    }

    /// Counts up from `start` (elapsed run / game time).
    init(since start: Date, style: CYTextStyle? = .numericBody, tint: Color? = CYColor.textPrimary) {
        self.date = start
        self.direction = .up
        self.style = style
        self.tint = tint
        self.endedKey = "comp.kit.countdown.ended"
    }

    var body: some View {
        TimelineView(.explicit([date])) { context in
            content(now: context.date)
                .monospacedDigit()
                .lineLimit(1)
                .modifier(CYOptionalTextStyle(style: style))
                .modifier(CYOptionalForeground(tint: tint))
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch direction {
        case .down:
            if now < date {
                Text(timerInterval: now...date, countsDown: true)
                    .accessibilityLabel(Text(date, style: .relative))
            } else {
                Text(endedKey)
            }
        case .up:
            Text(timerInterval: min(date, now)...Date.distantFuture, countsDown: false)
                .accessibilityLabel(Text(date, style: .timer))
        }
    }
}

/// `.cyText(style)` when a style is given; otherwise the inherited font.
struct CYOptionalTextStyle: ViewModifier {
    let style: CYTextStyle?

    func body(content: Content) -> some View {
        if let style {
            content.cyText(style, monospacedDigit: true)
        } else {
            content
        }
    }
}

/// `.foregroundStyle(tint)` when a tint is given; otherwise the inherited foreground.
struct CYOptionalForeground: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if let tint {
            content.foregroundStyle(tint)
        } else {
            content
        }
    }
}

private struct CYCountdownPreviewBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYCountdown(until: Date.now.addingTimeInterval(231))
            CYCountdown(until: Date.now.addingTimeInterval(3_900), style: .dataXL)
            CYCountdown(until: Date.now.addingTimeInterval(-10))
            CYCountdown(since: Date.now.addingTimeInterval(-754), style: .cardTitle, tint: CYColor.gameAccent)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
    }
}
#Preview("Countdown · player dark") { CYCountdownPreviewBody().themeDomain(.player) }
