# Supplement (handover 25, refresh 3)

## Refresh 3: proposed owner decisions, OPT triage, roll-ups

Branch `docs/completeness-3`, cut from `docs/completeness-2` `e1969026e`. This section covers the open rows of NX-01, NX-03, NX-04 and WP-R in `docs/release/completeness-missing.md`. The build work that results is listed in `docs/release/completeness-next.md`.

The owner said not to ask questions. Where the owner docs are silent or wrong, the mini-program is the reference. Each NX-01 row below therefore has a concrete decision. **Every decision in this section is PROPOSED - owner may override.** If the owner overrides one, only the rows that cite it change.

Sources: the same as refresh 2. The owner pack is `origin/ui/owner-handover` `15a7ddad1` (落地清单 §决策依赖 and §条件扩展, 工单-统一实施版, UI优化施工清单 §10.3). The mini-program is `liboyang42-cpu/hengyin` `chengyinhub-xcx` master `1ca6d3215`. `mp:` below means a path under `chengyinhub-xcx/` at that commit, and the line numbers are from that commit. Native evidence is on `ui/main` `e3264af9f`.

### NX-01: owner decisions (21 rows)

| row | PROPOSED decision (owner may override) | reason | mini-program evidence | build work it implies |
|---|---|---|---|---|
| `OWN-D-01` 积分单位和兑换政策 | One kind of point everywhere. The server quote is the only source for the point-to-yuan rate. The client never shows or computes a rate. Old orders show their snapshot (`pointUsed`) and are never repriced. The rules list shows earn rules and spend rules (eventType 14 「积分消耗」) separately. When the server quotes 0, the client turns the toggle off and gives the real reason. | The mini-program already works this way, and 落地清单 D-01's own fallback ("先展示服务端报价；不擅自统一乘50") points the same way. | `mp:pages/activity/baoming/baoming.js:1210` (`pointsDeductYuan` from the quote), `:1238-1243` (toggle off, 「暂无可用积分」 vs 「该票不支持积分抵扣」); `mp:subpackageMember/components/cy/profile/points-rules.js:10-15,18,50` (rate is a server constant and is not shown; eventType 14 is listed as spend); `mp:subpackageMember/components/cy/scene-member-order-detail/index.wxml:90` (snapshot points on old orders) | WP-10 rows D-01.a–c. Native hides eventType 14 entirely (`Core/WalletCommerceContracts.swift:205`) and shows one 「积分不足」 message for both cases (`App/RegistrationSheetView.swift:566`). |
| `OWN-D-02` 会费退款及权益政策 | No club dues in this release on either client, so no dues refund policy is needed. The only refund surface for a player is the registration cancel-refund, which already has time cut-offs. | The mini-program deleted the dues pages on 2026-09-09. Its `membership.*` danger-action entries have no callers. | `mp:pages/club/detail/index.js:1218-1221` (dues pages deleted); `mp:utils/danger-actions.js:602,614` (entries with no call site); `mp:pages/club/topic-detail/index.js:118,128` (registration refund cut-offs) | WP-10 row D-02: an absence check for dues routes and screens, with a test that cites `OWN-D-02`. |
| `OWN-D-03` A/B内容链切换 | No global switch. Each surface keeps the chain the mini-program uses today. The v1 community chain (B) serves feed, notifications, enforcements, appeals, capabilities and reports. The creative-square chain (A) serves square compose, detail, like, bookmark, report and delete. A later switch is a backend migration (OPT-023) and is not client work. | The mini-program runs both chains side by side, and 落地清单 D-03 says not to flip the B-stack switch. | `mp:utils/community-post-api.js:1,6` (`/api/v1/community` is canonical); `mp:pages/square/detail/index.js:581,622,794,855,1076` and `mp:pages/square/components/cy/post-compose/index.js:633` (`/api/creativesquare/*`) | WP-10 rows D-03.a–b: a table that maps each surface to its chain, and a test. Creative-square delete stays in WP-04. |
| `OWN-D-04` 结局选择兼容合同 | The server picks the ending. Each runtime keeps its current first-hit order, and no new priority strategy is turned on. The client only renders `/api/play/ending` and `/api/play/journey/ending` and has no ending logic of its own. | The mini-program has no ending selection code. It renders the server's opener and fragments. | `mp:pages/play/index.js:8446,8476`; `mp:pages/play/utils/life-archive.js:4` | WP-10 row D-04: a render-only test. Native already reads both routes (`Core/PlayExperienceService.swift`, `Core/JourneyNarrativeContracts.swift`). |
| `OWN-D-05` 资金和权限行为变更 | The payee for club income is the club owner's personal receiver. Binding it needs a one-time WeChat `wx.login` code that iOS cannot produce, so native shows the status and the unbind action and sends bind to the mini-program. The merchant payout account is read-only and needs `FINANCE_READ`. Onboarding is done by platform ops. There is no maker-checker step on the client and no new withdrawal entry. Every write stays behind `ReleaseMoneyWriteSwitch.payoutEnabled` and remains off in production until the owner turns it on. | This is what the mini-program does. It also corrects WP-01, which assumed native could bind. | `mp:pages/club/payout-receiver/index.js:1-3` (bind uses the wx.login code), `:75,105,124,133`; `mp:utils/danger-actions.js:56-62` (unbind confirmation); `mp:pages/merchant/payout-account/index.js:1-2` (read-only, FINANCE_READ); `mp:pages/club/settlement/index.js:237` (entry point) | WP-10 rows D-05.a–c. WP-01 scope changes: `API-/api/club/personal-receiver/bind` becomes a hand-off to the mini-program, not a native write. |
| `OWN-D-06` 会费端侧支付范围 | No dues and no in-app purchase for dues on iOS. The platform pass is the only digital product. It stays behind `MPCommerceGate` until App Store IAP products exist. WeChat Pay is not used for digital goods on iOS. | The mini-program sells the pass only through virtual payment, and dues are deleted (D-02). | `mp:subpackageMember/market/membership/index.js:1-2`; `mp:utils/discover-store-card.js:4` | WP-10 row D-06: a test that no dues product exists and that pass purchase goes through `MPCommerceGate`. Money readiness stays in WP-05. |
| `OWN-D-07` 位置共享与后台能力 | Players do not share their location with each other: no leader or team live location. Background location is allowed only while a play or roam session the player started is running. It is reference-counted per session and stops when the session ends, the player exits or the account changes. It does not stop when the app goes to the background. It uses When-In-Use permission with the system background indicator, not Always. The privacy page shows which purpose holds location and lets the player revoke it. | The mini-program declares background location and stops it per trip. It has no location-sharing feature. | `mp:utils/location/bg-tracker.js:1-13,161-162`; `mp:app.json:397-400,454-457` (`requiredBackgroundModes: location`); `mp:pages/play/index.js:10`; `mp:pages/roam/index.js:99`; `mp:pages/privacy/index.js:396` | WP-11 rows D-07.a–f. Native has no background location today (`App/PersonalLocationShareHost.swift:109` sets `allowsBackgroundLocationUpdates = false`). The share host's approvals stay nil. OPT-052 is dropped. |
| `OWN-D-08` AI额度费用留存和标识 | The quota comes from the server only. If the config is incomplete, AI shows as unavailable and the client never shows mock text. Users can delete and export their NPC chat data. AI output carries a label: 「AI 生成」 on ai_simple stories, and the `aiTraceId` 「[AI 辅助生成]」 mark on AI drafts. The owner's b4-u02-05 rule applies, so adopted templates show the author's name only. There is no long-term memory, no paid memory slot, and nothing is on by default. | This matches the mini-program and 落地清单 D-08's fallback. | `mp:pages/publish/simple/index.js:215` (quota); `mp:subpackageMember/components/cy/ai-chat-records/index.js:33,59` (export and delete); `mp:pages/club/topic-story/index.wxml:11`; `mp:pages/club/utils/aiPlanToDraft.js:23,33`; `mp:pages/templatedetail/utils/topic-adoption.js:119` | WP-10 rows D-08.a–c. The routes are already DONE (`Core/NPCChatLogDeletion.swift:20`, `Core/NPCChatData.swift:55`, `Core/QuickPublishValidation.swift:153`). |
| `OWN-D-09` 端侧范围与新业务范围 | Native iOS matches the mini-program `app.json` (173 pages), minus WeChat-only features. Flutter is not built. New business from the condition packages is built only where the mini-program already has it (see the EXT rows). | The owner said the mini-program is the reference. | `mp:app.json` (5 root pages and 168 subpackage pages) | None. Closed in CL-02 by this record plus the Flutter absence check that already exists (EXT-10). |
| `OWN-D-10` 创作者收益与市场规则 | Show only facts from the server ledger (`/api/marketing/revenue/author/mine`). The client does not show new ratios or automatic re-apply. An empty list hides the tab. A failed read says 「收益暂不可用」 and never shows 0. Retired distribution is not brought back (see EXT-05). | This is the mini-program's behavior. | `mp:subpackageA/components/revenue-allocations/index.js:1-3,19` | WP-10 row D-10: a test for the empty, hidden and error states. The route is DONE (十六-09). |
| `OWN-10.3` 内容合同 v1 | Use C2. Content that declares nothing is "unconfirmed" and does not block a start. Content whose declared required capability is missing refuses to start, and only that content. `content-schema.v1.json` stays a test and CI resource with no runtime loader, and nobody claims "runtime validated by schema". The golden vectors are the contract. Author `outcomeRules.pass/fail` feedback stays in the contract. | The mini-program sends no capability declaration and still plays, so blocking undeclared clients would break it. This also settles the L129 vs BE-07 conflict. | `mp:pages/play/index.js:4431` (`/api/play/nodes` read with no declaration) | WP-11 rows 10.3.a–c. Native already has `Core/PlayContentCompatibility.swift:1-20` and `Core/ContentContractV1.swift` with `Tests/CoreTests/ContentContractV1Tests.swift`. What is missing is a test that cites `OWN-10.3` for the two verdicts. |
| `OWN-EXT-01` 多人角色房间与主持权威 | DROP. Existing team play and the club director console cover multi-person play. No role rooms, private-clue rooms or host hand-off. | The mini-program removed the `multiplayer` section from its editor. | `mp:pages/publish/temp/r5-editor.js:7`; `mp:pages/club/topic-detail/director.js:1466` | None. Closed in CL-02 by an absence check. |
| `OWN-EXT-02` 完整离线导航与地图数据 | DROP full offline maps. Keep the mini-program behavior: an unconfirmed write is kept and confirmed after reconnect, and the client never reports a completion it did not get from the server. | The mini-program has no offline map. It handles only the unknown-write anchor. | `mp:pages/club/topic-detail/director.js:777-784` | None. Unknown-write handling is already native (`Core/PlayExperienceService.swift:303`). |
| `OWN-EXT-03` 商家储值和会员卡 | DROP. | The mini-program says the server has no member product. | `mp:utils/discover-store-card.js:4` | None. Absence check. |
| `OWN-EXT-04` 众筹送礼完整业务 | DROP crowdfunding. Keep the single-buyer gift (buy a pass as a gift, claim it by token), which already exists. | The mini-program has a gift claim and no crowdfunding. | `mp:subpackageMember/market/gift/index.js:1`; `mp:subpackageJourney/utils/journey-api.js:52`; `mp:subpackageMember/market/pass/index.js:202` | None. Gift is DONE (`PAGE-subpackageMember/market/gift/index`, `App/PassMarketViews.swift:151`). Closed in CL-02 with a citation test. |
| `OWN-EXT-05` 可追溯分销与归因 | Use the mini-program's signed referral token. A token is issued, stored per account and claimed after the order. No amounts or commission are shown. There is no multi-level distribution, and query-parameter attribution is never trusted. | This is the mini-program's referral model. | `mp:utils/commerce/referral.js:1-6,74`; `mp:subpackageJourney/utils/journey-api.js:46-47` | None. DONE as 十六-08 (`Core/JourneyLoopSource.swift:518`). Closed in CL-02 with a citation test. |
| `OWN-EXT-06` 完整内容市场授权与收益 | Keep the pass library, publisher pricing and author revenue read. DROP derivative licensing and take-down settlement. Workshop paid install stays in WP-05. | This is the scope of the mini-program market. | `mp:subpackageMember/market/passes/index.js:40,141`; `mp:subpackageA/components/revenue-allocations/index.js:19` | None. The pages are DONE (`App/PassMembershipViews.swift:64`, `App/PublisherLifecycleViews.swift:24`). Closed in CL-02 with a citation test. |
| `OWN-EXT-07` 长期AI记忆关系与多角色 | DROP. Same reason as D-08. | The mini-program has only the NPC profile plus delete and export. | `mp:pages/roam/index.js:290`; `mp:subpackageMember/components/cy/ai-chat-records/index.js:33,59` | None. WP-10 row D-08.c is the absence check. |
| `OWN-EXT-08` 多引擎与重表现容器 | DROP. One renderer, and no VM or embedded engine. | The mini-program's "engine" files are presentation only. | `mp:pages/play/components/chapter-flip/engine.js:1`; `mp:pages/play/utils/playkit-view.js:252` | None. Absence check. |
| `OWN-EXT-09` 积分有效期与新增成长体系 | DROP point expiry. Existing points never expire, so there is no new growth system. | The mini-program points ledger has no expiry field or copy. | `mp:subpackageMember/points-history/index.js:1` and `mp:subpackageMember/points-history/rows.js` (0 matches for 有效期, 过期 or expir) | None. Absence check. |
| `OWN-EXT-11` 开放生态协作及其他新增机制 | DROP: no external API, CRDT co-editing or crowd adjudication. The team "collaboration" panel is broadcasts only. | The mini-program has none of these. | `mp:pages/club/topic-detail/index.wxml:367-370` | None. Absence check. |

