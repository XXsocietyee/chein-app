# mp-states r3 — states sweep (empty / loading / error / offline / signed-out)

Branch `mp/r3-states`, base `origin/ui/combined-r7`. Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md`
(OWNER RULE + OWNER RULE 2). MP source: `origin/mp-source:chengyinhub-xcx`.

One native pattern everywhere:
- empty / error / signed-out / offline → `ContentUnavailableView` (via `CYEmptyState`, `CYErrorState`, `CYContentState`,
  `CYStateView` or a direct call) with the MP `cy-empty` / `cy-error` title and the MP CTA as the one button
  (`.borderedProminent` for 登录 / next step, `.bordered` for 重试);
- loading → system `ProgressView` with a **visible** label carrying the MP loading words (加载中… / 正在加载…).

No Swift compiler in this environment: edits are type-simple and mirror existing call sites.

## Method

`cy-empty` / `cy-error` titles, CTAs and retry labels were extracted from every player `.wxml` (merchant / shop / coop /
organizer / story excluded) and matched against the native string catalogs and Swift sources. A title with no native
match is a queue item (133 at the start). Tab roots first, then their pushed pages.

## Receipt

| Screen | MP state (path → title / CTA) | Native before | Native after |
|---|---|---|---|
| All screens using `CYLoadingStateView` (46 call sites) | `components/cy/empty` kind `loading` 加载中 · `cy-loading-mask` 加载中 | bare `ProgressView()`, words only for VoiceOver | `ProgressView { Text("cy.state.loading") }` — 加载中… / Loading… visible |
| All screens using `CYLoadingState` | same | skeleton block + footnote, no system spinner | `ProgressView` with the caller's MP loading words as the label |
| Official events (`OfficialReadScreen`: activity list / detail / mine / inbox) | `pages/activity/list` loading | overlay `ProgressView()`, label hidden | `ProgressView { Text("official.loading") }` — 正在加载官方活动 visible |
| Social reads (`SocialReadScreen`: guides, public profile, invites …) | loading | `ProgressView()`, label hidden | `ProgressView { Text("social.loading") }` — 正在加载… visible |
| 俱乐部 tab — club list (`ClubHomeView` → `ClubReadScreen usesClubTabStates`) | `pages/talent/list/index.wxml:65` cy-error: 登录后查看我的俱乐部 · 登录 / 当前身份不能查看俱乐部 · 重试 / 俱乐部列表加载失败 · 重试 | generic 请登录后继续 + hint / 暂无俱乐部访问权限 / 俱乐部加载失败 | MP titles (en: Sign in to see your clubs / This identity can’t view clubs / Couldn’t load the club list); same CTA; sign-in drops the extra hint like the MP (no sub) |
| 我的收藏 — topics + posts (`AccountCollectionFavoritesView` → `AccountCollectionIssueView favorites:`) | `pages/mylike/mylike.wxml:19-20,69-70` cy-empty no-permission 登录后查看收藏 · 登录 / cy-error 收藏加载失败 · sub errorMsg · 重试 | 登录后查看收藏和优惠券 with no button; failure title 这些内容没加载出来 / the raw server sentence as the title | 登录后查看收藏 (Sign in to see your favorites) + `.borderedProminent` 登录 when the host provides sign-in; 收藏加载失败 (Couldn’t load your favorites) title, server/network reason as the description, 重试 |
| 搜索结果 (`GlobalSearchView`, MP result merged into search2) | `pages/search2/result/index.wxml:23` cy-error 没能完成搜索 · 重试; `:24` cy-empty 没有找到 | failure 结果未能加载 · 重试; empty 没有找到 ✓ | failure 没能完成搜索 (Couldn’t finish the search) · 重试 (only the generic failure key is remapped; sign-in / not-configured keep their own titles) |
| 集邮册 (`RoamStampAlbumView`) and every roam read using `RoamExperienceIssue` (20 call sites: history, session, summary, stamps …) | `subpackageP3/pages/stamp-album/index/index.wxml:29` cy-error 集邮册无法打开 · 重新载入 | custom `Label` + `CYPillButton` 重试 (not the system pattern); album title 加载失败，请重试。 | `ContentUnavailableView` + `.bordered` retry for all 20 sites; the album passes 集邮册无法打开 (Couldn’t open the stamp album) · 重新载入 (Reload); sign-in / not-configured keep 请先登录 / 未配置 |
| 玩法文档 (`SocialGuideViews` → `SocialReadScreen failureTitle:`) and every `SocialIssueView` (16 call sites) | `subpackageA/pages/infomation/infomation.wxml:63` cy-error 玩法文档加载失败 · sub docsError · 重试 | non-network failures drew a leading `Label` + `Label(重试)` button VStack; generic title 加载失败 | `ContentUnavailableView` for every social issue (server sentence as the description, one `.bordered` 重试); guides list title 玩法文档加载失败 (Couldn’t load the how-to-play docs) |
| 广场帖子详情 (`SquareDetailView` → `SquareIssueView`, 3 sites) | `pages/square/detail` cy-error 加载失败 / 评论加载失败 · 重试 (titles already MP) | leading `Label` + caption + plain `Button` | `ContentUnavailableView`, server sentence as the description, `.bordered` 重试 |
| 主题/路线 reads (`TopicIssueView`, 9 sites) | topic pages cy-error · 重试 | `Label` + bordered button VStack | `ContentUnavailableView` + `.bordered` 重试 |
| 票夹 / ticket detail / enrolled chapters (`TicketWalletIssueView`, 7 sites) | ticket wallet cy-empty no-permission / cy-error · 重试 | `Label` + button VStack | `ContentUnavailableView` + `.bordered` 重试 |
| 附近 (`NearbyTeamsView` → `NearbyLoadIssueCard`, list + 我的) | `subpackageRoam/nearby/index.wxml:62` cy-error 附近信息获取失败 / 当前内容无法查看 · 重试 (login → 去登录) | elevated custom card + `CYPillButton`; titles 附近信息没能读到 / 当前账号无法查看附近信息 | `ContentUnavailableView`, MP titles (Couldn’t get nearby information / This content can’t be viewed), `.borderedProminent` 去登录 or `.bordered` 重试 |
| Page-level spinners with words for VoiceOver only → visible label: 票夹 (`TicketWalletView`), 广场评论 (`SquareDetailView`), 重组队伍 (`TeamReformFlowViews` ×2), 护照邮票 (`PassportView`), 六维 (`MemberAttributesSection`), 首页 search-tab states (`HomeSearchTabParityViews`), 通票货架 (`BundleShelfView`), 我的申诉 (`MemberScoreAppealListView`), 参与人 (`ProfileParticipantsView`), 自由探索通票 (`FreeExploreBundleLaunchView`) | MP `cy-empty kind="loading"` 加载中 / page loading words | `ProgressView()` + `.accessibilityLabel` (or an unlabeled spinner, or a spinner + separate Text) | `ProgressView { Text(<same key>) }` — the words are on screen; unlabeled ones use 加载中… (`cy.state.loading`) |
| 优惠券 (`AccountCollectionCouponsView` → `AccountCollectionIssueView couponWallet:`) | `subpackageMember/components/cy/scene-game-coupon-wallet/index.wxml:3,6,7` 登录后查看我的优惠券 · 登录 / 优惠券暂时没能打开 · sub errorMsg · 重试 / 这里还没有优惠券 · 当前筛选暂无优惠券 | signed-out 登录后查看收藏和优惠券, no button; a server refusal replaced the title with the raw sentence | 登录后查看我的优惠券 (Sign in to see your coupons) + 登录 when the host provides sign-in; server refusal keeps 优惠券暂时没能打开 as the title, sentence as the description; empty titles already MP ✓ |
| 玩法说明详情 (`SocialGuideViews` detail → `SocialReadScreen failureTitle:`) | `subpackageA/components/scene-how-to-play-detail/index.wxml:10,12` cy-error 玩法说明加载失败 · 重试 / cy-empty 这篇玩法说明暂时没有内容 | 暂时无法获取信息，请重试。 / 这篇说明暂时没有正文。 | 玩法说明加载失败 (Couldn’t load this how-to-play guide) · 重试 / 这篇玩法说明暂时没有内容 (This how-to-play guide has no content yet) |
| 投诉与建议 (`ProfileComplaintPreparationView`) | `subpackageMember/complaint/index.wxml:19-35` 登录后发起投诉与查看进展 · 登录 / 可投诉活动加载失败 · sub errorMsg · 重试 / 暂无可投诉的活动 (no sub) | a `Section` of three text lines (可投诉活动没能加载出来 + detail + read line) and a plain button; empty had an extra eligibility hint | `ContentUnavailableView`: MP titles (en: Sign in to file a complaint and follow its progress / Couldn’t load activities you can report), reason as description, `.borderedProminent` 登录 or `.bordered` 重试; empty is the MP title alone. Stale pin in `test_w2_04_p2_member_tools` updated with reason |
| 俱乐部 tab 帖文 feed + 俱乐部详情 帖文 (`ClubCommunityFeedView`) | `pages/talent/list/index.wxml:41` cy-error 动态加载失败 · 重试; `pages/club/detail/index.wxml:156` cy-error 帖文加载失败 · 重试 | grey line 加载失败，请刷新 + a separate bare 重试 row | `ContentUnavailableView` 动态加载失败 (feed) / 帖文加载失败 (club) with one `.bordered` 重试; the bare retry row is suppressed in that state |
| 俱乐部成员 (`ClubMembersView` → `ClubReadScreen`, prefix `club.members`) | `pages/club/detail/index.wxml:291,305` cy-error 成员列表加载失败 · 重新加载 / cy-empty 加入俱乐部后可查看成员 (no CTA) | 俱乐部加载失败 · 重试; non-member 暂未获取到成员名单 + hint + 重试 | 成员列表加载失败 (Couldn’t load the member list) · 重新加载 (Reload); non-member 加入俱乐部后可查看成员 (Join the club to see its members), no button, no hint |

## Gates

See the last commit message on the branch for the gate run that accompanied each push.
