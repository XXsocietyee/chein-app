# Receipt: native-r2/home-search

Lane: native-r2 home-search (Home, GlobalSearch, Search, Discovery, Official, Activity, Topic, Square, Bundle). Base: origin/ui/combined-r7. Brief: docs/briefs/native-r2.md (design/handoff-r2).

Gate: `python3 tools/check_scaffold.py` → PASS structural checks (see final line in the last commit). No Swift compiler in the cloud; every API was grepped against App/ usage and limited to iOS 17 (deployment target).

No new localization keys, so there is no docs/port/strings/native-r2-home-search.json fragment.

## Known contract-test effects (coordinator action)
- `test_global_search_category_recovery` and `test_category_roam_registration` pin SHA-256 of `App/GlobalSearchView.swift` / `App/SearchMapExplorerView.swift`; `test_social_guide_templates` pins Discovery file hashes. Any edit fails them, so the pins need re-baselining by the test owner.
- Some tests pin exact source text (CYPillButton/CYListRow in ActivityDetailView and TopicDetailView, CYFooterBar, QuestifyImageEntityCard, E1Activity* parts). Those pieces were kept so the tests stay green; they convert once the tests are updated.
- Other contract failures seen were already failing on the base (test_bk_backend_sync, test_square_detail_page_ready, test_signed_in_content_details, test_w2_07_pricing_apply_parity, test_search_map_contracts).

---

## Group A: home feed and global search

| File | What changed |
|---|---|
| App/HomeFeedView.swift | `CYLoadSlot` replaced by `ProgressView`. Offline `CYStateLayout` + `CYExploreGround` replaced by `ContentUnavailableView`. `CYTabs` replaced by `Picker(.segmented)`. `CYLoadingStateView`/`CYSkeleton` replaced by `ProgressView`. `CYEmptyState` replaced by `ContentUnavailableView`. `CYHeroBanner` replaced by a system paging horizontal `ScrollView` (cover via `AsyncImage`/MPAsset fallback, caption in `.headline`). Glass `CYCarouselRail` replaced by a system horizontal shelf (upcoming countdown kept as a secondary line). Retry card is now a `Label` + `.bordered` button. Section titles use `.title2.bold()`. `.cyRefreshable` replaced by `.refreshable`. Reveal, stagger and skeleton motion removed. Today card has no gradient, medallion, wave or clip; it is a plain image, `Label`, title, meta and `.borderedProminent` `.controlSize(.large)`. Status rows use `LabeledContent`. The live chip is a tinted `Label` under the card. The place link is a `LabeledContent` button. CYColor tokens replaced by `.primary`/`.secondary`/`.tint`. Previews no longer call `cyDomainPageBackground`. |
| App/HomeCityLocationConsentCard.swift | Card chrome replaced by `GroupBox`. Buttons are `.bordered` / `.borderedProminent` with `.controlSize(.large)`. Identifiers kept. |
| App/HomeFeedFixtureSupport.swift | Comment only (the banner fallback is now the MP cover, not a gradient). |
| App/HomeReturnSection.swift | `.cyText(.bodyCompact)` removed; rows use system list type. |
| App/HomeReturnAndCityDeltaSectionView.swift | Tinted `RoundedRectangle` boxes replaced by two `GroupBox`es. Inner boxes are plain stacks. Row type is system. All identifiers kept. |
| App/HomeSearchTabParityViews.swift | Hero search entry is now `.bordered` capsule buttons (search and map) with no custom capsule background. Avatar stroke removed. Continuation card: cover art, gradient and shadows removed; it is now a system row with a tinted play symbol. Shelf header and empty states: `HomeIndexEmptyStateView` empty/error use `ContentUnavailableView`. Mode switch uses `Color.accentColor`. Merchant `TabView`: the gradient `.cyDomainTabBar(.merchant)` is removed, so the system tab bar shows. `PublishTabFloatingButton` is `.borderedProminent` + `.capsule` (no shadow or palette fill). `PublishTabFloatingSheetView` is a `List(.insetGrouped)` with Sections: the quota badge is a tinted `Label` row, and actions are `Label` rows (`CYStatusChip`, `CYRowIcon` and `cyDomainCard` removed). |
| App/GlobalSearchView.swift | Field row has no night pill; 筛选 is `.bordered`. The search CTA is `.borderedProminent` `.controlSize(.large)`. Skeleton replaced by `ProgressView`. `CYEmptyState` replaced by `ContentUnavailableView`. History and recommended keyword chips are now system rows with SF Symbols, with 清空 in the section header. Category tiles (cover art, gradient, shadow) are now `.bordered` buttons in the grid. Map entry is a plain `Label` row and the menu row uses an `ellipsis.circle` `Label`. Result kind pills are now `Picker(.segmented)` in a horizontal scroll view, with `.sensoryFeedback`. The empty-submit toast is now an inline `info.circle` row. `scrollContentBackground(.hidden)`, page background, stagger and `cyAnimation` removed. The hosted field morph uses `.fill.tertiary`. |
| App/GlobalSearchLinksAndTemplates.swift | No change needed: it is already a native host plus readers. |
| App/HomeFeedModel.swift | No change needed: it holds no UI. |