Counts: 21 decisions. 10 imply native build rows in WP-10 or WP-11 (D-01, D-02, D-03, D-04, D-05, D-06, D-07, D-08, D-10, 10.3). D-05 also changes the scope of WP-01. 11 close without native build, all in CL-02. D-09 closes on this record. Seven rows are DROP (EXT-01, 02, 03, 07, 08, 09, 11) and close through absence checks. Three rows keep only the part the mini-program already has, which is ALREADY-DONE on native (EXT-04 gift, EXT-05 referral token, EXT-06 pass library and pricing), and close through a test that cites the id.

### NX-03 and NX-04: OPT triage (36 rows)

Each OPT row is a 落地清单 program ticket, and the native slice is judged against it. "ALREADY-DONE" means the native slice exists on `e3264af9f`. The evidence is matrix rows that are already DONE. The row still needs a test that cites the OPT id before the evaluator can close it (package CL-01). "DROP" means there is no native slice. Those rows close through an absence check in CL-01.

| row | triage | package | reason or evidence |
|---|---|---|---|
| `OWN-OPT-001` | ALREADY-DONE | CL-01 | Source and environment baseline: `completeness-matrix.md` §Sources read pins the app, backend and mini-program SHAs and TEST 8120. Native has no VPS of its own. |
| `OWN-OPT-002` | DROP | CL-01 | Re-review of the 509 old leads is a backend and mini-program defect triage. Native keeps its own register (`docs/release/cb70-gap-register.md`). |
| `OWN-OPT-003` | ALREADY-DONE | CL-01 | The decision list is frozen as the PROPOSED decisions above (NX-01 table). |
| `OWN-OPT-070` | ALREADY-DONE | CL-01 | requestId and receipt contract: `Tests/CoreTests/ContentContractV1Tests.swift:282` (fact key vs fingerprint); `Core/PlayExperienceService.swift:366` sends the requestId. |
| `OWN-OPT-071` | ALREADY-DONE | CL-01 | Environment gates: `App/ReviewedAreaSwitch.swift:78` (DEBUG/TEST money derivation), `Core/ChinaReviewedRouteCapability.swift:2413`; rollback in `docs/release/app-rollback-plan.md`. |
| `OWN-OPT-072` | BUILD | WP-11 | Native has no copyable reference outside the AI flows. The mini-program keeps a non-sensitive trace id that the user can copy. |
| `OWN-OPT-090` | BUILD | WP-11 | Multi-identity E2E rerun once WP-01…WP-11 land. The base is `docs/release/e2e/E2E-20261113b.md`. |
| `OWN-OPT-091` | BUILD | WP-11 | Real-device matrix: lock screen, call, low accuracy, denied permission, background location. |
| `OWN-OPT-092` | BUILD | WP-11 | Layered sign-off record for the release candidate (code, PR, merge, TestFlight, real entry readback) on `docs/release/release-checklist.md`. |
| `OWN-OPT-010` | BUILD | WP-10 | Points quote and rules display: D-01 rows a–c. |
| `OWN-OPT-011` | DROP | CL-01 | The mini-program has no cart flow (0 `'/api/cart` literals at `1ca6d3215`). Native refuses cart routes (`Core/WalletCommerceSafety.swift:323`). |
| `OWN-OPT-012` | ALREADY-DONE | CL-01 | Player refund is `/api/registration/cancel-refund` (`Core/OrderLifecycleCoordinator.swift`, `App/ReviewedProductionRoutes.swift`). Dues refund is dropped by D-02. |
| `OWN-OPT-013` | ALREADY-DONE | CL-01 | Merchant payable readback: `PAGE-pages/merchant/ledger/index` and its `batch-detail` and `order-detail` pages are DONE (`App/MerchantBusinessViews.swift:295`, `App/MerchantSettlementProgressView.swift:51`). Club settlement is WP-01. |
| `OWN-OPT-014` | BUILD | WP-03, WP-06 | The coupon claim, sold-out and unconfirmed states live on `subpackageMember/coupon/coupon` (WP-03) and `couponInfo` (WP-06). No new rows. |
| `OWN-OPT-060` | BUILD | WP-03 | Merchant claim routes (`ApiMerchantClaimController`) are already WP-03 rows. |
| `OWN-OPT-061` | ALREADY-DONE | CL-01 | Business dashboard: `PAGE-pages/merchant/index/index` (`App/MerchantHomeView.swift:216`) and `PAGE-pages/merchant/predict/index` (`App/MerchantPredictionInboxView.swift:165`) are DONE. |
| `OWN-OPT-062` | BUILD | WP-03 | CRM is DONE (`App/MerchantEngagementViews.swift:3`). The staff-permission half is `PAGE-pages/merchant/team/index` in WP-03. |
| `OWN-OPT-020` | ALREADY-DONE | CL-01 | Private content uses the v1 community chain: `API-/api/v1/community` is DONE (`App/AppCompositionRoot.swift:2574`, 29-route family). |
| `OWN-OPT-021` | ALREADY-DONE | CL-01 | Author moderation state: `API-/api/v1/community/me/enforcements` and `notifications` are DONE (`Core/SquareGovernanceService.swift:87,92`). |
| `OWN-OPT-022` | BUILD | WP-02 | All 8 community-trust routes are DONE (`Core/CommunityTrustPlayerService.swift:12-17`). The audit appeal and guard appeal routes are the remaining WP-02 rows. |
| `OWN-OPT-023` | DROP | CL-01 | Switching the content chain is a backend migration. D-03 keeps each surface on its current chain. |
| `OWN-OPT-030` | ALREADY-DONE | CL-01 | Author draft save and readback: `PAGE-pages/publish/fabu/index` and `topicadd` are DONE (`App/ProjectEditView.swift:269`). |
| `OWN-OPT-031` | ALREADY-DONE | CL-01 | Ending config parity: the fabu page is DONE, and D-04 makes the ending server-only. A guard test is WP-10 row D-04. |
| `OWN-OPT-032` | BUILD | WP-09 | Adoption is DONE (`OWN-21.3`, `App/TopicTemplateUseSection.swift:77`). The preset versions are WP-09 rows 21.1, 21.2 and U02-04. |
| `OWN-OPT-033` | ALREADY-DONE | CL-01 | Creator revenue: the `assetcenter/earnings` and `analysis` pages are DONE (`App/WalletCommerceViews.swift:71`), and 十六-09 is DONE. |
| `OWN-OPT-040` | ALREADY-DONE | CL-01 | Unknown result and recovery: `Core/PlayExperienceService.swift:303` (`unknownResult`), `:385-409` (no automatic retry), reconcile in `Core/PlayExperienceCoordinator.swift`. |
| `OWN-OPT-041` | ALREADY-DONE | CL-01 | GPS accuracy: `Core/PlayExperienceService.swift:19-25` (`PlayLocationMeasurement.validate`). `API-/api/play/arrive` and `API-/api/roam/checkin` are DONE. |
| `OWN-OPT-042` | BUILD | WP-11 | Background location (D-07), audio interruption and clock re-sync. |
| `OWN-OPT-043` | BUILD | WP-06 | Badges and growth are DONE. Stamp album, stamp camera and citystamp are IN-PROGRESS in WP-06. |
| `OWN-OPT-050` | DROP | CL-01 | Dues are dropped by D-02 and D-06, and `mp:pages/club/detail/index.js:1218` deleted them. |
| `OWN-OPT-051` | ALREADY-DONE | CL-01 | The official activity pages (detail, inbox, mine, organizer) are DONE (`App/OfficialOrganizerConsoleView.swift:3`). |
| `OWN-OPT-052` | DROP | CL-01 | D-07 rules out location sharing. |
| `OWN-OPT-053` | ALREADY-DONE | CL-01 | Broadcast and to-dos: `PAGE-pages/club/notify/index` (`App/ClubOpsNotifySections.swift:3`) and `official-inbox` are DONE. The WeChat subscription grant is WeChat-only. |
| `OWN-OPT-080` | ALREADY-DONE | CL-01 | AI safety and failure states: `API-/api/ai/safety/precheck` is DONE (`Core/PublishingAuxiliaryService.swift:33`). WP-10 row D-08.a adds the no-mock test. |
| `OWN-OPT-081` | ALREADY-DONE | CL-01 | NPC data delete and export are DONE (`Core/NPCChatLogDeletion.swift:20`, `Core/NPCChatData.swift:55`). |
| `OWN-OPT-082` | BUILD | WP-06 | The AI draft lives on `pages/publish/simple/index`. Its routes are DONE, and the page is IN-PROGRESS in WP-06. |

