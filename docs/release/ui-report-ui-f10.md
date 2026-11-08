# UI-F10 report: shared visual language fidelity (tokens, components, tab bar)

**NOT COMPILED.** Swift was written without a compiler; Cursor must build and screenshot.

Mini-program source: accessible (`liboyang42-cpu/chengyin`, `chengyinhub-xcx/`). Read: `style/tokens.wxss`, `app.wxss`, `style/components.wxss`, `style/TOKEN-MAPPING.md`, `components/tabBar/*`, `custom-tab-bar/*`, `app.json` tabBar, `docs/DESIGN.md`, `design-qa.md`. Looked at screenshot `docs/xcx-wechat-review-board-shots/shell-workbench.png` (merchant light, bottom bar). Not read in depth: `docs/xcx-wechat-review-board.html` (audit board, no token content), other `docs/*.md` handbooks, ~60 `components/cy/*` scene components.

Branch `cloud/ui-f10` from `origin/wip/gate-allowlist`. Presentation only; no existing file changed.

## Deliverables

| File | Purpose |
|---|---|
| `docs/release/ui-token-diff.md` | Token / component diff, exact values (colours dark+light, radii, spacing, type, shadows, tab bar, components). |
| `App/DesignSystem/CYDomainPalette.swift` (new) | `CYDomainPalette` (mini-program colours per `ThemeDomain`, from `Theme.Generated` with literal fallbacks), `@Environment(\.cyPalette)`, `.cyDomainCard()`, `.cyDomainPageBackground()`, `.cyDomainPrimary/.cyDomainSecondary/.cyDomainDestructive` button styles, dark + light `#Preview`s. |
| `App/DesignSystem/CYDomainTabBar.swift` (new) | `.cyDomainTabBar(.player/.merchant)` TabView styling (violet selected tint, glass/gradient bar), `CYDomainTabLabel` (outline/fill icon swap), `CYDomainTabIcons` (icon + title-key map for both roles), `CYTabBarAppearance.install()` (45% unselected), dark + light previews. |
| `App/Theme/Theme+MiniProgramReference.swift` (new) | `Theme.MiniProgramChrome` literals (tab violet, .45 opacity, .55 glass, sizes) and `ThemeDomain.palette`. |

## Key findings

1. `Theme.Generated` already carries the correct mini-program per-domain palette, but screens use `CYColor`, which is violet-accent and appearance-driven with different greys. Every `.cyPrimary` button and `CYCard` therefore differs from the mini-program: violet fill instead of `#F8F8F8` (player) / `#000000` (merchant), bordered cards instead of elevated-fill + top highlight (dark) / shadow (light), outline on secondary, soft-tint danger instead of solid `#D0323B`.
2. Tab structure already matches: both roots are native `TabView`s with the same five tabs, order and SF Symbol intent as `components/tabBar` (`custom-tab-bar` is an empty shim). Only styling differed (section 7 of the diff).
3. `CYRadius` names are shifted one step vs the mini-program (`CYRadius.md` = 16pt = mini `lg`). `Theme.Radius` is correct. `CYTypography.body` is `.body` (17pt) vs mini 14pt; kept (Dynamic Type rule).
4. Fix strategy: no existing symbol was edited (other agents compile against them). New domain-aware styles sit beside the old ones.

## Not done / needs the integrator

| Item | Why |
|---|---|
| Wiring `.cyDomainTabBar(.player)` on the `TabView` in `QuestifyApp.swift` and `.cyDomainTabBar(.merchant)` in `SessionMerchantRootContainerView` (`HomeSearchTabParityViews.swift`); calling `CYTabBarAppearance.install()` at launch | Those files are on the never-edit list. One line each. |
| Replacing `.cyPrimary` / `.cySecondary` / `.cyDestructive` / `CYCard` usages with `.cyDomain*` | Screens belong to other UI agents. Alternative global fix: change `CYColor` accent/primary values in `CYDesignTokens.swift` (existing file, rewrite barred by the brief). Recommend the integrator choose one. |
| Merchant card shadow opacity | Mini literal is `rgba(15,23,43,.48)` for a 4pt blur, looks like a possible `.048` typo; mirrored as is, flagged in the diff, check in screenshots. |
| Unselected tab contrast | Mini's 45% opacity on light gives ~3.4:1 for labels (below 4.5:1 AA for text); copied for fidelity, flag for UI-11. |
| Typography ramp | Not changed (Apple Dynamic Type styles decision); differences documented. |
| Remaining `components/cy/*` (empty/error detail, tag, scene components) | Not compared in depth. |
| Compile-time risks | `CYDomainPalette` uses `Theme.Generated.color(_:in:)` (internal, same module), `ToolbarBackground` with `LinearGradient`/material (iOS 16+), `UITabBarItemAppearance` loops; unverified by compiler. |

## New string keys

None (`docs/release/ui-strings-ui-f10.json` not needed). Tab titles reuse existing catalog keys `tabBar.*` / `tabBar.merchant.*`; preview text uses `verbatim:` synthetic strings.

## Files touched

4 added, 0 modified: the 3 Swift files and the 2 docs above (token diff, this report) -> 5 files added in total (3 Swift + 2 docs).