### Not converted / notes
- **GlobalSearchView keyword field:** it stays a `TextField` in a List row, not `.searchable`. Reasons: UI tests address `searchMap.keyword`, and the 首页 in-page host drives the field's position, focus and morph. Converting it would break both.
- **Hosted field morph capsule:** it keeps a `Capsule` filled with `.fill.tertiary` (the system search-field fill) while the field travels from 首页.
- **SearchMapIssue rows:** they keep `.questifyCardListRow()` because `SearchMapIssue` (another file) still draws its own card. `SearchMapCard` result rows are now plain `NavigationLink` rows.
- **Feed card components:** `CYImageCard` / `QuestifyImageEntityCard` stay as the feed's media cards. `QuestifyImageEntityCard` is required by `test_entity_card_reference`, and both live in shared files outside this group.
- **PublishTabFloatingButton:** it keeps `.foregroundStyle(CYColor.textOnAccent)` and `.frame(minHeight: CYSpacing.minTouchTarget)`, because `test_accessibility_hardening_wave` asserts them.
- **MerchantRootModeSwitchBannerView:** its tab row is an MP tabBar look-alike inside an account row. It keeps that layout with system colours; there is no direct Apple equivalent inside a row.
- **GlobalSearchView hash pins:** `test_global_search_category_recovery` (`CURRENT_VIEW_SHA256`) and `test_category_roam_registration` (`FROZEN_SHA256`) pin the file's bytes, so any edit fails them. The semantic forward contract still passes: the category grid and retry guards are kept.

---

## Group B: Discovery and Search map

| File | What changed |
|---|---|
| App/DiscoveryComponents.swift | Added `DiscoveryArtPlaceholder`, a system fill with an SF Symbol, in place of the gradient cover art. `DiscoveryPlayRow` is now a native row: body title, secondary meta, no drawn chevron. `DiscoveryCardRow` passes through unchanged (system row background). `DiscoverySectionHeader` is a plain `Text`, or a `Label` with the MP icon. Metadata uses system text styles and `.secondary`/`.tertiary`. Removed the artwork corner clip. |
| App/DiscoveryHomeView.swift | Replaced CYEmptyState, CYSkeleton, CYListRow/CYRowIcon, the pill NavigationLink, CYSectionHeader and CYImageCard with ContentUnavailableView, ProgressView, `Label` rows and `Section` headers. Plays are standard NavigationLink rows; the featured first item gets one plain header image. Banners are a plain image shelf. Uses `.insetGrouped` with `.refreshable`. Removed the stagger animation, the custom row insets and the clear row backgrounds. |
| App/DiscoveryTemplateBrowserView.swift | Changed ScrollView plus cards to `List(.insetGrouped)` with Sections. CYNoteBanner and the staff note are `Label`s with an orange symbol. The search capsule is a NavigationLink row. The chip row is a system `Menu` (checkmark on the current choice) plus a 全部分类 row. Featured rails are a system page `TabView` of plain images. States use ContentUnavailableView/ProgressView. The category sheet is a List with checkmarks. The toolbar inbox uses the SF `bell`. |
| App/DiscoveryTemplateBrowserView+Port.swift | Thumbnail placeholders now use system fills. The syncing row shows `ProgressView`. The empty-refresh action is a `.bordered` Button. |
| App/DiscoveryTemplateDetailView.swift | Replaced CYEmptyState and CYSkeleton with ContentUnavailableView and ProgressView. Removed the scrollContentBackground/page background, palette colours, gradient cover art (now DiscoveryArtwork or the placeholder) and the custom number discs (now `N.circle.fill` symbols). The disabled CTA is `.borderedProminent`/`.large`. Deleted the unused `PublicTemplateSilhouette`. The material bar is now `.bar`. |
| App/DiscoveryTemplateDetailParitySections.swift | Uses system text styles and colours. 官方 is a tinted `checkmark.seal` Label, no capsule. The notice is a `Label` with info.circle. The preview close button is a `Label`. |
| App/DiscoveryPlayTemplatePresentationView.swift | Uses system fonts and colours; removed the custom row insets. |
| App/SearchMapExplorerView.swift | The keyword TextField is now `.searchable` (city mode). Buttons are `.borderedProminent`/`.bordered`. CYEmptyState, CYLoadingStateView and CYSkeletonBlock are replaced with ContentUnavailableView and ProgressView. The selected-place card is a `GroupBox`. The nearby detail swaps CYHeroHeader for `.navigationTitle`. Removed card backgrounds, QuestifyCardButtonStyle and the scale transition. |
| App/SearchMapCanvas.swift | Removed the rounded clip and stroke around the map; system fonts and colours in the offline ground. |
| App/SearchMapComponents.swift | SearchMapIssue is a ContentUnavailableView with a bordered retry. Result cards are plain image/thumbnail plus text (no card chrome or tag capsules). |
| App/SearchMapDetailViews.swift | CYHeroHeader becomes `.navigationTitle`, CYStatusChip a tinted Label, CYLoadingStateView a ProgressView. Removed the cyGroupedSurface background. |
| App/SearchMapOfflineBanner.swift | The warning card is now a `GroupBox` with an orange `wifi.slash` Label. |
| App/SearchMapResultsCapsule.swift | The capsule is a `.bordered` capsule-shaped Button. Sheet states use ContentUnavailableView and ProgressView. |
| App/SearchMapActivityCard.swift | The timestamp label uses a system style. |
| App/SearchRoutePreviewView.swift | CYHeroHeader becomes `.navigationTitle`. CYPillButton becomes bordered/borderedProminent Buttons. CYLoadingStateView becomes ProgressView. Removed the custom page background. |
| App/MPGap/PlayerContent/SearchMapExplorerGapView.swift | Uses the Apple Maps pattern: MapKit `Map` with the MP marker art, `.mapControls { MapCompass; MapScaleView }`, `.searchable` with submit, and a toolbar `Menu` for the category filter. Sheets are NavigationStacks with detents and `presentationBackgroundInteraction`. Removed material and rounded chrome. |