Counts: NX-03 (17) has 7 ALREADY-DONE, 2 DROP and 8 BUILD. NX-04 (19) has 11 ALREADY-DONE, 3 DROP and 5 BUILD. Of the 13 BUILD rows, 6 go to the new packages (WP-10: OPT-010; WP-11: OPT-042, 072, 090, 091, 092) and 7 to existing ones (WP-02: 022; WP-03: 014, 060, 062; WP-06: 043, 082; WP-09: 032). OPT-014 also touches WP-06 but counts once.

### WP-R: roll-ups (5 rows)

The rule as written ("DONE when every native child row is DONE") would never close 22.1 or 十三. Their money children (十六-12 host tip, 十六-13 OTA code) are meant to stay off in production. The resolution below is **PROPOSED - owner may override**:

1. A child that is `IN-PROGRESS (production off)` counts as satisfied for its roll-up. That status means the call site and the route exist and only the money switch is off. A `screen/code, not finished` child does not count.
2. Each roll-up then closes when its children close, in this order:

| row | resolution | closes when |
|---|---|---|
| `OWN-22.1` | Stays a roll-up | WP-07 closes 十六 and 十七, WP-08 closes 十八, 20.1 and 20.2, and WP-09 closes 21.1 and 21.2 |
| `OWN-22.2` | Stays a roll-up of 22.1 | 22.1 closes |
| `OWN-十三` | Stays a roll-up | WP-09 closes 十三-02 and -03, WP-07 closes -08 and -09, and WP-08 closes -10 and -11 |
| `OWN-十一` | Stays a roll-up of 十三 | 十三 closes |
| `OWN-十四` | Stays a roll-up of 十三 | 十三 closes |

