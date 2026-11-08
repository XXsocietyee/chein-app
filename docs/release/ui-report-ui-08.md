# UI-08 report: merchant store setup / perks / reviews polish

**NOT COMPILED** (authored without a Swift toolchain; Cursor to build and screenshot).

| Screen file | What changed | Pattern followed | Theme | New string keys |
|---|---|---|---|---|
| App/MerchantReviewSummaryHeader.swift (`pages/merchant/reviews/index`) | Raw `Color.orange/.secondary` and system fonts replaced by `CYColor`/`CYTypography` tokens; score uses tabular rounded numeral; the four manage metrics sit on `bgSurfaceSubtle` rounded tiles (Revolut-style stat tiles). Em dash for missing values unchanged (UNKNOWN never 0). | Mini-program reviews header structure unchanged; Revolut stat tiles | light (merchant) | none |
| App/MerchantPerkTemplatesView.swift (`pages/merchant/decor/perks`) | Banner tints (`.green/.orange/.red/.secondary`) -> semantic `CYColor` tokens; row title/meta use `CYTypography`; type and expired labels become soft capsule badges (`accentSoft`/`warningSoft`); empty state uses `CYEmptyStateView`; close button uses `minTouchTarget`. | Mini-program perks list; Revolut calm cards/badges | light (merchant) | none |

## Not done
- `#Preview` blocks not added: `MerchantReviewSummaryPresentation` only has a failable init from a server document (Core, off limits), and `MerchantPerkTemplatesCoordinator` needs an injected reader/executor. Adding fixtures would need Core/test-support changes.
- Not touched (scope kept small, no compile available): store setup (`MerchantOperationsViews`), coupons, offers, authoring release, reservations. Forcing `.preferredColorScheme(.light)` is UI-01's role-root wiring, not repeated here.

Files touched: 2 source + this report. New component files: 0. New string keys: 0.