### Not converted / notes
- `DiscoveryTopicCoverThumb` keeps one small `RoundedRectangle` clip on list artwork (as Music and Podcasts draw it). It is not card chrome.
- The main SearchMapExplorerView body stays a ScrollView/VStack. Converting it to a List would put several buttons in one row, and the page uses ScrollViewReader. It also still lacks the Apple Maps persistent bottom sheet (`.height(120)` detent); that needs a restructure for step 3.
- QuestifyDensityMap (map canvas, not in this group) is unchanged. So are `QuestifyImageEntityCard` (pinned by `test_search_map_activity_card`), `GameplayPresetSection`, `TemplateShelfArtThumb`, `TemplateXbHead`/`Tabs`/`ShareButton`, `TopicTemplateDeckPreviewView` and the `.cyToast` helpers. These belong to other files and still carry some custom chrome.
- `searchNightPill()` (defined in SearchMapComponents) still draws a capsule because GlobalSearchView uses it. My files no longer call it.
- Hash-pinned tests: `test_global_search_category_recovery` pins the SHA-256 of SearchMapExplorerView, so any edit fails it. That test already failed 9/10 before this work and fails 11 now. `test_social_guide_templates` hash pins were already failing.

---

## Group C (activity and official events)

| File | What changed |
|---|---|
| App/ActivityBrowserView.swift | Empty, failed and unconfigured states now use `ContentUnavailableView`. Loading is a `ProgressView`. List rows are plain `NavigationLink`s with the system chevron. Removed the hero zoom, stagger, row transition and `cyAnimation`. Pull to refresh uses `.refreshable`. |
| App/ActivityPresentationComponents.swift | `ActivityListCard` is a plain List row: a 64 pt artwork thumbnail or a tinted SF Symbol, a headline title, secondary meta, and the state and price as text labels. Removed the card chrome and the `CYStatusChip`s. `ActivityTicketCard` uses Labels with tinted symbols and system text styles, with no card chrome. The detail header no longer has a placeholder rectangle or card surface. |
| App/ActivityDetailView.swift | Missing, failed and club-gate states use `ContentUnavailableView`. Loading is a `ProgressView`. Removed `cyDomainPageBackground`, `scrollContentBackground(.hidden)`, the custom section tabs, the stats bar, the tile buttons (now plain List `Button`+`Label` rows), the card surfaces, the forced-light map and its clip, the chip for the cancelled notice (now a Label tinted red), and the zoom transition into the footer sheet. The play, topic and character rows use `Label`. The review points note is a section footer. Added `.refreshable`. |
| App/ActivityCoverAuthoringView.swift | Buttons use `.bordered`, `.borderedProminent` and `.borderless`. Removed the palette colours and the clip shapes on the previews. |
| App/ActivityEditingView.swift | Status is a `Label` with a tinted symbol. Buttons use `.borderedProminent`. Removed the hidden scroll background and the page background. |
| App/ActivityHostCancelView.swift | Rows use `Label`. Loading is a `ProgressView` row and the error state is a `ContentUnavailableView`. The custom modal is now a system `.alert` with the same MP copy. Validation and the character counter are in the section footer. The confirm button uses the system destructive role. Sheets use `presentationDetents([.medium, .large])`. |
| App/ActivityPublishingWizardView.swift | The step bar is a `ProgressView` with borderless step buttons (the MP control has no Apple equivalent). The save chip is a `Label`. Back, Cancel, Next and Review use `.bordered`/`.borderedProminent` with `.controlSize(.large)`. The review summary has no card chrome. |
| App/ActivityTemplateSelectionView.swift | The search field is a plain Form row with no capsule. Template rows use a Settings-style checkmark, with no rounded card or stroke. Buttons are plain Form buttons. |
| App/ActivityReviewsSection.swift | The summary and reviews are plain List rows. Removed the card surfaces. Stars use `.orange`. |
| App/OfficialActionViews.swift | The stale state is a `ContentUnavailableView` and the busy state a `ProgressView`. Buttons use `.borderedProminent`/`.bordered`. Removed `cyGroupedSurface`. The safety consent checkbox is a `Toggle`. Sheet detents are `.medium` and `.large`. |
| App/OfficialEventComponents.swift | `OfficialIssueView` is a `ContentUnavailableView`, and all its action gates are kept. The skeleton slot (`CYLoadSlot`) is replaced by a `ProgressView` overlay. The status chip is the new `OfficialEventStatusLabel`. `OfficialFlowSurface`, `OfficialFlowActionBar` and `OfficialFlowNotice` no longer have custom backgrounds, tint or a forced colour scheme. |
| App/OfficialEventDetailView.swift | The empty state and the empty task list use `ContentUnavailableView`. The hero header is a plain title. The facts strip is `LabeledContent` rows. Mission status is a `Label`. The CTA uses `.borderedProminent`. Removed the card chrome, palette colours and hidden backgrounds. |
| App/OfficialEventsBrowserView.swift | The chip filter is a segmented `Picker`. Search is a `.roundedBorder` `TextField`. The empty state is a `ContentUnavailableView` (through a small helper). Removed the hidden scroll background. |
| App/OfficialOrganizerConsoleView.swift | Loading is a `ProgressView`. Denied and error states use `ContentUnavailableView`. `CYConfirmSheet` is now a `.confirmationDialog`, with the consequences in the message. The preset chips are a menu `Picker` with a "—" row that clears the preset. Action buttons use `.borderedProminent`/`.bordered`. Text uses system semantic colours. |
| App/OfficialPrivateViews.swift | The inbox empty state is a `ContentUnavailableView`. Status chips are `Label`s or `OfficialEventStatusLabel`. Removed the palette colours and backgrounds. Empty rows are plain secondary text. |
| App/OfficialRouteViews.swift | Loading, error, offline, empty and not-found states use `ProgressView`/`ContentUnavailableView`. Removed the hero zoom, stagger, pressable style and `cyAnimation`. Pull to refresh uses `.refreshable`. |

