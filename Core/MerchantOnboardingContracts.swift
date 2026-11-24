import Foundation

/// Only /merchant/info can establish absence or an application. Entry intent grants nothing.
public enum MerchantOnboardingSnapshot: Equatable {
    case none
    case application(MerchantOnboardingApplication)
}

public struct MerchantOnboardingApplication: Decodable, Equatable {
    public let id: Int
    public let status: Int
    public let accountStatus: Int
    public let name, preference, phone, address, businessTime, description, businessLicense: String
    public let derivatives, rejectReason, disableReason, createTime: String
    /// Comma-separated MERCHANT industry ids when /merchant/info returns them (M-16); empty when absent.
    public let categoryIds: String
    /// Map pin from the apply form. Nil when the stored application has no usable coordinate.
    public let locationLat: Double?
    public let locationLng: Double?
    public var canReapply: Bool { status == 2 && accountStatus != 2 }
    public var statusKey: String {
        if accountStatus == 2 { return "merchant.onboarding.status.disabled" }
        if status == 1 && accountStatus == 1 { return "merchant.onboarding.status.effective" }
        if status == 2 { return "merchant.onboarding.status.rejected" }
        if status == 1 { return "merchant.onboarding.status.activation" }
        return "merchant.onboarding.status.pending"
    }
    public var explanationKey: String { statusKey + ".hint" }
    /// A historical rejection is never presented as the reason for disablement.
    public var displayedReason: String? {
        let reason = accountStatus == 2 ? disableReason : (status == 2 ? rejectReason : "")
        return reason.isEmpty ? nil : reason
    }
    enum CodingKeys: String, CodingKey {
        case id, status, accountStatus, name, preference, phone, address, businessTime, description, businessLicense
        case derivatives, reson, disableReason, createTime, categoryIds, locationLat, locationLng
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.merchantInteger(.id), id > 0,
              let status = c.merchantInteger(.status), (0...2).contains(status),
              let accountStatus = c.merchantInteger(.accountStatus), (0...2).contains(accountStatus) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Unconfirmed merchant application")
        }
        self.id = id; self.status = status; self.accountStatus = accountStatus
        func text(_ key: CodingKeys) throws -> String {
            try c.decodeIfPresent(String.self, forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        name = try text(.name); preference = try text(.preference); phone = try text(.phone)
        address = try text(.address); businessTime = try text(.businessTime); description = try text(.description)
        businessLicense = try text(.businessLicense); derivatives = try text(.derivatives)
        rejectReason = try text(.reson); disableReason = try text(.disableReason); createTime = try text(.createTime)
        categoryIds = (try? text(.categoryIds)) ?? ""
        locationLat = Self.coordinate(c, .locationLat, range: -90...90)
        locationLng = Self.coordinate(c, .locationLng, range: -180...180)
    }
    private static func coordinate(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, range: ClosedRange<Double>) -> Double? {
        if let number = try? c.decodeIfPresent(Double.self, forKey: key), number.isFinite, range.contains(number) { return number }
        if let text = try? c.decodeIfPresent(String.self, forKey: key), let number = Double(text), number.isFinite, range.contains(number) { return number }
        return nil
    }
}

/// One MERCHANT industry row from api/category/list type=MERCHANT (server merges type 1 and 6).
public struct MerchantOnboardingCategory: Decodable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    private enum CodingKeys: String, CodingKey { case id, categoryName }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.merchantInteger(.id), id > 0 else { throw APIError.malformedResponse }
        let name = try c.decode(String.self, forKey: .categoryName).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw APIError.malformedResponse }
        self.id = id; self.name = name
    }
}

/// No public string initializer: a form cannot pretend a local image is an uploaded license.
public struct MerchantOnboardingLicense: Equatable {
    public let url: String
    init(serverURL: String) throws {
        let value = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URLComponents(string: value), url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil else { throw APIError.malformedResponse }
        self.url = value
    }
}

