import Foundation

/// Message-center coop-invite strip (mini-program `subpackageB/pages/im/list`, `utils/coop-invite-view.js`).
/// Pure projection over the existing `CooperationInvites` contract: no network, no writes.
public struct IMCoopInviteCard: Equatable, Identifiable {
    public enum Tone: Equatable { case pending, accepted, rejected, muted }
    public let key: CooperationInviteKey
    public let status: Int?
    public let tone: Tone
    public let partnerName: String?
    public let topicName: String?
    public let message: String?
    public let coverURL: String?
    public let terms: CooperationInvitePresentation.Terms
    public let awaitsMyAnswer: Bool
    public var id: String { "\(key.direction.rawValue).\(key.id)" }

    public init(invite: CooperationInvite, direction: CooperationDirection) {
        let presentation = CooperationInvitePresentation(invite: invite, direction: direction)
        key = CooperationInviteKey(id: invite.id, direction: direction)
        status = invite.status
        switch invite.status {
        case 0?: tone = .pending
        case 1?: tone = .accepted
        case 2?: tone = .rejected
        default: tone = .muted
        }
        partnerName = Self.clean(invite.partner?.name)
        topicName = Self.clean(invite.topicName) ?? invite.topicId.map { "#\($0)" }
        message = Self.clean(invite.message)
        coverURL = invite.coverURL
        terms = presentation.terms
        awaitsMyAnswer = direction == .received && invite.status == 0 && !invite.legacyReadonly
    }

    private static func clean(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Cards for one inbox tab: invitations that need an answer first, otherwise the server order is kept.
    public static func cards(_ invites: CooperationInvites, direction: CooperationDirection) -> [IMCoopInviteCard] {
        let all = invites.rows(direction).map { IMCoopInviteCard(invite: $0, direction: direction) }
        return all.filter(\.awaitsMyAnswer) + all.filter { !$0.awaitsMyAnswer }
    }

    /// Mini-program terms line: 分成型 / 固定型 / 引流型. Missing numbers stay "?" and are never turned into 0.
    public func termsLine(chinese: Bool) -> String? {
        func number(_ value: Double?) -> String {
            guard let value else { return "?" }
            return value == value.rounded() ? String(Int(value)) : String(value)
        }
        switch terms {
        case .share(let rate): return chinese ? "分成型 · 票款 \(number(rate))%" : "Revenue share · \(number(rate))% of tickets"
        case .fixed(let fee): return chinese ? "固定型 · ¥\(number(fee)) / 核销人头" : "Fixed fee · ¥\(number(fee)) per check-in"
        case .traffic: return chinese ? "引流型 · 无分成" : "Referral · no revenue share"
        case .unknown: return nil
        }
    }

    public func statusText(chinese: Bool) -> String {
        switch status {
        case 0?: return chinese ? "待确认" : "Pending"
        case 1?: return chinese ? "已接受" : "Accepted"
        case 2?: return chinese ? "已拒绝" : "Declined"
        case 3?: return chinese ? "已取消" : "Canceled"
        case 4?: return chinese ? "已顶替" : "Replaced"
        case 5?: return chinese ? "已过期" : "Expired"
        default: return chinese ? "状态未知" : "Unknown"
        }
    }
}
