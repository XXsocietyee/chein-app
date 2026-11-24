# Navigation Flows — G2 ops (`club`, `merchant-coop`, `account-publish`)

Extracted from `chengyinhub-xcx` (`wx.navigateTo` / `wx.switchTab` / `wx.redirectTo` / `wx.reLaunch` / `wx.navigateBack`).
Status legend: `OK` (routed in `MPReviewedPageScreen` / native flow), `MISSING-ROUTE` (target not in `MPReviewedPageScreen`), `PARKING-MOUNT` (covered in `App/MPGap`, pending coordinator mount), `DIFF` (routed differently).

## club

| Source MP file:line | Kind | Target | App Status |
|---|---|---|---|
| `pages/club/apply/index.js:160` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/club/apply/index.js:161` | `redirectTo` | `/pages/merchant/apply/index` | OK |
| `pages/club/apply/index.js:221` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/apply/index.js:222` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/apply/index.js:461` | `redirectTo` | `/pages/club/create/index` | OK |
| `pages/club/badges/index.js:121` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/badges/index.js:122` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/checkin-detail/index.js:207` | `navigateBack` | `/pages/index/index` | OK (system back) |
| `pages/club/components/cy/scene-club-edit/index.js:395` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/create/index.js:196` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/create/index.js:205` | `redirectTo` | `/pages/club/detail/index?owner=1&tab=manage` | OK |
| `pages/club/create/index.js:244` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/create/index.js:245` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/customer-detail/index.js:80` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/customer-detail/index.js:81` | `redirectTo` | `/pages/club/customers/index?clubId=` | OK |
| `pages/club/customer-detail/index.js:150` | `navigateTo` | `/pages/topic/index/index?id=` | OK |
| `pages/club/customers/index.js:88` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/customers/index.js:89` | `redirectTo` | `/pages/club/detail/index?id=` | OK |
| `pages/club/customers/index.js:90` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/customers/index.js:122` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/detail/index.js:736` | `navigateBack` | `/pages/talent/list/index` | OK (system back) |
| `pages/club/detail/index.js:944` | `navigateTo` | `/pages/coop/list/index` | MISSING-ROUTE (for Claude) |
| `pages/club/detail/index.js:950` | `navigateTo` | `/pages/club/customers/index?clubId=` | OK |
| `pages/club/detail/index.js:957` | `navigateTo` | `/pages/club/enroll/index?clubId=` | OK |
| `pages/club/detail/index.js:963` | `navigateTo` | `/pages/club/event-ops/index?clubId=` | OK |
| `pages/club/detail/index.js:998` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/detail/index.js:1079` | `navigateTo` | `/pages/club/settlement/index?clubId=` | MISSING-ROUTE (for Claude) |
| `pages/club/detail/index.js:1114` | `navigateTo` | `/pages/club/notify/index?clubId=` | OK |
| `pages/club/detail/index.js:1728` | `navigateTo` | `/pages/publish/fabu/index?clubId=` | OK |
| `pages/club/detail/index.js:2506` | `navigateTo` | `/pages/userinfo/userinfo?userId=` | OK |
| `pages/club/detail/index.js:2515` | `navigateTo` | `/pages/club/customer-detail/index?clubId=` | OK |
| `pages/club/detail/index.js:2658` | `navigateTo` | `/pages/club/badges/index?clubId=` | OK |
| `pages/club/detail/index.js:2664` | `navigateTo` | `/pages/club/roles/index?clubId=` | OK |
| `pages/club/detail/index.js:2680` | `navigateTo` | `/pages/club/governance/index?clubId=` | OK |
| `pages/club/detail/index.js:2885` | `navigateTo` | `/pages/play/index?topicId=` | OK |
| `pages/club/detail/index.js:2892` | `navigateTo` | `/pages/topic/index/index?id=` | OK |
| `pages/club/detail/index.js:2958` | `navigateTo` | `/pages/club/topic-detail/index?topicId=` | OK |
| `pages/club/edit/index.js:28` | `navigateBack` | `/pages/talent/list/index` | OK (system back) |
| `pages/club/edit/index.js:34` | `navigateTo` | `/pages/club/governance/index?clubId=` | OK |
| `pages/club/enroll/index.js:121` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/enroll/index.js:125` | `redirectTo` | `/pages/club/detail/index?id=` | OK |
| `pages/club/enroll/index.js:128` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/enroll/index.js:470` | `navigateTo` | `/pages/club/checkin-detail/index?clubId=` | OK |
| `pages/club/event-ops/index.js:491` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/event-ops/index.js:492` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/event-ops/index.js:500` | `navigateTo` | `/pages/publish/fabu/index?clubId=` | OK |
| `pages/club/governance/index.js:239` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/governance/index.js:240` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/governance/index.js:614` | `redirectTo` | `/pages/club/detail/index?id=` | OK |
| `pages/club/group-code/index.js:223` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/group-code/index.js:225` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/group-code/index.js:230` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/join-requests/index.js:60` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/join-requests/index.js:64` | `redirectTo` | `/pages/club/detail/index?id=` | OK |
| `pages/club/join-requests/index.js:67` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/notify/index.js:80` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/notify/index.js:81` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/payout-receiver/index.js:34` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/payout-receiver/index.js:35` | `reLaunch` | `/pages/index/index` | OK |
| `pages/club/payout-receiver/index.js:40` | `navigateTo` | `/pages/club/create/index` | OK |
| `pages/club/roles/index.js:207` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/roles/index.js:208` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/settlement/index.js:141` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/settlement/index.js:142` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/settlement/index.js:235` | `navigateTo` | `/pages/club/settlement/index?clubId=` | MISSING-ROUTE (for Claude) |
| `pages/club/settlement/index.js:240` | `navigateTo` | `/pages/club/payout-receiver/index?clubId=` | MISSING-ROUTE (for Claude) |
| `pages/club/settlement/index.js:254` | `navigateTo` | `/pages/coop/settlement-detail/index?source=club&topicId=` | MISSING-ROUTE (for Claude) |
| `pages/club/topic-detail/director.js:1492` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/topic-detail/index.js:815` | `navigateTo` | `/pages/club/topic-story/index?topicId=` | OK |
| `pages/club/topic-detail/index.js:821` | `navigateTo` | `/pages/club/event-ops/index?clubId=` | OK |
| `pages/club/topic-detail/index.js:875` | `navigateTo` | `/pages/club/enroll/index?clubId=` | OK |
| `pages/club/topic-detail/index.js:906` | `navigateTo` | `/pages/club/detail/index?id=` | OK |
| `pages/club/topic-detail/index.js:915` | `navigateTo` | `/pages/club/settlement/index?clubId=` | MISSING-ROUTE (for Claude) |
| `pages/club/topic-detail/index.js:1108` | `navigateTo` | `/pages/club/group-code/index?` | OK |
| `pages/club/topic-detail/index.js:1286` | `navigateTo` | `/pages/publish/fabu/index?id=` | OK |
| `pages/club/topic-detail/index.js:1292` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/topic-detail/index.js:1340` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/topic-detail/index.js:1341` | `switchTab` | `/pages/index/index` | OK |
| `pages/club/topic-story/index.js:209` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/topic-story/index.js:210` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/club/topic-story/index.js:248` | `navigateTo` | `/pages/templatedetail/templatedetail?id=` | OK |
| `pages/club/topic-story/index.js:326` | `switchTab` | `/pages/index/index` | OK |
| `pages/club/workbench/index.js:25` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/club/workbench/index.js:36` | `navigateBack` | `BACK` | OK (system back) |
| `pages/club/workbench/index.js:38` | `switchTab` | `/pages/talent/list/index` | OK |

