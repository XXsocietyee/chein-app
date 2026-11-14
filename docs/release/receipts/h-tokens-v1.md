# Receipt: `h-tokens-v1` — Design-Token Unification & Purple/Border Retirement

- **Branch**: `ui/h-tokens-v1`
- **Base**: `origin/ui/main` (`5ba7b0f2c5f10dea10905895da947c350b3e24ac`)
- **Spec**: `docs/design/mp-design-system.md` (on `origin/docs/mp-design-system`, `0b4ca1c35`, section 6 & section 6.4)
- **Generated Source (`tokens.wxss`)**:
  - Upstream repo: `hengyin` (`origin/master` commit `561cafd10214853e8b43128a3ffe419cf115cca2`)
  - `tokens.wxss` SHA-256: `b7766933ac47befbb41f937d1186a97ff0f546fe49fb3e9e3759925ad5a8e02c`
  - Generator: `tools/wxss_tokens.py` (`tokens: 589, unsupported: 206, diagnostics: 0`) -> `App/Theme/Theme+Generated.swift`

---

## 1. Token Mapping (`token -> old -> new -> call sites`)

### 1.1 Colors, Text Hierarchy & Borders (`CYColor`, `CYDomainPalette`, `CYNight`, `Theme.MiniProgramChrome`)

