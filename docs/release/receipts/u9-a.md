# u9-a receipt: screenshot-driven visual parity, domain A (player/club/guest rows)

Branch `ui/u9-a` from `origin/ui/next` @ 11b0b01d1. **Code only. Not compiled here**; the integrator compiles. References: private mini-program shot matrix @1c80c5a (not committed, not posted).
Checks: `swiftc -parse` clean on every touched Swift file; `tools/check_scaffold.py` PASS; `tools/check_design_lint.py` PASS (47 existing allowlisted violations, none new). No files added, so `generate_project.py` was not needed.
New strings (EN + zh-Hans, `Localizable.xcstrings`): `homeFeed.nearbyActivities`, `homeFeed.updating.{recommended,nearby,upcoming}`, `homeFeed.editorsPicksFootnote`, `searchMap.retryPage`, `searchMap.clearKeyword`, `globalSearch.empty`, `social.mine`, `pages.crop.back`, `participant.list.editShort`. Changed values: `club.tab.title` (发现 / Discover), `club.tab.empty` (还没有俱乐部), `searchMap.placeholder.player`, `searchMap.partialFailure`, `searchMap.allFailed`, `social.interests` (兴趣标签).
Test touched: `ProfileSelfProjectsFlowTests` now taps the merged "Mine" tab instead of "My projects".

