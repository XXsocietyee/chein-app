import Foundation

/// Source meeting-point row (scene-play-activity-detail `activity-meta`): a named place,
/// a coordinate-only location ("查看地图"), or an explicit unconfirmed state ("位置待确认").
public enum ActivityDetailMeetingPoint: Equatable {
    case named(String)
    case mapOnly
    case unconfirmed
}

/// Presentation-only facts for the source detail meta block: 分类 / 集合点 / 已报名.
/// Values come only from the allowed detail response. Nothing is inferred or defaulted:
/// a missing registration count stays unknown instead of being shown as zero.
public struct ActivityDetailHeaderFacts: Equatable {
    /// Source `sysCategoryList[].categoryName` joined with " · "; nil means 分类待确认.
    public let categoryText: String?
    public let meetingPoint: ActivityDetailMeetingPoint
    /// Source `registrationCount`; the bounded roster preview is never counted instead.
    public let registrationCount: Int?

    public init(detail: ActivityDetail) {
        let names = detail.summary.categoryNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        categoryText = names.isEmpty ? nil : names.joined(separator: " · ")
        // Source order: addressName || address, then the coordinate-only map hint.
        if let place = Self.nonempty(detail.summary.addressName) ?? Self.nonempty(detail.summary.address) {
            meetingPoint = .named(place)
        } else if detail.summary.hasValidCoordinates {
            meetingPoint = .mapOnly
        } else {
            meetingPoint = .unconfirmed
        }
        registrationCount = detail.people.registrationCount
    }

    static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Source section order for the ready detail page. `ActivityDetailView` keeps the extra map
/// section between `about` and `tickets` because test_activity_design_structure.py locks
/// header → about → map → tickets; the source itself has no map section (its meeting-point
/// row opens the system map instead).
public enum ActivityDetailSourceSection: String, CaseIterable {
    case header, cancelled, meta, about, host, participants, associatedPlays, tickets, reviews
}

/// Read capability for `pages/activity/detail/index`.
/// The only wired read is the live `api/activity/info` contract. A missing route stays hidden.
/// Merchant choice, payment, payout, withdrawal, and virtual goods stay off.
public enum ActivityDetailPageCapability {
    public static let readPath = "api/activity/info"
    public static let showsMerchantChoice = false
    public static let paymentEnabled = false
    public static let payoutEnabled = false
    public static let withdrawalEnabled = false
    public static let virtualGoodsEnabled = false
}

/// Page phases for the activity detail read. Unknown numbers use an em dash, never a guessed zero.
public enum ActivityDetailPagePhase: Equatable {
    case loading
    case empty
    case error
    /// Existing club gate from `api/activity/info`. The activity body stays hidden.
    case clubRequired(clubID: Int?, message: String?)
    case cancelled(canViewOwnOrders: Bool)
    case ready(ActivityDetailPageSnapshot)
}

public struct ActivityDetailTicketFact: Equatable {
    public let id: Int
    public let nameText: String
    public let priceText: String
    public let inventoryText: String
    /// Known sold-out, including a server zero. Unknown inventory is not sold out.
    public let soldOut: Bool
}

public struct ActivityDetailPlayFact: Equatable {
    public let titleText: String
    public let playersText: String
    public let durationText: String
}

/// Projection of one allowed `api/activity/info` body. Absent numbers are em dashes.
public struct ActivityDetailPageSnapshot: Equatable {
    public let activityID: Int
    public let nameText: String
    public let categoryText: String
    public let meetingPoint: ActivityDetailMeetingPoint
    public let meetingPointText: String
    public let registeredCountText: String
    public let reviewCountText: String
    public let averageRatingText: String
    public let reviewsConfirmedEmpty: Bool
    public let tickets: [ActivityDetailTicketFact]
    public let plays: [ActivityDetailPlayFact]
    public var ticketsEmpty: Bool { tickets.isEmpty }
}

public enum ActivityDetailPageModel {
    /// UNKNOWN display. Not a hyphen, and not a stand-in for zero.
    public static let unknownDisplay = "—"

    public static func countText(_ value: Int?) -> String {
        guard let value else { return unknownDisplay }
        return String(value)
    }

    public static func decimalText(_ amount: Decimal?) -> String {
        guard let amount else { return unknownDisplay }
        return NSDecimalNumber(decimal: amount).stringValue
    }

    /// Non-negative finite measurements. NaN, infinity, and negatives are unknown.
    /// A positive value that would round to zero at one decimal stays unknown.
    public static func measurementText(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else { return unknownDisplay }
        if value == 0 { return "0" }
        let scaled = (value * 10).rounded(.toNearestOrAwayFromZero)
        let digits = Int(scaled)
        if digits <= 0 { return unknownDisplay }
        let whole = digits / 10
        let fraction = digits % 10
        if fraction == 0 { return String(whole) }
        return "\(whole).\(fraction)"
    }

