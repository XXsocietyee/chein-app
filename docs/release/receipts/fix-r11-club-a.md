# fix-r11 club-a receipt (2026-11-26)

Lane `fix/r11-club-a`, based on `origin/ui/combined-r7` @ `b9a9d4d29`. Slice: every P0 and P1 row of the
`origin/audit/parity-r11-club:docs/audit/parity-r11/club.md` fix queue (§3, rows 1-11). No merchant-only rows
were in this slice.

There is no Swift compiler in the cloud. Every type and member was grepped before use. Gates at the last push:
`check_scaffold.py` PASS structural, `check_a11y_lint.py` PASS (0 new), `contract_ratchet.py --check` new 0.
The Swift unit tests below were added but have **not been run**. The first Xcode build/test on the coordinator
machine should run `ClubGovernanceProductionTests`, `ClubGroupCodeActivityOnlyTests`, `G2OpsGapTests`,
`MPFirstClubWriteRouteR10Tests` and `ReviewedChinaLaunchCompositionTests`.

| # | Row | Sev | Status | SHA | App / Core file:line | Notes |
|---|---|---|---|---|---|---|
| 1 | CLB-r11-money-01 | P0 | fixed | ea0dfa3a8, 8536ca6dc | Core/ClubGovernanceProduction.swift:32, 44, 47 (`clubMoney`, `moneyOpen`); App/MPFirstClubApprovals.swift:120, 156 (firewall gate), readShapes for cancel / end / occurrence status | cancelOccurrence and endTopic are in the MP-first live set. They dispatch only while `ReleaseMoneyWriteSwitch` `.hostCancelRefund` is on, checked in `permits` and again in the firewall, with exact MP bodies (MP event-ops/index.js:1106-1115, topic-detail/index.js:1145-1148). The pinned assertions were flipped, and a Release China composition check covers `permits == true`. `test_club_customer_permissions` span hash re-pinned. |
| 2 | CLB-r11-checkin-detail-01 | P0 | fixed | ac982560e | App/MPFirstClubApprovals.swift:22 (`ownerRefund`), :178 (`acceptsOwnerRefund`); App/ReviewedPlayerWriteLeases.swift:1453 | `ClubOwnerRefundApproval` is built for China while `.refund` is on and passed as `ownerRefundApproval`. The firewall admits only `cancel-by-owner` with the multipart `{id}` form, plus the `crm/checkin/detail` evidence read. A composition test checks that the approval matches in Release China and is nil with money off. |
| 3 | CLB-payout-receiver-01 | P0 | **blocked (owner + backend)**; interim fixed | 4fcc50bcd, a6a19ebdf | App/ClubPayoutReceiverView.swift:139 | Bind still needs the WeChat Open Platform app registration, a backend bind that accepts an app code, `OwnerDecisionGuardLease` and `weChatCode`. Interim: under `payoutReceiver.bind.mpOnly`, 去小程序绑定 copies `pages/club/payout-receiver/index?clubId=N` (via `LocalPasteboard`, 10 min). |
| 4 | CLB-r11-notify-01 | P1 | fixed | 5f4b1a316 | App/ClubGovernanceCommandForm.swift:585 (`notifyRetryLink`) | 只重试失败项 is back under the receipt card when the sent or refreshed campaign `canRetryFailed`. It pushes the retryNotification form for that campaign (MP notify/index.wxml:107-110). |
| 5 | CLB-r11-topic-detail-01 | P1 | fixed | 6976316a4 | Core/ClubGovernanceCommands.swift:114; Core/ClubGovernanceFormDraft.swift (endTopic anchor); App/ClubGovernanceCommandForm.swift:932; App/ClubGovernanceViews.swift (seed) | The end body sends `cancellationEpoch` from the topic-setting read, as a decimal string like the MP (utils/topic-cancellation-intent.js:2-8). The reply goes through `ClubTopicEndSummary`: failed sessions show 「N 场没能取消：…」, PENDING shows 原结束请求仍在处理中, and both keep the form open. DONE shows `endResultText`. |
| 6 | CLB-r11-settlement-01 | P1 | fixed | 52b69e78e | App/ClubFEReferenceSettlementHost.swift:11; Core/MPGap/Club/ClubGapReferenceSettlement.swift:42; Core/ChinaReviewedRouteCapability.swift:190 | `allowsSettle` and `FEReferenceSettlementMoneyWrite.enabled` follow `.payout`; TEST keeps `testOverride`. The route capability admits `/api/fe/reference-settlement/settle` under the payout kind. The settle lease uses the raw transport, so this route has no composition-firewall branch; the capability check is the gate. |
| 7 | CLB-r11-group-code-01 | P1 | fixed | d88bcbd44 | Core/ClubGovernanceValidation.swift:170 (`skipsReviewRead`); Core/ClubGovernanceCoordinator.swift (prepare/confirm); Core/ClubGovernanceService.swift (sendReviewed) | With no topicId, issueGroupCode has no review read. The `.access` read also needs a clubId, which the MP link lacks, so the alternative fix was used. The receipt is still checked by activityId. Test: Tests/CoreTests/ClubGroupCodeActivityOnlyTests.swift. |
| 8 | CLB-r11-detail-04 | P1 | fixed | c89512650 | App/MPFirstClubApprovals.swift:206 (`acceptsClubScan`) | No branch admitted these paths, so verifying alone was not enough. Exact bodies: redeem / scan_dynamic_code / coupon verification `{code}`, scan_qr_code `{type: activity/topic, code}`. Composition test: `testShippedChinaAdmitsClubScanVerifyAndCoopPoolApply`. |
| 9 | CLB-r11-detail-05 | P1 | fixed | c08c590af | App/MPFirstClubApprovals.swift:118 + readShapes `api/coop/pool/apply` | Admits the exact `{topicId, clubId, message ≤ 500}` body. Same composition test. |
| 10 | CLB-topic-detail-06 | P1 | fixed | ac0f684bf | App/ClubTopicSettingsInlineToggles.swift; App/ClubGovernanceViews.swift:1984 | Three inline `Toggle`s (开放商家承接 / 置顶在俱乐部主页 / 只对成员可见, MP wxml:503-530). Each change sends all three through the reviewed command, is disabled while saving, and rolls back with the server sentence in the footer. |
| 11 | CLB-customer-detail-04 | P1 | fixed | ae76200be | App/ClubCustomerInlineEditor.swift; App/ClubGovernanceViews.swift:1920 | Inline in the 标签与备注 Section: 编辑 → editor rows → 保存 / 取消, with no sheet. An unknown outcome stays journal-locked (`ClubGovernanceCoordinator.isLocked`), so 保存 is disabled. Pinned span contracts updated (`test_club_ops_customer`, `test_club_leaderboard_member_navigation`). |

New strings (zh-Hans + en): `payoutReceiver.bind.copyMPPath`, `payoutReceiver.bind.mpPathCopied`,
`club.topicSetting.{coopOpen,pinned,memberOnly,saveFailed}`, `clubR11.customer.cancelEdit`.
New files: App/ClubTopicSettingsInlineToggles.swift, App/ClubCustomerInlineEditor.swift,
Tests/CoreTests/ClubGroupCodeActivityOnlyTests.swift (project regenerated).
