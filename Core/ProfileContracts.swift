import Foundation

/// Account child routes from the retained client. All operations in this module are reads.
/// IDs are validated instead of synthesizing an address/order that cannot be opened safely.
public struct ProfileParticipant: Decodable, Equatable, Identifiable {
    public let id: Int
    public let fullName: String
    public let mobilePhone: String
    /// The entire province/city/district string, not a separate province component.
    public let province: String?
    public let detailAddress: String?
    public let isDefault: Bool
    public var oneLineAddress: String {
        [province, detailAddress].compactMap { value in
            value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        }.joined(separator: " ")
    }
    private enum CodingKeys: String, CodingKey { case id, fullName, mobilePhone, province, detailAddress, isDefault }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        guard id > 0 else { throw APIError.malformedResponse }
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        mobilePhone = try c.decodeIfPresent(String.self, forKey: .mobilePhone) ?? ""
        province = try c.decodeIfPresent(String.self, forKey: .province)
        detailAddress = try c.decodeIfPresent(String.self, forKey: .detailAddress)
        isDefault = (try? c.decode(Bool.self, forKey: .isDefault)) == true
            || (try? c.decode(Int.self, forKey: .isDefault)) == 1
            || (try? c.decode(String.self, forKey: .isDefault)) == "1"
    }
}

/// `data` object of the existing `POST api/user/address/list` payload.
/// `rows` is the page the client already reads. `total` is the table count on that
/// same object. A missing or null total stays nil. A numeric string is rejected
/// so it cannot be read as zero. This type does not add a contact field.
public struct ProfileParticipantListFacts: Decodable, Equatable {
    public let rows: [ProfileParticipant]
    public let total: Int?

    public init(rows: [ProfileParticipant], total: Int?) {
        self.rows = rows
        self.total = total
    }

    private enum CodingKeys: String, CodingKey { case rows, total }
    private struct Count: Decodable {
        let value: Int
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(Int.self)
            guard value >= 0 else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "negative count")
            }
            self.value = value
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rows = try container.decode([ProfileParticipant].self, forKey: .rows)
        guard container.contains(.total) else { total = nil; return }
        if try container.decodeNil(forKey: .total) { total = nil; return }
        total = try container.decode(Count.self, forKey: .total).value
    }
}

/// pages/address/address. Derived from a list read the app already performs.
/// It does not fetch, add a route, or mark a route live.
public enum ProfileParticipantListPhase: Equatable {
    case loading, empty, error, unknown, ready
}

/// One list row. Only the name and phone already on `ProfileParticipant`.
public struct ProfileParticipantListCard: Equatable, Identifiable {
    public let id: Int
    public let fullName: String
    public let mobilePhone: String
    /// A blank phone is unknown. The stored value is never replaced with a number.
    public var phoneText: String {
        mobilePhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ProfileParticipantListPage.unknownMark : mobilePhone
    }
    public init(_ row: ProfileParticipant) {
        id = row.id
        fullName = row.fullName
        mobilePhone = row.mobilePhone
    }
}

public struct ProfileParticipantListPage: Equatable {
    /// Missing numeric facts. Never a stand-in zero.
    public static let unknownMark = "—"
    public let phase: ProfileParticipantListPhase
    public let cards: [ProfileParticipantListCard]
    /// Nil while the table total was absent, null, or the list is not a settled success.
    public let total: Int?
    /// True only while a newer read is in flight and a previous list is still on screen.
    public let isRefreshing: Bool
    public var totalText: String { total.map(String.init) ?? Self.unknownMark }
    /// Mini-program footer: the add action is on a settled list, including a known empty one.
    public var showsAdd: Bool { phase == .ready || phase == .empty }

    public init(phase: ProfileParticipantListPhase, cards: [ProfileParticipantListCard], total: Int?, isRefreshing: Bool) {
        self.phase = phase
        self.cards = cards
        self.total = total
        self.isRefreshing = isRefreshing
    }
}

