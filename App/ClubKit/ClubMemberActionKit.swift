import SwiftUI

// MC-20 / MC-21 / MC-33 · organiser actions are a "⋯" pull-down per row (举报 · 设为管理员 ·
// 临时封禁 · 移除, destructive last and red), and anything that removes people goes through a
// consequence sheet. Page-level 退出 / 举报 are red rows in their own last group.

enum ClubMemberAction: String, CaseIterable, Identifiable, Sendable {
    case report, makeAdmin, tempBan, remove
    var id: String { rawValue }

    var isDestructive: Bool { self == .remove }
    /// Heavy actions that need the consequence sheet before they run.
    var needsConsequenceSheet: Bool { self == .remove || self == .tempBan }

    var symbol: String {
        switch self {
        case .report: return "flag"
        case .makeAdmin: return "person.badge.shield.checkmark"
        case .tempBan: return "clock.badge.xmark"
        case .remove: return "person.crop.circle.badge.minus"
        }
    }

    /// The menu order: what a viewer may do, with the destructive action always last.
    /// CLB-r7-A-07 (MP detail wxml:779, js:2451-2454): 临时封禁 needs `canGovernMembers` (owner or co-owner with
    /// club:member:manage); a legacy administrator is refused by the server, so the row is not offered.
    static func menu(canGovern: Bool, targetIsOwner: Bool, targetIsAdmin: Bool, canTempBan: Bool = true) -> [ClubMemberAction] {
        var actions: [ClubMemberAction] = [.report]
        guard canGovern, !targetIsOwner else { return actions }
        if !targetIsAdmin { actions.append(.makeAdmin) }
        if canTempBan { actions.append(.tempBan) }
        actions.append(.remove)
        return actions
    }
}

/// The "⋯" trailing element of a member, comment or post row (44 pt target, labelled for VoiceOver).
struct ClubMemberActionMenu: View {
    let actions: [ClubMemberAction]
    var memberName: String?
    var reportIdentifier: String?
    let perform: (ClubMemberAction) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Menu {
            ForEach(actions.filter { !$0.isDestructive }) { action in
                Button { perform(action) } label: {
                    Label { Text(verbatim: clubR1("member.action.\(action.rawValue)", locale)) } icon: { Image(systemName: action.symbol) }
                }
                .accessibilityIdentifier(action == .report ? (reportIdentifier ?? "club.member.action.report") : "club.member.action.\(action.rawValue)")
            }
            let destructive = actions.filter(\.isDestructive)
            if !destructive.isEmpty {
                Divider()
                ForEach(destructive) { action in
                    Button(role: .destructive) { perform(action) } label: {
                        Label { Text(verbatim: clubR1("member.action.\(action.rawValue)", locale)) } icon: { Image(systemName: action.symbol) }
                    }
                    .accessibilityIdentifier("club.member.action.\(action.rawValue)")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .cyText(.body, weight: .semibold)
                .foregroundStyle(palette.textSecondary)
                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel(Text(verbatim: memberName.map { String(format: clubR1("member.menuNamed", locale), $0) } ?? clubR1("common.more", locale)))
    }
}

/// Heavy confirmation (MC-33): fit sheet, title on one line, the object under it, consequence rows,
/// the softer alternative as the secondary, the destructive action as a red pill at the bottom.
struct ClubConsequenceSheet: View {
    let title: String
    var objectName: String?
    let consequences: [CYConfirmConsequence]
    let confirmTitle: String
    var alternativeTitle: String?
    var onAlternative: (() -> Void)?
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @State private var presented = 0

    var body: some View {
        CYResizableSheet(kind: .pickerLong, title: Text(verbatim: title)) {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            if let objectName, !objectName.isEmpty {
                Text(verbatim: objectName)
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
            }
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                ForEach(consequences) { item in
                    HStack(alignment: .top, spacing: CYSpacing.sm) {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(verbatim: item.text)
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(CYSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgElevated))
            VStack(spacing: CYSpacing.md) {
                if let alternativeTitle, let onAlternative {
                    Button {
                        dismiss()
                        onAlternative()
                    } label: { Text(verbatim: alternativeTitle) }
                    .buttonStyle(CYPillButtonStyle(style: .secondary))
                }
                Button {
                    dismiss()
                    onConfirm()
                } label: { Text(verbatim: confirmTitle) }
                .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true, isPill: true))
                .accessibilityIdentifier("club.consequence.confirm")
            }
        }
        }
        .sensoryFeedback(.warning, trigger: presented)
        .onAppear { presented += 1 }
    }
}

extension ClubConsequenceSheet {
    /// The consequence sheet for a member action that removes or restricts someone.
    static func member(_ action: ClubMemberAction, name: String?, locale: Locale, onConfirm: @escaping () -> Void) -> ClubConsequenceSheet {
        let key = action.rawValue
        return ClubConsequenceSheet(
            title: clubR1("member.consequence.\(key).title", locale),
            objectName: name,
            consequences: [
                CYConfirmConsequence(systemImage: action.symbol, text: clubR1("member.consequence.\(key).line1", locale)),
                CYConfirmConsequence(systemImage: "bell.slash", text: clubR1("member.consequence.\(key).line2", locale)),
            ],
            confirmTitle: clubR1("member.action.\(key)", locale),
            onConfirm: onConfirm)
    }
}

/// 退出俱乐部 and 举报俱乐部 as two quiet red rows in their own last group at the end of 概览.
struct ClubPageEndActions: View {
    var canLeave: Bool
    let onLeave: () -> Void
    var onReport: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            if canLeave {
                row(key: "club.leave", symbol: "rectangle.portrait.and.arrow.right", identifier: "club.end.leave", action: onLeave)
                if onReport != nil { Divider().padding(.leading, CYSpacing.lg) }
            }
            if let onReport {
                row(key: "club.report", symbol: "flag", identifier: "club.end.report", action: onReport)
            }
        }
        .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgElevated))
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
    }

    private func row(key: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                Image(systemName: symbol).frame(width: 24).accessibilityHidden(true)
                Text(verbatim: clubR1(key, locale))
                Spacer(minLength: 0)
            }
            .cyText(.bodyMedium)
            .foregroundStyle(palette.danger)
            .padding(.horizontal, CYSpacing.lg)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(CYListRowButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}

/// MC-29 / MR-07 / MR-38: withdrawal is a named customer-service hand-off with the next step and reply time.
struct ClubWithdrawalHandOffNote: View {
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .foregroundStyle(palette.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: clubR1("funds.handOff.title", locale))
                    .cyText(.bodyMedium)
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: clubR1("funds.handOff.line", locale))
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("club.withdraw.handOff")
    }
}
