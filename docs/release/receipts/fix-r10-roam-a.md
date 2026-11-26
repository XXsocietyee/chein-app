# Fix r10 — lane roam-a (play-roam.md §5: P0, then P1 first half)

- Brief: `origin/design/handoff-r2:docs/briefs/fix-r10.md`. Source: `docs/audit/parity-r10/play-roam.md` §5.
- Base: `origin/ui/combined-r7` @ `d9832ac50`. Branch: `fix/r10-roam-a`.
- Not compiled (no Swift toolchain in the cloud). Every type/member used was grepped first.
- Gates: `check_scaffold.py` PASS structural; `check_a11y_lint.py` PASS (0 new); `contract_ratchet.py --check` — see "Gates" below.

## P0

play-roam.md §4/§6 lists **P0 = 0** (the brief's lane table says "P0 1"; there is no P0 row in §5). Nothing to take.

## P1 first half (12 of the 23 P1 rows in §5 table order; roam-b takes N-PLAY-MAP onward)

| row | status | SHA | app file:line | note |
|---|---|---|---|---|
| PLAY-6a | **fixed** | `aa2cd85b9`, `3e34211e2` | App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift (body → `NavigationStack { Form }`, `.navigationTitle` + `.cancellationAction`); App/PlayInPlayTools.swift:209 (`openPreferences` row in 游玩工具 menu); App/PlayExperienceView.swift:693 (sheet mount, `@AppStorage` `play.bgmOn` / `play.narrationOn` / `play_reduced_motion` via `PlayReducedMotionPreference.set`) | Lead actions stay in the on-page `PlayLeadSection`, so the sheet is mounted with stats + preferences (`showsContentRows: false`). No native BGM player exists yet: the toggle stores `play.bgmOn` like the MP; narration autoplay is already read by `ChapterStoryView`. Store catalogued in docs/ops-safety/client-data-catalog.json. |
| QA-r9-1a | **blocked** | — | Core/PlayContentCompatibility.swift:103 | Cursor Core row. The MP (`hengyin/chengyinhub-xcx`, client-capabilities.js:27, playkit-view.js:606-609) is not reachable from this session (add_repo denied) and the `table` / `rules` / `lastRule` wire shape is not documented anywhere in this repo. Declaring `qa.table` without the shape would let the server send content we would render wrong. |
| QA-r9-1b | **blocked** | — | App/PlayKitQuestionForms.swift:20-40 | Depends on QA-r9-1a's decode (same reason). |
| OCARDS-3b | **fixed** | `3739e5d99` | App/ObjectCardViews.swift:33 (`categoryToolbar`: system `Menu` in a `ToolbarItem`, label + items use `ObjectCardCategory.mpIcon` MP assets); App/MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift:35 (tile grid → system list rows) | Identifiers `objects.filter`, `objects.category.*` kept. |
| BWALL-3b | **fixed** | `d9d0bd767` | App/ObjectBadgeViews.swift:143 (`ObjectBadgeWallBadgeLabel`: `ObjectBadgeTileArtwork` + text, `.grayscale` when locked) | Removed `CYFoilMedal`, `cyFoilSheen`, `cyNewPulse`, `cyDomainCard`, `cyLockedSilhouette` from the tile; deleted the unmounted list/wall `Picker` (`ObjectBadgeWallLayoutControl`), its layout/selection types and their unit test. Detail page foil/flip is untouched (N-B3D / later rows). |
| JSEAT-8 | **fixed** | `46f07b3d5` | App/JourneyLandingViews.swift:585 (`.navigationTitle("mp.seats.title")` = 开局大厅) | Eyebrow and 28 pt title removed; the topic name stays as a `.headline` header so the lobby still says which topic it is. |
| RPOI-5 / RROUTES-2 | **partly** | `70850364e` | Resources/Localizable.xcstrings `officialRoute.*` (12 zh-Hans values 路线 → 线路) | RROUTES-2 fixed from the MP copy inventory (docs/mp-gap/copy-g1-player.md:759-764: 官方线路 / 线路加载失败 / 还没有上架的官方线路 / 这条线路不存在或已下架 / 这条线路还没有节点). RPOI-5 (`roam.detail` = 地点 vs poi-detail/index.json:3) not changed: that title is not in any MP inventory in the repo and the MP repo is not reachable. en unchanged. |
| GROWTH-5 | **fixed** | `26d69ef0a` | App/GrowthCenterView.swift:320 (`GrowthProfileDisc(name:avatar:)`), call at :156 | HTTPS session avatar through `CYAvatarView` (same path the leaderboard rows use), `d_profile` fallback, custom `avatarRing` stroke removed. `ProfileCurrentAvatarView` needs a `ProfileEditModel`, so it was not reused. `test_growth_source_contract` still passes (no `AsyncImage` in Growth*.swift); no Cursor change needed. |
| RPOI-4 | **blocked (owner/infra)** | — | App/RoamItemDetailView.swift | Needs the universal-link domain + AASA from the owner before a `ShareLink`. |
| N-PLAY-DARK | **fixed** | `de785d659` | App/PlayExperienceView.swift:731 (`screenDomain` = `.player`), :143-145 (`.tint(Color.accentColor)`); App/PlaySessionView.swift:45-47, :63; App/PlayRouteMapView.swift:129-130, :139 | Shell, backpack, route map and node pages follow system Light/Dark. Pinned `Tests/ContractChecks/test_global_chrome_domain_contract.py` updated with an r10 comment (MP pages/play/index.wxml). |
| N-KIT-DARK | **fixed** | `621abbdde` | App/PlayKitScreen.swift:424-425 (`domain` / `tint` from `kind.isFocusedStage`), :88 (`.confirmationDialog` replaces `cyModalConfirm`) | Native r2 game shells (`usesNativeGame`) keep `.game` (they are stages). |
| N-KIT-FORMS | **partly** | `8e72b2f05`, `5b6c197b3` | App/PlayKitPersonalForms.swift:71 (register card → `GroupBox` + `LabeledContent`), profile seal → `Label`, choices → bordered checkmark buttons, `.cyField` → `.roundedBorder` `TextField(axis: .vertical)`, note `CYInfoCard` → `GroupBox`, presets → `.bordered .small`, photo input: `CYStepIndicator` removed, `CYPillButton` → one `.borderedProminent` per step (`PlayKitStepButtonStyle` :387) + `.bordered`, `CYNoteBanner` → `Label` | Not a `Form`: the kit container (`PlayKitScreen.screenContainer`) is shared with `PlayKitInlineHost`, which must not nest a List/Form inside the story flow. Converting the container is a shell change for every kit. |

## Gates

- `python3 tools/check_scaffold.py`: PASS structural checks.
- `python3 -B tools/check_a11y_lint.py`: PASS, 0 new.
- `python3 -B tools/contract_ratchet.py --check`: first run found 2 new failures caused by PLAY-6a (`test_appsec_review…test_5_local_data_protection_and_client_data_catalog`, `test_ops_safety_contracts…test_audit_tool_catalog_is_complete`: uncatalogued `@AppStorage` in PlayExperienceView) → fixed in `3e34211e2`. The third new failure, `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`, is in files this lane did not touch (SocialReadScreen `.onDisappear` token) and comes from the base.
