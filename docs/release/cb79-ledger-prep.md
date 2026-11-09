# CB79 ledger prep

This note lists every current-checkout inventory entry that differs from `tools/current_ci_manifest.json` on `origin/rc/20261108`. A later ledger refresh would rewrite these rows in `snapshot`. The refresh is not applied here. Whether to approve that refresh stays with the owner.

Entries listed: **175**.

| Kind | Entries |
|---|---:|
| `snapshot.sources` row added | 66 |
| `snapshot.sources` row sha256 change | 71 |
| `snapshot.sources` row removed | 0 |
| `snapshot.native_methods` identity added | 38 |
| `snapshot.native_methods` identity removed | 0 |
| `snapshot.native_methods` path change | 0 |
| `snapshot.portable_methods` change | 0 |
| `snapshot.device_only_methods` change | 0 |
| **Total** | **175** |

## Basis

- RC commit: `89dcba807e7e5439182ff8852d6600d1fa9fdd49` (`origin/rc/20261108`).
- Manifest bytes compared: `tools/current_ci_manifest.json` sha256 `1fe23eff35e513db5b7499e23a1c0cd23cba647193e51b57d6c9de75a09e81c7`.
- Live inventory: tracked files at that commit, hashed and parsed the same way `tools/current_ci.py` builds `snapshot` (`sources`, `native_methods`, `portable_methods`, `device_only_methods`). `tools/current_ci.py refresh` was not executed. The manifest file was not written.
- App version stays `0.1.0` (`1`): `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`. The ledger document `version` stays `1`.
- Stored manifest fields left as they are: `comparison_base` `5f318716e596dcd12ad2b84e83ad85046ce99f73`, `required_since` `2c2b9d7465605e2275ac8f9474262e67b73b08d8`.
- An inventory entry is one source row (`path` + `sha256`) or one test-method identity (`method` + owning path). A source row is listed when the path is absent from the manifest or the sha256 differs. A method identity is listed when it is absent, removed, or points at a different path.

Recorded snapshot size on the manifest: 8738 source rows, 24328 native methods, 7145 portable methods, 8 device-only methods. The live RC snapshot is 8804 source rows, 24366 native methods, 7145 portable methods, 8 device-only methods.

`snapshot.sources` skips `tools/current_ci_manifest.json` itself. This prep note is not on the RC commit, so it is not one of the 175 entries. A refresh run after this note is committed would also add `docs/release/cb79-ledger-prep.md` to `snapshot.sources`.

## Source rows that would be added (66)

These paths are on the RC and absent from `snapshot.sources`.

