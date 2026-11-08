# UIV-04 report: merchant console (light). NOT COMPILED

Branch cloud/uiv-04 from origin/ui/own-1. Mini-program truth: pages/merchant/index/index; screenshot chengyin/docs/evidence/player-e2e-20260927/001-home-player.png (merchant home). merchant-deep-20260928 holds club shots only (no merchant screens).

## Screens
| iOS file | mini page | notes |
|---|---|---|
| App/HomeSearchTabParityViews.swift `SessionMerchantRootContainerView` | merchant tabs | already `.roleTheme(.merchant)` + `.cyDomainTabBar(.merchant)`; no change |
| App/MerchantHomeView.swift (workbench) | pages/merchant/index | changed, see below |
| App/CouponManagementView.swift | subpackageMember/coupon | text styles + `.secondary` only, no raw colours; not changed |
| App/MerchantCustomerListParityViews.swift | pages/merchant/customer | raw `Color.orange/.secondary` -> `CYColor.warningText/textSecondary` |
| App/MerchantLedgerSettlementOverview.swift | pages/merchant/ledger | clean, not changed |

## Diffs fixed (MerchantHomeView)
- Hero: label above a centred Data 2XL tabular amount (CYTypography.data2XL, CYColor), store name as header; unknown revenue already an em dash via `MerchantMoney.display`.
- Quick actions: 56pt (scaled) white circles with hairline border and caption labels like the source; added the missing 4th action 更多 (scrolls to the existing "more" group; no new capability).
- List sits on `CYColor.bgPage` with hidden default list background, 24pt section gap.
- Loading uses `CYSkeleton` instead of a bare spinner.
- Identifiers unchanged; new id `merchant.workbench.more.action` added.

## Diffs left
- Greeting ("Hi, name") and 营业中 status chip: no localisation key or open-status field. UIV-TODO in code. ui-strings-uiv-04.json is empty (no new strings).
- Project cards (cover, 进行中 chip, bell, "今日无待办"): the iOS home shows a records list (orders/projects) instead; card layout needs project data not present in the workbench view. Left as list rows.
- Coupons / customers / finance pages not restructured; no Dynamic Type / empty state issues found by reading.

## Compile risks
- `ScrollViewReader` wraps the `List` (closing brace added before `navigationDestination` chain end); verify braces/modifier order in MerchantHomeView.
- `MerchantQuickCircleAction` is private in MerchantHomeView.swift; `CYSkeleton`, `CYTypography.data2XL`, `CYColor.bgPage/bgSurface/borderSubtle/warningText` verified by grep.