public enum ProfileParticipantListCoordinator {
    /// `list == nil` is still loading, unless a retained list is on screen (refresh).
    /// Cancellation keeps that list, or stays loading when there is none.
    /// A malformed payload with nothing retained is unknown, not an empty list.
    /// Any other first-load failure is an error. A failure that still has a retained
    /// list keeps that list. Counts stay an em dash until a real total arrives.
    /// A literal total of zero stays "0". The row count is never used as the total.
    public static func project(list: Result<ProfileParticipantListFacts, Error>?,
                               retained: ProfileParticipantListFacts? = nil,
                               outcomeUnknown: Bool = false) -> ProfileParticipantListPage {
        if outcomeUnknown { return unsettled(.unknown) }
        guard let list else { return retained.map { settled($0, isRefreshing: true) } ?? unsettled(.loading) }
        switch list {
        case .failure(let error):
            if error is CancellationError {
                return retained.map { settled($0, isRefreshing: true) } ?? unsettled(.loading)
            }
            if let retained { return settled(retained, isRefreshing: false) }
            if case APIError.malformedResponse = error { return unsettled(.unknown) }
            return unsettled(.error)
        case .success(let facts):
            return settled(facts, isRefreshing: false)
        }
    }

    private static func settled(_ facts: ProfileParticipantListFacts, isRefreshing: Bool) -> ProfileParticipantListPage {
        ProfileParticipantListPage(phase: facts.rows.isEmpty ? .empty : .ready,
                                   cards: facts.rows.map(ProfileParticipantListCard.init),
                                   total: facts.total, isRefreshing: isRefreshing)
    }

    private static func unsettled(_ phase: ProfileParticipantListPhase) -> ProfileParticipantListPage {
        ProfileParticipantListPage(phase: phase, cards: [], total: nil, isRefreshing: false)
    }
}

/// Registration and verification are separate facts. Neither becomes a payment verdict.
public enum ProfileRegistrationState: Equatable {
    case awaitingPayment, registered, cancelled, expired, unknown
    public init(code: Int?) {
        switch code {
        case 1: self = .awaitingPayment
        case 2: self = .registered
        case 3: self = .cancelled
        case 4: self = .expired
        default: self = .unknown
        }
    }
}

/// Shared read projection of MyRegistration and RegistrationDetail. Detail is always fetched
/// from /info; list snapshots are never treated as a fresh detail response. Unknown values
/// and missing prices remain unknown, including absent refund applications versus payout 0.
/// Ordinary ticket-session times from the current order response, not a purchase-time snapshot.
/// ApplicationConfig pins Jackson's bare timestamps to Asia/Shanghai. Reuse the
/// established ordinary-time parser and explicitly format into the phone's zone.
public enum ProfileOrderTicketTime: Equatable {
    case absent, unknown, source(String)
    public func display(phoneTimeZone: TimeZone) -> String? {
        guard case .source(let raw) = self else { return nil }
        return SearchMapActivityTime(raw).display(phoneTimeZone: phoneTimeZone)
    }
}
public struct ProfileOrderTicketSchedule: Decodable, Equatable {
    public let start: ProfileOrderTicketTime
    public let end: ProfileOrderTicketTime
    public var hasSourceFields: Bool { start != .absent || end != .absent }
    private enum CodingKeys: String, CodingKey { case startTime, endTime }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func time(_ key: CodingKeys) -> ProfileOrderTicketTime {
            guard c.contains(key), (try? c.decodeNil(forKey: key)) != true else { return .absent }
            guard let raw = try? c.decode(String.self, forKey: key) else { return .unknown }
            guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .absent }
            return .source(raw)
        }
        start = time(.startTime); end = time(.endTime)
    }
}

