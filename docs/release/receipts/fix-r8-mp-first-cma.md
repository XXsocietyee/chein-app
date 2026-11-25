# fix/r8-mp-first-cma — MP-first rule (owner 2026-11-25) for club / member / account-publish owner rows

Base `origin/ui/combined-r7` @ f5f3006d7. MP = `hengyin/chengyinhub-xcx` (read-only). Not compiled in the cloud.

## Implemented (MP-first)

| id | MP file:line | app files | test |
|---|---|---|---|
| A3-01 (P0) avatar / 探索作品 / 联系二维码 upload | pages/gerenziliao/gerenziliao.js:781-812 (avatar, crop 1:1), :354 `uploadCasePics`, :383 `uploadWechat`; app.js:654-668 (`uploadOSS`, bizType) | App/AppSession+ProfileAvatar.swift (new: `profileAvatarDependencies` from the player grant's avatar approval, `ReviewedProfileAvatarDispatch`, keychain journal, shared picker host); App/AccountView.swift (2 call sites), App/MPReviewedPageScreen.swift (2 call sites) pass it; App/ReviewedPlayerWriteLeases.swift grant `approvedOrigins` now `RetainedImageOrigin.configured(apiBase:extra: CYStampImageOrigins)` (was the raw base-URL string, which never matches an origin) | `MPFirstCMAGrantTests.testA3_01ProfileImageUploadGrantIsOnForTheShippedPlayer` |
| C-F6 (P0) 到访方式 read/save | pages/publish/fabu/theme-fe-visit.js:40 (GET `?topicId=`), :87 (POST `{nodeId, visitCheck, visitRadius}`); utils/publish/fe-visit-config.js:5-7 | Core/ChinaReviewedRouteCapability.swift (`freeExploreVisitConfigRead/Write = true`; new `mpFirstCMAOwnerGrant` admits the path on production); Core/BusinessRuntimeConfiguration.swift (`.projectRead` GET / `.projectWrite` POST accept the path); App/ReviewedPlayerWriteLeases.swift (`projectEditorRoutes` + `playPaths` carry it) | `PlayRuntimePortTests.testVisitConfigGateIsDefaultOnPerMPFirstAndOutsideTheMarkTable` (was pinned OFF — updated to the MP-first default), `PlayRuntimePortTests.testVisitConfigSavePinsTheMPRequestShape`, `MPFirstCMAGrantTests.testC_F6VisitConfigReadAndSaveAreGrantedOnProduction` |
| C-D12-r7 grant (TeamCommandWriter) | team/detail/index.wxml:5-14, team/join/index.wxml:2-11; utils/team-event-command.js:90-92 | none needed: the shipped China composition already has `playerWritesEnabled: true` (RegionalLaunchConfiguration.swift:92), so `teamRecoveryWriter()` is non-nil | `MPFirstCMAGrantTests.testC_D12TeamCommandWriterIsComposedForTheShippedPlayer` |
| C-F17-r7 topic save route | pages/publish/fabu/index.js:7893-7894 (`/api/topic/v2/create|update`, `/api/topic/create|update`; MP never sends `edit-requests/submit`) | Core/ProjectEditHTTPService.swift `submit`: when the edit-request envelope is not granted (China production) it sends the original route with the same JSON body (`ProjectEditRequestContract.payloadBytes`) and decodes with the existing `decodeAcknowledgment`; TEST keeps the envelope. Tests/ContractChecks/test_project_original_request_recovery.py: the `assertNotIn('path: path, body:')` pin flipped to MP-first | `MPFirstCMAGrantTests.testC_F17ProductionGrantsTheOriginalRoutesTheMPSends`; contract check `test_paired_submit_keeps_independent_original_route_guard` |
| CLB-r7-C-04 | club/create/index.js:40, index.wxml:68 (type name only) | App/ClubOperationsViews.swift (`subtitle: nil`) | — (copy) |
| B-SZ-13 | pages/shezhi/shezhi.wxml:19 (only 成为商家 for non-merchants; no 商家工具) | App/SettingsView.swift (商家工具 only when `effectiveRole == "merchant"`) | — |
| PLY-21-8 | subpackageMember/signup/index.wxml:16-18 (F13: no filter) | App/TicketWalletView.swift (toolbar filter menu removed; list stays `.all`) | — |
| MKT-4-1 (copy part) | subpackageMember/utils/platform-pass.js:79 (`30天·不自动续费`) | Resources/Localizable.xcstrings `mp.member.plan.month` | — |
| MKT-10-2 | subpackageMember/coupon/coupon.wxml:7 (`优惠券`), empty 还没有优惠券 | Localizable.xcstrings `couponManagement.title/empty` | — |
| A-OBJ | subpackageMember/components/cy/profile/index.wxml:350-356 (`藏品`) | Localizable.xcstrings `objects.title` | — |

Already matching the MP (closed, no change): **B-SZ-11** — MP shezhi.wxml:41 `cy-btn variant="secondary"` for 退出账号; the app row is already neutral (SettingsAccountEntries.swift:98-99). **MKT-8-2** — the MP entry label is 我的优惠券 (profile/index.wxml:536), same as the app.

## Money — kept TEST-only

| id | MP evidence |
|---|---|
| MKT-3-1 gift claim | subpackageMember/market/gift/index.js:101-130 `POST /api/marketing/product/gifts/claim` creates a registration from a friend's paid product order (`res.data.registrationId`): a paid-order gift claim. |
| CLB-payout-receiver-01 | pages/club/payout-receiver/index.js:88-119 bind/rebind a payout receiver with `wx.login` code. Payout, and the WeChat code (SendAuthReq) has no iOS equivalent in this build. |
| CLB-settlement-05 | pages/club/settlement/index.js:117-125, :189 `/api/club/settlement/mine`. Read only, but the owner listed it in `moneyAreaOwnerGrant` (payout area, 11-13). Kept; owner can say "settlement reads on" like decision #2. |
| MKT-4-6 buy pill | market/membership/index.wxml:62-65 + platform-pass.js:138 (`续买30天 ¥X` / `开通通行证 ¥X`). Purchase is money; the priced pill copy can follow the MP once money is on. |
| R7-MEM-16-1 (refund / unpaid cancel parts) | scene-member-order-history/index.wxml:85-86 (取消订单 / 立即支付 on unpaid), :89 (取消并退款). The free-order 取消报名 part is not money — see Follow-MP list. |
| FIN-19-1 | scene-member-withdraw-history/index.js:86-90 pages `/api/withdrawal/list` with `{pageNum, pageSize}`. Read of withdrawals; MP pages it, so paging should follow (Core: WalletCommerceService), but it sits in the withdrawal area. |

## Genuinely needs the owner

| id | MP evidence | why |
|---|---|---|
| CLB-detail-11 带票分享 attribution | pages/club/detail wxml:497-504, js:3509-3545 | MP attribution rides `onShareAppMessage` mini-program paths; iOS has no WeChat share attribution or universal link set up. Needs owner ruling on universal links or MP-only. |
| FIN-20-6 invite share | subpackageMember/myinvite/myinvite.js:22-28 `onShareAppMessage` → `/pages/index/index?inviter=` | WeChat-only share attribution; no app invite-URL builder exists. |
| A3-05 phone bind | gerenziliao.wxml:54-56, js:840-883 (`open-type="getPhoneNumber"`) | WeChat `getPhoneNumber` code is not available on iOS; a native SMS bind is a new flow. |
| B-MK-01 master 接收营销消息 toggle | pages/shezhi/components/marketing-consent/index.wxml:18,24 (per-row switches only), index.js:60-80 | The MP has no master toggle (MC-43 is a hand-off design item). MP-first says do not build it unless the owner wants it. |
| R7-MEM-24-2 此刻环境 / 掷骰 | n/a (MP character sheet has neither) | App-only sections; the MP does not have them. Owner: keep or drop. |
| B-AG-04 legal wording | — (MP uses its own `cy-agreement-sheet`) | App/Apple legal text (MR-39) is a legal decision, not an MP flow. |

## Follow-MP UI items left for area agents

MP-first applies (not owner items); left because they are larger than a localized fix or touch flows/tests owned by the area agent.

| id | MP evidence | what to do |
|---|---|---|
| PLY-25-2 (P0) orient-score sync / settle / recovery | subpackageMember/orient-score/index.wxml:26-51; index.js:205 (`/session/{id}/recovery` form `{kind}`), :240 & :313 (`/session/{id}/sync|settle` form `{sessionId, idempotencyKey}`); utils/orient-score-view.js:97 (`canSync = !settlement && status != 3`, `canSettle = ended && !settlement && pendingReviewCount == 0`) | Non-money (points / 探索值). IMPLEMENT: open `orientScoreReviewDecision` for sync/settle/recovery (ReviewedOrientScoreReviewLease.swift:16-19 returns false), mount `OrientSessionCoordinator.synchronizeScore`/settle in OrientScoreView with the MP confirm copy, add recovery. Note Core `write` drops `sessionId` from the sync/settle body (OrientSessionService.swift:146-147) but the MP sends it. Update the pins in ReviewedChinaLaunchCompositionTests.swift:296-297 and test_player_write_grant.py:36. |
| B-MK-05 | marketing-consent/index.js:60-80 (toggle sends at once, toast 已同意/已退订, no confirm) | Drop the per-toggle confirm sheet in AccountComplianceViews. |
| B-PV-04 | pages/privacy/index.wxml:10 (`我已阅读并同意` checkbox), :22 (agree disabled until checked) | Add the explicit checkbox to UsageConsentGateView; update UI tests that tap `authEntry.gate.agree`. |
| MKT-9-2 | subpackageMember/coupon-qr/index.js:58-87 (onShow goes straight to the token) | Remove the `.review` / `MemberCouponShowConfirmSheet` step in CouponCodeView. |
| MKT-10-3 | subpackageMember/coupon/coupon.wxml:46 (`cy-sheet`) | Present the coupon detail as a sheet (medium/large detents). |
| MKT-4-1 (filter part) | platform-pass.js:110-115 (`passView` keeps `planCode === 'MONTH'` only) and :86 (`首发价 ¥X`) | Filter plans to MONTH and show 首发价 in MPParityPassSession / PassMembershipViews (purchase itself stays TEST-only). |
| R7-MEM-16-1 (free part) | scene-member-order-history/index.wxml:89 (`取消报名` on free orders, card-level) | Card-level 取消报名 for free orders (non-money); paid cancel/refund stays TEST-only. |
| R8-MEM-26-1 / R7-MEM-26-1 / PLY-26-2/4/5 | app.json (mytemplate removed, xcx 910de033) | MP retired the page: retire the app's 我的节点玩法 page and deep link (MPReviewedPageScreen.swift:269, MiniProgramPageLink.swift:196). |
| A1-02 | subpackageMember/components/cy/profile/index.wxml:151-556 | Follow the MP 我的 structure. |
| A1-08 | pages/member/index/index.wxml:6 (in-page cy-empty 登录后查看我的主页 + 登录) | Signed-out 我的 shows the in-page login empty state, not WelcomeView. |
| A3-06 / A6-02 | gerenziliao.wxml:93-96 (`saveInfo` saves directly); addressinfo has no confirm modal | Drop the confirm-before-save steps. |
| A8-02 / A8-03 | talent/list js:193-230, wxml:64-76 | Follow the MP feed merge / sections. |
| C-A9-r7 | activity/index.wxml:203-221 | Real-name fields inline, as the MP. |
| CLB-detail-35 | club/detail wxml:192, 992-1026 | 出示团码 + 选择场次 on the detail; mount ClubGapRound4Views.swift:241. |
| CLB-detail-34 | MP has one club detail (pages/club/detail) everywhere | Build the governance-feed detail with the same action / management / community inputs (ClubHomeView.swift:135). |
| CLB-apply-04 (rest) | club/apply/index.wxml:30-33, index.js:158-163 (`wx.reLaunch('/pages/merchant/index/index')` — plain navigation, no switch API) | Active merchant: 切换到商家端 opens the merchant workbench. |
| CLB-workbench-03 | club/workbench/index.wxml:9-15 (没能进入俱乐部管理 + 重试进入 + 返回俱乐部) | Show that error state on the workbench route. |

## Notes
- C-F6 is granted to player/club roles through the play grant; a merchant-scoped editor still lacks the composition path.
- Unchanged per brief: merchant approvals, roam stamp, player-content (topic/activity/IM/wallet), `ReviewedAreaSwitch.merchantWrites`.
