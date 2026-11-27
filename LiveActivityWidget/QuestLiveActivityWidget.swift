import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation for `QuestLiveActivityAttributes`.
/// System fonts and colors only. Native r2 M4: compact / minimal / expanded regions for the orientation run
/// (`Text(timerInterval:)`), free-explore next stop and story audio, in the in-app island's symbols and tints.
/// Design P1 L9: taps carry `QuestWidgetLinks.liveActivity` (P-017 / G-087); stop / clue progress is a system
/// `ProgressView` in the activity's keyline tint (G-088).
/// Components r1 C1: the event "Starts in mm:ss · 加入" countdown (`Text(timerInterval:countsDown: true)`), a run
/// deadline countdown, the 50 m arrival with its 打卡 button, score / rank, and pause / resume buttons
/// (`QuestLiveActivityRunToggleIntent`, a `LiveActivityIntent`). Dark, high-contrast lock-screen surface.
struct QuestLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuestLiveActivityAttributes.self) { context in
            QuestLiveActivityLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
                .environment(\.colorScheme, .dark)
                .widgetURL(QuestWidgetLinks.liveActivity(context.attributes.kind))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    QuestLiveActivityHeader(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    QuestLiveActivityClock(attributes: context.attributes, state: context.state, isStale: context.isStale)
                        .font(.title3.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    QuestLiveActivityIslandCenter(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        QuestLiveActivityMetrics(attributes: context.attributes, state: context.state, isStale: context.isStale)
                        QuestLiveActivityActionRow(attributes: context.attributes, state: context.state)
                    }
                }
            } compactLeading: {
                QuestLiveActivityGlyphView(attributes: context.attributes, state: context.state)
            } compactTrailing: {
                QuestLiveActivityCompactValue(attributes: context.attributes, state: context.state, isStale: context.isStale)
                    .font(.caption.monospacedDigit())
            } minimal: {
                QuestLiveActivityGlyphView(attributes: context.attributes, state: context.state)
            }
            .keylineTint(QuestLiveActivityGlyph.tint(context.attributes.kind, mode: context.state.mode))
            .widgetURL(QuestWidgetLinks.liveActivity(context.attributes.kind))
        }
    }
}

/// Same symbols and tints as the in-app island (native r2 M4).
enum QuestLiveActivityGlyph {
    static func symbol(_ kind: QuestLiveActivityKind, mode: QuestLiveActivityMode? = nil) -> String {
        switch kind {
        case .roam: return "figure.walk"
        case .play:
            switch mode {
            case .orientation: return "stopwatch"
            case .explore: return "map"
            case nil: return "flag.checkered"
            }
        case .story: return "waveform"
        case .event: return "calendar.badge.clock"
        }
    }

    static func tint(_ kind: QuestLiveActivityKind, mode: QuestLiveActivityMode?) -> Color {
        switch kind {
        case .roam: return .green
        case .play: return mode == .orientation ? .orange : .accentColor
        case .story, .event: return .accentColor
        }
    }
}

struct QuestLiveActivityGlyphView: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    var body: some View {
        Image(systemName: state.arrived == true ? "mappin.and.ellipse" : QuestLiveActivityGlyph.symbol(attributes.kind, mode: state.mode))
            .foregroundStyle(state.arrived == true ? Color.green : QuestLiveActivityGlyph.tint(attributes.kind, mode: state.mode))
            .accessibilityLabel(Text(QuestLiveActivityTitles.key(attributes.kind, mode: state.mode)))
    }
}

enum QuestLiveActivityTitles {
    static func key(_ kind: QuestLiveActivityKind, mode: QuestLiveActivityMode?) -> LocalizedStringKey {
        switch kind {
        case .roam: return "liveActivity.roam.title"
        case .play:
            switch mode {
            case .orientation: return "liveActivity.orientation.title"
            case .explore: return "liveActivity.explore.title"
            case nil: return "liveActivity.play.title"
            }
        case .story: return "liveActivity.story.title"
        case .event: return "liveActivity.event.title"
        }
    }
}

/// Expanded centre: the next stop for play, the clip for story audio, nothing for roam.
struct QuestLiveActivityIslandCenter: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    var body: some View {
        switch attributes.kind {
        case .play:
            if let name = state.stopName {
                Label {
                    if state.arrived == true {
                        Text("liveActivity.play.arrived") + Text(verbatim: " · " + name)
                    } else {
                        Text(verbatim: name)
                    }
                } icon: {
                    Image(systemName: state.arrived == true ? "checkmark.seal.fill" : "mappin.and.ellipse")
                        .foregroundStyle(state.arrived == true ? Color.green : Color.secondary)
                }
                .font(.subheadline)
                .lineLimit(1)
            }
        case .event:
            if let place = attributes.place {
                Label {
                    Text(verbatim: place).lineLimit(1)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .font(.subheadline)
            }
        case .story:
            if let title = state.mediaTitle ?? attributes.title {
                Text(verbatim: title).font(.subheadline).lineLimit(1)
            }
        case .roam:
            EmptyView()
        }
    }
}

