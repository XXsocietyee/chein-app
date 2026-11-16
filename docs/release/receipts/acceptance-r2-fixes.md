# Acceptance r2 fixes (rerun 2026-11-15, F-01..F-20)

Branch `ui/h-acceptance-r2` from `origin/ui/main` (`5a93b447`). Source report:
`origin/ui/h-acceptance:docs/release/receipts/acceptance/REPORT.md`.

**Not compiled.** Swift and Xcode are not installed in the environment that made these
fixes, so no XCTest below has run. Run the app-unit and core suites on a Mac, then rerun
acceptance flows 02, 03, 05, 06 and 08–11.

## Commits

| Commit | Defects |
|---|---|
| `915509cc` | F-08, F-09, F-10 |
| `c4de0262` | F-01, F-02, F-03 |
| `d288018c` | F-05 (Play) |
| `35bdda33` | F-12, F-13, F-14, F-16, F-17, F-18; Questify.xcodeproj regenerated |

## Defect → root cause → fix → test

| ID | Root cause | Fix | Tests |
|---|---|---|---|
| F-01 | `RegistrationUIFlow.confirmationBlock` (Core/RegistrationUIFlow.swift:150, :165) returns `.quoteUnavailable` for every quote that isn't fresh, refused ones included. The footer (App/RegistrationSheetView.swift `blockReason`) always rendered that as "正在核对价格…". The server refusal "该主题尚未开售…" only appeared off screen. | New `Core/RegistrationCheckoutQuotePhase.swift` (`RegistrationUIQuotePhase`, `RegistrationCheckoutFooterNotice`). The footer shows the server message and a 重新获取价格 retry (`registration.form.retryQuote`). | `Tests/CoreTests/AcceptanceR2SignupQuoteTests.swift` (7 tests) |
| F-02 | A `payment-readiness` answer of `ready:false` stayed private to `RegistrationPaymentReadinessSection` and never reached the footer. | `onResult` callback; the footer shows the readiness message (支付服务暂不可用). | same file: `testPaymentReadinessFalseIsNamedWithItsMessage`, `testQuoteRefusalOutranksPaymentReadiness…` |
| F-03 | `VerificationCodeReceipt.validatedCode` (Core/VerificationCodePresentation.swift) compared the server's absolute expiry with the device clock, with a 5 s tolerance. A server 7 s ahead made every code expired on arrival. | Expiry is now the issue time plus TTL on the device clock, within a ±120 s offset limit. A code never lives longer than the server TTL. | `Tests/CoreTests/AcceptanceR2TicketQRClockSkewTests.swift` (6 tests) |
| F-05 (Play) | `PlayExperienceCoordinator.review` (Core/PlayExperienceCoordinator.swift:428) refuses a stop whose advanced prerequisite isn't ready (station 1). The refusal went to a generic row at the bottom of the list, under the keyboard. The station screen read the raw `node.done` instead of `snapshot.isDone`. The stops list was the last section of the half-height panel. | New `Core/PlayReviewRefusal.swift`, which names every refusal (`playReview.refusal.*`, `Resources/PlayReviewRefusal.xcstrings`) and shows it inline (`playx.answer.refusal`), as a toast and as a top row (`playx.review.refusal`). Done state comes from `snapshot.isDone`. `PlayStationListPresentation` lists all visible stops right after the progress header. | `Tests/CoreTests/AcceptanceR2PlayAnswerTests.swift` (10 tests); also fixes the pre-existing contract failure `test_normal_result_host_survives_missing_node_during_readback` |
| F-08 | In App/ClubActionPanel.swift, the confirmation `.sheet` and `onDisappear { reset() }` were attached to the List `Section`, so they applied to every row. When the progress row disappeared, it reset the confirmation. | One sheet on the membership button (`club.action.confirm`). The lifecycle handlers are on the section header. | `Tests/ContractChecks/test_acceptance_r2_club_chat.py` (`AcceptanceR2ClubLeaveConfirmation`) |
| F-09 | App/ClubChatEntryView.swift passed `session.messagingReader`, which builds a new reader on every access. The history kept restarting and the composer stayed locked, so the typed text was dropped. | Keeps one reader (`SessionMessagingHomeReaderOwner`). `MessageComposerModel.acceptsTyping` no longer waits for the history to load. Send shows `message.send.receipt` on success, or `message.send.issue` with 重试 on failure. | `Tests/AppUnitTests/AcceptanceR2ClubChatComposerTests.swift` (5 tests); contract `AcceptanceR2ClubChatSend` |
| F-10 | The `ToolbarItemGroup(placement: .keyboard)` 完成 button in App/MessageActionComposer.swift showed as a floating pill over Send (club chat and DM). | Removed. The composer stays pinned with `.safeAreaInset(edge: .bottom)`. Send has no focus-based gating. | contract `AcceptanceR2ComposerKeyboard`; `ReferenceChatTaskFlowTests.testMessageKeyboardKeepsSendActionReachable` updated to tap Send with the keyboard up |
| F-12 | `AppCompositionRoot.growthNormalReadApproval` was always nil, so `GrowthNormalReadTransport` threw `notConfigured` before sending anything. | Composed through `ReviewedProductionGateLeases.growthNormalRead` (non-money reads; all reviewed builds). | `Tests/AppUnitTests/AcceptanceR2GateTests.swift` |
| F-13 | `WalletPayoutCapability.isOn = false` was hard-coded (App/WalletCommerceViews.swift:116). | Owner rule, money TEST-only: in DEBUG/TEST builds off the production host, `isOn` follows `ReleaseMoneyWriteSwitch.withdrawalEnabled`. **Release compiles `static let isOn = false`**, and `tools/check_release_preflight.py` pins it. Adds `wallet.assets.withdraw`. | `AcceptanceR2GateTests` (DEBUG+TEST host on; Release off; production host off; no host off) |
| F-14 | `ProjectEditCoordinator.canSubmit` needs the `api/topic/edit-requests/submit` route. The production route table refuses it (a real production gap), and the DEBUG e2e run is guarded as production. | `Core/TestHostOnlyRouteAdmission.swift` admits the 4 edit-request/publish-status routes only for a DEBUG `--e2e-test-host` run. It is a constant false in Release. | `Tests/CoreTests/AcceptanceR2TestHostRouteTests.swift` |
| F-15 | Creator activity quota | Backend or seed; no app change | — |
| F-16 | `api/merchant/dashboard`, `todo-summary` and `events` had no admission in `guardedSend` and fell through to `notConfigured`, which shows "这项功能还没开通". | `App/ReviewedMerchantWorkbenchReadRoute.swift` admits them for a signed-in merchant (exact-match, read-only). | `AcceptanceR2GateTests` (merchant admitted, player refused, body/token mismatches rejected) |
| F-17 | `payoutAccount.reload` existed only in the failed state. A successful or empty load had no reload. The entry exists (`merchant.payoutAccount.open`). | Reload row for the ready and empty states (`PayoutPageState.needsSeparateReload`). | `AcceptanceR2GateTests` |
| F-18 | A failed verify confirm ended in `.result` with no result, so the result area was blank and the outcome rows had no ids. | `NativeVerificationOutcome` with ids `verification.result.redeemed/rejected/choose/failed/message`. | `AcceptanceR2GateTests` |
| F-19 | Backend (hengyin `fix/registration-list-r3`, `qa/REGLIST-R3.md`) | — | — |
| F-20 | Env / coordination (TEST redeployed without notice) | — | — |