    public static func titleText(_ value: String?) -> String {
        guard let value else { return unknownDisplay }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? unknownDisplay : trimmed
    }

    public static func phase(loading: Bool, failed: Bool, access: ActivityDetailAccess?) -> ActivityDetailPagePhase {
        if loading { return .loading }
        if failed { return .error }
        guard let access else { return .loading }
        switch access {
        case .clubRequired(let clubID, let message):
            return .clubRequired(clubID: clubID, message: message)
        case .cancelled(let canViewOwnOrders):
            return .cancelled(canViewOwnOrders: canViewOwnOrders)
        case .allowed(let detail):
            if isEmpty(detail) { return .empty }
            return .ready(project(detail))
        }
    }

    /// Allowed body with no ticket, person, play, review, place, date, category, or count.
    /// A known zero is a fact, so it is not empty.
    public static func isEmpty(_ detail: ActivityDetail) -> Bool {
        let facts = ActivityDetailHeaderFacts(detail: detail)
        let about = detail.summary.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return detail.tickets.isEmpty
            && about.isEmpty
            && detail.people.host == nil
            && detail.people.participants.isEmpty
            && detail.associatedPlays.isEmpty
            && detail.reviews.preview.isEmpty
            && detail.reviews.commentCount == nil
            && detail.reviews.averageRating == nil
            && facts.categoryText == nil
            && facts.meetingPoint == .unconfirmed
            && detail.summary.hasValidCoordinates == false
            && facts.registrationCount == nil
            && detail.cancelTime == nil
            && detail.summary.linkedTopicID == nil
            && titleText(detail.summary.startDate) == unknownDisplay
            && titleText(detail.summary.endDate) == unknownDisplay
    }

    public static func project(_ detail: ActivityDetail) -> ActivityDetailPageSnapshot {
        let facts = ActivityDetailHeaderFacts(detail: detail)
        let meetingText: String
        switch facts.meetingPoint {
        case .named(let place): meetingText = place
        case .mapOnly, .unconfirmed: meetingText = unknownDisplay
        }
        return ActivityDetailPageSnapshot(
            activityID: detail.summary.id,
            nameText: titleText(detail.summary.name),
            categoryText: facts.categoryText ?? unknownDisplay,
            meetingPoint: facts.meetingPoint,
            meetingPointText: meetingText,
            registeredCountText: countText(facts.registrationCount),
            reviewCountText: countText(detail.reviews.commentCount),
            averageRatingText: measurementText(detail.reviews.averageRating),
            reviewsConfirmedEmpty: detail.reviews.hasConfirmedNoReviews,
            tickets: detail.tickets.map { ticket in
                ActivityDetailTicketFact(
                    id: ticket.id,
                    nameText: titleText(ticket.name),
                    priceText: decimalText(ticket.price),
                    inventoryText: countText(ticket.remainingInventory),
                    soldOut: ticket.isSoldOut)
            },
            plays: detail.associatedPlays.map { play in
                ActivityDetailPlayFact(
                    titleText: titleText(play.title),
                    playersText: titleText(play.players),
                    durationText: measurementText(play.durationMinutes))
            })
    }
}

#if DEBUG
/// Synthetic activity-detail payloads. No URL, credential, or live account.
public enum ActivityDetailPageFixtureData {
    public static let readyJSON = #"{"id":101,"name":"Fixture activity","addressName":"Fixture meeting point","sysCategoryList":[{"categoryName":"Fixture walk"}],"registrationCount":7,"averageRating":4.2,"commentCount":2,"commentList":[{"memberNickname":"Fixture reviewer","rating":4,"contents":"Fixture review"}],"memberTemplateList":[{"title":"Fixture play","players":"4","duration":90}],"omsTicketList":[{"id":501,"name":"Fixture ticket","price":12.5,"remainingInventory":3}]}"#
    public static let unknownJSON = #"{"id":101,"name":"Fixture activity","registrationCount":-1,"isSignUp":2,"averageRating":null,"commentCount":-3,"omsTicketList":[{"id":501,"name":"Fixture ticket","price":null,"remainingInventory":null}],"memberTemplateList":[{"title":" ","players":null,"duration":null}]}"#
    public static let zeroJSON = #"{"id":101,"name":"Fixture activity","registrationCount":0,"averageRating":0,"commentCount":0,"memberTemplateList":[{"title":"Fixture play","players":0,"duration":0}],"omsTicketList":[{"id":501,"name":"Fixture free ticket","price":0,"remainingInventory":0}]}"#
    public static let emptyJSON = #"{"id":101,"name":"Fixture activity"}"#
    public static let blankNameJSON = #"{"id":101,"name":"  ","omsTicketList":[{"id":501,"name":"Fixture ticket","price":1,"remainingInventory":1}]}"#
    public static let clubGateJSON = #"{"gate":true,"clubId":9,"message":"Synthetic gate"}"#
    public static let errorEnvelopeJSON = #"{"code":500}"#
}
#endif
