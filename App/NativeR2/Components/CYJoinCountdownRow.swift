import SwiftUI

/// "Starts in 3:51 · 加入": an event / activity row with a live countdown to its start and a Join button.
/// Once it has started the countdown reads `startedKey`; a joined row shows a checkmark instead of the button.
/// Components r1 (C3); the Live Activity uses the same wording (`LiveActivityWidget`).
struct CYJoinCountdownRow: View {
    private let title: String
    private let subtitle: String?
    private let startsAt: Date
    private let isJoined: Bool
    private let joinKey: LocalizedStringKey
    private let startedKey: LocalizedStringKey
    private let tint: Color
    private let onJoin: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        startsAt: Date,
        isJoined: Bool = false,
        joinKey: LocalizedStringKey = "comp.kit.join",
        startedKey: LocalizedStringKey = "comp.kit.countdown.started",
        tint: Color = CYColor.actionPrimaryBg,
        onJoin: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.startsAt = startsAt
        self.isJoined = isJoined
        self.joinKey = joinKey
        self.startedKey = startedKey
        self.tint = tint
        self.onJoin = onJoin
    }

    var body: some View {
        HStack(spacing: CYSpacing.md) {
            details
            Spacer(minLength: CYSpacing.sm)
            trailing
        }
        .padding(.vertical, CYSpacing.sm)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: title)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(2)
            countdownLine
            if let subtitle, !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textTertiary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var countdownLine: some View {
        TimelineView(.explicit([startsAt])) { context in
            HStack(spacing: CYSpacing.xs) {
                if context.date < startsAt {
                    Text("comp.kit.startsIn")
                        .cyText(.meta)
                    CYCountdown(until: startsAt, style: .meta, tint: CYColor.textSecondary, endedKey: startedKey)
                } else {
                    Text(startedKey)
                        .cyText(.meta)
                }
            }
            .foregroundStyle(CYColor.textSecondary)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isJoined {
            Label {
                Text("comp.kit.joined")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
            }
            .labelStyle(.titleAndIcon)
            .cyText(.label)
            .foregroundStyle(CYColor.successText)
        } else {
            Button(action: onJoin) {
                Text(joinKey)
                    .cyText(.label)
                    .foregroundStyle(CYColor.actionPrimaryFg)
                    .padding(.horizontal, CYSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(tint)
            .frame(minHeight: CYSpacing.minTouchTarget)
        }
    }
}

private struct CYJoinCountdownRowPreviewBody: View {
    @State private var joined = false

    var body: some View {
        VStack(spacing: 0) {
            CYJoinCountdownRow(title: "Night Market Quest", subtitle: "0.8 km", startsAt: Date.now.addingTimeInterval(231), isJoined: joined) {
                joined = true
            }
            CYJoinCountdownRow(title: "City Orientation", startsAt: Date.now.addingTimeInterval(-60)) {}
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
    }
}
#Preview("JoinCountdownRow · player dark") { CYJoinCountdownRowPreviewBody().themeDomain(.player) }
