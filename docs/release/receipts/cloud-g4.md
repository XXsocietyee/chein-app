# cloud-g4

Re-landed the 50 `Fixture_*Tests` UI tests from `origin/cursor/ut-*` onto `ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`.

Each file is one `XCTestCase` with two methods. It launches a DEBUG `--design-fixture` in English and zh-Hans, waits for a hittable element, and rejects an unknown fixture, a raw dotted key, and the word Questify outside a DEBUG label. No `App`, `Core`, or `Config` file changed. `E4PurchaseFixtures.moneyMovingWrites` and `AppSession.canUsePassword` are untouched. Password login, payouts, and virtual-goods purchase stay off.

`python3 tools/generate_project.py` registered all 50 files in the `QuestifyUITests` target. `QuestifyAppUnitTests-Shards.xctestplan` lists that target with `skippedTests: []`, so these classes are in the Xcode Cloud UI test action with the rest of the UI target. The four app-unit shard plans still partition only `QuestifyAppUnitTests` and were not edited. The sealed `run138` UI shard contract and `tools/current_ci_manifest.json` were left unchanged. Both already disagree with this base, and a refresh would record unrelated tests.

Forty-eight files match the source commit byte for byte. Two source files called `launch(language:)` against `launch(_ language:)`, which does not compile. The parameter label is now `language` in `Fixture_d4_badges_errorTests` and `Fixture_e1_bundle_shelf_errorTests`. Launch arguments and assertions are unchanged.

This machine has no Xcode. `swiftc` 6.2 `-typecheck -swift-version 5` of all 50 files together succeeded against an Apple-shaped XCTest stub (`XCUIApplication` subclassing `XCUIElement`, `NSPredicate(format:)`). `swiftc -parse` of each file succeeded.