public struct ProfileOrder: Decodable, Equatable, Identifiable {
    public let id: Int
    public let historyFacts: ProfileOrderHistoryFacts
    /// Lenient supplemental detail facts (transaction id, refund time/reason); display only.
    public let detailFacts: ProfileOrderDetailFacts
    public let memberID: Int?
    public let ticketID: Int?
    public let ownerType: Int?
    public let ownerID: Int?
    public let registrationNo: String?
    public let registrationStatus: Int?
    public let verificationStatus: Int?
    public let paymentStatus: Int?
    public let purchaseKind: Int?
    public let title: String?
    public let productType: Int?
    public let startDate: String?
    public let endDate: String?
    public let addressName: String?
    public let meetingPoint: String?
    public let ticketSchedule: ProfileOrderTicketSchedule?
    public let gatherLatitude: Double?
    public let gatherLongitude: Double?
    public let participateDate: String?
    public let payableAmount: Decimal?
    /// Source order-history mode tag: activity orders are 城市定向; topic orders follow
    /// productType (1 城市定向, 2 自由探索); an unbackfilled topic mode stays nil.
    public let sourceMode: ProfileOrderSourceMode?
    public let pointUsed: Int?
    public let pointDeductAmount: Decimal?
    public let pointPaymentAmount: Decimal?
    public let wechatPaymentAmount: Decimal?
    public let paymentType: Int?
    public let pointsReturned: Int?
    public let refundAmount: Decimal?
    public let refundApplicationStatus: Int?
    public let manualRefundCaseStatus: String?
    public let refundDeadlineDisplay: String?
    public let realName: String?
    /// The retained detail contract documents this as server-masked; do not unmask locally.
    public let phone: String?
    public let ticketName: String?
    public let orderNum: Int?
    public let paymentTime: String?
    public let paymentTypeLabel: String?
    public let createTime: String?
    public let verificationTime: String?
    public let expiresAt: String?
    public let organizerName: String?
    public let statusText: String?
    public let orderHint: String?
    public let refundable: Bool?
    public let refundPayoutStatus: Int?
    /// FIN-17-3: CmsRegistration invoice facts (all strings on the wire). Unknown values hide the 发票 block.
    public let invoiceStatus: String?
    public let invoiceApplicationID: Int64?
    public let invoiceNo: String?
    /// History card and detail hero cover. Missing images stay nil.
    public let coverURL: String?
    /// `cmsActivity.teamMode`. Topic-only orders stay nil.
    public let teamMode: Int?
    public let club: ProfileOrderClub?
    /// `cmsTopic.memberId`, else `cmsActivity.memberId`. Consent matching uses this id.
    public let merchantOwnerMemberID: Int?
    public let party: ProfileOrderParty?
    /// `usableState == "EXPIRED"`.
    public let walletExpired: Bool
    public let settlementView: ProfileOrderSettlementView
    public var registrationState: ProfileRegistrationState { .init(code: registrationStatus) }
    /// Source resolveActualPaidAmount: cash (WeChat) paid first, then the payable amount.
    public var actualPaidAmount: Decimal? { wechatPaymentAmount ?? payableAmount }

