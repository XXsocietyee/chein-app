# UIV-08 report: play / roam / map group (player, dark). NOT COMPILED.

Branch `cloud/uiv-08` from `origin/ui/own-1`. Presentation only; no logic, hint, skip, scoring, network or identifier changes. No new strings (no ui-strings-uiv-08.json needed).

## Screens, references
| iOS file | Mini-program page | Reference |
|---|---|---|
| RoamBrowserView.swift | pages/roam/index | chengyinhub-xcx/docs/screenshots/roam-intro-nrc.png |
| RoamLiveSessionView.swift | roam live session (pcard / pbar) | roam-intro*.png |
| SearchMapCanvas.swift | pages/searchmap/index | docs/evidence/player-e2e-20260927/015-searchmap.png (not present in checkout) |
| PlayExperienceView.swift | pages/play/index | page-polish-20261102/preview/shots (not present in checkout) |
| PlaySessionView.swift | pages/play/index (overview list) | as above |
| SessionPlayRuntimeView.swift | host only | no visual change needed |

## Diffs fixed
- Raw system colours (`.orange`, `Color.green`, `Color.secondary`, `.tint`, `Color.accentColor`) replaced by `CYColor` status/text tokens (accent ring on the live HUD removed: no accent outside the selected tab).
- Spinner-only loading (`ProgressView`) replaced by `CYSkeleton` in PlaySessionView, PlayExperienceView, RoamBrowserView, RoamLiveSessionView (same accessibility identifiers kept).
- One primary action: run pause/resume and roam start/pause/resume use `.cyPrimary`; map is `.cySecondary`; end/finish is `.cyDestructive` (still behind the existing confirmation dialogs).
- Fonts moved to `CYTypography` (clock = dataXL tabular, titles, rows); numerals `.monospacedDigit()`.
- Page backgrounds: lists use `scrollContentBackground(.hidden)` + `CYColor.bgPage`.
- Map: card radius `CYRadius.lg` + hairline border (SearchMapCanvas), roam inline map min height 280, clipped, inset 16.
- Live HUD and bottom bar use `.ultraThinMaterial` glass with hairline border; bar paddings from `CYSpacing`.

## Diffs left (UIV-TODO, deliberately not done: needs compile/screenshots)
- Full-bleed map with floating glass round controls and a detent bottom sheet (mini-program roam home: map + GO button + info/map circles). RoamBrowserView is still a List with the map as a row; converting to ZStack map + `.presentationDetents` sheet changes navigation/sheet ownership and was too risky uncompiled.
- RoamLiveSessionView is still a List below the HUD; the sheet-style layout is the same follow-up.
- Reduce Transparency solid fallback for the glass surfaces.
- Dynamic Type AX3 check of the run/pause HStacks (may need vertical layout via ViewThatFits).
- Remaining `.font(.headline/.caption)` and `.secondary` in nested helper views of these files.

## Compile risks
- `.buttonStyle(.cyDestructive)` / `.cySecondary(fullWidth:)` rely on extensions in App/DesignSystem/CYDesignComponents.swift (verified present).
- `CYSkeleton` has its own accessibility label key `accountCollection.loading`.
