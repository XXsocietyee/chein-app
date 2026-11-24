# cursor/core-club — club Core contracts

Base: `origin/ui/combined-r7` `7fdfad1f177fadb76f7fd54a82b27fa69b82f1f8` (2026-11-24 06:51:52 -0800).
Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `8ece7763e192e13d27a765a0b8664955be6cf4ee`. There is no `chengyinhub-xcx/api/` folder; the calls live in the page JS.
Scope: Core/ and Tests/ only. No App/ screen edits. No `project.pbxproj`, no `tools/current_ci_manifest.json`. No new Swift folder, so `tools/generate_project.py` did not need a new glob (`Core/*.swift` already covers the new files).
No swiftc was run. This receipt does not claim a parse. Money stays display/count only. No new gate, and nothing here defaults on.

## Closed

| Id | What Core now does |
|---|---|
| CLB-r7-C-01 | `POST api/club/governance/ban` sends `durationDays` 7/30/90. Epoch keys are rejected. The form still collects `banDays` and converts it. |
| CLB-r7-A-07 / CLB-r7-C-02 | `canGovernMembers` and `allows("club:member:manage")` require that permission plus `CLUB_OWNER` or `CLUB_CO_OWNER`. Denial string: 仅主理人与联合主理人可进行成员治理. |
| CLB-enroll-04 / CLB-r7-C-05 | `signups` is the registrant count. `paidCount` counts `paymentStatus == 2` only. `POST api/club/topic-registrations`. |
| CLB-detail-16 | Plain members cannot `POST api/club/post/create` when `memberPostAllowed == false`. Nil still means allowed. Owner and administrator still create, including 公告. |
| CLB-detail-29 | `POST api/club/detail` decodes `memberDiscountPrice` / `memberDiscountPriceText` without failing the record. `ClubMemberWelcome.memberPricePerk` is 「成员价 …」. 0 or absent stays nil. |
| CLB-event-ops-06 | Weekly create checks the Shanghai 90-day / 64-occurrence window inside `ClubSeriesScheduleDraft.issue()`. Offer text and `sessionTicketCount > 1` capacity hiding live on `ClubEventOpsFormRules`. Path stays `POST api/club/event-ops/series/create`. |
| CLB-topic-story-05 | Club entry: `POST api/club/topic-node-answer` `{clubId,topicId,nodeId}`. No club id: `POST api/topic/host-node-answer` `{topicId,nodeId,scope}`. `ClubStoryPresentation` accepts a host scope. `Core/MPGap` was not edited. |
| CLB-group-code-06 | `pages/club/group-code/index` parses with `topicId` or `activityId`. A name alone is rejected. Issue still sends `{activityId}` to `api/verify/groupcode/issue`. |
| CLB-detail-30 | `ClubShareLink` builds and parses `/pages/club/detail/index?id=` and `&postId=`. |
| B-26 | `TopicClubShareLink` accepts `id` or `topicId`, requires `sourceClubId`, treats `clubCode` as optional (trim, 1–64; longer rejects the link), and ignores extra keys. `clubCode` would later map to `sourceChannelCode`. No registration write. |
| CLB-customer-detail-05 | `ClubCustomerDetailRefusal.sentence` keeps a non-generic business sentence. 200/401/2/403 and 系统繁忙，请稍后重试 stay generic. `POST api/club/crm/customers/detail`. |
| CLB-notify-04 / CLB-topic-detail-09 / CLB-event-ops-05 / CLB-settlement-10 | `ClubOpsNetworkFailureClassifier` maps `.unknown(nil)` to 网络连接失败 and other failures to the page sentence (通知工具暂时不可用, 入会申请加载失败, 结算数据暂不可用, 活动运营暂时不可用, 系列列表加载失败, 可开场主题加载失败, 活动无法打开, 链接已失效). Existing `titleKey` values are unchanged so current sections keep catalogued titles. The sentence is `literalTitle`. |
| CLB-detail-26 | `ClubOwnerStageMachine` ports the 13-stage copy. Display stage `.executionAccepted`（活动运营）is used when the MP stage key would stay `accepted` and an execution project is held. `ClubLeadPrimaryAction` was not extended. |
| CLB-r7-C-06 | `ClubProfileLocalDraftFlow.clearAfterConfirmedDissolve()` drops the current account's local edit draft after a confirmed `POST api/club/dissolve`. It does not send the dissolve. |
| CLB-workbench-04 | `ClubWorkbenchTiles.pendingVerifyCount` is an integer ≥ 0 only. `sessionsThisWeek` counts non-cancelled sessions in the Shanghai Monday–Sunday week, and returns nil when the snapshot is truncated or the week is not fully inside the snapshot month. |

