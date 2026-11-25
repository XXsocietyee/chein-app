# cursor-cov2-account-publish-a

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, message starts `Integrate Cursor round 4`). Branch `cursor/cov2-account-publish-a`. No pull request.

Coverage table: `docs/mp-contract-coverage.md` on that base. Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. The global totals in that table were not edited.

`swiftc` was not run. `AppSession.swift`, `tools/check_mp_contract_coverage.py`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No new Core type was added. `App/` was not edited.

## Split

Account-publish rows are those whose MP path starts with `pages/publish/`, `pages/publishkit/`, `pages/shezhi/`, `pages/gerenziliao/`, `pages/team/`, `pages/talent/`, `pages/address/`, `pages/addressinfo/`, or `pages/privacy/`. `utils/`, `app.js`, and `components/` are not in this set. The 91 rows are sorted by the full MP path, then by source line.

The split point is `pages/publish/fabu/theme-runtime-structure.js`. Lane A owns every row in the set whose path sorts before that path. 91 is odd, so this lane takes the extra row: 46 here, 45 on lane B. The last owned row is `pages/publish/fabu/theme-route-names.js:77`. Lane B starts at `pages/publish/fabu/theme-runtime-structure.js:338`.

## Area counts

| area | set | lane A | lane B |
|---|---:|---:|---:|
| address | 2 | 2 | 0 |
| addressinfo | 3 | 3 | 0 |
| gerenziliao | 6 | 6 | 0 |
| privacy | 1 | 1 | 0 |
| publish | 54 | 34 | 20 |
| publishkit | 5 | 0 | 5 |
| shezhi | 7 | 0 | 7 |
| talent | 7 | 0 | 7 |
| team | 6 | 0 | 6 |
| total | 91 | 46 | 45 |

## This lane

| count | value |
|---|---:|
| rows owned | 46 |
| already matched on the base | 8 |
| endpoints added | 0 |
| tests added | 23 |
| owned rows pinned by those tests | 23 |
| owned rows matched after this lane | 31 |
| remaining missing endpoint | 2 |
| remaining missing test | 15 |

The 23 tests are in `Tests/CoreTests/AccountPublishLaneAContractTests.swift`. Each quotes the path, the method, and the closed literal field names. `ReleaseMoneyWriteSwitch.kind(for:)` is nil for every pinned path. No money gate was enabled. The tests do not send a request.

Eight owned rows already had a Core symbol and a test: `pages/address/address.js:86`, four `api/user/info` reads (`pages/addressinfo/addressinfo.js:63`, `pages/gerenziliao/gerenziliao.js:581`, `pages/publish/activity/index.js:1303`, `pages/publish/fabu/index.js:5462`), `pages/publish/activity/index.js:1199`, `pages/publish/fabu/index.js:4029`, and `pages/publish/fabu/index.js:9295`. They were not redone.

## Endpoints not added

- `pages/privacy/index.js:119` forwards `url` into `sendRequest`. That call has no path string. No path was invented.
- `pages/publish/activity/index.js:818` sets `url` to a ternary of `/api/merchant/access/me` and `/api/publish/home`. The checker keeps no single path from that call, so a new Core literal would not attach.

## Tests that cannot pin

Thirteen owned rows already have a Core symbol, and the call's data is not a closed object literal (a variable, `Object.assign` with a non-literal, `JSON.stringify(...)`, or no `data` key). Those field lists stay unparsed. A test cannot pin them, and this lane does not claim a parse:

- `pages/addressinfo/addressinfo.js:194` `api/user/address/action`
- `pages/gerenziliao/gerenziliao.js:311` `api/user/nickname/suggest`
- `pages/gerenziliao/gerenziliao.js:667` `api/user/profile/review`
- `pages/gerenziliao/gerenziliao.js:713` `api/user/update`
- `pages/publish/components/location-todos/index.js:83` `api/template/topic-template/binding`
- `pages/publish/fabu/index.js:4051` `api/club/my`
- `pages/publish/fabu/index.js:6985` `api/ai/safety/precheck`
- `pages/publish/fabu/index.js:8798` `api/template/adopt-draft`
- `pages/publish/fabu/theme-d20-page.js:100` `api/topic/play-setup` `PUT`
- `pages/publish/fabu/theme-fe-visit.js:39` and `:86` `api/topic/free-explore/visit-config`
- `pages/publish/fabu/theme-initial-carry.js:87` `api/topic/state-keys` `POST`
- `pages/publish/fabu/theme-route-names.js:77` `api/topic/state-keys/named`

The two endpoint rows above are the other two missing tests. Remaining missing test for this half is 15. Remaining missing endpoint is 2.

## Same shape outside this half

The checker matches path, method, and field names, not the MP file. These lane B rows already had a Core symbol and now show one of this lane's tests because the closed literal shape is the same. No lane-B-only shape was given an endpoint or a test.

- `pages/publish/fabu/theme-runtime-structure.js:338`
- `pages/publish/utils/publish/template-adoption.js:44`
- `pages/publish/utils/publish/template-adoption.js:45`
- `pages/publish/utils/publish/template-adoption.js:63`
- `pages/publish/utils/publish/template-adoption.js:68`
- `pages/publishkit/components/topic-state-keys/index.js:130`

`pages/topic/utils/wx-phone-bind.js:27` and the two `api/template/my-list` reads whose only literal field is `scope` (`pages/topic/components/cy/chapter-node-form/index.js:358`, `pages/topic/components/cy/chapter-target-picker/index.js:100`) match the same way. They are outside the account-publish set.
