# i18n r1 — layout lane receipt (2026-11-27)

Branch `i18n/r1-layout`, based on `origin/ui/combined-r7` @ `fc95e6a19`. Scope: player and club code (App/, App/NativeR2/, App/MPGap/; merchant, DesignFixtures and NativeGallery excluded), widgets and Live Activities. Brief: `docs/briefs/i18n-r1.md` (layout row).

**No compiler in the cloud.** Every API used is a stock SwiftUI API already in use in this repo (`ViewThatFits`, `@ScaledMetric`, `dynamicTypeSize.isAccessibilitySize`, `.fixedSize(horizontal:vertical:)`, `.lineLimit`, `.minimumScaleFactor`). The coordinator's `build_sim` is the first compile of this branch.

## Shared helpers (new): `App/DesignSystem/CYLanguageProofLayout.swift`

| Helper | What it does |
|---|---|
| `.cyAdaptiveSegmented()` (`CYAdaptiveSegmentedPickerStyle`) | Replaces `.pickerStyle(.segmented)`. `ViewThatFits(in: .horizontal)` keeps the segmented control while every segment's title fits at its ideal width, otherwise uses the system menu picker. Always menu at accessibility text sizes. |
| `CYAdaptiveButtonRow` | Equal-width action buttons side by side while the titles fit on one line each, stacked otherwise (and always at accessibility sizes). |
| `CYAdaptiveLabelValueRow` | Label + value in one row when both fit, label above value otherwise. Added for the next rounds; not yet adopted. |

## Changes

### Segmented controls — 86 call sites in 70 files
Every `.pickerStyle(.segmented)` in player/club code and the design system (`CYTabs.swift:184`, `CYShareComposer.swift:135`) now reads `.cyAdaptiveSegmented()`. Before: 88 in scope. After: 2 left on purpose: `NearbyTeamMapViews.swift:33` (compact list/map toggle with `.fixedSize()`) and `WorkshopPaidInstalledTextView.swift:71` (byte-pinned protected consumer delivery, `test_workshop_protected_text_lifecycle.py`; owner to decide whether to re-pin).
Pinned contract tests updated in the same commit: `test_account_collection_structure.py:102`, `test_pkg03_favorites_closure.py:56`, `test_w2_04_participation.py:22`, `test_club_story_navigation.py:13`. Hash pins re-pinned with a note (presentation-only change): `test_club_leaderboard_member_navigation.py` (customers span of `ClubGovernanceViews.swift`, was `af3b69eb`) and `test_coop_fixture_lifecycle_diagnostic.py` (`CoopRelationDiscoveryView.swift`, was `550a2553`).
UI tests that query `app.segmentedControls[...]` still find a segmented control at the default text size as long as the titles fit (all the tested pickers have 2–4 short titles in a 390–430 pt window).

### Text clamped to one line / fixed widths around localized text
| File:line | Before | After |
|---|---|---|
| `App/ClubComponents.swift:81` (club row status) | `lineLimit(1)`; en "Waiting for the host to approve" truncated | `lineLimit(2)`, trailing alignment, vertical `fixedSize` |
| `App/ProfileInviteHistoryIssueView.swift:77` | nickname · "First-purchase reward received" `lineLimit(1)` | `lineLimit(2)` + vertical `fixedSize` |
| `App/NativeR2/MapHome/RoamMapHomePlaceCard.swift:201` | action-button captions `lineLimit(1)` in three equal columns | `lineLimit(2)`, centred, vertical `fixedSize` |
| `App/NativeR2/Components/CYStatPill.swift:34` | titled HUD pill truncated value or title | `ViewThatFits`: titled pill, else value-only pill (VoiceOver label unchanged); value `.fixedSize()` |
| `App/InGameChannelEntryViews.swift:211` | channel hint key `lineLimit(1)` | `lineLimit(2)` + vertical `fixedSize` |
| `App/NativeR2/CityOrientation/CityOrientationRunView.swift:278` | "To 3 · {stop}" `lineLimit(1)` | `lineLimit(2)` + vertical `fixedSize` |
| `App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift:40` | rank column `frame(width: 40)` clipped "#100" at large sizes | `.fixedSize().frame(minWidth: 40)` |
| `App/SquareXcxPostCard.swift:174` | upcoming card `frame(width: 240)` | `@ScaledMetric(relativeTo: .headline) cardWidth = 240` |
| `App/RoamNearbyParityExtras.swift:264, 307` | quote/review cards `frame(width: 240/220)` | `@ScaledMetric` widths |
| `App/RoamCityGuide.swift:106` | city-guide card `frame(width: 240)` | `@ScaledMetric(relativeTo: .subheadline)` width |

