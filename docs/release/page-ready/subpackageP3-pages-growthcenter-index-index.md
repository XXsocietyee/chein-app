# 成长中心 index — page-ready evidence

Page `subpackageP3/pages/growthcenter/index/index` maps to `App/GrowthCenterView.swift` with status `exists`. This note does not change that screen.

Live reads already sit on `GrowthCenterService` (`api/growth/center`, `api/play/growth`, `api/play/my-completed`, legacy `api/growth/leaderboard`). `api/growth/mission/complete` is not called. The anonymous leaderboard stays off the default `.legacy` contract.

`GrowthCenterReadModel` already has loading (`isLoading`) and error (`GrowthCenterIssue`). Empty collections stay empty arrays (`GrowthCenterSyntheticFixtures.emptyCenterJSON`). Unknown numbers stay nil; `GrowthLeaderboardStanding.unknown` drops a placeholder score of 0. The shipped unknown glyph is `growth.unknown` = `—` in both en and zh-Hans, never `0`.

DEBUG fixture data already exists as `GrowthCenterSyntheticFixtures` (`#if DEBUG`). Existing coverage stays in `Tests/CoreTests/GrowthCenterTests.swift` and `Tests/ContractChecks/test_growth_source_contract.py`.

The branch was missing the page catalog. It is now `docs/release/ui-strings-subpackageP3-pages-growthcenter-index-index.json`, locked by `Tests/ContractChecks/test_growth_center_index_page_ready.py`. No view file, score font, `Localizable.xcstrings`, project, or CI manifest was edited. Xcode was not run.
