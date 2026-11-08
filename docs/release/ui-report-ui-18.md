# UI-18 report — App/Native[M-Z]*.swift (dark / player) — NOT COMPILED

Reviewed: all 45 `App/Native[M-Z]*.swift` files (5402 lines). Wave-1 overlap (ui-01..11): none.

| file | change | pattern | theme |
|---|---|---|---|
| NativeSupersetOverMiniProgramSectionView.swift | raw `.green/.orange/.red` badges -> `CYColor.success/warning/danger` Text+Soft tokens (new private `badgeSoftColor`) | CYColor tokens | dark |
| NativeWebhookEndpointEditor.swift | `.foregroundStyle(.red)` -> `CYColor.dangerText` (2 places) | CYColor tokens | dark |
| NativeMotionReminderViews.swift | step count raw rounded font -> `CYTypography.data2XL` (monospaced digit) | numeric typography | dark |
| NativeMediaGallery.swift | `Color(uiColor: .systemBackground)` -> `CYColor.bgPage` | CYColor tokens | dark |

New string keys: none (`docs/release/ui-strings-ui-18.json` not needed).
Skipped: remaining files already clean (system controls, text styles, ContentUnavailableView, localized keys). `NativePresentationFixtureSupport.swift` uses UIColor for a fixture image only — left as is. Hard-coded Chinese `Text("...")` in the RPG/recovery author views were left (no catalog keys; adding keys would be a larger change than this pass allows).
Files touched: 4 source + this report.