### Button rows
`CYAdaptiveButtonRow` replaces the `HStack` in: `App/MPGap/PlayerContent/PlayerContentRound4Views.swift:378` ("Add to ticket wallet" / "Start game"), `App/MPGap/PlayerContent/TopicTemplateDeckPreviewView.swift:73` ("View Details" / "Use Template"), `App/NativeR2/Games/CameraKits.swift:79` ("Take a photo" / "Choose a photo").

### Widgets and Live Activities
| File:line | Change |
|---|---|
| `LiveActivityWidget/QuestLiveActivityWidget.swift` header | kind title ("Orientation run", "Free explore") `lineLimit(2)` in the narrow expanded-leading region |
| `QuestLiveActivityMetric` | label `lineLimit(2)` (e.g. "To next stop"); value one line, `minimumScaleFactor(0.8)` (numbers only) |
| compact trailing slot | distance / clue fraction `lineLimit(1)`, `minimumScaleFactor(0.8)`, `maxWidth: 52` like the timers, so "0.3 mi" never clips |
| run extras | "Time left" label `lineLimit(2)` |
| `LiveActivityWidget/QuestBoardWidgets.swift:269` | "Open my activities" `lineLimit(2)` in the small event widget |
| streak widget | "days in a row" and "%1$lld of the last %2$lld days" wrap to two lines |

## Counts (scanner: localized `Text`/`Label`/`Button` with `lineLimit(1)` and no `minimumScaleFactor`/`truncationMode`, in scope)
- Before 9, after 5. The 5 left are intentional: `SquareXcxPostCard.swift:51` (relative time, `fixedSize`), `NR2StoryReaderParts.swift:198` ("Audio"), `CYStatPill.swift` title (now has the value-only fallback), `QuestBoardWidgets.swift:660` ("My city") and `:725` tile titles ("Unread", "This week", "Revealed", "Stamps").
- `.pickerStyle(.segmented)` in scope: 88 → 2 (see above).
- Fixed `frame(width:)` around localized text: 4 card widths now scale; the rest found by the scan are icons, avatars, hidden 0×0 hosts or a share-image render (`ChoiceKits.swift:210`, fixed on purpose).

## Gates
- `python3 tools/check_scaffold.py`: PASS structural checks (5231 Swift sources, 19770 bilingual keys).
- `python3 tools/check_a11y_lint.py`: PASS, 0 new.
- `python3 tools/contract_ratchet.py --check`: 104 failing, baseline 104, new 0, fixed 0.

## Not done / for the owner or another lane
- `widget.community.inline` ("%1$lld unread · %2$lld club posts") in the accessory-inline family can truncate on small watches/lock screens. A shorter fallback needs a new catalog key (strings lane).
- `CYTicketPass` diagonal ribbon keeps its fixed 168×24 band with `minimumScaleFactor(0.7)` (it is a badge and already falls back to a chip at accessibility sizes). If the uppercase English state text still reads too small on device, the design owner should pick shorter English state words.
- Hard-coded Chinese in internal diagnostics views (`SevenDayLaunchCriticalPathSectionView`, `PublishTopicAndCommentModerationSectionView`) is left to the strings lane.
- Needs a device/simulator pass at `.xxxLarge` and an accessibility size in English to confirm the `ViewThatFits` choices (segmented vs menu) look right on 375 pt screens.
