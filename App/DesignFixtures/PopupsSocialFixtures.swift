#if DEBUG
import SwiftUI

/// Debug-only synthetic preview fixtures for social / community / club / IM / channel / team pop-ups.
/// Launchable via `--design-fixture popups-<case>` (e.g. `popups-team-leave`, `popups-club-refund`, `popups-social-ax5`).
enum PopupsSocialFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "popups-team-leave":
            return wrap(PopupsTeamConfirmFixture(isDisband: false))
        case "popups-team-disband":
            return wrap(PopupsTeamConfirmFixture(isDisband: true))
        case "popups-im-more":
            return wrap(PopupsIMMoreFixture())
        case "popups-im-safety":
            return wrap(PopupsIMSafetyFixture())
        case "popups-official-pause":
            return wrap(PopupsOfficialPauseFixture())
        case "popups-square-actions":
            return wrap(PopupsSquareActionsFixture())
        case "popups-favorites-unlike":
            return wrap(PopupsFavoritesUnlikeFixture())
        case "popups-club-refund":
            return wrap(PopupsClubRefundFixture())
        case "popups-club-badge":
            return wrap(PopupsClubBadgeGrantFixture())
        case "popups-club-channel-report":
            return wrap(PopupsClubChannelReportFixture())
        case "popups-club-cancel-event":
            return wrap(PopupsClubCancelEventFixture())
        case "popups-social-ax5":
            return AnyView(PopupsTeamConfirmFixture(isDisband: true)
                .themeDomain(.player)
                .environment(\.dynamicTypeSize, .accessibility5))
        default:
            return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player))
    }
}

@MainActor private struct PopupsTeamConfirmFixture: View {
    let isDisband: Bool
    @Environment(\.locale) private var locale
    @State private var toastMessage: LocalizedStringKey?

    var body: some View {
        ZStack {
            CYColor.bgPage.ignoresSafeArea()
            VStack {
                if isDisband {
                    CYModal(
                        title: appLocalized("team.disband", locale: locale),
                        message: appLocalized("team.disband.consequence", locale: locale),
                        consequences: [
                            CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: appLocalized("team.consequence.disband.1", locale: locale)),
                            CYConfirmConsequence(systemImage: "bubble.left.and.bubble.right.slash", text: appLocalized("team.consequence.disband.2", locale: locale)),
                            CYConfirmConsequence(systemImage: "ticket", text: appLocalized("team.consequence.disband.3", locale: locale))
                        ],
                        cancelTitle: appLocalized("team.cancel", locale: locale),
                        confirmTitle: appLocalized("team.disband", locale: locale),
                        lighterAlternativeTitle: appLocalized("team.leaveInstead", locale: locale),
                        isDestructive: true,
                        onCancel: {},
                        onLighterAlternative: { toastMessage = "team.page.leaveAndTransfer" },
                        onConfirm: {}
                    )
                } else {
                    CYConfirmSheet(
                        title: appLocalized("team.leave", locale: locale),
                        message: appLocalized("team.leave.consequence", locale: locale),
                        confirmTitle: appLocalized("team.leave", locale: locale),
                        cancelTitle: appLocalized("team.cancel", locale: locale),
                        isDestructive: true,
                        consequences: [
                            CYConfirmConsequence(systemImage: "person.badge.minus", text: appLocalized("team.consequence.leave.1", locale: locale)),
                            CYConfirmConsequence(systemImage: "ticket", text: appLocalized("team.consequence.leave.2", locale: locale)),
                            CYConfirmConsequence(systemImage: "arrow.uturn.backward", text: appLocalized("team.consequence.leave.3", locale: locale))
                        ],
                        onCancel: { toastMessage = "team.invite.copied" },
                        onConfirm: {}
                    )
                }
            }
        }
        .cyToast($toastMessage, tone: .info)
    }
}

@MainActor private struct PopupsIMMoreFixture: View {
    @Environment(\.locale) private var locale
    @State private var selected: String?