/// Merchant identity (owner 2026-11-16, verify-r1 Q2 changed): registering a business in China needs the operator's
/// real name and resident ID number. The number is held in a wrapper whose `description`, `debugDescription` and
/// reflection only ever show the masked form, so it cannot reach a log through string interpolation or `dump`.
/// It is sent once, in the application submit request (`realName`, `idCardNumber`).
public struct MerchantIdentityNumber: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// The raw text as typed. Read it only to build the request body or to bind the text field.
    public var rawValue: String
    public init(_ rawValue: String = "") { self.rawValue = rawValue }

    /// Upper-case, no spaces: the form that is validated and sent.
    public var normalized: String {
        rawValue.filter { !$0.isWhitespace }.uppercased()
    }

    public enum Failure: Equatable, Sendable { case empty, length, characters, dateField, checksum }

    /// GB 11643-1999: 17 digits and a check character (0-9 or X), a real calendar date in positions 7–14 (validity only; nothing is derived from it), and the ISO 7064 MOD 11-2 check.
    public var failure: Failure? {
        let value = Array(normalized)
        guard !value.isEmpty else { return .empty }
        guard value.count == 18 else { return .length }
        let body = value.prefix(17)
        guard body.allSatisfy({ $0.isASCII && $0.isNumber }), let last = value.last, last.isASCII, last.isNumber || last == "X" else { return .characters }
        let digits = body.compactMap { $0.wholeNumberValue }
        let year = digits[6] * 1000 + digits[7] * 100 + digits[8] * 10 + digits[9]
        let month = digits[10] * 10 + digits[11], day = digits[12] * 10 + digits[13]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        guard (1900...2100).contains(year), let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.month, from: date) == month, calendar.component(.day, from: date) == day else { return .dateField }
        let weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
        let sum = zip(digits, weights).reduce(0) { $0 + $1.0 * $1.1 }
        let checks: [Character] = ["1", "0", "X", "9", "8", "7", "6", "5", "4", "3", "2"]
        return checks[sum % 11] == last ? nil : .checksum
    }

    public var isValid: Bool { failure == nil }

    /// `110***********1234`: the first three and last four characters, the rest masked. Short input is fully masked.
    public var masked: String {
        let value = Array(normalized)
        guard value.count >= 8 else { return String(repeating: "*", count: value.count) }
        return String(value.prefix(3)) + String(repeating: "*", count: value.count - 7) + String(value.suffix(4))
    }

    public var description: String { masked }
    public var debugDescription: String { "MerchantIdentityNumber(\(masked))" }
    public var customMirror: Mirror { Mirror(self, children: ["masked": masked], displayStyle: .struct) }
}

public struct MerchantOnboardingDraft: Equatable {
    public private(set) var id: Int?
    public var name = "", preference = "", phone = "", address = "", businessTime = "", description = ""
    public var wechat = ""
    /// Parity apply P0 (M-16): 行业类型 chosen from api/category/list type=MERCHANT, 1–5 ids, sent as `categoryIds`.
    public var categoryIDs: [Int] = []
    public var categoryNames: [String] = []
    public static let categoryLimit = 5
    /// Owner 2026-11-16: 真实姓名 and 身份证号 for the identity step (step 4). Not restored on reapply: the
    /// application read does not return them.
    public var realName = ""
    public var idCardNumber = MerchantIdentityNumber()
    /// PIPL consent for the identity step (Figma `182:7628` / `406:9580`): 我已阅读并同意《个人信息处理规则》.
    /// Starts unchecked and is never restored on reapply; the backend refuses realName / idCardNumber without
    /// `identityConsent: true`.
    public var identityConsent = false
    public var license: MerchantOnboardingLicense?
    public var brandImages: MerchantOnboardingBrandImages?
    public var locationLat: Double?
    public var locationLng: Double?
    public private(set) var brandImagesSourceUnavailable = false
    public init() {}
    public init(reapplying application: MerchantOnboardingApplication) throws {
        guard application.canReapply else { throw APIError.invalidRequest }
        id = application.id; name = application.name; preference = application.preference
        phone = application.phone; address = application.address; businessTime = application.businessTime
        description = application.description
        categoryIDs = application.categoryIds.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { $0 > 0 }
        license = try? MerchantOnboardingLicense(serverURL: application.businessLicense)
        // New optional image flow admits valid historical image URLs only.
        // Unrecognized historical media stays omitted, not silently cleared.
        if !application.derivatives.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            brandImages = try? .init(source: application.derivatives)
            brandImagesSourceUnavailable = brandImages == nil
        }
        if let lat = application.locationLat, let lng = application.locationLng,
           MerchantOnboardingDraft.registrationCoordinates(lat: lat, lng: lng) != nil {
            locationLat = lat
            locationLng = lng
        }
    }
    public func blocker(step: Int? = nil) -> String? {
        if step == nil || step == 1 {
            if name.merchantOnboardingTrimmed.isEmpty { return "merchant.onboarding.required.name" }
            if categoryIDs.isEmpty || categoryIDs.count > Self.categoryLimit { return "merchant.onboarding.required.category" }
            if phone.merchantOnboardingTrimmed.isEmpty { return "merchant.onboarding.required.phone" }
            // Parity apply P1: source index.js:373-374 accepts an 11-digit mainland mobile number only.
            if phone.merchantOnboardingTrimmed.range(of: #"^1[3-9]\d{9}$"#, options: .regularExpression) == nil {
                return "merchant.onboarding.invalid.phone"
            }
        }
        if step == nil || step == 2 {
            if address.merchantOnboardingTrimmed.isEmpty { return "merchant.onboarding.required.address" }
            if businessTime.merchantOnboardingTrimmed.isEmpty { return "merchant.onboarding.required.hours" }
        }
        if step == nil || step == 3 {
            if license == nil { return "merchant.onboarding.required.license" }
        }
        if step == 4 { return identityBlocker() ?? consentBlocker() }
        return nil
    }

    /// The consent row's problem: nil once 我已阅读并同意《个人信息处理规则》 is checked.
    public func consentBlocker() -> String? {
        identityConsent ? nil : "merchant.onboarding.identity.required.consent"
    }

    /// The identity step's first problem, as a string key; nil when 真实姓名 and a valid 身份证号 are present.
    /// Checked by the wizard (step 4 and before submit). `blocker()` with no step keeps its earlier meaning.
    public func identityBlocker() -> String? {
        let name = realName.merchantOnboardingTrimmed
        if name.isEmpty { return "merchant.onboarding.identity.required.realName" }
        if name.count < 2 || name.count > 30 { return "merchant.onboarding.identity.invalid.realName" }
        switch idCardNumber.failure {
        case .none: return nil
        case .empty: return "merchant.onboarding.identity.required.idCard"
        case .length: return "merchant.onboarding.identity.invalid.idCardLength"
        case .characters: return "merchant.onboarding.identity.invalid.idCardCharacters"
        case .dateField, .checksum: return "merchant.onboarding.identity.invalid.idCard"
        }
    }
    public func jsonData() throws -> Data {
        guard blocker() == nil, let license else { throw APIError.invalidRequest }
        var fields: [String: Any] = [
            "name": name.merchantOnboardingTrimmed, "categoryIds": categoryIDs.map(String.init).joined(separator: ","),
            "phone": phone.merchantOnboardingTrimmed, "description": description.merchantOnboardingTrimmed,
            "address": address.merchantOnboardingTrimmed, "businessTime": businessTime.merchantOnboardingTrimmed,
            "businessLicense": license.url, "wechat": wechat.merchantOnboardingTrimmed
        ]
        if let brandImages { fields["derivatives"] = brandImages.wireValue }
        if let id { fields["id"] = id }
        if let pair = Self.registrationCoordinates(lat: locationLat, lng: locationLng) {
            fields["locationLat"] = pair.lat
            fields["locationLng"] = pair.lng
        }
        // Parity apply P0: identity is NOT part of merchant_registration (MerchantRegistrationDTO has no such fields);
        // it is registered first through POST api/publisher/identity (`identityRegistrationData`).
        return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }
    /// MP utils/publisher-identity.js registerIdentity: {realName, idCard, consent: true, source: "merchant_apply"}.
    public var canRegisterIdentity: Bool { identityBlocker() == nil && identityConsent }
    public func identityRegistrationData() throws -> Data {
        guard canRegisterIdentity else { throw APIError.invalidRequest }
        let fields: [String: Any] = ["realName": realName.merchantOnboardingTrimmed, "idCard": idCardNumber.normalized,
                                     "consent": true, "source": "merchant_apply"]
        return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }
    /// Both coordinates are sent, or neither. A half pair is not a map pin.
    public static func registrationCoordinates(lat: Double?, lng: Double?) -> (lat: Double, lng: Double)? {
        guard let lat, let lng, lat.isFinite, lng.isFinite, (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }
        return (lat, lng)
    }
}