    private enum CodingKeys: String, CodingKey {
        case id, memberId, ticketId, ownerType, ownerId, registrationNo, registrationStatus, verificationStatus, paymentStatus, purchaseKind
        case cmsActivity, cmsTopic, omsTicket, participateDate, payableAmount, realName, phone, ticketName, orderNum
        case paymentTime, paymentTypeLabel, createTime, verificationTime, expiresAt, organizerName
        case statusText, orderHint, refundInfo, refundApplication
        case pointUsed, pointDeductAmount, pointPaymentAmount, wechatPaymentAmount, paymentType, pointsReturned
        case manualRefundCaseStatus, refundDeadlineDisplay
        case invoiceStatus, invoiceApplicationId, invoiceNo
        case settlementSummary, party, usableState
    }
    private struct Owner: Decodable, Equatable {
        let name: String?
        let productType: ProfileWireInteger?
        let startDate: String?
        let endDate: String?
        let addressName: String?
        let imgUrl: String?
        let imgArrFirst: String?
        let teamMode: Int?
        let memberId: Int?
        let clubId: Int?
        let clubName: String?
        let clubLeaderMemberId: Int?
        private enum CodingKeys: String, CodingKey {
            case name, productType, startDate, endDate, addressName, imgUrl, imgArr, teamMode, memberId
            case clubId, clubName, clubLeaderMemberId
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            productType = try c.decodeIfPresent(ProfileWireInteger.self, forKey: .productType)
            startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
            endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
            addressName = try c.decodeIfPresent(String.self, forKey: .addressName)
            imgUrl = Self.image(c, .imgUrl)
            imgArrFirst = Self.image(c, .imgArr)
            teamMode = ((try? c.decodeIfPresent(ProfileWireInteger.self, forKey: .teamMode)) ?? nil)?.value
            memberId = ((try? c.decodeIfPresent(ProfileWireInteger.self, forKey: .memberId)) ?? nil)?.value
            clubId = ((try? c.decodeIfPresent(ProfileWireInteger.self, forKey: .clubId)) ?? nil)?.value
            clubName = (try? c.decodeIfPresent(String.self, forKey: .clubName)) ?? nil
            clubLeaderMemberId = ((try? c.decodeIfPresent(ProfileWireInteger.self, forKey: .clubLeaderMemberId)) ?? nil)?.value
        }
        private static func image(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
            if let text = try? c.decode(String.self, forKey: key) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            if let list = try? c.decode([String].self, forKey: key) {
                return list.lazy.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            }
            return nil
        }
    }
    private struct MeetingTicket: Decodable {
        let meetingPoint: String?
        let gatherLat: Double?
        let gatherLng: Double?
        let schedule: ProfileOrderTicketSchedule?
        private enum CodingKeys: String, CodingKey { case meetingPoint, gatherLat, gatherLng }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            meetingPoint = try c.decodeIfPresent(String.self, forKey: .meetingPoint)
            gatherLat = try c.decodeIfPresent(Double.self, forKey: .gatherLat)
            gatherLng = try c.decodeIfPresent(Double.self, forKey: .gatherLng)
            let value = try ProfileOrderTicketSchedule(from: decoder)
            schedule = value.hasSourceFields ? value : nil
        }
    }
    private struct RefundInfo: Decodable { let refundable: Bool? }
    private struct RefundApplication: Decodable {
        let payoutStatus: ProfileOrderStatusInteger?
        let status: ProfileOrderStatusInteger?
        let refundAmount: Decimal?
        enum CodingKeys: String, CodingKey { case payoutStatus, status, refundAmount }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            payoutStatus = try c.decodeIfPresent(ProfileOrderStatusInteger.self, forKey: .payoutStatus)
            status = try c.decodeIfPresent(ProfileOrderStatusInteger.self, forKey: .status)
            refundAmount = try c.profileOrderMoney(.refundAmount)
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        historyFacts = try ProfileOrderHistoryFacts(from: decoder)
        detailFacts = try ProfileOrderDetailFacts(from: decoder)
        guard id > 0 else { throw APIError.malformedResponse }
        memberID = try c.decodeIfPresent(Int.self, forKey: .memberId)
        ticketID = try c.decodeIfPresent(Int.self, forKey: .ticketId)
        ownerType = try c.decodeIfPresent(Int.self, forKey: .ownerType)
        ownerID = try c.decodeIfPresent(Int.self, forKey: .ownerId)
        registrationNo = try c.decodeIfPresent(String.self, forKey: .registrationNo)
        registrationStatus = try c.decodeIfPresent(Int.self, forKey: .registrationStatus)
        verificationStatus = try c.decodeIfPresent(Int.self, forKey: .verificationStatus)
        paymentStatus = try c.decodeIfPresent(Int.self, forKey: .paymentStatus)
        purchaseKind = (try? c.decodeIfPresent(ProfileOrderStatusInteger.self, forKey: .purchaseKind))?.value
        // Source precedence is the associated activity object, then the topic object.
        let activityOwner = try c.decodeIfPresent(Owner.self, forKey: .cmsActivity)
        let owner = try activityOwner ?? c.decodeIfPresent(Owner.self, forKey: .cmsTopic)
        if activityOwner != nil { sourceMode = .cityOrienteering }
        else { sourceMode = owner?.productType?.value.flatMap(ProfileOrderSourceMode.init(topicProductType:)) }
        title = owner?.name
        productType = owner?.productType?.value
        startDate = owner?.startDate
        endDate = owner?.endDate
        addressName = owner?.addressName
        let meeting = try c.decodeIfPresent(MeetingTicket.self, forKey: .omsTicket)
        meetingPoint = meeting?.meetingPoint
        ticketSchedule = meeting?.schedule
        gatherLatitude = meeting?.gatherLat; gatherLongitude = meeting?.gatherLng
        participateDate = try c.decodeIfPresent(String.self, forKey: .participateDate)
        if c.contains(.payableAmount), !(try c.decodeNil(forKey: .payableAmount)) {
            // Flutter's order projection accepts numeric amounts, not numeric strings.
            guard (try? c.decode(String.self, forKey: .payableAmount)) == nil else {
                throw APIError.malformedResponse
            }
            let amount = try c.decode(Decimal.self, forKey: .payableAmount)
            guard !amount.isNaN, amount >= .zero else { throw APIError.malformedResponse }
            payableAmount = amount
        } else { payableAmount = nil }
        pointUsed = try c.decodeIfPresent(Int.self, forKey: .pointUsed)
        if let pointUsed, pointUsed < 0 { throw APIError.malformedResponse }
        pointDeductAmount = try c.profileOrderMoney(.pointDeductAmount)
        pointPaymentAmount = try c.profileOrderMoney(.pointPaymentAmount)
        wechatPaymentAmount = try c.profileOrderMoney(.wechatPaymentAmount)
        paymentType = try c.decodeIfPresent(Int.self, forKey: .paymentType)
        pointsReturned = try c.decodeIfPresent(Int.self, forKey: .pointsReturned)
        manualRefundCaseStatus = try c.decodeIfPresent(String.self, forKey: .manualRefundCaseStatus)
        refundDeadlineDisplay = try c.decodeIfPresent(String.self, forKey: .refundDeadlineDisplay)
        realName = try c.decodeIfPresent(String.self, forKey: .realName)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        ticketName = try c.decodeIfPresent(String.self, forKey: .ticketName)
        orderNum = try c.decodeIfPresent(Int.self, forKey: .orderNum)
        paymentTime = try c.decodeIfPresent(String.self, forKey: .paymentTime)
        paymentTypeLabel = try c.decodeIfPresent(String.self, forKey: .paymentTypeLabel)
        createTime = try c.decodeIfPresent(String.self, forKey: .createTime)
        verificationTime = try c.decodeIfPresent(String.self, forKey: .verificationTime)
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        organizerName = try c.decodeIfPresent(String.self, forKey: .organizerName)
        statusText = try c.decodeIfPresent(String.self, forKey: .statusText)
        orderHint = try c.decodeIfPresent(String.self, forKey: .orderHint)
        refundable = try c.decodeIfPresent(RefundInfo.self, forKey: .refundInfo)?.refundable
        let refund = try c.decodeIfPresent(RefundApplication.self, forKey: .refundApplication)
        refundPayoutStatus = refund?.payoutStatus?.value
        refundApplicationStatus = refund?.status?.value
        refundAmount = refund?.refundAmount
        // Display only and lenient: a malformed invoice fact never fails the order read.
        invoiceStatus = (try? c.decodeIfPresent(String.self, forKey: .invoiceStatus)) ?? nil
        let application = (try? c.decodeIfPresent(String.self, forKey: .invoiceApplicationId)) ?? nil
        invoiceApplicationID = application.flatMap { text in
            guard let value = Int64(text), value > 0, String(value) == text else { return nil }
            return value
        }
        let number = ((try? c.decodeIfPresent(String.self, forKey: .invoiceNo)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
        invoiceNo = number?.isEmpty == false ? number : nil
        let activity = activityOwner
        let topic = (try? c.decodeIfPresent(Owner.self, forKey: .cmsTopic)) ?? nil
        coverURL = Self.coverURL(activity: activity, topic: topic)
        teamMode = activity?.teamMode
        club = Self.club(activity: activity, topic: topic)
        merchantOwnerMemberID = Self.positive(topic?.memberId) ?? Self.positive(activity?.memberId)
        party = (try? c.decodeIfPresent(ProfileOrderParty.self, forKey: .party)) ?? nil
        let usable = ((try? c.decodeIfPresent(String.self, forKey: .usableState)) ?? nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        walletExpired = usable == "EXPIRED"
        settlementView = ((try? c.decodeIfPresent(ProfileOrderSettlementSummary.self, forKey: .settlementSummary)) ?? nil)?
            .view ?? .hidden
    }

    /// Activity card: `imgUrl`, then `imgArr[0]`. Topic card: `imgArr[0]`, then `imgUrl`.
    /// Same choice as the detail hero (`resolveHeroImage`).
    private static func coverURL(activity: Owner?, topic: Owner?) -> String? {
        if let activity { return activity.imgUrl ?? activity.imgArrFirst }
        return topic?.imgArrFirst ?? topic?.imgUrl
    }

    private static func club(activity: Owner?, topic: Owner?) -> ProfileOrderClub? {
        for owner in [activity, topic] {
            if let id = positive(owner?.clubId) {
                let name = owner?.clubName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return ProfileOrderClub(id: id, name: name, leaderMemberID: positive(owner?.clubLeaderMemberId))
            }
        }
        return nil
    }

    private static func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    /// `paymentStatus == 2 && registrationStatus == 2 && orderNum > 1`.
    public var seatsOpen: Bool {
        paymentStatus == 2 && registrationStatus == 2 && (orderNum ?? 0) > 1
    }

    /// Activity order, registered, not completed, teamMode 1 or 2.
    public var teamOpen: Bool {
        ownerType == 2 && registrationStatus == 2 && historyState() != .completed
            && (teamMode == 1 || teamMode == 2)
    }
}

/// FIN-17-3: the MP order detail 发票 block (scene-member-order-detail index.js:431-437).
public enum ProfileOrderInvoiceState: Equatable {
    case notApplied, issuing, issued, paused
}

extension ProfileOrder {
    /// Paid (paymentStatus 2), non-free orders only; an unknown or absent status hides the block.
    public var invoiceState: ProfileOrderInvoiceState? {
        guard paymentStatus == 2 else { return nil }
        switch invoiceStatus {
        case "NONE": return .notApplied
        case "SUBMITTED", "CLAIMED", "PROCESSING", "ISSUE_UNKNOWN": return .issuing
        case "ISSUED": return .issued
        case "PAUSED": return .paused
        default: return nil
        }
    }
}

public struct ProfileIdentityBadge: Decodable, Equatable {
    public let badgeCode: String
    public let badgeName: String
    public let nameEn: String
    public let statement: String
    public let iconURL: String
    public let category: String
    public let unlockHint: String
    public let unlocked: Bool
    public let unlockTime: String?
    private enum CodingKeys: String, CodingKey {
        case badgeCode, badgeName, nameEn, statement, iconUrl, category, unlockHint, unlocked, unlockTime
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        badgeCode = try c.profileText(.badgeCode)
        badgeName = try c.profileText(.badgeName)
        nameEn = try c.profileText(.nameEn)
        statement = try c.profileText(.statement)
        iconURL = try c.profileText(.iconUrl)
        category = try c.profileText(.category)
        unlockHint = try c.profileText(.unlockHint)
        unlocked = try c.decodeIfPresent(ProfileWireBoolean.self, forKey: .unlocked)?.value ?? false
        unlockTime = try c.decodeIfPresent(String.self, forKey: .unlockTime)
    }
}

public struct ProfileMedal: Decodable, Equatable {
    public let templateID: Int?
    public let medalImage: String
    public let medalName: String
    public let style: String
    public let topicID: Int?
    public let getTime: String?
    public let condition: String
    public let kind: String
    public let badgeCode: String
    public var isAchievement: Bool { kind == "achievement" }
    /// Achievement rows do not supply a condition; do not borrow city-node conditions.
    public var displayCondition: String { isAchievement ? "" : condition }
    private enum CodingKeys: String, CodingKey {
        case templateId, medalImg, medalName, style, topicId, getTime, condition, kind, badgeCode
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        templateID = try c.decodeIfPresent(ProfileWireInteger.self, forKey: .templateId)?.value
        medalImage = try c.profileText(.medalImg)
        medalName = try c.profileText(.medalName)
        style = try c.profileText(.style)
        topicID = try c.decodeIfPresent(ProfileWireInteger.self, forKey: .topicId)?.value
        getTime = try c.decodeIfPresent(String.self, forKey: .getTime)
        condition = try c.profileText(.condition)
        kind = try c.profileText(.kind)
        badgeCode = try c.profileText(.badgeCode)
    }
}

/// Local classification of a failed medal read, never a server grant or inferred empty result.
public enum ProfileMedalReadRestriction: Equatable {
    case denied, unavailable
    static func classify(_ error: Error) -> Self? {
        if (error as? ProfileReadFailure)?.isDenied == true || error as? APIError == .httpStatus(403) { return .denied }
        if error as? APIError == .notConfigured { return .unavailable }
        return nil
    }
}
public struct ProfileBadgeWall: Equatable {
    public let identities: [ProfileIdentityBadge]
    /// nil means loading medals failed, not an empty collection.
    public let medals: [ProfileMedal]?
    public let medalFailureMessage: String?
    public let medalReadRestriction: ProfileMedalReadRestriction?
    public var isPartial: Bool { medals == nil }
    public var isEmpty: Bool { identities.isEmpty && medals?.isEmpty == true }
    public init(identities: [ProfileIdentityBadge], medals: [ProfileMedal]?, medalFailureMessage: String? = nil,
                medalReadRestriction: ProfileMedalReadRestriction? = nil) {
        self.identities = identities
        self.medals = medals
        self.medalFailureMessage = medalFailureMessage
        self.medalReadRestriction = medals == nil ? medalReadRestriction : nil
    }
}

/// Only fields whose retained parsers accept wire strings use these helpers.
private struct ProfileWireInteger: Decodable, Equatable {
    let value: Int?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let integer = try? c.decode(Int.self) { value = integer }
        else if let text = try? c.decode(String.self) { value = Int(text) }
        else if let number = try? c.decode(Double.self), number.isFinite { value = Int(exactly: number.rounded(.towardZero)) }
        else { value = nil }
    }
}
private struct ProfileWireBoolean: Decodable {
    let value: Bool
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let flag = try? c.decode(Bool.self) { value = flag }
        else if let number = try? c.decode(Int.self) { value = number == 1 }
        else if let text = try? c.decode(String.self) { value = text == "1" || text == "true" }
        else { value = false }
    }
}
private struct ProfileWireText: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self) { value = text }
        else if let flag = try? c.decode(Bool.self) { value = flag ? "true" : "false" }
        else if let number = try? c.decode(Decimal.self) { value = NSDecimalNumber(decimal: number).stringValue }
        else { throw APIError.malformedResponse }
    }
}
private extension KeyedDecodingContainer {
    func profileText(_ key: Key) throws -> String {
        try decodeIfPresent(ProfileWireText.self, forKey: key)?.value ?? ""
    }
}

