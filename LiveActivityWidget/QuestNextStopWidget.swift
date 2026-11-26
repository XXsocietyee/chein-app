import SwiftUI
import WidgetKit

/// Design P1 L9 (P-016 / G-089): Home Screen and Lock Screen widget. While a play run has a next stop (written by the
/// app's `QuestLiveActivityCenter` into the App Group store) it shows that stop and the stop progress; otherwise it is
/// the city passport entry, with 开始漫游 beside it on the medium size. Taps use `QuestWidgetLinks` (P-017 / G-087).
/// No network: the widget reads only what the app stored. System fonts, colours, `ProgressView` and `Gauge` only.
struct QuestNextStopWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuestWidgetStore.nextStopKind, provider: QuestNextStopProvider()) { entry in
            QuestNextStopWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("widget.nextStop.name")
        .description("widget.nextStop.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct QuestNextStopEntry: TimelineEntry {
    let date: Date
    let snapshot: QuestNextStopSnapshot?
}

struct QuestNextStopProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuestNextStopEntry {
        QuestNextStopEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestNextStopEntry) -> Void) {
        completion(QuestNextStopEntry(date: Date(), snapshot: QuestWidgetStore.read()))
    }

    /// The app reloads this timeline when the stop changes; a stored stop expires back to the passport entry.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestNextStopEntry>) -> Void) {
        let now = Date()
        let snapshot = QuestWidgetStore.read(now: now)
        var entries = [QuestNextStopEntry(date: now, snapshot: snapshot)]
        if let snapshot { entries.append(QuestNextStopEntry(date: snapshot.expiresAt, snapshot: nil)) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct QuestNextStopWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuestNextStopEntry

    var body: some View {
        content
            // A live stop opens the app where the run already is; the passport entry opens the stamp album.
            .widgetURL(entry.snapshot == nil ? QuestWidgetLinks.passport : nil)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular: QuestNextStopCircular(snapshot: entry.snapshot)
        case .accessoryRectangular: QuestNextStopRectangular(snapshot: entry.snapshot)
        case .systemMedium: QuestNextStopMedium(snapshot: entry.snapshot)
        default: QuestNextStopSmall(snapshot: entry.snapshot)
        }
    }
}

enum QuestNextStopStyle {
    static func symbol(_ snapshot: QuestNextStopSnapshot) -> String {
        QuestLiveActivityGlyph.symbol(.play, mode: snapshot.mode)
    }
    static func tint(_ snapshot: QuestNextStopSnapshot) -> Color {
        QuestLiveActivityGlyph.tint(.play, mode: snapshot.mode)
    }
}

/// Activity name (or the flow's title) above the stop.
struct QuestNextStopHeading: View {
    let snapshot: QuestNextStopSnapshot
    var body: some View {
        Label {
            if let title = snapshot.title, !title.isEmpty {
                Text(verbatim: title)
            } else {
                Text(QuestLiveActivityTitles.key(.play, mode: snapshot.mode))
            }
        } icon: {
            Image(systemName: QuestNextStopStyle.symbol(snapshot))
                .foregroundStyle(QuestNextStopStyle.tint(snapshot))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// `ProgressView` for the stop position, with the `2/5` value for VoiceOver.
struct QuestNextStopProgress: View {
    let snapshot: QuestNextStopSnapshot
    var body: some View {
        if let progress = QuestLiveActivityText.progress(snapshot.stopIndex, snapshot.stopCount) {
            ProgressView(value: progress.value, total: progress.total) {
                EmptyView()
            } currentValueLabel: {
                Text(verbatim: QuestLiveActivityText.fraction(snapshot.stopIndex, snapshot.stopCount))
                    .monospacedDigit()
            }
            .font(.caption)
            .tint(QuestNextStopStyle.tint(snapshot))
            .accessibilityLabel(Text("liveActivity.play.progress"))
        }
    }
}

struct QuestNextStopSmall: View {
    let snapshot: QuestNextStopSnapshot?
    var body: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 4) {
                QuestNextStopHeading(snapshot: snapshot)
                Text("widget.nextStop.label").font(.caption2).foregroundStyle(.secondary)
                Text(verbatim: snapshot.stopName)
                    .font(.headline)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                QuestNextStopProgress(snapshot: snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            QuestPassportEntry()
        }
    }
}

struct QuestNextStopMedium: View {
    let snapshot: QuestNextStopSnapshot?
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            QuestNextStopSmall(snapshot: snapshot)
            if snapshot == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Link(destination: QuestWidgetLinks.roam) {
                        Label("widget.roam.start", systemImage: "figure.walk")
                    }
                    Link(destination: QuestWidgetLinks.stories) {
                        Label("widget.story.continue", systemImage: "book")
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// No run in progress: the passport entry (opens the stamp album through `widgetURL`).
struct QuestPassportEntry: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text("widget.passport.title").font(.headline).lineLimit(2)
            Text("widget.passport.subtitle").font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct QuestNextStopRectangular: View {
    let snapshot: QuestNextStopSnapshot?
    var body: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("widget.nextStop.label")
                } icon: {
                    Image(systemName: QuestNextStopStyle.symbol(snapshot))
                }
                .font(.caption)
                Text(verbatim: snapshot.stopName).font(.headline).lineLimit(1)
                QuestNextStopProgress(snapshot: snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("widget.passport.title", systemImage: "book.closed").font(.headline)
                Text("widget.passport.subtitle").font(.caption).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

struct QuestNextStopCircular: View {
    let snapshot: QuestNextStopSnapshot?
    var body: some View {
        if let snapshot, let progress = QuestLiveActivityText.progress(snapshot.stopIndex, snapshot.stopCount) {
            Gauge(value: progress.value, in: 0...progress.total) {
                Image(systemName: "mappin")
            } currentValueLabel: {
                Text(verbatim: QuestLiveActivityText.fraction(snapshot.stopIndex, snapshot.stopCount)).monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel(Text(verbatim: snapshot.stopName))
            .accessibilityValue(Text(verbatim: QuestLiveActivityText.fraction(snapshot.stopIndex, snapshot.stopCount)))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: snapshot == nil ? "book.closed" : "mappin.and.ellipse")
                    .font(.title3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(snapshot == nil ? "widget.passport.title" : "widget.nextStop.label"))
        }
    }
}
