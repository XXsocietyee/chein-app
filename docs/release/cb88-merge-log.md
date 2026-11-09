# CB88 lane reconciliation

Base: `origin/rc/20261108` `2f6d5041a57d876d3b0a953f56ecf5208089622f`.

Every `cursor/cb1` through `cursor/cb87` ref that exists on `origin` is listed below. A tip that is already an ancestor of the base was not merged again. Safe non-UI tips that were not ancestors were merged with `--no-ff` when `git merge` applied cleanly. No view conflict was resolved, because branches that edit App Swift views, DesignSystem, fixtures, or page-map were not merged.

Already on the base, and not merged again:

- Docs queue tip `8cac4681a592621c663c231991bda4f2c660fa21` (`origin/cursor/cb74`).
- Core/test queue merge `ab58518e4261537908141e02cbdaeb3002c442e6` (the merge of `origin/cursor/cb75` into the base).
- UI queue `origin/cursor/cb76` `3f56269b55f52ef9aeb2e50df0e0793f42d15ce4`.
- Tooling queue `origin/cursor/cb77` `23b99dde3bc6f345f8a62263fed1d2216c88a30e`.
- `.github/workflows/ios-ci.yml` is byte-identical to the base. It was not edited.

`origin/ui/d6` `b85ae2741cba5afe0a1320097833e69cb9eb23a0` and `origin/ui/d7` `4271e3694a6aef6c36be5395bb03e1c801349ebc` were not merged.

Version stays `0.1.0` (`1`) in `Config/Base.xcconfig`. `tools/current_ci_manifest.json` was not refreshed. `tools/bump_version.py --apply` was not run. GitHub Actions was not rerun. No test file was deleted. This VM has no Xcode and no Swift, so this log is not a build and not an XCTest run. `python3 -m unittest` on the five contract modules brought in or updated by CB32, CB33, CB51, CB55, and CB71 reported 35 cases OK. Those modules read source files. They do not compile Swift.

The merged `Questify.xcodeproj/project.pbxproj` keeps the lane registrations for `Core/SignInWithAppleFlow.swift`, `Core/UniversalLinkParser.swift`, and `Core/CB51LocalDiagnostics.swift`. Compared with a scratch run of `python3 tools/generate_project.py`, the project membership matches after ignoring file ids and list order. The checkout project was not rewritten by that comparison.

## Lanes

