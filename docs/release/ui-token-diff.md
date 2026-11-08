# UI token / component diff: WeChat mini-program vs iOS (UI-F10)

NOT COMPILED. Sources compared:

- Mini-program: `chengyinhub-xcx/style/tokens.wxss` (v2 semantic layer, `page{}` = player dark, `.theme-light/.theme-merchant` = merchant light), `app.wxss`, `style/components.wxss`, `components/tabBar/*`, `custom-tab-bar/*`, `docs/DESIGN.md`, `style/TOKEN-MAPPING.md`, screenshot `docs/xcx-wechat-review-board-shots/shell-workbench.png` (merchant light tab bar).
- iOS: `App/DesignSystem/CYDesignTokens.swift`, `CYDesignComponents.swift`, `App/Theme/Theme.swift`, `Theme+Generated.swift` (generated from tokens.wxss, 375pt basis: 1rpx = 0.5pt).

## 0. Root cause

There are two token layers on iOS and they disagree:

| Layer | Matches mini-program? |
|---|---|
| `Theme` / `Theme+Generated.swift` (`ThemeDomain` player=dark, merchant=light) | Yes. Generated from tokens.wxss, per-domain values correct. |
| `CYColor` / `CYTypography` / `CYSpacing` / `CYRadius` / `CYCard` / `.cyPrimary` (what every screen uses per the UI brief) | No. Violet-accent palette (`#7A5CFF`), appearance-driven (not role-driven) light/dark pairs, different greys, pill buttons, bordered cards. |

The mini-program removed violet from brand/selection on 2026-08-01 (player brand = near-white, merchant brand = grey `#33363C`, CTA = solid neutral). Violet `#7A5CFF` survives only as the **selected tab icon** (UI-03, 2026-09-18). `CYColor.accent` / `.cyPrimary` still paint every primary action violet.

## 1. Colour: dark (player) values

| Mini-program token | Mini value | iOS `CYColor` equivalent | iOS value | Difference |
|---|---|---|---|---|
| `--cy-color-bg-page` | `#000000` | `bgPage` (dark) | `#000000` | none |
| `--cy-color-bg-surface` | `#0A0A0B` | `bgSurface` | `#0A0A0B` | none |
| `--cy-color-bg-surface-subtle` | `#141416` | `bgSurfaceSubtle` | `#141416` | none |
| `--cy-color-bg-elevated` (card fill) | `#1C1C1E` | `bgElevated` | `#1C1C1E` | none (but `CYCard` default variant is `.surface` = `#0A0A0B`, not elevated) |
| `--cy-color-bg-raised` | `#2A2A2C` | `bgRaised` | `#2A2A2C` | none |
| `--cy-color-bg-surface-strong` | `#3B3B3D` | `bgSurfaceStrong` | `#3B3B3D` | none |
| `--cy-color-bg-interactive` | `#4D4D4D` | none | , | missing |
| `--cy-color-text-primary` | `#F8F8F8` | `textPrimary` | `#F5F5F7` | slightly cooler/darker |
| `--cy-color-text-secondary` | `#B7B7B7` | `textSecondary` | `#D4D4D8` | iOS much brighter (13.0 vs ~9:1) |
| `--cy-color-text-tertiary` | `#919191` | `textTertiary` | `#A1A1AA` | iOS brighter, blue tint |
| `--cy-color-text-placeholder` | `#868686` | `textPlaceholder` | `#8E8E98` | blue tint |
| `--cy-color-text-disabled` | `rgba(255,255,255,.40)` | `textDisabled` | `#6E6E77` | different |
| `--cy-color-text-inverse` | `#0A0A0A` | `textInverse` | `#0A0A0B` | none (visually) |
| `--cy-color-brand` / `--cy-color-selection` | `#F8F8F8` | `accent` | `#7A5CFF` violet | **wrong hue** |
| `--cy-color-brand-soft` | `rgba(248,248,248,.12)` | `accentSoft` | `rgba(122,92,255,.18)` | **violet tint** |
| `--cy-color-action-primary-bg/fg` | `#F8F8F8` / `#0A0A0A` | `.cyPrimary` | `#7A5CFF` bg / white fg | **violet CTA instead of neutral** |
| `--cy-color-action-secondary-bg` | `rgba(255,255,255,.08)` | `.cySecondary` | `#141416` fill + 1pt `borderStrong` outline | mini: fill only, no outline |
| `--cy-color-action-danger-bg/fg` | `#D0323B` / `#FFFFFF` | `.cyDestructive` | soft red tint + red outline, `#F87171` text | mini: solid fill |
| `--cy-color-status-success` | `#22C55E` | `successText` | `#34D399` | different green |
| `--cy-color-status-warning` | `#D58300` | `warningText` | `#FBBF24` | different amber |
| `--cy-color-status-danger` | `#E5484D` | `dangerText` | `#F87171` | lighter |
| `--cy-color-status-info` | `#4C86FF` | `infoText` | `#60A5FA` | lighter |
| `*-soft` (danger/success/warning/info) | alpha .14 / .14 / .18 / .14 | `*Soft` | alpha .18 (all) on different bases | different alphas and base colours |
| `--cy-color-border-subtle` | `rgba(255,255,255,.08)` | `borderSubtle` | `rgba(255,255,255,.09)` | ~none |
| `--cy-color-border-strong` | `rgba(255,255,255,.16)` | `borderStrong` | `rgba(255,255,255,.18)` | ~none |
| `--cy-color-overlay` | `rgba(0,0,0,.56)` | `bgOverlay` | `rgba(0,0,0,.65)` | iOS darker |
| `--cy-color-bg-glass` | `rgba(28,28,30,.82)` (tab bar: `.55`) | `bgGlass` | `rgba(10,10,11,.84)` | different base |
| `--cy-color-skeleton-base/highlight` | `#191919` / `#242424` | none | , | missing |