### Not converted / notes
- **ActivityDetailView footer.** Kept `CYFooterBar` and four `CYPillButton`s (sign up / blocked / unavailable / primary), plus `CYListRow("context.review.title")` with `CYRowIcon`. Contract tests check for these exact source strings: `test_global_chrome_domain_contract`, `test_activity_design_structure` and `test_activity_reviews`. Convert them once those tests are updated.
- **E1ActivityDetailParts.swift.** Kept `E1ActivityHero`, `E1ActivityInfoCard` and the `E1IconHeader` tickets header, because `test_activity_registration_parity_w2_06` and `test_activity_reviews` require them in order. Their file is in no group, so it still draws custom chrome (hero gradient and cards). `QuestifyCardButtonStyle` is also kept on list rows, because `test_activity_design_structure` and `test_official_event_contracts` check for it.
- **Custom card components in other files.** `OfficialEventCard` (`QuestifyImageEntityCard`) and `OfficialRouteCard` draw their own card surfaces. They stay in clear rows (`questifyCardListRow`) until those files are converted.
- **Official events search.** It stays an in-page `TextField` (`.roundedBorder`), not `.searchable`. A UI test queries `app.textFields["official.search"]`, and the field hides on the 我的 tab.
- **MP controls with no Apple equivalent.**
  - The wizard step bar is now a `ProgressView` with borderless step buttons.
  - The `oo-chips` preset picker is now a menu `Picker`.
  - The `cy-tabs` chip filter is now a segmented `Picker`.
  - The `cy-consent-check` checkbox is now a `Toggle`.
  - The activity stats bar was dropped. Its facts are already shown in the info card and the meta section.
- **ActivityFixtureSupport.** The DEBUG fixture banner keeps its yellow background, because it is a test-only marker.

