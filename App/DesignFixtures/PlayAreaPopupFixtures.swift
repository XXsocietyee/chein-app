#if DEBUG
import SwiftUI

/// DEBUG hosts for the play-area sheets and modals. Launch with `--design-fixture play-popup-<id>`.
/// Money confirms render here as the open-host preview. The closed fixture is an em dash.
enum PlayAreaPopupFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "play-popup-roam-finish":
            return frame(PlayAreaRoamFinishModal(onConfirm: {}, onCancel: {}))
        case "play-popup-abandon-activity":
            return frame(PlayAreaActivityAbandonModal(onConfirm: {}, onCancel: {}))
        case "play-popup-seat-cancel":
            return frame(PlayAreaSeatCancelModal(seatNo: 3, onConfirm: {}, onCancel: {}))
        case "play-popup-host-cancel":
            return frame(PlayAreaHostCancelModal(paidCount: 4, onConfirm: {}, onCancel: {}))
        case "play-popup-host-cancel-unknown":
            return frame(PlayAreaHostCancelModal(paidCount: nil, onConfirm: {}, onCancel: {}))
        case "play-popup-host-cancel-closed":
            return frame(Text(verbatim: "—").accessibilityIdentifier("play-popup.moneyClosed"))
        case "play-popup-nonrefundable":
            return frame(PlayAreaNonRefundableModal(onConfirm: {}, onCancel: {}))
        case "play-popup-waitlist-quit":
            return frame(PlayAreaWaitlistQuitModal(onConfirm: {}, onCancel: {}))
        case "play-popup-nearby-range":
            return frame(PlayAreaNearbyRangeSheet(radii: [1000, 3000, 5000], selected: 3000, onSelect: { _ in }, onClose: {}))
        case "play-popup-team-apply":
            return frame(PlayAreaTeamReviewModal(action: .apply(.init(1)), name: "夜航队", onConfirm: {}, onCancel: {}))
        case "play-popup-team-withdraw":
            return frame(PlayAreaTeamReviewModal(action: .withdraw(.init(1)), name: "夜航队", onConfirm: {}, onCancel: {}))
        case "play-popup-team-reject":
            return frame(PlayAreaTeamReviewModal(action: .handle(team: .init(1), applicant: .init(2), approved: false), name: "小林", onConfirm: {}, onCancel: {}))
        default:
            return nil
        }
    }

    @MainActor private static func frame<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player))
    }
}
#endif
