# ui/cur-search

Task 62. Branch `ui/cur-search` from `origin/ui/main` `6feee423adc8962d7613f8ba93b77ffdc93ea1c4`.

Mini-program source: public repo `liboyang42-cpu/hengyin`, commit `73f4f7be45aa5b49381baa2c1aff57e1b2245fad` (`fix: 平台自玩路线走查第四轮——结算后落点、上传超时、太远弹窗等八项 (#829)`), read over HTTPS. Files: `chengyinhub-xcx/pages/search2/index.wxml`, `chengyinhub-xcx/pages/search2/index.js`, `chengyinhub-xcx/pages/search2/result/index.js`, `chengyinhub-xcx/pages/searchmap/index.wxml`, `chengyinhub-xcx/utils/discover-search.js`, `chengyinhub-xcx/pages/templatedetail/shelf/art.js`, `chengyinhub-xcx/pages/templatedetail/shelf/index.js`, `chengyinhub-xcx/tests/unit/search-sort-and-hot-words-contract.test.js`.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. `ReviewedAreaSwitch` is not redeclared. `www.chengyinhub.com` stays closed. `docs/release/contract-failing-baseline.txt` is unchanged. Unknown copy stays an em dash. A decoded `0` stays `0` (`totalTime` and play `duration` of 0 do not match “within an hour” or “within 5 minutes”).

Swift was not compiled. `swiftc` is not on this machine. Screenshots were not taken.

## Aligned

Search list (`pages/search2`), already on the shared filter sheet and left in place:

- Category chips on the search page.
- Date chips 今天 / 明天, plus a chosen start and end day.
- Price 最低区间 / 最高区间. Bounds stay client-side. `0` is not treated as an active minimum.
- Reset.

Search list sort, added:

- One chip, 最近 / Recent (`search.sort.recent`). It is the default `create_time desc` order.
- `SearchDiscoveryFilterParity.listSendsActivitySortType(.recent)` is false. Global search still calls activity list with `sortType: nil`. The chip is not written as `sort_type`.

Search map (`pages/searchmap`), already present and kept:

- 商家标签, 城市角色, category, dates, price.
- Sort 最近 (`sort_type` 1, Nearest) and 最热 (`sort_type` 2, Popular). The current `searchmap/index.wxml` still renders both chips (`data-value="1"` and `data-value="2"`), and `searchmap/index.js` still sends `sort_type`. The earlier removal applied to search2, not to the map. The map chip stays.

Discovery shelf (`pages/templatedetail/shelf`), wired through the existing topic and play template readers:

- Chip 全部 / All.
- Topic row, only tags that match a visible topic: 城市探索, 剧情叙事, 生存逃脱, 解谜推理, 科幻异常, 怀旧人文, 一个人, 两小时内. A tag chosen from 全部分类 that is not on that row is inserted at the front, matching `tagSet`.
- 全部分类 / All categories, grouped: 类型, 风格, 适合谁, 时长.
- Game row, only tags that match a shelf game: 营销引流, 插件玩法, 解谜, 运动, 竞技对抗, 社交破冰, 味觉, 5 分钟内, plus the same 全部分类 behavior.
- Game groups: 用途, 玩法, 题材, 适合的店, 人数, 时间, 分区.
- Shelf games are pack type 0, one of the 25 titles, not a `G<digits>｜` segment title, and the highest id when titles repeat. The shelf load uses the existing `discoveryPlayTemplates(keyword:packType:)` with `pack_type` 0. That value is the request, not a chip.
- Hidden topic 野生邻居观察局 is dropped by theme key, including a name that only prefixes a theme.
- Topic duration uses `totalTime` seconds. A stored 0 stays 0 and fails every “greater than 0” duration tag.
- Result-tab labels that the existing parity model already shows: 路线 → 主题 / Topics, 动态 → 帖文 / Posts. The on-screen kind bar already used `searchMap.kind.topic` and `social.posts`.

## Skipped

- Search-list 最热. It is not in the rendered search2 sheet. The only 最热 there is an HTML comment saying the sort was removed. `search-sort-and-hot-words-contract.test.js` asserts the stripped search2 markup does not match 最热. It was not added back. The map page is the place the current source still shows it.
- Sending search-list 最近 as activity `sort_type`. CU-M-66 forbids it. `sort_type` 1 on the map means 附近的活动, not the list’s 最近.
- A discovery sort. The shelf has no sort control.
- Pack chips 全部形态 / 单节点玩法 / 剧情包 / 店铺 IP 包. They are not on the shelf.
- Topic API category chips, and 推荐 as the “all” chip. The shelf’s all chip is 全部, and its tags are the shelf tags, not `/api/category/list`.
- Topic tag 竞技对抗. The source test is an empty name list, so the tag matches nothing and `tagSet` hides it. The rule is kept; the chip is not forced on.
- A 场景 dimension. The source comment says not to add one.
- Result chips 主题模板 and 玩法模板. They are not in `GlobalSearchKind`. Adding fetches for them would be a second search stack. Those templates stay on the discovery shelf. 帖文 stays the existing moments tab.
- Topic content shelves (全部主题, 两小时内玩完, 科幻异常, 城市记忆, 一个人也能玩) as extra chips. The filter row already has the duration and style tags. The unfiltered topic list is one list.
- Replacing the unfiltered game home sections (featured, latest, recommended, must play, hot). Those are the existing `homeData` shelves, not sort chips. Choosing a shelf tag filters the shelf catalog instead of those sections.