## 2. Colour: light (merchant) values

| Mini-program token | Mini value | iOS `CYColor` equivalent | iOS value | Difference |
|---|---|---|---|---|
| `--cy-color-bg-page` | `#F3F4F4` | `bgPage` | `#F3F4F4` | none |
| `--cy-color-bg-surface` / `elevated` | `#FFFFFF` | `bgSurface` / `bgElevated` | `#FFFFFF` | none |
| `--cy-color-bg-surface-subtle` | `#EEEEEE` | `bgSurfaceSubtle` | `#EEEEEE` | none |
| `--cy-color-bg-raised` | `#E6E6E6` | `bgRaised` | `#E6E6E6` | none |
| `--cy-color-bg-surface-strong` | `#E4E4E4` | `bgSurfaceStrong` | `#E4E4E4` | none |
| `--cy-color-text-primary` | `#000000` (user decision 2026-08-07: pure black) | `textPrimary` | `#18181B` | cool-tinted off-black |
| `--cy-color-text-secondary` | `#404040` | `textSecondary` | `#3F3F46` | blue tint |
| `--cy-color-text-tertiary` | `#6B6B6B` | `textTertiary` | `#52525B` | iOS darker |
| `--cy-color-text-placeholder` | `#6F6F6F` | `textPlaceholder` | `#71717A` | blue tint |
| `--cy-color-text-disabled` | `#737373` | `textDisabled` | `#71717A` | ~none |
| `--cy-color-brand` / selection | `#33363C` (grey, no violet/ink-blue) | `accent` | `#7A5CFF` | **wrong hue** |
| `--cy-color-brand-soft` | `#EAEBEE` | `accentSoft` | `#EDE9FE` | violet tint |
| `--cy-color-action-primary-bg/fg` | `#000000` / `#FFFFFF` | `.cyPrimary` | `#7A5CFF` / white | **violet CTA instead of black** |
| `--cy-color-action-secondary-bg` | `#EEEEEE` | `.cySecondary` | `#EEEEEE` fill + 1pt `rgba(15,23,42,.16)` outline | outline not in mini |
| `--cy-color-action-danger-bg` | `#D0323B` | `.cyDestructive` | `#FEE2E2` soft + outline | mini: solid |
| `--cy-color-status-success` | `#0B7A57` | `successText` | `#047857` | different |
| `--cy-color-status-warning` | `#96610A` | `warningText` | `#B45309` | different |
| `--cy-color-status-danger` | `#D0323B` | `dangerText` / `dangerSolid` | `#B91C1C` / `#DC2626` | different |
| `--cy-color-status-info` | `#2563EB` | `infoText` | `#1D4ED8` | different |
| `--cy-color-border-subtle` | `#E8E8E8` | `borderSubtle` | `rgba(15,23,42,.08)` | ink-blue tint, translucent |
| `--cy-color-border-strong` | `#DBDBDB` | `borderStrong` | `rgba(15,23,42,.16)` | ink-blue tint |
| `--cy-color-overlay` | `rgba(0,0,0,.56)` | `bgOverlay` | `rgba(15,23,42,.48)` | ink-blue tint |
| input idle / filled bg (light) | `#FFFFFF` / `#EFEFEF` | none | , | missing |