| Token | Old | New | Call sites / Consumers |
| --- | --- | --- | --- |
| `CYColor.textPrimary` | hardcoded `CYRGB(0x18181B)` light / `0xF5F5F7` dark | `resolved { $0.textPrimary }` (`#000000` light / `#F8F8F8` dark, `--cy-color-text-primary`) | All `CYColor.textPrimary` consumers across `App/` |
| `CYColor.textSecondary` / `CYDomainPalette.textSecondary` | fallback `0xB7B7B7` dark / `0x404040` light | `0xC7C7C7` dark / `0x404040` light (`--cy-color-text-secondary`) | `CYColor.textSecondary`, `CYSecondaryButtonStyle`, `CYPillButtonStyle` secondary, `CYOrderActionSecondaryLabel` |
| `CYColor.textTertiary` / `CYDomainPalette.textTertiary` | fallback `0x919191` dark / `0x6B6B6B` light | `0xA8A8A8` dark / `0x6B6B6B` light (`--cy-color-text-tertiary`) | All `CYColor.textTertiary` consumers |
| `CYColor.textPlaceholder` / `CYDomainPalette.textPlaceholder` | hardcoded `0x71717A` light / `0x8E8E98` dark (`legible` `0x929292` / `0x868686`) | `resolved { $0.textPlaceholder }` (`#6F6F6F` light / `#9E9E9E` dark, `--cy-color-text-placeholder`) | All `CYColor.textPlaceholder` consumers |
| `CYColor.textDisabled` | hardcoded `0x71717A` light / `0x6E6E77` dark | `resolved { $0.textDisabled }` (`#737373` light / `rgba(255,255,255,.40)` dark) | Button styles & disabled rows |
| `CYColor.textInverse` | hardcoded `0xFFFFFF` light / `0x0A0A0B` dark | `resolved { $0.textInverse }` (`#FFFFFF` light / `#0A0A0A` dark) | Inverse text consumers |
| `CYColor.bgPage/Surface/SurfaceSubtle/Elevated/Raised/SurfaceStrong/Interactive` | hardcoded RGBs (`0x0A0A0B`, etc.) in `CYDesignTokens.swift` | Delegated via `resolved { ... }` to `CYDomainPalette` (`Theme.Generated`) | All surface containers |
| `CYColor.borderSubtle` | `0x0F172A` alpha `0.08` light / `0xFFFFFF` `0.09` dark | `resolved { $0.borderSubtle }` (`#E8E8E8` light / `rgba(255,255,255,.08)` dark) | Hairline dividers & inner strokes |
| `CYColor.borderStrong` | `0x0F172A` alpha `0.16` light / `0xFFFFFF` `0.18` dark | `resolved { $0.borderStrong }` (`#DBDBDB` light / `rgba(255,255,255,.16)` dark) | Focused inputs & control outlines |
| `CYColor.focusRing` | `CYColor.accent` (`#7A5CFF`) | `CYColor.brand` (neutral `--cy-color-brand`) | Focus rings |
| `CYColor.accent` / `accentPressed` / `accentText` / `accentSoft` / `accentStrong` / `accentWarm` / `accent*RGB` | Exposed purple (`#7A5CFF`, `#6A4AF0`, `#C4B5FD`, `#EDE9FE`) & coral (`#E04F2E` / `#FF8266`) | **Removed**; replaced with neutral `actionPrimaryBg` / `actionPrimaryFg` / `brand` / `brandStrong` / `brandSoft` / `rare` / semantic status colors | See Section 2 call-site table |
| `CYColor.actionPrimaryBg` / `actionPrimaryFg` / `brandStrong` / `brandSoft` | Missing direct exposure on `CYColor` (`textOnAccent` only) | Added delegating to `CYDomainPalette` (`#000000`/`#FFFFFF` CTA; `#F8F8F8`/`#0A0A0A` dark CTA) | Primary buttons, selected pills, CTAs (`CYDesignComponents`, `AuthChannelView`, `OrderCardComponents`, etc.) |
| `CYColor.sheetGlass` / `CYDomainPalette.sheetGlass` | Missing | `--cy-comp-sheet-player-glass` (`rgba(44,44,46,.98)` dark / `#FFFFFF` light) | Player/merchant sheets |
| `CYColor.sheetCard` / `CYDomainPalette.sheetCard` | Missing | `--cy-comp-sheet-player-card` (`#3A3A3C` dark / `#FFFFFF` light) | Nested sheet cards |
| `CYColor.modalPanel` / `CYDomainPalette.modalPanel` | Missing | `--cy-comp-modal-panel` (`#4D4D4D` dark / `#FFFFFF` light) | Centered modals |
| `CYColor.rare` / `rareFg` / `rareSoft` | Missing (callers used `CYColor.accentWarm`) | `--cy-color-rare` (`#F59F00`), `--cy-color-rare-fg`, `--cy-color-rare-soft` | `CharacterSheetDetailView.swift`, `DiceD20View.swift`, `CYNight.foilA` |
| `CYColor.medalGold` / `medalSilver` / `medalBronze` | Missing | `--cy-color-medal-gold` / `-silver` / `-bronze` | Podium/rank consumers |
| `CYColor.gameAccent` / `gameAccentFg` / `gameAccentSoft` / `gameMarker` / `gameWin` / `gameFloodWin` / `gameFloodOk` / `gameFloodMiss` + `CYDomainPalette.playkit*` + `playStory*` + `gameHeroSize` / `gameReadoutSize` | Missing | Delegated to `CYDomainPalette(.game)` / `Theme.Generated` (`--cy-game-*`, `--cy-color-playkit-*`, `--cy-color-play-story-*`) | Game runtime / playkit surfaces |
| `CYColor.tabSelected` / `CYColor.avatarRing` / `CYColor.resultSpinner` | `#7A5CFF` previously leaked via `CYColor.accent` & `CYNight.violet` | Only 3 reserved `#7A5CFF` roles (`--cy-ref-violet-500`, `--cy-comp-profile-avatar-ring`, `--cy-comp-result-spinner`) | `CYDomainTabBar.swift`, `CYNightTabBar.swift`, `CYDesignComponents.swift` (`CYAvatarView` ring), `CYDomainPalette.swift`, `CYScreenStyle.swift` |
| `CYNight.violet` / `CYNight.selection` / `CYNight.foilA` | `violet = 0x7A5CFF`; `selection -> violet`; `foilA = 0x7A5CFF` | `@available(*, deprecated, renamed: "CYColor.tabSelected") violet`; `selection -> CYColor.selection`; `foilA = 0xF59F00` | `CYNightTabBar` -> `CYColor.tabSelected`; `ClubOperationsViews` -> `CYColor.selection`; `SquareCloudFeedViews` -> `CYColor.successText`; `SearchMapComponents` -> `CYColor.actionPrimaryBg`; `CYCityBoard` -> `CYNight.lantern` |
| `Theme.MiniProgramChrome.tabUnselectedOpacity` / `tabGlassAlpha` / `lightTabGlassAlpha` | `0.45` / `0.55` / missing | `0.6` / `0.82` / `0.78` | `CYDomainTabBar.swift` |

### 1.2 Typography (`CYTypography`, `Theme.Font`)