| row | route | state | native file | gaps found | fixed | left (needs logic or decision) |
|---|---|---|---|---|---|---|
| A01 | pages/index/index | normal | HomeFeedView.swift | nearby rail titled 活动精选 (MP 附近活动); no editor-picks footnote | rail is now 附近活动; 编辑精选 · 参加条件以详情为准 footnote | native keeps the search field, Today card and pass card between greeting and rails (native IA, not in MP) |
| A02 | pages/index/index | loading (state-unmet) | HomeFeedView.swift | no 正在更新… line while a loaded rail refreshes | per-rail 正在更新编辑精选/附近活动/即将上线… | — |
| A03 | pages/index/index | error | HomeFeedView.swift | same layout as A01 | covered by A01 | — |
| A04 | pages/index/index | guest | HomeFeedView.swift | same layout as A01 | covered by A01 | — |
| A10 | pages/square/detail/index | normal | SquareDetailView.swift | 举报 hidden in the comment overflow (MP shows it beside the like count) | visible 举报 in each comment row (same report flows, same a11y id) | viewer avatar left of the 留下你的评论 bar; follow "+" on comment avatars |
| A11 | square detail | long-value | SquareDetailView.swift | none beyond A10 | — | — |
| A12 | square detail | no media | SquareDetailView.swift | none beyond A10 | — | — |
| A13 | square detail | loading | SquareDetailView.swift | skeleton is generic rows, MP is image block + lines | — | skeleton shape (shared CYSkeleton) |
| A14 | pages/talent/list/index | mine | ClubHomeView.swift | title 俱乐部 inside the club list (MP 发现 above the 帖文/俱乐部 tabs); extra 你的俱乐部 / 发现 headers | 发现 hero title above the tabs for both tabs; one headerless list | bell (notifications) entry; "N 个近期团" count on cards (no data on the card) |
| A15 | talent list | nearby | ClubHomeView.swift | as A14 | as A14 | as A14 |
| A16 | talent list | empty | ClubHomeView.swift | empty copy 你还没有加入俱乐部 (MP 还没有俱乐部) | copy changed | native also lists directory/owned/events sections below (native entries kept) |
| A22 | pages/search2/index | before | GlobalSearchView.swift | 筛选 was an icon inside the field (MP separate tile with label); recent-routes shelf not in MP; history as rows (MP chips); placeholder said 路线 | separate 筛选 tile; shelf removed; history chips; 搜索主题、活动、俱乐部 | 商家 stays out of the player placeholder (merchant gate) |
| A23 | search2 | history (state-unmet) | GlobalSearchView.swift | as A22 | as A22 | — |
| A24 | search2 | no category | GlobalSearchView.swift | categories hide when empty (already) | — | — |
| A25 | pages/search2/result/index | image | GlobalSearchView.swift, SearchMapComponents.swift | 全部 tab carried a count; failure copy 部分结果未能更新 + kind list (MP 内容搜索未完成，重试本页 banner); tags joined as text (MP chips); no clear (x) | 全部 without count; banner with 重试本页 on indigo ground; tag chips; clear button | — |
| A26 | search result | multi | same | as A25 | as A25 | — |
| A27 | search result | empty (state-unmet) | GlobalSearchView.swift | empty copy 没有找到匹配的地点 (MP 没有找到); 刷新搜索结果 only under results | 没有找到; refresh shown whenever not loading | — |
| A28 | search result | loading | GlobalSearchView.swift | no in-field 搜索中 indicator | spinner in the field while loading | skeleton is row-shaped, MP card-shaped |
| A30 | pages/searchmap/index | no location | SearchMapExplorerView.swift | MP 定位权限未开启 · 去设置 card | — | explorer has no location-permission state (area is picked manually); needs logic. Map screen layout (full-bleed map, floating search) is a native form layout |
| A31 | searchmap | summary | SearchMapResultsCapsule.swift | capsule said 查看全部 N 个结果 when no row has a map point | 这一带还没有活动 · N 个活动只在列表显示 (still opens the list) | — |
| A32 | pages/member/index/index | player | MemberHomeHeader.swift, AccountView.swift | 票夹 was a half tile beside balance; city glyph was a pin | full-width 票夹 pill; location-arrow glyph | MP tabbed 我的/成就/关于 profile vs native Passport/Account form (IA decision); balance tile still in header (MP shows it under 我的资产) |
| A34 | member home | empty (state-unmet) | MemberHomeHeader.swift | as A32 | as A32 | 我的资产 / 通行证与礼品 order (IA decision) |
| A35 | member home | points skeleton | ProfileWeeklyPoints (via SocialPublicProfileView) | 积分任务 sheet not reviewed in depth | — | sheet anatomy check |
| A36 | member home | posts | SocialPublicProfileView.swift | no 好友/关注/粉丝 counters in the head | counters row (em dash when omitted) | — |
| A37 | member home | achievements | SocialPublicProfileView.swift | counts repeated in 成就 section | — | points/ranking card anatomy; duplicate counts list kept (UI tests read `social.profile.friends`) |
| A38 | member home | about | SocialPublicProfileView.swift | 兴趣 (MP 兴趣标签); no 加入时间 | 兴趣标签 | 加入时间: no join date in `SocialPublicProfile`; 探索与更多 list lives in Account |
| A39 | subpackageMember/signup/index | tickets | TicketPassSheet.swift | title 我的票 (MP 票夹) | title 票夹 | 开始游戏 CTA on the pass (play provider not injected into the sheet); "+" add button; title chevron switcher (native uses overflow picker) |
| A40 | signup | empty | TicketPassSheet.swift | MP 还没有票 only; native adds body + 查看全部票券 | — | kept native body/CTA |
| A41 | signup | expired (state-unmet) | TicketPassSheet.swift | as A39 | as A39 | as A39 |
| A61 | signup | loading | TicketPassSheet.swift | skeleton is small block, MP full pass silhouette | — | skeleton shape |
| A42 | pages/userinfo/userinfo | other | SocialPublicProfileView.swift | follow / message were plain rows; no counters | 关注 + 发消息 side-by-side pills; counters row | ⋯ more button; city line; MP hides 帖文 tab for others |
| A45 | pages/mylike/mylike | topic | AccountCollectionFavoritesView.swift | no 据点 tab; no share button on cards | — | 据点 (node favorites) has no reader; card share needs a share URL |
| A48 | mylike | refreshing | AccountCollectionFavoritesView.swift | none beyond A45 | — | — |
| A52 | pages/gerenziliao/gerenziliao | default | ProfileEditView.swift | 手机号 sat between 昵称 and 个人介绍 | [昵称, 个人介绍] then 手机号 in its own group | 更换背景 under the name (cover lives in its own section) |
| A53 | gerenziliao | editing | ProfileEditView.swift | intro editor sheet already present | — | — |
| A54 | pages/crop/index | missing source | MiniCropView.swift | cancel/use-original/confirm shown with no image (MP only 返回上一页) | single full-width 返回上一页, info glyph | — |
| A56 | pages/agreement/index?type=service | normal | SettingsLegalDocumentView.swift | 本文档仅提供中文版本 shown above the title in Chinese UI | note only for non-Chinese UI | version/effective-date/no-acceptance lines kept (compliance) |
| A57 | agreement?type=deregister | normal | SettingsLegalDocumentView.swift | as A56 | as A56 | — |
| A58b | pages/privacy/index | pending | UsageConsentGateView.swift | title 隐私与定位 (MP 隐私保护); longer body | — | consent copy is compliance text; title change would touch EntryUsageConsent UI tests — decision |
| A58 | privacy | revoked | PrivacyProtectionView.swift | MP sheet lists 首页城市自动定位 / 附近的人位置分享 / 漫游定位 / 我的待审媒体 controls | — | those controls live in Settings › 隐私与定位 by design (file header note); decision |
| A59 | pages/shezhi/shezhi | club | SettingsView.swift | MP flat list; native grouped, searchable | — | rows exist; layout is native IA (decision) |
| A60 | pages/address/address | list | ProfileParticipantsView.swift | edit/delete only in swipe actions (MP visible 编辑 and ×) | visible 编辑 and × per row (open the existing review flows) | — |

Shared components touched within this domain only: `SearchMapComponents.swift` (result card tags) and `SearchMapResultsCapsule.swift` (search screens). No design-system files changed.
