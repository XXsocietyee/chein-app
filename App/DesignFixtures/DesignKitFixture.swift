#if DEBUG
import SwiftUI

enum DesignKitSectionTab: String, CaseIterable, Hashable {
    case base = "基础组件"
    case business = "业务组件"
    case states = "弹层/状态"
}

enum DesignKitDomainMode: String, CaseIterable, Hashable {
    case both = "双域对照"
    case player = "玩家暗色"
    case merchant = "商户亮色"
}

private struct DesignKitChipOption: Identifiable {
    let id: Int
    let name: String
}

/// Complete DEBUG Design Kit fixture mounting every Part 4 base component and Part 5 Chengyin business component
/// across every required state in BOTH domains (`player` dark and `merchant` light).
struct DesignKitFixture: View {
    @State private var domainMode: DesignKitDomainMode
    @State private var section: DesignKitSectionTab = .base

    init(initialDomain: ThemeDomain = .player, initialMode: DesignKitDomainMode = .both) {
        self._domainMode = State(initialValue: initialMode)
        let _ = initialDomain
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    modeControls
                    switch domainMode {
                    case .both:
                        domainShowcase(.player, heading: "Player Dark · 玩家暗域")
                        domainShowcase(.merchant, heading: "Merchant Light · 商户亮域")
                    case .player:
                        domainShowcase(.player, heading: "Player Dark · 玩家暗域")
                    case .merchant:
                        domainShowcase(.merchant, heading: "Merchant Light · 商户亮域")
                    }
                }
                .padding(.vertical, CYSpacing.lg)
            }
            .background(CYColor.bgPage.ignoresSafeArea())
            .navigationTitle(Text(verbatim: "Design Kit")).navigationBarTitleDisplayMode(.inline)
        }
        .themeDomain(domainMode == .merchant ? .merchant : .player)
    }

    private var modeControls: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYTabs(
                items: DesignKitDomainMode.allCases.map { CYTabItem(id: $0, title: $0.rawValue) },
                selection: $domainMode,
                variant: .segmented
            )
            CYTabs(
                items: DesignKitSectionTab.allCases.map { CYTabItem(id: $0, title: $0.rawValue) },
                selection: $section,
                variant: .underline
            )
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
    }

    private func domainShowcase(_ domain: ThemeDomain, heading: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            Text(verbatim: heading)
                .cyText(.sectionTitle)
                .foregroundStyle(CYDomainPalette(domain).textPrimary)
                .padding(.horizontal, CYSpacing.pageHorizontal)

            DesignKitCanvas(domain: domain, section: section)
                .padding(.vertical, CYSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
                        .fill(CYDomainPalette(domain).bgPage)
                )
                .padding(.horizontal, CYSpacing.sm)
        }
        .themeDomain(domain)
    }
}

private struct DesignKitCanvas: View {
    let domain: ThemeDomain
    let section: DesignKitSectionTab

    @State private var chipSelection: Int? = 1
    @State private var underlineTab = 0
    @State private var segmentedTab = 0
    @State private var chipTab = 0
    @State private var stickyTab = 0
    @State private var fieldIdle = ""
    @State private var fieldFilled = "城隐 · 夜游路线 01"
    @State private var fieldFocus = "输入中光标态"
    @State private var fieldError = "价格不能为负数"
    @State private var fieldHelp = ""
    @State private var fieldSuccess = "CY-2026-0815"
    @State private var fieldNotes = "支持多行文本与字符计数反馈。"
    @State private var selectedRootTab: RootTab = .home
    @State private var selectedSlotID = "slot-sat"
    @State private var attendees = 2
    @State private var publishStep = 1
    @State private var toastMessage: LocalizedStringKey? = nil
    @State private var showFullSheet = false
    @State private var showModalOverlay = false

