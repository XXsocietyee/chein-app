# U9 screenshot parity: domains C, D, E (receipt)

Branch `ui/u9-cde`, rebased on `origin/ui/next` (5530ea560). Code only: no xcodebuild or simulator run, so the integrator must compile.
References: the private mini-program matrix `1c80c5a-matrix` (65 non-merchant rows whose id starts with C, D or E) and the `chengyinhub-xcx` source.
No screenshots were committed or posted.

Checks run here: `tools/check_scaffold.py` PASS and `tools/check_design_lint.py` PASS. No Swift files were added, so `generate_project.py` was not needed.
I also ran every ContractChecks module that names a changed file (268 modules) and compared the result with the base tree. My changes introduced 4 new failures; all 4 are fixed, by reverting the change or by keeping the exact pinned source string. The other 38 modules also fail on the base tree, for reasons unrelated to this work.

New strings live in `tools/add_u9_cde_localizations.py`. They use the `u9cde.*` prefix, have EN and zh-Hans, and the script is idempotent.

| row id | route | state | native file | gaps found | fixed | left (needs logic or decision) |
|---|---|---|---|---|---|---|
| C23 | pages/topic/index?id=9 | normal | App/TopicDetailView.swift | Cover CTA 查看详情与报名 missing | Added a CTA that scrolls to the 详情 anchor (`topic.cover.details`) | The full-screen cover slide is still the native gallery |
| C24 | pages/topic/index?id=9 (路线 tab) | normal | App/TopicXcxSections.swift | 固定路线 / 没有固定路线 note missing; empty title should read 路线配置中 | Added the route note chip (`topic.route.note`) and the 路线配置中 title above the existing empty line | Bookmark/share buttons, 主题徽章 stat cell and per-stop thumbnails need data and a share decision |
| C25 | pages/topic/index | missing-param | Core/MiniProgramPages.swift → `.unsupported` | MP shows 无法打开主题 + 返回发布广场 | — | Needs router logic: a topic route with no id goes to the generic unsupported screen |
| C38 | pages/club/apply | form (unmet, intro shown) | App/ClubGovernanceViews.swift | Intro had two extra benefit rows | Intro is now the large two-line title plus the 成为主理人 CTA | — |
| C39 | pages/club/apply | success | App/ClubGovernanceViews.swift | Done card used a 已成为主理人 header and a Status row instead of the 已生效 chip | Card now shows the 已生效 chip, then 可建俱乐部 / 最多 2 个 | 创建我的俱乐部 CTA needs ClubOperationsAccess wired into the governance read |
| C40–C43 | pages/club/create | form (C41–43 stale, identical PNG) | App/ClubOperationsViews.swift (stepped create) | None: intro 建一个俱乐部 + 开始创建 already match | — | — |
| C44 | pages/club/detail?id=1 | normal (member) | App/ClubDetailView.swift | Club logo next to the name missing; tab label is 帖文 in source | Added a logo tile when an https logo exists (`club.detail.logo`) | 帖文 vs 帖子: `club.detail.tab.posts` = 帖子 is pinned by two contract tests (`test_club_detail_tabs`, `test_club_detail_page_ready`), so this needs a decision; hero share button and posts composer row |
| C45 | pages/club/detail?id=1 | permission (owner) | App/ClubDetailView.swift | Same as C44, plus the 管理 tab and settings gear | Logo (as C44); 管理 tab already present | Same as C44 |
| C46 | pages/club/edit?id=1 | form | App/ClubOperationsViews.swift | Admin note sits under the title in MP but inside 基础信息 in native | — (reverted) | The placement is pinned by `test_club_member_pages`; moving it needs a decision |
| C47, C48 | pages/club/enroll?clubId=1 | normal | App/ClubEnrollmentView.swift | Header was a big 团数 figure plus the club name; MP has one line 「俱乐部名 · N 个团」. Team meta should read 已报名 N 人 | Single sub line (fallback 我的俱乐部); 已报名 N 人 (— when unknown); escrow line kept (contract-pinned) | — |
| C49 | pages/club/enroll | empty | App/ClubEnrollmentView.swift | Matches (还没有城市定向团) | Sub line (as above) | — |
| C50 | pages/club/enroll | permission | App/ClubEnrollmentView.swift | MP uses a sheet; native uses the inline denied title + banner | — | Sheet vs inline presentation is a decision |
| C51 | pages/club/group-code?id=1 | sheet | App/ClubGovernanceViews.swift (topic overview sessions) | MP has a dedicated 选择场次 list; native folds group code into 接下来 sessions | — | Structural decision (separate page) |
| D01 | subpackageMember/order/order | empty | App/ProfileOrdersView.swift | Filter chips hidden when empty | — | Chips on the empty state need the list restructured |
| D02 | …/order | normal (pending) | App/ProfileOrdersView.swift | Card showed the order number (source moved it to the detail page); state was not on the mode-tag line; label should be 待付款 | Card is now cover · mode tag + state / name / time / place, then 待付款/实付款 + action; number removed from the card | 取消订单 / 立即支付 stay on the detail page behind the payment gate |
| D03 | …/order | normal (ended) | App/ProfileOrdersView.swift | MP shows no action on closed orders | Pill hidden unless registrationStatus is 1/2; 查看退款详情 for refunds | — |
| D04 | …/order | normal (in progress) | App/ProfileOrdersView.swift | Card anatomy | Fixed (as D02) | — |
| D05 | …/order | loading | ProfileReadScreen (shared) | Skeleton matches | — | — |
| D07 | subpackageMember/orderinfo?id=1001 | normal (refund) | App/ProfileOrdersView.swift (ProfileOrderDetailView) | MP: hero (cover, title, state) → 订单明细 → 支付明细 → 订单进度; native puts the title in a row and the timeline later | — | Money page; reordering sections needs a decision |
| D08 | subpackageMember/mycanyu | normal | App/PlayerJourneyViews.swift | Card was cover on top; MP has cover left, text right, clock icon | Horizontal card (stacks at accessibility sizes); CYNight.ink2 placeholder | — |
| D09 | …/mycanyu | empty | App/PlayerJourneyViews.swift | MP shows only the title (native adds detail copy) | — | — |
| D10 | …/mycanyu | error | App/PlayerJourneyViews.swift | MP silently shows a blank list; native shows an error with retry | — (native kept) | — |
| D11 | subpackageMember/mycanyuinfo?id=1 | normal | App/PlayerJourneyViews.swift | 开始游戏 was a list row; MP pins it as the bottom primary | Pinned bottom primary (safeAreaInset), same identifiers and contract-pinned button source | — |
| D12 | …/mycanyuinfo | missing-param | — | Native opens detail only with an id | — | n/a natively |
| D12a | subpackageMember/character | missing-param | App/CharacterCardReadbackView.swift | Native always has topic context | — | n/a natively |
| D12b, D12h | invoice / invoice-detail | login | App/InvoiceLaunchPresentation.swift | Signed out showed 请重新登录 + retry with a warning icon | Lock icon + 登录后查看发票 (`invoice.signedOut`) | 微信登录 CTA needs a sign-in hook in the invoice model |
| D12i | invoice-apply | login | App/InvoiceLaunchApplyView.swift | Same | 登录后申请开票 | Same |
| D12j, D12k | invoice-titles / invoice-title-edit | login | App/InvoiceLaunchTitlesView.swift, InvoiceLaunchTitleEditor.swift | Same | 登录后管理发票抬头 | Same |
| D12l | subpackageMember/appeal-mine | login | App/MemberScoreAppealListView.swift | MP: 登录后查看申诉 + 微信登录; native maps signed-out to the disabled/stale read errors | — | Needs a signed-out state in the appeal flow |
| D12c | orient-score | missing-param | App/OrientScoreView.swift | Native entry always passes an id | — | n/a |
| D12d | free-explore | missing-param | App/FreeExploreBundleLaunchView.swift | `linkMissing: false` natively | — | n/a |
| D15 | couponInfo?id=1 | normal (error row) | — | PNG is a blank light page | — | Nothing to compare |
| D17 | subpackageMember/coupon-qr?id=1 | normal (used) | App/CouponCodeView.swift | Name/description not in a card; used state was a small label | Head card (ink2); large verify disc + 已核销 + time | — |
| D18 | …/coupon-qr | error | App/CouponCodeView.swift | MP copy 二维码暂时没能生成，请稍后重试 + 重试 pill | New title, primary retry | — |
| D19, D20 | subpackageMember/tixian | form/normal (error rows) | — | PNG shows the merchant home (redirect) | — | Money-gated; nothing to compare |
| D21 | subpackageMember/tixianjilu | normal | App/WithdrawalHistoryView.swift | Matches (native adds day groups) | — | — |
| D22 | …/tixianjilu | empty | App/WithdrawalHistoryView.swift | Matches (还没有发起提现) | — | — |
| D23 | subpackageMember/myinvite | normal | App/SocialInviteHistoryView.swift | Row was a vertical stack; MP has an initial avatar, name + timeline, and a +N 积分 pill on the right | HStack row with avatar and +N 积分 pill | Header 首购奖励积分 +N summary card |
| D24 | …/myinvite | error | App/SocialInviteHistoryView.swift | MP is blank; native shows the error | — | — |
| D25 | subpackageMember/complaint | form | App/ProfileComplaintPreparationView.swift | Order and copy match | — | — |
| D27 | subpackageMember/mytemplate | normal | App/TemplateAuthoringMineView.swift | Anatomy matches (评分/个人审核/模板广场/时长/创建时间) | — | — |
| D28, D29 | assetcenter/income-detail | normal | App/WalletCommerceViews.swift (WalletIncomeView) | MP has a fourth chip 主办分润 | — | 主办分润 filter needs a WalletIncomeFilter case and backend mapping |
| D30–D32 | …/income-detail | empty/error | App/WalletCommerceViews.swift | Copy matches (还没有收益记录) | — | — |
| D33 | assetcenter/earnings | normal | App/WalletCommerceViews.swift | Quick row should be 提现 / 明细 / 分析 / 更多 (native had 积分) | 分析 is now the third quick action (`wallet.analysis.quick`); 积分明细 moved into 更多 (`wallet.points.open`) | — |
| D33A | assetcenter/analysis | normal | App/WalletIncomeAnalysisView.swift | Matches (收入/提现, month, chart, sources) | — | — |
| D34, D35 | subpackageB/im/list | normal | App/MessagingHomeView.swift | Native adds segments, search and day sections | — | — |
| D36 | subpackageB/im/chat | normal | App/MessagingHistoryView.swift | Matches | — | — |
| D38 | pages/deregister | normal | App/AccountComplianceViews.swift | Same anatomy (notice, agree, confirm); MP presents it as a sheet | — | Identity/password gated; keep |
| D90 | subpackageMember/points-history | normal (unmet) | App/WalletCommerceViews.swift (WalletLedgerView .points) | Chips should read 全部 / 获得 / 使用 | Points ledger uses 获得 / 使用 (money ledgers keep 收入/支出) | — |
| D91 | subpackageMember/report-mine | normal | App/SquareReportProgressView.swift | Row was five stacked lines; MP: 「对象 · 原因」 / 「编号 N · 时间」 with stage + chevron; 已经到底了 footer | Row restructured; footer added (`report.progress.end`) | — |
| D92 | subpackageMember/report-detail?reportId=9 | normal | App/MemberReportProgressDetailView.swift | MP: head card → 处理结论 → 你的举报说明 → 处理进度 | Head card (`report.detail.head`), sections reordered and retitled; internal target id / policy / version rows dropped | 查看我的全部举报 link |
| E15 | pages/publish/activity | normal | App/PublishingModesViews.swift | Step 1 fields match (title, venue, dates, type) | — | — |
| E27 | coupon-qr?id=8801 | normal (ready) | App/CouponCodeView.swift | Countdown should read 二维码 Ns 后自动刷新; refresh should be an outline pill | Countdown copy; bordered capsule refresh | Countdown sits outside the white QR card |
| E30 | subpackageRoam/citynode-code | normal | App/VerificationCodeView.swift, App/RoamSubpageParityViews.swift | MP order is title → QR → Ns 后自动刷新 → 出示给商家扫码领券, with no refresh button | Reordered for city-voucher autoIssue; refresh pill kept for the other kinds | — |

Shared components: nothing in App/DesignSystem was changed. `InvoiceLaunchStateSection` (invoice-local) gained an optional `sessionTitle` parameter.
