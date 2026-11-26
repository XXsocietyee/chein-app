import Foundation

/// JSON body only. No endpoint, transport, consent submission or payment execution is configured here.
public struct RegistrationQuoteRequest: Encodable, Equatable {
    public let ownerID: Int
    public let ticketID: Int?
    public let usePoints: Bool
    public let waitlistOffer: RegistrationWaitlistOffer?
    /// R7-PC-C2-1: MP baoming.wxml:155-161 / js:1876 send the picked 儿童年龄 with quote and create.
    /// Nil (no child on the ticket, or nothing picked) leaves the key out of the body.
    public let childAge: Int?
    public var ownerType: Int { 2 }

    public init(ownerID: Int, ticketID: Int? = nil, usePoints: Bool = false, waitlistOffer: RegistrationWaitlistOffer? = nil,
                childAge: Int? = nil) throws {
        guard ownerID > 0, ticketID.map({ $0 > 0 }) ?? true, childAge.map({ $0 >= 0 }) ?? true else {
            throw APIError.invalidRequest
        }
        self.childAge = childAge
        self.ownerID = ownerID
        self.ticketID = ticketID
        guard waitlistOffer == nil || ticketID != nil else { throw APIError.invalidRequest }
        self.usePoints = usePoints
        self.waitlistOffer = waitlistOffer
    }

    private enum CodingKeys: String, CodingKey { case ownerType, ownerId, ticketId, isUsePoint, waitlistOfferId, waitlistOfferToken, childAge }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ownerType, forKey: .ownerType)
        try c.encode(ownerID, forKey: .ownerId)
        try c.encodeIfPresent(ticketID, forKey: .ticketId)
        try c.encode(usePoints ? 1 : 0, forKey: .isUsePoint)
        try c.encodeIfPresent(childAge, forKey: .childAge)
        if let waitlistOffer {
            try c.encode(waitlistOffer.id, forKey: .waitlistOfferId)
            try c.encode(waitlistOffer.token, forKey: .waitlistOfferToken)
        }
    }
}

/// Amount names and defaults follow RegistrationQuote in the retained Flutter client.
/// Missing monetary fields stay unknown; none is replaced by zero or a currency conversion.
public struct RegistrationQuote: Decodable, Equatable {
    public let payAmount: Decimal?
    public let pointsUsed: Int
    public let pointsDeductYuan: Decimal?
    public let pointsUsable: Bool
    /// Server point balance on the quote, when the quote carries one. Nil stays unknown.
    public let availablePoints: Int?
    public let memberDiscountYuan: Decimal?
    public let couponDeductYuan: Decimal?
    public let clubMember: Bool
    public let quoteSign: String
    /// Source RegistrationQuoteResult.prioritySignupEnabled. Only an explicit true counts
    /// (mini-program `=== true`); absent or malformed values never invent a club benefit.
    public let prioritySignupEnabled: Bool
    /// Source `/api/registration/quote` refund deadline (`yyyy-MM-dd HH:mm:ss` or ISO string).
    public let refundDeadline: String?
    /// Source `/api/registration/quote` tri-state refundability (`true`, `false`, or `nil` when not applicable).
    /// In `pages/activity/baoming/baoming.js`, `payAmount > 0 && refundableNow === false` triggers the
    /// mandatory 24-hour non-refundable confirmation ("本单不可退").
    public let refundableNow: Bool?
    /// R7-PC-C2-1: MP baoming.js:1871-1876 shows the 通行证 row when the quote's `mkt.coveredByPass === true`.
    public let coveredByPass: Bool
    /// R7-PC-C2-1: quote `delivery` (包含内容), MP pages/activity/utils/quote-view.js:20-71. Nil when absent or malformed.
    public let delivery: RegistrationQuoteDelivery?

