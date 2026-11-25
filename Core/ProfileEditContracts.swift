import Foundation

/// Read-only current-self phone display. Raw server phone bytes are never retained.
public enum ProfileBoundPhoneDisplay: Equatable {
    case unavailable
    case unbound
    case masked(String)

    public static func masking(_ source: String) -> Self {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .unbound }
        guard value.utf8.count <= 64 else { return .unavailable }
        let bytes = Array(value.utf8)
        guard bytes.allSatisfy({ (48...57).contains($0) || [32, 40, 41, 43, 45, 46].contains($0) }) else { return .unavailable }
        let digits = bytes.filter { (48...57).contains($0) }
        // Supported current mobile/E.164 lengths hide at least four digits. Unknown
        // legacy shapes must not be printed raw or mistaken for an unbound account.
        guard (11...15).contains(digits.count) else { return .unavailable }
        let prefix = String(decoding: digits.prefix(3), as: UTF8.self)
        let suffix = String(decoding: digits.suffix(4), as: UTF8.self)
        return .masked(prefix + "****" + suffix)
    }
}

/// Read-only bound phone for the participant form. The mini-program shows `data.phone || data.mobilePhone`
/// and does not write it back. This value is not the masked profile display and is not part of the edit payload.
public struct ProfileParticipantPhone: Equatable, Sendable {
    public let text: String
    public init?(source: String) {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 64 else { return nil }
        let bytes = Array(value.utf8)
        guard bytes.allSatisfy({ (48...57).contains($0) || [32, 40, 41, 43, 45, 46].contains($0) }) else { return nil }
        let digits = bytes.filter { (48...57).contains($0) }
        guard (11...15).contains(digits.count) else { return nil }
        text = value
    }
}

