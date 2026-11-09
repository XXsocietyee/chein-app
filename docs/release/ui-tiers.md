# UI tiers

Source: every data row of `docs/parity/page-map.csv` (163 rows) on `rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. This note only classifies those rows. It does not edit a view, deploy, or refresh the CI ledger.

Counts: **T1 20**, **T2 60**, **T3 83**. The three sets are disjoint and their union is the whole map.

## Rule

T1 is the launch path. A row is T1 when a first guest or signed-in session has to render it to use a player tab, open a route, open an activity, register, play, check in, see the ticket or the order, open growth, or reach privacy, the user agreement, or settings. The cap is 20. The `#` column is the 1-based data-row index in `page-map.csv`.

T2 is the next ring: one step out from a T1 screen, the merchant front door a role switch opens, or a legacy link that still draws its own unavailable screen. Each T2 row has one archetype: `list`, `detail`, `form`, `settings`, `chat`, or `empty/error`. The band is 60 rows.

T3 is every remaining row. The work for T3 is the theme layer only: player stays dark, merchant stays light, and the screen keeps the shared tokens. T3 does not get a per-screen layout pass.

A row whose status is `merged-into:` is T3. The canonical screen it names keeps that screen's own tier. The one `dropped:` row still presents its own retired landing, so it is T2 `empty/error`.

## Files excluded

`docs/release/design-spec-d1.md` is the only `docs/release/design-spec-d*.md` file in this tree. The views it owns are not tier targets. No page-map `target_native_screen` is one of these files. Two notes mention one of them; the row stays classified on its own screen file.

| Spec section | Owned file | Page-map effect |
|---|---|---|
| 1 Welcome | `App/WelcomeView.swift` | No page-map row. Welcome is outside this map. |
| 2 Consent gate | `App/UsageConsentGateView.swift` | Cited by the notes of `pages/privacy/index`. That row is T1 on `App/PrivacyProtectionView.swift` only. |
| 3 Login | `App/LoginView.swift` | No page-map row. |
| 3 Login | `App/AuthChannelView.swift` | No page-map row. |
| 3 WeChat section | `App/WeChatAppAuthSection.swift` | No page-map row. The spec names the WeChat section; this is that view. |
| 4 Role picker | `App/ClubRoleAssignmentPicker.swift` | Cited by the notes of `pages/club/roles/index`. That row is T3 on `App/ClubOpsGovernanceSections.swift` only. |

## T1 — launch-critical (20)

Two of these rows are still `partial` in the map (`pages/template/index`, `pages/play/index`). They stay T1 because the publish tab and the play session are on the launch path. The tier does not claim the gated writes inside them are done.