| Lane | Tip | Result |
|---|---|---|
| `origin/cursor/cb1` | `5f44d2cead78a5a4cb33fad31b196924f880f44b` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb2` | `d3c9f6d39e6d93d5974762d0fd683c5374504b1f` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb3` | `f273c806c04edd9395c993048f188791e937fb94` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb4` | `c1232ba82a780b49049a2b6d97b898bbde608c50` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb5` | `0f03149bd3334e7c55e01e0b3261bf9e1b6b7e3f` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb6` | `b82cbcc4031612f4704925e3794c1bd4094cd784` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb7` | `6c3dfe6bbccaac52768457bedd8fba723cead235` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb8` | `748e1c4b0e3c630eaee4e67df428c825e7dccb06` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb9` | `a7a11b9234b966b9c4d3e7fcc82ebe5d74b068ca` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb10` | — | Skipped. `origin/cursor/cb10` does not exist. |
| `origin/cursor/cb11` | `4ecbb385e45782a160a692bbbf07f4d0e6cd7a11` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb12` | `0379fa0f0511ba39c9972624db8c52d8018d6d13` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb13` | `a8e8793fa1efb44333a8fe7e23e52c1fa2fd30f1` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb14` | `70bde9230af9d13874717d85ac93a8ea63ab8716` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb15` | `8ba4e64c174b241c264debb59f4028534355bed8` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb16` | `4aba7815dfa34a730fb01f59950f8e734898b256` | Skipped. Edits App Swift views: `App/ClubDetailTabBar.swift`, `App/ClubGovernanceViews.swift`, `App/GlobalSearchView.swift`, `App/MerchantGameNodeView.swift`, `App/MerchantMarketingView.swift`, `App/MessagingHomeView.swift`, `App/NativeChannelProgressBoardView.swift`, `App/NativeFriendDirectoryView.swift`, `App/NativeFriendPickerView.swift`, `App/RoamBrowserView.swift`, `App/TopicXcxSections.swift`. |
| `origin/cursor/cb17` | `a25fc230c0591c3fdd03643b8b023c34163db0c2` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb18` | `d3908c3a5db1749f4b6d4931fdd9370bca3bed82` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb19` | `eb468b89f3b83a925ecbfa382724da6fb47251d0` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb20` | — | Skipped. `origin/cursor/cb20` does not exist. |
| `origin/cursor/cb21` | `36547e95352c7f4ae92b56080a96cebc8e838f8b` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb22` | `6776cffb9d3813d6080f400c38eaea65f97a9b0e` | Merged. Core retry bounds and truncated-JSON guards, plus `docs/release/cb22-quality.md`. Merge `6047b523591cce3154b3cc66201f5dc5d6a1a6cc`. |
| `origin/cursor/cb23` | `8ca9dfe1570ece813a4bf46212591974f570eeb0` | Skipped. Edits design-fixture screenshot tooling: `tools/design_fixture_screenshot_suite.py`, `Tests/DesignFixtureScreenshots/DesignFixtureScreenshotTests.swift`, and `Questify.xcodeproj/xcshareddata/xcschemes/QuestifyDesignFixtureScreenshots.xcscheme`. |
| `origin/cursor/cb24` | — | Skipped. `origin/cursor/cb24` does not exist. |
| `origin/cursor/cb25` | `bdc0e713b517c5c58376b9cca2d99d9d6da0f275` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb26` | — | Skipped. `origin/cursor/cb26` does not exist. |
| `origin/cursor/cb27` | — | Skipped. `origin/cursor/cb27` does not exist. |
| `origin/cursor/cb28` | — | Skipped. `origin/cursor/cb28` does not exist. |
| `origin/cursor/cb29` | — | Skipped. `origin/cursor/cb29` does not exist. |
| `origin/cursor/cb30` | — | Skipped. `origin/cursor/cb30` does not exist. |
| `origin/cursor/cb31` | — | Skipped. `origin/cursor/cb31` does not exist. |
| `origin/cursor/cb32` | `67d0b107eafaa1b97020b3848b19a8cdbcd0ba0b` | Merged. `Core/SignInWithAppleFlow.swift`, its contract and Core tests, and the app target registration. Merge `8fc9838d5e42d326da4217311ef885e508318078`. |
| `origin/cursor/cb33` | `ab93558a1a52258c167b501027893a34a9d7c138` | Merged. `Core/UniversalLinkParser.swift`, its contract and Core tests, and `docs/universal-links/cb33-associated-domains-plan.md`. Merge `8b0de76e636f923c7e945c408052a397f4d49d70`. |
| `origin/cursor/cb34` | `8af174556169d175f9d3dcf0a4195e0fb171dce1` | Skipped. Edits App Swift views: `App/RoamLiveSessionView.swift`, `App/RoamPosterScanView.swift`, `App/PlayKitNativeSensorProvider.swift`, `App/PlayNativeDeviceProvider.swift`, `App/RuntimeNativeLocationProvider.swift`. |
| `origin/cursor/cb35` | `11d46343910d70d63f734144a78cf8d17ceaa368` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb36` | `51c876d43863f0aa73b0c654078c78bd31816d97` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb37` | `7c998d8eefa739e125afabb9059c13ff3ff2490a` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb38` | `daef60be85ec2748587e774c4311192d22308120` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb39` | `5118b33e1e52aa2404cf87d4e122b7c951b16389` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb40` | `09adeff5f396f04de223616079a76c8e10a61104` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb41` | `360ef3fe595eaf23fb1a254f04ff6ebbfb3caf07` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb42` | `24dbbc07da0a4d9b96f6c8d249411696d3fd8380` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb43` | `540482dc5def579f1026366e7e7f009a2a9ad504` | Skipped. Edits App Swift views: `App/SettingsLegalDocumentView.swift`, `App/SettingsLegalSupportBody.swift`, `App/SettingsSupportSafetyEntry.swift`. |
| `origin/cursor/cb44` | `3cd082104813944ff8464a113d36c8799fa4f64f` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb45` | `8f19f66ce6340fd0fb6fecf689ffab073f250f18` | Skipped. Explicitly excluded. Also adds `docs/release/xcode-cloud-unsigned-archive.workflow.json` and `tools/bump_version.py`. |
| `origin/cursor/cb46` | `20c7e363952a7a2f93d778650f1e64b815f3c219` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb47` | `2b2ad6e02988f08e2ffe07f52c73633a756a8291` | Skipped. Edits fixtures: `App/DesignFixtures/D4Fixtures.swift` and `App/MerchantOnboardingFixtureSupport.swift`. |
| `origin/cursor/cb48` | `155290ee53f98385e645e086102c4c89d1171c6f` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb49` | `48f19094a3d34d55337e8345f09eb2da137b86ec` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb50` | `e466e6e63a0a98f07140379f096dc2636ac420e5` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb51` | `d06b6df4cd9ecae3158d7f6364eaf673c3ab2583` | Merged. `Core/CB51LocalDiagnostics.swift`, its contract and Core tests, and `docs/release/cb51-diagnostics.md`. Merge `44116b67cecd1880aaf555aaa8f8bd3e02c9c82e`. |
| `origin/cursor/cb52` | `58c4a26a3780cbc4388b1c7c47d69e3f75bc2332` | Skipped. Edits fixtures and an App Swift view: `App/DesignFixtures/D4Fixtures.swift`, `App/MerchantOnboardingFixtureSupport.swift`, and `App/GlobalSearchView.swift`. |
| `origin/cursor/cb53` | `527dc11eb17416300b146d42e5f110ea00286520` | Skipped. Edits DesignSystem: `App/DesignSystem/CYConfirmSheet.swift`, `CYDomainPalette.swift`, `CYDomainTabBar.swift`, `CYHeroHeader.swift`, `CYImageCard.swift`, `CYListRow.swift`, `CYPillButton.swift`, `CYSkeleton.swift`, `CYStates.swift`, `CYStatusChip.swift`. |
| `origin/cursor/cb54` | `e58827453ba453e46890c370c384bc5713f24a5a` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb55` | `b75bdd223396844fcc6592e185b18c9d0cad68aa` | Merged. File-timestamp reason `3B52.1` in `Resources/PrivacyInfo.xcprivacy`, with the matching contract and `tools/archive_unsigned.py` expectation, plus `docs/release/cb55-privacy.md`. Merge `e87d3dfc82abeebd922903a39c4f8ce97942bbad`. |
| `origin/cursor/cb56` | `8c465a66bfeacff783441d7a4bbd8bc045b5c653` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb57` | `c5aaf2a908db5c96c30a2aafc465b19f120b2d48` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb58` | `c1d277187126a9e3dffca2baf674a78f06ae737b` | Skipped. Edits App Swift views: `App/ChallengePOIView.swift`, `App/CharacterSheetDetailView.swift`, `App/CoopRelationDiscoveryView.swift`, `App/SocialGuideViews.swift`, `App/StoryRuleEditorView.swift`, plus `App/AppSession.swift`, `App/ProfileGuideHost.swift`, `App/SessionMessagingEntry.swift`, `App/CoopRelationPostFeedFactory.swift`, and `App/IMCoopInviteStripFactory.swift`. |
| `origin/cursor/cb59` | `8f30ce427e564de473338139ccc8fcbe57a4901f` | Skipped. Edits `docs/parity/page-map.csv`. |
| `origin/cursor/cb60` | `776df1ac780242cfa7529491367bdb9b4f6e0884` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb61` | `b5160d8546931480f6c4bdab47f440f920f3a284` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb62` | `101da89245e808714bcfc5d2510e2489d9c6da6c` | Skipped. Explicitly excluded. Also edits App Swift views and DesignSystem: `App/CityMerchantOperationsView.swift`, `App/QuestifyApp.swift`, `App/SessionExpiryNoticeModifier.swift`, `App/MerchantAuthoringLocalization.swift`, and `App/DesignSystem/CYConfirmSheet.swift`. |
| `origin/cursor/cb63` | `8f92c0fccddd67092384016738a483cf08725e11` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb64` | `1c75a0a172a548257985b9ee162ecc35de5a1e7d` | Merged. Adds `.maestro/club.yaml`, `.maestro/settings.yaml`, and `docs/release/cb64-maestro.md`. These flows launch existing DEBUG fixtures. The branch does not edit App Swift views, DesignSystem, fixture sources, page-map, a GitHub workflow, or `tools/current_ci_manifest.json`. Merge `c05a0dc402c79a2d28debd81b94f4d0b798a7454`. |
| `origin/cursor/cb65` | `8b87511a195de02234382aab27f4579c6b4537bb` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb66` | `207cae380d8b0ac1ae40ba987e953f4a9a0e4116` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb67` | `39240f389363afde060cdf79d4c06a893ea17880` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb68` | `6d3187fec62e9fd954860125d1be8af11bc30617` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb69` | `3a6f51026eed2482180c7d94ecea73359f6c950f` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb70` | `79c04fdbb0671dbfd27680fa9e004be07f98b57f` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb71` | `f9c5e19c013f6e0e01a8f332b81c71abc1a99ef6` | Merged. Adds assertions in the offline-pack, play-session, and regional-configuration tests. No production file and no test was deleted. Merge `cc8a992791e18d5fc8c986ca133f9de3f0be8818`. |
| `origin/cursor/cb72` | `1f4c9c565a0f6c34137c81a548066ce2f6b63226` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb73` | `0f6926d9db9270760e423bbc9b50489df15ecfc7` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb74` | `8cac4681a592621c663c231991bda4f2c660fa21` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb75` | `0024665b41de7fea993cf3a101db578ef3878656` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb76` | `3f56269b55f52ef9aeb2e50df0e0793f42d15ce4` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb77` | `23b99dde3bc6f345f8a62263fed1d2216c88a30e` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb78` | — | Skipped. `origin/cursor/cb78` does not exist. |
| `origin/cursor/cb79` | `8c186c6eecd9553da4ba57a1e96ccc51372ec2ee` | Merged. `docs/release/cb79-ledger-prep.md` only. Merge `47c9dd73ec4cd399691369abc007d8650f9fbd33`. |
| `origin/cursor/cb80` | `f719bcbc78b05ef053451eb149732411df1aa2cb` | Merged. `docs/release/cb80-gate.md` only. Merge `5dacc09607eb91640e1ba075bc6a026e954d1fa9`. |
| `origin/cursor/cb81` | `dca94228a905a86279d92ca28e260aa46d707a4a` | Already contained in `origin/rc/20261108`. No merge commit. |
| `origin/cursor/cb82` | `b92b1defb715c4c154b153516c1f1262b33acfe9` | Merged. `docs/release/cb82-release-build.md` only. Merge `82fa55a561c75ca105ebbca50682219dce0e0f89`. |
| `origin/cursor/cb83` | `b1f8a33ea2d0cb5781dc669dcea3c831b0ae0e2a` | Merged. `docs/release/cb83-sendable.md` only. Merge `988fbddf515ac84ce13de303e9785eb884aae320`. |
| `origin/cursor/cb84` | `a631e431158d2136bdfd8f30fa905897f558b4f1` | Merged. `docs/release/cb84-flaky.md` only. Merge `b4f05abd5dd744a8885f79c6f6e6b24043b950e6`. |
| `origin/cursor/cb85` | `dec264d7c3c2c6d7f78e213043b87c6e9534e939` | Merged. `docs/release/cb85-parity.md` only. Merge `43e341dfa6cb22b9d39e6cdeb5e076444956fd3b`. |
| `origin/cursor/cb86` | `8289db4d1cf23f2522a399a821d81cebca2ba0e8` | Merged. `docs/release/ui-fixture-index.md` only. Fixture sources were not edited. Merge `1f713a15f0c8b849b43d41fef1832c9ed3e885a6`. |
| `origin/cursor/cb87` | — | Skipped. `origin/cursor/cb87` does not exist. |

