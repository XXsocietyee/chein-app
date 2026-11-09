# Design report D5: merchant console (light)

Branch `ui/d5`, rebased on `origin/ui/kit`. Screens are the real views under `.roleTheme(.merchant)`, reached through DEBUG-only synthetic fixtures in `App/DesignFixtures/MerchantConsoleFixtures.swift` (registry names: `merchant-home`, `merchant-home-unknown`, `merchant-orders`, `merchant-projects`, `merchant-customers`, `merchant-finance`, `merchant-coupons`). Data is labelled synthetic ("Synthetic …", "SYN-…"). Never in Release.
Images in `/Users/fanning/chengyin-refs/design-reports/d5/`.

## Coupon grey bug (root cause + fix)
`--ui-coupon-management` has no word "merchant", so the DEBUG `FixtureThemeDomainModifier` in `QuestifyApp.swift` picked `.player` (dark) and the grouped List rendered mid-grey. Fix: the fixture host applies `.roleTheme(.merchant)` + `cyDomainPageBackground()`, and the real `CouponManagementView` paints `CYColor.bgPage` with `scrollContentBackground(.hidden)` so it no longer depends on the host. Verified light (#F3F4F4) in zh and EN (`compare-coupons-en.png`).

## Changes (presentation only)
- Home (`MerchantHomeView`): inline nav title so the store name is the page headline aligned to the card edge; revenue as the large tabular `CYTypography.display` figure (em dash when unknown, never 0); quick circles white with soft shadow; at accessibility sizes the circles flow into 2 columns instead of clipping. Pairing: `001-home-player.png` (the merchant home), `compare-home.png`.
- Orders, projects (+ their detail summaries), customers/business page, finance (ledger overview): `.scrollContentBackground(.hidden)` + `CYColor.bgPage`, so every merchant list is #F3F4F4 with white cards (before: system #F2F2F7).
- Orders row: number/amount and status/time stack at accessibility sizes (`ViewThatFits`), no mid-number wrapping.

## Compare images
`compare-home.png` (reference | native zh), `compare-home-en-xl.png` (EN | zh XL), `compare-coupons-en.png`, `compare-lists.png` (orders zh/EN/XL, projects, customers), `compare-xl-unknown.png` (orders XL, unknown revenue + empty todo, home XL).

## Checklist (home)
1 information order: greeting/name, revenue, 4 circles, reminders, todo, records, more: yes (reference has a project card list; the home does not load projects, so records rows remain, no logic added). 2 one primary: none added; scan is the leading circle. 3 other controls: customers, finance, more (3). 4 light theme: yes. 5 no violet: yes. 6 kit tokens: yes. 7 states: unknown = em dash, empty todo text, skeleton while loading: yes. 8 XL: no clipping on home and orders. 9 EN + zh: both checked. 10 builds 0 errors, no logic changes.

## Demoted controls
None removed. Refresh-access stays at the bottom of the home.

## Open issues
- Reference shows a "营业中" chip, greeting line and project cards with cover/status/bell on the home: no data/localisation key on the home reader (existing UIV-TODO), not invented.
- Amount lacks thousands grouping (`MerchantMoney.display`, Core logic untouched).
- Customers/finance/projects keep their existing list structure (only theme/background changed); no kit card restyle yet.
- Coupon XL and customers/finance XL were not re-shot.
