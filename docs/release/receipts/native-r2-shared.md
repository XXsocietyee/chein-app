# Receipt: native-r2 / shared components

Branch `native-r2/shared`, cut from `origin/ui/combined-r7` (contains `82bcf2c2d`, "native r2 tokens").
Brief: `docs/briefs/native-r2.md` (component rule, "EVERYTHING native", gates).

Scope: only `App/DesignSystem/*.swift`. I did not touch `CYDomainPalette.swift`, `CYDesignTokens.swift` or `App/Theme/*`
(coordinator-owned). No call site outside `App/DesignSystem` was edited. Every public/internal init, method, static
helper and modifier signature is unchanged, so existing call sites keep compiling. Token read-back helpers that unit
tests call (`CYPillButtonStyle.tokens`, `CYStatusChip.tokens`, `CYFilterChip.tokens`, `CYField.tokens`,
`CYListRowTokens.resolve`, `CYButtonTokens.resolve`, `CYCardSurfaceModifier.backgroundColor`) are kept as they were;
the views no longer read them.

`accessibilityIdentifier`s are kept wherever the component set one (`permission.priming.allow/notNow`,
`confirm.consequences`, the optional `titleIdentifier` / `confirmIdentifier` / `cancelIdentifier` /
`messageIdentifier` / `actionIdentifier` / `primaryIdentifier` paths).

## What each component renders now