| # | mini_path | feature | screen | status | why |
|---:|---|---|---|---|---|
| 1 | `pages/index/index` | 首页发现流 (推荐路线/近期活动/继续探索/固定入口) | `App/HomeFeedView.swift` | exists | Player home tab. First screen after welcome or guest browse. |
| 2 | `pages/template/index` | 发布与玩法模板库 Tab | `App/DiscoveryTemplateBrowserView.swift` | partial | Publish tab root. Always in the player tab bar. |
| 3 | `pages/talent/list/index` | 俱乐部 Tab (帖文/俱乐部双栏与未读消息入口) | `App/ClubHomeView.swift` | exists | Club tab root. Posts, clubs, and the message entry. |
| 4 | `pages/member/index/index` | 我的主页 Tab (身份卡/票夹入口/资产预览/权益) | `App/AccountView.swift` | exists | Mine tab root for a signed-in account. |
| 5 | `pages/roam/index` | 漫游首页与漫游护照 Tab | `App/RoamBrowserView.swift` | exists | Roam tab root. Map exploration and the passport start. |
| 6 | `pages/privacy/index` | 隐私保护与同意撤回 | `App/PrivacyProtectionView.swift` | exists | Privacy policy and consent withdrawal. |
| 7 | `pages/agreement/index` | 用户服务协议与法律文档 | `App/SettingsLegalDocumentView.swift` | exists | User agreement. |
| 9 | `pages/team/detail/index` | 队伍详情与成员管理 | `App/TeamHomeView.swift` | exists | Team the session is playing with. |
| 11 | `pages/play/index` | 游玩运行态主容器 (剧本/定向/自由探索/背包/入场码) | `App/PlayExperienceView.swift` | partial | Running play session. |
| 15 | `pages/activity/detail/index` | 活动详情页 (票种/集合点/报名状态) | `App/ActivityDetailView.swift` | exists | Activity opened from home, roam, and the list. |
| 16 | `pages/activity/baoming/baoming` | 活动报名结算页 | `App/RegistrationSheetView.swift` | exists | Registration checkout for a paid or free activity. |
| 17 | `pages/activity/list/index` | 官方活动列表页 | `App/OfficialEventsBrowserView.swift` | exists | Official activity list opened from the home shelf. |
| 28 | `subpackageP3/pages/growthcenter/index/index` | 成长中心 (等级/经验/已完成路线) | `App/GrowthCenterView.swift` | exists | Growth home. Level, experience, finished routes. |
| 62 | `pages/topic/index/index` | 主题详情页 (详情/路线节点/路线三栏与报名) | `App/TopicDetailView.swift` | exists | Route opened from home and from roam. |
| 104 | `pages/search2/index` | 全局搜索入口 (历史/推荐/分类/筛选) | `App/GlobalSearchView.swift` | exists | Search entry, including its result tabs and map mode. |
| 112 | `pages/shezhi/shezhi` | 设置主页 | `App/SettingsView.swift` | exists | Settings. Sign-out and the legal entries. |
| 136 | `subpackageMember/order/order` | 我的订单列表 (9 状态筛选) | `App/ProfileOrdersView.swift` | exists | Order list after registration. |
| 137 | `subpackageMember/orderinfo/orderinfo` | 订单详情与状态时间线 | `App/OrderLifecycleView.swift` | exists | Order receipt and cancel or refund state. |
| 142 | `subpackageMember/signup/index` | 票夹 (待核销/游玩入场凭证) | `App/TicketWalletView.swift` | exists | Ticket wallet. The pass that lets play start. |
| 147 | `subpackageRoam/poi-detail/index` | 漫游据点详情页 | `App/RoamItemDetailView.swift` | exists | Check-in at a roam point. |

Search's result tabs and map mode are part of `pages/search2/index`. The separate map and result rows are T3 duplicates, not a second launch screen.

## T2 — mid (60)

Archetypes name the primary structure, not every state the screen can show:

- `list` — a feed, inbox, ledger, grid, or other collection the person scans.
- `detail` — one object, one document, one code, or one dashboard.
- `form` — create, edit, apply, capture, or a wizard.
- `settings` — a preference or legal-adjacent control screen under settings.
- `chat` — a conversation transcript.
- `empty/error` — the screen's job is a retired or unavailable landing.

