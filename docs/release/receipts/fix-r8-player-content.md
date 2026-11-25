# Receipt: fix/r8-player-content (Claude App, r8 audit rows)

- **Branch:** `fix/r8-player-content`, from `origin/ui/combined-r7` @ f5f3006d7 (re-merged before each push; r7 did not move).
- **Queue:** `origin/audit/parity-r8-player-content:docs/audit/parity-r8/player-content.md` plus the A–D group files. Only "Claude App" rows were taken.
- **Strings:** `docs/port/strings/fix-r8-player-content.json` (xcstrings shape, en + zh-Hans). Until the integrator merges it, `tools/check_scaffold.py` reports 3 keys that are not yet in the catalog (`merchant.content.contactHost`, `im.composer.plus`, `discovery.templateDetail.readonly`). Base r7 passes that check, so this is the merge step, not a code fault.
- **For the integrator:** the fragment also **overrides 4 existing catalog values**. The r3-b fragment never landed for the first two. Merge with "fragment wins":
  - `official.bucket.upcoming` → 即将上线 (R7-PC-C3-3)
  - `official.detail` → 活动详情 (R7-PC-C4-5)
  - `searchMap.categoryFailed` → 类别加载失败 (R7-PC-A3-5)
  - `searchMap.citySearch` → 在地图上找 (R7-PC-A3-5)
- **No compiler here.** Every API used was grepped on r7 first.
- **Contract checks:** a local script ran every `Tests/ContractChecks` file that names a changed file, on r7 and on this branch, and compared the failure sets.
  - Result: no new failures.
  - The hash pins I touched were re-pinned with a comment naming the row: `test_merchant_station_submission_import` (EDITOR_BASE_SHA), `test_activity_publishing_wizard` (PREFIX_SHA only), `test_activity_registration_parity_w2_06`, `test_topic_template_name_search`, `test_social_guide_templates` (destination binding assertion), `test_official_detail_parity_w2_06`, `test_official_preference_ui_regressions`, and the `official.price` identifier entry in `docs/release/ui-strings-pages-activity-official-detail-index.json` (`test_cb212_official_detail_page_ready`).
  - `check_typography_lint.py`: PASS.

## Closed

