# Mini-program delta 3 (2026-11-14)

Player-visible behaviour and copy only. Styling, layout, color, spacing, and paper-look are skipped. Round 80 is `docs/release/mp-delta-2.md` on `ui/cur-mp-delta-2` `4279642dd62c7fd226cac79dd25894cbc574e7ae`. That round's baseline was `73f4f7be45aa5b49381baa2c1aff57e1b2245fad`. It ported two player changes and did not re-read the source of `3ffd1201704bd99787b9653f4618dab2c4c874bd` and `561cafd10214853e8b43128a3ffe419cf115cca2`. This round re-read those two commits, then read every later `master` and `fix/*` commit through the current `master` tip. The two round-80 ports are not redone.

Read over HTTPS from public `liboyang42-cpu/hengyin`. Player pages are `chengyinhub-xcx`.

## Commits read

`master` tip read: `f7fd2a8728971e52ddde6943cb24bce5264b3ca8` (2026-11-14 03:33 America/Los_Angeles). It is still the tip. Three commits sit after `73f4f7be`.

| SHA | When (America/Los_Angeles) | What |
|---|---|---|
| `3ffd1201704bd99787b9653f4618dab2c4c874bd` | 2026-11-14 02:08 | #831. Re-read. Player diff is type-in keys, Q&A judge removal, author preview split, checkout quote failure, profile failure vs empty profile, payment-unknown copy, rebuild flag, settle `request_id`, toast lift, unused-pass 「可使用」, plus server time zone. |
| `561cafd10214853e8b43128a3ffe419cf115cca2` | 2026-11-14 02:09 | #830. Re-read. No `chengyinhub-xcx` file outside tests and the action ledger. Backend roam projection, catalog place, shelf, import. |
| `f7fd2a8728971e52ddde6943cb24bce5264b3ca8` | 2026-11-14 03:33 | #835. New since round 80. `GET /api/city/places/{id}` permitAll. Mini-program diff is the auth-matrix test, order-fixture unload, and the action ledger. No player page. |

`fix/*` tips whose commit time is after `73f4f7be` (2026-11-14 05:05 UTC). A tip round 80 already named is compared with that recorded SHA. Unique range means commits not on `master`.

| Branch | Round 80 tip | Tip read now | Note |
|---|---|---|---|
| `fix/answers-checkout-1114` | `a6accac3a57a8799e9eeed6ca11075e3d296a7df` | same | xcx tree still matches `master` #831. |
| `fix/roam-backend-1114` | `24019702559a72e7ce875292fb32c39b4f016bf9` | same | No player page beyond #830. |
| `fix/maps-1114` | `a732fe7c2f716a066bda4b5ce66f6d4a2c815d6e` | same | Map style and share snapshot. |
| `fix/prod-release-ddl` | `46f2483c3cba3c4cb83c39587ed35a1629b9416d` | same | SQL idempotency. |
| `fix/guest-catalog-place-1114` | `fbd396523a287bd3277742fb7616537e1e3f8b96` | `187d5d0fd76e40cc7cf15a4f0efac094dbc9dfc7` | New commits are answer-timezone fixtures and order-fixture unload. The permit list is the change merged as #835. |
| `fix/master-ci-1114` | not named | `022a50f7dc165a92d8f1075b7a85bd2e628b481b` | Tree matches `master`. CI sync only. |
| `fix/roam-frontend-1114` | `ced1d576e3dd27efb67e81ba8c61a2e499742400` | `b3b6e67ecddf20142677b369d0a591ca7a7794e0` | The new commit only recalibrates the action ledger after merging `master`. Player pages are unchanged from the tip round 80 already skipped. |
| `fix/free-explore-1114` | `7112f73105fabc1f28b6f3790b3db3a4a87e8285` | `d6698fc0a9035312988270db630475e63fca9044` | New player diff moves pricing and template flags off `data` onto the page instance. No new string. |
| `fix/play-wave-1114` | `d77641aa6bfe9244f2cdb2777d4a41f26a687f54` | `550afadfd6cf1c15ede93cb6c3b2909645c68d98` | New unique commits seed `photoFailKind` / `photoJudging`, retarget a press selector, and mark a polyline color `ds-ok`. |

Other `fix/*` tips are at or before `73f4f7be` and were not reopened.

## Done

No new row. Round 80 already ported settle-rating `request_id` and the unused self-play pass label. Those two stay listed under Not done as already ported.

| Mini-program change | Native file | hengyin SHA |
|---|---|---|
| — | — | — |

## Not done

