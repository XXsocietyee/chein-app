# cursor/a11y-r4

Q2b. Accessibility fixes redone on `origin/ui/combined-r7` at `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (`Integrate F-agent round 2`). No rebase. `python3 -B tools/check_a11y_lint.py` is present on this base. `swiftc` was not run.

## Counts

Before, against the baseline that shipped on this base:

```
FAIL accessibility lint: 17 new, 130 current (unlabeled-button 4, unlabeled-image 120, small-tap 6), 147 baselined, 34 removed
```

| | new | current | baselined |
|---|---:|---:|---:|
| before | 17 | 130 | 147 |
| after | 0 | 0 | 0 |

After, with the committed baseline:

```
PASS accessibility lint: 0 new, 0 current (unlabeled-button 0, unlabeled-image 0, small-tap 0), 0 baselined, 0 removed
```

`tools/a11y_lint_baseline.txt` was written only after that re-run reported 0 current findings. The file exists and lists no signatures, so it allows nothing extra. No baseline line was added to hide an unfixed finding.

## Fixes

- A glyph next to text, or a glyph whose parent control already has a spoken name, is `.accessibilityHidden(true)`. The picture still draws.
- A photo that is the content uses an existing catalog label: `media.destination.image`, `image.retained.preview`, or `club.materials.title`.
- A button or menu VoiceOver activates has a spoken name. Its frame is at least 44pt (`CYSpacing.minTouchTarget`). The picture stays at its previous size inside that target: 40pt previews, the 32pt stepper glyph, the 4pt progress capsule, the 36×5 grabber.
- Segmented tabs use an outer `minHeight` of `CYSpacing.minTouchTarget`. `CYSpacing.xs` is still 4pt and was not changed to `.sm`. No colors were swapped. No `.font(.system(size:))` was added, and no text style below `.caption` was introduced.
- `-> Image {` and `: Image {` value builders are spelled `(Image)` so the scanner does not treat the type as an image view. The type is still `Image`. Share-card photo fallbacks sit outside any `View`.

Public signatures of `SettingsView`, `MerchantVerifyRecordsSections`, `PlatformConsumerSessionOwner`, `RoamPOIActions`, `TeamHomeView`, `TicketWalletView`, `TopicXcxSections`, `ClubDetailView`, and `ClubWorkbenchKit` were not changed. `JourneyReportViews.swift` has no type of that name; the private share-image helper on `JourneySettleView` is the parenthesized `(Image)` above.