| id | sev | what | files |
|---|---|---|---|
| R8-PC-D9-1 | P0 | 举报对方 is hidden unless a live `CommunityMemberReportClient` (writesEnabled) is on the session. There is none today, so the dead-end alert can no longer be reached. | App/MessagingHistoryView.swift |
| R7-PC-B3-2 | P0 | merchantapply: `MerchantApplyPickerGapView` (map picker, ≤9 photos, 承接说明) is mounted as a sheet in place of the raw address / longitude / latitude / picUrl / activityDesc fields. It writes through the same dirty-tracking bindings, and picUrl stays comma-joined as in the MP. Photo upload is still for Cursor (see below). | App/MerchantContentEditor.swift |
| R7-PC-B3-3 | P1 (part) | merchantapply 承接标的 summary (stop, then route · chapter) from the deep link's names and from the in-app 承接 rows. | App/MerchantContentEditor.swift, App/MPReviewedPageScreen.swift, App/MerchantContentViews.swift |
| R7-PC-B1-7 / R7-PC-C1-6 | P1 (part) | The review composer has the MP 5-star row (`icon_star2`/`icon_star1`, 44 pt, VoiceOver selected trait) in place of the numeric Picker, and text is capped at the MP 300. Photos need Core `img_arr`. | App/ContextualReviewComposer.swift |
| R7-PC-D9-3 | P1 | The chat composer `+` is a menu: 图片 / 位置 / 路线 push the conversation's existing send controls, and 投票 (when allowed) opens the poll composer. | App/MessageActionComposer.swift, App/MessagingHistoryView.swift |
| R7-PC-B2-4 | P1 | 我的项目 topic rows open the project home (`MerchantContentDocumentView(.project)`, MP merchantinfo?topicId=). The creator toolbar is kept. | App/ProjectOwnedContentViews.swift |
| R7-PC-B2-3 | P1 | The merchantinfo deep link and the 我的项目 project home inject `merchantContentSupplyDestination` / `merchantOfferWithdrawalDestination` (new `merchantProjectHostDestinations(session:)`). | App/ProjectOwnedContentViews.swift, App/MPReviewedPageScreen.swift |
| R7-PC-B2-2 | P1 | 联系主办 on the join view (`hostInviteId` / `coopInvite.inviteId`) goes through the reviewed `CoopFlowRequestPreview(.contact)`, and from there to the returned chat. | App/MerchantContentViews.swift |
| R7-PC-B2-5 | P1 (part) | MP enum copy: 承接方式 (权益/计酬/引流承接), and registration status (待审核/已通过/已驳回) where `status` is a registration. | App/MerchantContentViews.swift |
| R7-PC-C1-7 | P1 | 关于这场活动 moves to the first fold, above the people section. | App/ActivityDetailView.swift (+ re-pin) |
| R7-PC-D1-1 | P1 | The pushed publish menu's 我的项目 row opens `SessionCreatorProjectsView` (`makeProjects`), the same as the tab root. | App/PublishingModesViews.swift, App/SessionPublishingModesView.swift (+ re-pin) |
| R7-PC-D3-2 | P1 | Article https `<img>` / `<a>` render as `SocialArticleRichBlocksView` under the literal text renderer. The text renderer keeps its no-link contract. | App/SocialGuideViews.swift |
| R7-PC-A7-1 | P1 | Shelf topic rows and global-search 主题模板 rows open the topic-preview deck, and 查看详情 pushes the detail. | App/DiscoveryTemplateBrowserView.swift, App/GlobalSearchLinksAndTemplates.swift (+ re-pin) |
| R8-PC-A8-1 | P2 | A missing template author shows 创作者, not 城瘾. | App/DiscoveryTemplateDetailView.swift |
| R8-PC-A6-1 | P2 | A `readonly=1` link toasts 当前身份不能编辑模板 on 应用. | App/DiscoveryTemplateDetailView.swift, App/MPReviewedPageScreen.swift |
| R7-PC-A6-2 | P2 | A guest who taps 应用 signs in over the page, and adoption resumes after the re-read. | App/DiscoveryTemplateDetailView.swift |
| R7-PC-A6-4 | P2 | Numbered 规则 steps clamp to 3, with 更多 / 收起. | App/DiscoveryTemplateDetailView.swift |
| R7-PC-A2-7 | P2 | The guide's 更多玩法 catalog gets the session template-tab factories through an environment value. The section itself stays session-free (contract). | App/SocialGuideTemplateSection.swift, App/ProfileGuideHost.swift, App/MPReviewedPageScreen.swift |
| R7-PC-A4-2 | P2 | Template search results are cover cards (row layout at accessibility sizes). | App/SearchMapComponents.swift |
| R7-PC-A5-5 | P2 | The search-map result sheet has a visible 在地图中打开 under each card. | App/SearchMapResultsCapsule.swift |
| R8-PC-C1-1 | P2 | Without a tab switch, the guest 立即报名 presents `LoginView`. | App/ActivityDetailView.swift |
| R8-PC-C6-1 | P2 | A scope change during the stats read resets the row to idle. | App/OfficialPrivateViews.swift |
| R7-PC-C4-3 | P2 | The 价格 暂无价格信息 row is removed; its UI test and contract pins are retired. | App/OfficialEventDetailView.swift, Tests/AppUITests/OfficialEventFlowTests.swift, 2 contract checks |
| R7-PC-C1-5 | P2 (part) | Per-ticket 场次已开始 / 已结束 / 报名已截止 chip (Core `TicketWindowRule`). | App/ActivityPresentationComponents.swift |
| R7-PC-C3-3, R7-PC-C4-5, R7-PC-A3-5 | P2 | Fragment values (see the integrator note above). | docs/port/strings/fix-r8-player-content.json |
| R8-PC-B1-2 | P2 | The 还没有评价 card opens the composer. | App/TopicDetailView.swift |
| R7-PC-B1-22 | P2 | 分享卡片 (`TopicSharePosterCardView`) sheet beside the ShareLink. | App/TopicXcxSections.swift, App/TopicDetailView.swift |
| R7-PC-B1-18 | P2 (part) | The MP `routeNote` sentence (in order / N 站 / 步行约 N 公里; free explore: N 家). | App/TopicXcxSections.swift |
| R7-PC-B4-6 | P2 | Pricing `scope=MERCHANT` comes from the link or the owner sale route and feeds the preview input and confirm. | App/PublisherLifecycleViews.swift, App/TopicXcxSections.swift, App/TopicDetailView.swift, App/MPReviewedPageScreen.swift |
| R7-PC-D2-1 | P2 | The guide template detail / catalog is pushed, not a sheet. | App/SocialGuideTemplateSection.swift (+ re-pin) |

