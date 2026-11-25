# cursor-cov2-player-content-a

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, message starts `Integrate Cursor round 4`). Branch `cursor/cov2-player-content-a`. No pull request. `swiftc` was not run.

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Rows are the player-content set in `docs/mp-contract-coverage.md`: an MP location whose path starts with `pages/topic/`, `pages/activity/`, `pages/square/`, `pages/search2/`, `pages/searchmap/`, `pages/template/`, `pages/templatedetail/`, `pages/mylike/`, `pages/index/`, `subpackageA/`, `subpackageB/`, or `subpackageP3/`. `utils/`, `app.js`, and `components/` are not in the set.

## Split

The set has 257 rows. Sorted by the full MP location string (`file:line`, lexicographic). This lane owns the first 129 (the odd row). Lane b owns the other 128.

| edge | location |
|---|---|
| last row in this lane | `pages/topic/merchantinfo/merchantinfo.js:1651` |
| first row in lane b | `pages/topic/merchantinfo/merchantinfo.js:1680` |

## Counts for this half

The global totals in `docs/mp-contract-coverage.md` were not edited. Counts below are this half only, from `tools/check_mp_contract_coverage.py` (not edited).

| | before | after |
|---|---|---|
| rows | 129 | 129 |
| matched | 51 | 75 |
| missing endpoint | 8 | 7 |
| missing test | 78 | 54 |

Endpoints added: 1. Tests added: 78 (`Tests/CoreTests/PlayerContentMPLaneATests.swift`). The checker newly records a test for 24 rows in this half. The other 54 tests quote the path, the method, and the literal field names, and the checker still leaves them missing because the data argument is not a closed object literal, or the call forwards `url` and has no path.

## Endpoint added

`POST api/official/broadcast/{}/recover` — `PlayerContentMPContract.broadcastRecoverPath`, from `pages/activity/official-mine/index.js:193`. No data. The builder returns a POST request and does not send it. `PlayerContentMPContract.moneyEnabled` is false. `PlayerContentMPContract.pricingGrantEnabled` is false. `POST api/registration/quote`, `POST api/registration/create`, and `POST api/topic/pricing/confirm` still throw and send nothing.

## Still missing an endpoint

These seven calls have no single path literal. No path was invented.

| location | why |
|---|---|
| `pages/activity/official-inbox/index.js:110` | forwards `url` |
| `pages/index/index.js:1057` | forwards `url` |
| `pages/search2/result/index.js:198` | forwards `request.url` |
| `pages/templatedetail/templatedetail.js:331` | ternary of `api/template/myinfo` and `api/template/info` (both already in Core) |
| `pages/topic/components/cy/node-npc-form/index.js:641` | forwards `url` |
| `pages/topic/index/index.js:13` | `recordsRequest` forwards `url` |
| `pages/topic/merchantapply/index.js:672` | ternary of `api/registration/merchant/update` and `api/registration/merchant/create` (both already in Core) |

## Not edited

`tools/check_mp_contract_coverage.py`, `App/AppSession.swift`, `TopicClubShareLink` (`Self.clubCode(trimmed)`, `init(clubCode: String?)`), `project.pbxproj`, `tools/current_ci_manifest.json`.

The checker matches a whole shape, so these calls outside this half now name a lane-a test. No Core path was added for them: `pages/club/detail/index.js:3237`, `pages/roam/index.js:4886`, `pages/roam/index.js:6086`, `pages/roam/index.js:6098`, `pages/topic/merchantinfo/merchantinfo.js:2040`, `subpackageMember/components/cy/scene-member-order-detail/index.js:883`, `subpackageMember/components/cy/scene-roam-poi-detail/index.js:622`, `subpackageMember/components/cy/scene-roam-poi-detail/index.js:645`, `subpackageMember/signup/index.js:492`, `subpackageMember/signup/index.js:552`, `subpackageRoam/nearby/index.js:965`, `utils/post-feed-actions.js:83`.