Key mismatch: `CYColor` switches by `colorScheme`; the mini-program switches by **role domain**. Role roots already force the scheme (`ThemeDomain`), so a role-driven token reader is correct; `CYColor` pairs are still the wrong values.

## 3. Radii

| Mini token | rpx | pt (basis 375) | iOS `CYRadius` | iOS pt | Difference |
|---|---|---|---|---|---|
| `--cy-radius-sm` | 16 | 8 | `xs` | 8 | name shifted by one |
| `--cy-radius-md` (component button radius; default card radius in `.cy-card`) | 24 | 12 | `sm` | 12 | name shifted |
| `--cy-radius-lg` (`--cy-comp-card-radius`, sheet card) | 32 | 16 | `md` | 16 | name shifted |
| `--cy-radius-xl` | 40 | 20 | `lg` | 20 | name shifted |
| `--cy-radius-2xl` | 44 | 22 | `xl` | 22 | name shifted |
| (sheet) | , | , | `sheet` | 24 | no mini token (`--cy-sheet-immersive-radius` 88rpx = 44pt for immersive sheets) |
| `--cy-radius-pill` | 999 | 499.5 | `pill` | 999 | equal visually |

`Theme.Radius` (generated) already uses the mini names/values (sm 8, md 12, lg 16, xl 20, xxl 22). Mixing `CYRadius.md` (16) with the mini word "md" (12) is a trap; the new `CYDomainCard` uses `Theme.Radius`.
Buttons: mini component button = 12pt radius (`--cy-comp-btn-radius`) with `.cy-btn` global class at 16pt (`--cy-radius-lg`); iOS `.cyPrimary` = full pill (999). Mini screenshot confirms pill only on a few retry CTAs; default is rounded rectangle.

## 4. Spacing (4pt grid; mini basis 375pt)

| Mini token | rpx | pt | iOS `CYSpacing` | pt |
|---|---|---|---|---|
| `--cy-space-1` | 8 | 4 | `xs` | 4 |
| `--cy-space-1-5` | 12 | 6 | , | missing (use `Theme.Space.s1_5`) |
| `--cy-space-2` | 16 | 8 | `sm` | 8 |
| `--cy-space-2-5` | 20 | 10 | , | missing |
| `--cy-space-3` | 24 | 12 | `md` | 12 |
| `--cy-space-3-5` | 28 | 14 | , | missing |
| `--cy-space-4` / `--cy-page-x` / card padding | 32 | 16 | `lg` / `pageHorizontal` | 16 |
| `--cy-space-5` | 48 | 24 | `xxl` | 24 |
| `--cy-space-6` | 64 | 32 | `xxxl` | 32 |
| `--cy-space-7` | 80 | 40 | `hero` | 40 |
| `--cy-space-8` | 96 | 48 | `jumbo` | 48 |
| , | , | , | `xxs` 2, `xl` 20 | extras, no mini token |
| `--cy-btn-h` / `-sm` / `-xs` | 88 / 64 / 56 | 44 / 32 / 28 | `minTouchTarget` | 44 |

Values are compatible; only the doc comments in `CYSpacing` cite non-existent token names (`--cy-space-16`). `Theme.Space` (generated) has the exact mini names.

