import SwiftUI

/// Bilingual helpers for member/settings/wallet/orders/tickets/coupons popups.
/// zh-Hans copy comes verbatim from the mini-program (`chengyinhub-xcx`).
enum MemberPopupCopy {
    static func text(_ zh: String, _ en: String, locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }

    static func table(_ key: String.LocalizationValue, table: String, locale: Locale) -> String {
        String(localized: LocalizedStringResource(key, table: table, locale: locale))
    }
}

/// Sign-out confirmation (`account.logout`, `pages/shezhi/shezhi.js:317` + `utils/danger-actions.js:1179`).
/// Design P1 G-047: the system action sheet (Settings › Sign Out), not a custom sheet. `presenting` carries the
/// account snapshot captured when the row was tapped, so the confirm acts on exactly that sign-in.
struct MemberSignOutConfirmation<Expected>: ViewModifier {
    let isPresented: Binding<Bool>
    let expected: Expected?
    let message: LocalizedStringKey
    let confirmIdentifier: String
    let onConfirm: (Expected) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(Text("auth.signOutConfirm"), isPresented: isPresented,
                                   titleVisibility: .visible, presenting: expected) { value in
            Button(role: .destructive) { onConfirm(value) } label: { Text("auth.signOut") }
                .accessibilityIdentifier(confirmIdentifier)
            Button(role: .cancel) {} label: { Text("action.cancel") }
                .accessibilityIdentifier(confirmIdentifier.replacingOccurrences(of: ".confirm", with: ".cancel"))
        } message: { _ in
            Text(message)
        }
    }
}

extension View {
    /// Presents the system sign-out confirmation while `isPresented` is true and `expected` is non-nil.
    func memberSignOutConfirmation<Expected>(isPresented: Binding<Bool>, presenting expected: Expected?,
                                             message: LocalizedStringKey = "memberPopup.signOut.message",
                                             confirmIdentifier: String,
                                             onConfirm: @escaping (Expected) -> Void) -> some View {
        modifier(MemberSignOutConfirmation(isPresented: isPresented, expected: expected, message: message,
                                           confirmIdentifier: confirmIdentifier, onConfirm: onConfirm))
    }
}

/// Cancel account deregistration confirmation (`account.deregister.cancel`, `utils/danger-actions.js:1191`).
struct MemberDeregistrationCancelConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: MemberPopupCopy.table("compliance.cancelReview", table: "AccountCompliance", locale: locale),
            message: appLocalized("memberPopup.deregistrationCancelConfirmSheet.1", locale: locale),
            confirmTitle: MemberPopupCopy.table("compliance.cancelApplication", table: "AccountCompliance", locale: locale),
            isDestructive: true,
            confirmIdentifier: "compliance.cancel.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "checkmark.circle",
                    text: appLocalized("memberPopup.deregistrationCancelConfirmSheet.2", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "arrow.uturn.left",
                    text: appLocalized("memberPopup.deregistrationCancelConfirmSheet.3", locale: locale))
            ],
            onConfirm: onConfirm
        )
    }
}

/// Submit account deregistration confirmation (`account.deregister.submit`, `utils/deregister-flow.js`).
struct MemberDeregistrationSubmitConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("compliance.confirmSheet.title", locale: locale),
            message: appLocalized("compliance.confirmSheet.message", locale: locale),
            confirmTitle: appLocalized("compliance.confirmSheet.action", locale: locale),
            isDestructive: true,
            confirmIdentifier: "compliance.submit.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "hourglass",
                    text: appLocalized("memberPopup.deregistrationSubmitConfirmSheet.1", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: appLocalized("memberPopup.deregistrationSubmitConfirmSheet.2", locale: locale))
            ],
            onConfirm: onConfirm
        )
    }
}

/// Marketing channel opt-in/out confirmation (`pages/shezhi/marketing/index.wxml`).
struct MemberMarketingConsentConfirmSheet: View {
    @Environment(\.locale) private var locale
    let merchantName: String?
    let channelKey: String.LocalizationValue
    let optedIn: Bool
    let onConfirm: () -> Void

