# CB285 page-ready — `subpackageMember/orient-score/index`

本局定向计分与成绩核对. Native screen `App/OrientScoreView.swift`. Map status on `rc/20261108` stays `partial`.

Base `rc/20261108` `e8299803711abd007e33731bdd534c40d6536ea2`. Branch `cursor/cb285`. Core and tests only. Views, `docs/release/ui-strings-*.json`, `Resources/Localizable.xcstrings`, the Xcode project, and `tools/current_ci_manifest.json` were not edited. No route was added and none was marked live. `api/orient/scoring/session/{}` was already `live-in-production` in `ChinaReviewedRouteCapability`. Appeal, dispute, sync, and settle stay off this screen. `WelcomeView.showsMerchantChoice` stays `false`. `ReleaseMoneyWriteSwitch` is unchanged.

This machine has no Swift toolchain. `xcodebuild` was not run. No XCTest run and no Xcode Cloud result is claimed. Existing tests were not deleted or weakened.

## What rc already had

- `OrientSessionService.score` reads `api/orient/scoring/session/{id}` into `OrientSessionScore`. The strict decoder still requires a literal integer (or an exact numeric string via `orientInt`) for `totalCenti` and each dimension. That decoder was not changed.
- `OrientScoreLoadState` is `loading`, `empty`, `failed`, and `ready`. `OrientScoreModel` lives in the view file and was not edited. A loader result of `nil` is empty. A throw is `failed`. A decoded score is `ready` through `OrientScorePresentation.summary`.
- `OrientScoreFormat.centi(0)` is `"0.00"`. `OrientScorePresentationTests` and `OrientScoreModelLoadTests` still lock that path.
- `OrientScoreReviewModel` validates an appeal or dispute and sends nothing when `OrientScoreReviewFactory.makeSubmitter` is nil. The factory is still nil. The review section is still not embedded.

## What this pass adds

`OrientScorePage` classifies the same score payload. A missing client capability stays hidden (`phase == nil`). It does not open a session and it does not register a path.

| State | When |
|---|---|
| `loading` | A read is in flight and no payload is kept. |
| `empty` | The caller has no round (`roundPresent == false`), or the payload is an empty object. Not an error and not a zero score. |
| `error` | The read failed. |
| `unknown` | Null, a bare `0`, the string `UNKNOWN` or `"0"`, an empty array, a session id that is not a JSON integer greater than 0. |
| `ready` | `sessionId` is a JSON integer greater than 0. Unknown numbers inside that object are an em dash. |

Unknown scores use `—` (U+2014). That covers `UNKNOWN`, null, a missing number, a numeric string, a bool, a fraction, and an object. They are not stored as 0 and they are not shown as `0` or `0.00`.

A JSON integer 0 score stays the existing centi zero `0.00` (`OrientScoreFormat.centi`). A JSON integer 0 for points or explore XP stays `0`. A negative integer stays negative (`-300` centi is `-3.00`). A missing running total is not the sum of the delta. A missing settlement stays `.absent`, not 0 points. The string `UNKNOWN` for settlement stays `.unknown`.

`facts(from:)` projects a score the strict decoder already accepted, so a literal integer payload matches `OrientScorePresentation.summary`. The raw bind does not copy a numeric string that `orientInt` would coerce to 0. `totalCenti: "0"` still decodes as integer 0 on `OrientSessionScore`, and the page shows `—` for that field.

## Missing catalog keys

`OrientScoreView`, `OrientScoreReviewSection`, `OrientScorePresentation`, and `OrientScoreReviewModel` pass these strings through `W8Text.t`. None of them is a key in `Resources/Localizable.xcstrings`, and no catalog entry has both this Chinese sentence and this English sentence. The catalog was not edited. The key column names the gap. The code does not look these keys up.