| Path | RC sha256 |
|---|---|
| `.github/workflows/ios-ci.yml` | `30f17890b49392ae76d598faf3b315ac85d47e92da9cbf2dff9450aeb36ab9c9` |
| `App/DesignFixtures/D2Fixtures.swift` | `bd9d3a17778fd24de7fdec260384dbce757d922ae98ad43a9d45746c6ef3d1e0` |
| `App/DesignFixtures/D4Fixtures.swift` | `15bede912a6bc4f486b86a077795f0dd08f8f3850ffffe6669961dfa5c2d2e84` |
| `App/DesignFixtures/DesignFixtureRegistry.swift` | `9b7d5ffc97a4888286f19e876e6db6ab77dd13bb80ae1ad4eabcba25bc030e38` |
| `App/DesignFixtures/KitGalleryFixture.swift` | `9cf269e4a09d21196484fc26af6676c8f7e6352ef036cc862dea8f5a11e2a2bf` |
| `App/DesignFixtures/OnboardingFixtures.swift` | `882f9a3bdc6f4aeee0c6719a8d0946beb2db336e0f18682817a1844c676230fa` |
| `App/DesignFixtures/OrdersWalletFixtures.swift` | `f90084f829babd6b7e9f395d71e1a8f5c79ef2ecf7409b45e08ee14e55b88109` |
| `App/DesignSystem/CYHeroBanner.swift` | `d3befce54339fbb3f80c2abfcdfc2412700390f716bd1c14b20d501593aa4d6e` |
| `App/DesignSystem/CYHeroHeader.swift` | `46b1db5d5d60f8c0de8b900f9f9ddd42569d6c62dc629f4775e571351e801285` |
| `App/DesignSystem/CYImageCard.swift` | `afb12ed23201c2b990ba2f8da57d8408447cb97c4a1426e5e37392723b0dbc11` |
| `App/DesignSystem/CYListRow.swift` | `90d3104695829b765710657dbd57709c2eba32bae94b10691d7f7d4fc74c76c4` |
| `App/DesignSystem/CYPillButton.swift` | `24553c7ad1f512782d825ede3ed04ed14492e2fdfb882cbc874c645ac12eb9ab` |
| `App/DesignSystem/CYStates.swift` | `b5dd0793b8a3c5c1f20511ed271804396a87b0d6cb84d509f5acc3ec94cd3ce3` |
| `App/DesignSystem/CYStatusChip.swift` | `5ce2f9606bb2d00710a7a1f5417c662f063827f2c97fbc13a2783228934cad3a` |
| `App/OrderCardComponents.swift` | `281b1ba234e0e70f46a74b9d7dfcc82f20f017fbdaa850aad33773a5436e17ec` |
| `Core/PWaveP2AffiliateCenter.swift` | `821aa3e023b401bd8725c7d99974d71e28f9c3883594e92c45594abc5d75e31b` |
| `Core/PWaveP3ThemeCollection.swift` | `dc0049e1b83673cdd159304da981529ba19181bd9dbdfb6113520fd8d28a96f3` |
| `Core/PWaveP6CityPass.swift` | `e58641cdb2d388cf64c52d94d8e7efb07042ca36966d13706abb11c79398c796` |
| `Core/PWaveP8RunMemory.swift` | `cffabb7c09373e9aaf0aa21dc788aad2e853d497b136ffd70ed218e12bc9efd8` |
| `Core/PWaveP9Boards.swift` | `69f8bd577d6782cef12fdd457e8a568ffeb49f87fd08632391e6b73a21b63f86` |
| `Core/PlayActionReceipt.swift` | `2db9c4ebe9dda9b88a311355a7e67b2ecc31b8e982af575c4d10efd688ae09ad` |
| `Core/UGGameplay.swift` | `b535b467aa7238ca37c5786c4a671637df7f79f6c378ab65e2fd801b58ac7090` |
| `Core/UGGameplayReader.swift` | `d58beac701123392031126abd677247e9c16d558d465620a856b913b004e7842` |
| `Tests/CoreTests/PWaveSecondWaveTests.swift` | `b6e2a007ebdc839685097c66a604283560ce292658d4c16b80711a6f068a82a8` |
| `Tests/CoreTests/PlayActionReceiptTests.swift` | `769d8f8e9290b412d085c680d85597d5363515bb5dd784e6af094436a3315e7e` |
| `Tests/CoreTests/UGGameplayTests.swift` | `a676f4198a4b47d7e6ba758e78c9d06b52a0e0ef786ae8930126e23d2dd92fa5` |
| `docs/release/app-store-metadata-checklist.md` | `f2b2c97a3ca6503b8fd85560a7b9af5232afa3d54bec232715f758a3789f42b5` |
| `docs/release/cb2-core-unexpected.md` | `e8125dfe0d9957b5189aba7c568e6041187ef64067b7404429c88e1c8842e01b` |
| `docs/release/cb3-appunit-groups.md` | `46e7780a670ae88ad4018c854f71e467b213be9c47c05dc1c16a58d5c8b49acd` |
| `docs/release/design-report-K-shots/kit-2.png` | `436ac23b95ede9c3b493c18393a4fd235d7018a083f08cf13033756d2ac7cd23` |
| `docs/release/design-report-K-shots/kit-merchant-2.png` | `7b8a25e26a8faec300368aec4fc95f99128e88eed201c844e435ab487e77d7db` |
| `docs/release/design-report-K-shots/kit-merchant.png` | `82ce80350c5fb9b3d05f325d09f361ad8dcc1fc231fd7cab1dce75c0282bfccd` |
| `docs/release/design-report-K-shots/kit.png` | `796dbbf8ac2b06f1185b307e5d95f18f01f25c70461eb856e0882f7671995349` |
| `docs/release/design-report-K.md` | `3bf1297885bd8113d38b8c206617d5f2d135f1d7efb0b140ee4c378941b98cc5` |
| `docs/release/design-report-d1.md` | `f575daaf0664e84fbcc93124945287624a877b5ba4bc3921e10127bc256f8558` |
| `docs/release/design-report-d2-shots/compare-home.png` | `207c1a57918014c088ddaa02e767eb1270cba66f47a1282928ce619889c2e78c` |
| `docs/release/design-report-d2-shots/compare-roam.png` | `c992d446cb58d41ffeb6e6d365552e8d20ca9661cc4cfa6b29339f7c755e74bb` |
| `docs/release/design-report-d2-shots/compare-search.png` | `475684d8cc5898fc0f25fc29d000605bf72af6276c0d7c35aab8e0001a8b7544` |
| `docs/release/design-report-d2-shots/compare-square.png` | `bafb579a358003dd4ba37c4a4fd285cb04a5adff70ace059216c39d19519e6ef` |
| `docs/release/design-report-d2-shots/home-en-dark.png` | `4d7aee9a71f98defe3e4a8bddfe9117f4ebb61c5bb108282254d2d2ef9ccba3f` |
| `docs/release/design-report-d2-shots/home-zh-dark-XL.png` | `e6d8b657edd4cc58b8f92ccd9760311b86908acacbfe64485a45ee85c9f7ed7f` |
| `docs/release/design-report-d2-shots/home-zh-dark.png` | `93619d0c1fec5078f1b0f44c6505e6e6cb5543856016b19a1903a50dea0e5703` |
| `docs/release/design-report-d2-shots/roam-en-dark.png` | `a798ce685b238ffc8ac1802a58ece0c4e8e2285ad0ebf704ad6218fe0fc99e3b` |
| `docs/release/design-report-d2-shots/roam-zh-dark-XL.png` | `5a09c36bf949a7b365cc9ee82a306e8ba48beca80a1df25cec5513939aa228bd` |
| `docs/release/design-report-d2-shots/roam-zh-dark.png` | `2c459d8526937db4ebf52a8af9bc28ef4b708a5ab29d033e47025c2858837b08` |
| `docs/release/design-report-d2-shots/search-en-dark.png` | `2383ae1794016f9abfbb39d3fe2810e5c4dd1ca8dcafd843c4fac48399d36b17` |
| `docs/release/design-report-d2-shots/search-zh-dark-XL.png` | `062234473cdfe6557d1c459d6671b082ab02cafc31b5a0902f559a71e6241fcf` |
| `docs/release/design-report-d2-shots/search-zh-dark.png` | `43df327a1f8f312f538bc70354dc00f3f6f73968c07e8460b74b10c7627552ad` |
| `docs/release/design-report-d2-shots/square-en-dark.png` | `85bbb2bc47ed5648e8fa33bfedb12b2873b0a53fbdc5419537a6cff20d2d9286` |
| `docs/release/design-report-d2-shots/square-zh-dark-XL.png` | `ab7cf318bc5bd2f1e4eccceb10dbd0998be0bb86163d6168cd644ee45764d801` |
| `docs/release/design-report-d2-shots/square-zh-dark.png` | `c6e50b4a34baef107e3f2154d9fa97e71841c63e26eddacf09d28425b604f5a5` |
| `docs/release/design-report-d2.md` | `3c68346b0309966c5d5064b8fe6a0db4bfb781a4ae8fbd3313be0a5c41704511` |
| `docs/release/design-report-d3.md` | `53c271d8c856d8eaea203a10c588b79637fc6a13108efc268c439720ce3c034a` |
| `docs/release/design-report-d4.md` | `e70ed91d531e1a1187bbd8b699e21379c36db7939a62096ae3f34a6cbb270b52` |
| `docs/release/design-spec-d1.md` | `31a979289f6792540c985d40dbed8e81b1fdd124778a50491d52a170187d7961` |
| `docs/release/design-spec-d2.md` | `1aa9339074facd0621e19f2097764ae4a2f67a0deb109d302f3a650b38f4da8f` |
| `docs/release/design-spec-d3.md` | `f11050754639f879cdec95755abc0c6c6960be38bfce1934d5c0f5d1a5296cba` |
| `docs/release/design-spec-d4.md` | `c8633dcfd0336aacf2af6e2e8ab323613c449ba60429198bc6edc4959eb23532` |
| `docs/release/staging-schema-rehearsal.py` | `890c3b779fc351c52f04c696ddfb2ca3fd1d9b9d32237a6b6c97dc89ce532cfa` |
| `docs/release/ug-core.md` | `68d9c99dfc72e4f2c50fc6bee3209ffcffd20970f5e5cd86c20a7e02afcccc47` |
| `docs/release/ui-strings-d1.json` | `ffc93434876c3d86ddaec95807a7d525a05b274b298afc5f7e982bffa84e552a` |
| `docs/release/ui-strings-d2.json` | `a3c4e744a0c7e1abe352453af6efb55114337395d6713ee4e75edfca34f083b4` |
| `docs/release/ui-strings-d3.json` | `a92353d2427e2e213881571d4059feadb65d3d8a83ae95056cb4cb5b7b66b431` |
| `docs/release/ui-strings-d4.json` | `8a5fe633c9fd3c826373a75e42c5b9f0d1053588175e2b668cf1c77ce94cb55c` |
| `tools/archive_unsigned.py` | `30c471334a79fcad47f318190711e2a004abdf244fff30608e724ae0034525e7` |
| `tools/check_account_deletion_path.py` | `4788c92be708316d31f797a36a5c8f1937e38895a2a6820d47b94f136f3704be` |

