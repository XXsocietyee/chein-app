# Club parity audit r11: mini-program `pages/club/*` vs `ui/combined-r7`

This is a reviewer report; no product code was edited. Brief: `design/handoff-r2:docs/briefs/audit-r11.md`. Baseline: `design/handoff-r2:docs/audit/parity-r10/club.md`.

- **App:** `origin/ui/combined-r7` @ `b9a9d4d29` (r10 measured `82bcf2c2d`; 588 commits since, all 11 r10 lanes merged).
- **MP:** `origin/mp-source:chengyinhub-xcx/pages/club/` (hengyin master snapshot 2026-11-24). It has the same 20 pages and the same 574 denominator rows as r10.
- **Scope change (owner 11-26):** money is now **ON** in Release. That covers payment, refund, host-cancel refund, payout and withdrawal. r10's "money, not a gap" rows are therefore re-scored: a money write the MP sends that does not dispatch in Release is now a gap. Merchant-only rows are marked `merchant release` and not counted. Virtual goods are off. No visual redesign is in scope: function and MP behaviour are scored, plus a native column for "uses Apple components".
- **Method:** same page list, denominators and formula as r10. Every r10 row was re-checked in code on the tip, not from commit messages or receipts. Four sub-audits (A detail/workbench, B topic-detail/topic-story/event-ops, C governance/roles/apply/create/enroll/edit/badges, D the ops pages) each re-scanned their MP pages for missed rows. The two key P0 claims (check-in refund approval never built; cancel/end excluded from the live set) were re-verified by the lead.
- **Receipt note:** four SHAs cited in the fix-r10 club receipts do not exist (76c7de342, a25c7e159, 6936b9f64, 666d94a69). The real commits are cited per row in the appendices.
- **Abbreviations:** `GV` = App/ClubGovernanceViews.swift, `GS` = App/ClubOpsGovernanceSections.swift, `CF` = App/ClubGovernanceCommandForm.swift, `OPS` = App/ClubOperationsViews.swift, `PRV` = App/ClubPayoutReceiverView.swift, `PRB` = App/PayoutReceiverBridge.swift, `MPRPS` = App/MPReviewedPageScreen.swift, `CDV` = App/ClubDetailView.swift, `CCV` = App/ClubCommunityViews.swift, `ACR` = App/AppCompositionRoot.swift, `RPWL` = App/ReviewedPlayerWriteLeases.swift, `CRC` = Core/ChinaReviewedRouteCapability.swift.

## 1. Parity

| MP page | r10 code | **r11 code** | Δ | r10 release | **r11 release** | native r11 |
|---|---|---|---|---|---|---|
| detail | 126/137 | **133/137** | +7 | 126 | **≈130** (scan-verify + coop apply firewall, detail-04/05) | partly (near native) |
| workbench | 4/5 | **5/5** | +1 | 4 | 5 | native |
| topic-detail | 36/49 | **48/49** | +12 | ≈32 | **47** (endTopic dead) | partly |
| topic-story | 31/35 | **35/35** | +4 | 31 | 35 | partly (chapter chips) |
| event-ops | 36/43 | **42/43** | +6 | ≈32 | **41** (cancelOccurrence dead) | partly |
| governance | 26/27 | **27/27** | +1 | 26 | 27 | native (tokens left) |
| roles | 24/24 | 24/24 | 0 | 24 | 24 | native |
| apply | 23/24 | **24/24** | +1 | 23 | 24 | native |
| create | 21/25 | **24/25** | +3 | 21 | 24 | native |
| enroll | 21/24 | **23/24** | +2 | 21 | 23 | native |
| edit (+scene-club-edit) | 24/25 | **25/25** | +1 | 24 | 25 | native |
| badges | 24/25 | **25/25** | +1 | **0** | **25** | native (was custom) |
| notify | 20/21 | 20/21 | 0 (notify-05 +1, retry regressed −1) | ≈18 | 20 | native |
| settlement | 15/15 | 15/15 | 0 | 15 | **14** (FE settle off) | partly (withdraw-support page) |
| customer-detail | 19/20 | 19/20 | 0 | 18 | 19 | partly |
| checkin-detail | 16/16 | 16/16 | 0 | 16 (refund = money) | **15** (refund dead) | native |
| join-requests | 17/17 | 17/17 | 0 | 17 (untraced) | 17 (traced, 03d5694d0) | native |
| group-code | 11/13 | **12/13** | +1 | ≈3 | 12 | native |
| customers | 15/15 | 15/15 | 0 | 15 | 15 | native |
| payout-receiver | 12/14 | **13/14** | +1 | 12 (bind = money) | **13** (bind dead) | native |
| **total (20 pages)** | **521/574 (90.8%)** | **562/574 (97.9%)** | **+41** | **≈478 (≈83%)** | **≈555/574 (≈96.7%)** | **13 native · 7 partly · 0 custom** |

**Area parity: 90.8% → 97.9% on code (+7.1 pts, +41 rows). Release went from about 83% to about 96.7%.**

- **Release blockers closed:** r10's two Release blockers are fixed. gate-05 landed in 193356907: the 10 ops writes are in `ClubMPFirstGovernance.clubOps` (Core/ClubGovernanceProduction.swift:31-40), the firewall admits them (App/MPFirstClubApprovals.swift:85-110), and tests pin both. badges-01 landed in 704e52991, which composes the badge approval inside the Release China grant (ACR:609).
- **Release losses from the scope change:** these come from money being ON, not from any commit. cancelOccurrence/endTopic, the check-in refund, the payout bind and the FE settle all still never dispatch.
- **Unmapped rows:** four r9 detail denominator ids (A15, B15, E4, C11) and one unnamed enroll row are still counted absent. The r9 denominator file is not on any reachable branch, so they cannot be mapped to fix rows. The next denominator refresh should name them.
- **Native:** 13/20 pages are native, 7 are partly and 0 are custom; on the r10 weighting that is 82.5%, up from 47.5%. CY* *component* calls on the club pages fell from 515 to under 100. What remains is mostly `CYSpacing`/`.cyText` tokens and the `.cySheet` wrappers.

## 2. Open counts

| | P0 | P1 | P2 |
|---|---|---|---|
| parity / release | 3 | 8 | 13 |
| native | 0 | 0 | 9 |
| **total (33 rows)** | **3** | **8** | **22** |

r10 had P0 3 · P1 24 · P2 103 (130 rows).

r10 row outcomes (about 130 rows): about 115 fixed, 11 partly, 5 open (including the re-scored money rows), 1 regressed. Two rows were moved to `merchant release`: CLB-r10-apply-01/02 and the G13c 联系商家 button.

All three r11 P0s are money flows that the MP sends and the app does not dispatch in Release:
- host-cancel/end refund
- check-in owner refund
- payout-receiver bind

## 3. Fix queue (input for fix round r11)

P0 first, then P1, then P2. MP paths are relative to `chengyinhub-xcx/pages/club/`. Sizes: S ≤ 1 agent-hour, M = half a day, L = needs owner or backend.

