import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation for `QuestLiveActivityAttributes`.
/// Functional layout with system fonts and system colors only; visual design comes later.
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
                DynamicIslandExpandedRegion(.bottom) {
                    QuestLiveActivityMetrics(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                Image(systemName: QuestLiveActivityGlyph.symbol(context.attributes.kind))
            } compactTrailing: {
                QuestLiveActivityCompactValue(attributes: context.attributes, state: context.state)
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: QuestLiveActivityGlyph.symbol(context.attributes.kind))
            }
        }
    }
}

enum QuestLiveActivityGlyph {
    static func symbol(_ kind: QuestLiveActivityKind) -> String {
        switch kind {
        case .roam: return "figure.walk"
        case .play: return "flag.checkered"
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
                    Text(attributes.kind == .roam ? "liveActivity.roam.title" : "liveActivity.play.title")
                }
            } icon: {
                Image(systemName: QuestLiveActivityGlyph.symbol(attributes.kind))
            }
            .font(.headline)
            switch state.status {
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
                QuestLiveActivityMetric(label: "liveActivity.play.clues", value: QuestLiveActivityText.fraction(state.cluesSolved, state.cluesTotal))
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

/// Compact trailing slot: the running timer when there is one, otherwise distance (roam) or clue progress (play).
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
            case .play: Text(verbatim: QuestLiveActivityText.fraction(state.cluesSolved, state.cluesTotal))
            }
        }
    }
}
