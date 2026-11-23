import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Source pages/merchant/bundle-reservations (free-explore bundle, merchant side):
/// GET api/free-explore/bundle/merchant/reservations {from,to} (ms; now-2d … +9d) and
/// POST api/free-explore/bundle/merchant/reservation/{id}/no-show. A no-show consumes the unit only:
/// it is not a redemption and creates no payout.
public struct MerchantBundleReservation: Equatable, Identifiable {
    public enum Status: String, CaseIterable { case booked = "BOOKED", cancelled = "CANCELLED", waived = "WAIVED", lateCancelled = "LATE_CANCELLED", noShow = "NO_SHOW", fulfilled = "FULFILLED", merchantExited = "MERCHANT_EXITED" }
    public let id: Int64
    public let start: Date
    public let status: Status
    public func canMarkNoShow(now: Date) -> Bool { status == .booked && start <= now }

    /// MP `shape`: any row with a bad id, time or unknown status makes the page untrusted (nil).
    public static func rows(_ value: MerchantBusinessValue, chinaCalendar: Calendar = MerchantBundleReservation.chinaCalendar) -> [MerchantBundleReservation]? {
        guard let list = value.array else { return nil }
        var rows: [MerchantBundleReservation] = []
        for item in list {
            guard let object = item.object,
                  let idText = object["id"]?.numberText,
                  idText.range(of: #"^[1-9][0-9]{0,18}$"#, options: .regularExpression) != nil, let id = Int64(idText),
                  let status = object.mbText("status").flatMap(Status.init(rawValue:)),
                  let start = startDate(object["startAt"], calendar: chinaCalendar) else { return nil }
            rows.append(.init(id: id, start: start, status: status))
        }
        return rows
    }
    static func startDate(_ value: MerchantBusinessValue?, calendar: Calendar) -> Date? {
        guard let value else { return nil }
        if case .number(let ms) = value { return Date(timeIntervalSince1970: NSDecimalNumber(decimal: ms).doubleValue / 1000) }
        guard let text = value.string,
              let match = text.range(of: #"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}"#, options: .regularExpression) else { return nil }
        let parts = text[match].split(whereSeparator: { "- T:".contains($0) }).compactMap { Int($0) }
        guard parts.count == 5 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: parts[3], minute: parts[4]))
    }
    public static var chinaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        return calendar
    }
    public static func window(now: Date) -> (from: Int64, to: Int64) {
        let day: Int64 = 24 * 3600 * 1000
        let from = Int64(now.timeIntervalSince1970 * 1000) - 2 * day
        return (from, from + 9 * day)
    }
}

extension MerchantBusinessService {
    func bundleReservations(now: Date, token: String) async throws -> [MerchantBundleReservation] {
        let window = MerchantBundleReservation.window(now: now)
        var request = try makeRequest(.query("api/free-explore/bundle/merchant/reservations",
                                             ["from": String(window.from), "to": String(window.to)]), token: token)
        request.httpMethod = "GET"; request.httpBody = nil; request.setValue(nil, forHTTPHeaderField: "Content-Type")
        let data = try await bundleSend(request)
        guard let rows = MerchantBundleReservation.rows(data) else { throw MerchantBusinessFailure.malformed }
        return rows
    }
    func markBundleNoShow(_ id: Int64, token: String) async throws {
        guard id > 0 else { throw MerchantBusinessFailure.invalid }
        var request = try makeRequest(.json("api/free-explore/bundle/merchant/reservation/\(id)/no-show", [:]), token: token)
        request.httpMethod = "POST"
        _ = try await bundleSend(request, write: true)
    }
}

public extension MerchantBusinessReading {
    /// Default: unavailable (offline examples and fakes never invent reservations).
    func bundleReservations(now: Date) async throws -> [MerchantBundleReservation] { throw MerchantBusinessFailure.disabled }
    func markBundleNoShow(_ id: Int64) async throws { throw MerchantBusinessFailure.disabled }
}