| Component (file) | Now renders |
|---|---|
| `CYPillButton` (CYPillButton.swift) | `Button` + `.buttonStyle(.borderedProminent / .bordered / .borderless)` for primary / secondary / tertiary, `.controlSize(.large)`, system tint and label colour. Title is `Text`, or `Label` when `systemImage` is set. `fullWidth` keeps `.frame(maxWidth: .infinity)` on the label. `size`/`compact` are accepted and ignored (both are `.large`). |
| `CYNativeButtonChrome` | Only the system button style + `.controlSize(.large)`. No `.tint`, `.foregroundStyle`, capsule shape or `minHeight`. |
| `CYPillButtonStyle` | Has to stay a `ButtonStyle` (used through `AnyButtonStyle` in PublishingManagementViews and `extension ButtonStyle where Self == CYPillButtonStyle` in EditorKitFoundation). `makeBody` hosts the label in a real system `Button` of the matching style (role kept), with hit testing off so the outer button takes the tap; the press dim follows `isPressed`. |
| `CYPrimary/Secondary/Ghost/DestructiveButtonStyle`, `CYButton` (CYDesignComponents.swift) | Same host (`CYSystemButtonHost`): `.borderedProminent` / `.bordered` / `.borderless` / `.borderedProminent` + destructive role + `.tint(.red)`. `md` → `.large`, `sm` → `.regular`, `xs` → `.small`. `isLoading` shows `ProgressView()` over a hidden label. |
| `CYButtonSpinner` | `ProgressView()`. |
| `CYEmptyState`, `CYErrorState`, `CYEmptyStateView`, `CYErrorStateView`, `CYContentState`, `CYStateLayout` (CYStates / CYStateKit / CYDesignComponents) | `ContentUnavailableView` with the SF Symbol in the system colour (the MP empty illustrations via `MPAsset` stay, as the brief allows). Actions are `CYStateActionButton`: system bordered styles, `.controlSize(.large)`, no fixed heights. |
| `CYStateArt` | The MP illustration (`MPAsset`) when one exists, otherwise a plain `.largeTitle` SF Symbol in `.secondary`. The fanned cards, radial glow, sparkles and float animation are gone. |
| `CYLoadingStateView` (CYSharedStates.swift) | `ProgressView()` centred, one VoiceOver label (`cy.state.loading`). `rows` is accepted and ignored. |
| `CYLoadingState` (CYStates.swift) | Unchanged structure; its `CYSkeleton` is now the redacted placeholder below. |
| `CYSkeleton` (CYSkeleton.swift) | Plain `Text` / `Label` / `LabeledContent` rows with `.redacted(reason: .placeholder)`, shaped per variant (row, 2 rows for card / feed / map / detail, 3 `LabeledContent` for metrics, 3 `Label`s for the route timeline, 2 `LabeledContent` for form / ticket). No drawn bars, card chrome or pulse. |
| `CYSkeletonBlock` | One redacted placeholder `Text` line (`.headline` / `.body` / `.footnote` by the requested height). |
| `CYListRow` (CYListRow.swift) | `LabeledContent` whose label is a `Label` (title + `.subheadline` `.secondary` meta; icon = the leading view) and whose content is the trailing value (`.monospacedDigit()`). Chevron = `chevron.right` in `.tertiary`. `danger` → system red; disabled → 0.4 opacity. `card: true` → `cyDomainCard`. No custom row height, hairline, pressed fill or press tracking. `rowPressed` / `rowDivider` accepted and ignored (the List draws highlight and separators). |
| `CYListRowButtonStyle` | The label with a plain-button press dim; no fill. |
| `CYRowIcon` | The SF Symbol in `.tint`, no tile. |
| `CYFactRow` (CYCityKit.swift) | `LabeledContent { value } label: { label }`, value selectable. |
| `CYNoteBanner` | `Label(text, systemImage: symbol)` (default `info.circle`), `.footnote`, `.secondary`. No box. |
| `CYInfoCard` | `.headline` `Label` header (symbol in `.tint` or the caller's tint) over the content, on `cyDomainCard`. |
| `CYDetailsDisclosure`, `CYCollapsibleCard` | System `DisclosureGroup` (label = `Text` / `Label`). |
| `CYStepIndicator` | `ProgressView(value:total:)` with the current step title as label and "Step n of m" as `currentValueLabel`. |
| `CYCardPage` | `ScrollView` on `systemGroupedBackground`. |
| `CYCollectedLockedSummary` | Two `LabeledContent` lines (`Label` + count). |
| `CYChoiceRow` | Borderless button row: text, `checkmark` in `.tint` when selected (multi: `checkmark.circle.fill` / `circle`). |
| `cyField()` | `.textFieldStyle(.roundedBorder)`. |
| `CYTimelineItem` | Status SF Symbol (tint or `.secondary`) + content. The drawn rail is gone. |
| `CYSectionHeader` (CYDesignComponents.swift) | Plain `.headline` header text (`.isHeader`), optional `.footnote` `.secondary` subtitle, borderless trailing action (no chevron, no brand colour). |
| `CYCardSurfaceModifier` / `cyCardSurface` / `cyCard` / `CYCard` | `secondarySystemGroupedBackground` in `CYRadius.card`, no shadow, no variant tint. Increase Contrast adds a `separator` edge. |
| `cyAlbumCard`, `cyLookCard` (no look) | `cyCardSurface`. `cyLookCard` with a creator look keeps the look's card colour but drops the glass, gradient and shadow. |
| `cyNightCardDepth` | No-op. |
| `cyMiniListScreen`, `cyGroupedSurface` | No-op (system grouped background). `cyMiniCardRow` → `secondarySystemGroupedBackground` row. `cyDocumentSurface` → `systemBackground`. |
| `CYStatusChip` (CYStatusChip.swift) | `.footnote` `Text`, or a `Label` when a symbol is given. Neutral → `.secondary`; success / warning / danger / info / rare → system green / orange / red / blue / indigo (purple is reserved by the purple-restraint contract). Selected → semibold. No capsule. |
| `CYStatusTag` | Uses `CYStatusChip`, so the same. |
| `CYCountBadge` | System badge look: `.caption` semibold white digits on a system-red capsule. |
| `CYFilterChip`, `CYChipRow` (CYChipRow.swift) | Capsule system buttons: `.borderedProminent` when selected, `.bordered` otherwise (the Apple Maps filter-chip pattern). The right-edge fade gradient is removed. |
| `CYTabs` (CYTabs.swift) | `Picker(.segmented)` for up to 5 items in any variant except `.chip`; `.chip` or more than 5 items → the `CYFilterChip` row. Badges are shown as "Title n". |
| `CYProgressBar` (CYBusinessComponents.swift) | `ProgressView(value:total:)` labelled with a `LabeledContent` (title, "n / m"); a failed load shows `CYInlineError`. |
| `CYHeroHeader` (CYHeroHeader.swift) | Optional illustration, then a plain `.title` bold title and a `.body` `.secondary` subtitle. `cyHeroScreen()` is unchanged. |
| `CYHeroBanner` (CYHeroBanner.swift) | Page-style `TabView` with system page dots. Each page shows the cover (`AsyncImage`, HTTPS only) in `CYRadius.card`, or a `secondarySystemFill` with a `photo` symbol, then the optional title and subtitle as plain text below. No gradients, scrim, shadow, parallax or scale. |
| `CYField` (CYField.swift) | `.subheadline` `.secondary` label (" *" when required), a system `TextField` with `.roundedBorder` (multiline = `axis: .vertical`, `lineLimit(3...8)`), and a `.footnote` footer (red for errors). No custom box, border, placeholder colour, success icon or counter. `maxLength` is still enforced. |
| `CYConfirmSheet` (CYConfirmSheet.swift) | Callers present this view in their own `.sheet`, so it can't become `.confirmationDialog` without touching call sites. Inside the sheet: a `Form` with a `.headline` title, a `.body` `.secondary` message and the consequences as `Label` rows; confirm is `.borderedProminent` (red tint when destructive) and cancel is `.bordered`, both `.large`; `.presentationDetents([.medium, .large])` and a drag indicator. The join-reward seal and burst are replaced by `.sensoryFeedback(.success)`, and `onConfirm` now runs immediately instead of after the 720 ms animation. |
| `CYOfflineBanner`, `CYOfflineStrip` | `Label("…", systemImage: "wifi.slash")` `.footnote` `.secondary` + borderless retry. No tinted fill or capsule. |
| `CYInlineError` | `Label(exclamationmark.circle)` `.footnote` in system red + borderless retry. No tinted box. |
| `CYToastPill` | Kept as a toast because Apple has no toast control (the closest is the "Copied" HUD). It is a capsule on `secondarySystemBackground` with system-coloured tone icons and a borderless undo. The shadow is gone. |
| `CYPermissionPriming` | System fonts and colours (`.title2` bold, `.body` `.secondary`) on `systemBackground`, `CYStateArt` symbol, system buttons. |
| `CYPermissionDeniedCard` | `ContentUnavailableView` (`location.slash` / `camera`) with an "Open Settings" bordered button. |
| `CYGlassLabel`, `CYGlassButton`, `CYGlassCapsule` (CYMapChrome.swift) | SF Symbol in `.tint` on a plain `systemBackground` circle / capsule. No material, stroke, or fixed black and white. |
| `cyNightGlass` (CYNightGlass.swift) | `secondarySystemBackground` in the shape. No material, gradient edge or shadow. |

## Decorative effects made no-ops (content shows as is)

| Effect | Now |
|---|---|
| `CYBurst` (particles, confetti style) | `EmptyView()` |
| `CYConfettiBurst` (CYSignature.swift) | `EmptyView()` |
| `CYStarBloom` (bloom, orbit stars) | `EmptyView()`. The static timing helpers (`landScale`, `silhouetteOpacity`, …) are kept for callers. |
| `CYEdgeGlow`, `.cyEdgeGlow(trigger:color:)` | `EmptyView()`; the modifier returns `self` |
| `.cyFoil(...)` (holographic sheen + gyro tilt) | Returns the content unchanged |
| `CYFogLayer` (map fog vignette, CYRoamKit.swift) | `EmptyView()`. Coverage logic in Core is untouched. |
| `CYGlassSliver`, `CYGlassGroup`, `CYCarouselBackdrop` (CYGlassCarousel.swift) | Nothing / passthrough / `Color.clear` |

## Not done in this lane (follow-ups)
- `CYDomainCardModifier` / `cyDomainCard` / `cyDomainPageBackground` / `CYDomainPrimaryButtonStyle` live in
  `CYDomainPalette.swift`, which the coordinator owns. `cyDomainCard` already has no shadow after r1. For full parity
  it should fill `secondarySystemGroupedBackground` and drop the dark-mode top highlight.
- These DesignSystem files still have bespoke drawing that this pass did not reach: `CYOnboarding*` (wave shader,
  `FogWindow`, `AvatarOrbit`), `CYBadgeCraft`, `CYCollectible`, `CYShareCard`, `CYPassVerified`, `CYMedalStack`,
  `CYTicketPass`, `CYStampContinuity`, `CYGoHold`, `CYCoverArt`, `CYCelebrationViews`, `CYMorphButton`
  (`CYMorphOrbitDots`), `CYScan` (`CYOrbitDots`), `CYWave` (press ripple), `CYTilt`, `CYDomainTabBar` /
  `CYNightTabBar` (custom tab bars; the brief says to use `TabView`, and that change belongs at the shell's call
  site), `CYSheetModal`, and `CYPlayerKit` (`CYSheetHeader`, `CYResizableSheet`, `CYHoldToStartButton`,
  `CYLevelUpMoment`).
- `CYConfirmSheet` → `.confirmationDialog` needs call-site changes in each flow lane.

## Gates
- `python3 tools/check_scaffold.py` → `PASS structural checks` on every commit. The typography lint flagged one
  `.caption2` and I fixed it.
- No compiler in the cloud, so I grepped every SwiftUI API used against Apple's API (iOS 17 target, `Package.swift`
  `.iOS(.v17)`), and most also against existing in-repo usage: `ContentUnavailableView`, `LabeledContent`,
  `ProgressView(value:total:label:currentValueLabel:)`, `.redacted(reason:)`, `ViewThatFits`,
  `TextField(_:text:prompt:axis:)`, `.lineLimit(3...8)`, `Picker(selection:content:label:)` + `.pickerStyle(.segmented)`,
  `.tabViewStyle(.page(indexDisplayMode:))` + `.indexViewStyle(.page(backgroundDisplayMode:))`,
  `ButtonStyleConfiguration.role`, `ControlSize`, `.buttonBorderShape(.capsule)`, `.sensoryFeedback(.success, trigger:)`,
  `.fontWeight(_:)`, `.background(_:in:)`, `Color(uiColor:)` with `.secondarySystemGroupedBackground` / `.systemBackground` /
  `.secondarySystemBackground` / `.secondarySystemFill` / `.separator`.
- No new string keys: all copy reuses existing keys or verbatim strings already in the files.
- Contract checks (`python3 -m unittest discover -s Tests/ContractChecks`): see the section below.