| Mini-program change | SHA | Reason |
|---|---|---|
| #831 settle rating `POST /api/comment/add` sends `request_id`, reused until success. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | Already ported by 80 in `Core/JourneyLoopSource.swift` and `App/PlayerJourneyReadBindings.swift`. Not redone. |
| #831 a paid self-play pass with no first successful scan shows 「可使用」. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | Already ported by 80 as `orderLifecycle.state.passReady` (可使用 / Ready to use). Not redone. |
| #831 type-in adds a second key row for characters outside a–z. The flex wrap is layout. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | No player screen of that kind. `App/PlayKitTimedChallengeView.swift` uses the system keyboard. There is no terminal a–z row to extend. |
| #831 play Q&A drops local `matchesAnswer`. The server `AnswerNormalizer` decides. `utils/answer-text.js` splits author preview. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | Type-in outcomes on this tip are already server-owned. Author preview is not a player screen. |
| #831 author preview and hangman split on `、,，;；`. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | No player screen. Authoring only. |
| #831 checkout quote `failed` does not fall back to the listed price. Total and lines are 「—」. Pay label 「重新获取价格」. Alert 「价格没取到，请重试」. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | No quote failed/ready state. `App/TopicSelfPlaySheet.swift` prices the sheet from `topic.selfPlayPrice`. Money stays behind the existing `ReviewedAreaSwitch`. No StoreKit product id is invented. |
| #831 profile load failure is not an empty profile. Toast 「资料没取到，请检查网络后重试」. Keep the cached checkout profile. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | No profile-prefetch modal. This tip collects name and phone in the sheet. |
| #831 payment timeout no longer marks the payment settled. Dialog stays 「支付结果待确认」, with refresh and poll copy. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | Money closed. No StoreKit product id. Provider return already opens the readback. The payment path is left alone. |
| #831 each confirm resets `_rebuildUsed` so a new purchase intent can create an order. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | This tip has no rebuild flag. A new order is created only after registration 3/4. Money closed. |
| #831 checkout toast `lift` so a payment-failure toast does not cover the consent row. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | Layout. |
| #831 time windows use Asia/Shanghai. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | Server only. No mini-program client change. |
| #830 roam list/detail projection, catalog place detail, batch shelf, import tools. | `561cafd10214853e8b43128a3ffe419cf115cca2` | No player page. The re-read diff has no `chengyinhub-xcx` source outside tests and the ledger. |
| #835 `GET /api/city/places/{id}` is anonymous. Tests unload order fixtures and separate an empty profile body from a failed request. | `f7fd2a8728971e52ddde6943cb24bce5264b3ca8` | No player screen. This tip does not call `/api/city/places/{id}`. The empty-versus-failed profile rule is the #831 checkout behavior above, and the mini-program page source does not change in this commit. |
| `fix/guest-catalog-place-1114` answer-timezone fixtures and order-fixture unload. | `187d5d0fd76e40cc7cf15a4f0efac094dbc9dfc7` | No player page. The permit list is already the #835 row. |
| `fix/master-ci-1114` syncs `master` and records that #835 covers the CI fix. | `022a50f7dc165a92d8f1075b7a85bd2e628b481b` | Tree matches `master`. No player page. |
| `fix/roam-frontend-1114` ledger recalibration after merging `master`. The older unmerged entry map, place card, nearby chips, and medal copy are unchanged from `ced1d576`. | `b3b6e67ecddf20142677b369d0a591ca7a7794e0` | No new player copy. This tip still does not have those roam controls. The branch is not on `master`. |
| `fix/free-explore-1114` pricing and template pages keep floor, scope, and platform rate on the page instance instead of `data`. | `d6698fc0a9035312988270db630475e63fca9044` | No new player-visible string. No matching player screen. Merchant pricing stays behind the closed money switches. |
| `fix/play-wave-1114` seeds `photoFailKind: ''` and `photoJudging: false` when the photo-check view is built. | `ca2cab504d9532ebaae107b304e2a86bc8261c4c` | No player screen for that photo resubmit control. The visible failure copy was already on `d77641aa`, which round 80 left unported because this tip's play kit does not have those controls. The branch is not on `master`. |
| `fix/play-wave-1114` pass-reveal press selector `.pr-tap { opacity: .85 }`. | `550afadfd6cf1c15ede93cb6c3b2909645c68d98` | Styling. |
| `fix/play-wave-1114` polyline color comment marked `ds-ok`. The color value does not change. | `4eec86b925bb2668f60e8525b6389afd89ffc11f` | Styling. Map snapshot drawing is not ported. |
| `fix/maps-1114` map style white / black / paper / 2077 and a map snapshot on the share card. | `a732fe7c2f716a066bda4b5ce66f6d4a2c815d6e` | Styling and paper-look. No map-style switch is added. |
| `fix/answers-checkout-1114` and `fix/roam-backend-1114`. | `a6accac3a57a8799e9eeed6ca11075e3d296a7df`, `24019702559a72e7ce875292fb32c39b4f016bf9` | Already on `master` as #831 and #830. No extra player port. |
| `fix/prod-release-ddl`. | `46f2483c3cba3c4cb83c39587ed35a1629b9416d` | Schema idempotency. No new player copy after `73f4f7be`. |