No worker is needed. The evaluator change in rule 1 is row CL-02.R.

## Refresh 2 (app `e3264af9f`, backend hengyin `067da9748`)

The sections below the line were written against app `cf2884760`. Where they disagree with this section, this section wins.

- **Handover branches are merged.** `ui/cur-ext-games` and every `ui/cur-be-gap-*` app branch are in `origin/ui/main` `e3264af9f` (merge commits `2ac8f111e`, `cb7a6bf3c`, `5111a3c28`, `415461f7b`, `b1d2cca9c`, `862991555`, `dc50f1a92`). The hengyin be-gap branches are merged into `integration/backend-app-r2` `067da9748`, which runs on TEST 8120. capgraph reports 0 true-missing routes for the app's 1172 called paths. No matrix row is IN-PROGRESS H18–H24 any more.
- **UG gameplay draws screens now.** `App/PlayKitQuestoViews.swift` (UG-01 hangman, UG-03/04 accusation), `App/PlayKitQuestionForms.swift` (UG-02), `App/PlayHelpLadderPanel.swift` (UG-05…09) and `App/TemplateHintLadderFields.swift` (UG-11) exist, with `Tests/CoreTests/PlayHelpLadderTests.swift` and `UGGameplayTests.swift`. `Core/UGGameplay.swift` still says `contractExecution = "NOT_RUN"` for the owner's candidate pack. That is an owner-side status, and the matrix does not use it to hold back a row that has code and a test. On device, the hint ladder is still blocked by E2E-20261113b N5.
- **The 17 pages missing from page-map are added** to `docs/parity/page-map.csv` (owner track `completeness-2`). 15 have a native screen behind `MPParityRoute`. `pages/club/payout-receiver/index` and `pages/merchant/payout-account/index` still have none (WP-01).
- **City game, channels, IM and community have a backend** on `067da9748` (`ApiCityGameR491Controller`, `ApiChannelPlatformController`, `ApiImMediaController`, `ApiCommunityPostController`, …). The four APP rows are DONE.
- **Money in DEBUG/TEST.** Owner rule 2026-11-13 "money ON for TEST/DEBUG only" is now in code. `ReleaseMoneyWriteSwitch` has a DEBUG/TEST `testDerivation` (`Core/ChinaReviewedRouteCapability.swift:2413`) that `ReviewedAreaSwitch.installReleaseMoneyDerivation` sets from the host (`App/ReviewedAreaSwitch.swift:78`). Release builds still compile the four constants `false`. The "Money, payout, merchant writes, password" section below is out of date on that point.
- **Owner-doc routes the app never calls.** hengyin serves them, and TEST 8120 answers 401 without a token: `/api/host-tip/*`, `/api/channel/redeem`, `/api/content-landing/*`, `/api/preset/gameplay/*`, `/api/marketing/group-checkout/*`, `/api/coupon/usability`, `/api/marketing/product/activate`. They are not mini-program literals, so they have no API rows. They appear in the evidence of the owner rows they serve (§16–§21, C, D) and in WP-07/WP-08/WP-09.
- **How §12 bans are judged.** A ban is DONE when a guard has a test, or when a reproducible absence check finds 0 hits in `App/` and `Core/`. The exact grep is written in the row.
- **Not native work.** UG-12, U03-04 and §18 E are the hengyin admin console. §25.1 and the 先读我 "全队共享提示" row are a backend gap. D-01…D-10, §10.3 and EXT-01…09/11 are owner or product decisions. EXT-10 (Flutter) is excluded by the owner and is DONE by absence. The OPT packages are 落地清单 program tickets: `Core/UnifiedOPT*` and `App/UnifiedOPT*SectionView.swift` are contract records, not behaviour. Each of these groups is a separate NX package in `docs/release/completeness-missing.md`.

