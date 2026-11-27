# native-a · round 3 receipt (2026-11-27)

Branch `native/r3-a` from `origin/ui/combined-r7`. Scope: player surfaces in `App/` files A–L (skipped `Merchant*`,
`*Fixture*`, `*Diagnostics*`, `*SectionView`; no story-flow theme work, no deploy).

## Starting point (scan of 422 A–L files)

Earlier native rounds had already done most of the brief's list, so this round went after what was left:

- `.font(.system(size:))`: **0** left. Everything goes through `.cyText(_:)`, which maps to text styles + `@ScaledMetric`, so Dynamic Type already works.
- `Color(red:…)`: 6 left, all procedural art (see "Kept on purpose").
- Custom segmented controls / search fields: none left. `ClubDetailTabBar` is already `Picker(.segmented)`, the search screens use `.searchable`, and the one in-Form keyword field (`ActivityTemplateSelectionView.swift:111`) is a documented exception (a `.searchable` covers a whole page, not one section).
- Empty states: already `ContentUnavailableView` (`ClubEmptyState`, `ClubTabEmptyState`, `ClubStoryEmptyState`, `ClubMPEmptyState`), except the editor kit state view (fixed below).
- Card surface tokens (`CYColor.bgElevated` etc.) resolve to the system grouped-background colours (`CYDomainPalette.native(.secondaryGroupedBackground…)`), so they are already semantic system colours.

## Replaced patterns (file:line on `native/r3-a`)

### Wrapper button styles → system `.borderedProminent` / `.bordered` / `.borderless`
The wrappers (`.cyPrimary`, `.cySecondary`, `CYPillButtonStyle`, `.editorPrimary`, `.editorSecondary`, `CYDestructiveButtonStyle`, `E3PressStyle`) put a fake inner `Button` inside a `ButtonStyle` and copied the press state with opacity. The call sites now use the system style directly, so the system draws press, disabled, role and Dynamic Type. Full-width buttons use `.controlSize(.large)` and a `.frame(maxWidth: .infinity)` label.
- `CatalogShareCardView.swift:89`: share card ShareLink, `.borderedProminent` (also dropped its custom font and 56 pt min height)
- `CityAcquisitionView.swift:209`: pay confirm `role: .destructive` + `.borderedProminent`. The role makes it red, which replaces `CYDestructiveButtonStyle`.
- `CityPlayerValuePanel.swift:39`: bind
- `CooperationContextualViews.swift:669`: review invite
- `ExternalGameImportView.swift:254` (run, `.bordered`), `:477` (confirm install, `.borderedProminent`)
- `GameplayPresetSection.swift:78`: create draft
- `HostTipViews.swift:185`: amount shortcuts, `.bordered`
- `JourneyLandingViews.swift:876`: seats invite send
- `JourneyNarrativeView.swift:96`: ask, `.bordered`
- `JourneyReportViews.swift:1353`: share
- `JourneyRoleViewSection.swift:29, 46, 60` (open / refresh, `.borderedProminent`), `:65` (close, `.borderless`)
- `EditorKitCards.swift:289`: editor footer primary (the spinner is now a plain `ProgressView` inside the system label)
- `EditorKitResults.swift:54, 59`: result sheet primary / secondary
- `EditorKitResults.swift:273`: gameplay "try preview", `.bordered`
- `EditorKitFoundation.swift:95`: removed the `editorPrimary` / `editorSecondary` statics (no callers left)
- `ClubComponents.swift:178–180`: `E3FollowButton`. Follow is `.borderedProminent`; following / requested / mutual is `.bordered`; the system `.capsule` shape replaces the hand-drawn black pill and outline.
- `ClubComponents.swift:435`: post like heart, `.borderless`. `E3PressStyle` stays defined only for the DEBUG design fixtures.

### Custom chips → system capsule buttons
- `EditorKitResults.swift:298–300`: gameplay category filter chips. Selected is `.borderedProminent`, the rest `.bordered`, with `.buttonBorderShape(.capsule)`. The "holds the pick" dot is kept.
- `EditorKitFeedback.swift:137–139`: `EditorToolChip`. Added is `.borderedProminent`, available / blocked is `.bordered`. A blocked chip keeps its popover and shows a secondary label.

### Empty state → `ContentUnavailableView`
- `EditorKitResults.swift:129`: `EditorStateView` empty / error / signed-out / no-permission. It was a hand-drawn 64 pt icon tile plus a text stack; it is now the system view with the same copy and the same single `.bordered` action.

