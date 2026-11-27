import SwiftUI

// Design pass explore + events (11-27). Principles: origin/design/handoff-r2:docs/briefs/design-principles.md.
// Small, data-only building blocks the explore / event surfaces share so the same event reads the same everywhere
// (P5): the "starts in" clock is the kit `CYCountdown` the Live Activity also uses, the going stack uses
// `CYLiveCounter`. Nothing here loads data or adds actions; callers pass what the MP payload already has.

/// Parses the activity source dates the same way `E1ActivityState.of` does (local first, then UTC).
enum ExploreEventClock {
    static func date(_ raw: String?) -> Date? {
        let utc = TimeZone(secondsFromGMT: 0)!
        return HomeFeedDate.parse(raw, sourceTimeZone: nil) ?? HomeFeedDate.parse(raw, sourceTimeZone: utc)
    }

    /// Only the next 24 hours tick; further out the date line on the card already says when (P1 without noise).
    static let horizon: TimeInterval = 86_400
}

/// P1 + P2: "距开始 1:23:45" / "Starts in 1:23:45" while an event is less than a day away, and
/// "进行中 · 还剩 0:42:10" / "In progress · Ends in 0:42:10" while it runs. It ticks by itself
/// (`Text(timerInterval:)` inside `CYCountdown`) and wakes exactly at start / end. Shows nothing otherwise.
/// P12: one line when it fits, the two halves stacked when English (or a large Dynamic Type size) does not.
struct ExploreStartsInLine: View {
    let start: Date?
    let end: Date?
    var tint: Color = CYColor.textSecondary
    var style: CYTextStyle = .label

    init(start: Date?, end: Date?, tint: Color = CYColor.textSecondary, style: CYTextStyle = .label) {
        self.start = start
        self.end = end
        self.tint = tint
        self.style = style
    }

    init(startRaw: String?, endRaw: String?, tint: Color = CYColor.textSecondary, style: CYTextStyle = .label) {
        self.init(start: ExploreEventClock.date(startRaw), end: ExploreEventClock.date(endRaw), tint: tint, style: style)
    }

    private var wakeDates: [Date] {
        [start, end].compactMap { $0 }
    }

    var body: some View {
        TimelineView(.explicit(wakeDates)) { context in
            // An explicit schedule can hand back a past entry date (the start) after the event ended; the
            // inner countdown reads the real clock, so the line would say "In progress · Ends in Ended".
            line(now: max(context.date, Date()))
        }
    }

    @ViewBuilder
    private func line(now: Date) -> some View {
        if let start, now < start, start.timeIntervalSince(now) <= ExploreEventClock.horizon {
            fitting(systemImage: "clock",
                    lead: Text("comp.kit.startsIn"),
                    clock: CYCountdown(until: start, style: nil, tint: nil, endedKey: "comp.kit.countdown.started"))
                .accessibilityIdentifier("explore.startsIn")
        } else if let start, let end, start <= now, now < end, end.timeIntervalSince(now) <= ExploreEventClock.horizon {
            fitting(systemImage: "dot.radiowaves.left.and.right",
                    lead: Text("comp.kit.countdown.started") + Text(verbatim: " · ") + Text("explore.endsIn"),
                    clock: CYCountdown(until: end, style: nil, tint: nil, endedKey: "comp.kit.countdown.ended"))
                .accessibilityIdentifier("explore.endsIn")
        }
    }

    private func fitting(systemImage: String, lead: Text, clock: CYCountdown) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                icon(systemImage)
                lead
                clock
            }
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                    icon(systemImage)
                    lead.fixedSize(horizontal: false, vertical: true)
                }
                clock
            }
        }
        .cyText(style, monospacedDigit: true)
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .accessibilityHidden(true)
    }
}

/// P6: who is going, next to the action it affects. Up to three participant avatars from the MP roster
/// (`registrationList`), then the MP `registrationCount` rolling with `CYLiveCounter`: "12 人已报名" / "12 going".
/// The roster can be partial, so the number is always `registrationCount`, never the roster length.
/// Shows nothing when the count is unknown or zero (no invented social proof).
@MainActor struct ExploreGoingStack: View {
    let people: ActivityPeople
    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 24

    private var faces: [ActivityPerson] {
        Array(people.participants.prefix(3))
    }

    var body: some View {
        if let count = people.registrationCount, count > 0 {
            HStack(spacing: CYSpacing.sm) {
                if !faces.isEmpty {
                    avatars
                } else {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(CYColor.textSecondary)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xxs) {
                    CYLiveCounter(count, style: .label, tint: CYColor.textPrimary)
                    Text("explore.going")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(count, format: .number) + Text(verbatim: " ") + Text("explore.going"))
            .accessibilityIdentifier("explore.going")
        }
    }

    private var avatars: some View {
        HStack(spacing: -side * 0.32) {
            ForEach(Array(faces.enumerated()), id: \.offset) { _, person in
                ExploreAvatar(url: MemberIdentityCardSection.remoteAvatarURL(person.avatarURL), side: side)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One round avatar with a ring so overlapping faces stay separate. https only (via `remoteAvatarURL`).
private struct ExploreAvatar: View {
    let url: URL?
    let side: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill").resizable()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill").resizable()
            }
        }
        .foregroundStyle(CYColor.textTertiary)
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().stroke(CYColor.bgSurface, lineWidth: 2))
        .accessibilityHidden(true)
    }
}

#if DEBUG
private struct ExploreDesignPassPreviewBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            ExploreStartsInLine(start: Date.now.addingTimeInterval(231), end: Date.now.addingTimeInterval(4_000))
            ExploreStartsInLine(start: Date.now.addingTimeInterval(-60), end: Date.now.addingTimeInterval(2_530), tint: CYColor.successText)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
    }
}
#Preview("Explore · starts in") { ExploreDesignPassPreviewBody().themeDomain(.player) }
#Preview("Explore · starts in (en)") {
    ExploreDesignPassPreviewBody().themeDomain(.player).environment(\.locale, Locale(identifier: "en_US"))
}
#endif
