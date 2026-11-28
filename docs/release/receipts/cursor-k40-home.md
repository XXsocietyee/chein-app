# K40 home / discovery

Branch `cursor/1128-k40-home` from `origin/ui/combined-r7` @ `a7c956335`. Audits: `1128-plan` domain home, `1128-functions` Tab 1, `1128-ada` mp-home behaviour. Re-checked on that pin. No restyle. No backend change: `api/template/info`, `api/template/list` and `api/template/homeData` are already `liveInProduction`. Money switches, `AppSession.swift` (7977) and `AppCompositionRoot.swift` (4175) line counts, and init order are unchanged. The home role chip 「商家」 stays a `Label`.

Player path covered by `K40HomeDiscoveryCompositionTests` (`RegionalLaunchConfiguration.reviewedDeployment` + `makeComposition`). No Swift compiler on this runner; the contract tests and the gates below ran here.

Gates: `tools/generate_project.py`, `tools/check_scaffold.py` PASS, `tools/check_a11y_lint.py` 0 new, `tools/check_design_consistency.py` PASS, `tools/check_appsession_ratchet.py` PASS, `tools/contract_ratchet.py --check` new 0 (46 failing, baseline 46).

Tally: **n=3 fixed**, **m=22 already fixed**, **k=3 owner-only**. One deferred-merchant row. Map, publish, city-game and ADA layout rows are not this agent.

## Fixed

| # | Audit row | Close |
|---|---|---|
| 1 | H-04a / function P2-3 city locate | `HomeCityCentre` now has all 20 `HomeHeroCityNames.manualOptions` cities (WGS-84, city-hall). 同意 still takes one on-device fix and stores the nearest city within 100 km. A fix at each city's own centre maps to that city (上海–苏州 is 85 km, so Suzhou's centre stays 苏州). The coordinate is not sent. `api/map/reverse-geocode` stays off the home path. Extends @ `c2e84e360`. |
| 2 | Function audit template detail load, search template results, discovery home shelf | Those reads were built by `DiscoveryService` and then refused by the release composition. `PublicPlayTemplateReadRoute` admits the exact POST bodies (`info` form `id`, `list` form `pageNum`/`pageSize=50`/optional `keyword`/`pack_type`, `homeData` JSON `{}`) only when `.homeAndSearch` is granted and the viewer is a public template viewer. `myinfo`, `scope`, extra fields, a bad id and the public-topic-only grant stay refused. |
| 3 | Function P2-3 / activity 关联玩法模板 rows | `memberTemplateList[].id` decodes as `publicTemplateID` when it is a positive int or a canonical numeric string. imgUrl and answer stay dropped. The session path opens `DiscoveryTemplateDetailView` (public `api/template/info`). A row with no id, and every fixture that does not pass a destination, stays a label. |

## Already fixed

| # | Audit row | Where |
|---|---|---|
| 1 | H-01a home section order | On the pin. Home lane merge @ `283c21721`. |
| 2 | H-01b rail taps and per-section empty/error | On the pin. Stream empty action `homeFeed.empty.switchKind`. |
| 3 | H-01c city rail (我的地盘) | Kept by owner round-1 Q1. The rail does not ask for location on load (`CityHomeRail` uses a fix only when already authorized). Moving the rail is K40-city. |
| 4 | H-02b P21 回到游戏 | @ `30b72903c`. |
| 5 | H-05e guest 俱乐部 search | @ `7d8d5e6db`. `clubRows` no longer requires a token. |
| 6 | H-12a topic beta graduate | On the pin. `api/topic/beta/graduate`. |
| 7 | H-14 topic detail entries from home/search | On the pin. |
| 8 | H-17 动态 only while the community read is on | @ `4fb288bf7`. |
| 9 | H-18 guest home list/detail reads | On the pin. Nil token, `.homeAndSearch`. |
| 10 | P2-2 topic-template share, activity share link, topic 屏蔽作者 memberId | @ `291ed4940`. Landing is owner-only (row k3). |
| 11 | P1-8 写评价 on topic and activity | @ `460ec4d2b`. |
| 12 | Function audit home rails, stream, paging, refresh, card tap, 地点 / Maps | On the pin. |
| 13 | Hero banners 和朋友报名活动 and 成为俱乐部, avatar → 我的, city menu | On the pin. |
| 14 | City consent 同意 records `home_city_location`; 不同意 is local | On the pin. Locate is row n1. |
| 15 | In-place search: field, history, scope chips, result rows, retry | On the pin. Template results are row n2. |
| 16 | Topic detail load, 收藏, 举报, 移交, 游玩记录, refresh | On the pin. |
| 17 | Activity detail load, people, 集合点, club gate, more info, 屏蔽主办方, refresh | On the pin. Associated-play tap is row n3. |
| 18 | Public profile load, 关注, 屏蔽 | On the pin. |
| 19 | Template 举报 and 应用 entry | On the pin. The editor itself is K40-publish. |
| 20 | Role chip 「商家」 / 「玩家」 | `Label` in `.secondary` inside `greetingRow`. Not a `Button` or `NavigationLink`. |
| 21 | Banner 小游戏 | Test-host only (`externalGamesOpen`). Not a release banner. |
| 22 | ADA behaviour: home empty, offline `ContentUnavailableView`, retry, loading | Present. Pill style, banner slab and search-chip layout are K40-ada. |

## Owner-only

| # | Audit row | Value needed |
|---|---|---|
| 1 | H-02a 继续探索 and the today ticket | Both are fetched and not rendered. The MP home does not render them. Say whether to mount `PlayContinuationBannerView` / `HomeTodayCard`, or to drop the reads. |
| 2 | H-03 home scan entry | 交接 11.x says not to wire `/api/play/scan-entry`. The replacement (store code → deep link) is a launch decision. |
| 3 | P1-1 share landing (topic, activity, template, topic-template) | The https URLs already build (@ `291ed4940`, helper @ `107ceb4c6`). Opening them needs `com.apple.developer.associated-domains` and a hosted AASA. Those values are not in the repo. |

## Deferred-merchant

Banner 成为商家 stays filtered by `PlayerLaunch.isHidden` while `merchantCenterEnabled` is false in Release. The role chip is a label, not an entry into merchant center.

## Not this agent

H-04b guest city nodes, H-05a–d and searchmap layout: K40-map. H-06–H-11, H-13, H-15, H-16 and template authoring publish: K40-publish. ADA layout rows (d2-home banner slab, retry pill, d2-search chips, activity-detail chrome): K40-ada. Activity/member report 404: social/backend. City-rail placement: K40-city.