| # | id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|---|
| 1 | CLB-r11-money-01 (supersedes CLB-r10-money-01) | **P0** | event-ops/index.js:1106-1115; topic-detail/index.js:1118-1190, wxml:533-540, 644-650 | Core/ClubGovernanceProduction.swift:36-40; App/MPFirstClubApprovals.swift:85-104; Tests/AppUnitTests/MPFirstClubWriteRouteR10Tests.swift:72-73; Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift:187-188; Tests/CoreTests/ClubGovernanceProductionTests.swift:88 | **Host-cancel refund is dead in Release.** 1. Add `clubMoney: Set = [.cancelOccurrence, .endTopic]` and union it into `governance` (gate it on the Release money switch if one exists). 2. Add `api/club/event-ops/cancel`, `api/club/topic-setting/end` and the review read `api/club/event-ops/occurrence/status` to `governancePaths`, plus a `readShapes` entry `ids: ["clubId","activityId"]`. 3. The firewall's `pay/refund/settlement` substring refusal (MPFirstClubApprovals.swift:123-125) must let these two through. 4. Flip the two `XCTAssertFalse` assertions to true and keep the :88 non-financial assertion scoped to `clubOps`. 5. Add a test that both have `canDispatch == true` in a Release China composition. reportHours and submitEvidence are not sent by the MP, so leave them. | M |
| 2 | CLB-r11-checkin-detail-01 | **P0** | checkin-detail/index.js:143-200; wxml:77-88 (清退并退款) | App/NativeRuntimeDependencies.swift:57 (`ownerRefundApproval` defaults to nil, and no `ClubOwnerRefundApproval(` is built anywhere in App/Core); RPWL:1448-1462; App/AppSession.swift:6021; Core/ClubOwnerRefundApprovedAccess.swift:13 | **The owner refund is never composed, so the panel stays disabled in every build.** 1. Add `MPFirstClubApprovals.ownerRefund(_ context:) -> ClubOwnerRefundApproval?`, returning nil unless the market is China and the money switch has refund on. Its endpoints are exactly `api/registration/cancel-by-owner`, `api/club/access/me` and `api/club/crm/checkin/detail`. 2. Pass it as `ownerRefundApproval:` in the `NativeRuntimeDependencies(...)` call at RPWL:1448. 3. Make sure the composition firewall admits cancel-by-owner, which is a `.refund` kind. 4. Add a test that `clubOwnerRefundCoordinator.canDispatch` is true in Release China. | M |
| 3 | CLB-payout-receiver-01 (was "money, not a gap") | **P0 (blocked: owner + backend)** | payout-receiver/index.js:95-121 | PRB:15-17; PRV:121-133, 176-188; RPWL:10-13; App/AppSession.swift:3413 | **Bind is dead in Release:** `weChatCode` is never set, the WeChat SDK is unconfigured, and bind is not in the payout allowlist. The MP's `wx.login` jsCode has no iOS equivalent until the steps below are done. **Owner:** register the iOS app on WeChat Open Platform and bind its appid to the profit-sharing mchid. **Backend:** a bind variant that accepts an app OAuth code or unionid. **Core:** add `api/club/personal-receiver/bind` to `OwnerDecisionGuardLease.paths` and set `weChatSDKConfiguration`. **App:** set `PayoutReceiverBridge.weChatCode` to a `SendAuthReq` closure. **Interim (S):** under `payoutReceiver.bind.mpOnly`, add a 去小程序绑定 row that copies `pages/club/payout-receiver/index?clubId=N`. Unbind already dispatches. | L |
| 4 | CLB-r11-notify-01 (**regression**, e93c5b952) | P1 | notify/index.wxml:107-110 (只重试失败项), js retryFailed | CF:375-398 | In the receipt Section after `ClubOpsNotifyCampaignRows`, show it when `(try? ClubOpsNotifyCampaign(value: refreshedCampaign ?? receipt))?.canRetryFailed == true`. Add `NavigationLink { ClubGovernanceCommandForm(route: .init(operation: .retryNotification, scope: .init(clubID:…, activityID:…, campaignID: notifyCampaignID)), identity:, access:, coordinator:) } label: { Text("club.gov.action.retryNotification") }`, as GV:1933 does. | S |
| 5 | CLB-r11-topic-detail-01 | P1 | topic-detail/index.js:1118-1190 (`cancellationEpoch`, PENDING/DONE, failedSessions) | Core/ClubGovernanceCommands.swift:112 (`.endTopic` requiredKeys = []); Core/ClubTopicEndSummary.swift (0 call sites) | Send `cancellationEpoch` from the topicSettings read in the endTopic body, and parse the reply through `ClubTopicEndSummary`. If failedSessions is not empty, keep the confirm open with 「N 场没能取消：<first>」. On PENDING, show 原结束请求仍在处理中，请按原请求查回. On DONE, toast `endResultText`. Land with #1. | M |
| 6 | CLB-r11-settlement-01 | P1 | components/cy/fe-reference-settlement/index.js:57-75; wxml:23-24 (标记已结清) | App/ClubFEReferenceSettlementHost.swift:7-13, 47, 64; CRC:619-622 | Replace `static let allowsSettle = false` with a computed value from the Release money switch (payout), keeping the TEST override. Grant `/api/fe/reference-settlement/settle` (POST, exact body `{ids:[Int], voucherNo?:String}`) next to CRC:619-622 and in the composition firewall. The button already exists (App/MPGap/Club/ClubGapReferenceSettlementView.swift:55-60). | M |
| 7 | CLB-r11-group-code-01 | P1 | group-code/index.js:44-62, 93-105 | Core/ClubGovernanceCommands.swift:73; Core/ClubGovernanceContracts.swift:169, 183; MPRPS:354-356 | An activityId-only link fails at the `topicOverview` review read before the code is issued. When `scope.topicID == nil`, use the `.access` review read (`api/club/access/me`), or skip the read and validate the receipt by activityId (CF:921-928). Keep `topicOverview` when a topicId is present. Add a test that an activityId-only link issues in Release China. | M |
| 8 | CLB-r11-detail-04 (verify) | P1 | detail wxml:368-374, js `onClubScan` | App/ClubPostRefFollowSession.swift:58-74; ACR:3591; App/MPFirstClubApprovals.swift:80-100; CRC:1140, 1648, 1840 (route marks `.liveInProduction`) | No composition-firewall admission was found for `api/verify/groupcode/redeem`, `api/registration/scan_dynamic_code` or `api/coupon/verification`, although the route capability marks them live. Add a Release China composition test that POSTs each and asserts the reply is not `notConfigured`. If it fails, add the paths to `MPFirstClubWriteRoute.governancePaths`, or to an exact-body route next to it. | M |
| 9 | CLB-r11-detail-05 (verify) | P1 | detail js:3813-3847 (`/api/coop/pool/apply`) | App/ClubPostRefFollowSession.swift:41-56; RPWL:1530-1554; App/MPFirstCoopWrites.swift:40-50; CRC:2057 (in `wiredPatterns` only) | Admit `api/coop/pool/apply` (JSON `{topicId, clubId, message}`) in Release China. Either add it to `ClubGapProductionLease.paths` with an exact-key check, or add `.apply` to `MPFirstCoopWrites.nonMoneyCatalog`. Add the same composition test. | S |
| 10 | CLB-topic-detail-06 | P1 | topic-detail wxml:503-530; js:1245-1274 | GV:1977 | Replace the pushed `edit(.saveTopicSettings…)` form with three inline `Toggle`s: 合作开放 coopOpen, 置顶 pinned, 仅成员 memberOnly. On change, each one dispatches saveTopicSettings with all three values (this now dispatches in Release) and is disabled while saving. On failure, roll back and show the server sentence in the footer. | M |
| 11 | CLB-customer-detail-04 (partly) | P1 | customer-detail/index.wxml:83-118 | GV:805-809; App/ClubOpsCustomerViews.swift:478-510 | The editor rows are native now, but they still open in `.cySheet(item: $editor)`. Render tags and remark as an inline Section on the customer page, with Section buttons 保存 (`clubR3b.customer.save` → saveCustomer) and 取消. Coordinate with the governance journal lock (Core/ClubGovernanceCoordinator.swift:171-221). | M |
| 12 | CLB-r9-gate-04 / CLB-r10-detail-01 (partly) | P2 | detail wxml:96-158 | ACR:377-378, 1010-1011, 3256-3281; App/ClubPostOriginalComposition.swift:14 | Pick one: delete the dead `ClubPostOriginalRoute` / `ClubCommentOriginalRoute` branches and their two approval vars (the MP sends `api/club/post/*`, which is already granted), or set the approvals inside `if grantPlayerWrites` at ACR:601-609. | S |
| 13 | CLB-r11-topic-detail-02 | P2 | topic-detail/index.js:419, wxml:316 | GV ≈1791 (接下来 section) | When `topicStats["paidSessionsBlocked"] == true`, show the footer `.secondary` text 这个主题暂不能在线收款，玩家无法在线报名付费场次. | S |
| 14 | CLB-r11-topic-detail-03 | P2 | topic-detail wxml:296-312 (活动复盘) | App/ClubTopicDirectorMount.swift:243-330 | When the projection is FINISHED, add a Section 活动复盘 with `LabeledContent` rows from `projection.club["recap"]` (完成情况, 节点完成), or 复盘尚未生成. Add a 复制复盘数据 Button when `recap.exportAvailable` (Core/PlayDirectorRuntime.swift:161) and a 显示/隐藏榜单 toggle. | M |
| 15 | CLB-event-ops-05 (partly) | P2 | event-ops wxml:12; js:479 | MPRPS:349-352 | No clubId → replace `unavailable` with `MemberMissingLinkState(identifier: "clubOpsEvent.missingParam")` (链接已失效 + 返回), as at App/ClubOpsEventView.swift:53-55. | S |
| 16 | CLB-r11-event-ops-01 | P2 | event-ops wxml:86-87 (correctionWindowText) | App/ClubOpsEventInlineRoster.swift:12-30 | Under the segmented Picker, when `roster.correctionOperable == false`, show the orange note from App/ClubRosterBucketContent.swift:42-48 (`clubOpsEvent.roster.window` / `windowGeneric`). | S |
| 17 | CLB-r11-edit-01 | P2 | edit/index.js:23-30 (`onDissolved`) | CF:906-907; GS:450-460 | 1. Add `case .dissolve: "clubOpsGov.success.dissolve"` (俱乐部已解散) to `ClubOpsGovernanceSuccess`. 2. In CF, add a `.task(id:)` modelled on transferOwner (CF:502-507): after 0.5 s, dismiss the form and pop the edit page through a `clubDissolvedReturn` environment closure supplied by OPS. | M |
| 18 | CLB-r9-create-04 (+nat-create-02) | P2 (owner decision: MC-10 vs MP) | create/index.wxml:119-121 | OPS:1302; App/ClubKit/ClubCreateKit.swift:156-250 | If the MP wins: replace `ClubCreateCityRow` with `TextField("club.ops.city", text: $draft.city, prompt: Text("如 上海"))` capped at 20 characters in `.onChange`, put the rule in the Section footer, and delete `ClubCreateCityPicker`. | S |
| 19 | CLB-r11-detail-01 | P2 | detail wxml:863-871, js:3587-3604 | App/MPGap/Club/ClubGapManageExtensions.swift:257-293; App/ClubDetailR8Mounts.swift:30-45 | Settings sheet: add an owner-only Section 经营 with a `LabeledContent` row 俱乐部分润. Its value is `settledAmountText` from `api/club/settlement/summary`, or 暂时读不到. Tapping it opens `ClubGovernanceReadView(.settlement)` (CDV:204-208). Load it in `loadSettingsCounts`. | S |
| 20 | CLB-r11-workbench-01 | P2 | workbench wxml:9-15, js:33 | MPRPS:1150-1159 | On `.failed`, add the description 暂时无法进入俱乐部管理，请重试或返回俱乐部 and a second button 返回俱乐部 (`dismiss()`). | S |
| 21 | CLB-r11-detail-02 | P2 | detail wxml:555-600 | App/MPGap/Club/ClubGapManageExtensions.swift:81, 100 | Move the literals to catalog keys `club.coopPool.permissionTitle` (暂不能看可对接的活动) and `club.coopPool.publishedBy %@` (%@ 发布). | S |
| 22 | CLB-r11-settlement-02 | P2 | — | PRB:7, 11-12, 15-16; App/ClubFEReferenceSettlementHost.swift:3-6, 18; PRV:3-5 | Update the stale "money closed in Release" comments to match owner 11-26. | S |
| 23 | CLB-r11-detail-03 | P2 | — | App/MPGap/Club/ClubGapRound4Views.swift:8-113 | Delete the dead `ClubGapManagedProjectsDirectorSection` (0 refs since 0ab79f407). | S |
| 24 | CLB-r11-nat-group-code-04 | P2 native | — | App/DesignSystem/CYClubGameCodeCard.swift | Delete the unused hex-ink card file. | S |
| 25 | CLB-r11-nat-settlement-01 | P2 native | settlement wxml:43-46 → utils/withdraw-cs | App/WithdrawalSupportContactView.swift:35-63 | CYHeroHeader → `Section` header and footer. The 复制微信号 pill → `Button { } label: { Label(…, systemImage: "doc.on.doc") }`. CYStatusChip → orange `Label`. Drop `.cyGroupedSurface()`. | S |
| 26 | CLB-r10-nat-detail-03 (partly) | P2 native | — | CCV:853, 1202, 1265 | Delete the three `Button("club.community.refresh")` Sections, since `.refreshable` already exists (CCV:860, 1207, 1270). Optionally move the comment field to `.safeAreaInset(edge: .bottom)`. | S |
| 27 | CLB-r10-nat-detail-06 (partly, owner-held theme pause) | P2 native | — | CDV:402, 409, 502-503 | When the theme pause lifts, drop `.tint(CYDomainPalette(...).brand)` and `.cyTracksHeroScroll`. | S |
| 28 | CLB-r10-nat-detail-08 (partly) | P2 native | — | App/ClubActionPanel.swift:88-97, 112-122 | Move `club.application.messageHelp` and the required/too-long text into the Section `footer:`. Keep the F-08 modifiers on the header Text. | S |
| 29 | CLB-r10-nat-topic-story-03 | P2 native | topic-story chapter chips | GV:2505-2541 | Always use the `Picker(.menu)` branch (:2506-2516) and delete `chapterChips`. | S |
| 30 | CLB-r10-nat-topic-detail-04 (partly) | P2 native | — | GV:1769, 809 | `.cyDomainSheet(detents:)` → `.presentationDetents([.medium, .large])` for the quick sheet and `[.large]` for the editor. | S |
| 31 | CLB-r10-nat-event-ops-04 (partly) | P2 native | — | App/ClubOpsEventFormFields.swift:94-115 | `ClubOpsEventReasonField`: put the TextField in `Section { } footer: { subtitle + red validation }` and remove the VStack. | S |
| 32 | CLB-r10-nat-governance-03 (partly) | P2 native | — | GS:75-89, 123, 205-229; GS:139-153 | Replace 35 × `.cyText`: `.meta` → `.font(.footnote)`, `.bodyCompact` → `.subheadline`, `.cardTitle` → `.headline`. Drop the explicit `CYSpacing`. | S |
| 33 | CLB-r10-nat-edit-02 (partly) | P2 native | scene-club-edit save-failed | OPS:519-536 `editSaveBar` | On `editSaveFailed`, show `.alert("clubR8b.edit.saveFailed")` with the server message and the buttons 重新保存 and 继续编辑 (`.cancel`), and keep the bar plain. | S |

**Merchant release (not counted):** CLB-r10-apply-01 (切换到商家端 reLaunch), CLB-r10-apply-02 (`merchantActive` read) and the G13c 联系商家 button.

## 4. Regressions

| row | commit | what broke |
|---|---|---|
| CLB-r11-notify-01 | **e93c5b952** "fix(r9-club): CLB-notify-05 inline 刷新…" | It removed the composer's `NavigationLink` to `ClubGovernanceReadView(.notificationStatus)`, which was the only host of `edit(.retryNotification)` (GV:1933). The composer shows the failed count, but 只重试失败项 is unreachable. Fix: queue #4. |