F-04, F-06, F-07 and F-11 were not in this task's scope.

## Open items and follow-ups

- **Paid sign-up still stops before Pay (needs an owner decision).** `RegistrationCoordinator.confirm`
  (Core/RegistrationCoordinator.swift:251) refuses any non-zero quote with `.blocked(.paymentRequired)`.
  `RegistrationUIFlow.confirm` ignores that result. Once the topic is on sale, 立即报名 on a paid
  ticket will do nothing visible. This is the "payment stays off" gate, so it was left alone.
- **Station 1 still won't submit in flow 03.** Node 992021 has an advanced prerequisite: the flow
  must complete `playx.advanced` first, or the seed must drop that section. It now shows a reason
  instead of nothing. The server sent `done:false` for this node, so the `player_node_progress`
  row is not reaching `/api/play/nodes` (backend/seed).
- **F-12 and F-16 are on in production too.** Both were unwired non-money reads already listed as
  live production routes. Money (F-13) and the production-gap routes (F-14) stay TEST/DEBUG only.
- **Flow follow-ups:** F-17, scroll up rather than down to `merchant.payoutAccount.open`. The tap
  landed on the adjacent 我主办的项目 row, and why that page stayed on its skeleton is not triaged.
  F-18, have the player issue a live dyncode and feed it to `verification.code`.
- **Not regenerated:** `tools/current_ci_manifest.json` still has the old hash of
  `App/NativeVerificationView.swift`.

## Checks

- `python3 -B tools/check_scaffold.py`: exit 0, before and after.
- `python3 -B tools/contract_ratchet.py --check`:
  - Before, on `origin/ui/main`: 185 failing, baseline 184, **1 new** (the pre-existing
    `test_play_task_outcome_journey…test_normal_result_host_survives_missing_node_during_readback`).
  - After: **184 failing, baseline 184, new 0**.
