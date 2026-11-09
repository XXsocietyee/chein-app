# Design report D7: creator / publish screens (player dark)

Fixtures (DEBUG, registry, synthetic): `publish-sheet`, `publish-sheet-locked`, `publish-sheet-quota`, `publish-menu`, `publish-menu-pro`, `publish-projects`, `template-topics`, `template-games`, `template-detail` (App/DesignFixtures/PublishDesignFixtures.swift). `DesignFixtureRegistry.make` is now `@MainActor`.

## Screens done (real views, zh-Hans, default size)
- Publish menu `PublishingModesView` (Quick setup / Publish activity / My projects / Publisher registration): hero title, ONE primary pill (Quick setup), kit list rows in cards. shot-032021.png (before removing duplicate inline nav title).
- Publish tab sheet `PublishTabFloatingSheetView`: hero + quota chip + card rows with disabled reasons. shot-publish-sheet.png.
- Template browser `DiscoveryTemplateBrowserView` (topics + games): segmented shelf, search pill, filter chips, hero card, card rows. Compare with page-map pair pages/template/index: `compare-template-games.png` (ref 141-template-games). Topics shot-032331.png.
- Template detail `DiscoveryTemplateDetailView`: heavy headline, pill adopt button, dark page. `compare-template-detail.png` (ref 142; the reference is a loading skeleton).
All in /Users/fanning/chengyin-refs/design-reports/d7/.

## Demoted / changed controls (none removed)
Shelf search "搜索" button now inside the search pill (also Return); pack/category pickers became chips (same identifiers); topic cards use allowsHitTesting instead of `.disabled` (action guards unchanged).

## Checklist
1 order kept; 2 one primary (menu, detail); 3 ok; 4 dark; 5 no violet; 6 kit tokens; 7 skeleton/empty via CYSkeleton/CYEmptyState; 8 XL NOT verified; 9 zh-Hans verified, EN not shot; 10 builds, no logic changes.

## Round 2 (real views, EN + Dynamic Type accessibility-extra-large, player dark)
Shots in /Users/fanning/chengyin-refs/design-reports/d7/ named `r2-<page>-en.png` / `r2-<page>-xl.png`: projects, quick, activity, games (template browser), detail (template detail), menu, sheet.
- **PublishingProjectsView** (App/PublishingManagementViews.swift). Mini-program pair: subpackageA/pages/myproject ("我的项目": big title, tabs topic/activity/template, illustrated empty state). Reference image: docs/delivery/page-polish-20261102/preview/shots/q01-myproject-player.png (right half, dark). Matched: title, type tabs as a segmented control (All + topic/activity/template), empty/error state centred under the tabs. Different on purpose: native large title and segmented control instead of the WeChat capsule/underline tabs; state and publisher filters are quiet menu chips ("Status · All", "Publisher · All"); no illustration (asset not in the iOS catalog) and no "go publish" button (the view has no route to it; no flow invented). Project rows are kit cards with a state pill, signup count, secondary toggle and destructive-role remove actions (same logic, same guards); loading = CYSkeleton cards, error = CYErrorState, empty = CYEmptyState; remove/online/offline confirmation sheet uses kit pill/destructive buttons. All logic, identifiers and keys unchanged. Only the error state could be shot (fixture has no service); rows/skeleton/empty not visually verified.
- **QuickPublishingView / ActivityPublishingView** (App/PublishingModesViews.swift, ActivityPublishingWizardView.swift). Pairs: pages/publish/simple, pages/publish/activity (order unchanged). Player theme (dark) as in the code; page background and tint from the role palette (no violet). CYSectionHeader for sections, CYListRow/CYRowIcon for AI draft, place and chooser rows, CYPillButton for the one primary action (Continue in professional editor / Next / Review) with secondary Cancel/Back; stacked vertically at accessibility sizes. Wizard step dots, headings and validation use palette tokens. Fixtures `publish-quick`, `publish-activity` added.
- **Template hero**: `CYImageCard(verbatim:fallback:meta:imageURL:)` added to the kit (server titles verbatim, empty title falls back, blank meta dropped, HTTPS-only covers); private `TemplateHeroCard` removed.
- Menu and publish sheet re-shot in EN/XL (r2-menu-*, r2-sheet-*), unchanged since round 1.

## Checklist update
8 XL shot for all pages touched; 9 EN shot for all touched pages (zh-Hans verified earlier for menu/sheet/browser/detail). Build green (design-run, BUILD_EXIT=0); no tests run, no logic changes.

## Open issues
- At accessibility-extra-large the pinned bottom action (Next + Cancel stacked, 56pt scaled pills) takes about a third of the screen in the activity form; content still scrolls (safeAreaInset), but a tighter AX layout would be better. Wizard step labels truncate at AX XL ("Activity conte…").
- Projects list with real rows, skeleton and empty state not captured (fixture has no data source); locked/quota sheet fixtures not shot; zh-Hans for the new forms not shot.
- Not restyled: topic preview detail body, template detail sections (system List rows), other forms (cover, template selection, time range sheet).
- No side-by-side composite image tool available (no PIL/ImageMagick); the pair is the reference PNG above vs r2-projects-en.png, compared by eye.

## Round 3 (real views; shots in chengyin-refs/design-reports/d7/, contact-055403.png, batch-r3-*.png)
- zh-Hans shots: quick, activity, template detail, topic preview (batch-r3-*-zh). EN topic preview, EN+zh My projects.
- XL bottom bar: `ActivityPublishingWizardNavigation` is now one compact row at every size (Dynamic Type capped at xxxLarge on the bar only); form above still scrolls. batch-r3-activity-xl.png. The form body itself still scales to AX XL, wizard step labels still truncate there.
- Template detail sections + topic preview body: kit section headers (`DiscoverySectionHeader`), surface rows (`discoveryCardRow`), CYTypography/palette tokens, warning token instead of `.orange`, rating as data numeral. New fixture `topic-preview`.
- My projects real states: DEBUG-only `designPreview` on `PublishingProjectsView` + fixtures `publish-projects-rows|empty|loading` (rows titled "Sample ... (debug fixture)"). Rows, empty, skeleton verified in EN, rows in zh-Hans.
- Left: template detail zh shows English because the synthetic fixture content is English; other forms (cover, template selection, time range sheet) not restyled; no tests run; mini-program side-by-side compare not rebuilt this round.