Strings fragment (not merged into an xcstrings catalog): `docs/port/strings/cursor-core-club.json`.
Tests: `Tests/CoreTests/ClubCoreClubContractTests.swift` (one check per call above), plus the ban, share-link, and production-lock updates those contracts required.

## For the Claude F-agent (App/)

Do not delete `ClubDetailOverviewFactsGrid` until `ClubDetailOverviewFactsGridView` in `App/ClubDetailTabBar.swift` is gone (CLB-detail-42).

- Share: point the club/post share action at `ClubShareLink`. Universal-link registration attribution (CLB-detail-11) is still an owner decision; Core only parses `TopicClubShareLink`.
- Now card (`ClubWorkbenchKit` / `ClubLeadPrimaryActionSection`): read `ClubOwnerStageMachine.resolve` (`label` / `hint`). Do not add cases to `ClubLeadPrimaryAction`.
- Failure sections: prefer `literalTitle` over `titleKey`. For topic overview, when `prefersBack` is true the button is 返回 (pop), not reload. Customer detail: when `backTitle` is set, show `literalTitle` and 返回. Settlement / series / event topics / notify: show `literalTitle` (网络连接失败 vs the service sentence).
- Ban review row (`ClubGovernanceCommandForm`): the body no longer has `expiresAtEpochMs`. Show `durationDays` as 「N 天」. The picker already writes `banDays`.
- Welcome sheet: render `ClubMemberWelcome.memberPricePerk`.
- Composer: pass `memberPostAllowed` into `ClubCommunityEvidence`. Nil stays allowed.
- 临时封禁 / 成员治理: gate on `canGovernMembers`, and use `ClubGovernancePermissions.memberGovernanceDenial` when it is false. Do not treat a bare `club:member:manage` grant as enough.
- After dissolve success: call `clearAfterConfirmedDissolve()`.
- Workbench tiles 待核销 and 本周场次: hide when the helper returns nil.
- Group-code issue: a topic-only link can open the page; issuing still needs an `activityId`.
- Schedule error: `ClubSeriesScheduleDraft.weeklyHorizonMessage(now:)` is the sentence with the real max. `.weeklyHorizon` falls through `ClubSeriesScheduleIssueLabel` to `club.schedule.error.weeklyHorizon` until that key is catalogued.
- Merge `docs/port/strings/cursor-core-club.json` when those keys are shown.

## Skipped

- B-11 club settlement GET vs POST. `CoopFlowRead.clubSettlementSummary` stays the unmounted GET from `cursor/core-wiring-r6`. Production `ClubGovernanceRead.settlement` stays `POST api/club/settlement/summary`. The caller was not flipped.
- `Core/MPGap/Club` and the parked gap/g2-ops mounts (CLB-G01–G19 and the settlement reference screen).
- `restyle/r2-club-social` (visual only).
- CLB-detail-11 registration write (`sourceClubId` / `clubCode` into a signup). Parser only.
- CLB-detail-42 facts-grid deletion. App still references the type.
- CLB-payout-receiver-01 WeChat bind. Owner decision, not a Core change.
- Review A has no club Cursor rows. Review C club rows are Gemini/Claude.
- Role-assignment `expiresAtEpochMs` is not the ban payload and was left alone.