## Merged by this branch

- `cursor/cb22` `6776cffb9d3813d6080f400c38eaea65f97a9b0e` → `6047b523591cce3154b3cc66201f5dc5d6a1a6cc`
- `cursor/cb32` `67d0b107eafaa1b97020b3848b19a8cdbcd0ba0b` → `8fc9838d5e42d326da4217311ef885e508318078`
- `cursor/cb33` `ab93558a1a52258c167b501027893a34a9d7c138` → `8b0de76e636f923c7e945c408052a397f4d49d70`
- `cursor/cb51` `d06b6df4cd9ecae3158d7f6364eaf673c3ab2583` → `44116b67cecd1880aaf555aaa8f8bd3e02c9c82e`
- `cursor/cb55` `b75bdd223396844fcc6592e185b18c9d0cad68aa` → `e87d3dfc82abeebd922903a39c4f8ce97942bbad`
- `cursor/cb64` `1c75a0a172a548257985b9ee162ecc35de5a1e7d` → `c05a0dc402c79a2d28debd81b94f4d0b798a7454`
- `cursor/cb71` `f9c5e19c013f6e0e01a8f332b81c71abc1a99ef6` → `cc8a992791e18d5fc8c986ca133f9de3f0be8818`
- `cursor/cb79` `8c186c6eecd9553da4ba57a1e96ccc51372ec2ee` → `47c9dd73ec4cd399691369abc007d8650f9fbd33`
- `cursor/cb80` `f719bcbc78b05ef053451eb149732411df1aa2cb` → `5dacc09607eb91640e1ba075bc6a026e954d1fa9`
- `cursor/cb82` `b92b1defb715c4c154b153516c1f1262b33acfe9` → `82fa55a561c75ca105ebbca50682219dce0e0f89`
- `cursor/cb83` `b1f8a33ea2d0cb5781dc669dcea3c831b0ae0e2a` → `988fbddf515ac84ce13de303e9785eb884aae320`
- `cursor/cb84` `a631e431158d2136bdfd8f30fa905897f558b4f1` → `b4f05abd5dd744a8885f79c6f6e6b24043b950e6`
- `cursor/cb85` `dec264d7c3c2c6d7f78e213043b87c6e9534e939` → `43e341dfa6cb22b9d39e6cdeb5e076444956fd3b`
- `cursor/cb86` `8289db4d1cf23f2522a399a821d81cebca2ba0e8` → `1f713a15f0c8b849b43d41fef1832c9ed3e885a6`