---

Decisions below are where an owner document is silent, wrong, or disagrees with the mini-program or with `origin/ui/main` `cf28847602bc393ebcead93ca35d85633d23801b`. The mini-program is the product reference when it and an owner doc disagree. The matrix does not silently follow the owner doc.

## Where the owner files actually are

Read at `origin/ui/owner-handover` `15a7ddad1aa7629bcbab3d49d28bf29c9c5c0ee2`.

| Asked name | What is in that commit |
|---|---|
| UI优化施工清单, sections 三–25 | `docs/owner-handover/app-ai-pack-20261108/UI优化施工清单.md` |
| 先读我 | `docs/owner-handover/app-ai-pack-20261108/先读我-给App端AI.md` (the file name is `先读我-给App端AI.md`, not `先读我.md`) |
| 工单-统一实施版 | **Not** inside `app-ai-pack-20261108/`. It is `docs/owner-handover/工单-统一实施版.md`. It was read. |
| 落地清单 | **Not** inside `app-ai-pack-20261108/`. It is `docs/owner-handover/落地清单.md`. It was read. |

These names are cited by the pack or the landing list and are **not** in that commit. No rows were invented from them:

- `iOS优化交接.md` (cited by UI list section 十一)
- `统一实施主账.json` (cited by 落地清单 as the edit source, via a local Downloads path)
- `缺陷总表.md` and `工单-业务必需52条（分端）.md` (cited by 落地清单 §验收和交付边界)
- `小程序已做与剩余对账_20261015.md` (cited by 落地清单 and the work-order file)

