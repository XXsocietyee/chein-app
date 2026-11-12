# mp-mpjourney: journey loop fidelity pass on `ui/mpmissing`

Branch `ui/mpjourney` is rebuilt on `origin/ui/mpmissing` bf19c71d7. The coordinator said to stop duplicating, so my earlier parallel screens (`Journey*View.swift`, `JourneyLoop*`, `CYJourneyIllus`, `JourneyLoop.xcstrings`) are discarded and are not on this branch. I compared the screens line by line against the mini-program source `liboyang42-cpu/hengyin` `chengyinhub-xcx/subpackageJourney` (master 7fe779ceb, 2026-11-12): WXML sections and order, WXSS states, page JS data and actions, and the copy in `Resources/Localizable.xcstrings`. I fixed the gaps in place.

This is a code-only change and nothing was compiled. `tools/generate_project.py`, `tools/check_scaffold.py` and `tools/check_design_lint.py` pass.

## Verdict per mini-program page

| Mini-program | Native (ui/mpmissing) | Verdict | Fixed in this pass |
|---|---|---|---|
| `pages/landing/index` | `App/JourneyLandingViews.swift` `JourneyLandingView` / `JourneyDuoView` / `JourneyModeTilesView` | **Matches** in sections, order, copy, states and interactions. **Except:** claim, gift claim and 查询领取结果 are behind `MPCommerceGate.claimsEnabled = false` (the mpmissing policy), so they show a gate note instead of a live CTA. | 先逛逛 was never shown: no route passed `onBrowse`. The host now defaults to the Home tab through `rootTabSwitch` (and dismisses), as `wx.switchTab('/pages/index/index')` does. The duo now has the `jl-ring` breathing: both ends pulse every 2.4 s, half a beat apart, with no ring under Reduce Motion. |
| `pages/seats/index` (开局大厅) | `JourneySeatsView` / `JourneyInviteSheet` | **Matches.** Head, play-as row with 编辑, 一起玩的人 N/M with 邀请, seat circles, 怎么玩 (2 or more seats), 去起点, the invited list with 撤回 + confirm, the invite sheet, and the loading / missing / denied / error states are all present. | The lobby mode tiles drew radio dots; `lb-tile` has none. Added `JourneyModeTilesView.selectable`, which is off in the lobby. Seat styling now follows `seats/index.wxss`: `is-me` ring, `is-invited` dashed brand border with the number, `is-off` (expired) at 0.45 opacity. |
| `pages/promo/index` (邀请与收益) | `JourneyPromoView` | **Matches** and is read-only with no withdraw button (payout-off note). | `hasRecords` now follows the mini-program (allocations or deals), so links alone still show 暂无可核实记录. 退款 now shows only when the count is above 0 (`item.refunded ? …`). |
| `pages/report/index` (本局战报 / 主题记录) | `App/JourneyReportViews.swift` `JourneyReportView` / `JourneyMemoryTimeline` | **Matches.** Eyebrow, result pill, three stats, 名次 → board sheet, 提示扣减, 主题背包, 本局回忆 timeline sheet, 同行席位, 节点 list, finished 结算 + 分享 / in-progress 刷新结果, and all six states are present. | Mount: there was no entry point. `PlayExperienceView` 结果 now shows "本局战报" for a completed run when `mpParity.journeyReport` is bound; the run scope is the topic id and name, plus the activity id for activity scopes. |
| `pages/settle/index` (结算) | `JourneySettleView` / `JourneyShareCard` | **Matches.** Four-step dots, in-flow back, overview (trophy, kicker, theme, 本关第 N 名, score count-up, 节点), board panel, rate (stars, six tags, 500-character field, 先选星级 / 写一句再提交 / server error, 谢谢 modal → 去分享), share (帖文 / 故事 card, 分享 + 完成), and all states are present. | The board step title now falls back to 本关 (`topicName || '本关'`); it was empty. Added the second sparkle (`st-spk--b`, staggered 0.9 s / 1.1 s). |
| `components/rank-board` | `JourneyRankBoardView` | **Matches.** Scope tabs + 更多 sheet, laurel hero with roll and 前 N%, team stats, 累计 / 本周 (hidden on team scopes), basis/window header, rows, unattributed note, and the loading / refresh / error / empty (team wording) states are present. | Light haptic when the rank roll lands (M13), not under Reduce Motion. |
| `components/cy-illus`, `images/laurel.svg` | SF Symbols (trophy / sparkles / rosette / envelope / laurel) inside the views above | **Matches in intent**: same objects and the same single light source. The layered PNG art is not ported. | — |
| `utils/journey-view.js`, `join-view.js`, `lobby-view.js`, `share-card.js` | Display shapes + binding stubs (`JourneyLandingBinding`, `JourneySeatsBinding`, `JourneyPromoBinding`, `JourneyReportBinding`, `JourneySettleBinding`) | **Logic belongs to Cursor.** The projections must fill the content structs. | — |

## Mount points

- Report: play finish (`App/PlayExperienceView.swift`). It links on to settle and seats through `mpParityRouteDestination`.
- Seats: ticket detail (`App/TicketWalletDetailView.swift`, "同行席位"), the same as the mini-program order detail `goSeats`. The wallet id is the registration id.
- Promo: Account (`App/MPParityAccountLinks.swift`, already on mpmissing).
- Landing: **not mounted yet.** `MPParityRoute` parses `subpackageJourney/pages/landing/index?k&t&aid&tid`, but `Core/CheinDeepLink` rejects queries and no intake routes to it.
- Every entry is hidden while its `mpParity` binding is nil.

## Copy

New keys in `Resources/Localizable.xcstrings`, inserted textually so the rest of the file is unchanged: `mp.settle.thisStage` (本关 / This stage), `mp.entry.journeyReport` (本局战报 / Run report), `mp.entry.journeySeats` (同行席位 / Companion seats). The existing copy already matched the mini-program wording.

## Needs logic / owner (Cursor)

1. Fill the five journey bindings in `MPParityBindings` (`PWaveReader` referral/gift landing, choices → tiles, seats, battle report, P8 memory, P9 boards, P2 affiliate, `/api/user/info`, `/api/topic/info-to-user`, `/api/comment/add`, referral issue). Settle's board must use the settle preset: tabs 全体 / 队内 only, no 更多.
2. Landing deep-link intake: route `MPParityRoute` from `AppSession.receiveCheinURL` / universal links into a root `mpParityRouteDestination`.
3. Seat invite and cancel writes (Core `writesNotAvailable`), saving the request id and re-querying with the same id.
4. Owner decision: seat claim (同行席位) is not a purchase or a virtual good, but it sits behind the same `claimsEnabled` gate as gift claims. The mini-program offers it live.
5. Report share: the mini-program issues the referral only when 分享 is tapped. `shareURL` is precomputed, so the binding should issue it lazily or fall back to the public theme link.

Mini-program screenshots were not used or shared.
