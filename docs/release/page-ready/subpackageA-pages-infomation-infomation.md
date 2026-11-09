# subpackageA/pages/infomation/infomation

Page stays partial. The list read is the existing bodyless POST `api/common/infomation_list` (`ProfileGuideReadRoute.listPath`). This note does not mark that route live.

Already present: `SocialAccountService.informationList`, `ProfileGuideListReader.informationList`, `ProfileGuideReadRoute`, `Tests/AppUnitTests/ProfileGuideReadTests.swift`, `Tests/CoreTests/ProfileGuideReadRouteTests.swift`, and the DEBUG data `SocialAccountSyntheticFixtures.informationJSON`.

Added because the model had no loading, empty, error, and unknown phases: `PlayGuideInformationListPage` and `PlayGuideInformationListCoordinator` in `Core/ProfileGuideRead.swift`. A missing guide grant stays hidden. An unknown document count is an em dash (`—`), including a missing total, and is never `0` or the decoded row count. A server literal `0` stays `0`.

Tests: `Tests/CoreTests/PlayGuideInformationListModelTests.swift` and `Tests/ContractChecks/test_play_guide_information_list_page.py`. Strings and accessibility identifiers: `docs/release/ui-strings-subpackageA-pages-infomation-infomation.json`.

Left: `App/SocialGuideViews.swift` is unchanged, so the new phase is not on screen. `ProfileGuideListReader.refresh` still only bumps `revision`. No Xcode project edit. Swift tests were not executed in this environment.