    private enum CodingKeys: String, CodingKey {
        case payAmount, pointsUsed, pointsDeductYuan, pointsUsable, pointsBalance, availablePoints, userPoints
        case memberDiscountYuan, couponDeductYuan, clubMember, quoteSign
        case prioritySignupEnabled, refundDeadline, refundableNow, mkt, delivery
    }
    private struct Marketing: Decodable {
        let coveredByPass: Bool
        private enum CodingKeys: String, CodingKey { case coveredByPass }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            coveredByPass = ((try? c.decodeIfPresent(Bool.self, forKey: .coveredByPass)) ?? nil) == true
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        payAmount = try c.registrationMoney(forKey: .payAmount)
        pointsUsed = try c.decodeIfPresent(Int.self, forKey: .pointsUsed) ?? 0
        pointsDeductYuan = try c.registrationMoney(forKey: .pointsDeductYuan)
        pointsUsable = try c.decodeIfPresent(Bool.self, forKey: .pointsUsable) ?? true
        availablePoints = try c.decodeIfPresent(Int.self, forKey: .pointsBalance)
            ?? c.decodeIfPresent(Int.self, forKey: .availablePoints)
            ?? c.decodeIfPresent(Int.self, forKey: .userPoints)
        if let availablePoints, availablePoints < 0 { throw APIError.malformedResponse }
        memberDiscountYuan = try c.registrationMoney(forKey: .memberDiscountYuan)
        couponDeductYuan = try c.registrationMoney(forKey: .couponDeductYuan)
        clubMember = try c.decodeIfPresent(Bool.self, forKey: .clubMember) ?? false
        quoteSign = try c.decodeIfPresent(String.self, forKey: .quoteSign) ?? ""
        prioritySignupEnabled = ((try? c.decodeIfPresent(Bool.self, forKey: .prioritySignupEnabled)) ?? nil) == true
        let rawDeadline = try? c.decodeIfPresent(String.self, forKey: .refundDeadline)
        refundDeadline = rawDeadline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? rawDeadline?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        refundableNow = (try? c.decodeIfPresent(Bool.self, forKey: .refundableNow)) ?? nil
        coveredByPass = ((try? c.decodeIfPresent(Marketing.self, forKey: .mkt)) ?? nil)?.coveredByPass == true
        delivery = (try? c.decodeIfPresent(RegistrationQuoteDelivery.self, forKey: .delivery)) ?? nil
        guard pointsUsed >= 0 else { throw APIError.malformedResponse }
    }

    /// A known total and a signature are both required, even for an explicitly zero quote.
    /// This does not attest that the signature is authentic, current, or valid for another selection.
    public var isUsableForCreate: Bool {
        payAmount != nil && !quoteSign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public var hasPointsDeduction: Bool { pointsDeductYuan.map { $0 > .zero } ?? false }
    /// Matches mini-program `baoming.js`: `payAmount > 0 && res.data.refundableNow === false`.
    /// Pure-points / zero-yuan orders (`payAmount <= 0`) or `refundableNow != false` do not require the 24h non-refundable modal.
    public var requiresNonRefundableConfirmation: Bool {
        guard let payAmount, payAmount > .zero else { return false }
        return refundableNow == false
    }
}

/// An offer cannot be encoded with only an ID or only a token.
public struct RegistrationWaitlistOffer: Equatable {
    public let id: Int
    public let token: String

    public init(id: Int, token: String) throws {
        guard id > 0, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidRequest
        }
        self.id = id
        self.token = token
    }
}

/// Retain this immutable value for every attempt of the same create intent, including timeouts.
/// Its ID is generated once, never during encoding. Do not create a fresh value simply to retry.
/// Changing selection/points requires a fresh quote. Replacing an unresolved intent requires
/// order reconciliation first; this type deliberately provides no automatic key rotation.
public struct RegistrationCreateIntent: Encodable, Equatable {
    public let selection: RegistrationQuoteRequest
    public let realName: String
    public let phone: String
    public let email: String?
    public let participateDate: String?
    public let usesAppPaymentChannel: Bool
    public let requestID: String
    public let quoteSign: String
    public let waitlistOffer: RegistrationWaitlistOffer?
    public var ownerType: Int { 2 }

    /// `quote` must be the response for `selection`, under the current authenticated account.
    /// Opaque server signatures cannot be checked locally. Restoring a requestID is only valid
    /// with the same retained intent; the caller owns durable storage and account isolation.
    public init(selection: RegistrationQuoteRequest, quote: RegistrationQuote,
                realName: String, phone: String, email: String? = nil,
                participateDate: String? = nil, usesAppPaymentChannel: Bool = true,
                requestID: String = "app-\(UUID().uuidString)",
                waitlistOffer: RegistrationWaitlistOffer? = nil) throws {
        guard quote.isUsableForCreate,
              !realName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              requestID.utf16.count <= 64 else { throw APIError.invalidRequest }
        self.selection = selection
        self.realName = realName
        self.phone = phone
        self.email = email.flatMap { $0.isEmpty ? nil : $0 }
        self.participateDate = participateDate.flatMap { $0.isEmpty ? nil : $0 }
        self.usesAppPaymentChannel = usesAppPaymentChannel
        self.requestID = requestID
        self.quoteSign = quote.quoteSign
        guard selection.waitlistOffer == nil || selection.waitlistOffer == waitlistOffer else { throw APIError.invalidRequest }
        self.waitlistOffer = waitlistOffer
    }