---

## Group D: topic detail, browser and topic sections

| File | What changed |
|---|---|
| App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift | `CYColor` brand and text colours replaced with `Color.accentColor`, `.tint`, `.primary` and `.secondary`. |
| App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift | Progress row is now `LabeledContent` plus `ProgressView`. Map uses the system accent and adds `MapCompass`; its rounded clip is gone. Team and merchant rows lost their card fills and clips and now use system text styles and colours. |
| App/MPGap/PlayerContent/TopicTemplateDeckPreviewView.swift | Removed the 3D-flip rotation and spring. Flipping uses plain `withAnimation`. Colours and fonts are system styles. The bottom actions are `.bordered` and `.borderedProminent` with `.controlSize(.large)` on a `.bar` background. The page's custom background is gone. |
| App/TopicBrowserView.swift | `CYLoadingStateView` replaced with `ProgressView`. `CYEmptyState` replaced with `ContentUnavailableView` (keeps `topic.empty`). The read-only note is now a section footer. |
| App/TopicChapterCardsSection.swift | Palette colours replaced with `.primary` and `.secondary`. `.cyPressable` replaced with `.plain`. `CYMotion` spring replaced with the system animation. The move transition is removed. |
| App/TopicCreatorToolsView.swift | The custom `cyPromptModalOverlay` rename prompt is now a system `.alert` with a `TextField`. |
| App/TopicDetailView.swift | Loading shows `ProgressView`. The club picker (was `CYOptionSheet`) is a `List` sheet with `.presentationDetents`. The contact sheet (was `PlayCloseSheetHost` with `CYField`) is a `Form` with `TextField`s, `.textContentType` and `.keyboardType`. The four `CYModal` overlays and the result sheet are now `.alert`s; every confirm identifier is kept. The `CYCard` hero is plain rows. Removed `.listRowBackground(Color.clear)`, the separator tint, `scrollContentBackground(.hidden)` and the page background. The pinned tabs sit on `.bar`. The beta capsule chip is tinted text. Story uses a `Section` header. Paywall unlock is `.borderedProminent`; self-play is `.bordered`. The refused state uses `ContentUnavailableView`. |
| App/TopicLocationTodosSection.swift | Entry row is a system `Label` row. The reconfirm note moved to the section footer. `MerchantChoiceOptionSheet` replaced with a system `List` picker sheet. `.cyPrimary` replaced with `.bordered`. Palette colours replaced with system colours. |
| App/TopicPublicationViews.swift | `CYStatusChip` replaced with a `Label` and a tinted SF Symbol (new `PublishClarityText.color`). `CYColor` replaced with system colours. Fonts are text styles. |
| App/TopicReviewsContent.swift | Removed `questifyCardSurface` and `questifyCardListRow` card chrome; reviews are plain list rows. Fonts are text styles. |
| App/TopicSelfPlaySheet.swift | `.cyPrimary` and `.questifyPrimary` replaced with `.borderedProminent` and `.controlSize(.large)`. |
| App/TopicSessionSelectionView.swift | Both `CYEmptyState`s replaced with `ContentUnavailableView` (identifiers kept). Fonts are text styles. |
| App/TopicStoryParticipationHost.swift | Removed the page background and the fixed row height. The danger colour is `.red`. |
| App/TopicTeamsCard.swift | `CYColor` replaced with system colours and text styles. |
| App/TopicTemplateUseSection.swift | `.cyPrimary` replaced with `.borderedProminent` and `.controlSize(.large)`. Condition rows use `LabeledContent`. Header is a plain `Text`. Removed the no-op `discoveryCardRow`. Palette colours replaced with system colours. |
| App/TopicThemeRecordsView.swift | Loading shows `ProgressView`. Failed and empty states use `ContentUnavailableView`; reload is a `.bordered` button and the identifiers are kept. Added `.refreshable` on the list and the card. |
| App/TopicUnlikeControls.swift | `CYConfirmSheet` replaced with `.confirmationDialog`; a guard stops the dismissal from cancelling a confirmed unlike. The heart is a `.bordered` circle button. |
| App/TopicXcxSections.swift | `CYTabs` replaced with a segmented `Picker` (`topic.tabs` kept). Category chips are one secondary line. The review capsule is a `Label`. The stat bar card is removed. `.cyPrimary` replaced with `.borderedProminent`. `CYNight` and palette colours in the route section replaced with system colours. Stop numbers use the `N.circle.fill` SF Symbols. `TopicBarRecede` is now a pass-through, so the decorative scale and clip are gone. |

Unchanged (already native, or not UI): TopicComponents, TopicFavoriteHost, TopicFixtureSupport, TopicLikeAndSquareEvictionSectionView, TopicUnlikeInjection.

