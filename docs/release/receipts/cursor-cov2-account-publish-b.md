# cursor-cov2-account-publish-b

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, message starts "Integrate Cursor round 4"). Branch `cursor/cov2-account-publish-b`. No pull request. Not rebased.

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Rows are the checker’s `request(`, `sendRequest(`, `req(`, `wx.request(`, and `uploadFile(` calls. The checker does not parse JavaScript. `docs/mp-contract-coverage.md` was not edited, and its global totals were not rewritten.

## Split

The account-publish set is every row whose MP path starts with `pages/publish/`, `pages/publishkit/`, `pages/shezhi/`, `pages/gerenziliao/`, `pages/team/`, `pages/talent/`, `pages/address/`, `pages/addressinfo/`, or `pages/privacy/`. Sorted by the full MP file path, then by source line. 91 rows. Lane a owns the first 46 (the odd middle row stays with lane a). Lane b owns the second 45.

Split point: `pages/publish/fabu/theme-runtime-structure.js`.

Lane a ends at `pages/publish/fabu/theme-route-names.js:77`. The first lane-b row is `pages/publish/fabu/theme-runtime-structure.js:338`.

`utils/`, `app.js`, and `components/` were not taken. Lane a’s files before the split point were not given their own tests. A pin quotes one path, one method, and that call’s literal fields, so the same shape on an earlier line is recorded by the same test. Those shared shapes are listed under incidental rows.

## Area counts

Set size, then lane b after this branch. `missing endpoint` and `missing test` are lane b only. `matched` means the row has both a Core symbol and a pinning test.

| area | set rows | lane a | lane b | lane b matched | lane b missing endpoint | lane b missing test |
|---|---:|---:|---:|---:|---:|---:|
| `pages/publish/` | 54 | 34 | 20 | 7 | 8 | 13 |
| `pages/publishkit/` | 5 | 0 | 5 | 2 | 1 | 3 |
| `pages/shezhi/` | 7 | 0 | 7 | 2 | 0 | 5 |
| `pages/gerenziliao/` | 6 | 6 | 0 | 0 | 0 | 0 |
| `pages/team/` | 6 | 0 | 6 | 2 | 1 | 4 |
| `pages/talent/` | 7 | 0 | 7 | 3 | 0 | 4 |
| `pages/address/` | 2 | 2 | 0 | 0 | 0 | 0 |
| `pages/addressinfo/` | 3 | 3 | 0 | 0 | 0 | 0 |
| `pages/privacy/` | 1 | 1 | 0 | 0 | 0 | 0 |
| total | 91 | 46 | 45 | 16 | 10 | 29 |

Lane b before this branch: matched 6, missing endpoint 10, missing test 39. Endpoints added: 0. Tests added: 10. Money writes enabled: 0.

## Tests added

Each test is in `Tests/CoreTests/AccountPublishCoverageLaneBTests.swift`. It quotes the path, the method, and the literal field names. The request is built and the recording transport stays empty.

| MP file:line | method | path | fields | Core symbol | test |
|---|---|---|---|---|---|
| `pages/publish/fabu/theme-runtime-structure.js:338` | `POST` | `api/topic/author-saved-detail` | `id`, `scope` | `PlayerGapService.parityBPaths` | `testAuthorSavedDetailPinsIdAndScope` |
| `pages/publish/utils/publish/template-adoption.js:44` | `GET` | `api/template/adoption-detail` | `requestId`, `scope` | `TemplateAdoptionService.detailPath` | `testAdoptionDetailPinsRequestIdAndScope` |
| `pages/publish/utils/publish/template-adoption.js:45` | `POST` | `api/template/author-myinfo` | `id`, `scope` | `TemplateAdoptionService.authorMyInfoPath` | `testAuthorMyInfoPinsIdAndScope` |
| `pages/publish/utils/publish/template-adoption.js:63` | `GET` | `api/template/adoption-receipt` | `requestId`, `scope` | `TemplateAdoptionService.receiptPath` | `testAdoptionReceiptPinsRequestIdAndScope` |
| `pages/publish/utils/publish/template-adoption.js:68` | `GET` | `api/template/adoption-source` | `originalTemplateId`, `scope` | `TemplateAdoptionService.sourcePath` | `testAdoptionSourcePinsOriginalTemplateIdAndScope` |
| `pages/publishkit/components/reward-selector/index.js:96` | `POST` | `api/coupon/mypublishlist` | `is_select`, `scope` | `CouponInfoSettingsPage.publishedPath` | `testCouponPublishedListPinsIsSelectAndScope` |
| `pages/publishkit/components/topic-state-keys/index.js:130` | `GET` | `api/topic/state-keys` | `topicId`, `scope` | `NativeAttributeAuthorRuntimeConfiguration.path` | `testStateKeysListPinsTopicIdAndScope` |
| `pages/shezhi/components/post-governance/index.js:57` | `GET` | `api/v1/community/me/enforcements` | `cursor` | `SquareGovernanceService.enforcements` | `testEnforcementsPinsCursor` |
| `pages/talent/list/index.js:209` | `POST` | `api/creativesquare/list` | `is_my`, `user_id`, `pageNum`, `pageSize` | `CreativeSquareAuthorDelete.listPath` | `testCreativeSquareListPinsMineUserPage` |
| `pages/talent/list/index.js:454` | `POST` | `api/club/home` | (none) | `ClubService.home` | `testClubHomePinsEmptyPost` |