    private enum CodingKeys: String, CodingKey {
        case ownerType, ownerId, ticketId, realName, phone, email, participateDate
        case isUsePoint, quoteSign, payChannel, requestId, waitlistOfferId, waitlistOfferToken, childAge
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ownerType, forKey: .ownerType)
        try c.encode(selection.ownerID, forKey: .ownerId)
        try c.encodeIfPresent(selection.ticketID, forKey: .ticketId)
        try c.encode(realName, forKey: .realName)
        try c.encode(phone, forKey: .phone)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(participateDate, forKey: .participateDate)
        try c.encode(selection.usePoints ? 1 : 0, forKey: .isUsePoint)
        try c.encodeIfPresent(selection.childAge, forKey: .childAge)
        try c.encode(quoteSign, forKey: .quoteSign)
        if usesAppPaymentChannel { try c.encode("APP", forKey: .payChannel) }
        try c.encode(requestID, forKey: .requestId)
        if let waitlistOffer {
            try c.encode(waitlistOffer.id, forKey: .waitlistOfferId)
            try c.encode(waitlistOffer.token, forKey: .waitlistOfferToken)
        }
    }
}

/// Source-shaped create data, including free-order and idempotent-replay variants.
/// Neither absent payment parameters nor a zero amount proves payment/registration completion.
/// A future coordinator must read authoritative registration status before declaring success.
public struct RegistrationCreateResult: Decodable, Equatable {
    public let registrationID: Int
    public let registrationNo: String?
    public let payableAmount: Decimal?
    public let payParams: [String: String]?
    public var hasPaymentParameters: Bool { payParams?.isEmpty == false }

    private enum CodingKeys: String, CodingKey { case registrationId, registrationNo, payableAmount, payParams }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        registrationID = try c.decode(Int.self, forKey: .registrationId)
        guard registrationID > 0 else { throw APIError.malformedResponse }
        registrationNo = try c.decodeIfPresent(String.self, forKey: .registrationNo)
        // Unlike quote amounts, Flutter's asDoubleOrNull accepts a numeric string here.
        payableAmount = try c.registrationMoney(forKey: .payableAmount, acceptsString: true)
        let raw = try c.decodeIfPresent([String: RegistrationPaymentScalar].self, forKey: .payParams)
        payParams = raw.flatMap { $0.isEmpty ? nil : $0.mapValues(\.text) }
    }
}

/// Keep server-owned messages and numeric/string business codes available for later routing.
/// No retry/rebuild/payment policy is inferred from a code alone.
public struct RegistrationResponseFailure: Error, Equatable {
    public let code: Int?
    public let message: String?
    public var hasServerMessage: Bool { message != nil }
}

/// Both source operations use an AjaxResult envelope with a numeric 200 and an object in data.
/// Malformed or absent success data fails decoding instead of fabricating a free order.
public struct RegistrationResponse<Value: Decodable>: Decodable {
    public let data: Value
    private enum CodingKeys: String, CodingKey { case code, msg, data }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let numericCode = try? c.decode(Int.self, forKey: .code)
        guard numericCode == 200 else {
            let stringCode = try? c.decode(String.self, forKey: .code)
            throw RegistrationResponseFailure(
                code: numericCode ?? stringCode.flatMap(Int.init),
                message: try? c.decode(String.self, forKey: .msg)
            )
        }
        data = try c.decode(Value.self, forKey: .data)
    }
}

public typealias RegistrationQuoteResponse = RegistrationResponse<RegistrationQuote>
public typealias RegistrationCreateResponse = RegistrationResponse<RegistrationCreateResult>

private extension KeyedDecodingContainer {
    func registrationMoney(forKey key: Key, acceptsString: Bool = false) throws -> Decimal? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        let value: Decimal
        if let string = try? decode(String.self, forKey: key) {
            guard acceptsString else { throw APIError.malformedResponse }
            // Decimal(string:) alone accepts numeric prefixes. Validate the entire wire value.
            let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.range(of: #"\A[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\z"#,
                             options: .regularExpression) != nil,
                  let decimal = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
                throw APIError.malformedResponse
            }
            value = decimal
        } else {
            value = try decode(Decimal.self, forKey: key)
        }
        guard !value.isNaN, value >= .zero else { throw APIError.malformedResponse }
        return value
    }
}

/// The Flutter create model stringifies scalar payment values, including a numeric timestamp.
/// Preserve opaque keys without claiming that the provider parameters are complete or executable.
private struct RegistrationPaymentScalar: Decodable {
    let text: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { text = "" }
        else if let value = try? c.decode(String.self) { text = value }
        else if let value = try? c.decode(Bool.self) { text = value ? "true" : "false" }
        else if let value = try? c.decode(Int.self) { text = String(value) }
        else {
            let value = try c.decode(Decimal.self)
            guard !value.isNaN else { throw APIError.malformedResponse }
            text = NSDecimalNumber(decimal: value).stringValue
        }
    }
}
