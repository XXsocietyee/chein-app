# ui/cur-wp-09

HANDOVER 38, WP-09. Parent `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46` (`origin/ui/main`). The WP-09 section was read from `e1969026e9469669e165937013e0e4f5c61b4252` (`docs/completeness-2`). That commit is not the base.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. New Swift is picked up by `python3 tools/generate_project.py`. `docs/release/contract-failing-baseline.txt` is unchanged. `ReviewedAreaSwitch` is not redeclared. Money writes go through `ReviewedAreaSwitch.moneyPayments` and stay closed on `www.chengyinhub.com`.

`docs/release/completeness-matrix.csv` is not on `ui/main`. It was not imported. Row ids and status are listed below.

Swift was not compiled. `swiftc` is not on this machine, so `swiftc -parse` did not run. Screenshots were not taken.

## Screens

- `App/GameplayPresetSection.swift` on the template tab (`App/DiscoveryTemplateBrowserView.swift`). List, empty, loading, error with retry, and the draft form stay visible. Creating a draft needs `canDraft`. A staff browse-only tab still shows the section; the create control stays visible and does not send.
- `App/WP09AfterSaleSections.swift`: source lineage on the template-use row, role and shared facts on the team page, delivery / payment-return / partial refund on the order page, creator accrual on the wallet, and the paid-install authority notice.
- Unknown copy is an em dash (`U+2014`). Chinese and English come from `W8Text` / `WP09Copy`.

## Client calls

`Core/GameplayPresetClient.swift` calls:

- `GET /api/preset/gameplay/list`
- `GET /api/preset/gameplay/info?presetKey=`
- `POST /api/preset/gameplay/draft` with `{requestId, presetKey, inputs}`

`requestId` is 8–64 characters in `[A-Za-z0-9._:-]` and is reused. `APPLIED` and `REPLAYED` open the same editable draft. `REPLAYED` says the draft is still the original one. `PENDING` and an unknown receipt stay closed and the outcome is an em dash. A non-200 `msg` is shown as the server sent it. Money keys (`payChannel`, `payAmount`, `price`, `amount`, `payableAmount`, `refundAmount`) are refused before the transport.

`/api/topic/v2/create` and `/api/template/adopt-draft` were already done. They were not reimplemented. No diff, upgrade, or marketing-revenue route was added.

## Grants

Both lists name the three preset paths. They are not added to `marks` or `wiredPatterns` (`wiredPatternCount` stays 677, `callSiteCount` stays 997).

- `ReviewedProductionGateLeases.playPaths`: `api/preset/gameplay/list`, `api/preset/gameplay/info`, `api/preset/gameplay/draft`
- `ChinaReviewedRouteCapability.wp09PresetGrant`: the same three paths with a leading slash, checked in `admitsChinaProductionCall`

`POST` list and info are refused. The draft body must pass `GameplayPresetDraftBody.allows`. `ReleaseMoneyWriteSwitch` and `forcedOff` still run before the grant. `WorkshopPaidInstallAuthority.confirmSends` calls `ReviewedAreaSwitch.moneyPayments(apiHost:)`. A nil host and `www.chengyinhub.com` stay closed.

## Rows

| id | status |
|---|---|
| OWN-21.1 | done — draft client, editable draft, `testOWN_21_1_presetDraftOpensEditableDraftOnTEST` |
| OWN-21.2 | done — list and info, `testOWN_21_2_presetListAndInfo` |
| OWN-U02-04 | done — source identity and continue-current. Diff and save-as-new have no endpoint, so those rows stay an em dash. `testOWN_U02_04_sourceVersion` |
| OWN-十三-02 | done — the three children above. `testOWN_十三_02_templatePresetRollup` |
| OWN-U06-02 | done — my task, my evidence, waiting-on, my private clues. Another role's `privateClues` is not stored. `testOWN_U06_02_myRoleAndPrivateClues` |
| OWN-U06-04 | done — who must act, chapter release, pause, shared result, population, time window, club headcount and session count on separate lines. No merchant write. `testOWN_U06_04_organizerSharedResults` |
| OWN-U07-01 | done — delivery facts. Mixed null ticket fields say 按票种分别说明. `refundRule` nil has no refund line. `testOWN_U07_01_delivery` |
| OWN-U07-02 | done — querying, received, pending, cancelled, failed, unknown. Only received unlocks. `testOWN_U07_02_paymentReturn` |
| OWN-U07-03 | done — `PAID_INSTALL_AUTHORITY_UNAVAILABLE` stays on screen. Confirm follows `ReviewedAreaSwitch` and stays closed on `www.chengyinhub.com`. `testOWN_U07_03_workshopInstallStaysClosedOnProduction` |
| OWN-U07-04 | done — pending, processing and completed amounts are the server strings. Incomplete totals say 合计未齐. A missing amount is an em dash. `testOWN_U07_04_partialRefundServerAmounts` |
| OWN-U07-05 | done as a projection. The wallet shows 收益暂不可用 because WP-09 does not name the B8 ledger route. No `/api/marketing/revenue/*` call was added. `testOWN_U07_05_creatorAccrual` |
| OWN-十三-03 | done — the seven children above. `testOWN_十三_03_teamAndAfterSaleRollup` |

Rows still missing: none.

## Checks

`python3 tools/generate_project.py` completed. `python3 tools/check_scaffold.py` passed (structural checks, bilingual catalog, appsession ratchet, page route table). `python3 tools/check_design_lint.py` passed (no new violations). `swiftc` was absent, so `swiftc -parse` did not run. Screenshots were not taken.