## Skipped

Missing on origin: `cursor/cb10`, `cursor/cb20`, `cursor/cb24`, `cursor/cb26`, `cursor/cb27`, `cursor/cb28`, `cursor/cb29`, `cursor/cb30`, `cursor/cb31`, `cursor/cb78`, `cursor/cb87`.

- `cursor/cb16` `4aba7815dfa34a730fb01f59950f8e734898b256`. Skipped. Edits App Swift views: `App/ClubDetailTabBar.swift`, `App/ClubGovernanceViews.swift`, `App/GlobalSearchView.swift`, `App/MerchantGameNodeView.swift`, `App/MerchantMarketingView.swift`, `App/MessagingHomeView.swift`, `App/NativeChannelProgressBoardView.swift`, `App/NativeFriendDirectoryView.swift`, `App/NativeFriendPickerView.swift`, `App/RoamBrowserView.swift`, `App/TopicXcxSections.swift`.
- `cursor/cb23` `8ca9dfe1570ece813a4bf46212591974f570eeb0`. Skipped. Edits design-fixture screenshot tooling: `tools/design_fixture_screenshot_suite.py`, `Tests/DesignFixtureScreenshots/DesignFixtureScreenshotTests.swift`, and `Questify.xcodeproj/xcshareddata/xcschemes/QuestifyDesignFixtureScreenshots.xcscheme`.
- `cursor/cb34` `8af174556169d175f9d3dcf0a4195e0fb171dce1`. Skipped. Edits App Swift views: `App/RoamLiveSessionView.swift`, `App/RoamPosterScanView.swift`, `App/PlayKitNativeSensorProvider.swift`, `App/PlayNativeDeviceProvider.swift`, `App/RuntimeNativeLocationProvider.swift`.
- `cursor/cb43` `540482dc5def579f1026366e7e7f009a2a9ad504`. Skipped. Edits App Swift views: `App/SettingsLegalDocumentView.swift`, `App/SettingsLegalSupportBody.swift`, `App/SettingsSupportSafetyEntry.swift`.
- `cursor/cb45` `8f19f66ce6340fd0fb6fecf689ffab073f250f18`. Skipped. Explicitly excluded. Also adds `docs/release/xcode-cloud-unsigned-archive.workflow.json` and `tools/bump_version.py`.
- `cursor/cb47` `2b2ad6e02988f08e2ffe07f52c73633a756a8291`. Skipped. Edits fixtures: `App/DesignFixtures/D4Fixtures.swift` and `App/MerchantOnboardingFixtureSupport.swift`.
- `cursor/cb52` `58c4a26a3780cbc4388b1c7c47d69e3f75bc2332`. Skipped. Edits fixtures and an App Swift view: `App/DesignFixtures/D4Fixtures.swift`, `App/MerchantOnboardingFixtureSupport.swift`, and `App/GlobalSearchView.swift`.
- `cursor/cb53` `527dc11eb17416300b146d42e5f110ea00286520`. Skipped. Edits DesignSystem: `App/DesignSystem/CYConfirmSheet.swift`, `CYDomainPalette.swift`, `CYDomainTabBar.swift`, `CYHeroHeader.swift`, `CYImageCard.swift`, `CYListRow.swift`, `CYPillButton.swift`, `CYSkeleton.swift`, `CYStates.swift`, `CYStatusChip.swift`.
- `cursor/cb58` `c1d277187126a9e3dffca2baf674a78f06ae737b`. Skipped. Edits App Swift views: `App/ChallengePOIView.swift`, `App/CharacterSheetDetailView.swift`, `App/CoopRelationDiscoveryView.swift`, `App/SocialGuideViews.swift`, `App/StoryRuleEditorView.swift`, plus `App/AppSession.swift`, `App/ProfileGuideHost.swift`, `App/SessionMessagingEntry.swift`, `App/CoopRelationPostFeedFactory.swift`, and `App/IMCoopInviteStripFactory.swift`.
- `cursor/cb59` `8f30ce427e564de473338139ccc8fcbe57a4901f`. Skipped. Edits `docs/parity/page-map.csv`.
- `cursor/cb62` `101da89245e808714bcfc5d2510e2489d9c6da6c`. Skipped. Explicitly excluded. Also edits App Swift views and DesignSystem: `App/CityMerchantOperationsView.swift`, `App/QuestifyApp.swift`, `App/SessionExpiryNoticeModifier.swift`, `App/MerchantAuthoringLocalization.swift`, and `App/DesignSystem/CYConfirmSheet.swift`.

`origin/ui/d6` and `origin/ui/d7` are outside cb1–cb87 and were not merged.
