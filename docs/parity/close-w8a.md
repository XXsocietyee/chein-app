# CL-W8a close-the-gap report

Nothing here was compiled or run (Linux, no Swift toolchain). New Swift files in App/ or Core/ would need a
project.pbxproj entry (tools/check_scaffold.py asserts the file list), which this track may not edit, so all code
was added to existing files.

| row | what you built (file:line) | test (file::name) | remaining gap | hook needed |
|---|---|---|---|---|
| 0 pages/activity/official-detail/index (W4) | nothing new | existing OfficialEvent* tests | Only hosted SwiftUI tests fail at baseline on the iOS 27 simulator (env); no logic gap found. Re-run on Mac. | none |
| 2 pages/merchant/predict/index | nothing new: read parity, settlement gate (`permitsSettlement` false -> `.unavailable` state, App/MerchantPredictionInboxView.swift:317) and honest unavailable/stale states already exist | MerchantPredictionReadTests, MerchantPredictionReadCompositionTests (existing) | Settlement write stays gated (no grant, no route). | none; settlement needs an owner decision + grant |
| 4 pages/play/merchant/index | nothing new: `.writesUnavailable` / `.consentWritesUnavailable` notices already shown (App/PlayStoreDayMerchantView.swift:334-342) | PlayStoreDayTests::testProductionDefaultsSendNoWrites, ::testRequestsMatchMiniProgram (existing) | Live check-in/answer writes gated in the shipped config. | composition must inject an enabled PlayStoreDayService only once the grant exists (G1 files) |
| 6 pages/publish/fabu/index | nothing new: draft save, validation, confirm-then-submit and server-result display already exist (proof-pr5 row) | ProjectCloudDraftIntentTests, ProjectEditAuthorSaveContractTests (existing) | No SwiftUI button-tap test; routeRules stay local-only. A new AppUnitTests file would need a pbxproj entry, so none was added. | none |
| 8 pages/publish/temp/index | nothing new | TemplateAuthoringHTTPTests (existing) | No city-node-specific submit in TemplateAuthoringView; online publish gated by default adapter. | composition injects the live TemplateAuthoringRequestHTTPService (AppSession.swift:4669, G1) |
| 10 subpackageA/pages/infomation/infomation | nothing new (read-only, tested) | ProfileGuideReadTests (existing) | CSV owner may mark `exists`; status untouched. | none |
| 12 subpackageMember/character/index | Attribute level labels (mini `rules.levels` -> `levelLabel`): `CharacterAttributeLevel.read(rules:)` Core/CharacterSheetRules.swift:15; `CharacterCard.attributeLevels` Core/CharacterCardReadback.swift:75 filled while parsing the card (:211-217); passed to the sheet at App/CharacterCardReadbackView.swift:23 (row UI already rendered levels). 3D dice keeps a textual result (DiceRollerSession.announcement, existing). | Tests/CoreTests/CharacterCardReadbackTests.swift::testAttributeLevelsComeFromRulesLevelsAndDropMalformedRows, ::testAttributeWithoutRulesHasNoLevelEntry | Character save still has no server contract (stays "not available yet"). | none |
| 14 subpackageMember/mytemplate/mytemplate | nothing new | TemplateAuthoringHTTPTests (existing) | No view-level button test; writes live only when the adapter is enabled. | same as row 8 |

Not done (not in this worker's rows or blocked): image crop sheet (pages/crop/index is not an even-index W8/W4 row), external-game import (gate untouched).
Nothing was compiled. Level-label change touches CharacterCard's memberwise init (new defaulted trailing var); the only construction sites are Core/CharacterCardReadback.swift.
