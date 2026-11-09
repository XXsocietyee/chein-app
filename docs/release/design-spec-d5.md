# Design spec D5: merchant home / console (light theme)

Theme: merchant = light only (`#F3F4F4` page, white cards, neutral/black CTA). Violet only on the selected tab (not on these screens).
Branch `ui/d5`, base `origin/ui/merge`. The K kit branch (`ui/kit`) does not exist yet, so this uses the components already in
`App/DesignSystem` (CYBalanceHero, CYColor, CYSpacing, CYTypography). No parallel components are added.

## Screen 1: Merchant home (`MerchantWorkbench` in `App/MerchantHomeView.swift`)
Reference: `docs/evidence/player-e2e-20260927/001-home-player.png` (this is the merchant home), mini-program `pages/merchant/index`.

```
 Hi, <store name>                      (large heavy headline, 2 lines max)
 [● 营业中]  welcome line              (status chip: only if data exists; see states)

              收入
            ¥1,234.00                 (CYBalanceHero, centred, tabular figures; "—" when unknown)

  (◎ 扫码) (◎ 客户) (◎ 财务) (◎ 更多)   four circular quick actions, white circles, soft shadow

  提醒  (reminders: white rounded card, rows)
  待办  (todo counts card)
  项目 / 订单 (records card: orders, projects; "全部 N →" style trailing chevron)
  更多 (tools card, reached by the 更多 circle)
  近 7 日收入 / 动态 (cards)
```
- Stays: all sections, all rows, all accessibility identifiers, all localisation keys. Order unchanged: hero, quick actions, reminders, todo, records, more, revenue7d, events.
- Change: the plain inset `List` rows become white rounded cards (`.listRowBackground(CYColor.bgElevated)` plus the system inset-grouped radius) on the `#F3F4F4` page; hero uses the `CYBalanceHero` look (meta label, data amount, centred); quick circles get a soft shadow.
- Primary action: none is added on the home. The scan circle is the first quick action (leading, the only emphasised control). Visible controls besides it: customers, finance, more (3).
- Demoted: "refresh access" button stays in the last section (already at the bottom); nothing is removed.
- States: loading = CYSkeleton in the hero slot; error = inline failure row with retry; unknown revenue (no dashboard permission or failed read) = "—" not 0; empty todo = "merchant.todo.empty" text in the card.
- Dynamic Type XL: amount uses `minimumScaleFactor`, circles use `@ScaledMetric`, labels wrap to 2 lines.

## Screen 2: Coupon management (`App/CouponManagementView.swift`, fixture `--ui-coupon-management`)
Reference: mini-program `subpackageMember/coupon` and `merchant` coupon list (no dedicated screenshot; closest: merchant list cards in `page-polish-20261102/impl-merchant`).
- Known bug: renders mid-grey. Root cause is in the DEBUG fixture theme switch (`FixtureThemeDomainModifier` in `QuestifyApp.swift`): it only picks `.merchant` when a launch argument contains the word "merchant". `--ui-coupon-management` has none, so the fixture got `.player` (dark, and a dark `List` shows `#3A3A3C`-like grouped cells). Fix: the fixture host sets `.themeDomain(.merchant)` itself, and the view paints `CYColor.bgPage` with `scrollContentBackground(.hidden)` so it never depends on the host.
- Keeps: every row, identifiers, the create (+) toolbar button (the one primary), recover button (shown only with pending commands).
- States: loading (ProgressView row), empty (ContentUnavailableView), signed-out, unavailable.

## Screens 3-5: customers, finance entry, orders / projects lists
`MerchantOrdersView`, `MerchantProjectsView`, customers (`MerchantBusinessPage`) and the ledger entry are reached from the home. They keep their structure; the light page background and card rows come from the same list treatment (`.scrollContentBackground(.hidden)` + page colour). No reference screenshot exists for these beyond the merchant list shots, so the closest reference is stated in the report.

## Type and spacing
Headline `CYTypography.sectionTitle` (heavy), amount `CYTypography.dataXL` with `.monospacedDigit()`, spacing from `CYSpacing` (md 12 / lg 16 / xxl), card radius from the system inset-grouped style (continuous).
