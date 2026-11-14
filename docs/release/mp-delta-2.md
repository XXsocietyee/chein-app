# Mini-program delta 2 (2026-11-14)

Player-visible behaviour and copy only. Styling, layout, color, spacing, and paper-look are skipped. Round 1 is `docs/release/mp-delta-1113.md` on `ui/cur-mp-delta` `5cb9251dc1a597aa44cfa81986ab1a4a5dd01f3c`. Those rows are not repeated.

Read over HTTPS from public `liboyang42-cpu/hengyin`, `chengyinhub-xcx` unless a row says otherwise.

## Commits read

Baseline (round 1 tip, not redone): `73f4f7be45aa5b49381baa2c1aff57e1b2245fad`.

`master` has moved. Two commits after that baseline:

| SHA | When (America/Los_Angeles) | What |
|---|---|---|
| `3ffd1201704bd99787b9653f4618dab2c4c874bd` | 2026-11-14 02:08 | #831 answers, checkout, profile failure, time zone. `docs/delivery/questo-ui-20261109/answers-checkout-1114/RESULT.md` |
| `561cafd10214853e8b43128a3ffe419cf115cca2` | 2026-11-14 02:09 | #830 roam backend projection, catalog place, shelf tools. `docs/delivery/questo-ui-20261109/roam-backend-1114/RESULT.md`. No player page. |

`fix/*` tips read. Player work newer than `73f4f7be` is the range from each branch's merge-base, not a three-dot compare that rewrites files already on `master`.

| Branch | Tip | Note |
|---|---|---|
| `fix/answers-checkout-1114` | `a6accac3a57a8799e9eeed6ca11075e3d296a7df` | xcx tree matches `master` #831. No extra player port. |
| `fix/roam-backend-1114` | `24019702559a72e7ce875292fb32c39b4f016bf9` | Same player surface as #830. No extra player port. |
| `fix/roam-frontend-1114` | `ced1d576e3dd27efb67e81ba8c61a2e499742400` | Unmerged. Entry map, place card, nearby, medal copy. |
| `fix/free-explore-1114` | `7112f73105fabc1f28b6f3790b3db3a4a87e8285` | Unmerged. Merchant shelf, pricing, reservations, template authoring. |
| `fix/guest-catalog-place-1114` | `fbd396523a287bd3277742fb7616537e1e3f8b96` | Unmerged. `SecurityConfig` permit list and tests. No player page. |
| `fix/maps-1114` | `a732fe7c2f716a066bda4b5ce66f6d4a2c815d6e` | Unmerged. Map style white/black/paper/2077 and share snapshots. |
| `fix/play-wave-1114` | `d77641aa6bfe9244f2cdb2777d4a41f26a687f54` | Unmerged. Play-page walk. Merge-base is older than `73f4f7be`; unique range is `d77641aa` and its parent commits after that merge-base. |
| `fix/prod-release-ddl` | `46f2483c3cba3c4cb83c39587ed35a1629b9416d` | SQL idempotency. Merge-base `92eda912` is older than the baseline. No new player copy. |

Tips at or before `73f4f7be`, or already named in round 1, were listed and not redone: `fix/play-round3-1114` `35d9feb0`, `fix/play-round4-1114` `361229c2`, `fix/backend-final-gaps-1114` `18f9ab4e`, `fix/fe-perk-entry-20261113` `a592b1f9`, and the 1113 `fix/*` branches named in `mp-delta-1113.md`.

## Rows