## Source rows whose sha256 would change (71)

The path is already in the manifest. The live file bytes hash to a different sha256.

| Path | Manifest sha256 | RC sha256 |
|---|---|---|
| `.maestro/consent.yaml` | `b98dd0eb1c2367ea6902307cc65a14b0b47a2a84e40b234d2ed594a091c9b3bc` | `fcea09e3b977e591a1622f4a9e8d61adf8ad470a2abd888ddff792fdb6261d1f` |
| `.maestro/launch.yaml` | `35f04b1b5dec5e139506f25c47d79048e7a59fb159a995837d37a0095fe09da7` | `11f29935f320988d33f746ae9bdb778af7bd0e325f4db2b7c2797df20e0eb0bf` |
| `.maestro/sign-in.yaml` | `be1539de1199049fb77a0fe907ba100dde86636b250e6f2ba7530b24047a4b29` | `2b98d73bd722c06d82bda21c6b6ee3647af7c10bc663dc076a7692ece9a59542` |
| `.maestro/welcome.yaml` | `d87b0241bc41c32ab3e9452d6233072025a7a80fd63ba022d7b43ffbb994ba6a` | `dd6968b3a92051b498f156c3ce0a446427eb8f93682286a2890eabd07986956c` |
| `App/AccountCollectionComponents.swift` | `74c8e2d5ce1b6c56d046bea62a7ed9200199200bc59b48d883c60577e44b6321` | `b9559988f1d44a35151dbcd577af999ee16170e9943910ba9cc03cadfec126de` |
| `App/AccountCollectionCouponsView.swift` | `9312ebdc547210a37bea6e110b4b911bd27756c1bd5d63db1ccebf638ab4ba84` | `2525fc84b07f0f5666337086dc11f5b4f1915513655733c0f337af06a965dbc2` |
| `App/AppCompositionRoot.swift` | `33ea9a9a12749720a2f9087d3324034f8578eea454966ed61e8360a45285ec75` | `52ee03a2f7907746ebc3584eb3da16cc53f44875626093df17f853f9a5e97f39` |
| `App/AuthChannelView.swift` | `9a8bf785085ddb5bcfb2bfb33803b09ecdeb32d1167dbd3292fad5a01eb146bc` | `64cb89cb7b3c1d93a86d70c6cc9e525c0d6662df2aaa13f5dbf5797cd585b28f` |
| `App/ClubActionPanel.swift` | `079a8ecd961cf8403a6caa41a7b2bceed5eecc099828852e35dd051f2267e5a2` | `b81adf5c2f489a69ccde0d9422b058fb8c3d3b956334032ea84f07c7b581c40d` |
| `App/ClubChannelMessagingView.swift` | `c933adfc3571366cf23a9e449418d4c613b24c06e1ed722bc1be0dc09a9e66e7` | `fbc6e14cbe440c54fef4acb81b25ca0329faf3534cc6c563d5c84fd1169693f5` |
| `App/ClubComponents.swift` | `5978607da618d68a69206b321444f98c48c4b1eaf09533dd4aec7fc8701e358d` | `6eb5117a16a491687db380ca0fa05e26ffd08961044553717a3b7871a0f7873c` |
| `App/ClubDetailView.swift` | `82a88c298f548f903e00fede9fea37308d3a2eed54de0b69dda98ee9629126a2` | `5d32cae59fed435b0d54f147ec214f214d1ae6d93c3080b2ab6960cf5b83fbee` |
| `App/ClubDirectoryView.swift` | `a6929c5fd815e0f81471b3907a9a6f0a57d0fd70cac481dd4b171860cb811045` | `fc368bb05201ed0b3a21dfe6f6497353f6f6f8dc8206b22130d8110ecaaa1dbf` |
| `App/ClubEnrollmentView.swift` | `d058529ac2a9fd08dbb5da346fa6f4370bdb88e67cda22bcc174e07600fe8fe2` | `01524fdf15732473232210e9c3f0043a030ca8f65db974f40e7015b9e86d722d` |
| `App/ClubGovernanceCommandForm.swift` | `af2d72cdc6ee8014b20dddd47ab4cb0d37afac7928df6d556d647dde83307888` | `b597e7b8bc34f9ceceda2bddd9b43efa05059b67edf8743228a9f47682f8cf32` |
| `App/ClubGovernanceViews.swift` | `ed670c31699d286ac35cef34bb92639383b226cda91a30ddeb23ed6c72c59d7b` | `36e84be1fd0b8f5f8c17469a729a96d660aa467154390d4f62e4c701a5c42b1e` |
| `App/ClubOperationsViews.swift` | `31e1c47573a5a03303707b33986b774f273f9bb69cffd4efa09e2c3f1841311d` | `cfd2a530cee869630c0ecf87e6f4c8fb9c599f8ab0b1075badbc39f121cf17a3` |
| `App/ClubRoleAssignmentPicker.swift` | `8ab5edced0b28b7075891e36616804feb263eaf2fdae6a19d6502d0c7c7e5f4b` | `73fbd88cc92b8d64b123949fe8ecad754f691ea389b8c216bb4cd4c88449d501` |
| `App/DesignSystem/CYConfirmSheet.swift` | `78ab4f3af62a5adb92a3539927a649230634eadf0aad6228a0d0cad5b3fc21a5` | `ef01914321b4c2855973d0382122369f9772c282f7c9ecf4fe7acb53da14c51e` |
| `App/DesignSystem/CYDomainPalette.swift` | `47f1fd07c279ff5eb1bacd5afc452f000da4f70f50dfee1123759ad918e02744` | `41336b6c225b08341bc6b34ba2d0772958dfd0ea250ae7c76c72111f8776851f` |
| `App/DesignSystem/CYSkeleton.swift` | `79ff3b42e2fce4a7c21ed17bfcbf380691caa8546a0da1bb647af77808a9259c` | `2df3f79b92db2b96cceb4f43b94f744190ae853a3181eb2148071b7f9207ae42` |
| `App/GlobalSearchView.swift` | `e57e02774fc92f06c9e557e5f7199cbab114dd05032385da2947f378f4de0173` | `6548654029d1ad58950295030140cc2c0cb6fb9e5e8e97ebccacd27ec5152408` |
| `App/GrowthCenterView.swift` | `5b8165fd2f2a6121351181bc22e3739a22f7b0f4872a4b9d34f916eaf932140f` | `7b9254c62149345fa200171616ffeb7276113ec15df203ef8a318f8aca5d5e38` |
| `App/GrowthLeaderboardView.swift` | `416a8e30c9527fd132b6df859ee74536d15f5db69176f41f3cd2e7db6bd5f4a5` | `5fc003af0bae04aae51855fb80611c1332ced8c976b4759510d26eea21e139c2` |
| `App/HomeFeedFixtureSupport.swift` | `7ecfd97dfa892d6ff6c441d77caf9ee17aa3317cca5e61abf9cab7b5e0dd23e4` | `cbd704405929122e5b62a6adb890ba04ece142ebb88049c02aa4a672b0fb056f` |
| `App/HomeFeedView.swift` | `2ce12a78f569d518e31c16b9217a3ae6e30d6ee4ff959a56d62dbc43cbf9b2ff` | `d7a699722bcfc61ed72403c3116536ea4cc2c2193696fff6cd1b1a5bdf9dc2b5` |
| `App/HomeSearchTabParityViews.swift` | `237a4fdee20fc86e227d040d0740a8c08224a2050b949ba552a9064026749bac` | `c64a166d297466e4e8b2173d3de7e031085a8ea2405d7b0f98d9389b368fc194` |
| `App/LoginView.swift` | `b3708c4d7973b30e556a28cbbd08612b82d75171e1a649e27271ef1186d86dec` | `bfc2cf928f9891039ce4f7cdddb5770963d91ef4f7d9f46ee8e9b168f3ddbb33` |
| `App/ObjectBadgeViews.swift` | `2c8d7382bd2e501041c54288d1d0097dc9e7c4a3319e196b5859c9bf13c3ace8` | `3b07b5cdace9ba2e488d7371367b466ec62c029e4163f826ddd1b4e09cd37553` |
| `App/OrderLifecycleView.swift` | `49824276e07bc5fca52de60a5f3f919a316b6cafc4c0e1ffc1086921e3f2d11a` | `faa6332d9fe5574dea07fd1c900caedb4568afae8d288e6e976a51034f8bb352` |
| `App/PrivacyProtectionView.swift` | `802adb2cabe92bed875394bb6c479cb2262cac494d2f4e2a0066cd5c9bc80331` | `e9de5222132589afdcee1805dcc715feb3ac496743324e3d0282d12d7a8df4b5` |
| `App/ProfileOrderFilterFixture.swift` | `d014a41fe3ff198f4b751f963a2b9b81b52fef0ff9329bafc6e66f9fad95b43a` | `c1d06f3e1fceea9013f34d7f2d69fcecd4dbc7da8cc64d0780d93b46bbb3e049` |
| `App/ProfileOrderFilterSection.swift` | `892b874dcbfaa7cf194932bdea7a6bbda851b7becf7a1305d6b371ef8a44f0b0` | `740d18a4bb9d3581d28980dfb834c117de4618e2014afb6fcaa687d92c887335` |
| `App/ProfileOrdersView.swift` | `6f146b1552e1a5a1008e47d1d33414ea889ce0549e8542485a666603366ef7d5` | `353bb2537c4ab6143f6b80dcbf48fb7305669f748e5ff5ca61dd6da2a576c7af` |
| `App/QuestifyApp.swift` | `e486e19da865d03ef3b297e52b78bab924b50052b3d81c5fef111e8186f8e9ee` | `731686e223c0e6ba3e6206f8c339748e38cb054e4b6d64769275ee8579559f96` |
| `App/RegionalLaunchConfiguration.swift` | `86bb7c01ada83eda3837f3b2321d9eab6c0c9d59aab5e6ef14e88023c41fb545` | `b1e9b06bea589523406f0afd661f29e85c5a7d15d66a86a54ad6ef362f3732ae` |
| `App/RoamHomeTabsView.swift` | `92f8a174791da24cdc1c96630c21bc374fcdff1d2c75cf05822ca91b9bf147cf` | `18e47b034ef5ebb538d57bc1097fcefb6dd653b5a22e1bda22841574985c0d81` |
| `App/SettingsAccountEntries.swift` | `abebcd164a8d9c78ead0ed84bb4cd7d5fe48ef1d1493ea31415ea26c8abd8aef` | `5510fd408f447f0a99c7a6dc41b0f1dedcdecb2190b90956825f5bc49a9ac40d` |
| `App/SettingsView.swift` | `b90080dcc83d4ec1ffe01e4cb901d4432102dc13238015e87619c436439e28dd` | `dbb3c986a0b65cc5d556f9f33f5b750d17636e57973f9c0677022b291ff4cdaa` |
| `App/SquareBrowserView.swift` | `eab6a894879a8bf55afab5ee71e14dc68db83f4484a3039c7789765aed82aee3` | `1ca959b7a4a288d00645101e4586c424d841be9c5a74d6b7494508f34c295ed9` |
| `App/SquareXcxPostCard.swift` | `d91f70af323e18149953e2e7d8056d79e7c115b9f379524896e6aa1b63709f47` | `ceffdd9c6032529931ff63af9e225861c1486fec08591c03938f008f573ee506` |
| `App/TicketWalletDetailView.swift` | `8b870fbf9d7aa4d8fa4b3cb634e1a48f8c414417f18bda6836d43dcb0ba8e8e1` | `ba464d12dddbdac86fc78ba6cf07fb1f1fe66464b61ee01c581049baeeab76e1` |
| `App/TicketWalletView.swift` | `9e19df02656c17ec16f9c45c9597e93a73a57031cad22dbc845c8cc16b7b94a0` | `13519f2fa47e68d778cb3334aea9619fefa4ee7e3fa2049a7162d3452a7ccc2e` |
| `App/UsageConsentGateView.swift` | `4cde043db85e00313c7f009e7b0ef841739f9cea87f68d996ad2375b5b81cc52` | `7beb50caf47c2a0ce4b485c89f7b84a187154f601372cadfe7f123d23ba1ea41` |
| `App/WalletCommerceFixtureHost.swift` | `727d574f7442a8e8a8c0b6071e2ee87dddd337fb8e7ea76384992a8945917478` | `7cabaa679b3905e9080ccb6890c0033ed447704b8c0d9cb5115a457be7354ac4` |
| `App/WalletCommerceViews.swift` | `8f90e9956cd66cef575c0b6de291587cf803af3ce3677a2353098adf7ff5922e` | `74749098f50a8eec14e9fa5baf1d9420a8cab4b8e0169ee14e20b20b8d37d75b` |
| `App/WeChatAppAuthSection.swift` | `39b436a26c129707ed2b166ab312d19947baafe206535fcca366dc80b932d72a` | `4838079b95386afdbdca9a251b70c4424b959b48b653a58858ff8b367678e2e9` |
| `App/WelcomeView.swift` | `0c2bf80bd49ce88b7423724d50c1412865eef02b173b35a94c4f27a51f6aace4` | `b90b975a6136ea5e4a2c424c78d840ba2862ed595ca74ef3cd6308f8604c8d44` |
| `Config/China.Production.xcconfig` | `0438b1444865a43463697b9ded8f08ac4ac0533e33a90bc506198c6d165e54f8` | `31e844274a68e4207a910603f781d701a278684f2412893c290fd176c52557a8` |
| `Core/PWavePresentation.swift` | `b0436b708ffad02a4f82355e8cfcc647dcd55a6f455983ca1bc50b90e6ee9000` | `582ee36bd2f2031888c2d5e7d8d58b507686548d0d42162acbd5410b913fc3f2` |
| `Core/PWaveReader.swift` | `c5b166e17625abced624f0a2024b7a6a43332e1d5ddea981b106b55427e90081` | `9c2fb7fabc71c0ed844f4248f0d462c6f0eee12edd0412687679c9ba5daf8e5d` |
| `Core/PlayExperienceCoordinator.swift` | `13101f077e07728ecac9b91c83c9455fbac2d4577f320960f27f213e87748205` | `217f76dcd14bb91f7f29dd85a7a598c65043509a2aada08ac325f6935e2e344f` |
| `Core/PlayExperienceService.swift` | `09b7e1d829f6d50433c1cacaa154b991e9db940e30bc129004ddcb4bdfe08233` | `8ea448274d1bb35499f0a808c9803dc8a6b677e85b4be97f4991df6271110cf2` |
| `Core/RegionalConfiguration.swift` | `07aebbbedf63bb3d9caf93bc4fc26ce1ad7c50bf5ba5b2915b11ffaf1a8b2ed8` | `b53dbd78e1c12b0252aae6d3a5904f79f2320a3dba120e4199a7df252759592a` |
| `Questify.xcodeproj/project.pbxproj` | `1ccf4e125535f6f42d5f3f7f637cb2ca1e061de332889792ab02cd20a0aa8f30` | `d631233ccf49fdda823b02604df3e9d1a926517bb0d46334ced8ab26434761ed` |
| `Resources/AuthEntry.xcstrings` | `c414ddc3663ce67a3637ea431c7010cf52758cfa6536f4ddb007d2c272df7633` | `8972fcacdd80ee20657a917adc3714488a6de93ccfd1114379b724dc51f61814` |
| `Resources/Localizable.xcstrings` | `70379d7e0144492e20b53d532e83a4b0eefb6ae768463522e9086b71d2126b29` | `e1e182bb784a82706e9b74deb734ad63c3b4ea3cc6b9df4f76d9337583ec2d7a` |
| `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` | `31af8c81be932b0da8d2a70bfd69d67342298bb558e29b4abbe6916af482f477` | `b7d4ab92b8327d01dc0e194859d23644424dbd3e425340c83bad03c1b5b4513f` |
| `Tests/CoreTests/PWaveCoreTests.swift` | `e3bddc01baa80d681a4ac63a146f43a2596ef5ffedc2af0769238c9392d34a62` | `b99fdc001dbd3b0e6cc47554cdbb1dd8ba102daa9565845623419934363712d1` |
| `Tests/CoreTests/ReviewedChinaLaunchTests.swift` | `068efcc9848d7dcd4a0babd225bfad75f673ceea62429083f2968ab81c6e3f98` | `b28958719acc49c08e29384b55bf517161904d7306e14aba7236ea2fe1699080` |
| `Tests/CoreTests/WP04OwnerDecisionGuardTests.swift` | `7083987731d706f97b7ba389c9d4c2866e6ba10040081e454eb01eb6685ec81f` | `59acb74100bc9246eb8c263f922c9eb25eb3cfdcf83d0dc397ee2c5d5975134f` |
| `docs/release-readiness-checklist.md` | `15664dedf5100f5db8ab37f4c143218dca28d6473e9a6220d6100d99bfdb81b0` | `a875b12221db7954b18048d525685306eb071648ce0d569cc40d661a272ce0b7` |
| `docs/release/backend-deploy-plan.md` | `8a50e84b80fdc7f31f19be4288a4260573760832a2f40c23ab03a14d15ba3b4b` | `5201a7f49058d889b819bb66c536b7c399fe989d805b2efe025d30e77818252b` |
| `docs/release/pwave-core.md` | `a15de7877adcb944ab7dbd4d2330fe2534057a91a662f563d7464dc2488415df` | `e2f3fa83ff747e027c5ce2c41ea5d91128cf7720bd79e2fe882fbce18529fa85` |
| `docs/release/ship-prep.md` | `4ab19c327d98a92aa308797444c9c2c6ceda6acb7b632c838ed3d219452ba75f` | `e5ecff2b895950dfb6c3c6f184130a6686831a18bea725cfdc2ccae8c35775e1` |
| `docs/release/smoke-flows.md` | `855e97f5235352b2c1c53b1e88c9145bbee0067b5f055cc90ed3a502a99a5f67` | `adfe1d23961e070e8514637652a7c681ab5e07c48f85982b92f15b3db0d07b32` |
| `docs/release/wire-1-grants.md` | `c6802e9833cddf7aa0c5f341a327a7b3a4c965153980091332dab58afe2b0c1e` | `ce2289d9e64a1062eb7e0ecbe5391571e3877223f59cea8c39ef49d34319dbd6` |
| `docs/release/zip-diff-ios.md` | `3110dad9962e5e35b14a02c4debfc7532b18f3179b7c5027380725fd88daed7b` | `dc93941c6aa2ff0bed6f20709fb3b7800784a049f29efddeb0e103fc1e5d4a3d` |
| `tools/check_l2_environment_configs.py` | `7739ac78b98309c839255805c69715824f86eefab914d8f9b06b73791bd6dcc0` | `0fb3a50e3243c338668639d7491c5b210be835835ca19cc308dafec61016ba2c` |
| `tools/check_scaffold.py` | `3505394d4962753e01089b3048d4113f3c4d3e9bde5ae14b4fd6827374c84b85` | `ccb393f8382e974a5472cab9a8c7afbdff1454a3384aa27585e68247653deb9b` |
| `tools/generate_project.py` | `93eb273bd6404cde15923d24c6e085812c271d379cc0c9814f11d7e600bfe8e2` | `fc58ce328faf6392a057d5eeea7d446dbe4281d6826ea37ca8c5cfcee2238c31` |

