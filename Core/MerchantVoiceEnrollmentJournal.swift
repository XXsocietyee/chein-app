import Foundation

/// `pages/merchant/utils/voice-enrollment-journal.js` on hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Line 6 defines `request` as a local id check. The four calls pass one property and do not
/// forward `url`. There is no HTTP method and no API path. Nothing here builds or sends a request.
public enum MerchantVoiceEnrollmentJournal {
    /// Same expression as the mini-program: `sample:` plus 64 lowercase hex digits, or 8-4-4-4-12 lowercase hex.
    public static let idPattern = #"^(?:sample:[a-f0-9]{64}|[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$"#

    public static let httpMethod: String? = nil

    /// Line 18. `request(value.active)`.
    public static let activeCall = "request(value.active)"
    /// Line 20. `request(row.requestId)`.
    public static let recordRequestIDCall = "request(row.requestId)"
    /// Line 76. `request(result.voiceRequestId)`.
    public static let voiceRequestIDCall = "request(result.voiceRequestId)"
    /// Line 100. `request(value.requestId)`.
    public static let recoverRequestIDCall = "request(value.requestId)"

    public static func accepts(_ value: String) -> Bool {
        value.range(of: idPattern, options: .regularExpression) != nil
    }
}
