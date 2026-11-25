# cursor-r8-merchant-coop

Base `f5f3006d781ac4d61c225a079ef74e2e2a86befd`. Core only. No `swiftc` run, so this receipt does not claim a parse. Club settlement summary is unchanged (`POST {clubId}`). `api/creativesquare/list` was not taken.

## Gates turned on

`MerchantCoopLiveWrites` synthesizes a China grant only when composition injected no approval. An explicit grant is not widened. Pay, refund execution, payout, withdrawal, paid orders, `saveSku`, and review report stay off and send nothing.

- Aftercare respond (AGREE / REJECT / EVIDENCE opinion, not a refund execution)
- Review reply, reply/update, reply/delete
- CRM notes, note hide, tag assign/remove, batch tag
- Operators invite, role, remove, revoke, and invite accept `{token, requestId}`
- City-node claim, claim/cancel, offline, save (`MerchantCityNodeWriteGate` and `MerchantContentService.permits`). Poster code and station commands stay off.
- Operations paths `business-status/update`, `decor/save`, `npc/save`, `coop-profile/save` are admitted when a matching account approval is present, even if that approval's path set omitted them
- `POST api/merchant/events` is now `application/x-www-form-urlencoded` with an empty body (mini-program `data: {}`)
- Batch tag JSON omits `tagColor` (single-tag assign still sends it)

## Rows taken

Cursor Core: MC8-17-4, MC8-23-5 (coordinator already calls `writer.enroll`; the live screen has no writer), MC8-27-2, MC8-33-4, MC8-01-3 (Core `.live` gate; the 更多 row still constructs `.off`), MC8-08-1, MC8-23-7, MC8-28-6, MC8-33-7.

Not taken: MC8-28-2 (`api/creativesquare/list`). MC8-18-4 stays off because the predict/settle lock and `settlement: true` live in App composition; production settlement was not turned on.

Owner-decision writes whose fix is these Core switches: MC8-13-1, MC8-13-2, MC8-13-3 (not MC8-13-4 report), MC8-14-1, MC8-15-1 through MC8-15-5, MC8-17-1, MC8-23-1 (decor/npc save path; voice enroll gate default stays false), MC8-24-1, MC8-25-1, MC8-29-1, MC8-29-2. MC8-24-2 through MC8-24-6 and MC8-29-5 follow once those grants exist. Game-node station commands (MC8-26-1) were not in the send list and stay off.

## App call sites left for Claude

Do not treat a Core grant as delivered on device until these admit the request. `AppSession.swift` and `AppCompositionRoot.swift` were not edited.

- Rebase onto `b5b9d900373c`: the other side's `mpFirstActions`, `mpFirstAcceptInvitation`, `writeApproval().cityNode`, and `MerchantCityNodeWriteGate` `.mpFirst` default were dropped. Those writes go through `MerchantCoopLiveWrites` only. `MerchantContentWriteApproval.station` defaults off and `permits` returns false for `.station`. Review report is not in `admits` and is not in `MPFirstMerchantApprovals.businessPaths`.
- `App/AppCompositionRoot.swift` already calls `MPFirstMerchantWriteRoute` for the remaining admitted merchant writes. Events is still required as JSON `{}` by `MerchantOverviewScope.accepts`, while Core sends urlencoded empty.
- `App/AppCompositionRoot.swift` `MerchantOverviewScope.accepts` still requires `api/merchant/events` as JSON `{}`. Core now sends urlencoded empty. Admit that body or the events read stops.
- `App/AppCompositionRoot.swift` `ReviewedMerchantOperationsRoute.writePaths` omits `api/merchant/business-status/update` and only matches JSON saves. Core will build the form `{business_status}` when a matching operations approval exists. Admit the form. NPC `personality` is still absent from the npc key allowlist, so Core did not add it to `npc/save`.
- `App/MerchantStoreCharacterSessionBinding.swift` builds `StoreCharacterCoordinator` with `StoreCharacterOperationsReader` and no writer. `canSave` / `canEnroll` stay false. `reviewText` is loaded only by `StoreCharacterServiceBackend`.
- `App/MerchantStoreCharacterView.swift` hero does not render `coordinator.reviewText`.
- `App/MPReviewedPageScreen.swift` coop-center calls `merchantCoopCenterDestination()` with no tab or topic. Relation opens `SessionCoopRelationDiscoveryView` without `tab` / `topicId` on `CoopRelationDisplayContext`. Batch-detail already reads `batchId` once the link arrives.
- `App/NearbyMerchantView.swift` `card` still draws name, address, and distance. Cover, logo, business time, capacity, charge type, suit types, and coordinates are on `NearbyMerchantRow`.
- `App/QuestifyApp.swift` still constructs `MerchantDeskManualCodeGate.off`. Pass `.live` for the 手输码 row. Resolve still does not redeem.
- `App/AppSessionDoorEntry.swift` passes predict locks nil, and `merchantMarketingGates.settlement` stays false. Leave settlement off outside TEST.
