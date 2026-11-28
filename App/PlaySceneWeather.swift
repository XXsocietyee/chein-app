import SwiftUI

/// fix/1128c-ai-weather (inventory B2 / C1 / C2), level A. The play scene's weather:
/// - a SURVIVAL theme look draws the author's story weather (`StoryClimate`, MP look-fx) and no live chip;
/// - otherwise the live weather at the route's first placed node, merged with the topic's
///   `api/play/environment` snapshot so the scene matches the server's weather gates; the chip opens the weather
///   events (`weather_event_rule`) with their server reasons.
struct PlaySceneWeather: ViewModifier {
    let topicID: Int?
    let latitude: Double?
    let longitude: Double?
    let look: CYThemeLook?
    @StateObject private var model = SceneWeatherModel()
    @State private var eventsShown = false

    func body(content: Content) -> some View {
        if let story = look?.storyClimate {
            content.overlay { CYWeatherScene(spec: .init(story: story), strength: 0.7) }
        } else {
            content
                .modifier(MapSceneWeather(latitude: latitude, longitude: longitude, topicID: topicID,
                                          onChipTap: Self.tapAction(model: model, shown: $eventsShown), strength: 0.7, model: model))
                .sheet(isPresented: $eventsShown) {
                    PlayWeatherEventsSheet(snapshot: model.environment, context: model.context, attribution: model.attribution)
                }
        }
    }

    /// The chip opens the events sheet only when the topic has weather events to show.
    static func tapAction(model: SceneWeatherModel, shown: Binding<Bool>) -> (() -> Void)? {
        guard let snapshot = model.environment, !snapshot.events.isEmpty else { return nil }
        return { shown.wrappedValue = true }
    }

    /// First node with a usable coordinate (the play scene's place), as (latitude, longitude).
    static func point(_ nodes: [PlayNode]) -> (latitude: Double, longitude: Double)? {
        for node in nodes {
            if let lat = node.latitude, let lng = node.longitude, MapSearchPlayerService.cell(latitude: lat, longitude: lng) != nil {
                return (lat, lng)
            }
        }
        return nil
    }
}

/// `weather_event_rule` events of the topic (`api/play/environment` `events`): active ones first with the author's
/// hint, inactive ones with the server's lock reason. Server wording is shown verbatim.
struct PlayWeatherEventsSection: View {
    let snapshot: PlayEnvironmentService.Snapshot

    var body: some View {
        Section {
            ForEach(snapshot.orderedEvents) { event in
                PlayWeatherEventRow(event: event)
            }
            if snapshot.sourceStatus == .fallbackUnknown {
                Label(LocalizedStringKey("weather.events.sourceUnknown"), systemImage: "exclamationmark.triangle")
                    .cyText(.meta)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("play.weather.sourceUnknown")
            }
        } header: {
            Text("weather.events.title")
        } footer: {
            Text("weather.events.footer")
        }
        .accessibilityIdentifier("play.weather.events")
    }
}

private struct PlayWeatherEventRow: View {
    let event: PlayEnvironmentService.Event

    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: event.active ? "sparkles" : Self.symbol(event.conditionKey))
                .foregroundStyle(event.active ? CYColor.successText : CYColor.textTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: event.ruleName.isEmpty ? "—" : event.ruleName)
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                if event.active, let hint = event.taskLabel {
                    Text(verbatim: hint).cyText(.body).foregroundStyle(CYColor.textPrimary)
                }
                Text(LocalizedStringKey(event.active ? "weather.events.active" : "weather.events.waiting"))
                    .cyText(.meta)
                    .foregroundStyle(event.active ? CYColor.successText : CYColor.textSecondary)
                if let reason = event.active ? event.reason : (event.lockReason ?? event.reason) {
                    Text(verbatim: reason).cyText(.meta).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("play.weather.event.\(event.id)")
    }

    static func symbol(_ key: String) -> String {
        switch key {
        case "weather": return "cloud.sun"
        case "daypart": return "clock"
        case "weekpart": return "calendar"
        case "season": return "leaf"
        default: return "lock"
        }
    }
}

private struct PlayWeatherEventsSheet: View {
    let snapshot: PlayEnvironmentService.Snapshot?
    let context: WeatherContext?
    let attribution: WeatherKitReader.Attribution?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let context, context.reportsCondition {
                    Section {
                        CYWeatherChip(context: context, attribution: attribution)
                            .listRowBackground(Color.clear)
                    }
                }
                if let snapshot, !snapshot.events.isEmpty {
                    PlayWeatherEventsSection(snapshot: snapshot)
                } else {
                    ContentUnavailableView(LocalizedStringKey("weather.events.empty"), systemImage: "cloud.sun")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("weather.events.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("weather.events.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
