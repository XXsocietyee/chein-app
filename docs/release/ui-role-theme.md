# Role theme (UI-01) — NOT COMPILED

Player surfaces are **dark**, merchant surfaces are **light**, independent of device appearance.

## Pieces
- `App/Theme/Theme.swift` (existing): `ThemeDomain`, `.themeDomain(_:)` — sets environment `themeDomain`, `colorScheme` and `preferredColorScheme`.
- `App/Theme/RoleTheme.swift` (new): `RoleTheme { player, merchant }`, `EnvironmentValues.roleTheme`, `.roleTheme(_:)`, `.roleThemedPresentation()`. Thin layer over `ThemeDomain`; no new colours.

## Where it is applied (roots only)
| Root | File | Modifier |
|---|---|---|
| Player tab shell | `App/QuestifyApp.swift` `SessionRootView` | `.roleTheme(.player)` |
| Welcome / guest entry | `App/QuestifyApp.swift` | `.roleTheme(.player)` |
| Merchant console | `App/HomeSearchTabParityViews.swift` `SessionMerchantRootContainerView` | `.roleTheme(.merchant)` |

Previously these called `.themeDomain(...)` directly; behaviour is identical plus the `roleTheme` environment value.

## Sheets / fullScreenCover
`roleTheme` is an environment value, so a presented sheet inherits it from the presenting view. `preferredColorScheme` set at the root also governs presented hierarchies. For a sheet or cover whose content should be forced explicitly (e.g. presented from a UIKit host or a different window), append `.roleThemedPresentation()` to the **sheet content**:

```swift
.sheet(item: $item) { MySheet(item: $0).roleThemedPresentation() }
```

Rules: merchant-only screens/sheets live under the merchant root and inherit light; creator/authoring, clubs, IM and wallet are player (dark) unless under the merchant console. Colours still come from `CYColor` / `Theme.Color(in:)`; no raw hex outside `App/DesignSystem/`.

## Not done / follow-ups
- Not compiled; Cursor to build and screenshot.
- Existing per-screen `.themeDomain(domain)` calls are left untouched (they remain valid).
- Sheets are not mass-edited; add `.roleThemedPresentation()` per sheet only if a screenshot shows it following the device appearance.
