import SwiftUI
import WidgetKit

/// Components r1 (C2): Home Screen, Lock Screen and StandBy widgets fed by the App Group sections in
/// `QuestWidgetBoard` (written by the app where it already has the values). No network: each widget shows only
/// what the app stored and falls back to an entry that opens the matching MP page. Dark high-contrast surface with
/// one accent per widget from the feature's existing tint (roam green, play orange, passport accent, messages blue).
/// System fonts, SF Symbols, `Text(timerInterval:)`, `Gauge`, `ProgressView` and `.contentTransition(.numericText())`.

// MARK: Shared surface

struct QuestBoardSurface: View {
    var body: some View {
        LinearGradient(colors: [Color(white: 0.12), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// Dark surface on the Home Screen / StandBy; accessory families drop the background themselves.
    func questBoardBackground() -> some View {
        environment(\.colorScheme, .dark)
            .containerBackground(for: .widget) { QuestBoardSurface() }
    }
}

/// Small caption heading with the widget's accent glyph.
struct QuestBoardHeading: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// `99+` cap for counters, as the MP badges show.
enum QuestBoardCount {
    static func text(_ value: Int) -> String { value > 99 ? "99+" : String(value) }
}

/// A big counter that rolls between timeline entries.
struct QuestBoardCounter: View {
    let value: Int
    let tint: Color
    var body: some View {
        Text(verbatim: QuestBoardCount.text(value))
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(value > 0 ? tint : Color.secondary)
            .contentTransition(.numericText(value: Double(value)))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }
}

/// Capsule call to action ("加入", "开始漫游") on medium widgets.
struct QuestBoardAction: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    let url: URL
    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tint, in: Capsule())
        }
    }
}

// MARK: Next event countdown ("Starts in 3:51 · 加入")

struct QuestEventCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuestWidgetBoard.eventKind, provider: QuestEventProvider()) { entry in
            QuestEventWidgetView(entry: entry).questBoardBackground()
        }
        .configurationDisplayName("widget.event.name")
        .description("widget.event.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct QuestEventEntry: TimelineEntry {
    let date: Date
    let event: QuestWidgetBoard.Event?
}

struct QuestEventProvider: TimelineProvider {
    /// Inside this window the widget counts down to the second; further out it shows the start date.
    static let countdownWindow: TimeInterval = 24 * 60 * 60

    func placeholder(in context: Context) -> QuestEventEntry { QuestEventEntry(date: Date(), event: nil) }

    func getSnapshot(in context: Context, completion: @escaping (QuestEventEntry) -> Void) {
        completion(QuestEventEntry(date: Date(), event: Self.current(now: Date())))
    }

    /// Entries at now, when the countdown window opens, at the start and when the event leaves the widget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestEventEntry>) -> Void) {
        let now = Date()
        guard let event = Self.current(now: now) else {
            completion(Timeline(entries: [QuestEventEntry(date: now, event: nil)], policy: .never))
            return
        }
        let marks: [Date] = [event.startsAt.addingTimeInterval(-Self.countdownWindow), event.startsAt]
        var entries = [QuestEventEntry(date: now, event: event)]
        entries += marks.filter { $0 > now }.map { QuestEventEntry(date: $0, event: event) }
        entries.append(QuestEventEntry(date: event.expiresAt, event: nil))
        completion(Timeline(entries: entries, policy: .never))
    }

    static func current(now: Date) -> QuestWidgetBoard.Event? {
        guard let event = QuestWidgetStore.section(QuestWidgetBoard.Event.self, key: QuestWidgetStore.eventKey),
              event.expiresAt > now else { return nil }
        return event
    }
}

/// "Starts in 3:51:20" inside the window, the start date further out, "进行中" once started.
struct QuestEventWhen: View {
    let event: QuestWidgetBoard.Event
    let date: Date
    var font: Font = .system(.title, design: .rounded).weight(.bold)

    var body: some View {
        if event.startsAt <= date {
            Text("widget.event.started").font(font).foregroundStyle(Color.orange)
        } else if event.startsAt.timeIntervalSince(date) <= QuestEventProvider.countdownWindow {
            Text(timerInterval: date...event.startsAt, countsDown: true)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(Color.orange)
        } else {
            Text(event.startsAt, format: .dateTime.month().day().hour().minute())
                .font(.headline)
                .foregroundStyle(Color.orange)
        }
    }
}

