# PAGE-READY subpackageA/pages/infomationdetail/infomationdetail

玩法详情文档页. Native screen remains `SocialInformationView` in `App/SocialGuideViews.swift`. This change does not edit that view.

The detail read was already wired: `ProfileGuideReadRoute.detailPath` (`api/common/infomation_detail`), `SocialAccountService.information(id:)`, and `ProfileGuideArticleReader.information(id:)`. No new route was added and the route was not marked live.

`InformationDetailPageModel` in `Core/ProfileGuideRead.swift` projects that result. Phases are loading, empty (incomplete link or removed), error, unknown, and ready. Unknown display is `—`. A missing count, a numeric string, and a removed id of 0 also display `—`. A literal JSON 0 stays `0`. A missing read capability, or any path other than the existing detail path, stays hidden.

EN and zh-Hans keys, plus accessibility identifiers, are in `docs/release/ui-strings-subpackageA-pages-infomationdetail-infomationdetail.json`. DEBUG fixture payloads are `InformationDetailFixtureData` in `Core/SocialAccountSyntheticFixtures.swift`.

Tests: `Tests/CoreTests/InformationDetailPageModelTests.swift` and `Tests/ContractChecks/test_information_detail_page_ready.py`.

Left: the view still loads through `SocialReadScreen` and does not read the new model. No DEBUG launch argument mounts the detail page. No screenshot. Commerce flags stay false. Xcode was not run.
