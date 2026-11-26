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