No other scored row went backwards. Dead code was left behind: 0ab79f407 stopped mounting `ClubGapManagedProjectsDirectorSection` but kept the type (#23).

## 5. Verdict

1. **Code parity is 97.9% (562/574), up 7.1 pts.** About 115 of r10's ~130 rows are fixed in code, including all three r10 P0s (gate-05 193356907, badges-01 704e52991, G13a 50ebf1367/91251b38d).
2. **Release parity is about 96.7%.** All remaining Release losses are money flows that the owner turned on on 11-26 and that are still wired off:
   - host-cancel/end refund
   - check-in refund
   - payout bind
   - FE settle

   #1 and #2 are Core wiring (M each). #3 needs an owner and backend decision.
3. **Native:** 13 of 20 pages are native and none are custom. The 9 native rows left are all P2 and size S.

---

# Appendices: sub-audit row tables

Each appendix is the sub-audit's working file, with the full r10 row-by-row status, evidence (file:line @ sha) and page notes. §1–§4 above are the merged result; the fix-queue tables inside the appendices are superseded by §3.


---

# Appendix A

## out-A · club r11 · pages/club/detail (137) + pages/club/workbench (5) + gate rows

App tip `b9a9d4d29` (r10 measured `82bcf2c2d`). Reviewer only; no product code edited. Every row was re-read in code on the tip. Receipt claims were used only as pointers. Four receipt SHAs (76c7de342, a25c7e159, 6936b9f64, 666d94a69) do not exist; the real SHAs are cited below. `CDV` = App/ClubDetailView.swift, `MPS` = App/ClubManagedProjectsSection.swift, `CCV` = App/ClubCommunityViews.swift, `ACR` = App/AppCompositionRoot.swift.

## Row status

| id | sev | r11 status | evidence (app file:line @ sha) | note |
|---|---|---|---|---|
| CLB-r9-gate-04 (= CLB-r10-detail-01) | P2 | **partly (unchanged)** | ACR:377-378, 1010-1011 still `{ _ in nil }`; no setter in the `grantPlayerWrites` block ACR:601-609; fenced branch ACR:3256-3281 | MP create/comment dispatch via `clubCommunityWriteService` (ACR:614-617). The `api/club/post/operation/*` original path is still dead. club-a/b/c receipts all deferred it to Cursor Core. |
| CLB-detail-42 (= CLB-r10-detail-02) | P2 | **fixed** | `ClubDetailOverviewFactsGrid` is gone (0 refs repo-wide). The 待补充 fallback is live in CDV:711-713, 774-785 (`factsLine`) @ 3ab7e881a | — |
| CLB-detail-34 | P1 | **fixed** | App/ClubHomeView.swift:137-138 now passes actionCoordinator, management, community and publicRoster @ 892f6d4d3. Same at :182 and at every other ClubDetailView call site except fixtures | — |
| CLB-G06 | P1 | **fixed** | Gear at CDV:421-428 for `isOwner ‖ canUseManageTab`. The sheet gets `canGovern: club.isOwner` (CDV:432), not `true`. The 设置 quick action is at App/ClubDetailQuickActions.swift:47-52, wired at CDV:129 @ 892f6d4d3 | The gear and 设置 also need `management?.operations != nil` (CDV:421, 579). |
| CLB-r7-A-04 | P1 | **fixed** | MPS:305-352: one session opens directly; several open the 选择场次 sheet (MPS:259-291); none sets a footer notice (MPS:335-336). Tools are filtered by `permissions.tools` (MPS:346-351, CDV:607-614) @ 892f6d4d3 | — |
| CLB-r7-A-07 | P2 | **fixed** | App/ClubMembersView.swift:49-55 (`loadGovernGrant`: `club:member:manage` and OWNER/CO_OWNER) and :223 `canTempBan: isOwner ‖ canGovernMembers` @ cef838d90 | Matches MP js:2425-2426. |
| CLB-detail-09 | P1 | **fixed** | MPS:136-257 has the cover (AsyncImage, `routeFreeCover` fallback), `timeText · N 人报名` / 还没有场次 (MPS:253-257), row tap → topic (MPS:188), redacted loading (:140-144), ContentUnavailableView + 重新加载 (:146-152), 暂无分配给你的项目 (:181), no 12 cap and no extra header. Mounted at CDV:133-141 @ 892f6d4d3 | The old `ClubGapManagedProjectsDirectorSection` is now dead code (see CLB-r11-detail-03). |
| CLB-detail-14 | P1 | **fixed** | 帖文 renders `ClubCommunityFeedView(leading: pageHeader)` inline (CDV:111-112, 519-528) @ d0d2aa7a3. The chat, IM and channel rows moved to 概览 (CDV:356-388) @ 0bcd0607d | — |
| CLB-detail-30 | P1 | **fixed** | The invite uses `ClubShareURL` → `PublicContentShareLink.club` (App/ClubMPAssetViews.swift:9-14), with https first and `chein://` only as fallback. The header share is at App/ClubKit/ClubWorkbenchKit.swift:228-249, 带票分享 at App/ClubEditionsShareSection.swift:78-85, and the builder at Core/PublicContentShareLink.swift:75-105 @ ce3bb93c0. AASA lists `/pages/club/detail/index` and `/pages/topic/index/index` (docs/release/aasa.json:19-20). Test: Tests/CoreTests/PublicContentShareLinkTests.swift:109-122 | Absorbs CLB-r10-detail-03. |
| CLB-r10-detail-03 | P2 | **fixed** (via detail-30) | App/ClubEditionsShareSection.swift:82-85 @ ce3bb93c0 | — |
| CLB-detail-35 | P1 | **fixed** | 出示二维码 quick action (App/ClubDetailQuickActions.swift:41-45; CDV:130, 592-600: no project → toast, several → 请在下方选择, one → code). 出示团码 on activity rows (App/ClubPublicActivityListView.swift:42-58; CDV:185, 587-590). The gate matches MP wxml:375 (owner ‖ admin ‖ `club:event:checkin`, CDV:583-586) @ 892f6d4d3 | The issue write now dispatches in Release: `.issueGroupCode` is in Core/ClubGovernanceProduction.swift:38-41, and `api/verify/groupcode/issue` is in App/MPFirstClubApprovals.swift:93. |
| CLB-r9-detail-01 | P2 | **fixed** | Name and role under each avatar (App/MPGap/Club/ClubGapManageExtensions.swift:180-195). Tap → profile, or the 公开资料/客户档案 dialog (CDV:251, 452-453, 568-576; App/ClubDetailR8Mounts.swift `ClubDetailStripMemberOpen`) @ b698382a1, 1b7c983ef | — |
| CLB-r9-detail-03 | P2 | **fixed** | The settings sheet uses catalog keys (ClubGapManageExtensions.swift:263-290). R8M:39, 43 use `club.settings.customerCount` / `countUnavailable` @ 0589d6682 | New literals elsewhere are tracked as CLB-r11-detail-02. |
| CLB-r9-native-07 | P2 | **fixed** | `common.cancel`/`common.close` at ClubGapManageExtensions.swift:59, 299; ClubGapRound4Views.swift:87; ClubGapRemainingViews.swift:53 @ 9bb9fff7c | — |
| CLB-workbench-03 | P2 | **fixed** | App/MPReviewedPageScreen.swift:1138-1175 `ClubSingleOwnedEntry`: ProgressView, then on `.failed` a ContentUnavailableView 没能进入俱乐部管理 + 重试进入 (:1150-1159) @ 42450ede4 | No 返回俱乐部 action and no sub line (CLB-r11-workbench-01). |
| CLB-r10-nat-workbench-02 | P2 | **fixed** | App/ClubKit/ClubWorkbenchKit.swift:59-183 is one `Section` with LabeledContent rows. 0 RoundedRectangle, 0 CY* @ 892f6d4d3 | — |
| CLB-r10-nat-detail-01 | P2 | **fixed** | CCV:332-431: `List`, ProgressView, ContentUnavailableView (:346-353), `.refreshable` (:431); no CYHeroHeader or cyDomainCard @ b47382ab8 | — |
| CLB-r10-nat-detail-02 | P2 | **fixed** | CCV:908-960: `Form` + TextEditor in a Section, prompt and `n/300` in the footer (:916-924), toolbar cancel/confirm (:951, 957) @ b47382ab8 | The prompt is still `locale.pick` verbatim (CCV:919). |
| CLB-r10-nat-detail-03 | P2 | **partly** | Post detail, comments and history are `List` + `.refreshable` (CCV:777/860, 1127/1207, 1228/1270). The comment TextField is in a Section (:1195) @ b47382ab8 | Redundant 刷新 button rows remain at CCV:853, 1202, 1265. The comment field is not in `.safeAreaInset`. |
| CLB-r10-nat-detail-04 | P2 | **fixed** | CCV:1040-1110: List sections and toolbar cancel; no CYCard and no offline plate @ b47382ab8 | `.cyDomainSheet` remains (CCV:1110); theme work is paused. |
| CLB-r10-nat-detail-05 | P2 | **fixed** | App/ClubDetailTabBar.swift:10-37: system `Picker(.segmented)`, `.menu` at AX sizes, no ScrollView @ b47382ab8 | — |
| CLB-r10-nat-detail-06 | P2 | **partly** | Logo `@ScaledMetric` and no stroke (CDV:708, 739-742) @ ec4301e16 | Still: `.tint(CYDomainPalette…)` CDV:503, `.cyPushedChrome` CDV:409/502, `.cyTracksHeroScroll` CDV:402. Held for the owner's theme pause. |
| CLB-r10-nat-detail-07 | P2 | **fixed** | CDV has 0 CYListRow/CYRowIcon/CYEmptyState/CYStatusChip; it uses NavigationLink + Label and ContentUnavailableView (CDV:166) @ 0bcd0607d | — |
| CLB-r10-nat-detail-08 | P2 | **partly** | Leave is `Button(role:.destructive)` with a `.confirmationDialog` (App/ClubActionPanel.swift:132-141, 178-181); the page-end row is a system cell (:166-175) @ ca477e884 | The join help and validation are still rows (ClubActionPanel.swift:88-97), not the section footer. |
| CLB-r10-nat-detail-09 | P2 | **fixed** | 出示团码 is `.bordered .small` (ClubPublicActivityListView.swift:54-58) @ 34c79a0fd. Activity rows have no plate (App/ClubActivityListContent.swift:55-90) | The cover still has a 10 pt rounded clip (ClubActivityListContent.swift:66). Acceptable. |
| CLB-r10-nat-detail-10 | P2 | **fixed** | R8M uses ProgressView, ContentUnavailableView and `.confirmationDialog`; 0 CY components (only `.cyPushedChrome` :277, 287) @ 892f6d4d3 | — |
| CLB-r10-nat-detail-11 | P2 | **fixed** | App/ClubMembersView.swift: no CYSheetHeader, CYOptionSheet or CYEmptyState; only CYSpacing and `.cySheet` (:116, 131) @ 892f6d4d3 | — |
| CLB-r10-nat-detail-12 | P2 | **fixed** | ClubGapRound4Views.swift `dateRow` DatePicker @ ee1c2fc80; pills are `.bordered` | — |
| CLB-r10-nat-detail-13 | P2 | **fixed** | ClubGapManageExtensions.swift:48-105: apply field in a Form, ContentUnavailableView, no CY chip or pill @ 35852c11d | Literals remain (CLB-r11-detail-02). |
| CLB-r10-nat-detail-14 | P2 | **fixed** | ClubGapRemainingViews.swift:137-142 `.bordered/.borderedProminent`; ClubEditionsShareSection.swift:63-68 ShareLink `.bordered` @ 35852c11d | — |

Money (owner 11-26: money ON in Release). The MP `pages/club/detail` has **no payment or refund flow of its own**: join is the free `/api/club/join` (MP js:2558), 申请带队 and 扫码 move no money, and 结算 / 俱乐部分润 only navigate to `pages/club/settlement` (MP js:1073-1079), which belongs to another slice. The app's 结算 entry is present (CDV:203-209 → `ClubGovernanceReadView(.settlement)`). Join and quit dispatch in Release China: `clubOrdinaryAdmissionApproval` is granted at ACR:602, and the firewall branch at ACR:3240-3254 with `simpleClubMembership` admits them (App/ReviewedPlayerWriteLeases.swift:474-488). No detail row is a money row.

**Release-dispatch concern (new, P1):** I found no composition-firewall admission for two r10 "fixed" detail writes:
- G02 扫码核销 sends `api/verify/groupcode/redeem`, `api/registration/scan_dynamic_code` or `api/coupon/verification`.
- G04 申请带队 sends `api/coop/pool/apply`.

Both go through `session.runtimeHTTPTransport` (App/ClubPostRefFollowSession.swift:41-74). None of these paths appears in `CompositionHTTPTransport.guardedSend` (ACR:2605-3620), `MPFirstClubWriteRoute` (App/MPFirstClubApprovals.swift:80-100), `ClubGapProductionLease` (App/ReviewedPlayerWriteLeases.swift:1530-1554, which lists only the exact `api/coop`), the player grant path sets (:619-896) or `ReviewedPlayerReadRoute`. `MPFirstCoopWrites.nonMoneyCatalog` also leaves out `.apply` (App/MPFirstCoopWrites.swift:40-50). The UI gates on `showsRoute`, which reads `wiredPatterns` (Core/ChinaReviewedRouteCapability.swift:2057, 1840), so the buttons show in Release but the POST would be refused with `notConfigured`. A Release-China composition test is needed to confirm. New rows CLB-r11-detail-04/05 track this.

## Page scores

| page | r10 code | r11 code | Δ | r11 release | native grade | CY* calls |
|---|---|---|---|---|---|---|
| pages/club/detail | 126/137 | **133/137** | +7 | **130** (133 if G02/G04 turn out to be admitted) | partly (close to native) | 76 CY tokens in 15 files, down from ~118 in r10. 34 are `CYSpacing`; 14 are `.cySheet`. The remaining components are `CYDomainPalette` tint, `.cyPushedChrome`×4, `.cyTracksHeroScroll`, CYCoverArt/CYIMCoverArt placeholders×3, `.cyDomainSheet`, `.cyPageTitle`×3, `.cyText`×3, CYAvatarView, CYConfirmConsequence×5, CYScreenOfflineWriteBanner, CYJoinReward and CYHaptics. |
| pages/club/workbench | 4/5 | **5/5** | +1 | 5 | native | 0 (entry is ProgressView / ContentUnavailableView; manage-tab Section has 0 CY) |

Detail now present: F7 (detail-30), B5 (detail-14), E3 (detail-35), E6 (G06), E11 (detail-09), E13 (A-04), N1 (A-07). Still absent: A15, B15, E4, C11. These are r9 denominator ids with no row id in r10. The r9 denominator file is not in any reachable branch, no fix commit claims them, and I counted them as still absent. Release 130 = 133 − A11/E2 (G02 scan) − E18 (G04 apply), on the firewall finding above.

## Fix queue

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| CLB-r11-detail-04 | P1 | detail wxml:368-374, js `onClubScan` | App/ClubPostRefFollowSession.swift:58-74; ACR:3591 (firewall chain); App/MPFirstClubApprovals.swift:80-100 | Admit the club scan-verify POSTs in Release China. Add `api/verify/groupcode/redeem` and `api/registration/scan_dynamic_code` (and `api/coupon/verification` if clubs use it) to `MPFirstClubWriteRoute.governancePaths`, or to a new exact-body route next to it. The money-key check stays. Add an AppUnitTest that builds the Release China composition and asserts each path's POST is not refused with `notConfigured`. If a branch already admits them, add only that test and close the row. | M |
| CLB-r11-detail-05 | P1 | detail js:3813-3847 (`/api/coop/pool/apply`) | App/ClubPostRefFollowSession.swift:41-56; App/ReviewedPlayerWriteLeases.swift:1530-1554; App/MPFirstCoopWrites.swift:40-50 | Admit `api/coop/pool/apply` (JSON `{topicId, clubId, message}`) in Release China. Either add it to `ClubGapProductionLease.paths` with an exact-key body check, or add `.apply` to `MPFirstCoopWrites.nonMoneyCatalog` and route through the coop executor. Add the same Release-composition test. | S |
| CLB-r9-gate-04 / CLB-r10-detail-01 | P2 | detail wxml:96-158 | ACR:377-378, 1010-1011, 3256-3281; App/ClubPostOriginalComposition.swift:14; App/AppSession.swift:863-866 | Decide: delete the `ClubPostOriginalRoute`/`ClubCommentOriginalRoute` branches and the two approval vars (the MP sends `api/club/post/*`, already granted), or set `clubPostOriginalApproval`/`clubCommentOriginalApproval` inside `if grantPlayerWrites` at ACR:601-609. | S |
| CLB-r10-nat-detail-03 | P2 | — | CCV:853, 1202, 1265 | Delete the three `Button("club.community.refresh")` Sections; `.refreshable` already exists (CCV:860, 1207, 1270). Optionally move the comment TextField + 审核 button (CCV:1194-1199) into `.safeAreaInset(edge: .bottom)`. | S |
| CLB-r10-nat-detail-06 | P2 | — | CDV:402, 409, 502-503 | Owner-held (theme pause). When released, drop `.tint(CYDomainPalette(viewerDomain).brand)` and `.cyTracksHeroScroll`, and use the system accent. | S |
| CLB-r10-nat-detail-08 | P2 | — | App/ClubActionPanel.swift:88-97, 112-122 | Move `club.application.messageHelp` and the required/too-long text into the Section `footer:`. Keep the F-08 lifecycle modifiers on the header Text (:117-120), or on the TextField row, so the pinned test still passes. | S |
| CLB-r11-detail-01 | P2 | detail wxml:863-871, js:3587-3604 | App/MPGap/Club/ClubGapManageExtensions.swift:257-293; App/ClubDetailR8Mounts.swift:30-45 | Settings sheet: add an owner-only Section 经营 with a row 俱乐部分润 (`LabeledContent`, trailing value = server `settledAmountText` from `api/club/settlement/summary`, or 暂时读不到 on failure). Tapping it opens the same `ClubGovernanceReadView(.settlement)` as CDV:204-208. Load it in `loadSettingsCounts` next to customerCountText. This is a read only, no money write. | S |
| CLB-r11-detail-02 | P2 | detail wxml:555-600 | App/MPGap/Club/ClubGapManageExtensions.swift:81, 100 | Replace `ContentUnavailableView("暂不能看可对接的活动", …)` with a catalog key `club.coopPool.permissionTitle`, and `Text(verbatim: "\(nick) 发布")` with `Text("club.coopPool.publishedBy \(nick)")`. Add both to Localizable.xcstrings (zh 「暂不能看可对接的活动」/「%@ 发布」). | S |
| CLB-r11-detail-03 | P2 | — | App/MPGap/Club/ClubGapRound4Views.swift:8-113 | Delete the dead `ClubGapManagedProjectsDirectorSection` (0 references since 0ab79f407; replaced by ClubManagedProjectsSection). It still carries the verbatim 管理中的项目 at :56. Delete its tests too if any exist. | S |
| CLB-r11-workbench-01 | P2 | workbench wxml:9-15, js:33 | App/MPReviewedPageScreen.swift:1150-1159 | On `.failed`, add `description: Text("club.workbench.enterFailed.detail")` (暂时无法进入俱乐部管理，请重试或返回俱乐部) and a second action `Button("club.workbench.backToClub") { dismiss() }` (返回俱乐部) using `@Environment(\.dismiss)`. | S |

## Regressions

None. No scored row went backwards. One piece of dead code was left behind: 0ab79f407 removed the mount of `ClubGapManagedProjectsDirectorSection` but kept the type (CLB-r11-detail-03).

## New rows found

- CLB-r11-detail-04 (P1): the G02 scan-verify POSTs have no Release composition-firewall admission. They are likely dead in Release.
- CLB-r11-detail-05 (P1): the G04 `api/coop/pool/apply` has no Release admission, and `MPFirstCoopWrites` leaves out `.apply`. Likely dead in Release.
- CLB-r11-detail-01 (P2): the settings sheet is missing the 经营 · 俱乐部分润 row and its `settledAmountText`.
- CLB-r11-detail-02 (P2): coop pool literals at ClubGapManageExtensions.swift:81 and 100.
- CLB-r11-detail-03 (P2): dead `ClubGapManagedProjectsDirectorSection`.
- CLB-r11-workbench-01 (P2): the workbench failure state has no sub line and no 返回俱乐部.

---

# Appendix B

## out-B · club r11 · topic-detail / topic-story / event-ops

App tip `b9a9d4d29` (r10 measured `82bcf2c2d`). GV = App/ClubGovernanceViews.swift, MPRPS = App/MPReviewedPageScreen.swift, CF = App/ClubGovernanceCommandForm.swift. MP = chengyinhub-xcx/pages/club/<page>/.

**Release dispatch (writes on these pages).**
- **Fixed in 193356907 (+1b520ae38): gate-05 writes.** createSeries, updateSeries, correctAttendance, saveTopicSettings, chapterRecruit and chapterFinish are in `ClubMPFirstGovernance.clubOps` (Core/ClubGovernanceProduction.swift:33-40), which is joined into `governance` at :32.
  - Their write and review-read paths are on the firewall `governancePaths` (App/MPFirstClubApprovals.swift:85-104). The chapter recruit and finish multipart paths are in `formPaths` (:110).
  - The approval is composed in Release China at App/ReviewedPlayerWriteLeases.swift:1452, behind `playerWritesEnabled`. The firewall is App/AppCompositionRoot.swift:3591.
  - Tests: ReviewedChinaLaunchCompositionTests.swift:186 and ClubGovernanceProductionTests.swift:82.
- **Also dispatches: G13a 通用玩法.** These actions go through `api/game/session/command` (MPFirstClubApprovals.swift:106, guarded by `PlaySharedRunOps.acceptsCommandBody`), from AppSession+PopupsClose.swift:147-158.
- **Still dead in Release (money is now ON): cancelOccurrence and endTopic.** Neither is in `clubOps`, and that is deliberate (ClubGovernanceProduction.swift:36).
  - Their paths `api/club/event-ops/cancel`, `api/club/topic-setting/end` and `api/club/event-ops/occurrence/status` are not on `governancePaths`.
  - Tests pin the refusal: Tests/AppUnitTests/MPFirstClubWriteRouteR10Tests.swift:72-73 and ClubGovernanceProductionTests.swift:88.
  - The confirm stays disabled with the 暂不可用 note (CF:296-297).
  - The MP sends both: event-ops/index.js:1106-1115 (取消本场 with refund) and topic-detail/index.js:1147 (结束主题 with full refund). These are **P0**.
- **reportHours / submitEvidence: not a gap.** They are also dead (GV:2276, detail-page compensation), but the MP never sends `hours/report` or `quality/evidence` (grep of the whole MP: 0 hits). No MP flow exists, so there is no gap.

## Row status

| id | sev | r11 status | evidence (app file:line @ sha) | note |
|---|---|---|---|---|
| CLB-r10-gate-05 (my pages' 6 writes) | P0 | **fixed** | Core/ClubGovernanceProduction.swift:32-40; App/MPFirstClubApprovals.swift:85-110 @193356907, 1b520ae38 | createSeries, updateSeries, correctAttendance, saveTopicSettings, chapterRecruit and chapterFinish now dispatch in Release China. |
| CLB-r10-money-01 → **CLB-r11-money-01** | **P0** | **open (now counts)** | ClubGovernanceProduction.swift:36 (excluded on purpose); MPFirstClubWriteRouteR10Tests.swift:72-73; CF:296-297 | cancelOccurrence (event-ops) and endTopic (topic-detail) never dispatch in Release. reportHours and submitEvidence are not sent by the MP, so they are not a gap. |
| CLB-G13a | P0 | **fixed** | App/ClubTopicDirectorOpsSections.swift:8-140 (rows → `ClubTopicGenericOpsSheet`, `.disabled(writeLocked…)` :50); App/ClubTopicGenericOpsSheet.swift:1-272 (Form, 时间为北京时间 :85, ledger rows :86, toolbar 取消/确认并提交 :71-78, submit :249) @50ebf1367, 91251b38d, 6428e0c58 | Shared-run submit is wired in AppSession+PopupsClose.swift:147 and admitted on the firewall. |
| CLB-G13b | P1 | **fixed** | GV:2116-2146 (`directorActive` = director host present); primary GV:2181-2188; confirm `.alert` GV:785-790; 更多 → 结束活动 GV:1753-1762 @9c917c011 | This is director FINISH, not money. |
| CLB-G13c | P1 | **fixed** (联系商家 = merchant release) | App/ClubTopicDirectorMount.swift:131-200 (`ClubTopicDirectorReadySection`, preparing only, stations and teams); 联系商家 gated on `PlayerLaunch.merchantCenterEnabled` :192 @5a2c5bee1 | 联系商家 is hidden in Release by Lane G, so it is marked merchant release and not counted. |
| CLB-G13d | P2 | **fixed** | ClubTopicDirectorMount.swift:62-86 (ProgressView / ContentUnavailableView + 重新加载), :243-330 (unknown-write copy, gated tools, 暂无榜单记录 + leaderboard rows) @7eba5ec4f | — |
| CLB-topic-detail-05 | P2 | **fixed** | App/ClubTopicDetail+Port.swift:7-22 (台账 NavigationLink in header); GV:1722-1733 (场次管理, 退出与暂停规则 in 更多) @70cccab93 | — |
| CLB-topic-detail-06 | P1 | **open** | GV:1977 still `edit(.saveTopicSettings, seed:…)` → pushed form | The write now dispatches, but there are still no inline toggles that save on change and roll back on failure. |
| CLB-topic-detail-10 | P1 | **fixed** | GV:1999-2021 (定向广播 row, disabled + footer reason, NO_RECIPIENT copy) @7c4b8510b, ea3f91375, 587a52700, 208903166 | — |
| CLB-r9-topic-detail-01 | P2 | **fixed** | App/ClubTopicMerchantContent.swift:48-59 (`copiedRow` → 手机号已复制 inline) @b92b696e6 | — |
| CLB-r9-topic-detail-02 | P2 | **fixed** | GV:1683 (one 更多; the toolbar `ClubGapTopicMoreMenu` is no longer mounted, 0 call sites) @ed97d12fe | — |
| CLB-topic-story-04 | P1 | **fixed** | Core/ClubStoryPresentation.swift:28-29, 105, 140-142; App/ClubStoryViews.swift:212-215 → ClubGapRound4Views.swift MKMapItem @87eb12b52 | — |
| CLB-topic-story-06 | P2 | **fixed** | GV:2435-2437 `ClubStoryEmptyState(title: "club.story.noRoute"…)` @b4d7d7052 | — |
| CLB-r9-topic-story-01 | P2 | **fixed** | MPRPS:397-399 `MemberMissingLinkState(title: "club.story.missingTopic")` @333115610 | — |
| CLB-G15 | P1 | **fixed** | App/ClubOpsEventView.swift:124 (hook → fabu push :78-83), :140-157 (empty 发布主题 state); paymentNotice App/ClubOpsEventFormFields.swift:25-29; windowWarning CF:400-404 @01c216f2d, d9000e3a1 | — |
| CLB-r9-event-ops-01 | P2 | **fixed** | ClubOpsEventView.swift:172, 194-204 (`Picker(.menu)` topic) @0f7ad2d13 | — |
| CLB-event-ops-05 | P2 | **partly** | Retry is fixed: ClubOpsEventView.swift:56-68 (ContentUnavailableView + 重新加载). In-view missing-param is at :53-55 @96e188c2e. | A deep link without clubId still hits `unavailable` at MPRPS:349-352 (a CYEmptyState on a CYNight ink background), so the in-view state is never reached. |
| CLB-r9-native-02 | P2 | **fixed** | App/MPGap/Club/ClubGapTopicDirectorViews.swift:26-60 (catalog keys) @269b8dac0 | That view is no longer mounted. The mount uses ClubTopicDirectorToolsSection. |
| CLB-r9-native-05 | P2 | **fixed** | ClubStoryViews.swift:161-164 `@ScaledMetric`; ClubGapRound4Views.swift:118 @6baff7f92 | — |
| CLB-r10-nat-topic-detail-01 | P2 | **fixed** | ClubTopicDetail+Port.swift:26-37 `LabeledContent` + `.monospacedDigit()` @1ae8bd9d8 | — |
| CLB-r10-nat-topic-detail-02 | P2 | **fixed** | App/ClubTopicDetailRows.swift:103-131 (`.bordered` buttons, no Circle) @bfea7b414 | — |
| CLB-r10-nat-topic-detail-03 | P2 | **fixed** | GV:2055-2071 (`.borderedProminent`, no Divider, no CYPill) @6af4ebda6 | — |
| CLB-r10-nat-topic-detail-04 | P2 | **partly** | The List uses the default style and has no cyDomainPageBackground or cyGroupedSurface (GV has 0 hits). | `.cyDomainSheet` remains at GV:1769 (quick sheet) and :809 (editor). |
| CLB-r10-nat-topic-detail-05 | P2 | **fixed** | 0 CYStatusChip in GV/Rows; Rows:67-79 plain coloured Text @bfea7b414 | — |
| CLB-r10-nat-topic-detail-06 | P2 | **fixed** | Rows:36-39 `person.crop.circle`; story cover `.clipped()` :176 @f6ecb5d45 | — |
| CLB-r10-nat-topic-detail-07 | P2 | **fixed** | ClubTopicDirectorOpsSections.swift:47-51 (system Button rows) @ecb8ab943 | — |
| CLB-r10-nat-topic-detail-08 | P2 | **fixed** | ClubTopicDirectorMount.swift:62-86, 263-281 | — |
| CLB-r10-nat-topic-story-01 | P1 | **fixed** | ClubStoryViews.swift:247-312 (row: 80 pt thumbnail, title, meta; no forced dark, no gradient, no `.white`) @5a223a87b | — |
| CLB-r10-nat-topic-story-02 | P2 | **fixed** | ClubStoryViews.swift:183-188 (`"\(n).circle.fill"`), no card background | — |
| CLB-r10-nat-topic-story-03 | P2 | **open** | GV:2505-2541. The `Picker(.menu)` is still used only at accessibility sizes. Otherwise it is a horizontal ScrollView of `.bordered` capsule buttons (:2520-2541). | — |
| CLB-r10-nat-topic-story-04 | P2 | **fixed** | GV AIGC is a plain `Label` (story body ~:2427-2431); default List style | — |
| CLB-r10-nat-topic-story-05 | P2 | **fixed** | ClubStoryViews.swift:70-77 `ContentUnavailableView`; 0 CY* in ClubStoryViews/ClubStoryHostAnswer; GV story uses ProgressView/ContentUnavailableView | — |
| CLB-r10-nat-event-ops-01 | P2 | **fixed** | ClubOpsEventView.swift:45-74, 85-96 @96e188c2e | — |
| CLB-r10-nat-event-ops-02 | P2 | **fixed** | ClubOpsEventView.swift:100-190 (`NavigationLink { } label: { Label }`), 0 CYListRow/CYRowIcon @ad06ffc86 | — |
| CLB-r10-nat-event-ops-03 | P2 | **fixed** | ClubOpsEventView.swift:484 (ClubOpsTable* removed) @36e3b4377 | — |
| CLB-r10-nat-event-ops-04 | P2 | **partly** | The capacity Section is fixed: ClubOpsEventFormFields.swift:36-63 @8506a366f. | The `ClubOpsEventReasonField` (:94-115) still stacks TextField + validation + subtitle in one VStack row. |
| CLB-r10-nat-event-ops-05 | P2 | **fixed** | 0 CYStatusChip/CYPillButton in ClubOpsEventView | — |

## Page scores

| page | r10 code | r11 code | Δ | r11 release | native grade | CY* calls |
|---|---|---|---|---|---|---|
| topic-detail | 36/49 | **48/49** | +12 | **47/49** (endTopic dead) | partly (near native: `.cyDomainSheet` ×2, `.cyText` ×5 in merchant sheet) | 0 CY* components; ~16 `.cy*` modifiers (cySheet/cyDomainSheet/cyPageTitle/cyHaptic/cyText) |
| topic-story | 31/35 | **35/35** | +4 | **35/35** | partly (chapter chip ScrollView) | 0 CY* components; ~5 `.cy*` modifiers |
| event-ops | 36/43 | **42/43** | +6 | **41/43** (cancelOccurrence dead) | partly (hub is native; reason field stack; missing-clubId route uses CYEmptyState + CYNight) | 0 CY* in the hub and fields; CF `.cyText` ×3, `.cySheet` ×4; MPRPS `unavailable` 1 CYEmptyState |

Scoring notes:
- **topic-detail:** the only missing r10 row is topic-detail-06 (inline toggles). The page went from about 32 to 47 in Release.
- **event-ops:** the missing row is event-ops-05's missing-clubId half.
- **New rows below:** they are outside the r10 denominators and are not scored.

## Fix queue

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| CLB-r11-money-01 | **P0** | event-ops/index.js:1106-1115; topic-detail/index.js:1118-1190, wxml:533-540, 644-650 | Core/ClubGovernanceProduction.swift:36-40; App/MPFirstClubApprovals.swift:85-104; Tests/AppUnitTests/MPFirstClubWriteRouteR10Tests.swift:72-73; Tests/CoreTests/ClubGovernanceProductionTests.swift:88 | Add a `clubMoney: Set = [.cancelOccurrence, .endTopic]` and union it into `governance`, gated on the Release money flag if one exists. Then, in `governancePaths`: add `api/club/event-ops/cancel`, `api/club/topic-setting/end` and the review read `api/club/event-ops/occurrence/status`; add a `readShapes` entry `"api/club/event-ops/occurrence/status": .init(ids: ["clubId","activityId"])`. Flip the two `XCTAssertFalse` cancel/end assertions to true. Keep the :88 non-financial assertion scoped to `clubOps`. Finally, add a test that both have `canDispatch == true` in a Release China composition. | M |
| CLB-r11-topic-detail-01 | P1 | topic-detail/index.js:1118-1190 (`cancellationEpoch`, `cancellationIntent`, failedSessions / cancellationState PENDING/DONE) | Core/ClubGovernanceCommands.swift:112 (`.endTopic` requiredKeys = []); Core/ClubTopicEndSummary.swift (unused, 0 call sites) | Send `cancellationEpoch` (from the topicSettings read `cancellationEpoch`) in the endTopic body. Validate the reply through `ClubTopicEndSummary`. If failedSessions is not empty, keep the confirm open with 「N 场没能取消：<first>」. If the state is PENDING, show 原结束请求仍在处理中，请按原请求查回. On DONE, toast `endResultText` (已结束，退款 N 笔). Do this together with money-01. | M |
| CLB-topic-detail-06 | P1 | topic-detail wxml:503-530; js:1245-1274 | GV:1977 | In the topicSettings read, replace `edit(.saveTopicSettings…)` with three inline `Toggle`s (合作开放 coopOpen / 置顶 pinned / 仅成员 memberOnly). Each toggle dispatches saveTopicSettings on change with all three values and is disabled while saving. On failure it rolls back and shows the server sentence in the footer. | M |
| CLB-r11-topic-detail-02 | P2 | topic-detail/index.js:419, wxml:316 | GV:1791 area (upcoming section) / GV footer | When `topicStats["paidSessionsBlocked"] == true`, show the footer text 这个主题暂不能在线收款，玩家无法在线报名付费场次 under the 接下来 section, as `.secondary` text. | S |
| CLB-r11-topic-detail-03 | P2 | topic-detail wxml:296-312 (D9 复盘) | App/ClubTopicDirectorMount.swift:243-330 (`ClubTopicDirectorToolsSection` hides everything when finished) | When the projection status is FINISHED, add a Section 活动复盘. Use `LabeledContent` metric rows from `projection.club["recap"]`, with 完成情况 / 节点完成 rows, or 复盘尚未生成 when there is no recap. Add a 复制复盘数据 Button when `recap.exportAvailable` (the PlayDirectorRuntime export at Core/PlayDirectorRuntime.swift:161), and 显示/隐藏榜单. | M |
| CLB-event-ops-05 (rest) | P2 | event-ops wxml:12; js:479 | MPRPS:349-352 | In the `else` branch, replace `unavailable` with `MemberMissingLinkState(identifier: "clubOpsEvent.missingParam")` (链接已失效 + 返回), matching ClubOpsEventView.swift:53-55. | S |
| CLB-r11-event-ops-01 | P2 | event-ops wxml:86-87 (CU-C-73 correctionWindowText) | App/ClubOpsEventInlineRoster.swift:12-30 | Under the segmented Picker, when `roster.correctionOperable == false`, show the same orange note as ClubRosterBucketContent.swift:42-48 (`clubOpsEvent.roster.window <range>` / `windowGeneric`). | S |
| CLB-r10-nat-topic-detail-04 (rest) | P2 | — | GV:1769, 809 | Replace `.cyDomainSheet(detents:)` with `.presentationDetents([.medium, .large])` (quick sheet) and `[.large]` (editor). | S |
| CLB-r10-nat-topic-story-03 | P2 | topic-story wxml chapter chips | GV:2505-2541 | Always use the `Picker(.menu)` branch (:2506-2516) and delete `chapterChips`. | S |
| CLB-r10-nat-event-ops-04 (rest) | P2 | — | App/ClubOpsEventFormFields.swift:94-115 | `ClubOpsEventReasonField`: put the TextField in a `Section { } footer: { subtitle + red validation }`. Remove the VStack. | S |

## Regressions

None found:
- **Topic and story files:** every change to the slice files since 82bcf2c2d is additive or native-only.
- **Release score:** it rose. The previous gate-05 loss is gone. The only new Release losses (cancelOccurrence, endTopic) come from the scope change (money ON), not from a commit.

## New rows found

- **CLB-r11-money-01 (P0):** cancelOccurrence and endTopic are dead in Release now that money is ON. This supersedes CLB-r10-money-01.
- **CLB-r11-topic-detail-01 (P1):** the endTopic body has no `cancellationEpoch`, and there is no PENDING/DONE/failedSessions handling. `ClubTopicEndSummary` exists but is unused.
- **CLB-r11-topic-detail-02 (P2):** the paidSessionsBlocked paymentNotice is missing on topic-detail.
- **CLB-r11-topic-detail-03 (P2):** the ended director recap (活动复盘 / 复制复盘数据) is not inline.
- **CLB-r11-event-ops-01 (P2):** the inline hub roster lacks the CU-C-73 correction-window note.

---

# Appendix C

## out-C — r11 club slice C: governance / roles / apply / create / enroll / edit (+scene-club-edit) / badges

App tip `/home/user/app-r11` @ b9a9d4d29 (r10 measured 82bcf2c2d). All SHAs cited are new since 82bcf2c2d (each checked with `merge-base --is-ancestor`: on the tip, not in r10). Abbreviations: GV = App/ClubGovernanceViews.swift, CF = App/ClubGovernanceCommandForm.swift, OPS = App/ClubOperationsViews.swift, GS = App/ClubOpsGovernanceSections.swift, MPRPS = App/MPReviewedPageScreen.swift, ENR = App/ClubEnrollmentView.swift, BDG = App/ClubBadgeManagementView.swift. MP paths are relative to chengyinhub-xcx/pages/club/.

Money scope (11-26): no write in this slice is a money write. Enroll shows ticket money read-only (实收/已退). Refund lives on checkin-detail, which is outside this slice. **Cross-slice flag:** the gate-05 tests pin `cancelOccurrence` and `endTopic` **out** of the Release live set (Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift:187-188, Core/ClubGovernanceProduction.swift:36 comment "refund (owner decision #6)"). Under the 11-26 money-on rule these refund writes should count, so the event-ops and topic-detail slices must treat them as open Release gaps.

## Row status

| id | sev | r11 status | evidence (app file:line @ sha) | note |
|---|---|---|---|---|
| CLB-r10-gate-05 | P0 | **fixed** | Core/ClubGovernanceProduction.swift:31-40 (`clubOps` = sendNotification, retryNotification, issueGroupCode, saveCustomer, createSeries, updateSeries, correctAttendance, saveTopicSettings, chapterRecruit, chapterFinish; `governance = base ∪ clubOps`) @193356907. App/MPFirstClubApprovals.swift:10-16 (approval over `ClubMPFirstGovernance.governance`), :85-101 (write and review-read paths on `governancePaths`), :110 (`formPaths` for chapter recruit/finish and `api/topic/info-to-user`). Release composition passes it at App/ReviewedPlayerWriteLeases.swift:1452 (`playerWritesEnabled`, which is true in reviewedDeployment, App/RegionalLaunchConfiguration.swift:89-90). | I checked all 10 paths (Core/ClubGovernanceCommands.swift:10-30) and their reviewRead paths (Core/ClubGovernanceContracts.swift:115-138) against `governancePaths`/`formPaths` and `ClubMPFirstGovernance.paths`; `permits` takes the `liveOperations` path (Core/ClubGovernanceProduction.swift:81). **Pinned by tests:** Tests/CoreTests/ClubGovernanceProductionTests.swift:61-86 `testMPFirstClubOpsDispatchInChina` (each of the 10 `permits` plus a non-nil production service) and Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift:186 (Release China `liveOperations ⊇ clubOps`); firewall Tests/AppUnitTests/MPFirstClubWriteRouteR10Tests.swift:19, 59. Remaining caveat (out of slice): cancelOccurrence, endTopic, reportHours and submitEvidence are still excluded, which is now a gap under money-on. |
| CLB-r10-badges-01 | P0 | **fixed** | App/AppCompositionRoot.swift:609 (`self.clubBadgeManagementApproval = { MPFirstClubApprovals.badges($0) }` inside `grantPlayerWrites`, China plus reviewed plus playerWritesEnabled, :594-601); App/MPFirstClubApprovals.swift:41-49; firewall :107, :133, :140 @704e52991 | MPRPS:330-333 now gets a host, so the page and the detail 勋章 entry are reachable. Tests: ReviewedChinaLaunchCompositionTests.swift:190-192 (non-nil in Release China) and Tests/AppUnitTests/ClubBadgeHostDefaultTests.swift:24-30. |
| CLB-r8-governance-01 | P2 | **fixed** | Core/MiniProgramPageLink.swift:78-81 (`required: []`); Core/ClubGovernanceEntryRoute.swift:37 → `.missingClub`; MPRPS:423 `MemberMissingLinkState("club.governance.missing")` @00aab0078 | |
| CLB-r10-roles-01 | P2 | **fixed (verified)** | GV:947-961 `finishRoleManagementReturn` sets `roleRereadToast = "club.roles.rereadFailed"`, shown by `.clubIslandStatus` GV:384 | No change needed. |
| CLB-apply-05 | P1 | **fixed** | CF:174-175 mounts `ClubHostCertImagesSection` (App/ClubHostCertImagesSection.swift:8-75: `PhotosPicker`, at most 9, uploadOSS `image_free`, swipe to delete); `certImages` is a required hostApply key (Core/ClubGovernanceCommands.swift:96) @35cb3f59b | The uploader is injected at the root (App/QuestifyApp.swift:569). `api/common/uploadOSS` is on the player-write list (App/ReviewedPlayerWriteLeases.swift:834). |
| CLB-r10-apply-01 | P2 | **merchant release** (code fixed) | GV:1504-1520: full-screen cover instead of a push; whole branch behind `PlayerLaunch.merchantCenterEnabled` | Not counted. |
| CLB-r10-apply-02 | P2 | **merchant release** (open) | GV:1499 `value["merchantActive"].bool ?? true`; Core still has no producer | Not counted. |
| CLB-r9-create-01 | P2 | **fixed** | OPS:192-198 `ProgressView { Text("club.ops.create.checking") }` (= 正在确认创建资格) @b4f4c4227 | |
| CLB-r9-create-02 | P2 | **fixed** | OPS:184-188 `hostAutoOpenActive`, :291 `.modifier(ClubCreateHostAutoOpen…)`; App/ClubCreateHostApplicationLink.swift:20-40 @4f90bc64b | Behaviour is present. Two small differences remain: the app pushes where the MP uses `redirectTo` (create js:192-202), and there is no transient 正在前往主理人申请 / 即将打开申请页 state (create wxml:12-15). Not scored. |
| CLB-r9-create-03 | P2 | **fixed** | OPS:279-289 `ToolbarItem(.topBarTrailing) Text("\(step) / 4")` @69a8b248d | |
| CLB-r9-create-04 | P2 | **open (owner-blocked)** | OPS:1302 still `ClubCreateCityRow` (App/ClubKit/ClubCreateKit.swift:156-250) | HANDOFF-R1 MC-10 chose the picker; needs an owner call. |
| CLB-r10-create-01 | P2 | **fixed** (housekeeping) | OPS:1197-1198 comment now matches @4ad6e2b73 / 03d5694d0 | Not a parity row. |
| CLB-enroll-08 | P2 | **fixed** | Core/MiniProgramPageLink.swift:70-71 (`required: []`); MPRPS:340-348 → `ClubFirstOwnedEntry` (MPRPS:1181-1217: `clubOwned()` first row; none → `ContentUnavailableView("club.enroll.noOwned")` = 还没有可管理的俱乐部; failed → 重新加载) @42450ede4 | |
| CLB-r9-enroll-01 | P2 | **fixed** | ENR:89-96 `ProgressView` + `club.enroll.refreshing` (正在更新报名名册…) while a loaded roster refreshes @aa40ec35d | |
| CLB-r9-edit-01 | P2 | **fixed** | MPRPS:327-329 no id → `MemberMissingLinkState("club.edit.missing")` @34fe2a021 | |
| CLB-r8-badges-02 | P2 | **fixed** | BDG:299-314 title `clubR8b.badges.createFailedTitle` (勋章没有创建); sub = server msg, else 勋章没有创建成功 @7f9b218c1 | |
| CLB-r10-nat-shared-01 | P2 | **fixed** | GV, CF, OPS, ENR and App/ClubOperationsReviewView.swift have 0 `scrollContentBackground(.hidden)`, `cyDomainPageBackground`, `cyGroupedSurface` or `cyDomainScreen` (grep) @5a223a87b / ad06ffc86 / 35852c11d / 98294c98b | The remaining `cyDomainSheet` / `cySheet` are thin wrappers over system detents (App/DesignSystem/CYSheetModal.swift:92-108). |
| CLB-r10-nat-shared-02 | P2 | **fixed** | GV:2676-2689 `ClubGovActionChrome`: `.borderedProminent` / plain / `.borderless` @5a223a87b | |
| CLB-r10-nat-shared-03 | P2 | **fixed** | CF:481-486 discard is a `.confirmationDialog`; App/ClubKit/ClubMemberActionKit.swift:77-131 `ClubConsequenceSheet` is now `NavigationStack{List{Section}}` + `Button(role:.destructive)` + toolbar 取消 + `.presentationDetents` @5a223a87b | `CYConfirmConsequence` survives only as a data struct (ClubGovernanceConsequence.swift:52-75). |
| CLB-r10-nat-governance-01 | P2 | **fixed** | GS:363-376 `ContentUnavailableView` (lock) + `.bordered` 返回 | |
| CLB-r10-nat-governance-02 | P2 | **fixed** | GV:652-657 `ProgressView`; GV:671-700 failures are `ContentUnavailableView` + 重试 | |
| CLB-r10-nat-governance-03 | P2 | **partly** | Colours fixed: App/ClubOpsMemberActionCard.swift:41, 51, 56 and GS:42, 51 use `.secondary`/`.tertiary`/`Color.red`. | Left: GS has 35 `.cyText(...)` (e.g. GS:75-89, 205-229) and GS:139-153 `CYSpacing`. |
| CLB-r10-nat-roles-01 | P2 | **fixed** | App/ClubRoleAssignmentPicker.swift:157-193: two `Picker(...).pickerStyle(.navigationLink)` @39eb240f6 | |
| CLB-r10-nat-roles-02 | P2 | **fixed** | GS:46-53 `ClubOpsTag` is now plain `.subheadline` text, with no capsule | |
| CLB-r10-nat-apply-01 | P2 | **fixed** | GV:671-683 signed-out `ContentUnavailableView` + `.borderedProminent` 登录; GV:1500 merchant `ContentUnavailableView` | |
| CLB-r10-nat-apply-02 | P2 | **fixed** | GV:1535-1537 `LabeledContent` 已生效; GV:1552 intro `Text(...).font(.title2.bold())` in a normal row @79368d37b | |
| CLB-r10-nat-apply-03 | P2 | **fixed** | CF:764-797 system-labelled `TextField(text:prompt:)` rows; errors in step footers (CF:147, 153-156); 上一步 / 下一步 are system buttons (CF:304-312, 748-758) @8e7d32df5 | |
| CLB-r10-nat-create-01 | P2 | **fixed** | OPS:1207-1258 checkmark rows (`checkRow`) for 类型 and 方向; field errors in the footers @39e658f86 | |
| CLB-r10-nat-create-02 | P2 | **open** | → CLB-r9-create-04 (owner) | The city picker itself is native (`searchable` List, ClubCreateKit.swift:189-240). |
| CLB-r10-nat-create-03 | P2 | **fixed** | OPS:1677-1714 `ClubCreateStepBarView`: `.borderedProminent` / `.bordered` in `safeAreaInset` on `.bar` | This is the row's allowed alternative. |
| CLB-r10-nat-create-04 | P2 | **fixed** | OPS:204-237, 401-408 `ContentUnavailableView`; OPS:562 submitting `ProgressView` @2a63eff61 | |
| CLB-r10-nat-create-05 | P2 | **fixed** | OPS:1482-1513 `LabeledContent { TextField(label, text:, prompt:) }` @11b3a4069 | |
| CLB-r10-nat-create-06 | P2 | **fixed** | App/ClubOperationsReviewView.swift:33-51 `.navigationTitle` + toolbar `.cancellationAction`/`.confirmationAction` @4d2387502 | |
| CLB-r10-nat-enroll-01 | P2 | **fixed** | ENR:88-160: `ProgressView` loading/refresh, `Label` stale note, plain row `Button` 重新加载, `ContentUnavailableView` empty @35852c11d | |
| CLB-r10-nat-enroll-02 | P2 | **fixed** | ENR:286-295 cover `.clipped()` (no radius); no `cyPressTracking`, min-heights, `listRowInsets`, status chip or `palette.*` @b698e035b | ENR still has 21 `CYSpacing.*` tokens. |
| CLB-r10-nat-edit-01 | P2 | **fixed** | OPS:364-387 `clubIdentityHero` is now a `Label` row with a system-size cover @c05c086c3 | |
| CLB-r10-nat-edit-02 | P2 | **partly** | Done: OPS:216-224 no-permission `ContentUnavailableView`; OPS:374 role is a `Label`, not a chip; save is a `.borderedProminent` in a `.bar` inset (OPS:257-266). | Left: save-failed is still an inline VStack in the bottom bar (OPS:519-536), not an `.alert`. |
| CLB-r10-nat-badges-01 | P1 | **fixed** | BDG:16-31 `List`, `ProgressView`, `ContentUnavailableView` + 重新加载 @5a223a87b | |
| CLB-r10-nat-badges-02 | P1 | **fixed** | BDG:355-380 `NavigationStack{Form}` + toolbar 取消 / 创建 @5a223a87b | |
| CLB-r10-nat-badges-03 | P1 | **fixed** | BDG:63-70 toolbar 创建; BDG:175 颁发 swipe action @4c9008597 | Small leftovers: BDG:144 thumbnail `clipShape(RoundedRectangle(8))`; empty uses `ClubMPEmptyState` (a `ContentUnavailableView` with MP art, App/ClubKit/ClubMPArt.swift:46-61). |
| CLB-r10-nat-badges-04 | P1 | **fixed** | BDG:190-245 member picker `NavigationStack{List}`; BDG:252 `.confirmationDialog` @fe15a7863 | |

Totals for the 39 rows above (the two `merchant release` rows not counted): **fixed 34, partly 2 (nat-governance-03, nat-edit-02), open 2 (r9-create-04 / nat-create-02, owner-blocked), regressed 0.**

## Page scores

| page | r10 code | r11 code | Δ | r11 release | native grade | CY* calls (r10 method: components/styles/sheets) + tokens |
|---|---|---|---|---|---|---|
| governance | 26/27 | **27/27** | +1 | 27 | native (tokens left) | 0 components; wrappers `cySheet`/`cyDomainSheet` ~9 (shared GV); tokens `.cyText` 38 (GS 35, CF 3), `CYSpacing` ~11 |
| roles | 24/24 | **24/24** | 0 | 24 | native (tokens left) | 0 components; `.cyText` 4 + GS shared; `CYSpacing` 1 |
| apply | 23/24 | **24/24** | +1 | 24 | native | 0 components; `.cyFullScreenCover` 1 (merchant only); `.cyText` 3 (CF) |
| create | 21/25 | **24/25** | +3 | 24 | native | 0 components; `.cySheet` 2 (city); `.cyText` 3; open: city picker vs typed field (owner) |
| enroll | 21/24 | **23/24** | +2 | 23 | native | 0 components; `CYSpacing` 21 |
| edit (+scene-club-edit) | 24/25 | **25/25** | +1 | 25 | native (save-failed block left) | 0 components; `.cySheet` 4 (OPS shared) |
| badges | 24/25 | **25/25** | +1 | **25** (was 0) | native (was custom) | 0 components; `.cySheet` 2; `CYSpacing` 6; one RoundedRectangle thumb clip |
| **slice** | 163/174 | **172/174 (98.9%)** | +9 | **172** (r10 release 139 + 0 = 139) | 7/7 native | |

- **Release score.** Release equals code on every page. Gates 01/02/03 still hold: create and edit go through `approvalSource → MPFirstClubApprovals.operations`, App/AppSession.swift:6072. The governance and roles approvals are composed in Release China. The badges approval is now composed (badges-01).
- **Enroll gap.** r10 listed 3 open rows on enroll: enroll-08, r9-enroll-01 and an unnamed "+1". Two are fixed. The third is not named in r10, so it stays open at 23/24.
- **Create gap.** The remaining open row is r9-create-04 (owner).
- **New rows.** The new row below is not added to the denominators. If it is adopted, edit becomes 25/26.

## Fix queue

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| CLB-r9-create-04 (+nat-create-02) | P2 | create/index.wxml:119-121 | OPS:1302; App/ClubKit/ClubCreateKit.swift:156-250 | **Owner decision first (MC-10 vs MP).** If MP wins: replace `ClubCreateCityRow` with `LabeledContent { TextField("club.ops.city", text: $draft.city, prompt: Text("如 上海")) }`, cap the input at 20 characters in `.onChange`, and put the rule in the Section footer. Then delete `ClubCreateCityPicker`. | S |
| CLB-r10-nat-governance-03 | P2 | — | GS:75-89, 123, 205-229 (35 × `.cyText`); GS:139-153 `CYSpacing` | Replace `.cyText(.meta)` → `.font(.footnote)`, `.cyText(.bodyCompact)` → `.font(.subheadline)` and `.cyText(.cardTitle)` → `.font(.headline)`. Drop the explicit `CYSpacing` in HStack/VStack (use the default spacing). | S |
| CLB-r10-nat-edit-02 (rest) | P2 | edit/scene-club-edit save-failed | OPS:519-536 `editSaveBar` | When `editSaveFailed`, keep the plain 保存修改 button in the bar and present `.alert("clubR8b.edit.saveFailed", isPresented:)` with the server `message` and the buttons 重新保存 (calls `prepare(.update…)`) and 继续编辑 (`state = .idle`, role `.cancel`). | S |
| CLB-r11-edit-01 | P2 | edit/index.js:23-30 (`onDissolved`: toast.success 俱乐部已解散, then navigateBack, else switchTab talent list) | CF:906-907 (dissolve receipt only clears the draft); GS:450-460 `ClubOpsGovernanceSuccess` has no `.dissolve` case | (1) Add `case .dissolve: return "clubOpsGov.success.dissolve"` (zh 俱乐部已解散). (2) In CF, add a `.task(id: route.operation == .dissolve && receipt != nil)` like the transferOwner one at CF:502-507: after 0.5 s, dismiss the form **and** pop the edit page (pass a `clubDissolvedReturn` closure through the environment from OPS that calls `dismiss()`), so the user does not land back on the edit form of a dissolved club. | M |
| (cross-slice) gate money | P0 for event-ops / topic-detail owner | event-ops cancel; topic-detail end | Core/ClubGovernanceProduction.swift:36-40; Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift:187-188; App/MPFirstClubApprovals.swift:123-125 (firewall refuses `pay/refund/settlement` substrings) | With money on (11-26), `cancelOccurrence`, `endTopic`, `reportHours` and `submitEvidence` still never dispatch in Release, and the tests pin that. **Not this slice; hand to the event-ops / topic-detail auditor.** | M |

## Regressions

None. Spot-checked the r10-present rows on these pages after the native sweep: governance-01 card (GV:1579), G19 transfer link (OPS:497-503), r8-create-01 去改名称 (OPS:578-581), roles re-read toast (GV:961), transfer auto-leave (CF:502-507). All intact.

## New rows found

- **CLB-r11-edit-01 (P2):** after a confirmed 解散, the MP toasts 俱乐部已解散 and leaves the edit page (edit/index.js:23-30). The app stays on the dissolve receipt with no dissolve-specific success line, and the edit page under it still shows the dissolved club.
- Minor, noted only and not scored: create-02 pushes the apply page instead of the MP's `redirectTo`, and has no transient 正在前往主理人申请 / 即将打开申请页 (create wxml:12-15).

---

# Appendix D

## out-D · club r11 · slice D (notify, settlement, customer-detail, checkin-detail, join-requests, group-code, customers, payout-receiver)

App tip `/home/user/app-r11` @ b9a9d4d29 (r10 measured 82bcf2c2d). MP `/home/user/mp-src/chengyinhub-xcx/pages/club/<page>/`. Every line below was read on the tip. Receipts were used only to find SHAs, and every claim was re-checked in code. No compiler was run, so dispatch was traced by reading code, not by running it.

Abbreviations: CF = App/ClubGovernanceCommandForm.swift, GV = App/ClubGovernanceViews.swift, MPRPS = App/MPReviewedPageScreen.swift, PRV = App/ClubPayoutReceiverView.swift, PRB = App/PayoutReceiverBridge.swift, RPWL = App/ReviewedPlayerWriteLeases.swift, CRC = Core/ChinaReviewedRouteCapability.swift.

### Release dispatch trace (gate-05 and money)
- **Non-money ops writes now dispatch in Release (China).** `ClubMPFirstGovernance.clubOps` holds sendNotification, retryNotification, issueGroupCode and saveCustomer, and is joined into `governance` (Core/ClubGovernanceProduction.swift:31-40). The approval is composed at RPWL:1452 (`playerWritesEnabled ? MPFirstClubApprovals.governance(context)`), with endpoints from `paths(for: governance)` (App/MPFirstClubApprovals.swift:10-16). The composition firewall admits the POSTs through `MPFirstClubWriteRoute.accepts` (App/AppCompositionRoot.swift:3591; App/MPFirstClubApprovals.swift:85-101; `api/topic/info-to-user` is in formPaths at :110). Each body passes `readShapes`/`moneyKeys`, checked by hand. SHAs: 193356907, fabccf0a7, 7c201f047.
- **Join-requests approve/reject now dispatch.** `api/club/join-requests` and `join-request/approve|reject` are on the firewall with exact shapes (App/MPFirstClubApprovals.swift:98-100, 176-178). The service uses the composition transport (App/AppSession.swift:7340; Core/ClubManagementService.swift:41-48). SHA 03d5694d0.
- **The money switch is ON in Release.** `ReviewedAreaSwitch.installReleaseMoneyDerivation` runs from the shipped host (App/RegionalLaunchConfiguration.swift:21). `openMoney` is true for any host (App/ReviewedAreaSwitch.swift:94-96), so `ReleaseMoneyWriteSwitch.payoutEnabled`, `.refundEnabled` and the rest are true (CRC:2693-2699). SHA 139e06853.
  - **Unbind dispatches.** PRB `AppLease` (payoutOpen) → Core `PayoutReceiverTransport` → firewall's last branch → `acceptsPlayerWrite` → `OwnerDecisionGuardLease.admits` (RPWL:9-29, 66).
  - **Withdraw works.** The MP has no network withdraw: settlement/index.js:266-281 opens a customer-service popup. The app does the same with `NavigationLink { WithdrawalSupportContactView() }`, disabled unless the balance is positive (PRV:375-378). The withdraw route is `forcedOff` (CRC:778-780), which is correct because nothing sends it.
  - **Bind is dead.** `PRB.weChatCode` is never assigned (PRB:17, with no other assignment in App). `weChatSDKConfiguration = nil` (App/AppSession.swift:3413). The bind path is also missing from `OwnerDecisionGuardLease.paths` (RPWL:10-13), and Core/OwnerDecisionGuards.swift:7 says "native never sends bind". The UI shows an MP-only label (PRV:121-133).
  - **Check-in refund is dead.** `ownerRefundApproval` defaults to nil (App/NativeRuntimeDependencies.swift:57), and nothing passes it (RPWL:1448-1462; grep finds no `ownerRefundApproval:` argument in App). As a result `ClubOwnerRefundConfiguredAccess.canDispatch == false` (Core/ClubOwnerRefundApprovedAccess.swift:43-47), and the panel shows `club.refund.disabled` (App/ClubOwnerRefundPanel.swift:56-57).
  - **FE 标记已结清 (settle) is dead.** `ClubFEReferenceMoneyWriteGate.allowsSettle` is a `static let ... = false` constant outside TEST (App/ClubFEReferenceSettlementHost.swift:7-13, 47, 64). `api/fe/reference-settlement/settle` is also in no route grant: CRC:619-622 lists only the reads.
- **App equivalent of the MP's `wx.login` jsCode (bind).** The MP posts `{clubId, jsCode, consent}`, and the server runs jscode2session for the **MP appid**, then adds that openid as a WeChat Pay profit-sharing receiver ("收入将分账到你本人的微信").
  - **What the app would need.** The native equivalent is WeChat OpenSDK `SendAuthReq`, which returns an OAuth `code` for the **mobile-app appid**.
  - **Why it can't work today.** The server bind cannot accept that code: it needs sns/oauth2 exchange, and a receiver under the app appid or a unionid mapping. The app also has no WeChat SDK configured in Release.
  - **Conclusion.** No in-app path works today. This needs an owner decision (WeChat Open Platform app plus mchid binding) and a backend bind variant before Core/App can wire it. Interim: keep the MP-only label, ideally with a `WXLaunchMiniProgram` jump, which also needs the SDK.

## Row status

| id | sev | r11 status | evidence (app file:line @ sha) | note |
|---|---|---|---|---|
| CLB-r10-gate-05 (notify/group-code/customer-detail part) | P0 | **fixed** | Core/ClubGovernanceProduction.swift:31-40; App/MPFirstClubApprovals.swift:85-101,110; RPWL:1452; App/AppCompositionRoot.swift:3591 @193356907, fabccf0a7 | Traced by reading code. The event-ops and topic-detail parts belong to other slices. |
| CLB-r10-notify-01 | P0 | **fixed** | as above; CF:296-297 now enabled because `canDispatch` is true @193356907 | Send dispatches in Release. |
| CLB-r10-group-code-01 | P0 | **fixed** (with a caveat) | `.issueGroupCode` in clubOps; App/MPFirstClubApprovals.swift:92,110 @193356907, 7c201f047 | Activity-only links still fail before dispatch; see CLB-r11-group-code-01. |
| CLB-r10-customer-detail-01 | P1 | **fixed** | `.saveCustomer` in clubOps; `api/club/crm/customers/tag-remark` + detail read at App/MPFirstClubApprovals.swift:93,96,171 @193356907 | |
| CLB-notify-05 | P1 | **fixed** | CF:378-397 has an inline 刷新 / `ProgressView` 刷新中… with no pushed page @e93c5b952, 14407904f | e93c5b952 also removed the only entry to 只重试失败项; see CLB-r11-notify-01. |
| CLB-r10-nat-notify-01..04 | P2 | **fixed** | CF:326-352 (system Form buttons, no `.questifyPrimary`); App/ClubNotificationAudienceView.swift (no CY* UI); App/ClubOpsJoinNotifyViews.swift (0 CY*) @ad06ffc86, bfea7b414, 5a223a87b | |
| CLB-customer-detail-04 | P1 | **partly** | Editor rows are native: `.onDelete` at App/ClubOpsCustomerViews.swift:484, `.onSubmit` at :496, `TextField(axis: .vertical)` at :507 @a4e34092d | The editor still opens in `.cySheet(item: $editor)` at GV:805-809, not inline (MP wxml:83-118). |
| CLB-r10-nat-customer-detail-01 | P2 | **fixed** | App/ClubOpsCustomerViews.swift (LabeledContent metrics, ContentUnavailableView) @7623036a3 | CYAvatarView remains at :217. |
| CLB-r10-nat-customer-detail-02 | P2 | **partly** | as customer-detail-04 | |
| CLB-group-code-06 | P1 | **fixed** | CF:921-928: the receipt is checked by activityId, and clubId only when known @a2f6f5f38 | |
| CLB-group-code-05 | P1 | **fixed** | MPRPS:362-364 `ClubGroupCodeMissingLinkView`; App/ClubKit/ClubGroupCodeSessionStep.swift:67 `onOpenManage` wired, :108-131 @ee0e1472a | |
| CLB-r10-nat-group-code-01 | P1 | **fixed** | App/ClubGroupCodePresentation.swift:25-38 shows the QR on a white quiet zone in a plain row; `CYClubGameCodeCard` has 0 references outside its own file @dcdced85a | Dead file remains; see CLB-r11-nat-group-code-04. |
| CLB-r10-nat-group-code-02/03 | P2 | **fixed** | CF has no CYPill/RoundedRectangle; ClubGroupCodeSessionStep.swift:46,51 (ProgressView, ContentUnavailableView); the picker uses `NavigationLink` because `sessionDestination` is passed (:68 → ClubGapRound4Views.swift:283) | The Button+chevron branch (ClubGapRound4Views.swift:285-293) is unreachable from this page. |
| CLB-settlement-05 / -06 / r9-settlement-01 | P1 | **still fixed** | PRB:13 `readsOpen`; PRV:375-388 withdraw disabled + hints; App/ClubPersonalFundsStagesSection.swift | |
| CLB-r10-nat-settlement-01..06 | P2 | **fixed** | PRV:68 `themeDomain(.player)` @39f9f4f57; PRV:316-336 LabeledContent @37041e3bc; App/ClubFEReferenceSettlementHost.swift:86-98 @ed617b4ab; ClubGapRound4Views.swift:213-249 DatePicker @ee1c2fc80; App/ClubOwnerFundsView.swift:225-320 @4c7d8bcd3/377be9f17; App/ClubOpsSettlementViews.swift:3-30 @48bcc9517 | Duplicate club-b/club-d commits merged cleanly. |
| CLB-r9-payout-receiver-02 | P2 | **fixed** | PRV:122-133: no bind button without a code; shows the `payoutReceiver.bind.mpOnly` label @f95ea5f56 | |
| CLB-payout-receiver-01 (was money, not a gap) | **P0** | **open** | PRB:15-17 (never assigned); App/AppSession.swift:3413 `weChatSDKConfiguration = nil`; RPWL:10-13 (bind not admitted); PRV:176-188 | MP bind (index.js:106-121) is dead in Release. Blocked on owner + backend (app OAuth code). |
| unbind (payout-receiver) | — | **present in Release** | PRV:134-136, 190-198 → PRB:48-56 → RPWL:24-28, 66 | Traced by reading code. |
| CLB-r10-nat-payout-receiver-01/02 | P2 | **fixed** | PRV:44-66 (`.alert` / `.confirmationDialog` destructive), PRV:71-145 (ContentUnavailableView, LabeledContent, system buttons) @35852c11d | |
| settlement withdraw (was money, not a gap) | — | **present in Release** | PRV:375-378 → App/WithdrawalSupportContactView.swift | Matches MP (customer-service hand-off, no POST). |
| settlement FE settle POST (was money, not a gap) | P1 | **open** → CLB-r11-settlement-01 | App/ClubFEReferenceSettlementHost.swift:7-13,47,64; CRC:619-622 | |
| checkin refund panel (was money, not a gap) | **P0** | **open** → CLB-r11-checkin-detail-01 | App/NativeRuntimeDependencies.swift:57; RPWL:1448-1462; Core/ClubOwnerRefundApprovedAccess.swift:13,43-47 | |
| CLB-r10-nat-checkin-01/02 | P2 | **fixed** | App/ClubCheckinRailView.swift:150-163 (`photo` glyph, `.clipped()`) @5b710fe37/d24ab1c1c; App/ClubOwnerRefundPanel.swift:30-58 system text @a9a540084 | |
| CLB-r10-join-requests-01 | P2 | **fixed** (it was a real gap) | App/MPFirstClubApprovals.swift:98-100,176-178 @03d5694d0 | Approve/reject now pass the Release firewall. |
| CLB-r10-nat-join-requests-01 | P2 | **fixed** | App/ClubManagementView.swift: no clear rows, hidden separators or insets; ContentUnavailableView :63,65,90,144; ProgressView :68,201 @497afb251 | |
| CLB-r10-nat-customers-01/02 | P2 | **fixed** | GV uses `Picker(.segmented)` + `.searchable`; App/ClubOpsCustomerViews.swift:92-108 @5a223a87b | |
| CLB-r11-notify-01 | P1 | **regressed** | e93c5b952 removed CF's `NavigationLink { ClubGovernanceReadView(operation: .notificationStatus …) }` (CF:453 @82bcf2c2d). That view was the only host of `edit(.retryNotification)` (GV:1933, 2051) | 只重试失败项 (MP wxml:108-110) is no longer reachable from the composer. |
| CLB-r11-group-code-01 | P1 | **new** | `issueGroupCode.reviewRead = .topicOverview` (Core/ClubGovernanceCommands.swift:73) needs `topicId` (Core/ClubGovernanceContracts.swift:169,183). Coordinator `prepare` reads it first (Core/ClubGovernanceCoordinator.swift:152) | Activity-only links (MPRPS:354-356 with no topicId; App/PlayExperienceView.swift:1870 leader 展示整团码) throw `invalidRequest`. The MP issues with `{activityId}` alone (group-code/index.js:44-62, 93-105). |
| CLB-r11-settlement-01 | P1 | **new** | App/ClubFEReferenceSettlementHost.swift:7-13 | 标记已结清 is dead in Release (see above). The MP marks the record as settled offline ("钱不经平台"), so I scored it P1, not P0. |
| CLB-r11-checkin-detail-01 | P0 | **new** | see the refund row | MP 清退并退款 (checkin-detail/index.js:143+, wxml:77-88) never dispatches. |
| CLB-r11-settlement-02 | P2 | **new** | PRB:7, 11-12, 15-16; App/ClubFEReferenceSettlementHost.swift:5-6; PRV:3-5 | Stale comments say money is "closed in Release / TEST-only". |
| CLB-r11-nat-settlement-01 | P2 | **new** | App/WithdrawalSupportContactView.swift:35 CYHeroHeader + clear row; :40,48 CYPillButton; :44 CYStatusChip; :49 `cyGroupedSurface` | The 联系平台客服提现 page is custom. |
| CLB-r11-nat-group-code-04 | P2 | **new** | App/DesignSystem/CYClubGameCodeCard.swift (0 references) | Dead hex-ink card. |

## Page scores

| page | r10 code | r11 code | Δ | r11 release | native grade | CY* calls (UI, on page path) |
|---|---|---|---|---|---|---|
| notify | 20/21 | 20/21 | 0 (notify-05 +1, retry regressed −1) | **20** (was ≈18) | native | 0 |
| settlement | 15/15 | 15/15 | 0 | **14** (FE settle dead) | partly (withdraw-support page) | 4 (WithdrawalSupportContactView) |
| customer-detail | 19/20 | 19/20 | 0 | **19** (was 18; save dispatches) | partly (sheet editor, CYAvatarView) | 1 |
| checkin-detail | 16/16 | 16/16 | 0 | **15** (refund dead) | native | 0 |
| join-requests | 17/17 | 17/17 | 0 | **17** (now traced, 03d5694d0) | native | 0 |
| group-code | 11/13 | 12/13 | +1 (05 and 06 +2; activity-only auto-issue −1) | **12** (was ≈3) | native | 0 |
| customers | 15/15 | 15/15 | 0 | 15 | native | 0 |
| payout-receiver | 12/14 | 13/14 | +1 (r9-payout-receiver-02) | **13** (bind dead; unbind dispatches) | native | 0 |
| **slice** | **125/141** | **127/141** | **+2** | **125/141** (r10 ≈114) | 6 native · 2 partly · 0 custom | 5 |

Native grade: `cySheet` / `cyDomainSheet` count as system sheet wrappers (DesignSystem/CYSheetModal.swift). `ClubMPEmptyState` wraps `ContentUnavailableView` with MP art. `CYHaptics`, `CYKitCopy` and `CYOptionalAccessibilityIdentifier` are not UI.

## Fix queue

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| CLB-r11-checkin-detail-01 | P0 | checkin-detail/index.js:143-200; wxml:77-88 | App/NativeRuntimeDependencies.swift:57; RPWL:1448-1462; Core/ClubOwnerRefundApprovedAccess.swift:13 | **Owner: Cursor Core.** Add `MPFirstClubApprovals.ownerRefund(_ context:) -> ClubOwnerRefundApproval?`. It returns nil unless `context.market == .china` and `ReleaseMoneyWriteSwitch.isEnabled(.refund)`. Endpoints are exactly `api/registration/cancel-by-owner`, `api/club/access/me` and `api/club/crm/checkin/detail`. Pass `ownerRefundApproval: MPFirstClubApprovals.ownerRefund(context)` in the `NativeRuntimeDependencies(...)` call at RPWL:1448. Confirm the RuntimeDependencyTransport request passes the composition firewall: cancel-by-owner is `.refund` kind, so add it to a grant if it does not. Add a test that `clubOwnerRefundCoordinator.canDispatch` is true in a Release China composition. | M |
| CLB-payout-receiver-01 | P0 (blocked: owner + backend) | payout-receiver/index.js:95-121 | PRB:15-17; PRV:121-133,176-188; RPWL:10-13; App/AppSession.swift:3413 | **Owner decision first.** Register the iOS app on WeChat Open Platform and bind its appid to the mchid for profit sharing. **Backend:** a bind variant that accepts an app OAuth code (`sns/oauth2/access_token`) or unionid. **Core:** add `api/club/personal-receiver/bind` to `OwnerDecisionGuardLease.paths`, and set `weChatSDKConfiguration`. **App:** set `PayoutReceiverBridge.weChatCode` to a `SendAuthReq`-backed closure. **Interim (S):** under the `payoutReceiver.bind.mpOnly` label add a 去小程序绑定 row that shows the MP path `pages/club/payout-receiver/index?clubId=N` to copy. | L |
| CLB-r11-notify-01 | P1 | notify/index.wxml:107-110 (只重试失败项), js retryFailed | CF:375-398 | In the receipt Section after `ClubOpsNotifyCampaignRows`, add a 只重试失败项 control when `(try? ClubOpsNotifyCampaign(value: refreshedCampaign ?? receipt))?.canRetryFailed == true`. Use `NavigationLink { ClubGovernanceCommandForm(route: .init(operation: .retryNotification, scope: .init(clubID: route.scope.clubID, activityID: route.scope.activityID, campaignID: notifyCampaignID)), identity: identity, access: access, coordinator: coordinator) } label: { Text("club.gov.action.retryNotification") }`, the same as GV:1933 `edit(.retryNotification)`. This regressed in e93c5b952. | S |
| CLB-r11-group-code-01 | P1 | group-code/index.js:44-62, 93-105 | Core/ClubGovernanceCommands.swift:73; Core/ClubGovernanceContracts.swift:169,183; MPRPS:354-356; App/PlayExperienceView.swift:1870 | **Owner: Cursor Core.** When `scope.topicID == nil`, `issueGroupCode` must not need `topicOverview`. Either give it the reviewRead `.access` (`api/club/access/me` with optional activityId, already in governancePaths/readShapes), or skip the topic read and validate only the receipt by activityId (CF:921-928 already does this). Keep `topicOverview` when topicId is present (session label, GV:1333). Add a test: an activityId-only link issues in Release China. | M |
| CLB-r11-settlement-01 | P1 | components/cy/fe-reference-settlement/index.js:57-75; wxml:23-24 | App/ClubFEReferenceSettlementHost.swift:7-13,47,64; CRC:619-622 | Replace `static let allowsSettle = false` with `static var allowsSettle: Bool { ReleaseMoneyWriteSwitch.payoutEnabled }`, keeping the TEST override. Add `"/api/fe/reference-settlement/settle"` (POST, exact body `{ids:[Int], voucherNo?:String}`) to the reviewed grant next to CRC:619-622 and to the composition firewall. The button already exists in `ClubGapFEReferenceSettlementSection` (ClubGapReferenceSettlementView.swift:55-60). | M |
| CLB-customer-detail-04 | P1 (partly) | customer-detail/index.wxml:83-118 | GV:805-809; App/ClubOpsCustomerViews.swift:478-510 | Render the tags/remark editor as a Section on the customer page, with 保存 (`clubR3b.customer.save`) and 取消 as Section buttons calling the saveCustomer submit, instead of `.cySheet(item: $editor)`. Blocked on the governance journal-lock release (club-c receipt, Core/ClubGovernanceCoordinator.swift:171-221). | M |
| CLB-r11-nat-settlement-01 | P2 | settlement/index.wxml:43-46 → utils/withdraw-cs popup | App/WithdrawalSupportContactView.swift:35-63 | CYHeroHeader + clear row → plain `Section { Text(...) } header:` with the explanation as footer. CYPillButton 复制微信号 → `Button { … } label: { Label(…, systemImage: "doc.on.doc") }`. CYStatusChip → `Label(…, systemImage: "exclamationmark.bubble").foregroundStyle(.orange)`. Retry pill → `Button("wallet.retry")`. Drop `.cyGroupedSurface()`. | S |
| CLB-r11-settlement-02 | P2 | — | PRB:7,11-12,15-16; App/ClubFEReferenceSettlementHost.swift:3-6,18; PRV:3-5 | Update comments: money (payout/refund) is on in Release when a host is installed (owner 11-25). Bind is blocked only by the missing WeChat app code. | S |
| CLB-r11-nat-group-code-04 | P2 | — | App/DesignSystem/CYClubGameCodeCard.swift | Delete the unused file (hex CYNight card). | S |

## Regressions

- **CLB-r11-notify-01** (notify 只重试失败项), commit **e93c5b952** ("CLB-notify-05 inline 刷新 … no pushed status page"). It removed the composer's link to `ClubGovernanceReadView(.notificationStatus)`, which was the only host of `edit(.retryNotification)`. The composer shows the failed count but offers no retry.

## New rows found

- **CLB-r11-checkin-detail-01 (P0):** owner refund approval never composed. MP 清退并退款 is dead in Release.
- **CLB-r11-group-code-01 (P1):** activityId-only group-code links fail at the topicOverview review read before the issue.
- **CLB-r11-settlement-01 (P1):** FE 标记已结清 is hard-off (`allowsSettle` constant false) and has no route grant.
- **CLB-r11-notify-01 (P1, regression):** retry-failed is unreachable from the notify composer.
- **CLB-r11-nat-settlement-01 (P2):** the withdraw-support page uses CY hero/pill/chip and a grouped surface.
- **CLB-r11-settlement-02 (P2):** stale "money closed in Release" comments.
- **CLB-r11-nat-group-code-04 (P2):** dead CYClubGameCodeCard.
- **Re-scored (was "money, not a gap"):** CLB-payout-receiver-01 → P0 open (bind dead in Release). Unbind and withdraw are present.