## 5. Type scale

Mini sizes at 375pt basis (`--cy-type-*`, scaled by `--cy-type-scale` except data/display).

| Mini token | rpx | pt | iOS `CYTypography` | actual iOS size at default Dynamic Type | Difference |
|---|---|---|---|---|---|
| `--cy-type-data-2xl` | 84 | 42 | `data2XL` (`.largeTitle` rounded bold) | 34 | iOS 8pt smaller; mini fixed, iOS scales |
| `--cy-type-data-xl` | 64 | 32 | `dataXL` (`.title` rounded bold) | 28 | 4pt smaller |
| `--cy-type-display` | 56 | 28 | `display` (`.largeTitle` rounded bold) | 34 | iOS larger |
| `--cy-type-page-title` | 58 | 29 | `pageTitle` (`.title` bold) | 28 | ~equal |
| `--cy-type-sheet-title` | 44 | 22 | `sheetTitle` (`.title2` semibold) | 22 | equal |
| `--cy-type-section-title` | 36 | 18 | `sectionTitle` (`.title3` semibold) | 20 | +2 |
| `--cy-type-card-title` / `--cy-type-button` | 32 | 16 | `cardTitle` (`.headline`) / `label` | 17 / 15 | ±1 |
| `--cy-type-body` | 28 | 14 | `body` (`.body`) / `bodyCompact` (`.subheadline`) | 17 / 15 | **body is 3pt larger** (doc comments claim 15) |
| `--cy-type-label` | 24 | 12 | `meta` (`.footnote`) | 13 | +1 |
| `--cy-type-caption` | 22 | 11 | `caption` (`.caption` medium) | 12 | +1 |
| `--cy-type-micro` | 20 | 10 | `micro` (`.caption2` semibold) | 11 | +1 |
| `--cy-font-numeric` | SF Mono / DIN | , | `.monospacedDigit()` | , | tabular digits kept; mini uses numeric family only for live readouts |

`Theme.Font` (generated) maps the same ramp to native text styles (`pageTitle` = `.title` semibold, `body` = `.body`, `label` = `.caption`, `button` = `.callout` semibold); `display`/`dataXL`/`data2XL` are fixed-size (56/64/84 rpx -> 28/32/42pt rounded). Decision: keep Dynamic Type text styles on iOS (owner rule); do NOT force 14pt body. Fixed display numerals follow `Theme.Font.dataXL/data2XL`.

## 6. Shadows / elevation

| Surface | Mini | iOS |
|---|---|---|
| Dark card | no shadow; 0.5pt top-edge highlight `rgba(255,255,255,.08)` (`--cy-comp-card-highlight`); fill `#1C1C1E`; border transparent | `CYCard`: fill `#0A0A0B` (surface) with 1pt `borderSubtle` outline all round, no highlight |
| Light card | `--cy-comp-card-shadow-day: 0 2rpx 8rpx rgba(15,23,43,.48)` = y 1pt, blur 4pt; border transparent. Legacy `--cy-shadow-card: 0 4rpx 16rpx rgba(0,0,0,.04)` | `.elevated`: 1pt outline + shadow black .05, radius 10, y 4 |
| Tab bar (dark) | glass `rgba(28,28,30,.55)`, blur 40rpx (20pt) + saturate 160%, 0.5pt top border `rgba(255,255,255,.08)`, shadow `0 -1pt 8pt rgba(0,0,0,.4)` | system default bar |
| Tab bar (merchant) | transparent -> `rgba(255,255,255,.96)` vertical gradient, no blur, no border, no shadow | system default bar |
| Sheet | player glass `rgba(0,0,0,.48)` / merchant `rgba(255,255,255,.58)` (publish quick menu); sheet radius per `--cy-comp-sheet-*` | native `presentationDetents` |

Open question for design: mini `rgba(15,23,43,.48)` for a 4pt-blur card shadow is unusually opaque (looks like a `.048` typo). `CYDomainPalette.cardShadowColor` mirrors the literal value; if screenshots look heavy, change one constant.

## 7. Bottom tab bar (`components/tabBar` + `custom-tab-bar`)

