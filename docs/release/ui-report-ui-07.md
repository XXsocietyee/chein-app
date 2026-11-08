# UI-07 report — Merchant console home / to-do / analytics / customers (NOT COMPILED)

Theme: LIGHT (merchant). Base: origin/wip/gate-allowlist. No new strings, no new components.

| File | Change | Follows | Theme | New keys |
|---|---|---|---|---|
| App/MerchantHomeView.swift | `.preferredColorScheme(.light)` at the merchant home root; to-do empty state is now a `Label` with checkmark symbol; `MerchantCountRow` shows a large tabular `title3` semibold numeral with secondary label (Revolut-style); 2 previews (light + dark sanity) | pages/merchant/index/index; Revolut numerals | light | none |
| App/MerchantCustomerListParityViews.swift | raw `Color.orange/.secondary` replaced by `CYColor.warningText/textSecondary`; footer token colour; 2 previews | pages/merchant/customer/index | light | none |

Analytics: `MerchantMoney.display` already renders UNKNOWN as an em dash (verified in Core/MerchantContracts.swift); `MerchantMarketingHomeSections` left untouched (counts are server-given, source says never a dash; no change needed).

Could NOT do: previews with full Row/Reader fixtures (types need Core fixtures I could not verify without compiling); skeleton loaders for dashboard (would need new component, out of scope for safe diff); per-sheet light forcing for sheets presented from child views (UI-01 owns role-root theming).

Files touched: 2 (+ this report). New component files: 0. New string keys: 0.