| Mini-program change | Native file | Result |
|---|---|---|
| #831 `3ffd120`. Play type-in adds a second key row for characters that are not a–z (digits, punctuation, Chinese, case-sensitive capitals). `pages/play/playkit-typein`. The flex wrap is layout and is skipped. | `App/PlayKitTimedChallengeView.swift` | Not done. This tip's type-in is the system keyboard. There is no terminal a–z key row to extend. |
| #831 `3ffd120`. Play Q&A drops the local `matchesAnswer` judge. The server `AnswerNormalizer` decides. `utils/answer-text.js` is the author preview splitter, not the play judge. | `Core/PlayKitScreenProjection.swift` | Not done. Type-in outcomes on this tip are already server-owned. Author preview is not a player screen. |
| #831 `3ffd120`. Author preview and hangman split on `、,，;；` in `pages/publish/temp/preview-verdict.js` and `questo-author.js`. | — | Not done. Authoring, not player play. |
| #831 `3ffd120`. Checkout quote `failed` does not fall back to the listed price. Total and lines are 「—」. Pay label 「重新获取价格」. Alert 「价格没取到，请重试」. Requote reloads facts and does not create an order. Confirm is blocked while failed or refused. | `App/TopicSelfPlaySheet.swift`, `Core/TopicSelfPlayFlow.swift` | Not done. This tip prices the sheet from `topic.selfPlayPrice`. It has no quote failed/ready state. Money stays behind the existing `ReviewedAreaSwitch`. It is not redeclared here. |
| #831 `3ffd120`. Profile load failure is not an empty profile. Toast 「资料没取到，请检查网络后重试」. Do not show 「还差姓名和手机号」 or jump to profile. Keep the cached checkout profile. | `App/TopicSelfPlaySheet.swift` | Not done. This tip collects name and phone in the sheet. It has no profile-prefetch modal. |
| #831 `3ffd120`. A payment timeout no longer marks the payment settled and no longer drops the real SDK callback. Dialog stays 「支付结果待确认」. Content 「暂不要重复支付。可以刷新订单状态，确认后会自动进入通行证。」 Confirm 「刷新订单状态」. Cancel 「稍后再说」. Toasts 「正在刷新订单状态」 / 「还在确认支付结果，请勿重复支付」 / 「还在确认支付结果，请稍候」. Poll 5s × 6. | `App/TopicSelfPlaySheet.swift` | Not done. Provider return already opens the readback (`OrderPaymentVerifier` → `showReadback()`). There is no WeChat callback timer that marks the order settled. No StoreKit product id is invented. `www.chengyinhub.com` stays closed. |
| #831 `3ffd120`. Each confirm click resets `_rebuildUsed` so a new purchase intent can create an order. Unused `_retrySelfPlayPayment` is deleted. | `Core/TopicSelfPlayFlow.swift` | Not done. This tip has no rebuild flag. A new order is created only after registration 3/4. |
| #831 `3ffd120`. Settle rating `POST /api/comment/add` sends `request_id`. The same intent is reused until success, then cleared. Server accepts `[A-Za-z0-9_-]{16,64}` when member id > 0. | `Core/JourneyLoopSource.swift`, `App/PlayerJourneyReadBindings.swift` | Done. `rate` requires `requestID` and rejects any other shape before the request is sent. `PlayerJourneySettleModel` keeps the id until `envelope.ok && !envelope.unconfirmed`. Square comments, roam place comments, and contextual reviews are unchanged. |
| #831 `3ffd120`. Checkout toast `lift` so a payment-failure toast does not cover the consent row. | — | Not done. Layout. |
| #831 `3ffd120`. A paid self-play pass with no first successful scan, after the end check and after a future start, shows 「可使用」 instead of 「进行中」. A future start stays 「未开始」. After a first scan, 「进行中」 on the mini-program. Expired stays 「已结束」. Pass means `purchaseKind == 2`, or legacy `ownerType == 1` with no ticket and `expiresAt`. Ticket id 0 is no ticket. `purchaseKind` 0 is present and is not a pass. | `Core/ProfileOrderHistoryFilter.swift`, `Core/ProfileOrderSourcePresentation.swift`, `Core/ParticipationParity.swift`, `App/ProfileOrdersView.swift`, `Resources/Localizable.xcstrings` | Done for the unused-pass label. Key `orderLifecycle.state.passReady` (可使用 / Ready to use). A decoded scan of 0 stays the string `0` and is not a scan time. A decoded ticket id of 0 stays 0. A future start stays `orderLifecycle.state.notStarted`. `OrderLifecycleDetail.summary` is unchanged. A parsed first scan still completes a pass on this tip; that path was already here and is not this delta. |
| #831 `3ffd120`. Time windows use Asia/Shanghai. Server only. | — | Not done. No mini-program client change. |
| #830 `561cafd`. Roam list/detail projection, catalog place detail, batch shelf, import tools. No player page. | — | Not done. The mini-program consumption of those fields is `fix/roam-frontend-1114`, which is not on `master`. |
| `fix/roam-frontend-1114` `ced1d576`. Entry map loads without a location fix, extra key pins, clustering, place sheets, nearby chips 「距你很近」 / 「只显示离你最近」, gap 「还差 xx 米」 plus navigation, medal primary 「写一张城市签」, cover, tags, truncated hint, 「资料来源」, 「本城推荐」. | `App/RoamStampCameraView.swift` and the roam home already on this tip | Not done. This tip does not have those controls. The visible 「投一张」 is `roamSub.w208.poi.dropStamp`, a different button. `RoamExperienceCapabilities.stampExchange` is false. The branch was not merged. |
| `fix/maps-1114` `a732fe7c`. Map style white / black / paper / 2077, and a real map snapshot instead of a drawn route on the share card. | — | Not done. The style switch is paper-look and styling. The native roam share card is a different implementation. No map-style switch is added. |
| `fix/play-wave-1114` `d77641aa`. Play-page behaviour and copy after the baseline: compass `allowSkip`, location recovery 「开启定位」 / 「扫码到达」, story hints, 300m start gate, hangman title, finish and archive, ticket link `topicId`, chapter gate, duration of at least one hour as h:mm:ss, multi-select, photo resubmit 「提交失败，照片已保留」 / 「重新提交」, pass skip, shown `routeSessionId`, China-zone time parse, real map snapshot instead of a fake grid. New strings include 「上一次打卡还没确认。核对一次，看看有没有记上。」, 「打卡结果待确认」, 「本局完成」, 「开局时检查你是否在起点约 300 米内…」. | Play kit on this tip (`App/PlayKitTimedChallengeView.swift` and the server-owned play projection) | Not done. Those mini-program controls are not this tip's play kit. Round 1 already recorded the earlier location-retry dialog and the client 300m gate as absent. This branch was not merged to fetch them. |
| `fix/free-explore-1114` `7112f731`. D-01–D-30 merchant shelf, pricing, reservations, and template preview copy, including 「已锁价，需联系客服」. | — | Not done. No matching player screen. On this tip 「已锁价，需联系客服」 is `cooperation.detail.cancelLocked`, a different screen. |
| `fix/guest-catalog-place-1114` `fbd39652`. Catalog place reads allowed without a session. | — | Not done. Server `SecurityConfig` and tests only. No player page. |
| `fix/answers-checkout-1114` `a6accac3` and `fix/roam-backend-1114` `24019702`. | — | Not done as a separate port. Their player files are already on `master` as #831 and #830. |
| `fix/prod-release-ddl` `46f2483c`. | — | Not done. Schema idempotency and an older integration merge. No new player copy after `73f4f7be`. |