    var body: some View {
        CYOptionSheet(
            title: appLocalized("im.chat.more", locale: locale),
            items: [
                CYOptionSheetItem(id: "report", title: appLocalized("im.chat.more.report", locale: locale), systemImage: "exclamationmark.triangle"),
                CYOptionSheetItem(id: "block", title: appLocalized("im.chat.more.block", locale: locale), systemImage: "hand.raised", isDanger: true),
                CYOptionSheetItem(id: "hide", title: appLocalized("im.chat.more.hide", locale: locale), systemImage: "eye.slash", isDanger: true)
            ],
            selectedID: selected,
            onSelect: { selected = $0 },
            onClose: {}
        )
    }
}

@MainActor private struct PopupsIMSafetyFixture: View {
    @Environment(\.locale) private var locale

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("im.safety.hide.title", locale: locale),
            message: appLocalized("im.safety.hide.content", locale: locale),
            confirmTitle: appLocalized("im.safety.hide.confirm", locale: locale),
            cancelTitle: appLocalized("action.cancel", locale: locale),
            isDestructive: true,
            consequences: [
                CYConfirmConsequence(systemImage: "eye.slash", text: appLocalized("im.safety.hide.c1", locale: locale)),
                CYConfirmConsequence(systemImage: "tray", text: appLocalized("im.safety.hide.c2", locale: locale))
            ],
            onCancel: {},
            onConfirm: {}
        )
    }
}

@MainActor private struct PopupsOfficialPauseFixture: View {
    @Environment(\.locale) private var locale

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("official.organizer.pause.title", locale: locale),
            message: appLocalized("official.organizer.pause.body", locale: locale),
            confirmTitle: appLocalized("official.organizer.pause.confirm", locale: locale),
            cancelTitle: appLocalized("action.cancel", locale: locale),
            isDestructive: true,
            consequences: [
                CYConfirmConsequence(systemImage: "person.crop.circle.badge.xmark", text: appLocalized("official.organizer.pause.c1", locale: locale)),
                CYConfirmConsequence(systemImage: "megaphone", text: appLocalized("official.organizer.pause.c2", locale: locale)),
                CYConfirmConsequence(systemImage: "clock", text: appLocalized("official.organizer.pause.c3", locale: locale))
            ],
            onCancel: {},
            onConfirm: {}
        )
    }
}

@MainActor private struct PopupsSquareActionsFixture: View {
    var body: some View {
        SquareCloudPostActions(
            owner: true,
            bookmarkable: true,
            bookmarked: false,
            summary: "Saturday evening city walk route around West Bund",
            onEdit: {},
            onBookmark: {},
            onDelete: {},
            onReport: {},
            onClose: {}
        )
    }
}

@MainActor private struct PopupsFavoritesUnlikeFixture: View {
    @Environment(\.locale) private var locale
    @State private var toastMessage: LocalizedStringKey? = "topic.unlike.toast"

    var body: some View {
        CYConfirmSheet(
            title: String(localized: LocalizedStringResource("member.unlike.confirmTitle", table: "MemberProfile", locale: locale)),
            message: String(localized: LocalizedStringResource("member.unlike.confirmMessage", table: "MemberProfile", locale: locale)),
            confirmTitle: String(localized: LocalizedStringResource("member.unlike.confirm", table: "MemberProfile", locale: locale)),
            cancelTitle: String(localized: LocalizedStringResource("member.unlike.cancel", table: "MemberProfile", locale: locale)),
            isDestructive: true,
            onCancel: {},
            onConfirm: { toastMessage = "topic.unlike.toast" }
        )
        .cyToast($toastMessage, tone: .info)
    }
}