`custom-tab-bar/index.*` is an empty shim (only makes `tabBar.custom:true` legal). The real bar is `components/tabBar` (in-page, per-role).

| # | Mini player (`CONSUMER_LIST`) | iOS player (`RootTab`) | Mini merchant (`MERCHANT_LIST`) | iOS merchant (`RootTabBarParity.merchantTabs`) |
|---|---|---|---|---|
| 1 | 首页 `icon_f1` | `.home` `tabBar.home` `house` | 工作台 `icon_tab_workbench` | `tabBar.merchant.workbench` `square.grid.2x2` |
| 2 | 漫游 `icon_roam` | `.roam` `map` | 营销 `icon_tab_marketing` | `tabBar.merchant.marketing` `megaphone` |
| 3 | 发布 `icon_f3` | `.publish` `plus.square` | 模板 `icon_tab_template` | `tabBar.merchant.templates` `plus.square` |
| 4 | 俱乐部 `icon_f4` | `.club` `person.3` | 合作 `icon_tab_relation` | `tabBar.merchant.cooperation` `person.2` |
| 5 | 我的 `icon_f5` | `.mine` `person.crop.circle` | 我的 `icon_tab_mine` | `RootTab.mine` `person.crop.circle` |

Structure (count, order, titles, SF Symbols) already matches and both roots are native `TabView`s (`QuestifyApp.swift` player; `SessionMerchantRootContainerView` merchant). Differences are styling only:

| Aspect | Mini | iOS today | New (`CYDomainTabBar.swift`) |
|---|---|---|---|
| Selected tint | `#7A5CFF` | system accent / app tint | `.tint(CYColor.accent)` via `.cyDomainTabBar(_:)` |
| Unselected | icon + label at 45% | system grey | `CYTabBarAppearance.install()` 45% white / black |
| Icon idle/selected | outline PNG/SVG, filled variant only in non-monochrome (unused) | `.fill` variants not used | `CYDomainTabLabel` swaps outline/fill (optional) |
| Background player | glass .55 + blur + hairline | system | `.ultraThinMaterial` + `.toolbarColorScheme(.dark)` |
| Background merchant | 0 -> .96 white gradient, no border | system | `LinearGradient` toolbar background |
| Floating publish "+" | only on the template page, not a tab | n/a (publish is a tab) | not changed |

## 8. Components

| Mini component | iOS equivalent | Difference |
|---|---|---|
| `cy/btn` (primary/secondary/danger/ghost; h 44pt, radius 12pt, 700 weight, press opacity .88, disabled = placeholder text on subtle bg) | `.cyPrimary` / `.cySecondary` / `.cyDestructive` | colours (violet vs neutral), radius (pill vs 12), outline on secondary, disabled/pressed treatment. New `.cyDomainPrimary/Secondary/Destructive` follow mini. |
| `cy/card` (fill elevated, radius 16pt, pad 16pt, highlight/shadow) | `CYCard` / `.cyCardSurface` | fill, border, shadow (section 6). New `.cyDomainCard()`. |
| `cy/empty`, `cy/error`, `cy/state-shell` | `CYEmptyStateView`, `CYErrorStateView` | Not re-verified in detail; token fixes flow through palette. Mini error shows title, one-line hint, black pill "重试" (screenshot). |
| `cy/avatar`, `cy/badge`, `cy/tag` | `CYAvatarView`, `CYUnreadBadge` | tag (h 20pt, padx 9pt, pill) has no iOS equivalent; not changed. |
| `cy/switch` (scale .8) | native `Toggle` | by design (Apple-native). |
| `cy/sheet`, `cy/nav-bar`, `cy/tabs`, `cy/modal` | native sheet detents, `NavigationStack`, `Picker`/segmented, `confirmationDialog` | by design. |
| `cy/skeleton` (`#191919`->`#242424` dark, `#ECEFF3`->`#F6F8FA` light) | `redacted(reason:)` / none | palette adds `skeletonBase/Highlight`. |

Not compared: remaining ~60 `components/cy/*` (scene-*, play-*, etc.), which are page-specific.
