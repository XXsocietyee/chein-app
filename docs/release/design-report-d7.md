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

## Open issues
- Not restyled: `PublishingProjectsView` (fixture `publish-projects` exists but no shot), QuickPublishingView/ActivityPublishingView forms, topic preview detail body (only background/title), template detail sections still system List rows.
- `CYImageCard` has no verbatim-string init, so a private `TemplateHeroCard` exists in the browser for server titles; fold into kit.
- Dynamic Type XL, English, and `publish-sheet-locked/quota` screenshots not taken.