struct QuestEventWhenCaption: View {
    let event: QuestWidgetBoard.Event
    let date: Date
    var body: some View {
        if event.startsAt > date {
            Text("widget.event.startsIn").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct QuestEventWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuestEventEntry

    var body: some View {
        content.widgetURL(QuestWidgetBoard.ticket(entry.event?.ticketID))
    }

    @ViewBuilder private var content: some View {
        if let event = entry.event {
            switch family {
            case .accessoryInline: QuestEventInline(event: event, date: entry.date)
            case .accessoryRectangular: QuestEventRectangular(event: event, date: entry.date)
            case .systemMedium: QuestEventMedium(event: event, date: entry.date)
            default: QuestEventSmall(event: event, date: entry.date)
            }
        } else {
            QuestEventEmpty(family: family)
        }
    }
}

struct QuestEventSmall: View {
    let event: QuestWidgetBoard.Event
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            QuestBoardHeading(title: "widget.event.heading", symbol: "calendar.badge.clock", tint: .orange)
            Text(verbatim: event.title).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            QuestEventWhenCaption(event: event, date: date)
            QuestEventWhen(event: event, date: date).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuestEventMedium: View {
    let event: QuestWidgetBoard.Event
    let date: Date
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                QuestBoardHeading(title: "widget.event.heading", symbol: "calendar.badge.clock", tint: .orange)
                Text(verbatim: event.title).font(.headline).lineLimit(2)
                if let place = event.place, !place.isEmpty {
                    Label { Text(verbatim: place) } icon: { Image(systemName: "mappin.and.ellipse") }
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                QuestEventWhenCaption(event: event, date: date)
                QuestEventWhen(event: event, date: date).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            QuestBoardAction(title: "widget.event.join", symbol: "arrow.right.circle.fill", tint: .orange,
                             url: QuestWidgetBoard.ticket(event.ticketID))
        }
    }
}

struct QuestEventRectangular: View {
    let event: QuestWidgetBoard.Event
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label { Text(verbatim: event.title) } icon: { Image(systemName: "calendar.badge.clock") }
                .font(.headline).lineLimit(1)
            QuestEventWhenCaption(event: event, date: date)
            QuestEventWhen(event: event, date: date, font: .title3.weight(.semibold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct QuestEventInline: View {
    let event: QuestWidgetBoard.Event
    let date: Date
    var body: some View {
        if event.startsAt > date, event.startsAt.timeIntervalSince(date) <= QuestEventProvider.countdownWindow {
            Label { Text(timerInterval: date...event.startsAt, countsDown: true) } icon: {
                Image(systemName: "calendar.badge.clock")
            }
        } else {
            Label { Text(verbatim: event.title) } icon: { Image(systemName: "calendar.badge.clock") }
        }
    }
}

struct QuestEventEmpty: View {
    let family: WidgetFamily
    var body: some View {
        switch family {
        case .accessoryInline:
            Label("widget.event.empty", systemImage: "calendar")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("widget.event.heading", systemImage: "calendar").font(.headline)
                Text("widget.event.empty").font(.caption).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        default:
            VStack(alignment: .leading, spacing: 4) {
                QuestBoardHeading(title: "widget.event.heading", symbol: "calendar", tint: .orange)
                Spacer(minLength: 0)
                Text("widget.event.empty").font(.headline).lineLimit(2)
                Text("widget.event.browse").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: Roam streak grid (days walked)

struct QuestRoamStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuestWidgetBoard.roamStreakKind, provider: QuestRoamStreakProvider()) { entry in
            QuestRoamStreakWidgetView(entry: entry).questBoardBackground()
        }
        .configurationDisplayName("widget.streak.name")
        .description("widget.streak.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct QuestRoamStreakEntry: TimelineEntry {
    let date: Date
    let days: QuestWidgetBoard.RoamDays
}

struct QuestRoamStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuestRoamStreakEntry {
        QuestRoamStreakEntry(date: Date(), days: QuestWidgetBoard.RoamDays(days: []))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestRoamStreakEntry) -> Void) {
        completion(QuestRoamStreakEntry(date: Date(), days: Self.stored()))
    }

    /// The grid moves at midnight; the app reloads after a walk.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestRoamStreakEntry>) -> Void) {
        let now = Date()
        let days = Self.stored()
        var entries = [QuestRoamStreakEntry(date: now, days: days)]
        let today = Calendar.current.startOfDay(for: now)
        if let midnight = Calendar.current.date(byAdding: .day, value: 1, to: today) {
            entries.append(QuestRoamStreakEntry(date: midnight, days: days))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func stored() -> QuestWidgetBoard.RoamDays {
        QuestWidgetStore.section(QuestWidgetBoard.RoamDays.self, key: QuestWidgetStore.roamDaysKey)
            ?? QuestWidgetBoard.RoamDays(days: [])
    }
}

/// Week columns (oldest left), Monday-first rows like the MP history calendar; today is outlined.
struct QuestStreakGrid: View {
    let days: QuestWidgetBoard.RoamDays
    let date: Date
    let weeks: Int
    var cell: CGFloat = 10

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    /// Start of the oldest shown week.
    private var firstDay: Date {
        let today = calendar.startOfDay(for: date)
        let weekday = (calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7
        let thisWeek = calendar.date(byAdding: .day, value: -weekday, to: today) ?? today
        return calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: thisWeek) ?? thisWeek
    }

    var body: some View {
        let start = firstDay
        let today = calendar.startOfDay(for: date)
        HStack(spacing: 3) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: start) ?? start
                        QuestStreakCell(walked: days.walked(on: day, calendar: calendar),
                                        isToday: day == today, isFuture: day > today, size: cell)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct QuestStreakCell: View {
    let walked: Bool
    let isToday: Bool
    let isFuture: Bool
    let size: CGFloat

    private var fill: Color {
        if isFuture { return Color.clear }
        return walked ? Color.green : Color.white.opacity(0.12)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(fill)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                }
            }
            .frame(width: size, height: size)
    }
}

/// "5 天连续漫游" with the VoiceOver summary of the grid.
struct QuestStreakHeadline: View {
    let days: QuestWidgetBoard.RoamDays
    let date: Date
    let span: Int

    var body: some View {
        let streak = days.streak(now: date)
        let walked = days.walkedCount(last: span, now: date)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: String(streak))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(streak > 0 ? Color.green : Color.secondary)
                    .contentTransition(.numericText(value: Double(streak)))
                Text("widget.streak.days").font(.caption).foregroundStyle(.secondary)
            }
            Text("widget.streak.walked \(walked) \(span)").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.streak.a11y \(streak) \(walked) \(span)"))
    }
}

struct QuestRoamStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuestRoamStreakEntry

    var body: some View {
        content.widgetURL(QuestWidgetBoard.roamHistory)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular: QuestStreakCircular(days: entry.days, date: entry.date)
        case .accessoryRectangular: QuestStreakRectangular(days: entry.days, date: entry.date)
        case .systemMedium: QuestStreakMedium(days: entry.days, date: entry.date)
        default: QuestStreakSmall(days: entry.days, date: entry.date)
        }
    }
}

struct QuestStreakSmall: View {
    let days: QuestWidgetBoard.RoamDays
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            QuestBoardHeading(title: "widget.streak.heading", symbol: "figure.walk", tint: .green)
            QuestStreakHeadline(days: days, date: date, span: 35)
            Spacer(minLength: 0)
            QuestStreakGrid(days: days, date: date, weeks: 5, cell: 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuestStreakMedium: View {
    let days: QuestWidgetBoard.RoamDays
    let date: Date
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                QuestBoardHeading(title: "widget.streak.heading", symbol: "figure.walk", tint: .green)
                QuestStreakHeadline(days: days, date: date, span: 84)
                Spacer(minLength: 0)
                QuestBoardAction(title: "widget.roam.start", symbol: "figure.walk", tint: .green,
                                 url: QuestWidgetLinks.roam)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            QuestStreakGrid(days: days, date: date, weeks: 12, cell: 12)
        }
    }
}

struct QuestStreakCircular: View {
    let days: QuestWidgetBoard.RoamDays
    let date: Date
    var body: some View {
        let streak = days.streak(now: date)
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "figure.walk").font(.caption)
                Text(verbatim: String(streak)).font(.title3.weight(.bold)).monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.streak.a11y \(streak) \(days.walkedCount(last: 7, now: date)) \(7)"))
    }
}

struct QuestStreakRectangular: View {
    let days: QuestWidgetBoard.RoamDays
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("widget.streak.heading", systemImage: "figure.walk").font(.headline)
            QuestStreakHeadline(days: days, date: date, span: 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: City revealed ring % and passport stamps

struct QuestCityProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuestWidgetBoard.cityProgressKind, provider: QuestCityProgressProvider()) { entry in
            QuestCityProgressWidgetView(entry: entry).questBoardBackground()
        }
        .configurationDisplayName("widget.city.name")
        .description("widget.city.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct QuestCityProgressEntry: TimelineEntry {
    let date: Date
    let progress: QuestWidgetBoard.CityProgress?
}

struct QuestCityProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuestCityProgressEntry {
        QuestCityProgressEntry(date: Date(), progress: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestCityProgressEntry) -> Void) {
        completion(QuestCityProgressEntry(date: Date(), progress: Self.stored()))
    }

