import SwiftUI

/// MC8-29-3 / MC8-29-4 (pages/merchant/team/index.js:668-718, utils/danger-actions.js:380-401): 移除成员 and
/// 撤销邀请 use the MP destructive confirm and send the MP fixed reason. There is no typed reason any more.
/// The confirmed mutation still goes through the page's reviewed prepare → submit path, so it dispatches only
/// when the merchant-business approval is granted (MC8-29-1); otherwise the review shows 提交暂不可用.
struct MerchantTeamDangerConfirm: Identifiable, Equatable {
    enum Kind: Equatable { case removeOperator, revokeInvite }
    let id = UUID()
    let kind: Kind
    let row: MerchantBusinessRecord

    /// The MP `confirmDanger` reasons, sent verbatim on the wire.
    static let removeOperatorReason = "店主在经营团队页移除成员"
    static let revokeInviteReason = "店主在经营团队页撤销邀请"

    var titleKey: LocalizedStringKey {
        switch kind {
        case .removeOperator:
            // MP 第十二轮 k3: the title names the member and role so the owner does not remove the wrong person.
            let role = row.fields.mbText("roleName") ?? row.fields.mbText("roleCode") ?? ""
            let name = role.isEmpty ? row.title : row.title + " · " + role
            return "merchantTeam.danger.removeTitle \(name)"
        case .revokeInvite: return "merchantTeam.danger.revokeTitle"
        }
    }
    var messageKey: LocalizedStringKey {
        kind == .removeOperator ? "merchantTeam.danger.removeBody" : "merchantTeam.danger.revokeBody"
    }
    var confirmKey: LocalizedStringKey {
        kind == .removeOperator ? "merchantTeam.danger.removeConfirm" : "merchantTeam.danger.revokeConfirm"
    }

    /// The reviewed mutation with the fixed reason, or nil when the row has no usable id or version (MP returns early).
    func mutation() -> MerchantBusinessMutation? {
        guard let raw = Int(row.id), let version = try? row.fields.mbInt("version") else { return nil }
        switch kind {
        case .removeOperator:
            guard let id = try? MerchantOperatorID(raw) else { return nil }
            return .removeOperator(id: id, version: version, reason: Self.removeOperatorReason)
        case .revokeInvite:
            guard let id = try? MerchantOperatorInviteID(raw) else { return nil }
            return .revokeInvite(id: id, version: version, reason: Self.revokeInviteReason)
        }
    }
}

/// The destructive dialog: title, the MP consequence lines as the message, 移除成员 / 撤销邀请 and 取消.
struct MerchantTeamDangerConfirmModifier: ViewModifier {
    @Binding var pending: MerchantTeamDangerConfirm?
    let onConfirm: (MerchantBusinessMutation) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(pending?.titleKey ?? "", isPresented: Binding(
            get: { pending != nil }, set: { if !$0 { pending = nil } }
        ), titleVisibility: .visible, presenting: pending) { danger in
            Button(danger.confirmKey, role: .destructive) {
                pending = nil
                if let mutation = danger.mutation() { onConfirm(mutation) }
            }
            .accessibilityIdentifier("merchant.team.danger.confirm")
            Button("action.cancel", role: .cancel) { pending = nil }
        } message: { danger in
            Text(danger.messageKey)
        }
    }
}
