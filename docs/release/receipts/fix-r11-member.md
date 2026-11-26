# Receipt: fix-r11-member

Lane **member**, branch `fix/r11-member`, base `origin/ui/combined-r7` @ `b9a9d4d29`.
Source: `origin/audit/parity-r11-member:docs/audit/parity-r11/member.md` §4 Fix queue (6 rows, no P0).
No compiler in the cloud: every type/member used was grepped; gates listed below were run before push.

| id | sev | status | SHA | app file:line | note |
|---|---|---|---|---|---|
| R11-MEM-17-1 | P1 | fixed | `c5dd47654` | `App/ExploreCompletionComposition.swift:21` (provider), `App/OwnedOrderComposition.swift:12,60` (env install), `App/ReviewedPlayerWriteLeases.swift:511` (reviewed player read path), `:1326` (lease) | Production-gated `ExploreCompletionReadApproval` (1 h, China) from `ReviewedProductionGateLeases`; one cached `ExploreCompletionSessionReader` per session+lease on the composition transport; `ExploreCompletionProvider` bound to `currentOwnedOrderSession` (now internal, no line growth in AppSession). MP `scene-member-order-detail/index.js:833-835`. |
| R11-MEM-17-2 | P2 | fixed | `39fdd0b6b` | `App/ProfileOrderRecordSection.swift:15`, mounted `App/ProfileOrdersView.swift:580` | 查看记录 → `SessionPlayRuntimeView(.journey(scope))`. Shown only for MP `primaryCta == 'record'` (index.js:187-194): registrationStatus 2, paymentStatus 2, completed, purchaseKind 3, owner id > 0. `ticketHasGame` treats a missing activity projection as having a game, so no extra check. Key `playerJourney.viewRecord`. |
| R11-MEM-17-3 | P2 | fixed | `1ba8006ca` | `App/ExploreCompletionRevisitSection.swift:11`, mounted `App/ExploreCompletionView.swift:193` | 下次再来: club name, 关注主办俱乐部 (`MemberRound2Service.followClubOwner`, followed only on 200), 加入俱乐部 via club page (`ClubActionCoordinator`), 已加入俱乐部 state, next edition → `SessionTopicDetailView`, else 下一期开售后会在这里出现. Replaced the old 回访信息 section; unused keys dropped from `Resources/ExploreCompletionLocalizations.fragment.json` so the pinned key-set test still matches (catalog keeps them). Pending-review text (申请已提交) shows on the club page, not here. |
| NAT-R11-1 | P2 native | fixed | `e3772687f` | `App/MPParityPassSession.swift:467-476` | Dropped `.background(CYNight.ink0…)` from the order-missing fallback. |
| NAT-R11-2 | P2 native | fixed | `a3a42152f` | `App/MPGap/Member/OrientScoreGapViews.swift:22-30,97-105,152` | Both sheets: `NavigationStack` + `navigationTitle` + `.cancellationAction` `action.close`; submit `.borderedProminent`. |
| NIT-R11-1 | nit | fixed | `c17b299e8`, `1834fab9d` | `App/ProfileOrdersView.swift:63-87` | Visible trailing `Menu` (`ellipsis.circle`, 44 pt) with `cardExitButton(order)`; row extracted into `orderListRow` to keep the body small. Key `profile.orderExit.more` = 订单操作 (not 更多操作, which `test_square_detail_page_ready` pins as missing). `test_profile_order_filters` pin updated for the row helper. |
| DEC-1 | owner | not queued | — | `App/PassMarketViews.swift:1206` | Owner decision pending (pass-order cancel/refund in Release). |

Strings: `docs/port/strings/fix-r11-member.json` merged into `Resources/Localizable.xcstrings` (zh-Hans + en).

## Gates (final push)
- `python3 tools/check_scaffold.py`: PASS structural checks (5195 Swift files, 19579 bilingual keys)
- `python3 -B tools/check_a11y_lint.py`: PASS (0 new)
- `python3 tools/check_appsession_ratchet.py`: PASS (AppSession.swift unchanged at 7979 lines)
- `python3 -B tools/contract_ratchet.py --check`: 192 failing, baseline 192, **new 0**
- `Tests/ContractChecks/test_explore_completion_read.py`: OK (14 tests)
- Not run: Xcode build / simulator (no compiler in the cloud).