    var body: some View {
        let name = merchantName ?? appLocalized("compliance.merchant", locale: locale)
        let channel = appLocalized(channelKey, locale: locale)
        MemberConfirmSheet(
            title: MemberPopupCopy.table("compliance.marketing.review", table: "MarketingConsentOriginalPresentation", locale: locale),
            message: "\(name) · \(channel)",
            confirmTitle: MemberPopupCopy.table(
                optedIn ? "compliance.marketing.confirmOptIn" : "compliance.marketing.confirmOptOut",
                table: "MarketingConsentOriginalPresentation",
                locale: locale),
            isDestructive: !optedIn,
            confirmIdentifier: "compliance.marketing.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Favorites & recommendations explanation sheet (`member.favorites.recommendNote`).
struct MemberFavoritesRecommendNoteSheet: View {
    @Environment(\.locale) private var locale
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("member.favorites.recommendNote.body", tableName: "MemberProfile")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: MemberPopupCopy.table("member.favorites.recommendNote.title", table: "MemberProfile", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { onDismiss() } label: {
                        Text("member.favorites.recommendNote.dismiss", tableName: "MemberProfile")
                    }
                    .accessibilityIdentifier("member.favorites.recommendNote.dismiss")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Confirm unlike in liked topics (`subpackageMember/components/cy/scene-route-content/index.js:350`).
struct MemberTopicUnlikeConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: MemberPopupCopy.table("member.unlike.confirmTitle", table: "MemberProfile", locale: locale),
            message: MemberPopupCopy.table("member.unlike.confirmMessage", table: "MemberProfile", locale: locale),
            confirmTitle: MemberPopupCopy.table("member.unlike.confirm", table: "MemberProfile", locale: locale),
            isDestructive: true,
            confirmIdentifier: "member.unlike.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Abandon unsubmitted bank withdrawal details (`subpackageA/pages/assetcenter/earnings/index.js:294`).
struct MemberBankWithdrawalDiscardConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("memberPopup.bankWithdrawalDiscardConfirmSheet.1", locale: locale),
            message: appLocalized("memberPopup.bankWithdrawalDiscardConfirmSheet.2", locale: locale),
            confirmTitle: appLocalized("bank.withdrawal.discard", locale: locale),
            isDestructive: true,
            confirmIdentifier: "bank.withdrawal.discard.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Confirm merchant swap on free-explore bundle (`subpackageMember/free-explore/index.js:265`).
struct MemberBundleSwapConfirmSheet: View {
    @Environment(\.locale) private var locale
    let merchantName: String
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("memberPopup.bundleSwapConfirmSheet.1", locale: locale),
            message: String(format: appLocalized("memberPopup.bundleSwapConfirmSheet.2", locale: locale), locale: locale, merchantName),
            confirmTitle: appLocalized("memberPopup.bundleSwapConfirmSheet.3", locale: locale),
            isDestructive: false,
            confirmIdentifier: "freeExplore.swap.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Confirm submitting report appeal (`subpackageMember/report-detail/index.wxml:55`).
struct MemberReportAppealConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("memberPopup.reportAppealConfirmSheet.1", locale: locale),
            message: appLocalized("memberPopup.reportAppealConfirmSheet.2", locale: locale),
            confirmTitle: appLocalized("memberPopup.reportAppealConfirmSheet.3", locale: locale),
            isDestructive: false,
            confirmIdentifier: "report.appeal.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Confirm showing short-lived dynamic coupon code (`CouponCodeView`).
struct MemberCouponShowConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("couponCode.review", locale: locale),
            message: appLocalized("couponCode.review.detail", locale: locale),
            confirmTitle: appLocalized("couponCode.show", locale: locale),
            isDestructive: false,
            confirmIdentifier: "couponCode.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Discard coupon draft edit confirmation (`subpackageMember/couponInfo/couponInfo.js:208`).
struct MemberCouponDiscardConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("couponManagement.discardTitle", locale: locale),
            message: appLocalized("memberPopup.couponDiscardConfirmSheet.1", locale: locale),
            confirmTitle: appLocalized("couponManagement.discard", locale: locale),
            isDestructive: true,
            confirmIdentifier: "couponManagement.discard.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Stop issuing merchant coupon modal (`merchant.coupon.stop`, `subpackageMember/coupon/coupon.js:232`).
struct MemberCouponStopConfirmModal: View {
    @Environment(\.locale) private var locale
    let couponName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        MemberConfirmAlert(
            title: String(format: appLocalized("memberPopup.couponStopConfirmModal.1", locale: locale), locale: locale, couponName),
            message: appLocalized("memberPopup.couponStopConfirmModal.2", locale: locale),
            consequences: [
                CYConfirmConsequence(
                    systemImage: "ticket",
                    text: appLocalized("memberPopup.couponStopConfirmModal.3", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: appLocalized("memberPopup.couponStopConfirmModal.4", locale: locale))
            ],
            cancelTitle: appLocalized("action.cancel", locale: locale),
            confirmTitle: appLocalized("memberPopup.couponStopConfirmModal.5", locale: locale),
            isDestructive: true,
            confirmIdentifier: "couponManagement.stopModal.confirm",
            cancelIdentifier: "couponManagement" + ".stopModal.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Withdraw invoice application confirmation (`subpackageMember/invoice/base.js:162`).
struct MemberInvoiceWithdrawConfirmSheet: View {
    @Environment(\.locale) private var locale
    let confirmIdentifier: String
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: MemberPopupCopy.table("withdrawConfirm", table: "InvoiceLaunchUI", locale: locale),
            message: appLocalized("memberPopup.invoiceWithdrawConfirmSheet.1", locale: locale),
            confirmTitle: MemberPopupCopy.table("withdraw", table: "InvoiceLaunchUI", locale: locale),
            isDestructive: true,
            confirmIdentifier: confirmIdentifier,
            onConfirm: onConfirm
        )
    }
}

/// Delete invoice title confirmation (`subpackageMember/invoice-titles/index.js:49`).
struct MemberInvoiceTitleDeleteConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: MemberPopupCopy.table("deleteConfirm", table: "InvoiceLaunchUI", locale: locale),
            message: appLocalized("memberPopup.invoiceTitleDeleteConfirmSheet.1", locale: locale),
            confirmTitle: MemberPopupCopy.table("delete", table: "InvoiceLaunchUI", locale: locale),
            isDestructive: true,
            confirmIdentifier: "invoice.title.delete.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Delete all NPC chat logs confirmation (`ai.npc.chatData.delete`, `utils/danger-actions.js:789`).
struct MemberNPCLogDeleteConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: MemberPopupCopy.table("npcLogDelete.confirmTitle", table: "NPCChatLogDeletion", locale: locale),
            message: MemberPopupCopy.table("npcLogDelete.confirmMessage", table: "NPCChatLogDeletion", locale: locale),
            confirmTitle: MemberPopupCopy.table("npcLogDelete.confirm", table: "NPCChatLogDeletion", locale: locale),
            isDestructive: true,
            confirmIdentifier: "npcLogDelete.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "trash",
                    text: appLocalized("memberPopup.nPCLogDeleteConfirmSheet.1", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "info.circle",
                    text: appLocalized("memberPopup.nPCLogDeleteConfirmSheet.2", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: appLocalized("memberPopup.nPCLogDeleteConfirmSheet.3", locale: locale))
            ],
            onConfirm: onConfirm
        )
    }
}

/// Orient-score action confirmation (`subpackageMember/orient-score/index.js:186,217,284`).
struct MemberOrientScoreConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("orientScore.review.confirmTitle", locale: locale),
            message: appLocalized("memberPopup.orientScoreConfirmSheet.1", locale: locale),
            confirmTitle: appLocalized("orientScore.review.send", locale: locale),
            isDestructive: false,
            confirmIdentifier: "orientScore.review.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Profile editor & draft discard confirmations (`ProfileEditView`, `ProfileDraftReviewSection`, `ProfileAvatarDraftSection`).
struct MemberProfileDiscardConfirmSheet: View {
    enum Kind { case exitDiscard, reloadDiscard, reviewRestore, avatarDiscard }

    @Environment(\.locale) private var locale
    let kind: Kind
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void

    init(kind: Kind, onCancel: (() -> Void)? = nil, onConfirm: @escaping () -> Void) {
        self.kind = kind
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        switch kind {
        case .exitDiscard:
            MemberConfirmSheet(
                title: appLocalized("profile.exitDiscard.title", locale: locale),
                message: appLocalized("profile.exitDiscard.message", locale: locale),
                confirmTitle: appLocalized("profile.exitDiscard.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.exitDiscard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .reloadDiscard:
            MemberConfirmSheet(
                title: appLocalized("profile.reloadDiscard.title", locale: locale),
                message: appLocalized("profile.reloadDiscard.message", locale: locale),
                confirmTitle: appLocalized("profile.reloadDiscard.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.reloadDiscard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .reviewRestore:
            MemberConfirmSheet(
                title: appLocalized("profile.reviewRestore.title", locale: locale),
                message: appLocalized("profile.reviewRestore.message", locale: locale),
                confirmTitle: appLocalized("profile.reviewRestore.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.reviewRestore.confirm",
                cancelIdentifier: "profile" + ".reviewRestore.cancel",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .avatarDiscard:
            MemberConfirmSheet(
                title: appLocalized("profile.avatar.discardTitle", locale: locale),
                message: appLocalized("memberPopup.profileDiscardConfirmSheet.1", locale: locale),
                confirmTitle: appLocalized("profile.avatar.discard", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.avatar.discard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
    }
}

/// Delete participant confirmation (`address.delete`, `utils/danger-actions.js:913`).
struct MemberParticipantDeleteConfirmSheet: View {
    @Environment(\.locale) private var locale
    let summary: String
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void

    init(summary: String, onCancel: (() -> Void)? = nil, onConfirm: @escaping () -> Void) {
        self.summary = summary
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        let bodyText = summary.isEmpty
            ? appLocalized("participant.list.deleteBody", locale: locale)
            : summary + "\n\n" + appLocalized("participant.list.deleteBody", locale: locale)
        MemberConfirmSheet(
            title: appLocalized("participant.list.deleteTitle", locale: locale),
            message: bodyText,
            confirmTitle: appLocalized("participant.list.deleteConfirm", locale: locale),
            isDestructive: true,
            confirmIdentifier: "participant.list.delete.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: appLocalized("participant.list.deleteIrreversible", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "calendar",
                    text: appLocalized("participant.list.deleteKeepsRegistration", locale: locale))
            ],
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Submit complaint confirmation (`subpackageMember/complaint/index.js:304`).
struct MemberComplaintSubmitConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("profile.complaint.submit.confirmTitle", locale: locale),
            message: appLocalized("profile.complaint.submit.confirmBody", locale: locale),
            confirmTitle: appLocalized("profile.complaint.submit.action", locale: locale),
            isDestructive: false,
            confirmIdentifier: "profile.complaint.submit.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Discard confirmation when leaving a dirty settings screen (`pages/shezhi/shezhi.wxml:91`).
struct MemberSettingsSceneDiscardModal: View {
    @Environment(\.locale) private var locale
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmAlert(
            title: appLocalized("memberPopup.settingsSceneDiscardModal.1", locale: locale),
            message: appLocalized("memberPopup.settingsSceneDiscardModal.2", locale: locale),
            cancelTitle: appLocalized("memberPopup.settingsSceneDiscardModal.3", locale: locale),
            confirmTitle: appLocalized("memberPopup.settingsSceneDiscardModal.4", locale: locale),
            isDestructive: true,
            confirmIdentifier: "memberPopup.sceneDiscard.confirm",
            cancelIdentifier: "memberPopup.sceneDiscard.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Option sheet choosing among multiple owned clubs from Settings (`pages/shezhi/shezhi.js:123`).
struct MemberSettingsClubPickerSheet: View {
    @Environment(\.locale) private var locale
    let clubs: [ClubRecord]
    let onSelect: (ClubRecord) -> Void
    let onClose: () -> Void

    var body: some View {
        MemberOptionSheet(
            title: appLocalized("memberPopup.settingsClubPickerSheet.1", locale: locale),
            items: clubs.map { club in
                CYOptionSheetItem(
                    id: club.id,
                    title: club.name,
                    subtitle: club.city,
                    systemImage: "flag"
                )
            },
            onSelect: { selectedID in
                if let match = clubs.first(where: { $0.id == selectedID }) {
                    onSelect(match)
                }
            },
            onClose: onClose
        )
    }
}

/// Option sheet for AI chat records (`subpackageMember/components/cy/ai-chat-records/index.wxml:1`).
struct MemberAIChatRecordsOptionSheet: View {
    @Environment(\.locale) private var locale
    let onSelect: (NPCChatRecordsOption) -> Void
    let onClose: () -> Void

    var body: some View {
        MemberOptionSheet(
            title: appLocalized("memberPopup.aIChatRecordsOptionSheet.1", locale: locale),
            items: [
                CYOptionSheetItem(
                    id: .view,
                    title: appLocalized("memberPopup.aIChatRecordsOptionSheet.2", locale: locale),
                    systemImage: "doc.text.magnifyingglass"
                ),
                CYOptionSheetItem(
                    id: .export,
                    title: appLocalized("memberPopup.aIChatRecordsOptionSheet.3", locale: locale),
                    systemImage: "square.and.arrow.up"
                ),
                CYOptionSheetItem(
                    id: .clear,
                    title: appLocalized("memberPopup.aIChatRecordsOptionSheet.4", locale: locale),
                    systemImage: "trash",
                    isDanger: true
                ),
            ],
            onSelect: onSelect,
            onClose: onClose
        )
    }
}

/// Full-screen / large detent DS sheet hosting merchant NPC chat plus export and clear controls
/// (`subpackageMember/components/cy/npc-chat/index.wxml:9`).
struct MemberMerchantNPCChatSheet<Content: View>: View {
    @Environment(\.locale) private var locale
    let title: String
    let onExport: (() async -> Void)?
    let onClear: (() async -> Void)?
    let onClose: () -> Void
    let content: Content

    @State private var confirmsClear = false

    init(
        title: String,
        onExport: (() async -> Void)? = nil,
        onClear: (() async -> Void)? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onExport = onExport
        self.onClear = onClear
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            // System sheet header: inline title and the standard close glyph (no NavigationStack: the hosted chat may own one).
            HStack(spacing: 12) {
                Text(verbatim: title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("action.close"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            if onExport != nil || onClear != nil {
                HStack(spacing: 8) {
                    if let onExport {
                        Button {
                            Task { await onExport() }
                        } label: {
                            Text(verbatim: appLocalized("memberPopup.merchantNPCChatSheet.1", locale: locale))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("merchant.npcChat.export")
                    }
                    if onClear != nil {
                        Button(role: .destructive) {
                            confirmsClear = true
                        } label: {
                            Text(verbatim: appLocalized("memberPopup.merchantNPCChatSheet.2", locale: locale))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("merchant.npcChat.clear")
                    }
                }
                .padding(.horizontal, 16)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDragIndicator(.visible)
        .cySheet(isPresented: $confirmsClear) {
            MemberNPCLogDeleteConfirmSheet {
                confirmsClear = false
                if let onClear {
                    Task { await onClear() }
                }
            }
        }
    }
}

/// Discard confirmation when leaving cooperation invite editor with unsaved text.
struct MemberCoopInviteDiscardConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
            title: appLocalized("coopflow.invite.discardPrompt", locale: locale),
            message: appLocalized("memberPopup.coopInviteDiscardConfirmSheet.1", locale: locale),
            confirmTitle: appLocalized("coopflow.invite.discard", locale: locale),
            isDestructive: true,
            confirmIdentifier: "coopflow.invite.discard.confirm",
            onConfirm: onConfirm
        )
    }
}

/// DS invitation sheet (`subpackageMember/components/cy/coop-invite-sheet/index.wxml:2`)
/// listing owned topics & invite chapters on member/merchant public home.
struct MemberCoopInviteSheet: View {
    @Environment(\.locale) private var locale
    let targetName: String
    let merchantMemberID: Int?
    let loadTopics: @MainActor () async -> [(id: Int, title: String)]
    let loadChapters: @MainActor (Int) async -> [TopicInviteChapter]
    let onOpenFullCoopFlow: (() -> Void)?
    let onClose: () -> Void

    @State private var topics: [(id: Int, title: String)] = []
    @State private var selectedTopicID: Int?
    @State private var chapters: [TopicInviteChapter] = []
    @State private var draft = MemberCoopInviteDraft()
    @State private var loading = false
    @State private var showsDiscard = false
    @State private var toastMessage: LocalizedStringKey?

    private var dirty: Bool { draft.selectedChapterID != nil || draft.normalizedNote != nil }

    var body: some View {
        NavigationStack {
            Form {
                if !targetName.isEmpty {
                    Section {
                        Text(verbatim: targetName)
                            .font(.headline)
                    }
                }

                if loading {
                    Section {
                        ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
                    }
                } else if topics.isEmpty {
                    ContentUnavailableView(
                        appLocalized("memberPopup.coopInviteSheet.1", locale: locale),
                        systemImage: "doc.text"
                    )
                } else {
                    Section {
                        ForEach(topics, id: \.id) { topic in
                            Button {
                                selectedTopicID = topic.id
                                draft.selectedChapterID = nil
                                Task { chapters = await loadChapters(topic.id) }
                            } label: {
                                HStack {
                                    Text(verbatim: topic.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTopicID == topic.id {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("member.coopInvite.topic.\(topic.id)")
                            .accessibilityAddTraits(selectedTopicID == topic.id ? .isSelected : [])
                        }
                    } header: {
                        Text(verbatim: appLocalized("memberPopup.coopInviteSheet.2", locale: locale))
                    }

                    if !chapters.isEmpty {
                        Section {
                            ForEach(chapters, id: \.id) { chapter in
                                let numericID = Int(chapter.id) ?? 0
                                Button {
                                    draft.selectedChapterID = numericID
                                } label: {
                                    HStack {
                                        Text(verbatim: chapter.name.isEmpty ? "#\(chapter.id)" : chapter.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if draft.selectedChapterID == numericID {
                                            Image(systemName: "checkmark")
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .accessibilityIdentifier("member.coopInvite.chapter.\(chapter.id)")
                                .accessibilityAddTraits(draft.selectedChapterID == numericID ? .isSelected : [])
                            }
                        } header: {
                            Text(verbatim: appLocalized("memberPopup.coopInviteSheet.3", locale: locale))
                        }
                    }

                    Section {
                        TextField(
                            appLocalized("memberPopup.coopInviteSheet.4", locale: locale),
                            text: $draft.note,
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                        .accessibilityLabel(appLocalized("memberPopup.coopInviteSheet.5", locale: locale))
                        .accessibilityIdentifier("member.coopInvite.note")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text(verbatim: appLocalized("memberPopup.coopInviteSheet.6", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if dirty { showsDiscard = true } else { onClose() }
                    } label: {
                        Text(verbatim: appLocalized("memberPopup.coopInviteSheet.7", locale: locale))
                    }
                    .accessibilityIdentifier("member.coopInvite.close")
                }
                if !loading && !topics.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            if let onOpenFullCoopFlow {
                                onClose()
                                onOpenFullCoopFlow()
                            } else {
                                toastMessage = LocalizedStringKey(
                                    appLocalized("memberPopup.coopInviteSheet.8", locale: locale)
                                )
                            }
                        } label: {
                            Text(verbatim: appLocalized("memberPopup.coopInviteSheet.9", locale: locale))
                        }
                        .disabled(!draft.isReadyToSend || merchantMemberID == nil)
                        .accessibilityIdentifier("member.coopInvite.send")
                    }
                }
            }
        }
        .cyToast(message: $toastMessage, tone: .info)
        .cySheet(isPresented: $showsDiscard) {
            MemberCoopInviteDiscardConfirmSheet {
                showsDiscard = false
                onClose()
            }
        }
        .task {
            loading = true
            topics = await loadTopics()
            if let first = topics.first {
                selectedTopicID = first.id
                chapters = await loadChapters(first.id)
            }
            loading = false
        }
    }
}

/// Discard confirmation when closing a deep-linked scene with unsaved changes (`scene-deep-link/index.wxml:78`).
struct MemberDeepLinkDiscardModal: View {
    @Environment(\.locale) private var locale
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        let prompt = DeepLinkSceneDiscardPrompt()
        MemberConfirmAlert(
            title: MemberPopupCopy.text(prompt.title, "Discard current changes?", locale: locale),
            message: MemberPopupCopy.text(prompt.message, "Unsaved edits will be lost if you close.", locale: locale),
            cancelTitle: MemberPopupCopy.text(prompt.cancelTitle, "Keep editing", locale: locale),
            confirmTitle: MemberPopupCopy.text(prompt.confirmTitle, "Discard & close", locale: locale),
            isDestructive: true,
            confirmIdentifier: "deepLink.discard.confirm",
            cancelIdentifier: "deepLink.discard.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

// MARK: - Native confirmation chrome (native r2)

/// Native replacement for `CYConfirmSheet` (same arguments): a system sheet with the title and message in an inset
/// grouped list, consequences as SF Symbol labels, and the confirm / cancel pair as system buttons in the bottom bar.
struct MemberConfirmSheet: View {
    private let title: String
    private let message: String
    private let confirmTitle: String
    private let cancelTitle: String?
    private let isDestructive: Bool
    private let confirmDisabled: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let titleIdentifier: String?
    private let consequences: [CYConfirmConsequence]
    private let onCancel: (() -> Void)?
    private let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String, message: String, confirmTitle: String,
         cancelTitle: String? = nil,
         isDestructive: Bool = false, confirmDisabled: Bool = false,
         confirmIdentifier: String? = nil,
         cancelIdentifier: String? = nil, titleIdentifier: String? = nil,
         consequences: [CYConfirmConsequence] = [],
         onCancel: (() -> Void)? = nil,
         onConfirm: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.confirmDisabled = confirmDisabled
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.titleIdentifier = titleIdentifier
        self.consequences = consequences
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: title)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .memberOptionalIdentifier(titleIdentifier)
                    if !message.isEmpty {
                        Text(verbatim: message)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }
            if !consequences.isEmpty {
                Section {
                    ForEach(consequences) { item in
                        Label {
                            Text(verbatim: item.text).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: item.systemImage).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("confirm.consequences")
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button(role: isDestructive ? .destructive : nil) {
                    onConfirm()
                } label: {
                    Text(verbatim: confirmTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(confirmDisabled)
                .memberOptionalIdentifier(confirmIdentifier)
                Button {
                    onCancel?()
                    dismiss()
                } label: {
                    Group {
                        if let cancelTitle { Text(verbatim: cancelTitle) } else { Text("action.cancel") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .memberOptionalIdentifier(cancelIdentifier)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Native replacement for the centred `CYModal` dialog (same arguments): a system `.alert`. The host shows this view
/// only while its flag is on and clears the flag in `onCancel` / `onConfirm`. Consequences join the alert message.
struct MemberConfirmAlert: View {
    private let title: String
    private let message: String
    private let consequences: [CYConfirmConsequence]
    private let cancelTitle: String?
    private let confirmTitle: String
    private let isDestructive: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    init(title: String, message: String, consequences: [CYConfirmConsequence] = [],
         cancelTitle: String? = nil, confirmTitle: String, isDestructive: Bool = false,
         confirmIdentifier: String? = nil, cancelIdentifier: String? = nil,
         onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.consequences = consequences
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    private var fullMessage: String {
        ([message] + consequences.map { "• " + $0.text }).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .alert(Text(verbatim: title), isPresented: Binding(get: { true }, set: { _ in })) {
                Button(role: isDestructive ? .destructive : nil, action: onConfirm) {
                    Text(verbatim: confirmTitle)
                }
                .accessibilityIdentifier(confirmIdentifier ?? "memberPopup.alert.confirm")
                Button(role: .cancel, action: onCancel) {
                    if let cancelTitle { Text(verbatim: cancelTitle) } else { Text("action.cancel") }
                }
                .accessibilityIdentifier(cancelIdentifier ?? "memberPopup.alert.cancel")
            } message: {
                Text(verbatim: fullMessage)
            }
    }
}

/// Native replacement for `CYOptionSheet` (same arguments): an inset grouped list of system rows in a sheet,
/// with the title inline and 关闭 in the toolbar. A danger item is a destructive button.
struct MemberOptionSheet<ID: Hashable>: View {
    let title: String
    let items: [CYOptionSheetItem<ID>]
    var selectedID: ID? = nil
    var closeIdentifier: String? = nil
    let onSelect: (ID) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        Button(role: item.isDanger ? .destructive : nil) {
                            onSelect(item.id)
                        } label: {
                            HStack {
                                if let systemImage = item.systemImage {
                                    Label {
                                        optionText(item)
                                    } icon: {
                                        Image(systemName: systemImage)
                                    }
                                } else {
                                    optionText(item)
                                }
                                Spacer(minLength: 8)
                                if item.id == selectedID {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(item.isDanger ? Color.red : Color.primary)
                        .accessibilityAddTraits(item.id == selectedID ? .isSelected : [])
                        .memberOptionalIdentifier(item.identifier)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close", action: onClose)
                        .memberOptionalIdentifier(closeIdentifier)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private func optionText(_ item: CYOptionSheetItem<ID>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: item.title)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = item.subtitle {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension View {
    @ViewBuilder func memberOptionalIdentifier(_ identifier: String?) -> some View {
        if let identifier { accessibilityIdentifier(identifier) } else { self }
    }
}
