# Receipt: cursor/r9-member

Owner: Cursor Core, area member. Parent is `d9115273d70e5b88343b2a14f81d111bf515c561`. This branch was not rebased. `origin/ui/combined-r7` was not pushed.

This VM did not run `swiftc` or `xcodebuild`. Nothing here was parsed or compiled. Swift tests were written and were not executed. `python3 -m unittest tools.tests.test_merge_localization_member` passed. `tools/check_appsession_ratchet.py` passed. `Tests/ContractChecks/test_player_write_grant.py` passed.

`AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No new Swift file.

Money stays off. Pay, gift claim, payout, withdrawal execution, refund execution, paid orders, quote, registration create, and pricing confirm were not built and were not sent. Cancel, confirm, and refund-apply were not changed.

## Rows

| id | status | SHA | file:line |
|---|---|---|---|
| MKT-3-1 | blocked | d9115273d70e5b88343b2a14f81d111bf515c561 | `Core/PlatformPass.swift:232` still throws `unreachable`. `App/MPParityPassSession.swift:689` still sends nothing. Gift claim is on the money list, so this row does not build or send `POST /api/marketing/product/gifts/claim`. |
| PLY-25-2 | fixed | d9115273d70e5b88343b2a14f81d111bf515c561 | Sync and settle keep `sessionId` (`Core/OrientSessionService.swift:153`). Recovery POSTs `kind` (`Core/OrientSessionService.swift:96`). Receipt kinds include SYNC and SETTLE (`App/ReviewedOrientScoreReviewLease.swift:95`). The production lease admits the MP sync/settle body and the recovery body (`App/ReviewedOrientScoreReviewLease.swift:57`, `App/ReviewedOrientScoreReviewLease.swift:72`). Recovery is live (`Core/ChinaReviewedRouteCapability.swift:1507`). `canSync` / `canSettle` (`Core/OrientSessionContracts.swift:158`). `settleEnabled` and `syncEnabled` are true; payment, payout, and withdrawal stay false (`Core/OrientScorePresentation.swift:249`). App mount of `OrientScoreSettlementGapSection` is Claude. |
| R9-MEM-STR-2 | fixed | d9115273d70e5b88343b2a14f81d111bf515c561 | A fragment replaces a different catalog entry (`tools/merge_localization_fragments.py:46`). `--check-member` exits 1 while a member fragment zh-Hans differs (`tools/merge_localization_fragments.py:72`). Live check: 21 keys in `docs/port/strings/fix-r3-member-a.json` and 22 keys in `docs/port/strings/fix-r3-member-b.json`. Those 43 values were not written. That write is R9-MEM-STR-1, Claude App. |
| R8-MEM-26-1 | partly | d9115273d70e5b88343b2a14f81d111bf515c561 | A `subpackageMember/mytemplate/mytemplate` link opens `pages/activity/official-mine/index` and drops the query (`Core/MiniProgramPageLink.swift:287`). The page is no longer a reviewed open page. App route retirement in `App/MPReviewedPageScreen.swift` and `App/TemplateAuthoringMineView.swift` is Claude. |
| MKT-7-3 | partly | d9115273d70e5b88343b2a14f81d111bf515c561 | Unit `validTo` (`Core/FreeExploreLaunchContracts.swift:115`). `refundHold` (`Core/FreeExploreLaunchContracts.swift:136`). `exitCases` (`Core/FreeExploreLaunchContracts.swift:157`). Reservation `canCancel` is `status == BOOKED` and does not send (`Core/FreeExploreLaunchContracts.swift:93`). `shopName` and chapter `content` (`Core/FreeExploreLaunchContracts.swift:187`). App mount is Claude. |
| FIN-19-1 | partly | d9115273d70e5b88343b2a14f81d111bf515c561 | History read POSTs `pageNum` and `pageSize` 10 (`Core/WalletCommerceService.swift:91`). The read route admits that body and still admits the bodyless list (`Core/WalletHistoryReading.swift:78`). `loadMore` concatenates (`Core/WithdrawalHistory.swift:190`). `withdrawals(token:)` stays bodyless (`Core/WalletCommerceService.swift:85`). No withdrawal create, preflight, or transfer. App 加载更多 is Claude. |
| PLY-21-5 | partly | d9115273d70e5b88343b2a14f81d111bf515c561 | `party` (`Core/TicketWalletContracts.swift:200`) and `exploreProgress` when `required > 0` (`Core/TicketWalletContracts.swift:206`). App copy is Claude. |
| R8-MEM-21-2 | partly | d9115273d70e5b88343b2a14f81d111bf515c561 | `TicketWalletTicket.memberID` (`Core/TicketWalletContracts.swift:61`). App owner check is Claude. |
| FIN-20-6 | partly | d9115273d70e5b88343b2a14f81d111bf515c561 | `MemberInviteShareLink.path` is `/pages/index/index?inviter=<userId>` (`Core/ClubShareLink.swift:88`). `httpsURL` is nil while verified origins are empty. No host was invented. App `ShareLink` is Claude. |
| R9-MEM-NIT-2 | fixed | d9115273d70e5b88343b2a14f81d111bf515c561 | Removed the unused raw zh title on `OrientReviewSheetKind` (`Core/MPGap/Member/MemberGapModels.swift:89`). |

## Not taken

Claude App only: R9-MEM-STR-1, FIN-17-4, MKT-9-2, R8-MEM-21-1, PLY-23-4, PLY-23-6, R7-MEM-7-1, R8-MEM-7-3, MKT-8-2, MKT-10-3, R7-MEM-16-1, R7-MEM-24-2, R9-MEM-17-2, R9-MEM-5-1, R9-MEM-3-1, R9-MEM-IOS-1, R9-MEM-NIT-1.

App call sites left for Claude: orient score settlement section, mytemplate screen retirement, free-explore field display, withdrawal history 加载更多, ticket party and explore copy, ticket owner check, invite share button.