struct QuestLiveActivityLockScreenView: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    let isStale: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                QuestLiveActivityHeader(attributes: attributes, state: state)
                Spacer()
                QuestLiveActivityClock(attributes: attributes, state: state, isStale: isStale)
                    .font(.title2.monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
            QuestLiveActivityMetrics(attributes: attributes, state: state, isStale: isStale)
            QuestLiveActivityActionRow(attributes: attributes, state: state)
        }
    }
}

struct QuestLiveActivityHeader: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                if let title = attributes.title {
                    Text(verbatim: title).lineLimit(1)
                } else {
                    Text(QuestLiveActivityTitles.key(attributes.kind, mode: state.mode))
                }
            } icon: {
                Image(systemName: QuestLiveActivityGlyph.symbol(attributes.kind, mode: state.mode))
                    .foregroundStyle(QuestLiveActivityGlyph.tint(attributes.kind, mode: state.mode))
            }
            .font(.headline)
            switch state.status {
            case .paused where attributes.kind == .story: Text("liveActivity.story.paused").font(.caption).foregroundStyle(.secondary)
            case .active where attributes.kind == .event:
                if let place = attributes.place {
                    Text(verbatim: place).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            case .paused: Text("liveActivity.status.paused").font(.caption).foregroundStyle(.secondary)
            case .finished: Text("liveActivity.status.finished").font(.caption).foregroundStyle(.secondary)
            case .active: EmptyView()
            }
        }
    }
}

/// Running: system timer that keeps counting while the app is suspended. Paused or finished: frozen value.
/// Components r1 C1: an event counts down to its start (`countsDown: true`), then reads 已开始.
struct QuestLiveActivityClock: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    let isStale: Bool
    var body: some View {
        if attributes.kind == .event {
            if !isStale, let interval = state.startInterval(now: Date()) {
                Text(timerInterval: interval, countsDown: true)
                    .foregroundStyle(QuestLiveActivityGlyph.tint(.event, mode: nil))
            } else {
                Text("liveActivity.event.started")
            }
        } else if let interval = state.timerInterval {
            Text(timerInterval: interval, countsDown: false)
        } else if state.elapsedSeconds != nil {
            Text(verbatim: QuestLiveActivityText.elapsed(state.elapsedSeconds))
        } else {
            EmptyView()
        }
    }
}

struct QuestLiveActivityMetrics: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    let isStale: Bool
    var body: some View {
        switch attributes.kind {
        case .roam:
            HStack {
                QuestLiveActivityMetric(label: "liveActivity.roam.distance", value: QuestLiveActivityText.distance(state.distanceMeters))
                Spacer()
                QuestLiveActivityMetric(label: "liveActivity.roam.places", value: state.placesRevealed.map(String.init) ?? "—")
            }
        case .play:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("liveActivity.play.stop").font(.caption).foregroundStyle(.secondary)
                        if let name = state.stopName {
                            Text(verbatim: name).font(.body).lineLimit(1)
                        }
                        if state.stopIndex != nil {
                            Text(verbatim: QuestLiveActivityText.fraction(state.stopIndex, state.stopCount))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if state.nextDistanceMeters != nil {
                        QuestLiveActivityMetric(label: "liveActivity.play.nextDistance", value: QuestLiveActivityText.distance(state.nextDistanceMeters))
                        Spacer()
                    }
                    QuestLiveActivityMetric(label: "liveActivity.play.clues", value: QuestLiveActivityText.fraction(state.cluesSolved, state.cluesTotal))
                }
                QuestLiveActivityProgress(attributes: attributes, state: state)
                QuestLiveActivityRunExtras(state: state)
            }
        case .story:
            HStack {
                Label {
                    Text(state.mediaPlaying == true ? "liveActivity.story.playing" : "liveActivity.story.paused")
                } icon: {
                    Image(systemName: state.mediaPlaying == true ? "speaker.wave.2.fill" : "pause.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
        case .event:
            QuestLiveActivityJoinRow(state: state, isStale: isStale)
        }
    }
}

/// G-088: system progress bar for the stops (or, without stops, the clues), tinted like the keyline.
struct QuestLiveActivityProgress: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    var body: some View {
        let stops = QuestLiveActivityText.progress(state.stopIndex, state.stopCount)
        if let progress = stops ?? QuestLiveActivityText.progress(state.cluesSolved, state.cluesTotal) {
            ProgressView(value: progress.value, total: progress.total)
                .tint(QuestLiveActivityGlyph.tint(attributes.kind, mode: state.mode))
                .accessibilityLabel(Text(stops == nil ? "liveActivity.play.clues" : "liveActivity.play.progress"))
                .accessibilityValue(Text(verbatim: stops == nil
                    ? QuestLiveActivityText.fraction(state.cluesSolved, state.cluesTotal)
                    : QuestLiveActivityText.fraction(state.stopIndex, state.stopCount)))
        }
    }
}

