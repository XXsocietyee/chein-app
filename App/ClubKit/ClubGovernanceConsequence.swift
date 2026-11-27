import SwiftUI

/// verify-r1 3.8 / MC-33 (Figma 222:5684): which club governance commands confirm in `ClubConsequenceSheet`, and what
/// that sheet says. The sheet replaces the form's plain confirm, so each command is still confirmed exactly once.
enum ClubGovernanceConsequence: Equatable {
    case ban, transferOwner, revokeRole, dissolve, endTopic

    init?(_ operation: ClubGovernanceMutation) {
        switch operation {
        case .ban: self = .ban
        case .transferOwner: self = .transferOwner
        case .revokeRole: self = .revokeRole
        case .dissolve: self = .dissolve
        // r4 · MC-27: ending a topic cancels its sessions and refunds people, so it confirms with its consequences.
        case .endTopic: self = .endTopic
        default: return nil
        }
    }

    private var key: String {
        switch self {
        case .ban: return "ban"
        case .transferOwner: return "transferOwner"
        case .revokeRole: return "revokeRole"
        case .dissolve: return "dissolve"
        case .endTopic: return "endTopic"
        }
    }

    /// Two lines for transfer / end topic; mp-club r3 pass 8 (MP utils/danger-actions.js `club.dissolve`): 解散 lists the
    /// MP's three consequences in order (members removed, events taken down without automatic refunds, cannot be undone).
    private func defaultConsequences(_ text: (String) -> String) -> [CYConfirmConsequence] {
        var lines = [
            CYConfirmConsequence(systemImage: symbols.0, text: text("line1")),
            CYConfirmConsequence(systemImage: symbols.1, text: text("line2")),
        ]
        if self == .dissolve {
            lines.append(CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: text("line3")))
        }
        return lines
    }

    private var symbols: (String, String) {
        switch self {
        case .ban: return ("clock.badge.xmark", "bell.slash")
        case .transferOwner: return ("crown", "person.crop.circle.badge.minus")
        case .revokeRole: return ("shield.slash", "person.2")
        case .dissolve: return ("person.2.slash", "calendar.badge.minus")
        // mp-club r3 (MP cy/club-topic-end-confirm): 停止售卖并退票, then the lighter alternative 下架就够了; confirm 结束并退款.
        case .endTopic: return ("arrow.uturn.backward.circle", "eye.slash")
        }
    }

    /// `name`: the member (ban) or the role (revoke) the MP names in its title, or the topic (结束主题) it names
    /// above the body; nil keeps the generic sheet.
    func sheet(locale: Locale, name: String? = nil, onConfirm: @escaping () -> Void) -> ClubConsequenceSheet {
        let named = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForConsequence
        let text: (String) -> String = { OpsR3Text.string("r3club.consequence.\(key).\($0)", locale: locale) }
        switch self {
        case .ban:
            // CLB-governance-04 (MP governance js:445-451): the ban ends membership and the group chat at once;
            // unbanning only restores the right to apply.
            let mp: (String) -> String = { appLocalized(String.LocalizationValue(stringLiteral: "club.gov.consequence.ban." + $0), locale: locale) }
            return ClubConsequenceSheet(
                title: named.map { appLocalized("club.gov.consequence.ban.titleNamed \($0)", locale: locale) } ?? mp("title"),
                consequences: [
                    CYConfirmConsequence(systemImage: "person.crop.circle.badge.xmark", text: mp("line1")),
                    CYConfirmConsequence(systemImage: "arrow.uturn.backward.circle", text: mp("line2")),
                ],
                confirmTitle: mp("confirm"),
                onConfirm: onConfirm)
        case .revokeRole:
            // CLB-roles-07 (MP utils/danger-actions.js `club.role.revoke`): one confirm with its three consequences.
            let mp: (String) -> String = { appLocalized(String.LocalizationValue(stringLiteral: "club.gov.consequence.revokeRole." + $0), locale: locale) }
            return ClubConsequenceSheet(
                title: named.map { appLocalized("club.gov.consequence.revokeRole.titleNamed \($0)", locale: locale) } ?? mp("title"),
                consequences: [
                    CYConfirmConsequence(systemImage: "lock", text: mp("line1")),
                    CYConfirmConsequence(systemImage: "person.2", text: mp("line2")),
                    CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: mp("line3")),
                ],
                confirmTitle: mp("confirm"),
                onConfirm: onConfirm)
        default:
            // mp-club r3 pass 8 (MP club-topic-end-confirm, CU-C-154): the title stays 结束主题; the topic name is the
            // first line above the consequences, not part of the title. Only 结束主题 passes a name here.
            return ClubConsequenceSheet(
                title: text("title"),
                objectName: self == .endTopic ? named : nil,
                consequences: defaultConsequences(text),
                confirmTitle: text("confirm"),
                onConfirm: onConfirm)
        }
    }
}

private extension String {
    var nilIfEmptyForConsequence: String? { isEmpty ? nil : self }
}
