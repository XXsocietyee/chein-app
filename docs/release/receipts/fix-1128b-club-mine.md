# Receipt: fix/1128b-club-mine (second wave, club + mine)

Branch `fix/1128b-club-mine` from `origin/ui/combined-r7`. Source: `origin/audit/1128-plan:docs/audits/1128-plan.md` gaps #10, #11, #12, #13, #14, #18, #29 and #30.

This is static work. There is no Swift toolchain in the cloud, so the new XCTest files were written but **not run**. These Swift-free gates are green:
- `tools/generate_project.py`
- `tools/check_scaffold.py` (including the AppSession / AppCompositionRoot line ratchet)
- `tools/contract_ratchet.py --check`: 52 failing, baseline 52, 0 new
- `tools/check_design_consistency.py`
- `tools/check_a11y_lint.py`

Merchant stays off. No deploy, no SQL, and `main` was not touched.

## How Release reaches these routes

Club owner reads go through `CompositionHTTPTransport.guardedSend`. When the reviewed deployment has `playerWritesEnabled`, which is true for `RegionalLaunchConfiguration.reviewedDeployment` and for the shipped CN build, they reach `MPFirstClubWriteRoute.accepts`. Before this branch, the paths below were missing from that firewall or were refused by its substring guards.

## Gaps

| # | Gap | Fix | Files | Test |
|---|---|---|---|---|
| 12 | Club settlement page errored before the R10 button (C-05) | Already fixed upstream by P1-12: `settlementSummaryPath` is the one settlement path exempt from the `"settlement"` guard. This branch verifies it and pins that `settlement/withdraw`, `settlement/mine` and `settlement/apply` stay refused | — (verified) `App/MPFirstClubApprovals.swift` | `Fix1128bClubReadRouteTests.testSettlementSummaryOnlyPasses` |
| 13 | Director console hidden for every owner (C-08) | Admits `crm/topic-manage-stats` (`{clubId, topicId, activityId: null\|positive}`), `recruit/overview` (`{clubId, topicId}`) and `crm/topic-customers` (`{clubId, topicId, filter: String}`). `topic-setting/detail\|save\|end` were already admitted. On topic detail, a failed stats read now shows a **retry row** (`ClubTopicStatsRetryRow`, "场次管理台加载失败" + 重试) instead of silently hiding the console. A role refusal (`forbidden`), sign-out and cancellation still hide it quietly, as the MP's `applyVerifyVisibility` does | `App/MPFirstClubApprovals.swift`, `App/ClubGovernanceViews.swift`, `App/ClubTopicStatsRetry.swift` (new), `Resources/Localizable.xcstrings` (`club.topic.stats.failed`) | `testDirectorConsoleReadsPass`, `testTopicStatsFailureIsRetryableExceptForRoleRefusal` |
| 14 | Club roster and 查看答案 refused (C-19, C-09) | `acceptsTopicRegistrations` matches `api/club/topic-registrations` exactly (JSON `{clubId, topicId}`, two positive ids) **before** the `"registration"` guard. No other registration path passes. `api/club/topic-node-answer` (`{clubId, topicId, nodeId}`) was added to `governancePaths` | `App/MPFirstClubApprovals.swift` | `testRosterAndNodeAnswerPass` |
| 18 | Event-ops series and occurrences never loaded (C-07a) | Added `event-ops/series/occurrences` (`{clubId, seriesId}`). `series/list` (from P1-12), `series/detail`, `series/create`, `series/update-future`, `roster`, `occurrence/status` and `attendance/correct` were already admitted; the test now pins all of them | `App/MPFirstClubApprovals.swift` | `testEventOpsSeriesPaths` |
| 30 | Merchant sections leaked into the club manage tab (C-01b, C-15) | 可对接商家 (`ClubMerchantDiscoveryView` + its profile host) and 收到的邀约 (`ClubInvitationFeedbackEntry`) are now wrapped in `PlayerLaunch.merchantCenterEnabled`. With merchant off, the owner stage no longer offers 邀请商家, 查看邀请进度 or 合作邀约: a published topic goes to 开一场. The `.merchants` / `.sentInvitations` lead destinations return nil. 带队进度 stays | `App/ClubDetailView.swift`, `App/ClubLeadPrimaryActionView.swift`, `Core/ClubOwnerStageCopy.swift` (`ClubOwnerStageInput.merchantEnabled`, default `PlayerLaunch.merchantCenterEnabled`) | `Tests/CoreTests/ClubOwnerStageMerchantGateTests.swift` |
| 10 | Profile follow and 私信 always failed (M-17c/d) | See the #10 details below the table | see below | `Tests/AppUnitTests/Fix1128bMineCompositionTests.swift` (`testReleaseIssuesExactFollowAndChatApprovals`, `testCompositionFirewallAdmitsTheMemberActionRequests`, `testReleaseDeploymentMatchesTheReviewedDeployment`) |
| 11 | 提现 popup showed "未配置" (O-08; R10) | `AppSession.withdrawalSupportReader` now uses `makeBundledWithdrawalSupportReader()`. Its source is the bundled contact: Info.plist `QuestifyWithdrawSupportWeChatID` ← `QUESTIFY_WITHDRAW_SUPPORT_WECHAT_ID` in `Config/OwnerValues.xcconfig`, set to the MP constant from `utils/withdraw-cs.js:8`. It is approved only on a reviewed deployment, so fixtures and UI tests keep "未配置". **No withdraw request and no contact request are ever sent.** The profile-earnings 提现 entry now gets the same reader instead of `nil`. A signed-out reader shows "登录后查看客服微信" instead of "未配置" | `App/WithdrawalSupportBundledSource.swift` (new), `App/AppSession.swift` (1 line, line-neutral), `App/WithdrawalSupportContactView.swift`, `App/SessionWalletCommerceView.swift`, `Config/Info.plist`, `Config/OwnerValues.xcconfig`, `docs/release/owner-values.md`, xcstrings `withdrawal.support.signedOut` | `testBundledSupportContactReadsWithoutAnyRequest` |
| 29 | 我的邀请 list never loaded (O-14b) | `ReviewedProductionGateLeases.profileInviteHistory(_:)` issues one stable `ProfileInviteHistoryReadAccess` per signed-in China context, for `api/user/invite_list` + `api/user/points/list`. When `productionGatesEnabled`, the composition falls back to it, the same way as `messagingHistory` (line-neutral in `AppCompositionRoot.swift`) | `App/ReviewedPlayerWriteLeases.swift`, `App/AppCompositionRoot.swift` | `testInviteHistoryReadIsIssuedInRelease` |