@MainActor private struct PopupsClubRefundFixture: View {
    @Environment(\.locale) private var locale

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("club.refund.question", locale: locale),
            message: appLocalized("club.refund.scopeWarning", locale: locale),
            confirmTitle: appLocalized("club.refund.confirm", locale: locale),
            cancelTitle: appLocalized("club.refund.cancel", locale: locale),
            isDestructive: true,
            consequences: [
                CYConfirmConsequence(systemImage: "arrow.uturn.backward.circle", text: appLocalized("club.refund.consequence1", locale: locale)),
                CYConfirmConsequence(systemImage: "ticket", text: appLocalized("club.refund.consequence2", locale: locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: appLocalized("club.refund.consequence3", locale: locale))
            ],
            onCancel: {},
            onConfirm: {}
        )
    }
}

@MainActor private struct PopupsClubBadgeGrantFixture: View {
    @Environment(\.locale) private var locale

    var body: some View {
        CYConfirmSheet(
            title: String(localized: LocalizedStringResource("confirmGrant", table: "ClubBadge", locale: locale)),
            message: String(localized: LocalizedStringResource("confirmGrantDetail", table: "ClubBadge", locale: locale)),
            confirmTitle: String(localized: LocalizedStringResource("grant", table: "ClubBadge", locale: locale)),
            cancelTitle: String(localized: LocalizedStringResource("cancel", table: "ClubBadge", locale: locale)),
            isDestructive: false,
            consequences: [
                CYConfirmConsequence(systemImage: "person.badge.plus", text: String(localized: LocalizedStringResource("confirmGrantConsequence1", table: "ClubBadge", locale: locale))),
                CYConfirmConsequence(systemImage: "medal", text: String(localized: LocalizedStringResource("confirmGrantConsequence2", table: "ClubBadge", locale: locale))),
                CYConfirmConsequence(systemImage: "exclamationmark.circle", text: String(localized: LocalizedStringResource("confirmGrantConsequence3", table: "ClubBadge", locale: locale)))
            ],
            onCancel: {},
            onConfirm: {}
        )
    }
}

@MainActor private struct PopupsClubChannelReportFixture: View {
    @Environment(\.locale) private var locale

    var body: some View {
        CYOptionSheet(
            title: appLocalized("club.channel.report.title", locale: locale),
            items: [
                CYOptionSheetItem(id: "SPAM_SCAM", title: appLocalized("club.channel.report.spam", locale: locale), systemImage: "exclamationmark.bubble", isDanger: true),
                CYOptionSheetItem(id: "HARASSMENT", title: appLocalized("club.channel.report.harassment", locale: locale), systemImage: "hand.raised", isDanger: true),
                CYOptionSheetItem(id: "OBJECT_CONTENT", title: appLocalized("club.channel.report.illegal", locale: locale), systemImage: "exclamationmark.triangle", isDanger: true)
            ],
            onSelect: { _ in },
            onClose: {}
        )
    }
}

@MainActor private struct PopupsClubCancelEventFixture: View {
    @Environment(\.locale) private var locale

    var body: some View {
        CYConfirmSheet(
            title: String(localized: LocalizedStringResource("clubOpsEvent.cancel.confirmTitle", table: "ClubOpsEvent", locale: locale)),
            message: String(localized: LocalizedStringResource("clubOpsEvent.cancel.confirmBody", table: "ClubOpsEvent", locale: locale)),
            confirmTitle: String(localized: LocalizedStringResource("clubOpsEvent.cancel.confirmAction", table: "ClubOpsEvent", locale: locale)),
            cancelTitle: String(localized: LocalizedStringResource("clubOpsEvent.cancel.keep", table: "ClubOpsEvent", locale: locale)),
            isDestructive: true,
            consequences: [
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: String(localized: LocalizedStringResource("clubOpsEvent.cancel.consequence1", table: "ClubOpsEvent", locale: locale))),
                CYConfirmConsequence(systemImage: "person.2.slash", text: String(localized: LocalizedStringResource("clubOpsEvent.cancel.consequence2", table: "ClubOpsEvent", locale: locale)))
            ],
            onCancel: {},
            onConfirm: {}
        )
    }
}
#endif