| Token | Old | New | Call sites / Consumers |
| --- | --- | --- | --- |
| `CYTypography.display` / `Theme.Font.display` | `.largeTitle` `.bold` / `Theme.length("--cy-type-display") .semibold` | `Theme.length("--cy-type-display")` (28pt) `.bold` | Display headers |
| `CYTypography.pageTitle` / `Theme.Font.pageTitle` | `.title` `.bold` / `.semibold` | `Theme.length("--cy-type-page-title")` (29pt) `.heavy` (800) | Page headers |
| `CYTypography.sheetTitle` / `Theme.Font.sheetTitle` | `.title2` `.semibold` | `.title2` (22pt) `.bold` | Sheet titles |
| `CYTypography.sectionTitle` / `Theme.Font.sectionTitle` | `.title3` `.semibold` / `.headline` | `Theme.length("--cy-type-section-title")` (18pt) `.bold` | Section headers |
| `CYTypography.cardTitle` / `Theme.Font.cardTitle` | `.headline` / `.callout` `.semibold` | `.callout` (16pt) `.bold` | Card titles |
| `CYTypography.button` / `Theme.Font.button` | Missing on `CYTypography` (`CYPrimaryButtonStyle`/`CYSecondaryButtonStyle` used `.label`; `CYPillButtonStyle` used `.system(.body).bold()`) | `.callout` (16pt) `.bold` (700) via `Theme.Font.button` | `CYPrimaryButtonStyle`, `CYSecondaryButtonStyle`, `CYDestructiveButtonStyle`, `CYPillButtonStyle` |
| `CYTypography.body` / `bodyMedium` / `bodyCompact` / `numericBody` / `Theme.Font.body` | `.body` / `.subheadline` | `Theme.length("--cy-type-body")` (14pt) | All body text |
| `CYTypography.label` / `Theme.Font.label` | `.subheadline` `.semibold` / `.caption` | `.caption` (12pt) `.medium` via `Theme.Font.label` | Labels & metadata |
| `CYTypography.meta` | `.footnote` | `.caption` (12pt) regular | Row metadata |
| `CYTypography.caption` / `Theme.Font.caption` | `.caption` `.medium` / `.caption2` | `.caption2` (11pt) via `Theme.Font.caption` | Compact captions |
| `CYTypography.micro` / `Theme.Font.micro` | `.caption2` `.semibold` / `.caption2` | `Theme.length("--cy-type-micro")` (10pt) `.medium` | Micro badges |
| `CYTypography.dataXL` / `Theme.Font.dataXL` | `.title` rounded `.bold` / `Theme.length .semibold` | `Theme.length("--cy-type-data-xl")` (32pt) `.bold` `.rounded.monospacedDigit()` | Wallet & telemetry KPIs |
| `CYTypography.data2XL` / `Theme.Font.data2XL` | `.largeTitle` rounded `.bold` / `Theme.length .semibold` | `Theme.length("--cy-type-data-2xl")` (42pt) `.bold` `.rounded.monospacedDigit()` | Primary balance displays |

### 1.3 Spacing & Radius (`CYSpacing`, `CYRadius`)

| Token | Old | New | Call sites / Consumers |
| --- | --- | --- | --- |
| `CYSpacing.xs..jumbo`, `pageHorizontal`, `minTouchTarget` | Literal `4, 8, 12, 16, 24, 32, 40, 48, lg, 44` | Delegated to `Theme.Space.s1..s8`, `Theme.Space.pageX`, `Theme.MiniProgramChrome.minHit` | All `CYSpacing` consumers |
| `CYSpacing.s1_5`, `s2_5`, `s3_5` | Missing | `Theme.Space.s1_5` (6pt), `Theme.Space.s2_5` (10pt), `Theme.Space.s3_5` (14pt) | Half-step spatial layouts |
| `CYRadius.xs` | `8` (primary 8pt token; shifted 1 tier) | `@available(*, deprecated, renamed: "sm") public static let xs: CGFloat = sm` (8pt preserved for source compatibility) | Existing `CYRadius.xs` callers keep compiling (`ClubChannelMessagingView:494` updated to `CYRadius.sm`) |
| `CYRadius.sm / md / lg / xl / xxl` | `12 / 16 / 20 / 22 / missing` | `Theme.Radius.sm` (8) / `md` (12) / `lg` (16) / `xl` (20) / `xxl` (22) | `CYCardSurfaceModifier`/`cyCardSurface`/`CYCard`/`CYRoamNearbyCard` default -> `CYRadius.lg` (16pt); `CYSecondaryButtonStyle`/`CYDestructiveButtonStyle` -> `CYRadius.md` (12pt) |
| `CYRadius.sheet` / `pill` | `24` / `999` | `24` / `Theme.Radius.pill` (`499.5`, prefer `Capsule`) | Sheet & pill radii |

---

