# Mini-program delta 4 (2026-11-14)

Behavior, copy, and visual changes. Shared components and tokens already on this branch only. Round 3 is `docs/release/mp-delta-3.md` on `ui/cur-mp-delta-3` `2d6e8ff4b88fdfe755c06c037ef38ae892781632`. That round's master tip was `f7fd2a8728971e52ddde6943cb24bce5264b3ca8`. The two round-80 ports (unused self-play pass 「可使用」, settle rating `request_id`) are not redone.

Read over HTTPS from public `liboyang42-cpu/hengyin`. Player pages are `chengyinhub-xcx`.

## Commits read

`master` tip read: `5149d4fcdb655f1f9275db76bd2cee18b2ba68ab` (2026-11-14 05:34 America/Los_Angeles). Two commits sit after `f7fd2a872`.

| SHA | When (America/Los_Angeles) | What |
|---|---|---|
| `316f717d1040af392647891dbe9a8b01a41b290f` | 2026-11-14 05:05 | #838. Squash of the 1114 waves (play, roam, maps, free-explore, template shelf). Player diff is on this commit. |
| `5149d4fcdb655f1f9275db76bd2cee18b2ba68ab` | 2026-11-14 05:34 | #839. Owner decision A. Cross-club and four-shop session cash settles to the organizer. Java and a RESULT note. No `chengyinhub-xcx` file. |

`fix/*` tips whose commit time is after `f7fd2a872` (2026-11-14 03:33 America/Los_Angeles). A tip round 3 already named is compared with that recorded SHA.

| Branch | Round 3 tip | Tip read now | Note |
|---|---|---|---|
| `fix/play-wave-1114` | `550afadfd6cf1c15ede93cb6c3b2909645c68d98` | `eaf7d4f43dd2780191191a79ca0e1a9bcaca8616` | The new commit is only `docs/delivery/questo-ui-20261109/play-wave-1114/RESULT.md`. Player source landed on master as #838. |
| `fix/fe-settlement-a-1114` | not named | `4dbd89d9054d88a1e85bda12b825808f5f878063` | Diverges from master after the squash. Unique files are settlement Java and `fe-settlement-a-1114/RESULT.md`. No player page. |
| `fix/free-explore-1114` | `d6698fc0a9035312988270db630475e63fca9044` | same | Already read in round 3. Player source is now on master as #838. |
| `fix/roam-frontend-1114` | `b3b6e67ecddf20142677b369d0a591ca7a7794e0` | same | Already read in round 3. Player source is now on master as #838. |
| `fix/master-ci-1114` | `022a50f7dc165a92d8f1075b7a85bd2e628b481b` | same | CI sync. No new player page. |

Other `fix/*` tips are at or before `f7fd2a872` and were not reopened. That includes `fix/answers-checkout-1114`, `fix/roam-backend-1114`, `fix/maps-1114`, `fix/guest-catalog-place-1114`, and `fix/prod-release-ddl` at the SHAs round 3 recorded.

## Done

Five rows. All from #838.

| Mini-program change | Native file | Screen | hengyin SHA |
|---|---|---|---|
| Whole-run clock uses `h:mm:ss` once the run reaches one hour. Under one hour stays `mm:ss`. Short challenge timers are unchanged. | `Core/PlayRunLifecycle.swift` (`PlayRunElapsedText`), `App/PlayExperienceView.swift` | Play run clock | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Ticket expiry that lands on China midnight counts as the previous playable day, the same day as 「可玩至」. | `Core/MoneyParityRules.swift` (`MoneyPassExpiry`) | Ticket wallet detail | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Q&A rows draw the letter and drop a matching author prefix (`A `, `A.`, `（A）`). A strip that would leave no words keeps the original. Picture options use the same strip. The option id is unchanged. | `Core/PlayKitQuestoContracts.swift`, `App/PlayKitQuestionForms.swift`, `App/DesignSystem/CYCityKit.swift` | Play kit Q&A | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Hangman title falls back to the station question, then the place name. After the server says solved, feedback is the kit line, else the station `passText`. Judgement stays on the server. | `Core/PlayKitQuestoContracts.swift`, `Core/PlayContracts.swift`, `App/PlayKitQuestoViews.swift`, `App/PlayAdvancedView.swift`, `App/PlayExperienceView.swift` | Play kit hangman | `316f717d1040af392647891dbe9a8b01a41b290f` |
| Pass reveal: a tap while the animation is running, and the skip control, land on the end state. They do not leave the screen. The primary button appears with that end state. | `App/PassMembershipViews.swift` | Pass reveal | `316f717d1040af392647891dbe9a8b01a41b290f` |