### Not converted / notes
- `TopicDetailView.swift` keeps 2 `CYPillButton`s: `context.review.title` and `mpfresh.topic.back`. `Tests/ContractChecks/test_topic_reviews.py` and `test_topic_session_selection.py` assert that exact source text. Convert them once those tests are updated.
- `TopicXcxSections.swift` keeps `CYFooterBar` for the pinned bottom bar, because `test_global_chrome_domain_contract.py` requires it. `TopicBrowserView.swift` keeps `QuestifyImageEntityCard` and its card-row modifiers, because `test_entity_card_reference.py` requires them.
- Clips kept on photos only:
  - the deck preview cover card (paged photo deck; no Apple control matches it);
  - chapter card cover images;
  - 56pt stop thumbnails.

  `cornerRadius` in `TopicBarHeroSource` is the zoom-transition source radius, not card chrome.
- No Apple equivalent, closest used: the MP card-flip deck stays as `TabView(.page)` with a plain front/back swap. `cyToast` (toast) is kept in TopicDetailView, TopicCreatorToolsView and TopicUnlikeControls. `CYDesignedCover` is kept as the no-image hero placeholder.
- Alerts close as soon as you tap. The old `CYModal` stayed open with a spinner. The busy flags still disable a repeat confirm.
- No new strings.

---

## Group E: Square (feed, detail, composer, report, workspace)

| File | What changed |
|---|---|
| App/SquareBrowserView.swift | `CYLoadingStateView` → `ProgressView`; `CYEmptyState`/`CYStateLayout` (closed, error, empty) → `ContentUnavailableView` (ids moved to the title `Text`, retry keeps `square.retry`); load-more `CYPillButton` → borderless `Button`; removed `scrollContentBackground(.hidden)` + `bgPage`, the clear picker row background and `CYColor`; `.listStyle(.insetGrouped)`. |
| App/SquareCloudComposerView.swift | Composer rebuilt as a `Form`: `TextField(axis: .vertical)` with a system prompt (no hand-drawn placeholder), author in the section header, counter in the footer, notice as an `info.circle` `Label`, attachments and tools as `Label` rows, announcement as a `Toggle`; Publish / Check result / Close moved to the navigation bar's `.confirmationAction` (as in Mail); drafts page → inset-grouped `List` with `ContentUnavailableView` for no drafts, plus swipe and context-menu delete; review page → `Form` with a `ProgressView`; status screens → `ContentUnavailableView`; removed `CYSkeleton`, `CYColor` backgrounds and the capsule chips. |
| App/SquareCloudFeedViews.swift | Route preview: `Canvas` on `CYNight` → MapKit `Map` + `MapPolyline` (orange, no interaction, double-tap kudos kept); Strava block: removed card background, banner tint and avatar chrome, system fonts; post actions: `CYOptionSheet`/`CYSheetContainer`/`CYConfirmSheet` → `NavigationStack` + `List` of role buttons + `.confirmationDialog` for delete, `.presentationDetents([.medium, .large])`; author `cy/popover` → system `Menu` (the custom `SquareCloudPopover` was removed and had no other users); activity and completed pickers → inset-grouped `List`, `ContentUnavailableView` states with Retry, `.refreshable`. |
| App/SquareComponents.swift | Avatar `cyAnchoredMenu` → system `Menu`; `cyText` → text styles; dropped the `cyPressable` style and the min-frame. |
| App/SquareDeletionViews.swift | `CYConfirmSheet` → `NavigationStack` + `Form` (consequences as `Label`s, title in the header, message in the footer, destructive button row, Cancel in the toolbar), medium/large detents; `CYStatusChip` → `Label` with a tinted symbol; `CYPillButton` → bordered `Button`. |
| App/SquareDetailView.swift | `CYSkeleton` → `ProgressView`; removed `cyMiniListScreen`/`cyMiniCardRow` (now `.insetGrouped`); more-comments `CYPillButton` → `Button`; comment bar → bordered large `Button` inside the existing `CYFooterBar` (no capsule chrome); block `CYModal` → `.alert(presenting:)`; deletion sheet detents are system; `CYColor` → semantic colours; author-delete section uses a `ProgressView` and bordered/destructive `Button`s; play card and issue view → system fonts; `SquareDetailIssueView` → `ContentUnavailableView` (MP empty art kept as the icon). |
| App/SquareGovernanceViews.swift | Sign-in `CYPillButton` → `Button` row in a `Section`; `CYSkeleton` → `ProgressView`; `.insetGrouped`; appeal counter styled as footnote. |
| App/SquarePostLocalMediaPresentation.swift | Removed the rounded clip on the thumbnail and the `SquareFlowNoticeStyle` custom tone; system fonts and semantic red/orange. |
| App/SquarePostVideoViews.swift | `CYSkeleton` → `ProgressView`; `CYStatusChip` → `Label` with a tinted symbol; `CYPillButton` → `Button`; removed `.cornerRadius(8)`; system fonts. |
| App/SquareRelatedTopicView.swift | `CYPillButton` → bordered `Button` with `Label("…", systemImage: "map")`. |
| App/SquareReportFixtureHost.swift | `cyText` → `.font(.caption)` (DEBUG fixture). |
| App/SquareReportProgressView.swift | Row: removed the capsule stage chip and `CYColor`, now secondary text with a tertiary chevron; `CYEmptyState` (empty, error, signed out) → `ContentUnavailableView` (ids kept on title/action); `CYSkeleton` → `ProgressView`; `cyGroupedSurface` → `.insetGrouped`. |
| App/SquareReportView.swift | Discard `CYConfirmSheet` → `.confirmationDialog` (ids `squareReport.discard` / `keepEditing` kept); reason picker `CYSheetContainer` with rounded cards → `NavigationStack` + `List` with checkmark rows and a Cancel toolbar button (`squareReport.reasonCancel`); `CYStatusChip` → `Label`; `CYPillButton` → `Button` rows; `CYSkeleton` → `ProgressView`; removed `cyGroupedSurface`; no-attachments line moved into the section footer. |
| App/SquareWorkspaceView.swift | `CYPillButton` → `Button`; `CYSkeleton` → `ProgressView`; issue `CYModal` → `.alert`; withdraw-location `CYConfirmSheet` → `.confirmationDialog(presenting:)`. |
| App/SquareXcxPostCard.swift | Removed rounded fills on the play card and upcoming cards and the capsule badges; `cyText` → text styles; lifecycle tint is `.orange`. |