## 2. Retired Purple (`#7A5CFF` / `CYColor.accent*` / `accentWarm` / `CYNight.violet` / `CYNight.selection`) & Outer Stroke Border Call Sites Changed

- **DesignSystem core components**:
  - `App/DesignSystem/CYNight.swift`: `violet` deprecated (`CYColor.tabSelected`), `selection` -> `CYColor.selection`, `foilA` `0x7A5CFF` -> `0xF59F00`.
  - `App/DesignSystem/CYNightTabBar.swift:90-92`: `CYNight.violet` -> `CYColor.tabSelected` (approved tab-selected role).
  - `App/DesignSystem/CYCityBoard.swift:146`: `CYNight.violet` -> `CYNight.lantern`.
  - `App/DesignSystem/CYDesignComponents.swift`:
    - `CYCardSurfaceModifier`, `View.cyCardSurface`, `CYCard`: default radius `CYRadius.md` -> `CYRadius.lg` (16pt), `.accentTint` fill `CYColor.accentSoft` -> `CYColor.brandSoft`, removed `borderColor` & `.overlay(shape.strokeBorder(borderColor, lineWidth: 1))`.
    - `CYSectionHeader:142`: `CYColor.accentText` -> `CYColor.brand`.
    - `CYPrimaryButtonStyle`: font `.label` -> `CYTypography.button`, foreground `CYColor.textOnAccent` -> `CYColor.actionPrimaryFg`, background `CYColor.accent`/`accentPressed` -> `CYColor.actionPrimaryBg`/`CYColor.brandStrong`.
    - `CYSecondaryButtonStyle`: radius `CYRadius.sm` -> `CYRadius.md` (12pt), font `.label` -> `CYTypography.button`, foreground `CYColor.textPrimary` -> `CYColor.textSecondary`, removed `.overlay(shape.strokeBorder(CYColor.borderStrong, lineWidth: 1))`.
    - `CYDestructiveButtonStyle`: radius `CYRadius.sm` -> `CYRadius.md` (12pt), font `.label` -> `CYTypography.button`, removed `.overlay(shape.strokeBorder(CYColor.dangerText.opacity(0.28), lineWidth: 1))`.
    - `CYUnreadBadge:372`: `CYColor.accent` -> `CYColor.brand`.
    - `CYAvatarView:493,514,517`: ring `CYColor.accent` -> `CYColor.avatarRing` (approved role), fallback circle/initial `CYColor.accentSoft`/`accentText` -> `CYColor.brandSoft`/`brand`.
  - `App/DesignSystem/CYPillButton.swift:85,93,101-111`: font -> `CYTypography.button`, secondary foreground `palette.textSecondary`, secondary fill `palette.actionSecondaryBg`/`bgSurfaceSubtle`, removed `.overlay(shape.strokeBorder(...))` & `stroke`.
  - `App/DesignSystem/CYAlbum.swift:442`: removed outer card `strokeBorder(CYColor.borderSubtle, lineWidth: 1)`.
  - `App/DesignSystem/CYCelebrationViews.swift:658,691`: removed outer `strokeBorder` on `CYRoamSummaryView` & `CYRoamRouteCard`.
  - `App/DesignSystem/CYClubCards.swift:382`: removed outer `strokeBorder` on `CYClubRowCard`.
  - `App/DesignSystem/CYPermissionPrimer.swift:200`: removed outer `strokeBorder` on `CYPermissionPrimer`.
  - `App/DesignSystem/CYBalanceHero.swift:32`: `CYColor.accentSoft` -> `CYColor.brandSoft`.
  - `App/DesignSystem/CYDiceGestures.swift:102`: `CYColor.accent` -> `CYColor.brand`.
  - `App/DesignSystem/CYRoamKit.swift`: player dot (`CYColor.accent` -> `CYColor.infoText`, lines `218,220`), toast (`CYColor.accentText` -> `CYColor.brand`, line `278`), pin (`CYColor.accent` -> `CYColor.actionPrimaryBg`/`brand`, `Color.white` -> `CYColor.actionPrimaryFg`, lines `310-312`), nearby card (`CYColor.accent*` -> `CYColor.brand*`/`CYRadius.lg` / clear border unless selected, lines `430-435`).
  - `App/DesignSystem/CYSharedStates.swift:93`: `CYColor.accentText` -> `CYColor.brand`.
  - `App/DesignSystem/CYSquareShareSheet.swift:62`: `CYColor.accent` -> `CYColor.actionPrimaryBg`.