private extension KeyedDecodingContainer {
    func profileOrderMoney(_ key: Key) throws -> Decimal? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        guard (try? decode(String.self, forKey: key)) == nil else { throw APIError.malformedResponse }
        let value = try decode(Decimal.self, forKey: key)
        guard !value.isNaN, value >= 0 else { throw APIError.malformedResponse }
        return value
    }
}
private struct ProfileOrderStatusInteger: Decodable {
    let value: Int
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let code = try? c.decode(Int.self) { value = code }
        else if let text = try? c.decode(String.self), let code = Int(text), String(code) == text { value = code }
        else { throw APIError.malformedResponse }
    }
}

public struct ProfileOrderClub: Equatable, Sendable {
    public let id: Int
    public let name: String
    public let leaderMemberID: Int?
    public init(id: Int, name: String, leaderMemberID: Int?) {
        self.id = id
        self.name = name
        self.leaderMemberID = leaderMemberID
    }
}

/// `party.childCount > 0` → `N 大 N 小`, plus `（儿童 N 岁）` when `childAge` is present.
public struct ProfileOrderParty: Equatable, Sendable, Decodable {
    public let adultCount: Int
    public let childCount: Int
    public let childAge: String?
    public var text: String? {
        guard childCount > 0 else { return nil }
        var value = "\(adultCount) 大 \(childCount) 小"
        if let childAge, !childAge.isEmpty { value += "（儿童 \(childAge) 岁）" }
        return value
    }
    private enum CodingKeys: String, CodingKey { case adultCount, childCount, childAge }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        adultCount = Self.integer(c, .adultCount) ?? 0
        childCount = Self.integer(c, .childCount) ?? 0
        childAge = Self.text(c, .childAge)
    }
    private static func integer(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? c.decode(Int.self, forKey: key) { return value }
        if let text = try? c.decode(String.self, forKey: key) { return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let number = try? c.decode(Double.self, forKey: key), number.isFinite { return Int(exactly: number.rounded(.towardZero)) }
        return nil
    }
    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let text = try? c.decode(String.self, forKey: key) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = try? c.decode(Int.self, forKey: key) { return String(value) }
        return nil
    }
}

