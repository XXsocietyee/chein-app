import Foundation

/// A3-01 (mini-program pages/gerenziliao `uploadCasePic` / `uploadWechat`): which profile image an upload
/// fills. The avatar keeps its square `image_1_1` route; the 探索作品 pictures and the 联系二维码 go up
/// uncropped, as the mini-program's `app.chooseImage` does without a crop ratio (`bizType: image_free`).
public enum ProfileMediaKind: String, Equatable, CaseIterable, Sendable {
    case avatar, casePicture, contactQR
    /// Mini-program cap for 探索作品 (`9 - tempCasePics.length`).
    public static let casePictureLimit = 9
    var bizType: String { self == .avatar ? "image_1_1" : "image_free" }
    var filename: String {
        switch self {
        case .avatar: return "avatar.jpg"
        case .casePicture: return "case.jpg"
        case .contactQR: return "wechat.jpg"
        }
    }
    /// Only the avatar requires a square image; the other kinds keep the picked frame.
    public func accepts(_ image: RetainedSelectedImage) -> Bool { self != .avatar || image.width == image.height }
    /// The staged replacement that this kind put into the draft, matched exactly.
    public func isStaged(_ replacement: ProfileAvatarReplacement, in draft: ProfileEditDraft) -> Bool {
        switch self {
        case .avatar: return draft.avatarReplacement == replacement
        case .casePicture: return draft.addedCasePictures.contains(replacement)
        case .contactQR: return draft.contactQRReplacement == replacement
        }
    }
}

extension ProfileAvatarUploadClient {
    /// Same checked multipart route and fences as the avatar upload, with the kind's bizType.
    public func upload(_ image: RetainedSelectedImage, kind: ProfileMediaKind, target: ProfileAvatarTarget, attemptID: UUID,
                       ownerCurrent: @escaping () -> Bool) async throws -> ProfileAvatarUploadReceipt {
        if kind == .avatar { return try await upload(image, target: target, attemptID: attemptID, ownerCurrent: ownerCurrent) }
        guard kind.accepts(image) else { throw ProfileAvatarFailure.notSent }
        return try await upload(jpeg: image.jpeg, bizType: kind.bizType, filename: kind.filename, target: target,
                                attemptID: attemptID, ownerCurrent: ownerCurrent)
    }
}

extension ProfileCasePortfolio {
    /// Appends newly uploaded references to the kept wire value with the mini-program's `;` separator,
    /// without reserializing the kept part.
    public static func appending(_ references: [String], to kept: String) -> String {
        guard !references.isEmpty else { return kept }
        let added = references.joined(separator: ";")
        if kept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return added }
        return kept.hasSuffix(";") ? kept + added : kept + ";" + added
    }
}