## Mini-program SHA

Pages and `/api` literals are from `https://github.com/liboyang42-cpu/hengyin` folder `chengyinhub-xcx`, master `1ca6d3215beee96afdcdfd300dd9176f2d0ac5b3` (2026-11-13 08:09 America/Los_Angeles). hengyin was not edited.

`app.json` has 5 root pages and 168 subpackage pages (173). `docs/parity/page-map.csv` on this app commit has 163 paths. Seventeen `app.json` pages are not in the page-map (matrix PAGE rows, status MISSING), including video bounty, market passes, journey report/landing/seats/promo/settle, topic catalog, merchant payout account, and club payout receiver. Seven page-map paths are not in this `app.json` (`pages/square/list/index`, `pages/talent/search/index`, `pages/templatedetail2/templatedetail2`, `pages/topic/settlement/index`, `subpackageMember/signupInfo/signupInfo`, `subpackageMember/signupInfo2/signupInfo2`, `subpackageTools/capsule/index`). The matrix follows `app.json` for page rows.

`/api/login/phone`, `/api/login/apple`, `/api/login/wechat/app`, and `/api/userInfo` are native `AuthEndpoint` values in `Core/APIConfiguration.swift`. They are not quoted as their own strings in non-test mini-program JS at this SHA (a test permit-list mentions them). The login workflow uses the native enum. That is an app contract, not a silent owner-doc guess.