| Key | zh-Hans | EN |
|---|---|---|
| `orientScore.title` | 本局计分 | Round score |
| `orientScore.loading` | 计分加载中 | Loading score |
| `orientScore.empty.title` | 没有可查看的本人对局 | No round of yours to show |
| `orientScore.empty.detail` | 参加一场定向后，成绩会显示在这里。 | Scores appear here after you play an orienteering round. |
| `orientScore.error.title` | 计分加载失败 | Couldn't load the score |
| `orientScore.error.retry` | 重新读取 | Try again |
| `orientScore.appeals` | 计分申诉 | Score appeals |
| `orientScore.appeals.empty` | 暂无计分申诉 | No score appeals |
| `orientScore.disputes` | 成绩争议 | Score disputes |
| `orientScore.disputes.empty` | 暂无成绩争议 | No score disputes |
| `orientScore.readOnly` | 申诉、争议和结算暂时只能在对局记录中提交；这里只显示结果，不会替你提交。 | Appeals, disputes and settlement can only be submitted from the round record for now. This screen only shows results and never submits for you. |
| `orientScore.precision` | 计分精确到 0.01 分；积分与探索值以结算结果为准。 | Scores are exact to 0.01. Points and explore XP follow the settlement result. |
| `orientScore.breakdown` | 得分构成 | Score breakdown |
| `orientScore.settlement` | 结算结果 | Settlement |
| `orientScore.settled` | 本局已结算 · \(settlement.total) | Settled · \(settlement.total) |
| `orientScore.rewards` | 积分 \(settlement.points) · 探索值 \(settlement.xp) | Points \(settlement.points) · Explore XP \(settlement.xp) |
| `orientScore.timeline` | 计分时间线 | Score timeline |
| `orientScore.timeline.empty` | 还没有计分记录 | No score entries yet |
| `orientScore.running` | 累计 \(row.running) | Running total \(row.running) |
| `orientScore.reverses` | 冲正原流水 \(reversed) | Reverses entry \(reversed) |
| `orientScore.appealPending` | 申诉待处理 | Appeal pending |
| `orientScore.appealPending.spoken` | ，申诉待处理 | , appeal pending |
| `orientScore.resolution` | 处理说明：\(note) | Resolution note: \(note) |
| `orientScore.review.kind` | 类型 | Type |
| `orientScore.review.appeal` | 计分申诉 | Score appeal |
| `orientScore.review.dispute` | 成绩争议 | Score dispute |
| `orientScore.review.reason` | 说明理由（最多 500 字） | Explain why (up to 500 characters) |
| `orientScore.review.begin` | 提交前确认 | Review before sending |
| `orientScore.review.confirmTitle` | 确认提交？ | Send this? |
| `orientScore.review.send` | 确认提交 | Send |
| `orientScore.review.submitted` | 已提交，等待服务器处理 | Sent. The server will review it. |
| `orientScore.review.unavailable` | 暂未开放：申诉和争议暂时只能在对局记录中提交。 | Not available yet: appeals and disputes can only be sent from the round record for now. |
| `orientScore.timeline.spoken` | \(dimension) \(delta)，累计 \(running) | \(dimension) \(delta), running total \(running) |
| `orientScore.unsettled` | 本局尚未结算，暂不能确认积分或探索值到账。 | This round is not settled yet, so points and explore XP are not confirmed. |
| `orientScore.settledCorrection` | 结算后冲正只影响展示分，不追发或追扣本局奖励。 | Corrections after settlement only change the displayed score; they do not grant or claw back this round's rewards. |
| `orientScore.dimension.puzzle` | 解谜 | Puzzles |
| `orientScore.dimension.bonus` | 奖励 | Bonus |
| `orientScore.dimension.penalty` | 处罚 | Penalty |
| `orientScore.dimension.adjustment` | 调整 | Adjustment |
| `orientScore.phase.disqualified` | 已取消资格 | Disqualified |
| `orientScore.phase.ended` | 对局已结束 | Round ended |
| `orientScore.phase.progress` | 对局进行中 | Round in progress |
| `orientScore.review.accepted` | 已采纳 | Accepted |
| `orientScore.total.spoken` | 本局总分 \(total) 分 | Round total \(total) points |
| `orientScore.signIn` | 请登录本人账号查看对局 | Sign in to your own account to view this round. |
| `orientScore.error.detail` | 计分暂时无法读取，请稍后重试。 | The score can't be loaded right now. Please try again. |
| `orientScore.review.reasonInvalid` | 请填写 1 到 500 字的理由 | Enter a reason of 1 to 500 characters |

These pairs already exist on other keys. This screen still uses the literal, not the key: 取消 / Cancel (`action.cancel`), 任务 / Tasks (`playx.backpack.tab.game`), 待处理 / Pending, 已驳回 / Rejected, 状态待确认 / Status unconfirmed. Nearby keys that are not these sentences: 重新读取 is `club.ops.readBack` and others, while Try again is `closew5d.state.retry` and others. Settlement is `publisherPricing.settlement` and `wallet.fundStages`. Accepted is `club.inviteFeedback.status.1` and others. Adjustment is `merchant.settlementEntry.adjustment`.

`orientScore.loading`, `orientScore.empty`, `orientScore.error`, and `orientScore.total` in `docs/release/cb99-accessibility-ids.md` are accessibility identifiers, not catalog keys.

## Tests

Existing assertions were left in place.

- `OrientScorePageReadyTests.testMissingCapabilityStaysHiddenAndDoesNotInventARoute`
- `OrientScorePageReadyTests.testLoadingEmptyErrorAndUnknownStayDistinct`
- `OrientScorePageReadyTests.testLiteralIntegerScoreMatchesTheExistingSummaryIncludingZero` — a decoded integer payload matches `summary`, including total `0.00`, dimension `0.00`, and points `0`.
- `OrientScorePageReadyTests.testUnknownScoresAreAnEmDashAndAreNotStoredAsZero` — null, `UNKNOWN`, numeric strings, a fraction, and a nested object are `—`. `OrientSessionScore` still decodes `totalCenti: "0"` as integer 0. The page does not show that coerced 0. A missing running total is not summed from the delta.

Not executed. `swift` and `xcodebuild` are not on this machine.

## Left

- `OrientScoreView` still switches on `OrientScoreLoadState` and `OrientScorePresentation.summary`. It does not read `OrientScorePage`. A numeric string that survives `orientInt` still becomes a centi zero on that path. A missing dimension is omitted there, and `timelineRow` still accepts an exact numeric-string entry id.
- The empty, error, and unknown phases are model-only until a view binds them.
- The screen is still constructed only from its previews. Navigation stays unwired. The page-map row stays `partial`.
- The keys in the table above are absent from the catalog.
- `OrientScoreReviewFactory.makeSubmitter` stays nil. `OrientScoreReviewSection` stays unembedded. Sync and settle stay unoffered here.
- No simulator pass and no `xcodebuild`.