/// Read-only `settlementSummary` rows from `utils/order-settlement-view.js`.
/// Amount text uses `MoneyDisplay`. This does not send a refund.
public struct ProfileOrderSettlementView: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let key: String
        public let label: String
        public let value: String
        public init(key: String, label: String, value: String) {
            self.key = key
            self.label = label
            self.value = value
        }
    }
    public let show: Bool
    public let stage: String
    public let stageTone: String
    public let rows: [Row]
    public static let hidden = ProfileOrderSettlementView(show: false, stage: "", stageTone: "", rows: [])
    public init(show: Bool, stage: String, stageTone: String, rows: [Row]) {
        self.show = show
        self.stage = stage
        self.stageTone = stageTone
        self.rows = rows
    }
}

/// One matching unpaid consent row, or nil. Fail closed on zero or many matches, and on an opted-in row.
public enum ProfileOrderConsentOffer {
    public static func pick(rows: [ComplianceMarketingConsent], ownerMemberID: Int?) -> ComplianceMarketingConsent? {
        guard let ownerMemberID, ownerMemberID > 0 else { return nil }
        let matches = rows.filter { $0.valid && $0.merchantOwnerMemberId == ownerMemberID }
        guard matches.count == 1, let row = matches.first, row.inAppOptedIn == false else { return nil }
        return row
    }
}

