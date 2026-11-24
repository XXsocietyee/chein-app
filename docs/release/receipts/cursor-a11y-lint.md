# cursor/a11y-lint

K9. Static accessibility lint for SwiftUI `Button` and `Image` values. Cut from `origin/ui/combined-r7` at `97ee2bc9e73c00cd0cf8b8aa06aaa728cbac25c8`. No `App/` screens were edited. The acceptance workflow is not on this branch and was not copied.

## Gates step

```
python3 -B tools/check_a11y_lint.py
```

`tools/check_a11y_lint.py` scans `App/**/*.swift`. It flags only what the source proves:

- A `Button` with no `.accessibilityLabel`, no accessibility representation, and no visible text VoiceOver would speak. `pageTemplateControl(label:)` counts, because it applies `.accessibilityLabel`. A custom view (`commerceText(...)`, `CustomIcon()`, `backGlyph`) is not flagged: its label is not visible here.
- An `Image` VoiceOver can land on, with none of those, and not `Image(decorative:)` or `.accessibilityHidden(true)`. Images inside a labeled `Button` / `Label` / `Menu` / `Link` are not separate elements. An image passed into `ShareLink` or `SharePreview` is not an element. `overlay(Image(...))` / `background(Image(...))` / `mask(Image(...))` still are.
- A tap target (`Button`, `NavigationLink`, `Link`, `Menu`, `ShareLink`, or a view with `onTapGesture` / `TapGesture`) whose own `frame` declares a width or height under 44pt. `CYSpacing.minTouchTarget`, `Theme.MiniProgramChrome.minHit`, and `CurA11y.hit` are 44. System controls whose hit target is not in this source (`Toggle`, `Slider`, `Picker`, `TextField`, `EditButton`, …) are not flagged.

If `tools/a11y_lint_baseline.txt` is absent the script prints

```
SKIP accessibility lint: tools/a11y_lint_baseline.txt is absent; exiting 0 so a gates job can run before the baseline is merged
```

and exits 0. Once the baseline is present, a signature that appears more often than it does in the baseline fails. Fixing a finding (its signature disappears) passes. `--write-baseline` refuses to add signatures, so the baseline cannot be raised to hide a new violation. The file in this commit is the first baseline: the current tree, 147 findings.

## Run

```
SELF-TEST PASS: 51 case(s)
PASS accessibility lint: 0 new, 147 current (unlabeled-button 4, unlabeled-image 137, small-tap 6), 147 baselined, 0 removed
```

## Worst unlabeled controls

For the F-agents who own `App/` screens. Not fixed here.

### Buttons with no spoken name (4)

| Location | What VoiceOver gets |
|---|---|
| `App/ClubPostImagePicker.swift:306` | 40×40 preview of an uploaded image. `Button` opens the preview. No label. Also a small tap. |
| `App/ClubPostImagePicker.swift:352` | Same for a local candidate image. No label. Also a small tap. |
| `App/DesignSystem/CYBusinessComponents.swift:1011` | `stepperButton(symbol:)`. The glyph is 32pt inside a 44pt frame, so the hit size is fine, but plus and minus are the same unlabeled `Image(systemName: symbol)`. |
| `App/MPGap/PlayerContent/SearchMapExplorerGapView.swift:54` | Map pin `Button` whose label is only `mappin.circle.fill`. The `Annotation` title is `place.title`; the button does not speak it. |

### Tap targets declared under 44pt (6)

| Location | Declared size | Name |
|---|---|---|
| `App/TemplatePlayerPreviewPager.swift:58` | `minHeight` 22 (`CYSpacing.minTouchTarget / 2`) | Progress segment. Has `.accessibilityLabel`. |
| `App/CityKit/CityPropertySheet.swift:443` | width 36, `minHeight` 24 | Deed sheet grabber. Has `.accessibilityLabel`. |
| `App/CityKit/CityRoamRootView.swift:438` | width 36, `minHeight` 24 | Nearby-list grabber. Has `.accessibilityLabel`. |
| `App/DesignSystem/CYTabs.swift:261` | `minHeight` 38 (`CYSpacing.minTouchTarget - 6`) | Segmented tab. The label text is visible. |
| `App/ClubPostImagePicker.swift:306` | 40×40 | See the button row above. |
| `App/ClubPostImagePicker.swift:352` | 40×40 | See the button row above. |

### Images VoiceOver can land on (137)

Most are SF Symbols or photos next to text that was not combined or hidden, so VoiceOver focuses the image on its own. The worst ones that behave like controls:

| Location | Symbol | Note |
|---|---|---|
| `App/MPGap/PlayerContent/PlayerContentRound2Views.swift:215` | `plus.circle` | `Menu` label. No `.accessibilityLabel`. The menu rows have titles; the button that opens the menu does not. |
| `App/WalletCommerceFixtureHost.swift:126` | `ellipsis.circle` | `Menu` label in the commerce fixture. No label. |
| `App/ClubComponents.swift:369` | `play.fill` | 52pt play glyph on `E3VideoCard`. No label. |
| `App/DesignSystem/CYDesignComponents.swift:270` | `ellipsis` | `CYButtonSpinner` under Reduce Motion. No label. |
| `App/DesignSystem/CYChromeBars.swift:161` and `:169` | `chevron.left` | `backGlyph` has no label of its own. The bar at line 113 wraps it in a `Button` that already has `pageTemplateControl(label: Text("action.back"))`. The glyph is another function, so this lint cannot see that label. Hiding the glyph is the local fix. |
| `App/JourneyLandingViews.swift:692` | `plus` | Open-seat glyph inside `seatCircle`. The `Group` at line 676 sets the seat label. The image is in another function, so this lint cannot see that label. |
| `App/DesignFixtures/E3Fixtures.swift:268` | `plus` | Fixture composer control, 44×44, no label. The send arrow on the next lines is unlabeled too. |

The rest of the 137 images are in `tools/a11y_lint_baseline.txt` (row icons, gallery photos, status marks). A new one fails the check. Deleting a baseline line to silence a finding also fails: that signature becomes new, and `--write-baseline` will not put it back.