### Hand-drawn sheet header → system navigation bar
- `EditorKitSheet.swift:111–122`: `EditorSheetPage`. The hidden nav bar, drawn grabber, round ✕ and black Done pill are replaced by:
  - an inline `navigationTitle`, with the eyebrow in the `.principal` slot;
  - ✕ as a `.cancellationAction` (it still asks 放弃修改？ when the page is dirty);
  - 完成 / Done as a `.confirmationAction`, keeping `editorKit.sheet.done` for the UI tests;
  - the system back button on pushed sub-pages.
- `EditorKitSheet.swift:205`: the system drag indicator on resizable families. The `fit` detent adds a `@ScaledMetric` 56 pt allowance for the bar.

### Decorative gradient / custom shadow → system background or material
- `E1TicketCard.swift:37`: the pass sits on `.background(.background.secondary)`. The white gloss `LinearGradient` line and the two custom black `.shadow`s are gone; the notches, foil edge and image scrim stay (P20).
- `ClubComponents.swift:350, 356`: video card play disc and duration pill use a dark `.ultraThinMaterial` instead of a hand-tinted black.
- `E1CommerceComponents.swift:105`: `E1GlassChip` uses only a dark `.ultraThinMaterial` (the extra black 42% layer is gone).
- `EditorKitFeedback.swift:45`: editor toast is a `.regularMaterial` HUD capsule with a primary label and an accent `.borderless` Undo, instead of an inverted black/white pill.

### P10: visible status words instead of a bare spinner
These were `ProgressView()` with the words only in `.accessibilityLabel`, so sighted users saw a bare spinner. They are now `ProgressView { Text(key) }` with the same existing key (en + zh-Hans already in the catalog):
- `AccountCollectionCouponsView.swift:52`, `AccountCollectionFavoritesView.swift:97, 291` (accountCollection.loading)
- `AccountComplianceViews.swift:837` (compliance.loading)
- `ActivityDetailView.swift:348` (activity.loading)
- `ClubActivityReportView.swift:154`, `ClubContextualViews.swift:100`, `ClubDetailR8Mounts.swift:423`, `ClubReadScreen.swift:52`, `ClubStatsOverviewView.swift:102` (club.loading)
- `ClubChatEntryView.swift:78` (club.chat.loading)
- `ClubCommunityViews.swift:339, 393, 816, 1125, 1222` (club.community.loading)
- `ClubEditionsShareSection.swift:26` (club.editions.loading)
- `ClubManagementView.swift:68, 426` (club.management.loading)
- `ClubPersonalFundsStagesSection.swift:17` (wallet.loading)
- `DiscoveryTemplateBrowserView.swift:335`, `DiscoveryTemplateBrowserView+Port.swift:70`, `DiscoveryTemplateDetailView.swift:69, 368, 434` (discovery.loading), `:875` (discovery.topicPreview.loading)

## Kept on purpose (not "decorative")
- `DiceD20View.swift:103–118` `Color(red:)`: per-face shading of the rendered 3D d20 (game art).
- `FogOverlayLayer.swift:35` and its gradients: procedural fog-of-war map rendering.
- `E1CommerceComponents.swift:46–70` gradients: generated cover-art placeholders (content, not chrome).
- `E1ActivityDetailParts.swift:57`, `E1TicketCard.swift:59`: legibility scrims over cover images.
- `ConfigR4Kit.swift:121` shadow: drag-lift feedback while reordering.
- `JourneyReportViews.swift:1306` and the `CYNight` journey surfaces: share-card art and the journey night look. Left alone because the story-flow theme is on hold.
- `ClubEventCalendarView` / `ClubComponents` month grids: there is no system month grid with per-day event dots.

## Not done
- `GlobalSearchView.swift:112` loading spinner: contract tests pin that block byte-for-byte, and search is the polish-search lane's area.
- `CouponManagementView`, `ClubTerminalSessionView`, `CreatorContentViews`, `CommunityMemberReportSheet` spinners: merchant/ops or uncertain-player surfaces, left for their owners.
- `ApprovedRelease*` / `AppStoreSubmission*` `CYPillButtonStyle` uses: internal release tooling, not player surfaces.
- The remaining bare `ProgressView()` rows (inside buttons, or already next to visible text) were checked and need no change.
- Not built: there is no Swift compiler in the cloud, so the edits were kept type-simple and mirror existing patterns (`Group { if … { x.buttonStyle(A) } else { x.buttonStyle(B) } }`, `ProgressView { Text(key) }`, `ContentUnavailableView { Label } description: { } actions: { }`).

## Gates
- `python3 tools/generate_project.py`: OK
- `python3 tools/check_scaffold.py`: PASS
- `python3 -B tools/check_a11y_lint.py`: PASS, 0 new
- `python3 -B tools/contract_ratchet.py --check`: see the final line below

Final run: `contract ratchet: 104 failing, baseline 104, new 0, fixed 0`.