| File | Class | Fixture | Methods | Source branch | Source commit |
|---|---|---|---|---|---|
| `Fixture_consentTests.swift` | `Fixture_consentTests` | `consent` | `testConsentEnglish`, `testConsentSimplifiedChinese` | `cursor/ut-consent` | `171c3db3b1a00ee52e772a8a3ff592842fd49c6a` |
| `Fixture_couponsTests.swift` | `Fixture_couponsTests` | `coupons` | `testCouponsDesignFixtureEnglish`, `testCouponsDesignFixtureSimplifiedChinese` | `cursor/ut-coupons` | `d822e830915335fd2542ef2a0445cd9900b4acad` |
| `Fixture_d2_cityTests.swift` | `Fixture_d2_cityTests` | `d2-city` | `testD2CityEnglish`, `testD2CitySimplifiedChinese` | `cursor/ut-d2-city` | `fae32fdc2d0d36f7eb7f83bfd84867d6b9f564a6` |
| `Fixture_d2_homeTests.swift` | `Fixture_d2_homeTests` | `d2-home` | `testD2HomeEnglish`, `testD2HomeZhHans` | `cursor/ut-d2-home` | `c9a502b766bd69f3b86157261d1523f50d2bb498` |
| `Fixture_d2_inboxTests.swift` | `Fixture_d2_inboxTests` | `d2-inbox` | `testD2InboxEnglish`, `testD2InboxSimplifiedChinese` | `cursor/ut-d2-inbox` | `42255c2d1ea32558c66ff50220c82f65a2bf2646` |
| `Fixture_d2_meTests.swift` | `Fixture_d2_meTests` | `d2-me` | `testD2MeEnglish`, `testD2MeZhHans` | `cursor/ut-d2-me` | `e684da31ee646bec1df903227a27201bc4513453` |
| `Fixture_d2_npcTests.swift` | `Fixture_d2_npcTests` | `d2-npc` | `testD2NPCEnglish`, `testD2NPCSimplifiedChinese` | `cursor/ut-d2-npc` | `ee582e7c45a688d8d34d48ecd3c8d8dc970d9dec` |
| `Fixture_d2_playTests.swift` | `Fixture_d2_playTests` | `d2-play` | `testD2PlayEnglish`, `testD2PlaySimplifiedChinese` | `cursor/ut-d2-play` | `dccb003fe8d80cf1e5bde6a24896b6f8d7da6ae6` |
| `Fixture_d2_roamTests.swift` | `Fixture_d2_roamTests` | `d2-roam` | `testD2RoamEnglish`, `testD2RoamSimplifiedChinese` | `cursor/ut-d2-roam` | `53a99f0cfd3429b381e8085c5ccbd3c3103b0b1b` |
| `Fixture_d2_search_resultsTests.swift` | `Fixture_d2_search_resultsTests` | `d2-search-results` | `testD2SearchResultsEnglish`, `testD2SearchResultsZhHans` | `cursor/ut-d2-search-results` | `934f276fc9aff5c881133e117863012586d31b15` |
| `Fixture_d2_searchTests.swift` | `Fixture_d2_searchTests` | `d2-search` | `testD2SearchEnglish`, `testD2SearchChinese` | `cursor/ut-d2-search` | `40bb3243b26dc07226ab812775b24abe76a1328d` |
| `Fixture_d2_squareTests.swift` | `Fixture_d2_squareTests` | `d2-square` | `testD2SquareEnglish`, `testD2SquareSimplifiedChinese` | `cursor/ut-d2-square` | `6d39863cb61ce13eb5e95a1a7c59a7221ee9b9cb` |
| `Fixture_d4_badges_emptyTests.swift` | `Fixture_d4_badges_emptyTests` | `d4-badges-empty` | `testEnglish`, `testSimplifiedChinese` | `cursor/ut-d4-badges-empty` | `42fba1c3c778fbe0ce3f9e68a9e49cfdcbd0bb60` |
| `Fixture_d4_badges_errorTests.swift` | `Fixture_d4_badges_errorTests` | `d4-badges-error` | `testD4BadgesErrorEnglish`, `testD4BadgesErrorSimplifiedChinese` | `cursor/ut-d4-badges-error` | `6d0fce5726bc502ff068990e6a036b37d9908ee0` |
| `Fixture_d4_badgesTests.swift` | `Fixture_d4_badgesTests` | `d4-badges` | `testD4BadgesEnglish`, `testD4BadgesSimplifiedChinese` | `cursor/ut-d4-badges` | `0e8ce43f1b31fb163c49fca65ba441066ddd9953` |
| `Fixture_d4_channel_chatTests.swift` | `Fixture_d4_channel_chatTests` | `d4-channel-chat` | `testEnglishDesignFixture`, `testSimplifiedChineseDesignFixture` | `cursor/ut-d4-channel-chat` | `06229e2cd3ef6be17bce88d406760d2c72f84b18` |
| `Fixture_d4_channelsTests.swift` | `Fixture_d4_channelsTests` | `d4-channels` | `testD4ChannelsEnglish`, `testD4ChannelsSimplifiedChinese` | `cursor/ut-d4-channels` | `778bae2ed9ca90690c023f7589e33e47dc6c6c16` |
| `Fixture_d4_confirmTests.swift` | `Fixture_d4_confirmTests` | `d4-confirm` | `testD4ConfirmEnglish`, `testD4ConfirmZhHans` | `cursor/ut-d4-confirm` | `e321bcefc77c61c4f055c1e32da16bea37a3eb65` |
| `Fixture_d4_detailTests.swift` | `Fixture_d4_detailTests` | `d4-detail` | `testD4DetailEnglish`, `testD4DetailSimplifiedChinese` | `cursor/ut-d4-detail` | `b80e818b285ebb95b79f7063aef8166dfc6ab199` |
| `Fixture_d4_directoryTests.swift` | `Fixture_d4_directoryTests` | `d4-directory` | `testDirectoryEnglish`, `testDirectorySimplifiedChinese` | `cursor/ut-d4-directory` | `ebaaf04fd6233e9a2a07cd882c3d6215e2aea04d` |
| `Fixture_d4_enrollTests.swift` | `Fixture_d4_enrollTests` | `d4-enroll` | `testD4EnrollEnglish`, `testD4EnrollChinese` | `cursor/ut-d4-enroll` | `a9efb51f132555648ef4c5a6a37e4b8c672baa30` |
| `Fixture_d4_govTests.swift` | `Fixture_d4_govTests` | `d4-gov` | `testD4GovEnglish`, `testD4GovSimplifiedChinese` | `cursor/ut-d4-gov` | `ba13188059c42ac225cb158951275c71259db9b3` |
| `Fixture_d4_growthTests.swift` | `Fixture_d4_growthTests` | `d4-growth` | `testD4GrowthEnglish`, `testD4GrowthSimplifiedChinese` | `cursor/ut-d4-growth` | `5fec205dda5726ad02b77f396e690fd4d6fe38d6` |
| `Fixture_d4_join_confirmTests.swift` | `Fixture_d4_join_confirmTests` | `d4-join-confirm` | `testEnglishJoinConfirmFixture`, `testSimplifiedChineseJoinConfirmFixture` | `cursor/ut-d4-join-confirm` | `a737ba37f001bccf828ab80a7fdd6af2a4fb8f37` |
| `Fixture_d4_leaderboardTests.swift` | `Fixture_d4_leaderboardTests` | `d4-leaderboard` | `testD4LeaderboardEnglish`, `testD4LeaderboardZhHans` | `cursor/ut-d4-leaderboard` | `d080ef62b83b21144816d41ee55d9954c32bac51` |
| `Fixture_d4_membersTests.swift` | `Fixture_d4_membersTests` | `d4-members` | `testD4MembersEnglish`, `testD4MembersChinese` | `cursor/ut-d4-members` | `23be11f35611a3a77fba06f2cc09c12858878cef` |
| `Fixture_d4_ops_createTests.swift` | `Fixture_d4_ops_createTests` | `d4-ops-create` | `testD4OpsCreateEnglish`, `testD4OpsCreateZhHans` | `cursor/ut-d4-ops-create` | `79a606663d3904c35f5dde4095a2d19abcb0d2fb` |
| `Fixture_d4_opsTests.swift` | `Fixture_d4_opsTests` | `d4-ops` | `testD4OpsEnglish`, `testD4OpsZhHans` | `cursor/ut-d4-ops` | `b3805eb078d7e780ada11b430ce38b1eb0ff1871` |
| `Fixture_d4_owner_detailTests.swift` | `Fixture_d4_owner_detailTests` | `d4-owner-detail` | `testD4OwnerDetailEnglish`, `testD4OwnerDetailSimplifiedChinese` | `cursor/ut-d4-owner-detail` | `496b22302308f307b8dcf14d48568cdc37b4b178` |
| `Fixture_d4_settingsTests.swift` | `Fixture_d4_settingsTests` | `d4-settings` | `testEnglish`, `testSimplifiedChinese` | `cursor/ut-d4-settings` | `b389758471459a6f0a20dcfe64ce55c82d0201e2` |
| `Fixture_d4_stamps_emptyTests.swift` | `Fixture_d4_stamps_emptyTests` | `d4-stamps-empty` | `testEnglishDesignFixture`, `testSimplifiedChineseDesignFixture` | `cursor/ut-d4-stamps-empty` | `bcab2d80ffe857db559ce45b7496e6a71cf8c300` |
| `Fixture_d4_stampsTests.swift` | `Fixture_d4_stampsTests` | `d4-stamps` | `testD4StampsEnglish`, `testD4StampsZhHans` | `cursor/ut-d4-stamps` | `d63d51b3b6c947a9009ad5f45c5ba20c62617dbb` |
| `Fixture_d4_tab_eventsTests.swift` | `Fixture_d4_tab_eventsTests` | `d4-tab-events` | `testD4TabEventsEnglish`, `testD4TabEventsSimplifiedChinese` | `cursor/ut-d4-tab-events` | `877fa1446be05b88dbc1798937af4cda928a0494` |
| `Fixture_d4_tab_overviewTests.swift` | `Fixture_d4_tab_overviewTests` | `d4-tab-overview` | `testEnglishDesignFixture`, `testSimplifiedChineseDesignFixture` | `cursor/ut-d4-tab-overview` | `7ee572702a78426848c6dcf97b0822b532d8bacd` |
| `Fixture_d4_tab_postsTests.swift` | `Fixture_d4_tab_postsTests` | `d4-tab-posts` | `testEnglish`, `testSimplifiedChinese` | `cursor/ut-d4-tab-posts` | `bbcaac99af8ce095cf5016cc92d3fc51b9ceedcf` |
| `Fixture_d6_liveTests.swift` | `Fixture_d6_liveTests` | `d6-live` | `testD6LiveEnglish`, `testD6LiveSimplifiedChinese` | `cursor/ut-d6-live` | `b200cb770dfb3123e6f2e7f6c29f069abc1c388c` |
| `Fixture_d6_play_loadingTests.swift` | `Fixture_d6_play_loadingTests` | `d6-play-loading` | `testD6PlayLoadingEnglish`, `testD6PlayLoadingSimplifiedChinese` | `cursor/ut-d6-play-loading` | `3629a585099cd0493530ad00ebcfd819a200e6d8` |
| `Fixture_d6_playTests.swift` | `Fixture_d6_playTests` | `d6-play` | `testD6PlayEnglish`, `testD6PlaySimplifiedChinese` | `cursor/ut-d6-play` | `14deab0ca2aa5de94728f1d12795c312447e4652` |
| `Fixture_d6_real_liveTests.swift` | `Fixture_d6_real_liveTests` | `d6-real-live` | `testD6RealLiveEnglish`, `testD6RealLiveSimplifiedChinese` | `cursor/ut-d6-real-live` | `2559f7a8765d63ab76e81018101dc013876a301c` |
| `Fixture_d6_roamTests.swift` | `Fixture_d6_roamTests` | `d6-roam` | `testD6RoamEnglish`, `testD6RoamSimplifiedChinese` | `cursor/ut-d6-roam` | `43317e132c0680cedf01261909496fdf0c468409` |
| `Fixture_d6_searchTests.swift` | `Fixture_d6_searchTests` | `d6-search` | `testD6SearchEnglish`, `testD6SearchSimplifiedChinese` | `cursor/ut-d6-search` | `b4409ff51d384914fd8a9d39e3c2595c5f083d05` |
| `Fixture_detailTests.swift` | `Fixture_detailTests` | `detail` | `testDetailEnglish`, `testDetailSimplifiedChinese` | `cursor/ut-detail` | `055d307935f72715c7f7a59839c9bc3faa32b5dc` |
| `Fixture_e1_activitiesTests.swift` | `Fixture_e1_activitiesTests` | `e1-activities` | `testE1ActivitiesEnglish`, `testE1ActivitiesSimplifiedChinese` | `cursor/ut-e1-activities` | `3feaeac4be9fa866d99c0675ee2c03caf9ff87e7` |
| `Fixture_e1_activity_detailTests.swift` | `Fixture_e1_activity_detailTests` | `e1-activity-detail` | `testE1ActivityDetailEnglish`, `testE1ActivityDetailSimplifiedChinese` | `cursor/ut-e1-activity-detail` | `a700c1a038df9c76762032312c2c89a5ae63f2ce` |
| `Fixture_e1_bundle_detail_offTests.swift` | `Fixture_e1_bundle_detail_offTests` | `e1-bundle-detail-off` | `testE1BundleDetailOffEnglish`, `testE1BundleDetailOffSimplifiedChinese` | `cursor/ut-e1-bundle-detail-off` | `7c8d9659e727777b11e2d173f467325e78f3dc2b` |
| `Fixture_e1_bundle_detailTests.swift` | `Fixture_e1_bundle_detailTests` | `e1-bundle-detail` | `testE1BundleDetailEnglish`, `testE1BundleDetailZhHans` | `cursor/ut-e1-bundle-detail` | `cc4a7fb1c25eab9f700e928c1dd8f890ac22a5e0` |
| `Fixture_e1_bundle_shelf_emptyTests.swift` | `Fixture_e1_bundle_shelf_emptyTests` | `e1-bundle-shelf-empty` | `testE1BundleShelfEmptyEnglish`, `testE1BundleShelfEmptyZhHans` | `cursor/ut-e1-bundle-shelf-empty` | `f1e7470f4ab5d940e23bec23fce17e121b00f02c` |
| `Fixture_e1_bundle_shelf_errorTests.swift` | `Fixture_e1_bundle_shelf_errorTests` | `e1-bundle-shelf-error` | `testE1BundleShelfErrorEnglish`, `testE1BundleShelfErrorSimplifiedChinese` | `cursor/ut-e1-bundle-shelf-error` | `29a4c813b5bc194ce8f8984a53ec255b7ee0d791` |
| `Fixture_e1_bundle_shelfTests.swift` | `Fixture_e1_bundle_shelfTests` | `e1-bundle-shelf` | `testE1BundleShelfEnglish`, `testE1BundleShelfSimplifiedChinese` | `cursor/ut-e1-bundle-shelf` | `697a2d40cfdb1f355a9c75e601ed7affd2833947` |
| `Fixture_e1_discoveryTests.swift` | `Fixture_e1_discoveryTests` | `e1-discovery` | `testE1DiscoveryEnglish`, `testE1DiscoverySimplifiedChinese` | `cursor/ut-e1-discovery` | `c77a48de9397b36d25abb1800aab65a847c435a1` |

