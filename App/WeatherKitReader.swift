import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// fix/1128c-ai-weather (inventory A3). Apple WeatherKit behind the owner build setting `CY_WEATHERKIT_ENABLED`
/// (Info.plist `CYWeatherKitEnabled`, `Config/OwnerValues.xcconfig`). WeatherKit also needs the WeatherKit capability
/// on the App ID and the `com.apple.developer.weatherkit` entitlement (owner values, `docs/release/owner-values.md`).
/// Off, no entitlement, no network or any error: nil, and the scene falls back to the backend readings.
/// Each coordinate is rounded to the backend's ~5.5 km cell centre first, so the exact position never leaves the device
/// in a weather request and one cell is asked at most every ten minutes.
@MainActor final class WeatherKitReader {
    static let shared = WeatherKitReader()
    static let infoKey = "CYWeatherKitEnabled"
    static let ttl: TimeInterval = 600

    struct Attribution: Equatable {
        let lightMarkURL: URL
        let darkMarkURL: URL
        let legalPageURL: URL
        let serviceName: String
    }

    /// The build setting. Values `YES` / `1` / `true` switch it on; empty or anything else keeps it off.
    nonisolated static func isEnabled(info: [String: Any]? = Bundle.main.infoDictionary) -> Bool {
        guard let raw = info?[infoKey] else { return false }
        if let flag = raw as? Bool { return flag }
        let text = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return text == "yes" || text == "1" || text == "true"
    }

    private var cache: [String: (at: Date, reading: DeviceWeatherReading?)] = [:]
    private var failedUntil: Date?
    private(set) var attribution: Attribution?

    func reading(latitude: Double, longitude: Double, now: Date = Date()) async -> DeviceWeatherReading? {
        guard Self.isEnabled(), let cell = MapSearchPlayerService.cell(latitude: latitude, longitude: longitude) else { return nil }
        if let failedUntil, now < failedUntil { return nil }
        let key = "\(cell.0):\(cell.1)"
        if let hit = cache[key], now.timeIntervalSince(hit.at) < Self.ttl { return hit.reading }
        let centre = CLLocation(latitude: (Double(cell.0) + 0.5) / MapSearchPlayerService.cellsPerDegree,
                                longitude: (Double(cell.1) + 0.5) / MapSearchPlayerService.cellsPerDegree)
        let value = await Self.fetch(centre)
        if value == nil { failedUntil = now.addingTimeInterval(Self.ttl) }
        cache[key] = (now, value)
        if cache.count > 32, let oldest = cache.min(by: { $0.value.at < $1.value.at })?.key { cache[oldest] = nil }
        if value != nil, attribution == nil { attribution = await Self.fetchAttribution() }
        return value
    }

    private static func fetch(_ location: CLLocation) async -> DeviceWeatherReading? {
        #if canImport(WeatherKit)
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            let kind = WeatherSceneKind.apple(current.condition.rawValue)
            let rate = current.precipitationIntensity.converted(to: .kilometersPerHour).value * 1_000_000
            let celsius = current.temperature.converted(to: .celsius).value
            return DeviceWeatherReading(kind: kind,
                                        intensity: DeviceWeatherReading.intensity(precipitationMillimetresPerHour: rate, kind: kind),
                                        temperatureCelsius: celsius, isDaylight: current.isDaylight)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private static func fetchAttribution() async -> Attribution? {
        #if canImport(WeatherKit)
        guard let value = try? await WeatherService.shared.attribution else { return nil }
        return Attribution(lightMarkURL: value.combinedMarkLightURL, darkMarkURL: value.combinedMarkDarkURL,
                           legalPageURL: value.legalPageURL, serviceName: value.serviceName)
        #else
        return nil
        #endif
    }

    /// Sign-out: forget cached readings.
    func reset() { cache.removeAll(); failedUntil = nil }
}
