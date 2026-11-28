# K13 · Release composition audit (`cursor/1128-release-audit`)

The planning audit's root cause: the player services existed, but the Release composition never switched them on (nil approvals, empty approval lists, disabled gates, missing allow-list use). This pass builds `RegionalLaunchConfiguration.reviewedDeployment` for the China release and for the shipped US storefront and classifies every player service.

The shipped US build does not use a US-market deployment. `shippedComposition` pins a US build on the reviewed host to the China backend (`market: CN`, `https://www.chengyinhub.com/prod-api/`) and then calls `reviewedDeployment`. The CN and US columns below are that shared deployment. A literal `reviewedDeployment(market: US)` is not the release path; its player leases stay off.

Counts on that shared deployment: **54 on**, **26 off by design**, **10 was off by mistake** (now on). The literal US-market deployment is one more off-by-design row, so the table's off-by-design total is **27**.

Money switches were not flipped. `PlayerLaunch.merchantCenterEnabled` stays `false` in Release. Security and account-deletion gates were not touched. Injected approvals still win. A deployment with `productionGatesEnabled == false` still issues none of the new reads.

Proof: `Tests/AppUnitTests/ReleasePlayerServiceAuditTests.swift`.

| Service | CN | US | Classification | What changed |
|---|---|---|---|---|
| Play configuration | on | on | on | Unchanged. Devices, capabilities, and artwork hosts were already on. |
| Player write grant | on | on | on | Unchanged. IM, club, square, profile, registration, team, play, roam, likes, reports, friends, channel text. |
| Club governance | on | on | on | Unchanged. |
| Official player actions | on | on | on | Unchanged. |
| Contextual review | on | on | on | Unchanged. |
| Player coupon QR | on | on | on | Unchanged. `api/coupon/qr-token`, `api/coupon/status`. |
| Order device-payment flag | on | on | on | Unchanged. `devicePaymentApproved` stays true. Payment approvals stay empty. |
| Non-cash rewards | on | on | on | Unchanged. |
| Club community read | on | on | on | Unchanged. |
| Club post image upload | on | on | on | Unchanged. |
| Club badges | on | on | on | Unchanged. |
| Club role assignment | on | on | on | Unchanged. |
| Club welcome note | on | on | on | Unchanged. |
| Club public roster | on | on | on | Unchanged. |
| Club public topics | on | on | on | Unchanged. |
| Template shelf | on | on | on | Unchanged. |
| Template authoring | on | on | on | Unchanged. |
| Story image upload | on | on | on | Unchanged. |
| Story audio upload | on | on | on | Unchanged. |
| Node image upload | on | on | on | Unchanged. |
| Owned topic cover | on | on | on | Unchanged. |
| Roam nearby events | on | on | on | Unchanged. |
| Roam nearby players | on | on | on | Unchanged. |
| Roam entry nearby | on | on | on | Unchanged. |
| Received stamps | on | on | on | Unchanged. |
| Roam album | on | on | on | Unchanged. |
| Roam tiles | on | on | on | Unchanged. |
| Roam session fact | on | on | on | Unchanged. |
| Passport tools | on | on | on | Unchanged. |
| Passport history | on | on | on | Unchanged. |
| Roam live | on | on | on | Unchanged. |
| Roam private tools write | on | on | on | Unchanged. The write lease also admits the private-tool reads. |
| Wallet history | on | on | on | Unchanged. |
| Messaging history | on | on | on | Unchanged. |
| Owned orders | on | on | on | Unchanged. |
| Favorites | on | on | on | Unchanged. |
| Favorite topic | on | on | on | Unchanged. |
| Invite history | on | on | on | Unchanged. |
| Growth reads | on | on | on | Unchanged. |
| Team read | on | on | on | Unchanged. |
| Explore completion | on | on | on | Unchanged. |
| Invoice reads | on | on | on | Unchanged. |
| Nearby team read | on | on | on | Unchanged. |
| Nearby team write | on | on | on | Unchanged. |
| Topic unlike | on | on | on | Unchanged. |
| Profile participant | on | on | on | Unchanged. |
| City voucher and ticket codes | on | on | on | Unchanged. |
| Owned coupons | on | on | on | Unchanged. |
| Social member follow and chat issuer | on | on | on | Unchanged. `AppSession.releaseIssuesSocialMemberActions` for production gates plus player writes. |
| Business runtime | on | on | on | Unchanged. IM, publishing, and AI creation routes. |
| Shop NPC text | on | on | on | Unchanged. Text and voice transmission. Reply playback stays off. |
| Activity editing | on | on | on | Unchanged. |
| Merchant business writes | on | on | on | Unchanged. Pre-existing MP-first approvals for any China session. Not widened. |
| Merchant engagement writes | on | on | on | Unchanged. Pre-existing MP-first approvals. Not widened. |
| Weekly points | on | on | was off by mistake | `ReleasePlayerReadLeases.weeklyPoints`, issued when production gates are on. `api/user/points/statistics`. |
| Public profile | on | on | was off by mistake | `publicInfo`. `api/user/public-info`. |
| Guide | on | on | was off by mistake | `guide`. `api/common/infomation_list`, `api/common/infomation_detail`. |
| Member role info | on | on | was off by mistake | `memberRole`. `api/role/info` (当前权益). |
| Own media list | on | on | was off by mistake | `ownMediaList`. `GET api/media/asset/list`. `allowsStatus` stays false. |
| Manual map | on | on | was off by mistake | `manualMap`, only when the deployment reads include `.manualMap` (the shipped set does; the default set does not). |
| Public map layers | on | on | was off by mistake | `publicLayers` when `.publicMapLayers` or `.manualMap` is granted. `api/map/public-layers`. |
| Social reader | on | on | was off by mistake | `socialReader` on the player/club session dependencies. `api/object-card/list`, `api/im/messages`, message-image origins. |
| Play kit sensors | on | on | was off by mistake | `playSensors` (acceleration, soundPeak, heading) passed into `playConfiguration`. The devices/artwork contract line is unchanged. `api/play/sensor-result` was already in `playPaths`. |
| Owner draft list and restore | on | on | was off by mistake | `ownerDrafts` for personal `.list` and `.restore` only. |
| Merchant center in Release | off | off | off by design | Unchanged. `PlayerLaunch.merchantCenterEnabled` stays `false` outside DEBUG/TEST. |
| Merchant operations for a player | off | off | off by design | Unchanged. The write lease stays merchant-role only. |
| Merchant coupon management for a player | off | off | off by design | Unchanged. Coupon management stays merchant-role only. |
| Order payment approvals | off | off | off by design | Unchanged. `approvals` stays `[]`. |
| External checkout | off | off | off by design | Unchanged. `externalCheckoutApproved` stays false. |
| Self-play payment | off | off | off by design | Unchanged. |
| Bank withdrawal document | off | off | off by design | Unchanged. |
| Signup payment document | off | off | off by design | Unchanged. |
| Workshop paid install | off | off | off by design | Unchanged. |
| Workshop purchased packages | off | off | off by design | Unchanged. Still closed unless `ReviewedAreaSwitch.moneyPayments` is already open. The production host stays closed. |
| Bundle approvals | off | off | off by design | Unchanged. `bundleApprovals` stays `.closed`. |
| Account deletion source | off | off | off by design | Unchanged. `accountDeregistrationOriginalSource` stays nil. |
| Password login | off | off | off by design | Unchanged. Verified capability stays `.domesticChinaPhone` only. |
| Journey reads | off | off | off by design | Unchanged. Story-flow theme stays paused. |
| Journey narrative images | off | off | off by design | Unchanged. |
| Native platform acceptance | off | off | off by design | Unchanged. Legal review and the https privacy URL are still required. |
| Walking navigation | off | off | off by design | Unchanged. No verified MapKit regions are invented. |
| Personal location share | off | off | off by design | Unchanged. `installReviewedPersonalLocationShareApprovals` has no production caller. |
| Project topic image | off | off | off by design | Unchanged. No reviewed media policy, so no default issuer. |
| Nearby merchant location | off | off | off by design | Unchanged. `nearbyLocation` stays false (`api/merchant/nearby`). |
| Private home | off | off | off by design | Unchanged. |
| Owner refund beyond the money switch | off | off | off by design | Unchanged. Still follows `ReleaseMoneyWriteSwitch.refund`. |
| City board | off | off | off by design | Unchanged. `QuestifyCityGameRegion` is empty; no region was invented. |
| Own media status writes | off | off | off by design | Unchanged. The new list lease keeps `allowsStatus` false. |
| Owner draft save and delete | off | off | off by design | Unchanged. The new lease is list and restore only. |
| Shop NPC reply playback | off | off | off by design | Unchanged. Reply audio stays off. |
| Literal US-market reviewedDeployment | n/a | off | off by design | Unchanged. Not the release path. Player leases stay nil because the market is not China. |

## Left off on purpose

Merchant center (Release flag), merchant operations and merchant coupon management for a player, order payment approvals, external checkout, self-play payment, bank withdrawal, signup payment, workshop paid install, workshop purchased packages, bundle approvals, virtual-goods and other money switches, account deletion, password login and the other security gates, journey reads and journey images, native platform acceptance, walking navigation, personal location share, project topic image, nearby merchant location, private home, owner refund except where its existing money switch is already on, the city board (empty region), own-media status writes, owner-draft save/delete, and shop NPC reply playback.

## Gates

`python3 tools/check_scaffold.py` PASS (AppSession ratchet PASS, AppCompositionRoot stays at 4175).
`python3 tools/check_a11y_lint.py` PASS (0 new).
`python3 tools/contract_ratchet.py --check` 52 failing, baseline 52, new 0, fixed 0.
`python3 tools/generate_project.py` regenerated the project for the new Swift files.
`swiftc` and `swift test` are not on this machine. The new tests are source-checked by the contract and scaffold gates; the coordinator compiles them on a Mac.
