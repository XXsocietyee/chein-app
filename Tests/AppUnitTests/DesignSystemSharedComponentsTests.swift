import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import Questify

@MainActor
final class DesignSystemSharedComponentsTests: XCTestCase {
    private func assertFits<V: View>(
        _ view: V,
        domain: ThemeDomain,
        localeIdentifier: String = "zh-Hans",
        typeSize: DynamicTypeSize = .large,
        width: CGFloat = 390,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #if canImport(UIKit)
        let hosted = view
            .environment(\.themeDomain, domain)
            .environment(\.colorScheme, domain.colorScheme)
            .environment(\.locale, Locale(identifier: localeIdentifier))
            .environment(\.dynamicTypeSize, typeSize)
            .frame(width: width)
        let controller = UIHostingController(rootView: hosted)
        let size = controller.sizeThatFits(in: CGSize(width: width, height: 4000))
        XCTAssertGreaterThan(size.height, 0, "Expected positive height for \(label)", file: file, line: line)
        XCTAssertLessThanOrEqual(size.width, width + 1.0, "Horizontal overflow for \(label)", file: file, line: line)
        #endif
    }

    // MARK: - 1. Base Shared Components Render & Adapt Across Domains, Locales & Dynamic Type

    func testAllBaseDesignComponentsRenderWithoutOverflowInEnZhLongAndAX5() {
        let domains: [ThemeDomain] = [.player, .merchant]
        let longChinese = "这是一段用于验证极端中文长文案换行的城市漫游活动副标题与操作说明，确保在超大字体下不裁切也不横向溢出。"

        for domain in domains {
            let configurations: [(locale: String, typeSize: DynamicTypeSize, width: CGFloat, suffix: String)] = [
                ("en", .large, 390, "en-390"),
                ("zh-Hans", .large, 390, "zh-390"),
                ("zh-Hans", .accessibility5, 320, "zh-ax5-320"),
            ]

            for cfg in configurations {
                // Button + Pill button
                let buttons = VStack(spacing: CYSpacing.sm) {
                    CYButton(variant: .primary, isFullWidth: true, action: {}) {
                        Text(verbatim: cfg.locale == "en" ? "Continue" : longChinese)
                    }
                    CYButton(variant: .secondary, isFullWidth: true, action: {}) {
                        Text(verbatim: cfg.locale == "en" ? "Cancel" : "取消")
                    }
                    CYButton(variant: .ghost, isFullWidth: false, action: {}) {
                        Text(verbatim: cfg.locale == "en" ? "Skip" : "跳过此步")
                    }
                    CYButton(variant: .danger, isFullWidth: true, action: {}) {
                        Text(verbatim: cfg.locale == "en" ? "Delete" : "删除草稿")
                    }
                    CYPillButton(verbatim: cfg.locale == "en" ? "Publish Activity" : longChinese, style: .primary, action: {})
                }
                assertFits(buttons, domain: domain, localeIdentifier: cfg.locale, typeSize: cfg.typeSize, width: cfg.width, "buttons-\(domain)-\(cfg.suffix)")

                // Tag / Status chip + badges + avatar
                let tagsAndBadges = VStack(spacing: CYSpacing.sm) {
                    CYStatusChip(verbatim: cfg.locale == "en" ? "Pending Review" : longChinese, tone: .info, systemImage: "sparkles")
                    CYStatusChip(verbatim: cfg.locale == "en" ? "Action Required" : "需要处理", tone: .danger, isSelected: true)
                    HStack {
                        CYCountBadge(count: 120)
                        CYUnreadBadge(count: 18, style: .danger)
                        CYUnreadBadge(isDotOnly: true, style: .accent)
                        CYAvatarView(name: "城印", size: .md, showAccentRing: true, isOnline: true)
                    }
                }
                assertFits(tagsAndBadges, domain: domain, localeIdentifier: cfg.locale, typeSize: cfg.typeSize, width: cfg.width, "tags-\(domain)-\(cfg.suffix)")

                // Chip & Tabs
                let chipsAndTabs = VStack(spacing: CYSpacing.sm) {
                    CYFilterChip(
                        verbatim: cfg.locale == "en" ? "Recommended" : longChinese,
                        systemImage: "sparkles",
                        count: 12,
                        isSelected: true,
                        action: {}
                    )
                    CYTabs(
                        items: [
                            CYTabItem(id: "all", title: cfg.locale == "en" ? "All" : "全部", badgeCount: 9),
                            CYTabItem(id: "active", title: cfg.locale == "en" ? "In Progress" : "进行中的城市漫游路线"),
                        ],
                        selection: .constant("all"),
                        variant: .underline
                    )
                    CYTabs(
                        items: [
                            CYTabItem(id: "a", title: cfg.locale == "en" ? "List" : "列表视图"),
                            CYTabItem(id: "b", title: cfg.locale == "en" ? "Map" : "地图视图"),
                        ],
                        selection: .constant("a"),
                        variant: .segmented
                    )
                }
                assertFits(chipsAndTabs, domain: domain, localeIdentifier: cfg.locale, typeSize: cfg.typeSize, width: cfg.width, "tabs-\(domain)-\(cfg.suffix)")

                // Cell & Card & Field
                let cellCardField = VStack(spacing: CYSpacing.sm) {
                    CYListRow(
                        verbatim: cfg.locale == "en" ? "Merchant Settlement" : longChinese,
                        meta: cfg.locale == "en" ? "Updated today" : "今日更新 · 支持超长中文副标题自动换行",
                        trailing: .valueChevron("¥1,280.00"),
                        card: true
                    ) {
                        CYRowIcon(systemImage: "creditcard.fill")
                    }
                    CYListRow(
                        verbatim: cfg.locale == "en" ? "Disabled Row" : "暂不可用",
                        trailing: .chevron
                    ) {
                        CYRowIcon(systemImage: "lock.fill")
                    }
                    .rowDisabled()

                    Text(verbatim: cfg.locale == "en" ? "Card surface" : longChinese)
                        .cyCardSurface(variant: .elevated)

                    CYField(
                        label: cfg.locale == "en" ? "Activity Title" : "活动名称",
                        placeholder: cfg.locale == "en" ? "Enter title" : "请输入活动名称",
                        text: .constant(cfg.locale == "en" ? "Weekend Walk" : longChinese),
                        isRequired: true,
                        maxLength: 80,
                        errorText: cfg.locale == "en" ? "Title too long" : "字数超出限制，请精简标题"
                    )
                }
                assertFits(cellCardField, domain: domain, localeIdentifier: cfg.locale, typeSize: cfg.typeSize, width: cfg.width, "cellCardField-\(domain)-\(cfg.suffix)")

                // Sheet & Modal
                let sheetAndModal = VStack(spacing: CYSpacing.md) {
                    CYOptionSheet(
                        title: cfg.locale == "en" ? "Choose Action" : "选择操作",
                        items: [
                            CYOptionSheetItem(id: "edit", title: cfg.locale == "en" ? "Edit" : "编辑活动信息", systemImage: "pencil"),
                            CYOptionSheetItem(id: "delete", title: cfg.locale == "en" ? "Delete" : longChinese, subtitle: cfg.locale == "en" ? "Cannot be undone" : "删除后无法恢复", systemImage: "trash", isDanger: true),
                        ],
                        selectedID: "edit",
                        onSelect: { _ in },
                        onClose: {}
                    )
                    CYModal(
                        title: cfg.locale == "en" ? "Cancel Activity?" : "确认取消活动？",
                        message: cfg.locale == "en" ? "Participants will be notified." : longChinese,
                        consequences: [
                            CYConfirmConsequence(systemImage: "exclamationmark.triangle.fill", text: cfg.locale == "en" ? "Refunds issued automatically" : "已报名用户将收到自动退款通知"),
                        ],
                        cancelTitle: cfg.locale == "en" ? "Keep" : "保留",
                        confirmTitle: cfg.locale == "en" ? "Cancel Activity" : "确认取消",
                        isDestructive: true,
                        onCancel: {},
                        onConfirm: {}
                    ).panelCard
                }
                assertFits(sheetAndModal, domain: domain, localeIdentifier: cfg.locale, typeSize: cfg.typeSize, width: cfg.width, "sheetModal-\(domain)-\(cfg.suffix)")

                // NavBar, Footer, TabBar strip
                let chromeBars = VStack(spacing: CYSpacing.sm) {
                    CYNavBar(title: cfg.locale == "en" ? "Details" : longChinese, mode: .solid, onBack: {})
                    CYFooterBar(
                        primary: CYFooterAction(cfg.locale == "en" ? "Confirm" : "确认提交", action: {}),
                        secondary: CYFooterAction(cfg.locale == "en" ? "Cancel" : "取消", action: {})
                    )
                    CYRootTabBarStrip(selection: .constant(.home))
                }
                assertFits(chromeBars, domain: domain, localeIdentifier: cfg.locale, typeSize: cfg.typeSize, width: cfg.width, "chrome-\(domain)-\(cfg.suffix)")
            }
        }
    }

