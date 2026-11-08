# UI-02 report — Player Home / Discover / Map / Roam / city selection (dark)

**STATUS: NOT COMPILED** (authored in a Linux cloud session; Cursor must build and screenshot).

| File | What changed | Follows | Theme | New string keys |
|---|---|---|---|---|
| App/HomeFeedView.swift | List page background -> `CYColor.bgPage` (`scrollContentBackground(.hidden)`); rail/section titles via `CYTypography.sectionTitle` + heading trait, `textCase(nil)`; unavailable/empty states -> `CYEmptyStateView`; retry & load-more -> `.cySecondary` (44pt); banner placeholder -> `CYColor.bgSurfaceSubtle`; rail spacing -> `CYSpacing.md`; added dark + light `#Preview` (DEBUG, existing synthetic `HomeFeedFixtureReader`) | `pages/index/index` (structure unchanged: hero, banners, 3 rails, explore stream) | dark (player root forces it) | none |
| App/HomeSearchTabParityViews.swift | Hero greeting -> `CYTypography.pageTitle` + `CYColor.textPrimary` + header trait; non-menu city label `.secondary` -> `CYColor.textSecondary` | `v3-hero-greet-row` | dark | none |

Every `accessibilityIdentifier` and existing text key is kept. No logic, contract, routing or Core changes.

## Not done
- `RoamBrowserView.swift` (487 lines, heavy read/state logic), map layers and `CityAcquisition*` / city switching views were not touched: without a compiler the risk of breaking tightly coupled state code outweighed the benefit. Recommend a follow-up pass with build access.
- Player-root `.preferredColorScheme(.dark)` belongs to UI-01 and was not duplicated here.
- No new components; no new strings (`docs/release/ui-strings-ui-02.json` is `[]`).

Files touched: 2 source + 2 docs.