    /// The app reloads when the share or the stamp count changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestCityProgressEntry>) -> Void) {
        completion(Timeline(entries: [QuestCityProgressEntry(date: Date(), progress: Self.stored())], policy: .never))
    }

    static func stored() -> QuestWidgetBoard.CityProgress? {
        QuestWidgetStore.section(QuestWidgetBoard.CityProgress.self, key: QuestWidgetStore.cityProgressKey)
    }
}

enum QuestCityText {
    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

/// The ring: a system `Gauge` in its circular capacity style, tinted with the passport accent.
struct QuestCityRing: View {
    let revealed: Double
    var body: some View {
        Gauge(value: revealed, in: 0...1) {
            Image(systemName: "map")
        } currentValueLabel: {
            Text(verbatim: QuestCityText.percent(revealed)).monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Color.accentColor)
        .accessibilityLabel(Text("widget.city.revealed"))
        .accessibilityValue(Text(verbatim: QuestCityText.percent(revealed)))
    }
}

struct QuestStampsCounter: View {
    let stamps: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuestBoardCounter(value: stamps, tint: .accentColor)
            Text("widget.city.stamps").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.city.stamps.a11y \(stamps)"))
    }
}

struct QuestCityProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuestCityProgressEntry

    var body: some View {
        content.widgetURL(entry.progress?.revealed == nil ? QuestWidgetLinks.passport : QuestWidgetLinks.roam)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular: QuestCityCircular(progress: entry.progress)
        case .accessoryRectangular: QuestCityRectangular(progress: entry.progress)
        case .systemMedium: QuestCityMedium(progress: entry.progress)
        default: QuestCitySmall(progress: entry.progress)
        }
    }
}

