import SwiftUI

/// fix/1128c-ai-weather: one live-weather host for the roam map home, the roam browser map, live roam and the play
/// map / scene. It merges the backend readings with WeatherKit (`WeatherContext.compose`), draws `CYWeatherScene`
/// and the condition + temperature chip, and publishes the result to `WeatherContextBoard.shared` for the AI guide.
@MainActor final class SceneWeatherModel: ObservableObject {
    @Published private(set) var context: WeatherContext?
    @Published private(set) var environment: PlayEnvironmentService.Snapshot?
    @Published private(set) var attribution: WeatherKitReader.Attribution?
    /// The raw `/api/map/weather` reading for the cell (fix/1128c: the AI guide reads it; no second request).
    @Published private(set) var mapReading: MapSearchPlayerService.Weather?

    private var mapCache: [String: (at: Date, weather: MapSearchPlayerService.Weather?)] = [:]
    private var environmentCache: [Int: (at: Date, snapshot: PlayEnvironmentService.Snapshot?)] = [:]
    static let ttl: TimeInterval = 600

    struct Request: Hashable {
        let cell: String
        let topicID: Int?
        let account: Int?
    }

    static func request(latitude: Double?, longitude: Double?, topicID: Int?, account: Int?) -> Request {
        let cell: String
        if let latitude, let longitude, let value = MapSearchPlayerService.cell(latitude: latitude, longitude: longitude) {
            cell = "\(value.0):\(value.1)"
        } else {
            cell = ""
        }
        return Request(cell: cell, topicID: topicID.flatMap { $0 > 0 ? $0 : nil }, account: account)
    }

    func refresh(latitude: Double?, longitude: Double?, topicID: Int?, client: PlayerCapabilityClient?, now: Date = Date()) async {
        var hasPoint = false
        if let latitude, let longitude, MapSearchPlayerService.cell(latitude: latitude, longitude: longitude) != nil { hasPoint = true }
        var map: MapSearchPlayerService.Weather?
        if hasPoint, let latitude, let longitude, let client {
            map = await mapWeather(latitude: latitude, longitude: longitude, client: client, now: now)
        }
        var snapshot: PlayEnvironmentService.Snapshot?
        if let topicID, topicID > 0, let client {
            snapshot = await environmentSnapshot(topicID: topicID, client: client, now: now)
        }
        var device: DeviceWeatherReading?
        if hasPoint, let latitude, let longitude {
            device = await WeatherKitReader.shared.reading(latitude: latitude, longitude: longitude, now: now)
        }
        guard !Task.isCancelled else { return }
        environment = snapshot
        if mapReading != map { mapReading = map }
        attribution = device == nil ? nil : WeatherKitReader.shared.attribution
        let composed = WeatherContext.compose(environmentWeather: snapshot?.weather, environmentDaypart: snapshot?.daypart,
                                              map: map.map { (kind: $0.kind, intensity: $0.intensity) }, device: device,
                                              latitude: latitude, longitude: longitude, now: now)
        context = composed
        WeatherContextBoard.shared.publish(composed)
    }

    private func mapWeather(latitude: Double, longitude: Double, client: PlayerCapabilityClient, now: Date) async -> MapSearchPlayerService.Weather? {
        guard let cell = MapSearchPlayerService.cell(latitude: latitude, longitude: longitude) else { return nil }
        let key = "\(cell.0):\(cell.1)"
        if let hit = mapCache[key], now.timeIntervalSince(hit.at) < Self.ttl { return hit.weather }
        let value = await MapSearchPlayerService(client: client).weather(latitude: latitude, longitude: longitude)
        mapCache[key] = (now, value)
        if mapCache.count > 64, let oldest = mapCache.min(by: { $0.value.at < $1.value.at })?.key { mapCache[oldest] = nil }
        return value
    }

    private func environmentSnapshot(topicID: Int, client: PlayerCapabilityClient, now: Date) async -> PlayEnvironmentService.Snapshot? {
        if let hit = environmentCache[topicID], now.timeIntervalSince(hit.at) < Self.ttl { return hit.snapshot }
        let value = await PlayEnvironmentService(client: client).snapshot(topicID: topicID)
        environmentCache[topicID] = (now, value)
        return value
    }

    /// Refreshes now and then every ten minutes while the host is on screen (the light follows the sun, the cache TTL
    /// matches `weather-core.js`). Cancelled with the hosting `.task`.
    func keepFresh(latitude: Double?, longitude: Double?, topicID: Int?, client: PlayerCapabilityClient?) async {
        while !Task.isCancelled {
            await refresh(latitude: latitude, longitude: longitude, topicID: topicID, client: client)
            try? await Task.sleep(nanoseconds: UInt64(Self.ttl * 1_000_000_000))
        }
    }

    /// Pull-to-refresh / session reload: re-read the topic environment (event rules can flip on the hour).
    func invalidateEnvironment() { environmentCache.removeAll() }
}