## Left open (with reason)

- **R7-PC-B4-3 (P1):** `PublisherPricingPreview` has no tickets, fee rate, sale status or settlement fields, so the gap section has nothing to show. Core is needed first (see "for Cursor").
- **R7-PC-C2-1 (P1):** `ActivityDetail` does not decode child-age range, 包含内容, 商家暂停营业 or pass coverage, and quote/create has no `childAge`. Core is needed first.
- **R7-PC-B1-6 (P1):** play-nodes progress, nearby teams and the free-explore catalog are only in the unmounted `PlayerContentGapService`, which returns raw replies. A session service and decoders are needed first.
- **R7-PC-B1-12 (P1):** depends on R8-PC-B1-1 (Core: self-play create).
- **R7-PC-D1-4 (P1):** the inline shelf needs `TemplateAuthoringMineView`'s List split into an embeddable section, with its review/state machine. That refactor is too large to do without a compiler. It is still reachable through 查看我的节点玩法.
- **R7-PC-A4-1 (P1):** there is no square post detail view to route post rows to, and `GlobalSearchView` is whole-file hash-pinned.
- **R7-PC-A5-2 (P1), R7-PC-A5-6, R7-PC-A3-4 (P2):** `SearchMapExplorerView` / `SearchMapFilterSheet` are whole-file pinned by `test_global_search_category_recovery` and `check_search_map*.py`. The audit routes that re-pin to Cursor Core.
- **R7-PC-B2-5 (rest):** fully designed merchantinfo rows. Only the enum copy is done here.
- **R7-PC-C5-2:** per-card busy text needs an observable `OfficialActionCoordinator.state` (it is a plain class).
- **R7-PC-B1-13:** the session picker selects activities. `TopicSessionSelectionFlow` has no ticket preselect.
- **R7-PC-A1-1:** there is no session relocate hook (clearing `roamArea` does not re-run location).
- **R7-PC-A1-4:** 地点 sits inside the card's Button label. A separate tap target needs a card restructure (long-press and the VoiceOver action exist).
- **R7-PC-A1-7:** no public share URL for 首页 yet.
- **R7-PC-A2-6:** horizontal rails per shelf group are a layout restyle; it is left for the restyle lane.
- **R8-PC-B6-1:** deleting `PublicCatalogView` also drops `Tests/AppUnitTests/PublicCatalogViewsTests.swift`. Leave that to the coordinator with a compiler.

## For Cursor (Core pieces my App work needs)

1. Merchant apply photo upload: an uploader for merchantapply `picUrl` (MP index.js:504-508). `MerchantApplyPickerGapView.onSelectPhotos` is a no-op until then. Also `/api/merchant/info` on the session, for the shop card (B3-3 #1).
2. Review composer photos: send ≤9 `img_arr` and cap contents at 300 in `ContextualReviewDraft` (B1-7 / C1-6).
3. `PublisherPricingPreview`: per-ticket rows, fee rate, sale status and 结算待处理, for `TopicPricingGapSection` (B4-3).
4. `ActivityDetail` decode: child-age range, 包含内容, merchant closed, pass covered; and `childAge` in quote/create (C2-1).
5. A session-scoped player-content service for `/api/play/nodes` progress, `/api/team/nearby` and `/api/free-explore/bundle/catalog`, with decoders to `TopicRouteTeamSummary` / `TopicFreeExploreMerchantCard` (B1-6).
6. `TopicMerchant.derivativeBenefits`, for the 到店礼 clause of the route note (B1-18).
7. Re-pin the search-map family (`GlobalSearchView`, `SearchMapFilterSheet`, `SearchMapExplorerView`) so that A3-2/3/4, A4-1/3/4, A5-2/3/6 can land.
8. Make `OfficialActionCoordinator` observable, or expose a published state (C5-2).
9. `SearchMapDestination.post(Int)` plus a square post detail, for unified-search post rows (A4-1).
