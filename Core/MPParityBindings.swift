import Foundation

/// Mini-program parity for the player loop in `chengyinhub-xcx/subpackageJourney/utils/journey-api.js`
/// at hengyin `1c80c5aea8f721ca8575e6108048495b100f5576`. One case per export. Paths and methods are
/// that file. `money` cases are named so they stay visible, and `JourneyLoopSource` does not send them.
public enum MPParityBindings {
    public static let sourceRevision = "1c80c5aea8f721ca8575e6108048495b100f5576"
    public static let landingPage = "subpackageJourney/pages/landing/index"

    public enum Journey: String, CaseIterable, Equatable, Sendable {
        case report
        case memory
        case choices
        case seats
        case rank
        case teamDetail
        case teamRanking
        case rate
        case referral
        case gift
        case issueReferral
        case affiliate
        case seatInvite
        case seatInvitation
        case seatClaim
        case seatCancel
        case giftClaim
    }

    public struct JourneyCase: Equatable, Sendable {
        public let name: Journey
        public let method: String
        public let path: String
        public let json: Bool
        public let form: Bool
        /// Issue-link and gift-claim writes. Seat invite, cancel, and claim are not money.
        public let money: Bool
        public var sendsWhileMoneyOff: Bool { !money }
    }

    public static let journey: [JourneyCase] = [
        JourneyCase(name: .report, method: "GET", path: "/api/play/player-journey/report", json: false, form: false, money: false),
        JourneyCase(name: .memory, method: "GET", path: "/api/play/player-journey/memory", json: false, form: false, money: false),
        JourneyCase(name: .choices, method: "GET", path: "/api/play/player-journey/choices", json: false, form: false, money: false),
        JourneyCase(name: .seats, method: "GET", path: "/api/play/player-journey/seats", json: false, form: false, money: false),
        JourneyCase(name: .rank, method: "GET", path: "/api/rank/list", json: false, form: false, money: false),
        JourneyCase(name: .teamDetail, method: "GET", path: "/api/orient/team/detail", json: false, form: false, money: false),
        JourneyCase(name: .teamRanking, method: "GET", path: "/api/orient/team/ranking", json: false, form: false, money: false),
        JourneyCase(name: .rate, method: "POST", path: "/api/comment/add", json: false, form: true, money: false),
        JourneyCase(name: .referral, method: "POST", path: "/api/referral/landing/referral", json: true, form: false, money: false),
        JourneyCase(name: .gift, method: "POST", path: "/api/referral/landing/gift", json: true, form: false, money: false),
        JourneyCase(name: .issueReferral, method: "POST", path: "/api/marketing/referral/token", json: true, form: false, money: true),
        JourneyCase(name: .affiliate, method: "GET", path: "/api/marketing/affiliate/summary", json: false, form: false, money: false),
        JourneyCase(name: .seatInvite, method: "POST", path: "/api/play/seat-invitations/invite", json: true, form: false, money: false),
        JourneyCase(name: .seatInvitation, method: "GET", path: "/api/play/seat-invitations/{invitationId}", json: false, form: false, money: false),
        JourneyCase(name: .seatClaim, method: "POST", path: "/api/play/seat-invitations/claim", json: true, form: false, money: false),
        JourneyCase(name: .seatCancel, method: "POST", path: "/api/play/seat-invitations/{invitationId}/cancel", json: true, form: false, money: false),
        JourneyCase(name: .giftClaim, method: "POST", path: "/api/marketing/product/gifts/claim", json: true, form: false, money: true)
    ]

    public static func journey(_ name: Journey) -> JourneyCase {
        guard let item = journey.first(where: { $0.name == name }) else {
            preconditionFailure("journey case \(name.rawValue) missing from the parity table")
        }
        return item
    }

    /// `subpackageJourney/pages/landing/index?k=r|g|s&t=` plus optional `aid` / `tid`. Also accepts a `chein://` URL.
    /// A link only classifies the landing. It does not claim, pay, or start a run.
    public static func journeyLink(miniProgramPath path: String) -> CheinDeepLink? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 2048, !trimmed.contains("#") else { return nil }
        if trimmed.lowercased().hasPrefix("chein:") {
            return URL(string: trimmed).flatMap { CheinDeepLink(url: $0) }
        }
        var text = trimmed
        while text.hasPrefix("/") { text.removeFirst() }
        guard let components = URLComponents(string: "https://journey.invalid/" + text),
              components.path == "/" + landingPage else { return nil }
        return CheinDeepLink(landingQuery: components.queryItems ?? [])
    }
}