    // MARK: - 2. Business Components (Activity Card, Route Node, Task Status 6 States)

    func testBusinessComponentsRenderAcrossDomainsLocalesAndAccessibilitySizes() {
        let longChinese = "在城市的老街巷里寻找百年茶馆与独立书店，完成全部打卡点即可领取限定纪念徽章。"
        let taskStates: [CYTaskStatusState] = [
            .locked(requirement: "需先完成第 1 站打卡", prereqTitle: "前往第 1 站", onOpenPrereq: {}),
            .available(methodLabel: "GPS 到店 + 拍照", onStart: {}),
            .submitting(requestId: "REQ-2026-0091"),
            .completed(receiptNo: "CY-RCPT-8841", completedAt: "14:20", onViewReceipt: {}),
            .retryableFailure(requestId: "REQ-2026-0092", detail: "网络波动，提交超时", onQueryOriginalReceipt: {}, onRetry: {}),
            .offlineAwaitingSync(draftId: "DRAFT-17", savedAt: "14:25", onSyncNow: {}, onViewDraft: {}),
        ]

        for domain in [ThemeDomain.player, ThemeDomain.merchant] {
            for typeSize in [DynamicTypeSize.large, .accessibility5] {
                let activityCard = CYActivityFeedCard(
                    title: "南锣鼓巷与钟鼓楼慢游 · 长标题自适应",
                    subtitle: longChinese,
                    capabilityTag: "可直接开局的模板",
                    rareTrophyCount: 3,
                    onPrimary: {},
                    onSecondary: {}
                )
                assertFits(activityCard, domain: domain, typeSize: typeSize, width: typeSize == .accessibility5 ? 320 : 390, "activityCard-\(domain)-\(typeSize)")

                let routeStack = VStack(spacing: 0) {
                    CYRouteNodeRow(index: 1, title: "鼓楼东大街茶馆", distanceAndETA: "0 m · 已到达", requirement: .gps, completion: .completed, isFirst: true)
                    CYRouteNodeRow(index: 2, title: longChinese, distanceAndETA: "320 m · 步行 4 分钟", requirement: .qr, completion: .current, perkTitle: "凭本路线核销赠手冲咖啡 1 杯", onPerkTap: {})
                    CYRouteNodeRow(index: 3, title: "未解锁终点站", requirement: .photo, completion: .locked, isLast: true)
                }
                assertFits(routeStack, domain: domain, typeSize: typeSize, width: typeSize == .accessibility5 ? 320 : 390, "routeNodes-\(domain)-\(typeSize)")

                for (idx, state) in taskStates.enumerated() {
                    let taskCard = CYTaskStatusCard(title: "第 \(idx + 1) 站 · \(longChinese)", state: state)
                    assertFits(taskCard, domain: domain, typeSize: typeSize, width: typeSize == .accessibility5 ? 320 : 390, "taskStatus-\(idx)-\(domain)-\(typeSize)")
                }
            }
        }
    }

