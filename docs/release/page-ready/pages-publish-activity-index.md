# CB234 PAGE-READY · pages/publish/activity/index

- Feature: 发布活动三步向导
- Native: `App/PublishingModesViews.swift`
- Map status: exists

The three-step wizard, `ActivityPublishDraft`, and the live reads in `PublishingRead` were already on `rc/20261108`. This change adds the page model those reads did not have.

- Model: `ActivityPublishingPageReadiness` in `Core/ActivityPublishingWizard.swift`. Phases are loading, empty, error, and unknown. Unknown counts display as — and a literal 0 stays 0. Create-request paths stay hidden because `ChinaReviewedRouteCapability` marks them missing. `showsMerchantChoice`, `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false.
- Tests: `Tests/CoreTests/ActivityPublishingPageReadinessTests.swift` and `Tests/ContractChecks/test_activity_publishing_page_readiness.py`.
- Strings: `docs/release/ui-strings-pages-publish-activity-index.json` (EN, zh-Hans, and accessibility identifiers).
- Fixture: `ActivityPublishingFixtureData`, compiled only in DEBUG, in the same Core file.

Views, `Localizable.xcstrings`, the Xcode project, and route marks were not changed. No Xcode Cloud result is claimed.
