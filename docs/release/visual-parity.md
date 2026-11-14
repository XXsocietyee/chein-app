# Visual parity — top player pages

Source: public `liboyang42-cpu/hengyin` `master` `8390d99e3f7a54899c493ecb3d70e9aa8f57dbca`, tree `chengyinhub-xcx`, read over HTTPS. Work started from `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46` and was rebased onto `origin/ui/main` `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0` before push. Page targets come from `docs/parity/page-map.csv`. Unknown values stay an em dash. Money on `www.chengyinhub.com` stays closed. `swiftc` is not on this machine, so this is not a typecheck.

| Page | Mini-program | Native | What differed | Result |
|---|---|---|---|---|
| Home | `pages/index/index.wxml` | `App/HomeFeedView.swift` | Feed tabs were 路线 / Routes. Empty copy was 还没有合适的内容 plus a category hint. An 探索 header and a 全部分类 picker sat above 主题 / 活动. Stream cards folded 价格 / 时间 / 地点 into one overlay line. | Fixed. Tabs are 主题 / Themes and 活动 / Activities. Empty titles are 暂时没有主题 and 暂时没有活动 (keyword hint only after a search). Header and category picker removed. Stream cards show 价格, 时间, 地点. Missing price or place is —. Missing time is 长期开放. |
| Discover | `pages/talent/list/index.wxml` (nav title 发现, tabs 帖文 / 俱乐部) | `App/ClubHomeView.swift`, `App/ClubCommunityViews.swift` | Page title was 俱乐部 / Clubs. The 帖文 feed stacked a second 帖文 header under the tab. | Fixed. Title is 发现 / Discover. Discover feed no longer repeats that header. Empty title 还没有帖文 was already `club.tab.feed.empty`. The em dash row when author-square delete is not connected arrived on `ui/main` and was left as the unknown state. |
| Club home | same `pages/talent/list/index.wxml` club tab | `App/ClubHomeView.swift` | List was split under 你的俱乐部 and 发现. Player empty copy was 你还没有加入俱乐部. | Fixed. One list: created, then joined, then nearby, no group headers. Empty title is 还没有俱乐部 / No clubs yet. Merchant empty 本城还没有俱乐部 was already correct. Create row 创建你自己的俱乐部 stays above the list. Directory, owned, and events rows below the list are native destinations and were left in place. |
| Search | `pages/search2/index.wxml` | `App/GlobalSearchView.swift` | Section order already matches: field and 筛选, then 搜索历史, 推荐搜索, 类别 (hidden only when the directory is known empty), then 在地图上找活动与主题节点. | No change. The extra “more ways” menu stays so nearby, layers, and shops remain reachable. |
| Activity sign-up | `pages/activity/baoming/baoming.wxml` | `App/RegistrationSheetView.swift` | Section order already matches: 参与人信息, 活动信息, 费用明细. | No change. |
| Wallet | `subpackageA/pages/assetcenter/earnings/index.wxml` | `App/WalletCommerceViews.swift` | Earnings title 账户收益 and the 可提现 row are already on the native overview. The mini page also has a full 提现 sheet (amount, name, bank, consent, 确认提现). | Not restyled. Bank payout stays closed. |
| Passport / me | `subpackageMember/components/cy/profile/index.wxml` (mounted by `pages/member/index/index.wxml`) | `App/AccountView.swift`, `App/MemberHomeHeader.swift` | Identity card and the 票夹 primary action already match the header. Nav title in the mini-program is 主页; self tabs are 我的 / 帖文 / 成就 / 关于. Native passport title is 护照. | Not rebuilt. `RootTab.playerTitleKey` for mine is `tabBar.passport`, and `RootTabTests` pins that key. The account form was not turned into those four tabs. |
| Topic detail | `pages/topic/index/index.wxml` | `App/TopicDetailView.swift` | — | Not started. The wxml was located; the native view was not walked. |
| Play runtime | `pages/play/index.wxml` | `App/PlayExperienceView.swift` | — | Not started. The wxml is the play shell (about 2,000 lines); the native view was not walked. |
| Roam | `pages/roam/index.wxml` | `App/RoamBrowserView.swift` | — | Not started. The wxml was located; the native view was not walked. |
| City | no player city page in `app.json` or the checked-out tree | — | — | Source not found. Not restyled. Merchant `pages/merchant/citynode` is not this page. |
| Club detail | `pages/club/detail/index.wxml` | `App/ClubDetailView.swift` | — | Not started. The wxml was located; the native view was not walked. |
| Club chat | no club-chat wxml. `pages/club/detail/index.wxml` says 进入群聊 was removed from the header; chat stays on the IM list | — | — | Source not found. Not restyled. |
| IM | `subpackageB/pages/im/list/index.wxml`, `subpackageB/pages/im/chat/index.wxml` | `App/MessagingHomeView.swift`, `App/MessagingHistoryView.swift` | — | Not started. Both wxml files were located; the native views were not walked. |
| Community square | `pages/square/list/index.wxml` is not in this tree. `app.json` only ships `pages/square/detail`. Page map merges the old list into the talent 帖文 tab | talent 帖文 tab above | — | List source not found. The live post feed is the Discover tab, compared above. |
| Community post | `pages/square/detail/index.wxml` | `App/SquareDetailView.swift` | — | Not started. The wxml was located; the native view was not walked. |