## Owner doc versus the app commit

UI list section 十一 and 十五 (2026-11-08) say the iOS client was not modified and that UG gameplay is NOT_RUN. `Core/UGGameplay.swift` on `cf2884760` agrees: the types decode a payload, the pack is NOT_RUN, and they do not draw a screen. `Tests/CoreTests/UGGameplayTests.swift` covers that decoder. The matrix marks UG-01…UG-10 IN-PROGRESS H23. It does not mark them DONE because a decoder exists. Where the owner doc says “client not started” and the file says “decoder only”, both are right, and neither is a finished screen.

`先读我` says P1/P2/P4/P7/P8 read APIs are NOT_RUN and that workshop paid install must not be faked. The newer mini-program has journey and market pages the page-map does not list. Those PAGE rows are MISSING. The owner sentence is not used to drop them, and it is not used to mark them done.

落地清单 EXT-10 says this round does not ship Flutter. This repo on `ui/main` is the native Swift app. No Flutter behavior was added.

`先读我` says not to add a friend graph. `/api/friend` remains a gap-list row with no screen requirement invented on top of it.

## Owner doc versus the mini-program

The October 15 work orders say mini-program club dues stay undone. The matrix does not describe dues as a live mini-program flow. OPT-050 stays MISSING.

Section 十二 forbids drawing unapproved abilities (gems as a second wallet, auto-renewal, OTA success, video cash payout). The mini-program is the reference for what a player can do. Those bans stay in the owner rows. Production money switches stay off even if a mini-program page still has a payout screen (`pages/merchant/payout-account/index` is MISSING on the native map, not reimplemented here).