## merchant-coop

| Source MP file:line | Kind | Target | App Status |
|---|---|---|---|
| `pages/coop/finance/index.js:21` | `navigateBack` | `BACK` | OK (system back) |
| `pages/coop/finance/index.js:23` | `redirectTo` | `/subpackageA/pages/assetcenter/earnings/index` | OK |
| `pages/coop/invite-detail/index.js:435` | `navigateTo` | `/pages/topic/merchantinfo/merchantinfo?topicId=` | OK |
| `pages/coop/invite-detail/index.js:444` | `navigateTo` | `/pages/topic/index/index?id=` | OK |
| `pages/coop/invite-detail/index.js:469` | `navigateTo` | `/subpackageB/pages/im/chat/index?conversationId=` | OK |
| `pages/coop/invite-detail/index.js:700` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/coop/invite-detail/index.js:701` | `navigateBack` | `BACK` | OK (system back) |
| `pages/coop/invite-detail/index.js:703` | `navigateBack` | `/pages/coop/list/index` | OK (system back) |
| `pages/coop/invite/index.js:989` | `redirectTo` | `/pages/coop/list/index?tab=sent` | MISSING-ROUTE (for Claude) |
| `pages/coop/invite/index.js:995` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/coop/list/index.js:685` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/coop/nearby/index.js:454` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/coop/nearby/index.js:538` | `navigateBack` | `/pages/merchant/index/index` | OK (system back) |
| `pages/coop/settlement-detail/index.js:170` | `navigateBack` | `BACK` | OK (system back) |
| `pages/coop/settlement-detail/index.js:171` | `reLaunch` | `/pages/club/settlement/index?clubId=` | MISSING-ROUTE (for Claude) |
| `pages/coop/settlement-detail/index.js:172` | `reLaunch` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/aftercare/detail/index.js:53` | `redirectTo` | `/pages/merchant/aftercare/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/aftercare/detail/index.js:71` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/aftercare/detail/index.js:72` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/aftercare/index.js:58` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/aftercare/index.js:59` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/aftercare/index.js:168` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/apply/index.js:381` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/apply/index.js:382` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/apply/index.js:745` | `reLaunch` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/apply/index.js:755` | `navigateTo` | `/pages/club/governance/index?clubId=` | OK |
| `pages/merchant/apply/index.js:774` | `switchTab` | `/pages/index/index` | OK |
| `pages/merchant/bundle-reservations/index.js:59` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/bundle-reservations/index.js:60` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/citynode/create/index.js:128` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/citynode/create/index.js:129` | `redirectTo` | `/pages/merchant/citynode/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/citynode/create/index.js:279` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/citynode/index.js:150` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/citynode/index.js:151` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/citynode/index.js:253` | `navigateTo` | `/pages/merchant/citynode/create/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/components/cy/club-pool-cards/index.js:54` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/components/merchant-claim-sheet/index.js:54` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/coop-center/index.js:118` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/coop-center/index.js:119` | `reLaunch` | `/pages/merchant/marketing/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/coop-center/index.js:128` | `navigateTo` | `/subpackageB/pages/im/list/index` | OK |
| `pages/merchant/coop-center/index.js:249` | `navigateTo` | `/pages/topic/merchantinfo/merchantinfo?id=` | OK |
| `pages/merchant/coop-center/index.js:254` | `navigateTo` | `/pages/activity/official-detail/index?id=` | OK |
| `pages/merchant/crm-campaigns/index.js:41` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/crm-campaigns/index.js:42` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/customer/detail/index.js:59` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/customer/detail/index.js:60` | `reLaunch` | `/pages/merchant/customer/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/customer/index.js:408` | `navigateTo` | `/pages/merchant/coop-center/index` | OK |
| `pages/merchant/customer/index.js:690` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/customer/index.js:1017` | `navigateTo` | `/pages/merchant/crm-campaigns/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/ai-npc/index.js:513` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/decor/ai-npc/index.js:514` | `redirectTo` | `/pages/merchant/decor/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/coop-setting/index.js:88` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/decor/coop-setting/index.js:89` | `redirectTo` | `/pages/merchant/decor/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/coop-setting/index.js:180` | `redirectTo` | `/pages/merchant/apply/index` | OK |
| `pages/merchant/decor/gallery/index.js:130` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/decor/gallery/index.js:131` | `redirectTo` | `/pages/merchant/decor/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/gallery/index.js:204` | `redirectTo` | `/pages/merchant/apply/index` | OK |
| `pages/merchant/decor/index.js:441` | `navigateTo` | `/pages/merchant/apply/index` | OK |
| `pages/merchant/decor/index.js:921` | `navigateTo` | `/pages/merchant/decor/index?view=` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:926` | `navigateTo` | `/pages/merchant/decor/ai-npc/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:944` | `navigateTo` | `/pages/merchant/decor/coop-setting/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:945` | `navigateTo` | `/pages/merchant/decor/gallery/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:946` | `navigateTo` | `/pages/merchant/decor/perks/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:947` | `navigateTo` | `/pages/merchant/reviews/index?mode=manage` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:1210` | `navigateTo` | `/pages/publish/activity/index?scope=MERCHANT` | OK |
| `pages/merchant/decor/index.js:1226` | `navigateTo` | `/pages/merchant/citynode/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:1234` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/decor/index.js:1252` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/decor/index.js:1252` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/decor/perks/index.js:145` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/decor/perks/index.js:146` | `redirectTo` | `/pages/merchant/decor/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/game-node/index.js:269` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/game-node/index.js:270` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/index/index.js:325` | `navigateTo` | `/subpackageRoam/citystamp/index?kind=sign&place=` | OK |
| `pages/merchant/index/index.js:346` | `navigateTo` | `/subpackageMember/coupon/coupon?scope=MERCHANT` | OK |
| `pages/merchant/index/index.js:351` | `navigateTo` | `/pages/merchant/aftercare/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:357` | `navigateTo` | `/pages/merchant/bundle-reservations/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:363` | `navigateTo` | `/pages/merchant/verify-records/index` | OK |
| `pages/merchant/index/index.js:368` | `navigateTo` | `/pages/merchant/payout-account/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:924` | `navigateTo` | `/pages/merchant/apply/index` | OK |
| `pages/merchant/index/index.js:930` | `navigateTo` | `/pages/merchant/predict/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:1224` | `navigateTo` | `/subpackageB/pages/im/list/index` | OK |
| `pages/merchant/index/index.js:1230` | `navigateTo` | `/pages/merchant/ledger/index?view=` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:1245` | `navigateTo` | `/pages/merchant/game-node/index?activityId=` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:1260` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:1609` | `navigateTo` | `/subpackageA/pages/assetcenter/earnings/index?theme=merchant` | OK |
| `pages/merchant/index/index.js:1613` | `navigateTo` | `/pages/merchant/decor/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:1621` | `navigateTo` | `/pages/merchant/customer/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/index/index.js:1630` | `navigateTo` | `/pages/topic/merchantinfo/merchantinfo?` | OK |
| `pages/merchant/index/index.js:1650` | `navigateTo` | `/subpackageA/pages/myproject/index?scope=MERCHANT` | MISSING-ROUTE (for Claude) |
| `pages/merchant/ledger/batch-detail/index.js:28` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/ledger/batch-detail/index.js:28` | `reLaunch` | `/pages/merchant/ledger/index?view=settlement` | MISSING-ROUTE (for Claude) |
| `pages/merchant/ledger/index.js:138` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/ledger/index.js:138` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/ledger/index.js:649` | `navigateTo` | `/pages/merchant/ledger/index?view=settlement&source=coop` | MISSING-ROUTE (for Claude) |
| `pages/merchant/ledger/index.js:655` | `navigateTo` | `/pages/coop/settlement-detail/index?source=ledger&id=` | MISSING-ROUTE (for Claude) |
| `pages/merchant/ledger/index.js:684` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/ledger/index.js:697` | `navigateTo` | `/subpackageA/pages/assetcenter/earnings/index?theme=merchant` | OK |
| `pages/merchant/ledger/index.js:698` | `navigateTo` | `/subpackageB/pages/im/list/index` | OK |
| `pages/merchant/ledger/order-detail/index.js:39` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/ledger/order-detail/index.js:39` | `reLaunch` | `/pages/merchant/ledger/index?view=redemptions` | MISSING-ROUTE (for Claude) |
| `pages/merchant/ledger/order-detail/index.js:128` | `navigateTo` | `/subpackageA/pages/assetcenter/earnings/index?theme=merchant` | OK |
| `pages/merchant/marketing/ai-insight/index.js:155` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/marketing/ai-insight/index.js:155` | `reLaunch` | `/pages/merchant/marketing/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/marketing/ai-insight/index.js:740` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/marketing/index.js:382` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/marketing/index.js:599` | `navigateTo` | `/subpackageMember/coupon/coupon?scope=MERCHANT` | OK |
| `pages/merchant/marketing/index.js:602` | `navigateTo` | `/pages/merchant/decor/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/marketing/index.js:604` | `navigateTo` | `/pages/publish/activity/index?scope=MERCHANT` | OK |
| `pages/merchant/marketing/index.js:607` | `navigateTo` | `/pages/merchant/marketing/ai-insight/index` | MISSING-ROUTE (for Claude) |
| `pages/merchant/marketing/index.js:619` | `navigateTo` | `/pages/merchant/coop-center/index` | OK |
| `pages/merchant/payout-account/index.js:40` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/payout-account/index.js:41` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/predict/index.js:78` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/predict/index.js:79` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/profile/index.js:121` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/profile/index.js:128` | `switchTab` | `/pages/index/index` | OK |
| `pages/merchant/profile/index.js:130` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/relation/index.js:409` | `navigateTo` | `/pages/userinfo/userinfo?userId=` | OK |
| `pages/merchant/relation/index.js:415` | `navigateTo` | `/pages/square/detail/index?id=` | OK |
| `pages/merchant/relation/index.js:420` | `navigateTo` | `/pages/club/detail/index?id=` | OK |
| `pages/merchant/relation/index.js:431` | `navigateTo` | `/pages/topic/index/index?id=` | OK |
| `pages/merchant/relation/index.js:516` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/reviews/index.js:164` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/reviews/index.js:168` | `switchTab` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/reviews/index.js:168` | `reLaunch` | `?` | MISSING-ROUTE (for Claude) |
| `pages/merchant/team/index.js:423` | `reLaunch` | `/pages/merchant/index/index` | OK |
| `pages/merchant/team/index.js:426` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/team/index.js:427` | `reLaunch` | `/pages/index/index` | OK |
| `pages/merchant/verify-records/index.js:53` | `navigateBack` | `BACK` | OK (system back) |
| `pages/merchant/verify-records/index.js:54` | `reLaunch` | `/pages/merchant/index/index` | OK |

