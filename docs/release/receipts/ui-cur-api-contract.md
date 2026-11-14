# ui/cur-api-contract

Parent `5ba7b0f2c5f10dea10905895da947c350b3e24ac` (`origin/ui/main`). Source is public hengyin `liboyang42-cpu/hengyin` commit `04307856090b3aa21cdc74c147173a34dedda99e`, file `docs/delivery/backend-app-r2/API-SMOKE.md`. `APP-CONTRACT-FIXES.md` is not on that commit. Only items (a), (b), and (c) are in this branch.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. `ReviewedAreaSwitch` is not redeclared. `docs/release/contract-failing-baseline.txt` is unchanged. `callSiteCount` stays 986, `liveInProductionCount` stays 974, `missingCount` stays 12, `wiredPatternCount` stays 677. `ReleaseMoneyWriteSwitch.paymentEnabled` and `payoutEnabled` stay compile-time false. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay closed on `https://www.chengyinhub.com`. A path-string change does not open those switches.

`/api/activity/update` and `/api/merchant/orders` are unchanged. Shop `/api/merchant/npc/*` (`ApiMerchantController`) is unchanged. `swiftc` was not run.

## Path table

| Item | Old path | New path | Controller read at `043078560` |
|---|---|---|---|
| (a) | `POST /api/merchant/chapter-node/npc/detail` (multipart form) | same path, JSON `nodeId` | `chengyinhub-admin/.../api/ApiChapterMerchantNodeController.java` `@RequestBody NodeNpcRequest` |
| (a) | `POST /api/merchant/chapter-node/npc/save` (multipart form) | same path, JSON `nodeId`, `name`, `avatar`, `greeting` | same file, `@RequestBody NodeNpcRequest`. No `MultipartFile` |
| (a) | `POST /api/merchant/chapter-node/npc/voice/enroll` (multipart form) | same path, JSON `nodeId`, `voiceSample` | same file, `@RequestBody NodeNpcRequest` |
| (a) | `POST /api/merchant/chapter-node/npc/voice/reset` (multipart form) | same path, JSON `nodeId` | same file, `@RequestBody NodeNpcRequest` |
| (a) | `POST /api/merchant/chapter-node/npc/voice/status` (multipart form) | same path, JSON `nodeId` | same file, `@RequestBody NodeNpcRequest` |
| (b) purchased | `POST /api/workshop/purchased` (404, not a route) | `POST /api/workshop/v2/purchased/list` and `POST /api/workshop/v2/purchased/detail` | `ApiWorkshopController.java` `@RequestMapping("/api/workshop")`. The Swift reader already posted those two children. The bare prefix is no longer a catalog mark or a player-write accept. It is not left as a prefix. |
| (b) payout | `POST /api/merchant/payout-account/save` | not retargeted | `ApiMerchantPayoutAccountController.java` has only `POST /api/merchant/payout-account`. Class comment: read of the current merchant's sub-merchant status (`FINANCE_READ`, merchant id from login). No `/save` and no bind method. `EcommercePayoutAdminController` is `/business/ecommerce-payout` (ops register/submit/refresh), not an app route. The write is not pointed at the read-only POST. |
| (c) | `/api/reward-pledge/versions` | not retargeted (left unsent) | `ApiRewardPledgeController.java`. No list under `/versions`. Children that exist are `POST /versions/{versionId}/hold` and `POST /versions/{versionId}/withdraw`. `RewardPledgeRequests.hold` and `withdraw` already send those. The bare prefix is refused. |
| (c) | `/api/friend/channel-invite` | not retargeted (left unsent) | `ApiFriendController.java`. Children already used by the caller: `GET .../picker`, `batch`, `notice`, `landing`, `mine`, `receipt`, and `POST .../command`. No one child matches the bare prefix. |
| (c) | `/api/friend/team-invite` | not retargeted (left unsent) | `ApiFriendController.java`. Caller already uses `GET .../picker`, `landing`, `mine`. Writes and receipts go to `POST`/`GET /api/team/original-request`. |

## Grants

- Chapter-node NPC paths were already in `wiredPatterns` and the live mark catalog. Content type changed; the paths did not.
- `WorkshopModRouteGrant.moneyPaths` lists `api/workshop/v2/purchased/list` and `api/workshop/v2/purchased/detail` in place of the bare `api/workshop/purchased` prefix. The same two keys are live marks. They are not added to `wiredPatterns` or `workshopModOwnerGrant`, so `https://www.chengyinhub.com` still refuses them while money stays off.
- `rewardPledgePaths` no longer contains `api/reward-pledge/versions`. `admitsRewardPledge` and `admitsRewardPledgeWrite` return false for that exact key. Hold and withdraw still match the `/api/reward-pledge/` prefix through the id children.
- `acceptsPlayerWrite` and `admitsChinaProductionCall` return false for the four exact prefixes: `api/workshop/purchased`, `api/reward-pledge/versions`, `api/friend/channel-invite`, `api/friend/team-invite`.

## Tests

Core tests use `https://8120.example.test`. A request aimed at `https://www.chengyinhub.com/prod-api/...` for the closed prefixes, the v2 purchased reads, and `payout-account/save` expects `APIError.notConfigured` (or the existing payout `.notSent` while the switch is off). None of those cases decode a success body. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` are the checks run for this change. `swiftc` was not run.