| # | mini_path | feature | screen | status | archetype |
|---:|---|---|---|---|---|
| 8 | `pages/deregister/index` | 注销账号流程 | `App/AccountComplianceViews.swift` | exists | `form` |
| 10 | `pages/team/join/index` | 队伍邀请加入页 | `App/TeamHomeView.swift` | exists | `detail` |
| 13 | `pages/play/circle/index` | 商圈自由探索旧版重定向壳 | `App/PlayPlayerAndCircleViews.swift` | dropped:retired-redirect-shell-in-xcx | `empty/error` |
| 14 | `pages/play/poi-challenge/index` | 据点限时/传感器挑战组件页 | `App/PlayKitTimedChallengeView.swift` | exists | `detail` |
| 18 | `pages/activity/official-detail/index` | 官方活动详情页 | `App/OfficialEventDetailView.swift` | exists | `detail` |
| 19 | `pages/activity/official-inbox/index` | 官方活动邀约收件箱 | `App/OfficialPrivateViews.swift` | exists | `list` |
| 23 | `subpackageA/pages/infomation/infomation` | 城瘾玩法指南列表 | `App/SocialGuideViews.swift` | partial | `list` |
| 24 | `subpackageA/pages/infomationdetail/infomationdetail` | 玩法详情文档页 | `App/SocialGuideViews.swift` | exists | `detail` |
| 25 | `subpackageA/pages/assetcenter/income-detail/income-detail` | 收益明细 (含主办分润四栏) | `App/WalletCommerceViews.swift` | exists | `list` |
| 26 | `subpackageA/pages/assetcenter/earnings/index` | 账户收益总览与提现入口 | `App/WalletCommerceViews.swift` | exists | `detail` |
| 27 | `subpackageA/pages/assetcenter/analysis/index` | 资产余额变动分析明细 | `App/WalletCommerceViews.swift` | exists | `list` |
| 29 | `subpackageP3/pages/growthcenter/leaderboard/index` | 完整排行榜 | `App/GrowthLeaderboardView.swift` | exists | `list` |
| 30 | `subpackageP3/pages/stamp-camera/index/index` | 印章相机拍摄与合成页 | `App/RoamStampCameraView.swift` | partial | `form` |
| 31 | `subpackageP3/pages/stamp-album/index/index` | 集邮册拼贴画廊 | `App/RoamStampViews.swift` | partial | `list` |
| 32 | `subpackageP3/pages/badge-wall/index/index` | 勋章墙展示页 | `App/ObjectBadgeViews.swift` | exists | `list` |
| 33 | `subpackageP3/pages/badge-3d/index` | 3D 勋章预览页 | `App/ObjectBadgeViews.swift` | exists | `detail` |
| 34 | `subpackageP3/pages/object-cards/index/index` | 藏品册 (物件卡收集与重命名) | `App/ObjectCardViews.swift` | exists | `list` |
| 35 | `subpackageB/pages/im/list/index` | 消息中心列表 (私信/系统通知) | `App/MessagingHomeView.swift` | partial | `list` |
| 36 | `subpackageB/pages/im/chat/index` | 聊天会话详情页 | `App/MessagingHistoryView.swift` | partial | `chat` |
| 40 | `pages/publish/activity/index` | 发布活动三步向导 | `App/PublishingModesViews.swift` | exists | `form` |
| 43 | `pages/club/apply/index` | 申请成为俱乐部主理人 | `App/ClubGovernanceViews.swift` | partial | `form` |
| 45 | `pages/club/create/index` | 创建俱乐部 | `App/ClubOperationsViews.swift` | partial | `form` |
| 48 | `pages/club/detail/index` | 俱乐部主页 (帖子/活动/概览/管理四栏) | `App/ClubDetailView.swift` | partial | `detail` |
| 67 | `pages/merchant/index/index` | 商家工作台主页 | `App/MerchantHomeView.swift` | exists | `detail` |
| 68 | `pages/merchant/apply/index` | 商家入驻申请 | `App/MerchantOnboardingView.swift` | gated | `form` |
| 69 | `pages/merchant/ledger/index` | 商家核销与退款台账 | `App/MerchantBusinessViews.swift` | exists | `list` |
| 72 | `pages/merchant/aftercare/index` | 商家退款售后列表 | `App/MerchantBusinessViews.swift` | exists | `list` |
| 75 | `pages/merchant/profile/index` | 商家公开主页 | `App/PublicMerchantHomeView.swift` | exists | `detail` |
| 76 | `pages/merchant/marketing/index` | 商家营销中心看板 | `App/MerchantMarketingView.swift` | exists | `detail` |
| 77 | `pages/merchant/reviews/index` | 商家口碑评价管理 | `App/MerchantBusinessViews.swift` | partial | `list` |
| 79 | `pages/merchant/relation/index` | 商家合作发现页 | `App/CoopRelationDiscoveryView.swift` | partial | `list` |
| 87 | `pages/merchant/coop-center/index` | 商家合作中心 (官方活动/广场商机) | `App/MerchantCoopCenterView.swift` | exists | `list` |
| 94 | `pages/coop/list/index` | 协作邀请列表 (收到/发出/官方/章节) | `App/CooperationBrowserView.swift` | exists | `list` |
| 95 | `pages/coop/invite-detail/index` | 协作邀请详情与条款 | `App/CooperationInviteDetailView.swift` | exists | `detail` |
| 96 | `pages/coop/invite/index` | 发起协作邀请与批量邀约 | `App/CooperationContextualViews.swift` | exists | `form` |
| 97 | `pages/coop/nearby/index` | 附近可合作商家发现 | `App/NearbyMerchantView.swift` | exists | `list` |
| 103 | `pages/square/detail/index` | 动态详情与评论互动 | `App/SquareDetailView.swift` | exists | `detail` |
| 107 | `pages/templatedetail/templatedetail` | 玩法模板详情与节点交互预览 | `App/DiscoveryTemplateDetailView.swift` | exists | `detail` |
| 110 | `pages/address/address` | 常用参与人信息列表 | `App/ProfileParticipantsView.swift` | partial | `list` |
| 111 | `pages/addressinfo/addressinfo` | 新增与编辑参与人信息 | `App/ParticipantFormView.swift` | exists | `form` |
| 113 | `pages/shezhi/about/index` | 关于城瘾与版本信息 | `App/SettingsAboutView.swift` | exists | `settings` |
| 114 | `pages/shezhi/marketing/index` | 营销消息与优惠券偏好设置 | `App/MarketingConsentOriginalPresentation.swift` | exists | `settings` |
| 115 | `pages/gerenziliao/gerenziliao` | 编辑个人资料 | `App/ProfileEditView.swift` | gated | `form` |
| 116 | `pages/userinfo/userinfo` | 玩家公开个人主页 | `App/SocialPublicProfileView.swift` | exists | `detail` |
| 117 | `pages/mylike/mylike` | 我的收藏 (帖文/主题) | `App/AccountCollectionFavoritesView.swift` | exists | `list` |
| 127 | `subpackageMember/complaint/index` | 投诉与建议提交与进度 | `App/ProfileComplaintPreparationView.swift` | gated | `form` |
| 128 | `subpackageMember/coupon-wallet/index` | 玩家优惠券卡包 | `App/AccountCollectionCouponsView.swift` | exists | `list` |
| 129 | `subpackageMember/coupon-qr/index` | 优惠券动态核销码出示页 | `App/CouponCodeView.swift` | exists | `detail` |
| 132 | `subpackageMember/mycanyu/mycanyu` | 我的参与记录列表 | `App/PlayerJourneyViews.swift` | exists | `list` |
| 133 | `subpackageMember/mycanyuinfo/mycanyuinfo` | 我的参与记录详情 | `App/PlayerJourneyViews.swift` | exists | `detail` |
| 138 | `subpackageMember/points-history/index` | 积分收支明细 | `App/ProfileWeeklyPointsSection.swift` | exists | `list` |
| 139 | `subpackageMember/report-mine/index` | 我的举报记录列表 | `App/SquareReportProgressView.swift` | exists | `list` |
| 143 | `subpackageMember/tixian/tixian` | 提现申请与资金阶段说明 | `App/WithdrawalSupportLandingView.swift` | exists | `form` |
| 144 | `subpackageMember/tixianjilu/tixianjilu` | 提现记录列表 | `App/WithdrawalHistoryView.swift` | exists | `list` |
| 146 | `subpackageRoam/history/index` | 漫游历史足迹列表与分享快照 | `App/RoamHistoryViews.swift` | partial | `list` |
| 148 | `subpackageRoam/session/index` | 漫游单次行程记录详情 | `App/RoamSubpageParityViews.swift` | exists | `detail` |
| 149 | `subpackageRoam/nearby/index` | 附近招募队伍与漫游据点地图 | `App/NearbyTeamViews.swift` | exists | `list` |
| 151 | `subpackageRoam/my-teams/index` | 我的队伍与附近招募页 | `App/NearbyTeamViews.swift` | exists | `list` |
| 152 | `subpackageRoam/official-routes/index` | 官方推荐漫游线路列表 | `App/RoamBrowserView.swift` | exists | `list` |
| 153 | `subpackageRoam/official-route/index` | 官方推荐漫游线路详情 | `App/RoamSubpageParityViews.swift` | exists | `detail` |