Unchanged (non-UI or already native): SquareFixtureSupport, SquareGovernanceFixtureHost, SquareGovernanceSessionAccess, SquarePostLocalMediaInspector, SquarePostLocalMediaPicker, SquareReportSessionAccess, SquareRouteMapProvider, SquareWorkspaceFixtureHost, SquareWorkspaceSecureStorage.

### Not converted / notes
- `CYFooterBar` stays in SquareDetailView, because `test_global_chrome_domain_contract.test_pinned_footer_bars_use_cy_footer_bar` pins it there. Only its content is native now.
- These shared DesignSystem components are still used, because they belong to App/DesignSystem and are out of this lane:
  - `CYSquareRouteMapCard`;
  - `CYSquareShareSheet`;
  - `CYSquareActivityPicker`;
  - `CYSquarePostDraftsSheet` (it has a 4-second undo flow);
  - `cyToast`;
  - `cySheet`;
  - `cyPushedChrome`;
  - `cyDomainScreen`.
- The source "即将开始" horizontal banner strip (`SquareXcxUpcomingStrip`) has no Apple list equivalent. It stays a horizontal `ScrollView` of plain text columns (no card chrome). Its single-row structure is kept so its `.task` loading is unchanged.
- The composer's activity "chips" are now plain `Label` rows with a clear button. The MP `cy/popover` author menu is now a system `Menu`.
- No new localization keys. Every new copy is an existing key or an existing `locale.pick` / `copy(zh, en)` pair.

---

## Group F: bundle commerce screens (native r2)