/// Text edits are staged together. The remaining replacement fields retain their
/// wire values, including whitespace and delimiter order; do not round-trip image URLs.
public struct ProfileEditSnapshot: Decodable, Equatable {
    public let id: Int
    public let nickname: String
    public let introduction: String
    public let avatar: String
    public let wechat: String
    public let casePics: String
    /// Nil means this response omitted the field; explicit JSON null is an editable empty value.
    public let caseIntroduction: String?
    public let tagIds: String
    /// Display-only labels from the existing self response; never sent back.
    public let preferenceNames: [Int: String]
    /// Metadata only; not part of the editable draft, payload or avatar replacement hash.
    public let phoneDisplay: ProfileBoundPhoneDisplay
    enum CodingKeys: String, CodingKey {
        case id, nickname, introduction, avatar, wechat, casePics, tagIds, sysCategoryList, phone
        case caseIntroduction = "caseIntroducton"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        guard id > 0 else { throw APIError.malformedResponse }
        if !c.contains(.phone) { phoneDisplay = .unavailable }
        else if try c.decodeNil(forKey: .phone) { phoneDisplay = .unbound }
        else if let phone = try? c.decode(String.self, forKey: .phone) { phoneDisplay = .masking(phone) }
        else { phoneDisplay = .unavailable }
        nickname = try c.decode(String.self, forKey: .nickname)
        // Explicit null is the source contract's empty value. Missing replacement fields
        // cannot safely be inferred as empty when this read is used for a destructive update.
        func preserved(_ key: CodingKeys) throws -> String {
            guard c.contains(key) else { throw APIError.malformedResponse }
            return try c.decodeIfPresent(String.self, forKey: key) ?? ""
        }
        if c.contains(.caseIntroduction) { caseIntroduction = try preserved(.caseIntroduction) }
        else { caseIntroduction = nil }
        let labels = (try? c.decode([ProfilePreferenceLabel].self, forKey: .sysCategoryList)) ?? []
        preferenceNames = ProfilePreferenceRemoval.names(labels)
        introduction = try preserved(.introduction)
        avatar = try preserved(.avatar); wechat = try preserved(.wechat); casePics = try preserved(.casePics)
        if c.contains(.tagIds) { tagIds = try preserved(.tagIds) }
        else {
            struct Category: Decodable { let id: Int }
            // E2E R9: `sysCategoryList` may be null or absent; that means no preferences, not a broken profile.
            let categories = try c.decodeIfPresent([Category].self, forKey: .sysCategoryList) ?? []
            guard categories.allSatisfy({ $0.id > 0 }) else { throw APIError.malformedResponse }
            tagIds = categories.map { String($0.id) }.joined(separator: ",")
        }
    }
    public var draft: ProfileEditDraft { .init(name: nickname, introduction: introduction) }
}
public struct ProfileEditDraft: Equatable {
    public var name: String
    public var introduction: String
    /// Nil leaves the server field untouched; an explicit empty string clears it.
    public var caseIntroduction: String?
    /// Clear-only proposal; no arbitrary replacement URL or upload capability.
    public var removesContactQR: Bool
    /// Clear all existing work-image references; no replacement or upload capability.
    public var removesCasePictures: Bool
    /// A source-bound ordered subset, never an arbitrary URL replacement.
    public var casePictureSubset: ProfileCasePictureSubset?
    /// Nil preserves the complete wire string. An explicit empty selection clears preferences.
    public var routePreferenceIDs: [Int]?
    public private(set) var avatarReplacement: ProfileAvatarReplacement?
    /// A3-01: checked uploads for 探索作品, appended after the kept pictures (mini-program `uploadCasePic`, ≤ 9 in all).
    public private(set) var addedCasePictures: [ProfileAvatarReplacement] = []
    /// A3-01: a checked upload that replaces the 联系二维码 (mini-program `uploadWechat`).
    public private(set) var contactQRReplacement: ProfileAvatarReplacement?
    public init(name: String = "", introduction: String = "", routePreferenceIDs: [Int]? = nil, avatarReplacement: ProfileAvatarReplacement? = nil, caseIntroduction: String? = nil, removesContactQR: Bool = false, removesCasePictures: Bool = false, casePictureSubset: ProfileCasePictureSubset? = nil) {
        self.name = name; self.introduction = introduction; self.routePreferenceIDs = routePreferenceIDs
        self.avatarReplacement = avatarReplacement; self.caseIntroduction = caseIntroduction
        self.removesContactQR = removesContactQR; self.removesCasePictures = removesCasePictures; self.casePictureSubset = casePictureSubset
    }
    public func stagingAvatar(_ value: ProfileAvatarReplacement) -> Self {
        .init(name: name, introduction: introduction, routePreferenceIDs: routePreferenceIDs, avatarReplacement: value, caseIntroduction: caseIntroduction, removesContactQR: removesContactQR, removesCasePictures: removesCasePictures, casePictureSubset: casePictureSubset).carryingUploads(of: self)
    }
    /// A3-01: keeps the staged 探索作品 / 联系二维码 uploads across init-based copies of a draft.
    public func carryingUploads(of other: Self) -> Self {
        var next = self; next.addedCasePictures = other.addedCasePictures; next.contactQRReplacement = other.contactQRReplacement; return next
    }
    public func stagingCasePicture(_ value: ProfileAvatarReplacement) -> Self {
        var next = self; next.addedCasePictures.append(value); return next
    }
    public func removingAddedCasePicture(id: UUID) -> Self {
        var next = self; next.addedCasePictures.removeAll { $0.id == id }; return next
    }
    /// A new QR replaces the old one, so a staged removal of the old one no longer applies.
    public func stagingContactQR(_ value: ProfileAvatarReplacement) -> Self {
        var next = self; next.contactQRReplacement = value; next.removesContactQR = false; return next
    }
    public func removingContactQRReplacement() -> Self { var next = self; next.contactQRReplacement = nil; return next }
    /// Every checked upload this draft would write; any of them makes the save image-bearing.
    public var stagedUploads: [ProfileAvatarReplacement] {
        [avatarReplacement].compactMap { $0 } + addedCasePictures + [contactQRReplacement].compactMap { $0 }
    }
    /// Pictures the saved profile would hold: the kept ones plus the staged uploads.
    public func casePictureCount(keeping snapshot: ProfileEditSnapshot) -> Int {
        let kept = removesCasePictures ? 0
            : (casePictureSubset.flatMap { $0.matches(source: snapshot.casePics) ? $0.retainedCount : nil }
               ?? ProfileCasePortfolio(casePics: snapshot.casePics).imageCount)
        return kept + addedCasePictures.count
    }
    public var normalized: Self { normalizedFields.carryingUploads(of: self) }
    private var normalizedFields: Self { .init(name: name.trimmingCharacters(in: .whitespacesAndNewlines), introduction: introduction.trimmingCharacters(in: .whitespacesAndNewlines), routePreferenceIDs: routePreferenceIDs, avatarReplacement: avatarReplacement, caseIntroduction: caseIntroduction, removesContactQR: removesContactQR, removesCasePictures: removesCasePictures, casePictureSubset: casePictureSubset) }
    public func hasChanges(comparedTo snapshot: ProfileEditSnapshot) -> Bool {
        var ordinary = normalized; ordinary.caseIntroduction = nil; ordinary.removesContactQR = false; ordinary.removesCasePictures = false; ordinary.casePictureSubset = nil
        let caseChanged = caseIntroduction.map { !ProfileCasePortfolio.sameText($0, snapshot.caseIntroduction) } ?? false
        let contactQRChanged = removesContactQR && !snapshot.wechat.isEmpty
        let picturesChanged = (removesCasePictures && ProfileCasePortfolio(casePics: snapshot.casePics).imageCount > 0)
            || casePictureSubset?.hasChanges == true || !addedCasePictures.isEmpty || contactQRReplacement != nil
        return ordinary != snapshot.draft.normalized || caseChanged || contactQRChanged || picturesChanged
    }
    public var isValid: Bool {
        let ids = routePreferenceIDs ?? []
        return !(removesCasePictures && casePictureSubset != nil) && !normalized.name.isEmpty && ids.allSatisfy { $0 > 0 } && Set(ids).count == ids.count
    }
}
public struct ProfileEditPayload: Encodable, Equatable {
    public let name: String
    public let introduction: String
    public let avatar: String
    /// `private(set) var` only so that A3-01 uploads can follow the kept value in the initializer.
    public private(set) var wechat: String
    /// Review metadata only; deliberately excluded from CodingKeys.
    public let removesContactQR: Bool
    public let removesCasePictures: Bool
    public let casePictureSubset: ProfileCasePictureSubset?
    public var changesCasePictures: Bool { removesCasePictures || casePictureSubset != nil || !addedCasePictures.isEmpty }
    /// A3-01: staged uploads for 探索作品 and 联系二维码. Review metadata; their references are in casePics / wechat.
    public let addedCasePictures: [ProfileAvatarReplacement]
    public let contactQRReplacement: ProfileAvatarReplacement?
    /// Every checked upload in this payload; any of them routes the save through the checked image transport.
    public var stagedUploads: [ProfileAvatarReplacement] {
        [avatarReplacement].compactMap { $0 } + addedCasePictures + [contactQRReplacement].compactMap { $0 }
    }
    public var carriesUpload: Bool { !stagedUploads.isEmpty }
    public private(set) var casePics: String
    public let caseIntroduction: String?
    public let tagIds: String
    public let avatarReplacement: ProfileAvatarReplacement?
    /// Review metadata only. The existing tagIds key is the sole wire representation.
    public let preferenceIDs: [Int]?
    enum CodingKeys: String, CodingKey {
        case name, introduction, avatar, wechat, casePics, tagIds
        case caseIntroduction = "caseIntroducton"
    }
    public init(draft: ProfileEditDraft, preserving snapshot: ProfileEditSnapshot) throws {
        guard draft.isValid, draft.caseIntroduction == nil || snapshot.caseIntroduction != nil else { throw APIError.invalidRequest }
        guard draft.casePictureSubset?.matches(source: snapshot.casePics) != false else { throw APIError.invalidRequest }
        casePictureSubset = draft.casePictureSubset?.hasChanges == true ? draft.casePictureSubset : nil
        caseIntroduction = draft.caseIntroduction
        preferenceIDs = draft.routePreferenceIDs
        removesContactQR = draft.removesContactQR && !snapshot.wechat.isEmpty
        removesCasePictures = draft.removesCasePictures && ProfileCasePortfolio(casePics: snapshot.casePics).imageCount > 0
        name = draft.normalized.name; introduction = draft.normalized.introduction
        for replacement in draft.stagedUploads {
            guard replacement.receipt.target.snapshotHash == ProfileAvatarExact.snapshot(snapshot) else { throw APIError.invalidRequest }
        }
        guard draft.addedCasePictures.isEmpty || draft.casePictureCount(keeping: snapshot) <= ProfileMediaKind.casePictureLimit else { throw APIError.invalidRequest }
        avatarReplacement = draft.avatarReplacement
        addedCasePictures = draft.addedCasePictures; contactQRReplacement = draft.contactQRReplacement
        avatar = draft.avatarReplacement?.reference ?? snapshot.avatar
        wechat = removesContactQR ? "" : snapshot.wechat
        casePics = removesCasePictures ? "" : (casePictureSubset?.wireValue ?? snapshot.casePics)
        // A3-01: an uploaded QR replaces the kept one; uploaded work pictures follow the kept ones,
        // `;`-separated as in the mini-program. The kept bytes themselves are never reserialized.
        if let qr = draft.contactQRReplacement { wechat = qr.reference }
        casePics = ProfileCasePortfolio.appending(draft.addedCasePictures.map(\.reference), to: casePics)
        tagIds = draft.routePreferenceIDs.map { $0.map(String.init).joined(separator: ",") } ?? snapshot.tagIds
    }
    public func matches(_ snapshot: ProfileEditSnapshot) -> Bool {
        if changesCasePictures && !casePics.utf8.elementsEqual(snapshot.casePics.utf8) { return false }
        if let caseIntroduction, !ProfileCasePortfolio.sameText(caseIntroduction, snapshot.caseIntroduction) { return false }
        if carriesUpload {
            guard zip([name, introduction, avatar, wechat, casePics, tagIds],
                      [snapshot.nickname, snapshot.introduction, snapshot.avatar, snapshot.wechat, snapshot.casePics, snapshot.tagIds])
                .allSatisfy({ $0.0.utf8.elementsEqual($0.1.utf8) }) else { return false }
        }
        return name == snapshot.nickname && introduction == snapshot.introduction && avatar == snapshot.avatar
        && wechat == snapshot.wechat && casePics == snapshot.casePics && tagIds == snapshot.tagIds
    }
}
public struct ProfileEditSession: Equatable {
    public let identity: ProfileReadIdentity
    public let viewerRevision: UInt64
    let token: String
    public init(accountID: Int, epoch: UInt64, token: String, viewerRevision: UInt64 = 0) throws {
        guard accountID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        identity = .init(accountID: accountID, epoch: epoch); self.token = token
        self.viewerRevision = viewerRevision
    }
}
public enum ProfileEditWriteError: Error { case notSent, rejected(ProfileReadFailure), outcomeUnknown }
public protocol ProfileEditServing {
    func read(token: String) async throws -> ProfileEditSnapshot
    func save(_ payload: ProfileEditPayload, token: String) async throws
}