Six lane-b rows already had both a Core symbol and a test and were left as they were: `pages/publish/temp/index.js:1469`, `pages/publish/template-intro/index.js:71`, `pages/shezhi/shezhi.js:403`, `pages/talent/list/index.js:116`, `pages/team/detail/index.js:292`, `pages/team/detail/index.js:396`.

The same shape is also recorded on these rows. They were not separate work.

| MP file:line | test |
|---|---|
| `pages/publish/fabu/index.js:8162` | `testAuthorSavedDetailPinsIdAndScope` |
| `pages/publish/fabu/index.js:8772` | `testAdoptionSourcePinsOriginalTemplateIdAndScope` |
| `pages/publish/fabu/index.js:8815` | `testAdoptionReceiptPinsRequestIdAndScope` |
| `pages/publish/fabu/index.js:8877` | `testAdoptionDetailPinsRequestIdAndScope` |
| `pages/publish/fabu/index.js:8879` | `testAuthorMyInfoPinsIdAndScope` |
| `pages/publish/fabu/index.js:8900` | `testAuthorMyInfoPinsIdAndScope` |
| `pages/publish/fabu/index.js:8988` | `testAuthorMyInfoPinsIdAndScope` |
| `pages/publish/fabu/index.js:9166` | `testAuthorMyInfoPinsIdAndScope` |
| `pages/publish/fabu/theme-route-names.js:53` | `testStateKeysListPinsTopicIdAndScope` |
| `pages/merchant/relation/index.js:388` | `testCreativeSquareListPinsMineUserPage` |

`pages/merchant/relation/index.js:388` is outside this set. The nine `pages/publish/fabu/` rows above the split point are lane a and share the lane-b field list.

## Endpoints not added

No owned row had an extracted path that was absent from Core and could be recorded.

- `pages/team/utils/team-invite-qr.js:26` sets `url: URL`. That forwards a binding. No path was invented. The constant in that file is `/api/team/invite-qrcode`, and `PlayerGapService.teamInviteQRCode` already posts `api/team/invite-qrcode`.
- `pages/publish/utils/publish/publish-workflow.js:44` calls the injected `request(payload, settle)`. No url literal.
- `pages/publish/utils/publish/server-draft.js:477`, `:491`, `:535`, `:559`, and `:574` call a local `request(kind, value, callback)` that forwards to `deps[kind]`. No url literal.
- `pages/publish/temp/index.js:3490` is `Object.assign` of a non-literal `request`. The checker drops the url. The following object chooses `/api/template/draft` or `/api/template/publish`. Both strings already exist. One path was not invented for the pair.
- `pages/publish/temp/index.js:3560` chooses `/api/template/author-myinfo` or `/api/template/author-info`. Both strings already exist. The checker keeps no single path.
- `pages/publishkit/components/topic-state-keys/index.js:307` is `` `/api/topic/state-keys?${...}&key=${...}` `` with method `DELETE`. The checker stores a templated pattern `api/topic/state-keys` after the query is removed, and no `{}` remains. A templated row does not read the exact-string index, so the existing `api/topic/state-keys` literal is not recorded. No second path was invented.

## Tests not recorded

The other lane-b rows stay missing a test because the data argument is not a closed object literal, the method is not a literal, or the path was not kept. Field names were not filled in for those calls. `CouponInfoSettingsPage.paymentEnabled` and `virtualGoodsEnabled` stay false. The coupon list pin is a read of `api/coupon/mypublishlist`, and its test shows the transport sent nothing. No pay, withdrawal, or pass write was enabled. `swiftc` was not run. `AppSession.swift`, `project.pbxproj`, `tools/current_ci_manifest.json`, and `tools/check_mp_contract_coverage.py` were not edited. No new Core type was added.
