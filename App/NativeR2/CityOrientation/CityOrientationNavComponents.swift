import SwiftUI

// Components r1 · lane C6 nav: the city orientation run's next-stop ETA, paused tag, team progress and
// arrival confirmation. Apple components only (Text, ProgressView, Label, TimelineView); numbers roll with
// `.contentTransition(.numericText())`, which is a no-op without an animation (Reduce Motion safe).

/// MP pages/play/index.js:4510-4527 `_syncNavMeta`: the second line of the nav bar is an estimate from the
/// straight-line distance at walking pace 5 km/h, at least one minute, with the arrival clock in Beijing time
/// (L01-098). The MP labels it 预计; there is no turn-by-turn (index.wxml:587-591).
enum CityOrientationETA {
    static let walkingMetersPerMinute = 5000.0 / 60

    /// Walking minutes for a distance, or nil without one.
    static func minutes(forMeters meters: Double?) -> Int? {
        guard let meters, meters.isFinite, meters >= 0 else { return nil }
        return max(1, Int((meters / walkingMetersPerMinute).rounded()))
    }

    /// `HH:mm` in Asia/Shanghai, the same clock as the MP and the opening hours.
    static func clockText(minutes: Int, from now: Date) -> String {
        formatter.string(from: now.addingTimeInterval(Double(minutes) * 60))
    }

    /// MP `dur`: `N分钟`, or `H小时M分` from one hour.
    static func durationText(minutes: Int, locale: Locale) -> String {
        if minutes >= 60 {
            return appLocalized("nativeR2.city.eta.hoursMinutes \(minutes / 60) \(minutes % 60)", locale: locale)
        }
        return appLocalized("nativeR2.city.eta.minutes \(minutes)", locale: locale)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// 预计 12分钟 · 14:32 到达. The arrival clock refreshes every minute; nothing shows without a distance.
struct CityOrientationETAText: View {
    let meters: Double?
    @Environment(\.locale) private var locale

    var body: some View {
        if let minutes = CityOrientationETA.minutes(forMeters: meters) {
            TimelineView(.everyMinute) { context in
                Text("nativeR2.city.eta \(CityOrientationETA.durationText(minutes: minutes, locale: locale)) \(CityOrientationETA.clockText(minutes: minutes, from: context.date))")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityIdentifier("nativeR2.city.eta")
        }
    }
}

/// The paused run (MP index.wxml:557-561, paused = 用时 / 已完成 / 路程 with 继续 · 结束): a tag on the next-stop
/// banner so the map says the clock is stopped, not only the peek. The pause tint is orange as in the MP.
struct CityOrientationPausedTag: View {
    var body: some View {
        Label("nativeR2.city.paused.tag", systemImage: "pause.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.orange)
            .accessibilityIdentifier("nativeR2.city.paused.tag")
    }
}

/// One team's progress on the shared route: name, 第 N 站 and a capacity bar of stops done over the route.
/// The bar uses the team's map colour so the row matches its trail. Without a total only the count shows.
struct CityOrientationTeamProgressRow: View {
    let team: TeamTrailTeam
    let total: Int

    private var clampedDone: Int { min(max(team.done, 0), max(total, 0)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                if total > 0 {
                    Text(verbatim: "\(clampedDone)/\(total)")
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(clampedDone)))
                } else if team.done > 0 {
                    Text("playerGap.trail.done \(team.done)")
                }
            } label: {
                Label { Text(verbatim: team.name) } icon: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(NativeR2RoutePath.teamColor(team.colorIndex))
                }
            }
            if total > 0 {
                ProgressView(value: Double(clampedDone), total: Double(total))
                    .tint(NativeR2RoutePath.teamColor(team.colorIndex))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: team.name))
        .accessibilityValue(total > 0 ? Text("nativeR2.city.team.progress \(clampedDone) \(total)") : Text(verbatim: ""))
        .accessibilityIdentifier("nativeR2.city.team.\(team.id)")
    }
}

/// Arrival confirmation in the punch sheet (MP index.wxml:1104-1110: 这一关你已通关, then 前往下一站):
/// a seal, the route progress, and where the next leg goes.
struct CityOrientationArrivalCard: View {
    let doneCount: Int
    let total: Int
    let nextName: String?
    let nextMeters: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("nativeR2.city.arrival.cleared", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color.green)
                .nativeR2BounceOnAppear()
            if total > 0 {
                ProgressView(value: Double(min(doneCount, total)), total: Double(total)) {
                    Text("nativeR2.city.arrival.progress \(min(doneCount, total)) \(total)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(doneCount)))
                }
                .tint(Color.green)
            }
            if let nextName, !nextName.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("nativeR2.city.arrival.next \(nextName)")
                        .font(.subheadline)
                        .lineLimit(2)
                    if let nextMeters {
                        HStack(spacing: 6) {
                            Text(verbatim: CityOrientationFormat.distance(nextMeters)).monospacedDigit()
                            CityOrientationETAText(meters: nextMeters)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nativeR2.city.punch.done")
    }
}
