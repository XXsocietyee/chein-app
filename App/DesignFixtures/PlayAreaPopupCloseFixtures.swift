#if DEBUG
import SwiftUI

/// DEBUG hosts for all closed play-area pop-ups (map style, apply note, album permission,
/// plan fallback, attendance rotate/dial, album retry, unsaved draft, result sheet, pending payment).
/// Launch with `--design-fixture play-close-popup-<id>`.
enum PlayAreaPopupCloseFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "play-close-popup-apply-note":
            return player(ApplyNoteHost())
        case "play-close-popup-map-style":
            return player(PlayAreaNearbyMapStyleSheet(
                selected: .standard,
                onSelect: { _ in },
                onClose: {}
            ))
        case "play-close-popup-album-permission":
            return player(PlayPhotoAlbumPermissionModal(onOpenSettings: {}, onBack: {}))
        case "play-close-popup-plan-fallback":
            return player(PlayDirectorPlanFallbackConfirmModal(
                reason: "全队同意按默认结局收尾",
                onCancel: {},
                onConfirm: {}
            ))
        case "play-close-popup-attendance-rotate":
            return player(PlayAttendanceRotateModal(onCancel: {}, onConfirm: {}))
        case "play-close-popup-attendance-dial":
            return player(PlayAttendanceDialModal(hostName: "夜航领队 · 阿哲", onCancel: {}, onConfirm: {}))
        case "play-close-popup-album-retry":
            return player(PlayKitAlbumRetryModal(onCancel: {}, onConfirm: {}))
        case "play-close-popup-unsaved":
            return player(PlayUnsavedEditModal(onKeepEditing: {}, onDiscard: {}))
        case "play-close-popup-result":
            return player(PlayCloseResultSheet(
                title: "已转正式主题",
                message: "可在我的主题列表查看并继续发布配置。",
                detail: "城市定向 · 静安夜游线",
                closeIdentifier: "playCloseFixture.result.close",
                onClose: {}
            ))
        case "play-close-popup-payment-pending":
            return player(PlayPaymentPendingModal(detailed: false, onGoOrders: {}, onClose: {}))
        default:
            return nil
        }
    }

    @MainActor private struct ApplyNoteHost: View {
        @State private var note = "晚上七点准时在静安寺集合"
        var body: some View {
            PlayNearbyApplyNoteModal(teamName: "夜航探店小队", note: $note, onCancel: {}, onConfirm: {})
        }
    }

    @MainActor private static func player<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player))
    }
}
#endif