/// Map weather ambience (MP `cy-map-weather`): particles and light above the map, below cards and buttons.
/// Nil (no reading, any failure) draws nothing, as in the MP.
struct MapWeatherOverlay: View {
    let spec: CYWeatherScene.Spec?
    var strength: Double = 1

    init(context: WeatherContext?, strength: Double = 1) {
        spec = context.map { CYWeatherScene.Spec($0) }
        self.strength = strength
    }

    /// Fixtures and the plain backend reading (`kind` rain / snow / fog).
    init(weather: MapSearchPlayerService.Weather?) {
        spec = weather.flatMap { value in
            WeatherSceneKind.server(value.kind).map { CYWeatherScene.Spec(kind: $0, intensity: value.intensity) }
        }
    }

    var body: some View {
        if let spec {
            CYWeatherScene(spec: spec, strength: strength)
        }
    }
}

/// Condition + temperature chip ("Rain · 12°"). Dynamic Type, one VoiceOver element. When any value came from Apple
/// Weather, the Apple Weather mark and the legal link sit under it (WeatherKit attribution requirement).
struct CYWeatherChip: View {
    let context: WeatherContext
    let attribution: WeatherKitReader.Attribution?
    var action: (() -> Void)? = nil

    @Environment(\.locale) private var locale

    private var temperature: String? {
        context.temperatureText(usesMetric: locale.measurementSystem != .us)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if let action {
                Button(action: action) { chipLabel }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("weather.chip.hint"))
            } else {
                chipLabel
            }
            if context.usesAppleWeather {
                AppleWeatherAttributionMark(attribution: attribution)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityIdentifier("weather.chip")
    }

    private var chipLabel: some View {
        HStack(spacing: CYSpacing.xs) {
            Image(systemName: context.kind.symbolName(isDaylight: context.isDaylight))
                .symbolRenderingMode(.multicolor)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(context.kind.titleKey))
                .cyText(.bodyMedium)
            if let temperature {
                Text(verbatim: temperature)
                    .cyText(.numericBody)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.sm)
        .background(.regularMaterial, in: Capsule())
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Apple Weather trademark + link to the legal attribution page (WeatherKit terms). Uses the mark images
/// `WeatherService.attribution` returns; until they load, the text mark with the same link (or plain text).
struct AppleWeatherAttributionMark: View {
    let attribution: WeatherKitReader.Attribution?
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption2) private var markHeight: CGFloat = 12

    var body: some View {
        if let attribution {
            Link(destination: attribution.legalPageURL) {
                AsyncImage(url: colorScheme == .dark ? attribution.darkMarkURL : attribution.lightMarkURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text("weather.attribution.apple").cyText(.meta)
                }
                .frame(height: markHeight)
            }
            .accessibilityLabel(Text("weather.attribution.legal"))
            .accessibilityIdentifier("weather.attribution")
        } else {
            Text("weather.attribution.apple")
                .cyText(.meta)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("weather.attribution")
        }
    }
}

/// The host modifier. `showsChip` false where the map already has a control row at that corner (roam browser).
struct MapSceneWeather: ViewModifier {
    let latitude: Double?
    let longitude: Double?
    var topicID: Int? = nil
    var showsChip = true
    var chipAlignment: Alignment = .topLeading
    var onChipTap: (() -> Void)? = nil
    var strength: Double = 1
    @ObservedObject var model: SceneWeatherModel
    @Environment(\.socialRoamCapabilities) private var capabilities

    func body(content: Content) -> some View {
        content
            .overlay { MapWeatherOverlay(context: model.context, strength: strength) }
            .overlay(alignment: chipAlignment) { chip }
            .task(id: SceneWeatherModel.request(latitude: latitude, longitude: longitude, topicID: topicID, account: capabilities?.accountID)) {
                await model.keepFresh(latitude: latitude, longitude: longitude, topicID: topicID, client: capabilities?.client)
            }
    }

    @ViewBuilder private var chip: some View {
        if showsChip, let context = model.context, context.reportsCondition {
            CYWeatherChip(context: context, attribution: model.attribution, action: onChipTap)
                .padding(.horizontal, CYSpacing.lg)
                .padding(.vertical, CYSpacing.sm)
        }
    }
}

/// Owns a `SceneWeatherModel` for hosts that do not need to read it themselves.
struct OwnedMapSceneWeather: ViewModifier {
    let latitude: Double?
    let longitude: Double?
    var topicID: Int? = nil
    var showsChip = true
    var chipAlignment: Alignment = .topLeading
    @StateObject private var model = SceneWeatherModel()

    func body(content: Content) -> some View {
        content.modifier(MapSceneWeather(latitude: latitude, longitude: longitude, topicID: topicID, showsChip: showsChip,
                                         chipAlignment: chipAlignment, model: model))
    }
}