## Native method identities that would be added (38)

These identities are declared in the RC test sources and absent from `snapshot.native_methods`. No native identity would be removed or retargeted.

| Method | Path |
|---|---|
| `QuestifyCoreTests/PWaveSecondWaveTests/testAStaleAccountDropsTheLaterReadAndAFailedReadIsNotZero` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testAffiliateNullHeldAndFalsePayoutAreNotAWithdrawableBalance` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testAffiliateStaysHiddenWithoutACapabilityAndDoesNotBecomeAnEmptyZero` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testCatalogRejectsAnUnknownFieldBeforeSending` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testCityPassKeepsUnknownPriceAsAnEmDashAndDoesNotSell` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testHistoryKeepsSessionIdsAndDoesNotFillCurrentContent` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testLaterOrderAndUnknownNumbersUseAnEmDash` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testMemberRankStaysHiddenUntilTheServerSendsIt` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testMemoryHidesOtherPhotosAndDoesNotTurnUnknownIntoZero` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testMultipleCurrenciesStayUnsummedAndALiteralAmountCanWithdraw` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testQuestRankStaysHiddenUntilTheCompletedNodeBasisAndUnknownIsAnEmDash` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testReaderHidesTheLaterWaveUntilTheGrantAndSendsNothing` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testReaderUsesTheNamedReadsAndRefusesWrites` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testTeamBoardIsNotMemberRankAndStaysHiddenWhenTheSwitchIsOff` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testThemeCollectionHidesWithoutCapabilityAndDoesNotPadOrInventProof` | `Tests/CoreTests/PWaveSecondWaveTests.swift` |
| `QuestifyCoreTests/PlayActionReceiptTests/testConfirmedOriginalReceiptAcknowledgesTheSameNode` | `Tests/CoreTests/PlayActionReceiptTests.swift` |
| `QuestifyCoreTests/PlayActionReceiptTests/testIdentityKeepsTheOriginalIdAndRefusesAReplacement` | `Tests/CoreTests/PlayActionReceiptTests.swift` |
| `QuestifyCoreTests/PlayActionReceiptTests/testPendingReceiptIsNotARejectionAndAForeignIdIsMalformed` | `Tests/CoreTests/PlayActionReceiptTests.swift` |
| `QuestifyCoreTests/PlayActionReceiptTests/testReceiptReadUsesTheOriginalIdAndLeavesCode520Pending` | `Tests/CoreTests/PlayActionReceiptTests.swift` |
| `QuestifyCoreTests/PlayActionReceiptTests/testRejectedWriteDoesNotQueryAReceipt` | `Tests/CoreTests/PlayActionReceiptTests.swift` |
| `QuestifyCoreTests/PlayActionReceiptTests/testUnknownRetryResubmitsTheSameActionId` | `Tests/CoreTests/PlayActionReceiptTests.swift` |
| `QuestifyCoreTests/PlayActionReceiptTests/testUnknownWriteQueriesTheOriginalReceiptAndDoesNotFail` | `Tests/CoreTests/PlayActionReceiptTests.swift` |
| `QuestifyCoreTests/ReviewedChinaLaunchTests/testShippedChinaAdmissionAcceptsOnlyTheReviewedHost` | `Tests/CoreTests/ReviewedChinaLaunchTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testAbsentCapabilityHidesTheFeatureAndUndeclaredDoesNotBlock` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testAccusationIsNotPublishableAndDropsSecrets` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testClueTransformDoesNotReverseTwiceOrGuess` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testContractOrderHidesSkipGemAndPublish` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testCoreSourcesCarryNoFixtureAnswerWalletOrLiveSession` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testEarlyCloseIsNotFailureAndUnreadableProgressIsPending` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testHangmanProjectionDoesNotStoreOrCutTheAnswer` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testHelpLadderKeepsLegacyAndRejectsUnknownTypesGemsAndSkipControl` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testHelpReceiptDoesNotRenderUnknownOrNotScoredAsZero` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testHelpUseDoesNotSliceOrOpenAWallet` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testImageOptionDropsUndeliveredMediaAndDoesNotStoreCorrect` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testReaderRefusesProductionWritesAndAnAbsentGrant` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testReceiptUnknownStaysPendingAndScopeChangeDiscards` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testRunQuotaDoesNotPreferRootOrTurnUnknownIntoZero` | `Tests/CoreTests/UGGameplayTests.swift` |
| `QuestifyCoreTests/UGGameplayTests/testUnknownNumbersAreNeverZero` | `Tests/CoreTests/UGGameplayTests.swift` |

## Portable methods and device-only methods

`snapshot.portable_methods` stays 7145 identities, each still owned by the same path. `snapshot.device_only_methods` stays the same 8 identities and paths. The pinned device-only source hashes still match the RC files.

## Test files inside the source rows

Seven source rows above are test files that own current declarations. They are already counted in the 66 or the 71. They are not an extra 7 entries. `changed_test_sources` on a refresh whose prior snapshot is this manifest would be these paths:

| Path | Already counted as |
|---|---|
| `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` | sha256 change |
| `Tests/CoreTests/PWaveCoreTests.swift` | sha256 change |
| `Tests/CoreTests/PWaveSecondWaveTests.swift` | added source row |
| `Tests/CoreTests/PlayActionReceiptTests.swift` | added source row |
| `Tests/CoreTests/ReviewedChinaLaunchTests.swift` | sha256 change |
| `Tests/CoreTests/UGGameplayTests.swift` | added source row |
| `Tests/CoreTests/WP04OwnerDecisionGuardTests.swift` | sha256 change |

`Tests/CoreTests/ReviewedChinaLaunchTests.swift` is one changed source row and also contributes the one new method in that file. The other method identities in that file, and every method identity in `PWaveCoreTests.swift`, `ReviewedChinaLaunchCompositionTests.swift`, and `WP04OwnerDecisionGuardTests.swift`, are already in the manifest and keep the same path. Those identities are not listed again.

The 38 new identities are the 15 in `PWaveSecondWaveTests.swift`, the 7 in `PlayActionReceiptTests.swift`, the 15 in `UGGameplayTests.swift`, and `ReviewedChinaLaunchTests.testShippedChinaAdmissionAcceptsOnlyTheReviewedHost`.

## What a refresh would still take from the owner

`refresh` writes a new `snapshot` from the live files. That snapshot differs from this manifest in the 175 entries above. It also rewrites `audit`, `comparison_base`, `required_since`, `required_current_methods`, `source_dependencies`, and `ui_costs`. Those objects are not inventory entries, and this note does not list them.

`audit.added` and `audit.removed` are computed against the snapshot stored at the `--base` the owner passes (`git show <base>:tools/current_ci_manifest.json`), or against a one-time snapshot of that base when the manifest is absent there. This note does not select a base.

When that base is this RC commit, the prior snapshot is the manifest compared here: `audit.added` is the 38 method identities, `audit.removed` is empty, and `audit.changed_test_sources` is the seven test paths in the table above. An empty removal set needs no retirement row for that base. The 53 replacement bindings in `additional_base_test_reviews` still match the RC file hashes, so that binding check does not refuse the write on its own.

A different `--base` can produce a different `audit.added` / `audit.removed` pair. The `snapshot` rows taken from these RC files remain the rows listed above.