| File | What changed |
|---|---|
| App/BundleOrderStatusView.swift | Shared lane chrome: `Cloud03Screen` is now `List` (inset grouped) + inline navigation title (generated cover art and page background removed; `Cloud03Cover` deleted, no other users). New `Cloud03Note` = system `Label` with a tinted SF Symbol (replaces `CYNoteBanner`). Order status: `ProgressView` in the receipt row, `LabeledContent` + `Label` rows, `ContentUnavailableView` for no order, plain `Button` for recheck. |
| App/BundleAppealView.swift | Form-style sections: `Picker`, vertical `TextField`, `Label` evidence row, explanation as the section footer; status rows use `Cloud03Note`/`ProgressView`/`ContentUnavailableView`; submit is `.borderedProminent` `.large`, recovery buttons are separate rows. |
| App/BundleCancelView.swift | `Toggle` section, system `Button`s (destructive confirm), `Cloud03Note`, `ProgressView` loading rows, `ContentUnavailableView` for not open. |
| App/BundleRefundApplyView.swift | `LabeledContent` rows, `Cloud03Note`, one `.borderedProminent` submit. |
| App/BundleRefundProgressView.swift | `LabeledContent` rows; not-refunded note is the section footer. |
| App/BundleRefundQuoteView.swift | Amount row with text styles, route `Section` with header `Label`, `LabeledContent` rows, quote-only notice and policy version in the footer. |
| App/BundleRedeemResultView.swift | `ProgressView`, `ContentUnavailableView` (unavailable / failed + retry), result as a `Label` with a tinted symbol (custom result mark removed). |
| App/BundleDetailView.swift | `List` with sections (price `LabeledContent`, included, merchants, compliance `DisclosureGroup`), bundle name as the inline navigation title (hero art, gradient, parallax, stagger, card chrome removed). Custom buy bar replaced by a bottom bar on `.bar`: borderless total button (opens the summary sheet) + one `.borderedProminent` Buy button with `ProgressView` while paying. `BundleIncludedRow` is a `Label` row. Keeps `.themeDomain(.player)` and system sheet detents. |
| App/BundleOrderSummarySheet.swift | `NavigationStack` + `List` with inline title; `LabeledContent` price rows, compliance line in the footer, `.borderedProminent` Pay button, included section. |
| App/BundlePayResultView.swift | `List` led by a `ContentUnavailableView` result (SF Symbol, title, message; `.contentTransition(.symbolEffect(.replace))`), `LabeledContent` detail rows, `ProgressView` while processing, `.borderedProminent` primary + borderless secondary. Gradient, confetti, entrance motion removed; haptics kept. |
| App/BundleRenewalIntentView.swift | Cover art removed; `ContentUnavailableView` notices; inline `Picker` for the intent; `TextField` note; plain Form buttons; `.refreshable { await model.load() }`. Source scan words (pay/order/…) avoided, so no `.bordered*` button styles here. |
| App/BundleReservationsView.swift | Cover art removed; `ContentUnavailableView` empty / legacy; reservation rows are `Label`s with a tinted status symbol. |
| App/BundleReserveWindowView.swift | `DatePicker` + plain `Button` row; `ContentUnavailableView` when there is no window; custom insets removed. |
| App/BundleReviewComposeView.swift | `ScrollView` + cards → `Form`: menu `Picker`, `TextEditor`, counter in the footer, `ProgressView`, `ContentUnavailableView`, `LabeledContent` summary, tinted status `Label`. |
| App/BundleReviewListView.swift | `ProgressView`, `ContentUnavailableView` (unavailable / failed + retry / empty), inset-grouped list, `.refreshable`. |
| App/BundleShelfView.swift | `ScrollView` of cards → inset-grouped `List` of `Button` rows (thumbnail via `AsyncImage` of the server cover, else SF Symbol), `ContentUnavailableView` states, `.refreshable`. |
| App/BundleTransferClaimView.swift | Cover art removed; `ContentUnavailableView`, `TextField` with `.oneTimeCode` / `.submitLabel`, plain `Button`, `ProgressView`, `Cloud03Note`. |
| App/BundleTransferSendView.swift | `ContentUnavailableView` states, `ProgressView` rows, tinted `Label` state, sticky bottom actions are `.borderedProminent` / destructive `.bordered` with `.controlSize(.large)`. |
| App/BundleVoucherView.swift | `ProgressView`, `ContentUnavailableView` (+ retry), status as secondary `Text`, inset-grouped, `.refreshable { await model.reload() }`. Privacy shield / `privacySensitive` kept. |
| App/BundleWalletView.swift | `ContentUnavailableView` legacy / no-detail, expired as an orange-symbol `Label`, text styles. `.appSwitcherPrivacyShield()` kept. |
| App/BundleCommerceMount.swift | Forced-dark `CYNight.ink0` backgrounds and `.scrollContentBackground(.hidden)` removed; lists inset grouped; `BundleCommerceStatus` = `ProgressView` / `ContentUnavailableView` (+ prominent retry). |
| App/BundleExitSwapView.swift | Palette colours → `Label` with `.secondary` / `.red`; inset grouped; `.themeDomain(.player)`. |
| App/BundleMerchantStallView.swift | Text styles; `ContentUnavailableView` for unavailable. |

Unchanged (no UI): BundleAppealTransport, BundleCancelCanceler, BundleCancelTransport, BundleCommerceReadTransport, BundleComposition, BundleReadTransport, BundleRefundTransport, BundleTransferTransport.

### Not converted / notes
- `App/BundleShelfView.swift`: `.clipShape(.rect(cornerRadius: 8))` on the server cover photo thumbnail only (image clip, as Apple does for artwork).
- Bundle detail buy bar: the MP's pinned price + buy bar has no single Apple control; closest is a `.safeAreaInset` bottom bar on the system `.bar` material with a borderless total button and one `.borderedProminent` button (App Store / Apple Store pattern).
- `BundleExitSwapView` still presents the shared `MemberBundleSwapConfirmSheet` (not in this group).
- `cyAnimation` (state cross-fade, Reduce Motion aware) and haptics were kept; decorative motion (stagger, parallax, confetti, entrance, row transitions) removed.
- No new strings.

