import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation for `QuestLiveActivityAttributes`.
/// System fonts and colors only. Native r2 M4: compact / minimal / expanded regions for the orientation run
/// (`Text(timerInterval:)`), free-explore next stop and story audio, in the in-app island's symbols and tints.
struct QuestLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuestLiveActivityAttributes.self) { context in
            QuestLiveActivityLockScreenView(attributes: context.attributes, state: context.state)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    QuestLiveActivityHeader(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    QuestLiveActivityClock(state: context.state)
                        .font(.title3.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    QuestLiveActivityIslandCenter(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    QuestLiveActivityMetrics(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                QuestLiveActivityGlyphView(attributes: context.attributes, state: context.state)
            } compactTrailing: {
                QuestLiveActivityCompactValue(attributes: context.attributes, state: context.state)
                    .font(.caption.monospacedDigit())
            } minimal: {
                QuestLiveActivityGlyphView(attributes: context.attributes, state: context.state)
            }
            .keylineTint(QuestLiveActivityGlyph.tint(context.attributes.kind, mode: context.state.mode))
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
        }
    }

    static func tint(_ kind: QuestLiveActivityKind, mode: QuestLiveActivityMode?) -> Color {
        switch kind {
        case .roam: return .green
        case .play: return mode == .orientation ? .orange : .accentColor
        case .story: return .accentColor
        }
    }
}

struct QuestLiveActivityGlyphView: View {
    let attributes: QuestLiveActivityAttributes
    let state: QuestLiveActivityContent
    var body: some View {
        Image(systemName: QuestLiveActivityGlyph.symbol(attributes.kind, mode: state.mode))
            .foregroundStyle(QuestLiveActivityGlyph.tint(attributes.kind, mode: state.mode))
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
                    Text(verbatim: name).lineLimit(1)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                QuestLiveActivityHeader(attributes: attributes, state: state)
                Spacer()
                QuestLiveActivityClock(state: state)
                    .font(.title2.monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
            QuestLiveActivityMetrics(attributes: attributes, state: state)
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
            case .paused: Text("liveActivity.status.paused").font(.caption).foregroundStyle(.secondary)
            case .finished: Text("liveActivity.status.finished").font(.caption).foregroundStyle(.secondary)
            case .active: EmptyView()
            }
        }
    }
}

/// Running: system timer that keeps counting while the app is suspended. Paused or finished: frozen value.
struct QuestLiveActivityClock: View {
    let state: QuestLiveActivityContent
    var body: some View {
        if let interval = state.timerInterval {
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
    var body: some View {
        switch attributes.kind {
        case .roam:
            HStack {
                QuestLiveActivityMetric(label: "liveActivity.roam.distance", value: QuestLiveActivityText.distance(state.distanceMeters))
                Spacer()
                QuestLiveActivityMetric(label: "liveActivity.roam.places", value: state.placesRevealed.map(String.init) ?? "—")
            }
        case .play:
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
    var body: some View {
        if let interval = state.timerInterval {
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
            }
        }
    }
}