private struct ProfileOrderSettlementSummary: Decodable {
    let refundStage: String
    let amountsComplete: Bool
    let refundPendingAmount: Decimal?
    let refundProcessingAmount: Decimal?
    let refundCompletedAmount: Decimal?
    let refundRequestedAmount: Decimal?
    let entitlementTotal: Decimal?
    let entitlementRedeemed: Decimal?

    private enum CodingKeys: String, CodingKey {
        case refundStage, amountsComplete
        case refundPendingAmount, refundProcessingAmount, refundCompletedAmount, refundRequestedAmount
        case entitlementTotal, entitlementRedeemed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let stage = (((try? c.decodeIfPresent(String.self, forKey: .refundStage)) ?? nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        refundStage = stage.isEmpty ? "NONE" : stage
        amountsComplete = (try? c.decode(Bool.self, forKey: .amountsComplete)) == true
        refundPendingAmount = Self.amount(c, .refundPendingAmount)
        refundProcessingAmount = Self.amount(c, .refundProcessingAmount)
        refundCompletedAmount = Self.amount(c, .refundCompletedAmount)
        refundRequestedAmount = Self.amount(c, .refundRequestedAmount)
        entitlementTotal = Self.amount(c, .entitlementTotal)
        entitlementRedeemed = Self.amount(c, .entitlementRedeemed)
    }

    var view: ProfileOrderSettlementView {
        if refundStage == "NONE" { return .hidden }
        let stageText = Self.stageText[refundStage] ?? Self.stageText["UNKNOWN"]!
        let tone = refundStage == "COMPLETED" ? "done" : (refundStage == "REJECTED" ? "muted" : "pending")
        var rows: [ProfileOrderSettlementView.Row] = []
        func amountRow(_ key: String, _ label: String, _ value: Decimal?) {
            if let value, value == 0 { return }
            if value == nil, amountsComplete { return }
            let text = value.map { MoneyDisplay.yuan($0) } ?? "金额待确认"
            rows.append(.init(key: key, label: label, value: text))
        }
        amountRow("pending", "审核中", refundPendingAmount)
        amountRow("processing", "退款处理中", refundProcessingAmount)
        amountRow("completed", "已退回", refundCompletedAmount)
        if amountsComplete, let requested = refundRequestedAmount, requested > 0, rows.count > 1 {
            rows.append(.init(key: "total", label: "退款合计", value: MoneyDisplay.yuan(requested)))
        }
        if let total = entitlementTotal, total > 0 {
            let used = entitlementRedeemed ?? 0
            rows.append(.init(key: "entitlement", label: "已使用", value: "\(Self.count(used)) / \(Self.count(total))"))
        }
        return ProfileOrderSettlementView(show: true, stage: stageText, stageTone: tone, rows: rows)
    }

    private static let stageText = [
        "UNDER_REVIEW": "退款审核中",
        "PAYOUT_PENDING": "已批准，等待原路退回",
        "MANUAL_PAYOUT": "人工退款处理中",
        "COMPLETED": "已原路退回",
        "REJECTED": "退款未通过",
        "MANUAL_REVIEW": "售后处理中",
        "UNKNOWN": "退款状态待确认"
    ]

    private static func amount(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Decimal? {
        guard c.contains(key), (try? c.decodeNil(forKey: key)) != true else { return nil }
        if let value = try? c.decode(Decimal.self, forKey: key), !value.isNaN { return value }
        if let number = try? c.decode(Double.self, forKey: key), number.isFinite { return Decimal(number) }
        if let text = try? c.decode(String.self, forKey: key) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.range(of: #"^[+-]?(?:0|[1-9]\d*)(?:\.\d+)?$"#, options: .regularExpression) != nil,
                  let value = Decimal(string: trimmed), !value.isNaN else { return nil }
            return value
        }
        return nil
    }

    private static func count(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

public enum ProfileOrderSourceMode: Equatable {
    case cityOrienteering, freeExplore
    public init?(topicProductType: Int) {
        switch topicProductType {
        case 1: self = .cityOrienteering
        case 2: self = .freeExplore
        default: return nil
        }
    }
}
