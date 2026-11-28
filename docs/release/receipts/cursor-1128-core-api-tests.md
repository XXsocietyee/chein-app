# K25 · core-api-tests

Branch `cursor/1128-core-api-tests`. Tests only. No production behavior, no App screen layout, no `App/AppSession.swift`. No `String(localized:)` literals.

`Tests/CoreTests/PlayerCoreAPICallPinTests.swift` adds one Core test per player call below. Each test pins the HTTP method, the path, the parameters the player app sends, and the fields the existing decoder reads. Fixtures are synthetic. Nothing here calls a live backend.

39 API calls got a test. 36 of those are distinct paths. `api/topic/list` and `api/activity/list` each have more than one parameter set.

| Call | Method | Path |
|---|---|---|
| Topic list | POST | `api/topic/list` (`is_my`, `pageNum`, `pageSize`, `keyword`, `category_id`, `is_recommend`, `sort_type`) |
| Home recommended topics | POST | `api/topic/list` (`is_my`, `is_recommend`, `pageNum`, `pageSize`) |
| Topic detail | POST | `api/topic/info-to-user` (`id`) |
| Home open activities | POST | `api/activity/list` (`is_my`, `status`, `sort_type`, `keyword`, `category_id`, `pageNum`, `pageSize`) |
| Home nearby | POST | `api/activity/list` (`is_my`, `sort_type`, `pageNum`, `pageSize`) |
| Home upcoming | POST | `api/activity/list` (`is_my`, `status`, `sort_type`, `pageNum`, `pageSize`) |
| Banners | POST | `api/common/banner` (`showType`, `linkType`) |
| Categories | POST | `api/category/list` (`parentid`, `type`) |
| Geocode | POST | `api/map/geocode` (`address`, `region`) |
| Place search | POST | `api/map/place-search` (`keyword`, `longitude`, `latitude`) |
| Weather | GET | `api/map/weather` (`lat`, `lng`) |
| Unified search | GET | `api/search/unified` (`keyword`, `types`, `city_code`, `pageNum`, `pageSize`) |
| Club home | POST | `api/club/home` (`{}`) |
| Club detail | POST | `api/club/detail` (`id`) |
| Club directory | POST | `api/club/list` (`name`) |
| Club members | POST | `api/club/members` (`clubId`) |
| Growth center | POST | `api/growth/center` (`{}`) |
| Growth progress | POST | `api/play/growth` (`{}`) |
| Completed play | POST | `api/play/my-completed` (`{}`) |
| Growth leaderboard | POST | `api/growth/leaderboard` (`metric`, `period`, `limit`) |
| Official route list | GET | `api/preset/route/list` |
| Official route info | GET | `api/preset/route/info` (`id`) |
| Explore day | GET | `api/roam/nearby-exploreday` (`lat`, `lng`) |
| Roam places | GET | `api/roam/pois` (`lat`, `lng`, `radius`) |
| Route nodes | POST | `api/map/nearby` (`latitude`, `longitude`, `radius`, `limit`) |
| Theme support matrix | GET | `api/play/theme/support-matrix` |
| IM unread total | POST | `api/im/unread-total` (no fields) |
| Official signup cancel | POST | `api/official/signup-command/cancel` (`targetId`, `action`, `requestId`) |
| Official signup query | POST | `api/official/signup-command/query` (`requestId`) |
| Orient abandon | POST | `api/play/orient/session/abandon` (`sessionId`, `idempotencyKey`) |
| Team command query | POST | `api/team/command/query` (`requestId`) |
| Team command cancel | POST | `api/team/command/cancel` (`action`, `targetId`, `requestId`) |
| Club customers | POST | `api/club/crm/customers/list` (`clubId`, `filter`, `keyword`, `pageNum`, `pageSize`) |
| Club check-in | POST | `api/club/crm/checkin/detail` (`clubId`, `registrationId`) |
| Follow | POST | `api/user/follow/action` (`follow_member_id`, `follow`) |
| Set inviter | POST | `api/user/setInviter` (`inviter_id`) |
| Join info | POST | `api/registration/join_info` (`member_id`) |
| Active official for roam | GET | `api/official/active-for-roam` |
| Registration pay | POST | `api/registration/pay` (`id`) — refused, nothing sent |

`setInviter` is observed with `bindingEnabled: true` on the test instance only. The production default stays `false`. Registration pay still throws `Adapt5PayRefusal.blocked`. `ReleaseMoneyWriteSwitch` was not assigned.

## Gaps

### Bind phone cannot be decoded

`AccountPublishRemainingClient.bindPhone` throws `APIError.notConfigured` and does not send. The product comment says a WeChat phone code is not a native bind, and it names no path. `testBindPhoneStaysUnconfiguredAndSendsNothing` records the empty transport. The product was not changed, so there is no method, path, or decoded phone to pin.

### Merchant center stays gated

`docs/mp-contract-coverage.md` has 1038 rows: 811 player, 227 merchant-center. Merchant-center rows are `pages/merchant/` (except the player-visible `pages/merchant/profile/index`), `pages/coop/`, `pages/cooperation/`, `pages/topic/merchantapply/index`, and `pages/topic/merchantinfo/merchantinfo`. Of those 227, 140 have no test and 26 have no Core symbol.

`PlayerLaunch.merchantCenterEnabled` is `false` outside `DEBUG || TEST`. `testMerchantCenterPagesStayHiddenWhenTheReleaseFlagIsOff` passes `enabled: false` and does not flip the flag. Those calls were not enabled and were not given sending tests.

### Player rows still outside this file

340 player rows in the coverage table already name some Core test. 471 player rows are still `MISSING` a checker pin, and 104 player rows have no Core symbol. The mini-program tree (`chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`) is not in this checkout, so those rows were not line-mapped onto a path. Shared catalogs such as `ClubGovernanceRead` stay shared. This branch does not invent endpoints for them and does not rewrite `docs/mp-contract-coverage.md`.

No other decoder was changed. A progress payload in this file includes `totalMileage`, which `GrowthPlayProgress` requires.

## Checks

This machine has no `swiftc`. The new file was parsed with Tree-sitter (`tools/check_swift_syntax.py`). It was not executed. Scaffold, a11y lint, and `python3 tools/contract_ratchet.py --check` are the gates. The contract baseline was not edited.