### #10 details

- **Issuer.** `SocialMemberActionReleaseIssuer` (Core) issues one exact approval per signed-in context, member and operation. Each approval lasts 10 minutes. It covers either `follow/action` + `public-info`, or `im/start` + `public-info` + `im/conversations`. It is never issued for oneself, for member id ≤ 0, or outside the CN market.
- **Wiring.** `SocialMemberActionAccess` asks the issuer only when no configured approval matches, and fences each issued approval like a configured one. `SocialMemberActionSessionOwner` gained an `issue:` parameter. `AppSession` passes `issueSocialMemberApproval` (`App/AppSessionSocialMemberIssuer.swift`), which is gated on reviewed + productionGates + playerWrites + CN. The `AppSession` change is line-neutral.
- **Firewall.** `ReviewedProductionFormMutationRoute` admits the canonical `follow/action` form (`follow_member_id` > 0, `follow` ∈ {"0","1"}) and the `public-info` form (`member_id` > 0). `im/start` and `im/conversations` were already admitted.
- **UI.** A server-confirmed 关注 means the receipt matches and the profile re-read shows the new relation. After that, `SocialProfileInlineFollowButton.onConfirmed` bumps `relationRevision` in `SocialPublicProfileView`'s read key, so the friends / following / followers counts are read again. Failure keeps the inline "social.follow.failed". Signed-out viewers keep the disabled button.
- **Files.**
  - `Core/SocialMemberActionFactory.swift`
  - `Core/SocialMemberActionSessionOwner.swift`
  - `App/AppSessionSocialMemberIssuer.swift` (new)
  - `App/AppSession.swift`
  - `App/ReviewedProductionRoutes.swift`
  - `App/SocialPublicProfileView.swift`
  - `Tests/ContractChecks/test_profile_self_edit_return.py`: its read-key pin was updated, with a comment citing gap #10.

## Contract tests changed

- `Tests/ContractChecks/test_profile_self_edit_return.py`: the profile read key now ends with `-\(relationRevision)`. This is deliberate, for gap #10, and the reason is in a comment in the test.

## Owner actions

1. Confirm the 提现 support WeChat id in `Config/OwnerValues.xcconfig` (`QUESTIFY_WITHDRAW_SUPPORT_WECHAT_ID`). It currently mirrors the MP constant.
2. Run the new XCTests on a Mac:
   - `Fix1128bClubReadRouteTests`
   - `Fix1128bMineCompositionTests`
   - `ClubOwnerStageMerchantGateTests`
3. Run a device check: as a CN signed-in player, open another member's profile and tap 关注 → the counts update → tap 发消息 → the chat opens. Then, as a club owner, open a topic detail with a session (director console), 报名名册, 查看答案, and the series date list.
4. Backend: no change needed. Fields per hengyin `us/r3-functional`:
   - ApiUmsMemberController.java:910 `follow/action`
   - ApiClubCrmController.java:122/138
   - ApiClubRecruitController.java:24
   - ApiClubController.java:1847/1889
   - ApiClubEventOpsController.java:108

## Not done / notes

- The club firewall assumes that no earlier `guardedSend` branch intercepts these paths. This was checked by reading the code, not by a run.
- `ClubCoopPoolMount` (可对接的活动, 申请带队) is still shown. It is a club lead intent that an earlier owner-approved lane shipped, not one of the merchant sections named in gap #30.
