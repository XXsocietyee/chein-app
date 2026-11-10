# pages/template/index page-ready

CB197 non-view evidence for the partial map row `pages/template/index` (`App/DiscoveryTemplateBrowserView.swift`).

- Model: `TemplateIndexPageModel` and `TemplateIndexCount` in `Core/TemplateBrowserPort.swift`. Loading, empty, error, and ready are separate. Unknown counts render `—`. A literal 0 stays `0`. `DiscoveryTopicTemplate.chapterCountIncluded` in `Core/DiscoveryContracts.swift` records a missing chapter count so the stored fallback 0 is not shown as a known zero.
- Coordinator: `TemplateIndexPageCoordinator` calls the existing `DiscoveryService` reads `topicTemplates`, `templateHome`, and `playTemplates` (`api/template/topic-template/list`, `api/template/homeData`, `api/template/list`). `topic-template/use` stays hidden. A nil publish capability stays hidden. `showsMerchantChoice`, `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false.
- Tests: `Tests/CoreTests/TemplateIndexPageModelTests.swift` and `Tests/ContractChecks/test_pages_template_index_page_ready.py`.
- Strings: `docs/release/ui-strings-pages-template-index.json` (EN, zh-Hans, accessibility identifiers).
- Fixture: `TemplateIndexFixtureData` is DEBUG-only in `Core/TemplateBrowserPort.swift`.
- Left: the view was not edited. `Localizable.xcstrings`, the Xcode project, and the CI manifest were not updated. No Xcode Cloud run.