## Not done

| Mini-program change | SHA | Screen | Reason |
|---|---|---|---|
| #831 settle rating `request_id`, and the unused self-play pass label 「可使用」. | `3ffd1201704bd99787b9653f4618dab2c4c874bd` | — | Already ported on `ui/cur-mp-delta-2`. Not redone. |
| Play location recovery 「开启定位」 / 「扫码到达」, 300 m start gate, story hint ladder, chapter-gate final values, photo 「提交失败，照片已保留」 / 「重新提交」 / 「审核中…」, finish archive for every route, ticket link `topicId`, route-session shown state, album 「去设置」, connection-failure retry split, China-zone finish date, real map snapshot instead of a drawn route. | `316f717d1040af392647891dbe9a8b01a41b290f` | — | This tip's play screen does not have those controls. The run clock above is the one elapsed display that did overflow. Photo check is capture, upload, then use. No StoreKit product id is invented. |
| Hangman title `word-break: keep-all`, pass-reveal press opacity. | `316f717d1040af392647891dbe9a8b01a41b290f` | Play kit hangman, pass reveal | No shared text style keeps a short Chinese title from breaking between characters. The reveal tap is the behavior row above. |
| Roam entry map without a location fix, category pins, clustering, mystery pins, 「还差 N 米」, 「资料来源」, 「本城推荐」, nearby 「只显示离你最近的 N 处」, cover and quote cards, medal primary 「写一张城市签」. | `316f717d1040af392647891dbe9a8b01a41b290f` | — | This tip does not have those roam controls. 「投一张」 stays `roamSub.w208.poi.dropStamp`. The branch now on master does not add a second roam home. |
| Map style 白 / 黑 / 纸本 / 2077, and Tencent `takeSnapshot` share cards. | `316f717d1040af392647891dbe9a8b01a41b290f` | — | Those are Tencent layer styles and snapshot calls. This tip's maps do not have that switch, and there is no shared token for those four basemaps. |
| Template shelf 「暂未开放」, 「用这个模板」, 15 s fresh window, request id on adopt, staff retry 「岗位权限没加载出来，点此重试」. | `316f717d1040af392647891dbe9a8b01a41b290f` | — | No shelf screen with that preview toast or that adopt button. `TemplateTabPolicy` still serves the older template-tab refusals, which this commit did not rewrite. |
| Pricing 「平台服务费」, 「预计到手」, 「结算待处理」, 「已锁价，等待运营开售」, free-explore reservation, merchant 「套票到店」 / 「记未到店」. | `316f717d1040af392647891dbe9a8b01a41b290f` | — | Money and merchant writes stay closed on `www.chengyinhub.com`. No StoreKit product id. |
| Signup double-tap guard and earlier expiry/cancel toasts. | `316f717d1040af392647891dbe9a8b01a41b290f` | — | No ticket-wallet open animation with that 600 ms lock. Ticket id 0 stays 0. |
| #839 organizer settlement for cross-club and four-shop sessions. | `5149d4fcdb655f1f9275db76bd2cee18b2ba68ab` | — | No player page. Payout stays closed. Schema and ledger only. |
| `fix/play-wave-1114` RESULT note. | `eaf7d4f43dd2780191191a79ca0e1a9bcaca8616` | — | Docs only. The player diff is the #838 rows. |
| `fix/fe-settlement-a-1114`. | `4dbd89d9054d88a1e85bda12b825808f5f878063` | — | Java settlement and a RESULT note. Same closed money path as #839. |
| `fix/free-explore-1114`, `fix/roam-frontend-1114`, `fix/master-ci-1114`. | `d6698fc0a9035312988270db630475e63fca9044`, `b3b6e67ecddf20142677b369d0a591ca7a7794e0`, `022a50f7dc165a92d8f1075b7a85bd2e628b481b` | — | Tips unchanged since round 3. No extra player port beyond #838. |

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed. Swift was not compiled.