struct QuestCityHeading: View {
    let progress: QuestWidgetBoard.CityProgress?
    var body: some View {
        if let name = progress?.cityName, !name.isEmpty {
            Label {
                Text(verbatim: name)
            } icon: {
                Image(systemName: "building.2").foregroundStyle(Color.accentColor)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
        } else {
            QuestBoardHeading(title: "widget.city.heading", symbol: "building.2", tint: .accentColor)
        }
    }
}

struct QuestCitySmall: View {
    let progress: QuestWidgetBoard.CityProgress?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            QuestCityHeading(progress: progress)
            Spacer(minLength: 0)
            if let revealed = progress?.revealed {
                QuestCityRing(revealed: revealed).scaleEffect(1.3).frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text("widget.city.revealed").font(.caption).foregroundStyle(.secondary)
            } else if let stamps = progress?.stamps {
                QuestStampsCounter(stamps: stamps)
            } else {
                QuestPassportEntry()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuestCityMedium: View {
    let progress: QuestWidgetBoard.CityProgress?
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                QuestCityHeading(progress: progress)
                Spacer(minLength: 0)
                QuestStampsCounter(stamps: progress?.stamps ?? 0)
                Link(destination: QuestWidgetLinks.passport) {
                    Label("widget.passport.title", systemImage: "book.closed").font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 6) {
                QuestCityRing(revealed: progress?.revealed ?? 0).scaleEffect(1.5)
                Spacer(minLength: 0)
                Text("widget.city.revealed").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct QuestCityCircular: View {
    let progress: QuestWidgetBoard.CityProgress?
    var body: some View {
        if let revealed = progress?.revealed {
            QuestCityRing(revealed: revealed)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "book.closed").font(.title3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("widget.passport.title"))
        }
    }
}

struct QuestCityRectangular: View {
    let progress: QuestWidgetBoard.CityProgress?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("widget.city.heading", systemImage: "building.2").font(.headline).lineLimit(1)
            if let revealed = progress?.revealed {
                ProgressView(value: revealed) {
                    EmptyView()
                } currentValueLabel: {
                    Text(verbatim: QuestCityText.percent(revealed)).monospacedDigit()
                }
                .accessibilityLabel(Text("widget.city.revealed"))
            }
            if let stamps = progress?.stamps {
                Text("widget.city.stamps.a11y \(stamps)").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Channel unread and club new posts

struct QuestCommunityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuestWidgetBoard.communityKind, provider: QuestCommunityProvider()) { entry in
            QuestCommunityWidgetView(entry: entry).questBoardBackground()
        }
        .configurationDisplayName("widget.community.name")
        .description("widget.community.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline])
    }
}

struct QuestCommunityEntry: TimelineEntry {
    let date: Date
    let community: QuestWidgetBoard.Community?
}

struct QuestCommunityProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuestCommunityEntry { QuestCommunityEntry(date: Date(), community: nil) }

    func getSnapshot(in context: Context, completion: @escaping (QuestCommunityEntry) -> Void) {
        completion(QuestCommunityEntry(date: Date(), community: Self.stored()))
    }

    /// The app reloads when a counter changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestCommunityEntry>) -> Void) {
        completion(Timeline(entries: [QuestCommunityEntry(date: Date(), community: Self.stored())], policy: .never))
    }

    static func stored() -> QuestWidgetBoard.Community? {
        QuestWidgetStore.section(QuestWidgetBoard.Community.self, key: QuestWidgetStore.communityKey)
    }
}

/// One counter tile: glyph, rolling number, caption.
struct QuestCommunityTile: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    let value: Int
    let a11y: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).accessibilityHidden(true)
            Spacer(minLength: 0)
            QuestBoardCounter(value: value, tint: tint)
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }
}