- **Feature views (all `CYColor.accent*`, `CYColor.accentWarm`, `CYNight.violet`, `CYNight.selection`, and secondary label border sites)**:
  - `App/AuthChannelView.swift:147,195,210,212,247` (`CYColor.textOnAccent, CYColor.accent` -> `CYColor.actionPrimaryFg, CYColor.actionPrimaryBg`; `accent` -> `brand`; `accentSoft`/`Text` -> `brandSoft`/`brand`).
  - `App/CharacterSheetDetailView.swift:132,164,168,251,254,267,328` (`accentWarm` -> `CYColor.rare`, `accent*` -> `CYColor.brand*`).
  - `App/ClubChannelMessagingView.swift:276,483-484,494,532,618,639,707,894-895,919,1067,1080,1094-1095` (`accent*` -> `CYColor.actionPrimaryBg`/`brand`/`brandSoft`; `CYRadius.xs` -> `CYRadius.sm`).
  - `App/ClubOperationsViews.swift:1014,1049` (`CYNight.selection` -> `CYColor.selection`).
  - `App/ClubOpsGovernanceSections.swift:36` (`CYColor.accentText` -> `CYColor.brand`).
  - `App/CoopListParitySections.swift:35` (`CYColor.accentText` -> `CYColor.brand`).
  - `App/CooperationInviteActionSections.swift:67` (`CYColor.accentText` -> `CYColor.brand`).
  - `App/CreatorMaintenanceViews.swift:217` (`CYColor.accent` -> `CYColor.brand`).
  - `App/DiceD20View.swift:158` (`CYColor.accentWarm` -> `CYColor.rare`).
  - `App/GlobalSearchView.swift:443` (`Color.white` -> `CYColor.actionPrimaryFg` paired with neutral selected pill background).
  - `App/HomeCityLocationConsentCard.swift:15` (`CYColor.accent` -> `CYColor.brand`).
  - `App/MemberHomeHeader.swift:167-169,299` (`CYColor.accentSoft`/`accentText` -> `CYColor.brandSoft`/`brand`).
  - `App/MerchantMarketingHomeSections.swift:80` (`CYColor.accentText` -> `CYColor.brand`).
  - `App/MerchantPerkTemplatesView.swift:125,127` (`CYColor.accentText`/`Soft` -> `CYColor.brand`/`brandSoft`).
  - `App/NativeMotionReminderViews.swift:178` (`CYColor.accentText` -> `CYColor.brand`).
  - `App/OfficialEventComponents.swift:172,194` (`CYColor.accentText`/`accent` -> `CYColor.brand`).
  - `App/OfficialEventDetailView.swift:183` (`CYColor.accent` -> `CYColor.brand`).
  - `App/OrderCardComponents.swift:81,97` (`CYColor.accent` -> `CYColor.actionPrimaryBg`).
  - `App/OrderLifecycleView.swift:362,367,369` (`CYColor.accent` -> `CYColor.actionPrimaryBg`; `CYOrderActionSecondaryLabel` uses `CYColor.textSecondary` on `CYColor.actionSecondary` fill, removed `strokeBorder(CYColor.borderStrong)`).
  - `App/PlayInPlayTools.swift:188` (`CYColor.accent` -> `CYColor.brand`).
  - `App/PlayRouteMapView.swift:391` (`CYColor.accent` -> `CYColor.actionPrimaryBg`).
  - `App/PlayStoreDayMerchantView.swift:185,325` (`CYColor.accent` -> `CYColor.brand`).
  - `App/ProfileOrderSourceDetailSections.swift:56` (`CYColor.accent` -> `CYColor.brand`).
  - `App/ProfileParticipantsView.swift:118` (`CYColor.accent` -> `CYColor.infoText`).
  - `App/PublicCatalogViews.swift:101` (`CYColor.accent` -> `CYColor.brand`).
  - `App/SearchMapComponents.swift:83` (`CYNight.violet` -> `CYColor.actionPrimaryBg`).
  - `App/SquareCloudFeedViews.swift:554` (`CYNight.selection` -> `CYColor.successText`).
  - `App/StoryRuleEditorView.swift:443,453,544` (`CYColor.accentText`/`Soft` -> `CYColor.brand`/`brandSoft`).
  - `App/TeamReportReasonSheet.swift:91` (`CYColor.accent` -> `CYColor.brand`).
  - `App/TopicDetailView.swift:65,68,86-87,103` (`CYColor.accentText`/`Soft` -> `CYColor.brand`/`brandSoft`).
  - `App/UsageConsentGateView.swift:114` (`CYColor.accent` -> `CYColor.successText`).
  - `App/WalletCommerceViews.swift:999` (`CYColor.accent` -> `CYColor.actionPrimaryBg`).
  - `App/WelcomeView.swift:163` (`CYColor.accentPressed`/`accent` -> `CYColor.brandStrong`/`actionPrimaryBg`).