## T3 — theme layer only (83)

These rows are covered by the role theme and the shared tokens. This plan does not assign them a separate layout. Merged duplicate rows are in this band even when their canonical screen is T1 or T2.

| # | mini_path | feature | screen | status | layer |
|---:|---|---|---|---|---|
| 12 | `pages/play/merchant/index` | 探店日商家互动与核销页 | `App/PlayStoreDayMerchantView.swift` | gated | theme |
| 20 | `pages/activity/official-mine/index` | 我发布的官方活动与广播 | `App/OfficialPrivateViews.swift` | exists | theme |
| 21 | `pages/activity/official-organizer/index` | 官方活动主办控制台 | `App/OfficialOrganizerConsoleView.swift` | exists | theme |
| 22 | `subpackageA/pages/myproject/index` | 我的项目 (主题/活动/模板三栏管理) | `App/CreatorContentViews.swift` | partial | theme |
| 37 | `pages/publish/fabu/index` | 专业主题编辑器 | `App/ProjectEditView.swift` | gated | theme |
| 38 | `pages/publish/simple/index` | AI 快速发布向导 | `App/PublishingModesViews.swift` | partial | theme |
| 39 | `pages/publish/temp/index` | 节点玩法模板编辑器 | `App/TemplateAuthoringView.swift` | gated | theme |
| 41 | `pages/publish/topicadd/topicadd` | 专业手动编辑旧版入口 | `App/ProjectEditView.swift` | merged-into:pages/publish/fabu/index | theme |
| 42 | `pages/publish/template-intro/index` | 创建节点玩法引导页 | `App/TemplateAuthoringIntroExperience.swift` | exists | theme |
| 44 | `pages/club/badges/index` | 俱乐部专属勋章管理与授予 | `App/ClubBadgeManagementView.swift` | partial | theme |
| 46 | `pages/club/customer-detail/index` | 俱乐部客户详情与标签备注 | `App/ClubOpsCustomerViews.swift` | exists | theme |
| 47 | `pages/club/customers/index` | 俱乐部客户名册 | `App/ClubOpsCustomerViews.swift` | exists | theme |
| 49 | `pages/club/edit/index` | 编辑俱乐部资料与解散 | `App/ClubOperationsViews.swift` | partial | theme |
| 50 | `pages/club/enroll/index` | 俱乐部主题报名名单管理 | `App/ClubEnrollmentView.swift` | exists | theme |
| 51 | `pages/club/checkin-detail/index` | 俱乐部核销记录详情与退票 | `App/ClubGovernanceViews.swift` | exists | theme |
| 52 | `pages/club/event-ops/index` | 俱乐部活动运营 (场次/名单/候补) | `App/ClubOpsEventView.swift` | exists | theme |
| 53 | `pages/club/governance/index` | 俱乐部社区治理与处罚申诉 | `App/ClubOpsGovernanceSections.swift` | partial | theme |
| 54 | `pages/club/group-code/index` | 俱乐部团核销码签发页 | `App/ClubGovernanceViews.swift` | partial | theme |
| 55 | `pages/club/join-requests/index` | 俱乐部入会申请审核 | `App/ClubManagementView.swift` | gated | theme |
| 56 | `pages/club/notify/index` | 俱乐部群发通知 | `App/ClubOpsNotifySections.swift` | exists | theme |
| 57 | `pages/club/roles/index` | 俱乐部成员角色与权限分配 | `App/ClubOpsGovernanceSections.swift` | gated | theme |
| 58 | `pages/club/settlement/index` | 俱乐部结算与分润汇总 | `App/ClubOpsSettlementViews.swift` | exists | theme |
| 59 | `pages/club/topic-detail/index` | 俱乐部主办主题运营控台 | `App/ClubGovernanceViews.swift` | partial | theme |
| 60 | `pages/club/topic-story/index` | 俱乐部剧情与节点答案查看 | `App/ClubGovernanceViews.swift` | exists | theme |
| 61 | `pages/club/workbench/index` | 俱乐部工作台旧版跳转壳 | `App/ClubDetailView.swift` | merged-into:pages/club/detail/index | theme |
| 63 | `pages/topic/merchantinfo/merchantinfo` | 主题商家视角与章节承接 | `App/MerchantContentViews.swift` | partial | theme |
| 64 | `pages/topic/merchantapply/index` | 商家报名承接主题页 | `App/MerchantContentEditor.swift` | exists | theme |
| 65 | `pages/topic/pricing/index` | 主题定价与分润配置 | `App/PublisherLifecycleViews.swift` | exists | theme |
| 66 | `pages/topic/pricing/partner/index` | 合作方分润预览页 | `App/PublisherLifecycleViews.swift` | exists | theme |
| 70 | `pages/merchant/ledger/order-detail/index` | 商家核销订单详情 | `App/MerchantBusinessViews.swift` | exists | theme |
| 71 | `pages/merchant/ledger/batch-detail/index` | 商家对公结算批次详情 | `App/MerchantSettlementProgressView.swift` | exists | theme |
| 73 | `pages/merchant/predict/index` | 商家竞猜待答收件箱 | `App/MerchantPredictionInboxView.swift` | gated | theme |
| 74 | `pages/merchant/aftercare/detail/index` | 商家退款售后详情与处理 | `App/MerchantAftercareProgressView.swift` | gated | theme |
| 78 | `pages/merchant/marketing/ai-insight/index` | AI 店铺参谋经营解读 | `App/MerchantMarketingView.swift` | exists | theme |
| 80 | `pages/merchant/citynode/index` | 成为城市节点管理中心 | `App/MerchantCityNodeHubView.swift` | partial | theme |
| 81 | `pages/merchant/citynode/create/index` | 报名成为城市节点 | `App/MerchantCityNodeCreateView.swift` | exists | theme |
| 82 | `pages/merchant/decor/index` | 品牌中心 (门店装修与经营设置) | `App/MerchantOperationsViews.swift` | partial | theme |
| 83 | `pages/merchant/decor/ai-npc/index` | AI 店铺角色配置 | `App/MerchantStoreCharacterView.swift` | gated | theme |
| 84 | `pages/merchant/decor/coop-setting/index` | 商家承接设置 | `App/MerchantOperationsViews.swift` | gated | theme |
| 85 | `pages/merchant/decor/gallery/index` | 门店相册管理 | `App/MerchantOperationsViews.swift` | gated | theme |
| 86 | `pages/merchant/decor/perks/index` | 门店常备权益管理 | `App/MerchantOperationsViews.swift` | partial | theme |
| 88 | `pages/merchant/customer/index` | 商家客户名册与分群导出 | `App/MerchantBusinessViews.swift` | exists | theme |
| 89 | `pages/merchant/game-node/index` | 本站准备与运行工作台 | `App/MerchantGameNodeView.swift` | exists | theme |
| 90 | `pages/merchant/customer/detail/index` | 商家客户详情与互动记录 | `App/MerchantCustomerDetailSections.swift` | partial | theme |
| 91 | `pages/merchant/verify-records/index` | 商家核销记录明细 | `App/MerchantBusinessViews.swift` | exists | theme |
| 92 | `pages/merchant/crm-campaigns/index` | 商家客户触达与营销活动 | `App/MerchantEngagementViews.swift` | exists | theme |
| 93 | `pages/merchant/team/index` | 商家经营团队与员工权限 | `App/MerchantBusinessViews.swift` | exists | theme |
| 98 | `pages/coop/finance/index` | 协作分润明细 | `App/CoopFinanceProfitView.swift` | exists | theme |
| 99 | `pages/coop/settlement-detail/index` | 协作与俱乐部结算单详情 | `App/CoopSettlementDetailView.swift` | exists | theme |
| 100 | `pages/coop/withdraw/index` | 协作收益提现跳转壳 | `App/CoopWithdrawShellViews.swift` | merged-into:subpackageMember/tixian/tixian | theme |
| 101 | `pages/coop/withdraw/records/index` | 协作提现记录跳转壳 | `App/CoopWithdrawShellViews.swift` | merged-into:subpackageMember/tixianjilu/tixianjilu | theme |
| 102 | `pages/square/list/index` | 创意广场动态流 | `App/SquareBrowserView.swift` | merged-into:pages/talent/list/index | theme |
| 105 | `pages/search2/result/index` | 全局搜索结果页 (全部/路线/活动/俱乐部/商家) | `App/GlobalSearchView.swift` | merged-into:pages/search2/index | theme |
| 106 | `pages/searchmap/index` | 地图搜索点位与活动页 | `App/SearchMapExplorerView.swift` | merged-into:pages/search2/index | theme |
| 108 | `pages/templatedetail/topic-preview/index` | 主题模板预览页 | `App/DiscoveryTemplateDetailView.swift` | merged-into:pages/templatedetail/templatedetail | theme |
| 109 | `pages/templatedetail/topic-detail/index` | 主题模板详情页 | `App/DiscoveryTemplateDetailView.swift` | merged-into:pages/templatedetail/templatedetail | theme |
| 118 | `pages/crop/index` | 图片裁剪工具页 | `App/TemplateImageCropView.swift` | exists | theme |
| 119 | `subpackageMember/free-explore/index` | 自由探索权益包购买与退订 | `App/FreeExploreBundleLaunchView.swift` | partial | theme |
| 120 | `subpackageMember/character/index` | 我的角色卡 (RPG 属性与称号) | `App/CharacterCardReadbackView.swift` | partial | theme |
| 121 | `subpackageMember/orient-score/index` | 本局定向计分与成绩核对 | `App/OrientScoreView.swift` | partial | theme |
| 122 | `subpackageMember/invoice/index` | 我的发票记录列表 | `App/InvoiceLaunchHistoryView.swift` | exists | theme |
| 123 | `subpackageMember/invoice-detail/index` | 发票详情页 | `App/InvoiceLaunchDetailView.swift` | exists | theme |
| 124 | `subpackageMember/invoice-apply/index` | 申请开具发票 | `App/InvoiceLaunchApplyView.swift` | partial | theme |
| 125 | `subpackageMember/invoice-titles/index` | 发票抬头列表 | `App/InvoiceLaunchTitlesView.swift` | exists | theme |
| 126 | `subpackageMember/invoice-title-edit/index` | 新增与编辑发票抬头 | `App/InvoiceLaunchTitleEditor.swift` | exists | theme |
| 130 | `subpackageMember/coupon/coupon` | 商家我发布的优惠券管理 | `App/CouponManagementView.swift` | exists | theme |
| 131 | `subpackageMember/couponInfo/couponInfo` | 创建与编辑优惠券设置 | `App/CouponManagementView.swift` | partial | theme |
| 134 | `subpackageMember/myinvite/myinvite` | 好友邀请记录与奖励明细 | `App/SocialInviteHistoryView.swift` | exists | theme |
| 135 | `subpackageMember/mytemplate/mytemplate` | 我的节点玩法模板管理 | `App/TemplateAuthoringMineView.swift` | gated | theme |
| 140 | `subpackageMember/report-detail/index` | 举报处理进度详情与申诉 | `App/MemberReportProgressDetailView.swift` | exists | theme |
| 141 | `subpackageMember/appeal-mine/index` | 我的信誉与计分申诉列表 | `App/MemberScoreAppealListView.swift` | exists | theme |
| 145 | `subpackageRoam/citynode-code/index` | 城市据点动态核销码页 | `App/VerificationCodeView.swift` | exists | theme |
| 150 | `subpackageRoam/citystamp/index` | 城市印章拍照与交换三步流 | `App/RoamSubpageParityViews.swift` | partial | theme |
| 154 | `subpackageTools/capsule/index` | 时光胶囊封存与开启 | `App/RoamPassportPrivateToolsViews.swift` | partial | theme |
| 155 | `subpackageTools/monthly-recap/index` | 漫游月度回顾 | `App/RoamPassportToolsViews.swift` | partial | theme |
| 156 | `subpackageTools/exploration-goals/index` | 个人探索目标管理 | `App/RoamPassportPrivateToolsViews.swift` | exists | theme |
| 157 | `subpackageTools/anniversary/index` | 那年今日探索纪念 | `App/RoamPassportToolsViews.swift` | partial | theme |
| 158 | `subpackageTools/exploration-export/index` | 分块导出探索记录 (JSONL) | `App/RoamExplorationExportView.swift` | partial | theme |
| 159 | `pages/templatedetail2/templatedetail2` | 旧版第二套模板详情页 (路线图标记重复页) | `App/DiscoveryTemplateDetailView.swift` | merged-into:pages/templatedetail/templatedetail | theme |
| 160 | `subpackageMember/signupInfo/signupInfo` | 旧版票券详情页 v1 (路线图标记重复页) | `App/TicketWalletView.swift` | merged-into:subpackageMember/signup/index | theme |
| 161 | `subpackageMember/signupInfo2/signupInfo2` | 旧版票券核销与详情页 v2 (路线图标记重复页) | `App/TicketWalletView.swift` | merged-into:subpackageMember/signup/index | theme |
| 162 | `pages/topic/settlement/index` | 旧版主题独立结算页 (路线图标记重复结算页) | `App/CoopSettlementDetailView.swift` | merged-into:pages/coop/settlement-detail/index | theme |
| 163 | `pages/talent/search/index` | 旧版俱乐部独立搜索页 (路线图三合一搜索项) | `App/GlobalSearchView.swift` | merged-into:pages/search2/index | theme |

## Out of scope

No view file is edited. Nothing is deployed. The CI ledger is not refreshed.