    private let chipOptions = [
        DesignKitChipOption(id: 1, name: "近距离"),
        DesignKitChipOption(id: 2, name: "双人合作"),
        DesignKitChipOption(id: 3, name: "可开局模板"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxl) {
            switch section {
            case .base:
                buttonsSection
                badgesAndChipsSection
                tabsSection
                listCellsSection
                cardsAndFieldsSection
                chromeBarsSection
            case .states:
                sheetsAndModalsSection
                toastsAndFeedbackStatesSection
            case .business:
                activityAndRouteSection
                taskStatusSixStatesSection
                storyClueAndProgressSection
                registrationTeamPublishSection
            }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .cyToast(
            message: $toastMessage,
            tone: .undoable,
            undoTitle: "action.undo",
            onUndo: {}
        )
        .sheet(isPresented: $showFullSheet) {
            CYOptionSheet(
                title: "选择核验方式",
                items: [
                    CYOptionSheetItem(id: "qr", title: "扫码核验", subtitle: "现场出示动态二维码", systemImage: "qrcode"),
                    CYOptionSheetItem(id: "gps", title: "GPS 到点打卡", subtitle: "到达 50m 范围内自动解锁", systemImage: "location.fill"),
                    CYOptionSheetItem(id: "cancel", title: "退赛并释放名额", systemImage: "trash", isDanger: true),
                ],
                selectedID: "qr",
                onSelect: { _ in showFullSheet = false },
                onClose: { showFullSheet = false }
            )
            .cyDomainSheet(detents: [.peek, .half, .full])
            .themeDomain(domain)
        }
        .overlay {
            if showModalOverlay {
                CYModal(
                    title: "退出队伍并放弃当前线索？",
                    message: "退出后已领取的共享线索仍保留在团队档案中，但当前席位会立即释放。",
                    consequences: [
                        CYConfirmConsequence(systemImage: "person.badge.minus", text: "你的 S2 席位将变为 REVOKED"),
                        CYConfirmConsequence(systemImage: "ticket", text: "关联早鸟优惠券不会自动退回"),
                    ],
                    cancelTitle: "继续留队",
                    confirmTitle: "确认退出",
                    lighterAlternativeTitle: "仅暂离，保留席位",
                    isDestructive: true,
                    onCancel: { showModalOverlay = false },
                    onLighterAlternative: { showModalOverlay = false },
                    onConfirm: { showModalOverlay = false }
                )
            }
        }
    }

    private func groupTitle(_ text: String) -> some View {
        CYSectionHeader(verbatim: text)
    }

    // MARK: Part 4 Base Components

    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("Button · 变体 / 尺寸 / 禁用 / 加载 / Footer Pill")
            HStack(spacing: CYSpacing.sm) {
                CYButton(verbatim: "Primary", variant: .primary, isFullWidth: true, action: {})
                CYButton(verbatim: "Secondary", variant: .secondary, isFullWidth: true, action: {})
            }
            HStack(spacing: CYSpacing.sm) {
                CYButton(verbatim: "Ghost", variant: .ghost, isFullWidth: true, action: {})
                CYButton(verbatim: "Danger", variant: .danger, isFullWidth: true, action: {})
            }
            HStack(spacing: CYSpacing.sm) {
                CYButton(verbatim: "Disabled", variant: .primary, isFullWidth: true, action: {})
                    .disabled(true)
                CYButton(verbatim: "Loading", variant: .primary, isFullWidth: true, isLoading: true, action: {})
            }
            HStack(spacing: CYSpacing.sm) {
                CYButton(verbatim: "Size MD", variant: .secondary, size: .md, isFullWidth: false, action: {})
                CYButton(verbatim: "Size SM", variant: .secondary, size: .sm, isFullWidth: false, action: {})
                CYButton(verbatim: "XS", variant: .secondary, size: .xs, isFullWidth: false, action: {})
            }
            CYButton(verbatim: "Footer Pill CTA", variant: .primary, isFullWidth: true, isPill: true, action: {})
        }
    }

    private var badgesAndChipsSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("Tag / Status Badge / Filter Chip")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip(verbatim: "待处理", tone: .neutral, systemImage: "clock")
                    CYStatusChip(verbatim: "已完成", tone: .success, systemImage: "checkmark")
                    CYStatusChip(verbatim: "待同步", tone: .warning, systemImage: "exclamationmark.triangle")
                    CYStatusChip(verbatim: "失败", tone: .danger, systemImage: "xmark.circle")
                    CYStatusChip(verbatim: "提示", tone: .info, systemImage: "info.circle")
                    CYStatusChip(verbatim: "稀有成就", tone: .rare, systemImage: "star.fill", isSelected: true)
                    CYCountBadge(count: 8)
                    CYCountBadge(count: 120)
                }
            }

            HStack(spacing: CYSpacing.sm) {
                CYFilterChip(verbatim: "未选中筛选", systemImage: "line.3.horizontal.decrease", isSelected: false, action: {})
                CYFilterChip(verbatim: "已选中", systemImage: "checkmark", count: 12, isSelected: true, action: {})
            }

            CYChipRow(allTitle: "全部推荐", items: chipOptions, selection: $chipSelection) { $0.name }
        }
    }

    private var tabsSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("Tabs · Underline / Segmented / Chip / Sticky")
            CYTabs(
                items: [CYTabItem(id: 0, title: "路线概览"), CYTabItem(id: 1, title: "点位节点", badgeCount: 4), CYTabItem(id: 2, title: "规则")],
                selection: $underlineTab,
                variant: .underline
            )
            CYTabs(
                items: [CYTabItem(id: 0, title: "进行中"), CYTabItem(id: 1, title: "已归档")],
                selection: $segmentedTab,
                variant: .segmented
            )
            CYTabs(
                items: [CYTabItem(id: 0, title: "推荐"), CYTabItem(id: 1, title: "夜游"), CYTabItem(id: 2, title: "剧情解谜"), CYTabItem(id: 3, title: "亲子")],
                selection: $chipTab,
                variant: .chip
            )
            CYTabs(
                items: [CYTabItem(id: 0, title: "吸顶概览"), CYTabItem(id: 1, title: "任务"), CYTabItem(id: 2, title: "队伍")],
                selection: $stickyTab,
                variant: .sticky
            )
        }
    }

    private var listCellsSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("List Cell · 1行48pt / 2行64pt / 按压 / 禁用 / 危险")
            VStack(spacing: 0) {
                CYListRow(verbatim: "单行设置项 (48pt)", trailing: .valueChevron("已开启")) {
                    CYRowIcon(systemImage: "bell.fill")
                }
                .rowPadding()
                .rowDivider()

                CYListRow(verbatim: "双行详情项 (64pt)", meta: "说明文本与右栏不超过40%宽", trailing: .valueChevron("¥128.00")) {
                    CYRowIcon(systemImage: "wallet.bifold.fill")
                }
                .rowPadding()
                .rowDivider()

                CYListRow(verbatim: "按压反馈态", meta: "使用 bgSurfaceSubtle 填充", trailing: .chevron) {
                    CYRowIcon(systemImage: "hand.tap.fill")
                }
                .rowPadding()
                .rowPressed()
                .rowDivider()

                CYListRow(verbatim: "禁用状态", meta: "图标 40% 不透明度", trailing: .value("不可选")) {
                    CYRowIcon(systemImage: "lock.fill")
                }
                .rowPadding()
                .rowDisabled()
                .rowDivider()

                CYListRow(verbatim: "危险操作 · 退出活动", meta: "释放名额后不可恢复", trailing: .chevron) {
                    CYRowIcon(systemImage: "rectangle.portrait.and.arrow.right")
                }
                .rowPadding()
                .danger()
            }
            .cyDomainCard(padding: 0)
        }
    }

    private var cardsAndFieldsSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("Card & Field · 暗色顶光 / 亮色微阴影 & 全部输入态")
            CYCard {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: "语义卡片容器 (16pt 圆角 · 无外边框)")
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: "Dark 使用 0.5pt 顶部高光线；Light 使用中性软阴影。")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CYField(label: "Idle 待输入", placeholder: "请输入活动标题", text: $fieldIdle, isRequired: true, forcedState: .idle)
            CYField(label: "Filled 已填充", placeholder: "", text: $fieldFilled, forcedState: .filled)
            CYField(label: "Focused 聚焦 2pt 环", placeholder: "", text: $fieldFocus, forcedState: .focused)
            CYField(label: "Error 校验错误", placeholder: "", text: $fieldError, errorText: "输入金额须大于 ¥0.00", forcedState: .error("输入金额须大于 ¥0.00"))
            CYField(label: "Help 持久说明", placeholder: "输入核销备注", text: $fieldHelp, helperText: "仅向现场核销核对员展示。", forcedState: .help("仅向现场核销核对员展示。"))
            CYField(label: "Success 校验通过", placeholder: "", text: $fieldSuccess, isSuccess: true, forcedState: .success)
            CYField(label: "Disabled 禁用多行 (100pt)", placeholder: "", text: $fieldNotes, maxLength: 60, multiline: true, isDisabled: true, forcedState: .disabled)
        }
    }

    private var chromeBarsSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("Nav Bar / Footer Bar / Root Tab Bar")
            CYNavBar(title: "Solid 裸返回箭头", mode: .solid)
            CYNavBar(title: "Plain 无底栏", mode: .plain)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                    .fill(CYDomainPalette(domain).coverFallback)
                    .frame(height: 88)
                CYNavBar(title: "Overlay Hero 玻璃圆底", mode: .overlayHero)
            }

            CYFooterBar(primary: CYFooterAction("单主按钮 Pill", action: {}))
            CYFooterBar(
                primary: CYFooterAction("立即报名 (2 份宽)", action: {}),
                secondary: CYFooterAction("收藏 (1 份)", action: {})
            )

            CYRootTabBarStrip(selection: $selectedRootTab)
        }
    }

    // MARK: Part 4 Overlay / Feedback States

    private var sheetsAndModalsSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("Sheet & Modal · 玻璃面板 / 嵌套卡片 / 三段式危险弹窗")
            HStack(spacing: CYSpacing.sm) {
                CYButton(verbatim: "弹出 Option Sheet", variant: .secondary, size: .sm, isFullWidth: true) {
                    showFullSheet = true
                }
                CYButton(verbatim: "弹出破坏性 Modal", variant: .danger, size: .sm, isFullWidth: true) {
                    showModalOverlay = true
                }
            }

            CYSheetContainer(title: "Sheet 内嵌预览", onClose: {}) {
                VStack(spacing: CYSpacing.md) {
                    CYConfirmSheet(
                        title: "退出队伍？",
                        message: "退队后席位将自动放回队列。",
                        confirmTitle: "确认退出",
                        isDestructive: true,
                        consequences: [
                            CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: "无法保留已绑定的组队早鸟价"),
                        ],
                        onConfirm: {}
                    )
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))

            CYModal(
                title: "三段式销毁确认",
                message: "下架后新玩家将无法报名此活动，正在进行中的订单不受影响。",
                consequences: [
                    CYConfirmConsequence(systemImage: "eye.slash", text: "广场搜索与发现流立即隐藏"),
                    CYConfirmConsequence(systemImage: "clock", text: "已报名场次仍可正常核销"),
                ],
                cancelTitle: "取消",
                confirmTitle: "确认下架",
                lighterAlternativeTitle: "转为仅凭链接访问",
                isDestructive: true,
                onCancel: {},
                onLighterAlternative: {},
                onConfirm: {}
            )
            .panelCard
        }
    }

    private var toastsAndFeedbackStatesSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("Toast / Empty / Error / Skeleton Presets")
            VStack(spacing: CYSpacing.sm) {
                CYToastPill(verbatim: "提示 · 路线已离线缓存", tone: .info)
                CYToastPill(verbatim: "成功 · 草稿已保存到云端", tone: .success)
                CYToastPill(verbatim: "警告 · GPS 信号弱，请靠近地标", tone: .warning)
                CYToastPill(verbatim: "已移出收藏列表", tone: .undoable, undoTitle: "action.undo", onUndo: {})
            }
            CYButton(verbatim: "触发实时浮层 Toast", variant: .secondary, size: .sm, isFullWidth: true) {
                toastMessage = LocalizedStringKey("已加入待玩清单")
            }

            CYOfflineBanner(onRetry: {})
            CYInlineError(verbatim: "服务器返回异常 (ERR-502)，请核对原回执。", onRetry: {})

            CYEmptyState(systemImage: "ticket", "暂无已购门票", actionTitle: "去发现活动", action: {})
                .cyDomainCard()
            CYErrorState(onRetry: {})
                .cyDomainCard()

            CYSkeleton(variant: .feedCard)
            CYSkeleton(variant: .merchantMetric)
            CYSkeleton(variant: .routeTimeline)
            CYSkeleton(variant: .ticket)
        }
    }

    // MARK: Part 5 Chengyin Business Components

    private var activityAndRouteSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("5.1 Activity Card (248pt) & 5.2 Route Node")
            CYActivityFeedCard(
                title: "城南夜巷失踪的胶片",
                subtitle: "2.4 km · 预计 90 分钟 · 2–4 人 · 距起点 380m",
                capabilityTag: "可直接开局的模板",
                rareTrophyCount: 42,
                primaryTitle: "开始游玩",
                secondaryTitle: "查看详情",
                onPrimary: {},
                onSecondary: {}
            )

            VStack(spacing: 0) {
                CYRouteNodeRow(
                    index: 1,
                    title: "大栅栏百货旧址",
                    distanceAndETA: "已打卡 · 0 m · 19:15",
                    requirement: .gps,
                    completion: .completed,
                    isFirst: true
                )
                CYRouteNodeRow(
                    index: 2,
                    title: "青云胡同茶寮",
                    distanceAndETA: "350 m · 步行约 5 分钟",
                    requirement: .qr,
                    completion: .current,
                    perkTitle: "合作商户权益：盖章赠送桂花茶 1 杯",
                    perkActionTitle: "领取权益",
                    onPerkTap: {}
                )
                CYRouteNodeRow(
                    index: 3,
                    title: "天桥钟楼观景台",
                    distanceAndETA: "780 m · 步行约 11 分钟",
                    requirement: .photo,
                    completion: .locked,
                    isLast: true
                )
            }
            .cyDomainCard()
        }
    }

    private var taskStatusSixStatesSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("5.3 Task Status · 6 种法定状态与恢复链路")
            CYTaskStatusCard(
                title: "状态 1 · Locked 未解锁",
                state: .locked(requirement: "请先完成第 1 站「百货旧址」打卡后再解锁本站。", prereqTitle: "返回第 1 站", onOpenPrereq: {})
            )
            CYTaskStatusCard(
                title: "状态 2 · Available 可打卡",
                state: .available(methodLabel: "50m GPS 定位 + 现场扫码", ctaTitle: "开始打卡", onStart: {})
            )
            CYTaskStatusCard(
                title: "状态 3 · Submitting 提交中（锁重）",
                state: .submitting(requestId: "REQ-98214F")
            )
            CYTaskStatusCard(
                title: "状态 4 · Completed 已完成",
                state: .completed(receiptNo: "RCPT-2026-8841", completedAt: "19:24:09", onViewReceipt: {})
            )
            CYTaskStatusCard(
                title: "状态 5 · Retryable Failure 失败可恢复",
                state: .retryableFailure(
                    requestId: "REQ-98214F",
                    detail: "提交超时，可能已在服务端生效。保留同请求号防止重复扣减。",
                    onQueryOriginalReceipt: {},
                    onRetry: {}
                )
            )
            CYTaskStatusCard(
                title: "状态 6 · Offline Awaiting Sync 离线待同步",
                state: .offlineAwaitingSync(draftId: "DRAFT-04B", savedAt: "19:26", onSyncNow: {}, onViewDraft: {})
            )
        }
    }

    private var storyClueAndProgressSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("5.4 Story Clue & 5.5 Progress")
            CYStoryCluePanel(
                tiers: [
                    CYStoryClueTier(id: "t1", level: 1, title: "茶寮柜台上的旧票根", clueText: "票根背面的四位日期连起来就是密码箱前四位（1984）。", pointsCost: 0, isUnlocked: true),
                    CYStoryClueTier(id: "t2", level: 2, title: "柜台暗格钥匙方位", clueText: nil, pointsCost: 20, isUnlocked: false),
                    CYStoryClueTier(id: "t3", level: 3, title: "直通终局密码", clueText: nil, pointsCost: 50, isUnlocked: false),
                ],
                freeHintsRemaining: 0,
                onUnlockTier: { _ in }
            )

            CYProgressBar(title: "路线进度（真实计数）", completed: 3, total: 8)
            CYProgressBar(title: "路线进度（读取失败时不伪造 0%）", completed: nil, total: 8, loadFailed: true, onRetry: {})
        }
    }

    private var registrationTeamPublishSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            groupTitle("5.6 Registration / 5.7 Team Row / 5.8 Publish Status")
            CYRegistrationSummaryCard(
                slots: [
                    CYRegistrationSlot(id: "slot-sat", label: "周六 19:00", seatsLeftText: "余 6"),
                    CYRegistrationSlot(id: "slot-sun", label: "周日 15:00", seatsLeftText: "已满", isAvailable: false),
                ],
                selectedSlotID: $selectedSlotID,
                attendeeCount: $attendees,
                originalAmountText: "¥256.00",
                discountText: "-¥36.00",
                totalAmountText: "¥220.00",
                onSubmit: {}
            )

            VStack(spacing: CYSpacing.md) {
                CYTeamMemberRow(seatNumber: 1, occupantName: "林致远", isBuyer: true, status: .claimed)
                CYTeamMemberRow(seatNumber: 2, occupantName: nil, status: .pending, expiresAtText: "今日 21:00", issuedInviteToken: "CY-JOIN-7741", canRevoke: true, onRevoke: {})
                CYTeamMemberRow(seatNumber: 3, occupantName: "周可心", status: .claimed, canRelease: true, onRelease: {})
                CYTeamMemberRow(seatNumber: 4, occupantName: nil, status: .expired)
            }

            CYPublishStatusBar(
                currentStep: publishStep,
                saveState: .savedDraft(updatedAt: "19:30"),
                issues: [],
                onSelectStep: { publishStep = $0 },
                onSubmitReview: {}
            )
            CYPublishStatusBar(
                currentStep: 2,
                saveState: .saveFailed(reason: "草稿同步冲突，请保存后再提交审核。", onRetry: {}),
                issues: [CYPublishValidationIssue(id: "price", stepIndex: 2, message: "需设置至少 1 个有效可售场次")],
                onSelectStep: { _ in },
                onSubmitReview: {}
            )
        }
    }
}

#Preview("Design Kit · Player / Merchant") {
    DesignKitFixture()
}
#endif
