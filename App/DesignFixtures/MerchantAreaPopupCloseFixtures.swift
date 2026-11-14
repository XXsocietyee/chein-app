#if DEBUG
import SwiftUI

/// DEBUG hosts for all closed merchant-area pop-ups (chapter finish, project delete,
/// cancel & refund gated behind ReviewedAreaSwitch, chapter danger confirm, and sheet host).
/// Launch with `--design-fixture merchant-close-popup-<id>`.
enum MerchantAreaPopupCloseFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "merchant-close-popup-chapter-finish":
            return merchant(MerchantChapterFinishModal(
                chapterName: "第一章 · 夜探静安",
                onCancel: {},
                onCloseOpenSignupInstead: {},
                onConfirm: {}
            ))
        case "merchant-close-popup-project-delete":
            return merchant(MerchantProjectDeleteModal(
                kind: .route,
                name: "梧桐区夜游路线",
                onCancel: {},
                onUnpublishInstead: {},
                onConfirm: {}
            ))
        case "merchant-close-popup-cancel-refund":
            return merchant(MerchantCancelAndRefundModal(
                kind: .activity,
                name: "周六夜场剧本局",
                paidCount: 6,
                onCancel: {},
                onConfirm: {}
            ))
        case "merchant-close-popup-cancel-refund-closed":
            return merchant(Text(verbatim: "—").accessibilityIdentifier("merchantClosePopup.moneyClosed"))
        case "merchant-close-popup-chapter-danger":
            return merchant(MerchantChapterActionDangerModal(
                kind: .withdrawApplication,
                onCancel: {},
                onConfirm: {}
            ))
        case "merchant-close-popup-sheet-host":
            return merchant(MerchantCloseSheetHost(
                title: "路线模式介绍",
                closeIdentifier: "merchantCloseFixture.sheetHost.close",
                onClose: {}
            ) {
                Text("按章节招募的线下节点支持承接点配置与暂停降级。")
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textSecondary)
            })
        default:
            return nil
        }
    }

    @MainActor private static func merchant<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.merchant))
    }
}
#endif