Copy added or changed (en and zh-Hans):

| Key | en | zh-Hans |
|---|---|---|
| `homeFeed.topics` | Themes | 主题 |
| `homeFeed.topicsEmpty` | No themes right now | 暂时没有主题 |
| `homeFeed.openEnded` | Open-ended | 长期开放 |
| `homeFeed.status.price` | Price | 价格 |
| `homeFeed.status.time` | Time | 时间 |
| `club.tab.title` | Discover | 发现 |
| `club.tab.empty` | No clubs yet | 还没有俱乐部 |

`homeFeed.activitiesEmpty` (No activities right now / 暂时没有活动) and `homeFeed.place` (Place / 地点) were already in the catalog.

## Handover 49

Compared the rows above that were marked not started, against the same public `hengyin` `8390d99e` tree. Home, Discover, and Club home were not opened again. Search, activity sign-up, wallet, passport, city, club chat, and the square list stay as recorded above. `swiftc` is still absent.

| Page | What differed | Result |
|---|---|---|
| Topic detail | Middle tab was 路线节点. Free exploration's third tab was always 路线. The details tab still showed the venue card the source removed. Description was titled 主题介绍, and the includes list showed beside it. 场次 showed for every product type. Reviews empty title was 还没有人评价过这条路线 plus an extra line. Lineup was 阵容. Route empty added a second sentence under 路线配置中. | Fixed. Tabs are 详情 / 故事 / 路线, and 地点 when `productType == 2`. Story section title for free exploration is 护照. Description is 活动内容, and the includes list shows only when there is no description. 场次 only for free exploration. Empty reviews say 还没有评价. The points line 评论积分须符合参与及首评条件，以实际积分记录为准 sits under the reviews. Lineup is 参与品牌. Route empty is only 路线配置中. The bottom action bar and the stop-count row stay; the contract still requires them. |
| Play runtime | Tools row was 旅程记录. The mini-program shell is a story stage plus a tools drawer (开始游戏, 继续故事, 同行者榜, 我的游玩记录). The native screen is still the section list. | Label fixed: 我的游玩记录 / My play history. The stage was not rebuilt. 同行者榜 and 还没有消息-style empties that already matched were left. |
| Roam | Intro title 漫游, tabs 开始漫游 / 漫游护照, and the 附近活动 peek are already on `RoamBrowserView` / `RoamHomeTabsView`. | No change. |
| Club detail | Public tabs in source are 帖文 / 活动 / 概览, plus 管理. Native posts tab said 帖子. Header meta (类型 · 成员, 公开加入 / 需审核加入) already matches. Source removed 进入群聊 from the header. | Posts tab is 帖文. The posts-tab chat row stays; `test_club_detail_tabs.py` still requires `club.chat.entry`. |
| IM list | Empty action said 去广场找人. Title 消息 and empty 还没有消息 already match. Segments stay 全部 / 频道 / 私信 (iOS Messages layout). | Empty action is 去发现找人 / Find people in Discover. |
| IM chat | Empty title is already 还没有消息. Source nav title is blank with the name under it, or 系统通知. Native title stays 聊天. | No further change. |
| Community post | Closed title was 当前账号未开放社区. Empty comments added 说说你对这条动态的想法吧 under 还没有评论. Composer placeholder 留下你的评论 and deleted-comment line 该评论已删除 already match. Actions stay like, comment, favourite, share. | Closed title is 社区暂未开放 / Community isn't open yet. Empty comments are only 还没有评论. |

Copy added or changed (en and zh-Hans):

| Key | en | zh-Hans |
|---|---|---|
| `topicXcx.tab.nodes` | Story | 故事 |
| `topicXcx.tab.places` | Places | 地点 |
| `topicXcx.reviews.emptyTitle` | No reviews yet | 还没有评价 |
| `topicXcx.section.lineup` | Participating brands | 参与品牌 |
| `club.detail.tab.posts` | Posts | 帖文 |
| `square.xcx.closedTitle` | Community isn't open yet | 社区暂未开放 |
| `im.inbox.emptySquare` | Find people in Discover | 去发现找人 |
| `journey.record.title` | My play history | 我的游玩记录 |