---

## 3. Contract Checks & Verification Results

- **Added Contract Check**: `Tests/ContractChecks/test_design_token_unification_contract.py`
  - Verifies `Theme+Generated.swift` source commit (`561cafd10214853e8b43128a3ffe419cf115cca2`), SHA-256 (`b7766933...`), and newly required token keys.
  - Verifies `CYDesignTokens.swift` and `Theme.swift` remove forbidden literals (`0x0F172A`, `accentRGB`, `accentWarm`, `0x18181B`, etc.), delegate colors/type/spacing/radii, and resolve every `Theme.length`/`color`/`duration` key against `Theme+Generated.swift`.
  - Fails on any retired accent symbol (`CYColor.accent*`, `CYNight.violet`, `CYNight.selection`), any `#7A5CFF` / `122.0/255` literal outside generated/tab/palette files, or any `tabSelected`, `avatarRing`, `resultSpinner` usage outside those 3 approved roles.
  - Fails on outer `.strokeBorder`, `.stroke`, `.border`, or `borderSubtle`/`borderStrong` on `CYCardSurfaceModifier`, `CYSecondaryButtonStyle`, `CYDestructiveButtonStyle`, `CYDomainCardModifier`, `CYDomainSecondaryButtonStyle`, `CYDomainDestructiveButtonStyle`, `CYPillButtonStyle`, and `CYOrderActionSecondaryLabel`.
- **Lint/Ratchet updates**:
  - `tools/check_design_lint.py`: removed retired `{VIOLET: 2}` allowlist entry for `SearchMapComponents.swift`.
  - `Tests/ContractChecks/test_accessibility_hardening_wave.py`: updated lines 58, 251 from `CYColor.accent` to `CYColor.actionPrimaryBg`.
  - `Tests/ContractChecks/test_global_search_category_recovery.py`: updated `CURRENT_VIEW_SHA256` to `2bda8668e60abbd3d94b996ca7af71cde46adf3f8507b20a8cc047d9c2af1eb0` for the single-line `Color.white -> CYColor.actionPrimaryFg` legibility update in `App/GlobalSearchView.swift:443`.
- **Verified Gate Runs** (no `xcodebuild` / `swift build` / `swift test` run on this Mac):
  - `python3 -B tools/wxss_tokens.py /tmp/tokens.wxss /tmp/tokens_inventory.json --swift App/Theme/Theme+Generated.swift --source-commit 561cafd10214853e8b43128a3ffe419cf115cca2 --check`: exit 0 (`tokens: 589, domain_values: {color: 1672, duration: 125, easing: 45, length: 704, number: 75, unsupported: 206}, diagnostics: 0`).
  - `swiftc -parse` across all modified/added `.swift` files: exit 0 (`SWIFTC_PARSE_OK`).
  - `python3 -B tools/wxss_tokens.py --self-test`: exit 0 (`Ran 10 tests in 0.002s / OK`).
  - `python3 -B tools/check_design_lint.py`: exit 0 (`PASS design lint: scanned 1633 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)`).
  - `python3 -B tools/check_a11y.py`: exit 0 (`PASS accessibility lint: 10 scoped screens, helper checked, 2 range views left, 3076 other App views not scanned`).
  - `python3 -B tools/check_scaffold.py`: exit 0 (`PASS structural checks: 4768 Swift source files, 16562 bilingual keys...`).
  - `python3 -B -m unittest Tests/ContractChecks/test_design_token_unification_contract.py Tests/ContractChecks/test_accessibility_hardening_wave.py`: exit 0 (`Ran 34 tests in 6.686s / OK`).
  - `python3 -B tools/contract_ratchet.py --check`: exit 0 (`contract ratchet: 186 failing, baseline 186, new 0, fixed 0`).
  - Pre-existing CI drift noted (not introduced by this branch): `tools/current_ci.py check` exited 1 (`ValueError: Current source or test inventory changed without manifest audit`) on base `origin/ui/main` (`5ba7b0f2c5`) due to `tools/current_ci_manifest.json` snapshot drift against `comparison_base: 5f318716e596dcd12ad2b84e83ad85046ce99f73`; left untouched per task scope.
