# UI-12 report — Merchant[A-D]*.swift (light theme) — NOT COMPILED

Reviewed: 48 `App/Merchant[A-D]*.swift` files. Changed: 7. No new string keys (`docs/release/ui-strings-ui-12.json` not needed). No new components.

| File | Change | Pattern |
|---|---|---|
| MerchantAndPublishAuthoringSectionView.swift | `Color.green/orange` -> `CYColor.successText/warningText` | token status colours |
| MerchantBusinessEditor.swift | `.red` -> `CYColor.dangerText` | token |
| MerchantBusinessViews.swift | `.red` -> `CYColor.dangerText` | token |
| MerchantCRMDateRangePicker.swift | `.red` -> `CYColor.dangerText` | token |
| MerchantCityNodeCreateView.swift | orange tint bg -> `CYColor.warningSoft`; green/orange text -> success/warningText | token |
| MerchantCityNodeHubView.swift | red/orange tint bg -> `CYColor.dangerSoft/warningSoft` | token |
| MerchantContentEditor.swift | `.orange` -> `CYColor.warningText` | token |

Skipped (owned by wave 1): MerchantCustomerListParityViews.swift (UI-07), MerchantCoopCenterView.swift (UI-11).
Left as is: remaining files already use semantic styles (`.secondary`, text styles) or are fixture/model files; no per-view `preferredColorScheme` found. Larger layout/empty-state refactors not attempted (cannot compile; "if unsure, do not change").
Theme: light, via role root. Accessibility identifiers and text keys untouched.