struct QuestCommunityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuestCommunityEntry

    private var unread: Int { entry.community?.unread ?? 0 }
    private var posts: Int { entry.community?.clubNewPosts ?? 0 }

    var body: some View {
        content.widgetURL(unread > 0 || posts == 0 ? QuestWidgetBoard.messages
                          : QuestWidgetBoard.club(entry.community?.clubID))
    }

    private var unreadTile: QuestCommunityTile {
        QuestCommunityTile(title: "widget.community.unread", symbol: "bubble.left.and.bubble.right.fill", tint: .blue,
                           value: unread, a11y: Text("widget.community.unread.a11y \(unread)"))
    }

    private var postsTile: QuestCommunityTile {
        QuestCommunityTile(title: "widget.community.posts", symbol: "person.3.fill", tint: .blue,
                           value: posts, a11y: Text("widget.community.posts.a11y \(posts)"))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular: QuestCommunityCircular(unread: unread)
        case .accessoryInline:
            Label { Text("widget.community.inline \(unread) \(posts)") } icon: {
                Image(systemName: "bubble.left.and.bubble.right")
            }
        case .systemMedium:
            HStack(spacing: 16) {
                Link(destination: QuestWidgetBoard.messages) { unreadTile }
                Divider().overlay(Color.white.opacity(0.2))
                Link(destination: QuestWidgetBoard.club(entry.community?.clubID)) {
                    VStack(alignment: .leading, spacing: 2) {
                        postsTile
                        if let name = entry.community?.clubName, !name.isEmpty {
                            Text(verbatim: name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                QuestBoardHeading(title: "widget.community.heading", symbol: "bubble.left.and.bubble.right.fill",
                                  tint: .blue)
                HStack(spacing: 8) {
                    unreadTile
                    postsTile
                }
            }
        }
    }
}

struct QuestCommunityCircular: View {
    let unread: Int
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "bubble.left.fill").font(.caption)
                Text(verbatim: QuestBoardCount.text(unread)).font(.title3.weight(.bold)).monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.community.unread.a11y \(unread)"))
    }
}
