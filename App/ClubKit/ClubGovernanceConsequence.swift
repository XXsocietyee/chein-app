import SwiftUI

/// verify-r1 3.8 / MC-33 (Figma 222:5684): which club governance commands confirm in `ClubConsequenceSheet`, and what
/// that sheet says. The sheet replaces the form's plain confirm, so each command is still confirmed exactly once.
enum ClubGovernanceConsequence: Equatable {
    case ban, transferOwner, revokeRole, dissolve

    init?(_ operation: ClubGovernanceMutation) {
        switch operation {
        case .ban: self = .ban
        case .transferOwner: self = .transferOwner
        case .revokeRole: self = .revokeRole
        case .dissolve: self = .dissolve
        default: return nil
        }
    }

    private var key: String {
        switch self {
        case .ban: return "ban"
        case .transferOwner: return "transferOwner"
        case .revokeRole: return "revokeRole"
        case .dissolve: return "dissolve"
        }
    }

    private var symbols: (String, String) {
        switch self {
        case .ban: return ("clock.badge.xmark", "bell.slash")
        case .transferOwner: return ("crown", "person.crop.circle.badge.minus")
        case .revokeRole: return ("shield.slash", "person.2")
        case .dissolve: return ("trash", "person.3.sequence")
        }
    }

    func sheet(locale: Locale, onConfirm: @escaping () -> Void) -> ClubConsequenceSheet {
        let text: (String) -> String = { OpsR3Text.string("r3club.consequence.\(key).\($0)", locale: locale) }
        return ClubConsequenceSheet(
            title: text("title"),
            consequences: [
                CYConfirmConsequence(systemImage: symbols.0, text: text("line1")),
                CYConfirmConsequence(systemImage: symbols.1, text: text("line2")),
            ],
            confirmTitle: text("confirm"),
            onConfirm: onConfirm)
    }
}
