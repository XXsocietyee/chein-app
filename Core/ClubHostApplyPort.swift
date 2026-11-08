import Foundation

/// club/apply parity helpers: the mini-program wizard counts selected capabilities ("已选 N 项")
/// and only accepts non-negative whole numbers for the two optional event-size fields.
public enum ClubHostApplyPort {
    public static let capabilityKeys = ["canDesignRoute", "canDesignTask", "canNpc", "canMerchantCoop"]
    public static let sizeKeys = ["maxEventSize", "avgEventSize"]

    public static func capabilityCount(_ flags: [String: Bool]) -> Int {
        capabilityKeys.filter { flags[$0] == true }.count
    }

    /// Empty is allowed (sent as null). Otherwise a base-10 integer >= 0, matching parseInt on a number input.
    public static func isValidSize(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return true }
        guard let number = Int(value) else { return false }
        return number >= 0
    }

    /// Keys of size fields that must be fixed before the application can be reviewed.
    public static func invalidSizeKeys(_ text: [String: String]) -> [String] {
        sizeKeys.filter { !isValidSize(text[$0] ?? "") }
    }

    public static func requiredFieldsFilled(_ text: [String: String]) -> Bool {
        let name = (text["leaderName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = (text["phone"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !phone.isEmpty
    }

    /// Mini-program step gating: 1 needs name+phone, 2 needs an experience choice, 3 is optional, 4 is optional.
    public static func canAdvance(step: Int, text: [String: String]) -> Bool {
        switch step {
        case 1: return requiredFieldsFilled(text)
        case 2: return !(text["experience"] ?? "").isEmpty && invalidSizeKeys(text).isEmpty
        default: return true
        }
    }

    public static func canReview(text: [String: String]) -> Bool {
        requiredFieldsFilled(text) && invalidSizeKeys(text).isEmpty
    }
}