struct QuestLiveActivityMetric: View {
    let label: LocalizedStringKey
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.body.monospacedDigit())
        }
    }
}

/// Compact trailing slot: the running timer when there is one (orientation run, roam walk, story audio elapsed),
/// otherwise distance (roam), distance to the next stop or clue progress (play), or the paused glyph (story).
struct QuestLiveActivityCompactValue: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    let isStale: Bool
    var body: some View {
        if attributes.kind == .event {
            if !isStale, let interval = state.startInterval(now: Date()) {
                Text(timerInterval: interval, countsDown: true)
                    .frame(maxWidth: 52)
            } else {
                Image(systemName: "ticket.fill")
                    .accessibilityLabel(Text("liveActivity.event.started"))
            }
        } else if state.arrived == true {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.green)
                .accessibilityLabel(Text("liveActivity.play.arrived"))
        } else if let interval = state.timerInterval {
            Text(timerInterval: interval, countsDown: false)
                .frame(maxWidth: 52)
        } else {
            switch attributes.kind {
            case .roam: Text(verbatim: QuestLiveActivityText.distance(state.distanceMeters))
            case .play:
                if state.nextDistanceMeters != nil {
                    Text(verbatim: QuestLiveActivityText.distance(state.nextDistanceMeters))
                } else {
                    Text(verbatim: QuestLiveActivityText.fraction(state.cluesSolved, state.cluesTotal))
                }
            case .story:
                Image(systemName: state.mediaPlaying == true ? "speaker.wave.2.fill" : "pause.fill")
                    .accessibilityLabel(Text(state.mediaPlaying == true ? "liveActivity.story.playing" : "liveActivity.story.paused"))
            case .event:
                EmptyView()
            }
        }
    }
}

// MARK: Components r1 C1

/// Run deadline countdown and the player's server score / rank, when known.
struct QuestLiveActivityRunExtras: View {
    let state: QuestLiveActivityContent
    var body: some View {
        let deadline = state.deadlineInterval(now: Date())
        if deadline != nil || state.score != nil || state.rank != nil {
            HStack(alignment: .top) {
                if let deadline {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("liveActivity.play.deadline").font(.caption).foregroundStyle(.secondary)
                        Text(timerInterval: deadline, countsDown: true).font(.body.monospacedDigit())
                    }
                    Spacer()
                }
                if state.score != nil {
                    QuestLiveActivityMetric(label: "liveActivity.play.score", value: state.score.map(String.init) ?? "—")
                    Spacer()
                }
                if state.rank != nil {
                    QuestLiveActivityMetric(label: "liveActivity.play.rank", value: QuestLiveActivityText.rank(state.rank))
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// "Starts in mm:ss · 加入": the countdown to the session start, then 已开始, with the 加入 link to 票夹 (the ticket's pass).
struct QuestLiveActivityJoinRow: View {
    let state: QuestLiveActivityContent
    let isStale: Bool
    var body: some View {
        HStack(spacing: 8) {
            if !isStale, let interval = state.startInterval(now: Date()) {
                HStack(spacing: 4) {
                    Text("liveActivity.event.startsIn")
                    Text(timerInterval: interval, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 72, alignment: .leading)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            } else {
                Text("liveActivity.event.started").font(.subheadline)
            }
            Spacer()
            Link(destination: QuestWidgetLinks.wallet) {
                Label("liveActivity.event.join", systemImage: "ticket.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(QuestLiveActivityGlyph.tint(.event, mode: nil)))
                    .foregroundStyle(Color.white)
            }
            .accessibilityLabel(Text("liveActivity.event.join"))
        }
    }
}

/// Interactive buttons: 打卡 at the arrived stop (opens the punch sheet), pause / resume for a timed run.
struct QuestLiveActivityActionRow: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    private var toggle: Bool? { state.runToggle(kind: attributes.kind) }
    private var checkIn: Bool { attributes.kind == .play && state.arrived == true && state.status != .finished }
    var body: some View {
        if toggle != nil || checkIn {
            HStack(spacing: 8) {
                if checkIn {
                    Button(intent: QuestLiveActivityCheckInIntent()) {
                        Label("liveActivity.action.checkIn", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Color.green)
                    .accessibilityLabel(Text("liveActivity.action.checkIn"))
                }
                if let pause = toggle {
                    Button(intent: QuestLiveActivityRunToggleIntent(kind: attributes.kind, pause: pause)) {
                        Label(pause ? "liveActivity.action.pause" : "liveActivity.action.resume",
                              systemImage: pause ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(QuestLiveActivityGlyph.tint(attributes.kind, mode: state.mode))
                    .accessibilityLabel(Text(pause ? "liveActivity.action.pause" : "liveActivity.action.resume"))
                }
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
        }
    }
}