/// Locale changes must not change the source-established persisted businessTime format.
public struct MerchantOnboardingHours: Equatable {
    public var days: Set<Int> = Set(0...6)
    public var startMinutes = 600
    public var endMinutes = 1320
    public init() {}
    public init?(wireValue: String) {
        guard let value = MerchantStoreHours(wireValue: wireValue) else { return nil }
        days = value.days; startMinutes = value.startMinutes; endMinutes = value.endMinutes
    }
    private var storeHours: MerchantStoreHours {
        var value = MerchantStoreHours(); value.days = days
        value.startMinutes = startMinutes; value.endMinutes = endMinutes; return value
    }
    public var overnight: Bool { storeHours.overnight }
    public var blocker: String? { storeHours.blocker }
    public func wireValue() throws -> String {
        try storeHours.wireValue()
    }
}

public struct MerchantOnboardingImage: Equatable {
    /// A local memory cap, not an invented backend upload limit.
    public static let maximumBytes = 10 * 1024 * 1024
    public let data: Data
    public init(jpegData: Data) throws {
        guard !jpegData.isEmpty, jpegData.count <= Self.maximumBytes,
              jpegData.starts(with: [0xff, 0xd8, 0xff]) else { throw APIError.invalidRequest }
        data = jpegData
    }
}

public struct MerchantOnboardingFailure: Error, Equatable {
    public let code: Int?
    public let message: String?
    public init(code: Int?, message: String? = nil) { self.code = code; self.message = message }
    public var isUnauthorized: Bool { code == 401 }
}
public enum MerchantOnboardingWriteError: Error, Equatable {
    case notSent, rejected(MerchantOnboardingFailure), outcomeUnknown
}
extension String {
    fileprivate var merchantOnboardingTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
