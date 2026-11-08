import Foundation

/// club/create + club/edit parity helpers (pure logic; the SwiftUI screen only renders the result).
public enum ClubOperationsPort {
    /// Field limits copied from the mini-program inputs (maxlength) and mirrored by `ClubOperationsDraft.validate`.
    public static let limits: [String: Int] = ["name": 30, "city": 20, "description": 200, "keywords": 60, "style": 30]

    public static func limit(for field: String) -> Int? { limits[field] }

    /// `N / 200` style counter value; never negative and counted in Characters like the validator.
    public static func counter(_ text: String, field: String) -> (used: Int, limit: Int)? {
        guard let limit = limits[field] else { return nil }
        return (text.count, limit)
    }

    public static func isOverLimit(_ text: String, field: String) -> Bool {
        guard let c = counter(text, field: field) else { return false }
        return c.used > c.limit
    }

    /// First wizard step (1 type, 3 name, 4 city) whose required value is blank, mirroring the mini
    /// `submit()` pre-check; `nil` when the three required inputs are present.
    public static func missingCreateStep(clubType: String, name: String, city: String) -> Int? {
        func blank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if blank(clubType) { return 1 }
        if blank(name) { return 3 }
        if blank(city) { return 4 }
        return nil
    }

    /// Localization key (see port-1-new-strings.md) for the hint shown for a missing step.
    public static func missingStepHintKey(_ step: Int) -> String? {
        switch step {
        case 1: return "club.ops.create.needType"
        case 3: return "club.ops.create.needName"
        case 4: return "club.ops.create.needCity"
        default: return nil
        }
    }
}
