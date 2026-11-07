import Foundation

/// Mini-program `utils/compliance/separate-consent.js`: processing that sends personal material to a third
/// party model needs its own opt-in, recorded as `AGREE` for a fixed (docType, scene) pair. Refusing stops
/// only that feature. Voice enrollment's wire record lives in `StoreCharacterVoiceConsentRecord`.
public enum SeparateConsentFeature: String, CaseIterable, Equatable {
    case photo, voice

    public var docType: String {
        switch self { case .photo: return "photo_model_processing"; case .voice: return "voice_clone_processing" }
    }
    public var scene: String {
        switch self { case .photo: return "object_photo"; case .voice: return "merchant_voice" }
    }
    public static let eventType = "AGREE"

    /// The (docType, scene, eventType) triple the source sends to `recordConsent`.
    public var recordFields: [String: String] { ["docType": docType, "scene": scene, "eventType": Self.eventType] }

    public enum Answer: Equatable { case agree, decline, dialogFailed, timedOut }
    public enum Decision: Equatable {
        /// Record the consent now.
        case record
        /// Stop only this feature; nothing is recorded.
        case declined
        /// Signed out, or account/page changed while the dialog was open: ask again, record nothing.
        case reconfirm
        case notCompleted
    }

    /// Source `requestSeparateConsent`: a positive signed-in account is required before the dialog; after it,
    /// the owner (account + authorization) and page must be unchanged, then agree records / decline stops.
    public static func decide(accountID: Int?, ownerStillCurrent: Bool, answer: Answer) -> Decision {
        guard (accountID ?? 0) > 0 else { return .reconfirm }
        switch answer {
        case .dialogFailed, .timedOut: return .notCompleted
        case .agree: return ownerStillCurrent ? .record : .reconfirm
        case .decline: return ownerStillCurrent ? .declined : .reconfirm
        }
    }
}