## account-publish

| Source MP file:line | Kind | Target | App Status |
|---|---|---|---|
| `pages/address/address.js:44` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/address/address.js:125` | `navigateBack` | `/pages/member/index/index` | OK (system back) |
| `pages/addressinfo/addressinfo.js:81` | `navigateBack` | `/pages/address/address` | OK (system back) |
| `pages/addressinfo/addressinfo.js:218` | `navigateBack` | `BACK` | OK (system back) |
| `pages/addressinfo/addressinfo.js:222` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/addressinfo/addressinfo.js:225` | `reLaunch` | `?` | MISSING-ROUTE (for Claude) |
| `pages/agreement/index.js:52` | `navigateBack` | `BACK` | OK (system back) |
| `pages/agreement/index.js:52` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/crop/index.js:318` | `navigateBack` | `BACK` | OK (system back) |
| `pages/crop/index.js:320` | `reLaunch` | `/pages/index/index` | OK |
| `pages/deregister/index.js:6` | `navigateBack` | `/pages/shezhi/shezhi` | OK (system back) |
| `pages/gerenziliao/gerenziliao.js:765` | `navigateBack` | `BACK` | OK (system back) |
| `pages/gerenziliao/gerenziliao.js:766` | `switchTab` | `/pages/member/index/index` | OK |
| `pages/mylike/mylike.js:435` | `navigateTo` | `/subpackageRoam/poi-detail/index?poiId=` | MISSING-ROUTE (for Claude) |
| `pages/mylike/mylike.js:652` | `navigateTo` | `/pages/square/detail/index?id=` | OK |
| `pages/mylike/mylike.js:660` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/privacy/index.js:282` | `navigateBack` | `BACK` | OK (system back) |
| `pages/privacy/index.js:283` | `reLaunch` | `/pages/shezhi/shezhi` | OK |
| `pages/privacy/index.js:305` | `switchTab` | `/pages/index/index` | OK |
| `pages/publish/activity/index.js:738` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/publish/activity/index.js:748` | `navigateTo` | `/pages/publish/template-intro/index` | OK |
| `pages/publish/activity/index.js:932` | `navigateBack` | `/pages/talent/list/index` | OK (system back) |
| `pages/publish/fabu/index.js:682` | `navigateBack` | `/pages/template/index` | OK (system back) |
| `pages/publish/fabu/index.js:1128` | `redirectTo` | `/pages/publish/fabu/index?newDraft=1&mode=` | OK |
| `pages/publish/fabu/index.js:2878` | `switchTab` | `/pages/template/index` | OK |
| `pages/publish/fabu/index.js:3363` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/publish/fabu/index.js:8500` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/publish/fabu/index.js:8941` | `navigateTo` | `/pages/publish/temp/index?from=fabu&id=` | OK |
| `pages/publish/temp/index.js:542` | `navigateBack` | `BACK` | OK (system back) |
| `pages/publish/temp/index.js:544` | `switchTab` | `/pages/template/index` | OK |
| `pages/publish/temp/index.js:3520` | `reLaunch` | `/subpackageA/pages/myproject/index?type=template` | MISSING-ROUTE (for Claude) |
| `pages/publish/temp/index.js:3910` | `redirectTo` | `/pages/templatedetail/templatedetail?id=` | OK |
| `pages/publish/template-intro/index.js:291` | `navigateTo` | `/pages/publish/temp/index` | OK |
| `pages/shezhi/about/index.js:52` | `navigateBack` | `BACK` | OK (system back) |
| `pages/shezhi/about/index.js:53` | `redirectTo` | `/pages/shezhi/shezhi` | OK |
| `pages/shezhi/components/privacy-sheet/index.js:52` | `navigateTo` | `/pages/privacy/index` | OK |
| `pages/shezhi/marketing/index.js:34` | `navigateBack` | `BACK` | OK (system back) |
| `pages/shezhi/marketing/index.js:35` | `redirectTo` | `/pages/shezhi/shezhi` | OK |
| `pages/shezhi/shezhi.js:105` | `navigateBack` | `/pages/member/index/index` | OK (system back) |
| `pages/shezhi/shezhi.js:130` | `navigateTo` | `/pages/club/detail/index?owner=1&tab=manage` | OK |
| `pages/shezhi/shezhi.js:132` | `navigateTo` | `/pages/club/create/index` | OK |
| `pages/shezhi/shezhi.js:134` | `navigateTo` | `/pages/club/apply/index` | OK |
| `pages/shezhi/shezhi.js:147` | `navigateTo` | `/pages/merchant/apply/index` | OK |
| `pages/shezhi/shezhi.js:150` | `navigateTo` | `/subpackageA/pages/infomation/infomation` | OK |
| `pages/shezhi/shezhi.js:158` | `navigateTo` | `/pages/merchant/decor/index` | MISSING-ROUTE (for Claude) |
| `pages/shezhi/shezhi.js:161` | `navigateTo` | `/pages/gerenziliao/gerenziliao` | OK |
| `pages/shezhi/shezhi.js:167` | `navigateTo` | `/subpackageJourney/pages/promo/index` | MISSING-ROUTE (for Claude) |
| `pages/shezhi/shezhi.js:170` | `navigateTo` | `/pages/mylike/mylike` | OK |
| `pages/shezhi/shezhi.js:187` | `navigateTo` | `/pages/shezhi/marketing/index` | OK |
| `pages/shezhi/shezhi.js:215` | `navigateTo` | `/subpackageMember/complaint/index` | OK |
| `pages/shezhi/shezhi.js:218` | `navigateTo` | `/subpackageMember/appeal-mine/index` | OK |
| `pages/shezhi/shezhi.js:221` | `navigateTo` | `/subpackageMember/invoice/index` | OK |
| `pages/shezhi/shezhi.js:229` | `navigateTo` | `/pages/shezhi/about/index` | OK |
| `pages/shezhi/shezhi.js:325` | `reLaunch` | `/pages/index/index` | OK |
| `pages/square/detail/index.js:161` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/square/detail/index.js:170` | `navigateTo` | `/pages/topic/index/index?id=` | OK |
| `pages/square/detail/index.js:192` | `navigateTo` | `/pages/play/index?` | OK |
| `pages/square/detail/index.js:1103` | `navigateBack` | `BACK` | OK (system back) |
| `pages/square/detail/index.js:1105` | `switchTab` | `/pages/talent/list/index` | OK |
| `pages/talent/list/index.js:122` | `navigateTo` | `/subpackageMember/market/passes/index` | MISSING-ROUTE (for Claude) |
| `pages/talent/list/index.js:233` | `navigateTo` | `/pages/square/detail/index?id=` | OK |
| `pages/talent/list/index.js:238` | `navigateTo` | `/pages/club/detail/index?id=` | OK |
| `pages/talent/list/index.js:245` | `navigateTo` | `/pages/topic/index/index?id=` | OK |
| `pages/talent/list/index.js:251` | `navigateTo` | `/pages/play/index?topicId=` | OK |
| `pages/talent/list/index.js:275` | `navigateTo` | `/pages/userinfo/userinfo?userId=` | OK |
| `pages/talent/list/index.js:570` | `navigateTo` | `/subpackageB/pages/im/list/index` | OK |
| `pages/talent/list/index.js:583` | `navigateTo` | `?` | MISSING-ROUTE (for Claude) |
| `pages/team/detail/index.js:108` | `navigateBack` | `/subpackageRoam/my-teams/index` | OK (system back) |
| `pages/team/detail/index.js:420` | `navigateBack` | `/pages/talent/list/index` | OK (system back) |
| `pages/team/detail/index.js:468` | `navigateTo` | `/pages/team/join/index?code=` | OK |
| `pages/team/join/index.js:184` | `navigateBack` | `/pages/talent/list/index` | OK (system back) |
| `pages/team/join/index.js:198` | `navigateBack` | `/pages/index/index` | OK (system back) |
| `pages/team/join/index.js:226` | `navigateTo` | `/pages/activity/baoming/baoming?activityId=` | OK |
| `pages/team/join/index.js:234` | `navigateBack` | `BACK` | OK (system back) |
| `pages/team/join/index.js:237` | `redirectTo` | `/pages/team/detail/index?teamId=` | OK |
| `pages/userinfo/userinfo.js:52` | `navigateBack` | `BACK` | OK (system back) |
| `pages/userinfo/userinfo.js:53` | `switchTab` | `/pages/member/index/index` | OK |
| `subpackagePass/reveal/index.js:120` | `redirectTo` | `?` | MISSING-ROUTE (for Claude) |
| `subpackagePass/reveal/index.js:123` | `navigateBack` | `BACK` | OK (system back) |
| `subpackagePass/reveal/index.js:124` | `switchTab` | `/pages/member/index/index` | OK |

