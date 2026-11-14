# ui/cur-wp-10

HANDOVER 39, WP-10 owner-decision guards. Parent `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46` (`origin/ui/main`). Proposals taken from `docs/release/completeness-next.md` WP-10 and the matching PROPOSED rows in `docs/owner-handover/SUPPLEMENT.md` at `7ca515e19` on `docs/completeness-3`. That commit is not the base. WP-11 (D-07) and CL-02 (D-09) are not in this branch.

`docs/release/completeness-matrix.csv` is not on `ui/main`. Row status is listed here. The matrix was not imported.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged. `ReviewedAreaSwitch` is not redeclared. Payout and merchant writes still go through `ReviewedAreaSwitch` and stay closed on `www.chengyinhub.com`. `wiredPatternCount` stays 677.

`swiftc` is not on this machine, so `swiftc -parse` did not run. No simulator screenshots.

## Rows

| Row | Status |
|---|---|
| OWN-D-01.a | done |
| OWN-D-01.b | done |
| OWN-D-01.c | done |
| OWN-OPT-010 | done |
| OWN-D-02 | done |
| OWN-D-03.a | done |
| OWN-D-03.b | done |
| OWN-D-04 | done |
| OWN-D-05.a | done |
| OWN-D-05.b | done |
| OWN-D-05.c | done |
| OWN-D-06 | done |
| OWN-D-08.a | done |
| OWN-D-08.b | done |
| OWN-D-08.c | done |
| OWN-D-10 | done |

Rows still missing: none.

## What landed

- OWN-D-01.a: points rules keep earn rows and list eventType 14 as 「积分消耗」. `delFlag` other than 0 is dropped. Missing `delFlag` stays listed.
- OWN-D-01.b: a quote with `pointsDeductYuan == 0` turns the points toggle off. Balance 0 says 「暂无可用积分」. A ticket that refuses points says 「该票不支持积分抵扣」. The notice stays on the sheet after the quote is idled. No second quote is sent.
- OWN-D-01.c: order detail shows the snapshot `pointUsed`. No client rate literal in App/Core outside the existing server-port files `MoneyParityRules.swift` and `RegistrationCheckoutPresentation.swift`.
- OWN-OPT-010: closed by D-01.a–c. `OwnerDecisionGuardTests` cites `OWN-OPT-010`.
- OWN-D-02: no `api/club/membership` call site in App/Core outside `UnifiedOPT*` and `Legacy52*` contract records, and no dues screen.
- OWN-D-03.a: `OwnerDecisionContentChain` maps community surfaces to `/api/v1/community` and creative-square surfaces to `/api/creativesquare`. Square delete stays owned by WP-04 (`SquareDeletionFlow` still uses `api/v1/community/posts/{id}`).
- OWN-D-03.b: no type flips a surface between chains.
- OWN-D-04: ending text is only `api/play/ending` and `api/play/journey/ending`, in server order.
- OWN-D-05.a: club receiver reads `GET /api/club/personal-receiver/status` and can confirm unbind. Bind shows 「请在小程序完成绑定」 and the copyable path `pages/club/payout-receiver/index`. `bind()` returns `.notSent` and does not call the transport. There is no bind button.
- OWN-D-05.b: merchant payout account is read-only behind `merchant:finance:read` (alias `FINANCE_READ`). `POST /api/merchant/payout-account` has an empty body. https signing links can be copied. No edit and no withdraw.
- OWN-D-05.c: unbind and `payout-account/save` send nothing while `ReleaseMoneyWriteSwitch.payoutEnabled` is false. The same client sends nothing to `www.chengyinhub.com` even if a test derivation forces the switch on. Bind is not in the grant.
- OWN-D-06: no dues product. `MPCommerceGate` purchases, claims, and payout stay false. No WeChat Pay for digital goods.
- OWN-D-08.a: a failed or unavailable quota read shows unavailable and does not generate. An idle flow that has not read quota yet can still generate, matching the existing draft tests.
- OWN-D-08.b: `ai_simple` stories keep 「AI 生成」. A draft with `aiTraceId` appends `  [AI 辅助生成]`. An adopted author name drops those marks.
- OWN-D-08.c: no long-term NPC memory, paid memory slot, or AI feature on by default. Scene AI stays `defaultEnabled: false`.
- OWN-D-10: empty or non-participant revenue hides the tab. A failed read is 「收益暂不可用」, not 0. `G6RevenueAllocations.state` already does this; `WalletAuthorRevenueTab` uses the same gate.

Unknown money and unknown account fields render as an em dash (`U+2014`).

## Grants

Both `ChinaReviewedRouteCapability.ownerDecisionGuardGrant` and `OwnerDecisionGuardLease`:

- `api/club/personal-receiver/status` (GET)
- `api/club/personal-receiver/unbind` (listed, still blocked while payout is off)
- `api/merchant/payout-account` (POST, empty body, read)
- `api/merchant/payout-account/save` (listed, still blocked while payout is off)

`api/club/personal-receiver/bind` is not granted. Unbind, bind, and save are `ReleaseMoneyWriteSwitch` payout kinds, so `admitsChinaProductionCall` refuses them while `payoutEnabled` is false.

## Screens

Club settlement links to the receiver when `clubID > 0`. Merchant home links to the account when finance read is granted. Both screens have loading, empty, and error. Copy is Chinese and English through `ChannelCopy`.

`--owner-decision-fixture=` modes: `receiver-loading`, `receiver-empty`, `receiver-error`, `receiver`, `merchant-loading`, `merchant-empty`, `merchant-error`, `merchant-denied`, `merchant`.

## Checks

`python3 tools/build_page_route_table.py` wrote the two page paths into `Core/MiniProgramPages.swift`. `python3 tools/generate_project.py` completed. `python3 tools/check_scaffold.py` passed. `python3 tools/check_design_lint.py` passed. `swiftc` was not run.
