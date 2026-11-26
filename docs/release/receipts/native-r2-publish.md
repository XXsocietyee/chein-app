# Receipt: native-r2/publish (Apple-native front end, publish/authoring lane)

Brief: `origin/design/handoff-r2:docs/briefs/native-r2.md` (component rule, "EVERYTHING native", gates).
Base: `origin/ui/combined-r7` (merged before each push). Branch: `native-r2/publish`.

## Scope
This lane owns the App files whose names start with Publish, Publishing, Template, TopicEdit, TopicPublish, Project, Creator, Workshop, Content, Draft or Native. NativeChannel*, NativeRoam*, NativeStory* and NativeWalking* are excluded.
- **Owned:** 302 files.
- **Flagged:** a grep for the old CY components, gradients, shadows, RoundedRectangle chrome, `.background` chrome, fixed font sizes, forced dark and hex/CYRGB matched 117 files.
- **Converted:** all 117, plus one test (see "Contract checks").
- **Not edited:** the other 185 owned files already used `Form`/`Section`/`List` with `.cyText` and semantic tokens.
- **Untouched:** App/DesignSystem, CYDomainPalette, Theme, CYDesignTokens and Core/.

## What changed (pattern level)
| Was | Now |
|---|---|
| `CYPillButton` | `Button` + `.borderedProminent` / `.bordered` / `.borderless`, `.controlSize(.large)`. Inside a Form/List it is a plain Settings-style row button. One prominent button per screen. |
| `CYHeroHeader` | `.navigationTitle`; the subtitle moved to the first Section header or footer |
| `CYListRow`, `CYRowIcon`, fact rows | `Label`, `LabeledContent`, `NavigationLink` in inset-grouped `List`/`Form` |
| `CYStatusChip` / chip filters | tinted `Label` or secondary `Text`; filters became `Picker(.segmented)` or `.menu` |
| `CYEmptyState`, `CYErrorState` | `ContentUnavailableView` (with actions where there was a retry or sign-in) |
| `CYSkeleton`, `CYLoadingStateView` | `ProgressView` or `.redacted(reason: .placeholder)` |
| `CYConfirmSheet`, custom modals | `.confirmationDialog` / `.alert`; sheet confirms moved to `.confirmationAction`, cancels to `.cancellationAction` |
| `CYFooterBar` / safe-area footers | `.toolbar` `.bottomBar` (ProjectEditView, TemplateAuthoringView, Activity wizard, Quick publish) |
| Custom field boxes | system `TextField` / `TextEditor` with `.textContentType`, `.submitLabel` and `.keyboardType(.numberPad)` where numeric; validation moved to Section footers |
| Drag-handle reorder stacks | `ForEach.onMove` inside the Form (rule steps, choice options) |
| Gradients, shadows, glass/material, card backgrounds, CYMotion, `cyHaptic` | removed; haptics use `.sensoryFeedback` |
| ProjectEdit overview map | `Map` with `Marker`s; the node card is a Maps-style `.sheet` with detents |

These were kept unchanged:
- MP copy, keys and section order, and MPAsset images;
- every `accessibilityIdentifier` (moved onto the replacement control);
- every action, request, lease and state machine;
- pricing/money gating.

## MP controls with no Apple equivalent (closest Apple control used)
- **Interest bubbles** (`QuickPublishingInterestPicker`): a multi-select checkmark list.
- **Dashed "add" tile with n/limit counter**: a plain `Button` row with the count as trailing secondary text.
- **Chapter atmosphere swatches**: Settings-style rows with a checkmark. The swatch colour stays because the colour is the content.
- **Detail/ability tabs** (TemplateDetailXbChrome) and the preview pager step bar: `Picker(.segmented)`.
- **Friend picker search inside an embedded Section**: a system `TextField` with the search submit label, because `.searchable` must live on the parent screen.
- **Hotspot placement canvas, image crop canvases, reaction stage colour fill, QR camera instruction strip**: kept as functional canvases; only decoration was removed.

## Known exceptions left on purpose
- **Image crops:** `.clipShape(.rect(cornerRadius:))` on cover and preview images only.
- **`TemplateXbApplyLabel`:** still a capsule fill. Its caller, `DiscoveryTemplateDetailView`, is outside this lane and wraps it in `.buttonStyle(.plain)`. That caller should move to `.borderedProminent`.
- **DEBUG fixtures** (`NativeGalleryFixture`, `PublishDesignFixtures`): keep their own light/dark switch and footer.
- **Editor kit:** `EditorSectionBar`, `EditorRow`, `cyToast` and `cyDomainSheet` are shared outside this lane, so they were left as they are.

## Behaviour notes for review
- Dismissing a `.confirmationDialog` by tapping outside it runs Cancel:
  - friend removal clears its review;
  - publishing management sets `review = nil` without calling `service.cancel`, the same as the old swipe-dismiss.
- Some sheet confirms ("Next" on team code, creator-studio compose and close, add friend) moved from the bottom of the form to the top-right toolbar.
- Bottom toolbars with 2–3 buttons may crowd at accessibility text sizes. Check this on device.

## Compile risks (no compiler in the cloud; grep-checked only)
- `ContentUnavailableView { label } actions: { }` with no `description:`. The default exists and is used elsewhere in App.
- `.foregroundStyle(.white, Color.accentColor)` on an SF Symbol.
- `.fontWeight` on `Button`.
- `.sensoryFeedback(.impact(weight:))` (iOS 17).
- `ForEach(indices)` inside `.confirmationDialog(presenting:)`.
- `navigationDestination(item:)` inside the overview Form preview.
- Two-line VStacks used as `Label` titles.
- Identifiers on `Text` inside a segmented `Picker` may not reach XCUITest. No test currently uses them.

## Gates
- **Scaffold:** `python3 tools/check_scaffold.py` prints `PASS structural checks`.
- **Forbidden-pattern grep:** 0 hits across the converted files, apart from the exceptions above.
- **New string keys:** none.
- **Contract checks:** see the next section.

## Contract checks
- `Tests/ContractChecks/test_template_sample_browser.py`: the ordering assertion now pins `.navigationTitle("templateSamples.open")` instead of the removed `.cyGroupedSurface()`.
- Contract-check status after the follow-up fixes is listed below.
