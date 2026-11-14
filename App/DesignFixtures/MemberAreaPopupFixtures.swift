#if DEBUG
import SwiftUI

/// DEBUG hosts for member/passport/wallet/orders/tickets/coupons/settings popups & modals.
/// Launch with `--design-fixture member-popup-<id>`.
enum MemberAreaPopupFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "member-popup-sign-out":
            return player(MemberSignOutConfirmSheet(confirmIdentifier: "fixture.signOut.confirm") {})
        case "member-popup-deregister-cancel":
            return player(MemberDeregistrationCancelConfirmSheet {})
        case "member-popup-deregister-submit":
            return player(MemberDeregistrationSubmitConfirmSheet {})
        case "member-popup-marketing-opt-in":
            return player(MemberMarketingConsentConfirmSheet(
                merchantName: "夜航探店俱乐部",
                channelKey: "compliance.channel.sms",
                optedIn: true
            ) {})
        case "member-popup-marketing-opt-out":
            return player(MemberMarketingConsentConfirmSheet(
                merchantName: "夜航探店俱乐部",
                channelKey: "compliance.channel.sms",
                optedIn: false
            ) {})
        case "member-popup-favorites-note":
            return player(MemberFavoritesRecommendNoteSheet {})
        case "member-popup-topic-unlike":
            return player(MemberTopicUnlikeConfirmSheet {})
        case "member-popup-bank-discard":
            return player(MemberBankWithdrawalDiscardConfirmSheet {})
        case "member-popup-bundle-swap":
            return player(MemberBundleSwapConfirmSheet(merchantName: "星光探案馆") {})
        case "member-popup-report-appeal":
            return player(MemberReportAppealConfirmSheet {})
        case "member-popup-coupon-code":
            return player(MemberCouponShowConfirmSheet {})
        case "member-popup-coupon-discard":
            return merchant(MemberCouponDiscardConfirmSheet {})
        case "member-popup-coupon-stop":
            return merchant(MemberCouponStopConfirmModal(couponName: "周末漫游立减券", onConfirm: {}, onCancel: {}))
        case "member-popup-invoice-withdraw":
            return player(MemberInvoiceWithdrawConfirmSheet(confirmIdentifier: "fixture.invoice.withdraw") {})
        case "member-popup-invoice-title-delete":
            return player(MemberInvoiceTitleDeleteConfirmSheet {})
        case "member-popup-npc-delete":
            return player(MemberNPCLogDeleteConfirmSheet {})
        case "member-popup-orient-score":
            return player(MemberOrientScoreConfirmSheet {})
        case "member-popup-profile-exit":
            return player(MemberProfileDiscardConfirmSheet(kind: .exitDiscard) {})
        case "member-popup-profile-reload":
            return player(MemberProfileDiscardConfirmSheet(kind: .reloadDiscard) {})
        case "member-popup-profile-review-restore":
            return player(MemberProfileDiscardConfirmSheet(kind: .reviewRestore) {})
        case "member-popup-profile-avatar-discard":
            return player(MemberProfileDiscardConfirmSheet(kind: .avatarDiscard) {})
        case "member-popup-participant-delete":
            return player(MemberParticipantDeleteConfirmSheet(summary: "林小满 · 138****8820") {})
        case "member-popup-complaint-submit":
            return player(MemberComplaintSubmitConfirmSheet {})
        case "member-popup-settings-scene-discard":
            return merchant(MemberSettingsSceneDiscardModal(onCancel: {}, onConfirm: {}))
        case "member-popup-settings-club-picker":
            return player(MemberSettingsClubPickerSheet(
                clubs: sampleClubs(),
                onSelect: { _ in },
                onClose: {}
            ))
        case "member-popup-ai-chat-records":
            return player(MemberAIChatRecordsOptionSheet(onSelect: { _ in }, onClose: {}))
        case "member-popup-npc-chat-sheet":
            return merchant(MemberMerchantNPCChatSheet(
                title: "店铺形象向导",
                onExport: {},
                onClear: {},
                onClose: {}
            ) {
                Text(verbatim: "欢迎来到星光探案馆，今天想了解哪条主题路线？")
                    .font(CYTypography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            })
        case "member-popup-coop-invite-sheet":
            return merchant(MemberCoopInviteSheet(
                targetName: "星光探案馆",
                merchantMemberID: 88,
                loadTopics: { [(id: 101, title: "城市夜游剧本线"), (id: 102, title: "周末老街寻宝")] },
                loadChapters: { _ in [TopicInviteChapter(id: "11", name: "第一章 · 码头集合"), TopicInviteChapter(id: "12", name: "第二章 · 钟楼线索")] },
                onOpenFullCoopFlow: nil,
                onClose: {}
            ))
        case "member-popup-coop-invite-discard":
            return player(MemberCoopInviteDiscardConfirmSheet {})
        case "member-popup-deep-link-discard":
            return player(MemberDeepLinkDiscardModal(onCancel: {}, onConfirm: {}))
        default:
            return nil
        }
    }

    private static func sampleClubs() -> [ClubRecord] {
        let json = #"[{"id":11,"name":"夜航漫游俱乐部","city":"上海"},{"id":12,"name":"周末城市探索社","city":"杭州"}]"#
        return (try? JSONDecoder().decode([ClubRecord].self, from: Data(json.utf8))) ?? []
    }

    @MainActor private static func player<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player))
    }

    @MainActor private static func merchant<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.merchant))
    }
}
#endif
