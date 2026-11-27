import SwiftUI

/// Countdown to a date, or count-up from one, drawn with the system timer text (`Text(timerInterval:)`), so it
/// ticks without a timer and matches the Live Activity clock. When a countdown reaches its date it swaps to
/// `endedKey` (a `TimelineView(.explicit)` wakes exactly once, at the target).
/// Components r1 (C3). Use it for event start times, deadlines and run clocks.
struct CYCountdown: View {
    enum Direction { case down, up }

    private let date: Date
    private let direction: Direction
    private let style: CYTextStyle
    private let tint: Color
    private let endedKey: LocalizedStringKey

    /// Counts down to `target`; shows `endedKey` once it has passed.
    init(
        until target: Date,
        style: CYTextStyle = .numericBody,
        tint: Color = CYColor.textPrimary,
        endedKey: LocalizedStringKey = "comp.kit.countdown.ended"
    ) {
        self.date = target
        self.direction = .down
        self.style = style
        self.tint = tint
        self.endedKey = endedKey
    }

    /// Counts up from `start` (elapsed run / game time).
    init(since start: Date, style: CYTextStyle = .numericBody, tint: Color = CYColor.textPrimary) {
        self.date = start
        self.direction = .up
        self.style = style
        self.tint = tint
        self.endedKey = "comp.kit.countdown.ended"
    }

    var body: some View {
        TimelineView(.explicit([date])) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch direction {
        case .down:
            if now < date {
                Text(timerInterval: now...date, countsDown: true)
                    .cyText(style, monospacedDigit: true)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .accessibilityLabel(Text(date, style: .relative))
            } else {
                Text(endedKey)
                    .cyText(style)
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        case .up:
            Text(timerInterval: min(date, now)...Date.distantFuture, countsDown: false)
                .cyText(style, monospacedDigit: true)
                .foregroundStyle(tint)
                .lineLimit(1)
                .accessibilityLabel(Text(date, style: .timer))
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