## Gap list versus later client grants

`backend-gap-163.tsv` is from `origin/docs/backend-gaps` `9c21d402a3777ae49bcc818b6d1ceb4b049c12b6` (162 paths). `Core/ChinaReviewedRouteCapability.swift` on `ui/main` later admits some channel, IM, and city-game paths for non-money calls. Admission is not a backend. Gap rows in messaging, club, rewards, workshop, play, and merchant stay IN-PROGRESS on handovers 19–24. City-game paths have a screen and tests and no handover 18–24 branch, so the feature is IN-PROGRESS with no H number, and the path rows stay MISSING.

## Handover branches

`git ls-remote` while this matrix was written found hengyin `feature/game-import-review` at `e10a8e98f22b07f490a82d207d40692caaa67402`. It did not find `ui/cur-ext-games`, `ui/cur-be-gap-im`, `ui/cur-be-gap-club`, `ui/cur-be-gap-rewards`, `ui/cur-be-gap-workshop`, `ui/cur-be-gap-play`, `ui/cur-be-gap-merchant`, or hengyin `feature/be-gap-im`, `feature/be-gap-club`, `feature/be-gap-rewards`, `feature/be-gap-workshop`, `feature/be-gap-play-misc`, `feature/be-gap-merchant`. Handover 25 says those branches were started on 2026-11-13 and have not merged. Rows in those domains are IN-PROGRESS under the names given. No SHA is invented for a branch that was not on the remote. Nothing was force-pushed.

## Money, payout, merchant writes, password

Handover 25 says these are off in production and on for TEST/DEBUG only. The source is narrower:

- Password login is compiled in DEBUG and forced off on China production (`/api/login`).
- The four `ReleaseMoneyWriteSwitch` flags are `false` with no DEBUG branch. DEBUG does not turn payment, payout, withdrawal, or virtual goods on.
- China production `forcedOff` also blocks those pay, cart, product, and bank-withdrawal paths.
- A non-production host skips `refuseUnwiredChinaProduction` only. That is the test-host exception. It is not a production ship, and it is not the switch flipping to true.
- Merchant and coop money writes stay outside `playerWritesEnabled`.

Workflows E2E-11, E2E-12, and E2E-13 follow the source. They do not call payment, payout, or merchant money writes shipped.