    // MARK: - 3. Deterministic Formatting & Tab Parity Helpers

    func testBadgeFormattingAndDomainTabIconMappings() {
        XCTAssertEqual(CYCountBadge.formattedLabel(count: nil), "—")
        XCTAssertNil(CYCountBadge.formattedLabel(count: 0, showsZero: false))
        XCTAssertEqual(CYCountBadge.formattedLabel(count: 0, showsZero: true), "0")
        XCTAssertEqual(CYCountBadge.formattedLabel(count: 7), "7")
        XCTAssertEqual(CYCountBadge.formattedLabel(count: 99), "99")
        XCTAssertEqual(CYCountBadge.formattedLabel(count: 100), "99+")

        XCTAssertEqual(CYUnreadBadge.formattedCount(0), "")
        XCTAssertEqual(CYUnreadBadge.formattedCount(42), "42")
        XCTAssertEqual(CYUnreadBadge.formattedCount(150), "99+")

        // Merchant tab titles match mini-program parity keys
        XCTAssertEqual(CYDomainTabIcons.titleKey(for: .home, domain: .merchant), "tabBar.merchant.workbench")
        XCTAssertEqual(CYDomainTabIcons.titleKey(for: .roam, domain: .merchant), "tabBar.merchant.marketing")
        XCTAssertEqual(CYDomainTabIcons.titleKey(for: .publish, domain: .merchant), "tabBar.merchant.templates")
        XCTAssertEqual(CYDomainTabIcons.titleKey(for: .club, domain: .merchant), "tabBar.merchant.cooperation")

        // Player idle vs selected glyph pairs
        let roamIcon = CYDomainTabIcons.icon(for: .roam, domain: .player)
        XCTAssertEqual(roamIcon.idle, "images_icon_roam")
        XCTAssertEqual(roamIcon.selected, "images_icon_roam_d")

        // CYSheetDetent fractions match DESIGN.md Part 4
        XCTAssertEqual(CYSheetDetent.peek.presentationDetent, .fraction(0.30))
        XCTAssertEqual(CYSheetDetent.half.presentationDetent, .fraction(0.60))
        XCTAssertEqual(CYSheetDetent.full.presentationDetent, .fraction(0.80))

        // CYRouteArrivalRequirement labels
        XCTAssertEqual(CYRouteArrivalRequirement.gps.label, "GPS 到达")
        XCTAssertEqual(CYRouteArrivalRequirement.qr.label, "扫码打卡")
        XCTAssertEqual(CYRouteArrivalRequirement.photo.label, "拍照核验")
    }
}
