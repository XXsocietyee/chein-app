# fix/1128b-team-reg — team + registration + orders, second wave (receipt)

Base: `origin/ui/combined-r7` @ `3348aa51f` (it already has the first-wave `fix/1128-team`).
Plan: `origin/audit/1128-plan:docs/audits/1128-plan.md` gaps **#6, #7, #8, #9, #17, #28** (teamreg + mine domain tables).
MP behaviour reference: `chengyinhub-xcx` (`utils/team-event-command.js`, `pages/team/detail`, `subpackageRoam/nearby`,
`pages/activity/baoming`, `pages/roam` `verifyEventArrival`, `utils/order-status.js`, `utils/order-actual-pay.js`).
Backend: hengyin `origin/us/r3-functional` (`ApiPlayTeamController` + `TeamEventCommandService`, `ApiClubEventOpsController`,
`ApiOfficialEventController`).

There is no Swift compiler in this environment. The Swift tests below are written but have **not been run**. The Python
gates were run (see the end of this file). Merchant routes stay off: every new lease is player / club only, and each test
checks that a `merchant` context gets nil.

Each gap has a Release-composition proof in `Tests/AppUnitTests/Fix1128bTeamRegCompositionTests.swift`. Each one builds
`RegionalLaunchConfiguration.shippedComposition` (the reviewed CN deployment) and asserts that the approval or service is
non-nil and admits the exact paths, through the real composition firewall where a request is sent.

## #6 — Team writes go through `/api/team/command` (S1) → closed

| Step | Evidence |
|---|---|
| Join / quit / kick / disband / join-mode are sent by `TeamCommandWriter` to `api/team/command`, the route the Release player lease already admits. The body is the MP one: `{payload…, targetId, action, requestId}`, ids as strings, `joinMode` 1/2. Create keeps `api/team/create` | `Core/TeamHTTPService.swift` `submit` / `commandFields`; `TeamCommandWriter.commandBody` (unchanged MP order) |
| The command `requestId` is the team journal's operation UUID (32 hex). The recovery card adopts it (`adopt(key:requestID:)`), so 查询原请求 / 按原输入重试 / 终止 address the request that was really sent | `TeamCommandWriter.requestID(for:)`, `App/TeamHomeView.swift` recovery buttons |
| The writer now sends the viewer's `Authorization`. The composition firewall (`acceptsPlayerWrite` → `teamRequestID`) refused every unsigned command, so the first-wave recovery card could never reach the server | `TeamCommandWriter.init(…, context:)`, `submitReceipt(…, token:)`, `settle` |
| Release composition: `composition.teamWrites(context, transport:)` gives both the command writer (player grant) and the first-wave direct-route lease (fallback). `makeTeamCoordinator` uses it. AppSession line count is unchanged | `App/TeamMembershipWriteComposition.swift`, `App/AppSession.swift:5343`, `App/AppCompositionRoot.swift` `teamCommandWriter` |
| After APPLIED, the existing `readBackConfirmedWrite` re-reads `/api/team/info` (kick / join-mode). Quit / disband retire the team and return. Join opens 查看队伍 | `Core/TeamCoordinator.swift` (unchanged path) |

## #7 — `data.state` decoded; REJECTED is not success (S2) → closed

- `TeamCommandWriter.submit` / `submitReceipt` read the receipt. Only `data.state == APPLIED` returns `.applied`. `REJECTED`
  carries the server `message` / `errorCode`. `CANCELLED` is terminal. `UNKNOWN`, a missing receipt, transport failure and 5xx
  keep the saved id. A 2xx with `code != 200` (a `ServiceException` such as 原请求号与输入不一致) is a terminal rejection
  (`Core/TeamHTTPService.swift` `TeamCommandReceipt.decode`).
- `TeamHTTPService.decodeCommand`: REJECTED with text → new `TeamWriteOutcome.rejectedMessage(errorCode:message:)`. The
  coordinator clears the journal, keeps the team / row, sets `rejectionMessage`, and `TeamNotice` shows the server text as is
  (MP shows the receipt message next to the button). `TICKET_REQUIRED` and other machine codes still drive the 去购票 CTA.
- `NearbyTeamService.decodeWrite` (附近组队 approve / reject → `api/team/command` handle): APPLIED → acknowledged,
  REJECTED → `.rejected(errorCode, message)`, so the coordinator keeps the applicant row unless the error effect drops it.
  UNKNOWN or a receipt-less 200 → `.unknown`, and the dispatch lock is kept. Direct routes (`/apply`, `/withdraw`) are unchanged.

## #8 — Player waitlist on in Release (S1) → closed

- Deviation from the gap text, as the planning audit's own fix recommended: Release does **not** fabricate a per-activity
  `RegistrationProductionApproval`. That type also needs a ticket list, consent version, notice URL and expiry, and when issued it
  switches the whole create path to `RegistrationProductionService` on a raw `URLSessionTransport`, which bypasses the
  composition firewall. Instead the player write grant now issues a waitlist lease (`AppCompositionRoot.registrationWaitlistApproval`):
  exactly `RegistrationProductionApproval.waitlistPaths` = `api/club/event-ops/waitlist/{status,join,cancel}`.
- `Core/RegistrationWaitlistLeaseService.swift`: scoped to the one activity the sheet opened. It sends `{activityId, ticketId}`
  (`ApiClubEventOpsController` `ClubWaitlistRequest`) through the composition transport. Each join or cancel first does a fresh
  status read (`canJoin` / `canCancel`) and ends with an authoritative status read that must reconcile. Only that read-back is
  returned.
- `AppSession.registrationWaitlistService(activityID:)` falls back to this lease (same line count). The firewall admits only
  the exact two-integer JSON body (`ReviewedProductionFormMutationRoute.waitlistScopeBody`).
- An offer (`OFFERED` + token) → 查看候补名额 → quote → the existing pay step (unchanged flow). Any registration read-back
  (create applied, pay settled, durable status) now calls `onReadback` → `session.refreshTicketWallet()`. That moves the wallet
  reader scope, so every wallet view keyed by `scope` reads `/api/registration/my` again.

## #9 — Release order config and the "Pay with" row on re-pay (S1) → closed

- `sessionDependencies`: `devicePaymentApproved: true`. The WeChat SDK path stays gated by its own build flag
  (`QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED` / `WeChatPaymentBuildSettings`), and the pay routes stay behind `ReleaseMoneyWriteSwitch`
  in the firewall. `externalCheckoutApproved` stays false: the old review-sheet 审核支付 stays hidden (P1-4). Re-pay runs
  through `RegistrationPaySection`. Order approvals: `allowsReviewedCancellationAndRefund: true` issues the cancel / cancel-refund
  approval per reviewed order. A static per-order payment approval cannot exist (each one needs that order's signup document).
- `App/OrderRepaySection.swift` (used by `OrderLifecycleView`). A USD order gets the same `RegistrationPayMethodSection` picker
  (Apple Pay / Card, narrowed to the order's `paymentChannels`), and the Stripe rows follow that choice. A CNY order keeps the
  pay section's own WeChat Pay row and the `RegistrationPayStepMethodRow` picker while Alipay is offered. A server-confirmed
  paid read reloads the order.
- Contract check updated: `test_cb97_payment_gating.py` now pins `devicePaymentApproved: true` (comment cites gap #9).

## #17 — Official participation actions (S2) → closed

- `sessionDependencies` now passes `officialActionApproval: officialPlayerActions(context)`, which is
  `OfficialActionProductionApproval(playerMarket:endpoints:reviewedPolicyVersion:)` for player / club (merchant nil).
- The grant admits the participation commands on any server target: v1 `events/{id}/signup` and `/complete`, v2
  `events/{id}/arrivals`, inbox `v2/parties/{id}/ACCEPT|DECLINE|WITHDRAW`, organizer `v2/organizer-invites/{id}/accept|decline`.
  Publish, broadcast and merchant invites stay exact-command only. Exact grants still cannot carry an arrival (the existing
  test is kept).
- Arrival reads `api/official/events/{id}` before the write (the mission must still be open) and after it. An arrival answer
  (the server's accepted / completed verdict, idempotent by `requestId`) releases the event lock, so the next mission can be
  verified. A party the inbox shows with a new status releases its lock; an absent party stays locked.
- `OfficialActionProductionFactory(approvalSource:)` reads the approval on every use. The coordinator is retained, and a
  coordinator built before sign-in used to keep the nil grant forever.
- The firewall admits only the exact bodies `OfficialActionService.request` sends
  (`ReviewedProductionFormMutationRoute.officialParticipationDecision`).
- Contract checks updated: `test_official_action_contracts.py` and `test_official_action_production.py` (comments cite gap #17).

## #28 — Orders: MP state rules, reload on dismiss, activity refresh (S2) → closed

- `Core/ProfileOrderHistoryFilter.swift` `historyState` is `summarizeOrderState` rule by rule, in the MP order:
  1. paid-out refund (payout 1 / 4)
  2. 人工售后
  3. live refund (zero amount and rejected fall through)
  4. 活动已取消 (`cmsActivity.cancelTime`)
  5. registration status 1 / 3 / 4 / other
  6. an active `exploreProgress` (未开始 before the start, else 进行中)
  7. verified
  8. `topicCompleted`
  9. a paid first scan (never for a self-play pass)
  10. 不可退款 (never for a pass or a free order)
  11. ended (a pass by `expiresAt`; a date-only end covers the whole day, `endOf` + 86 399 999 ms)
  12. not started
  13. unused pass (可使用)
  14. 进行中

  When the read carries `serverNow`, it wins over the device clock (U-033). New facts are decoded in `ProfileOrderHistoryFacts`.
- Table-driven test: `ProfileOrderHistoryFilterTests.testOrderStatusJSRuleTable` (28 rows) plus
  `testServerNowWinsOverTheDeviceClock`. Two older assertions that pinned the previous rules were updated with gap comments:
  manual-over-refunded, and pass first scan = completed (the MP rule says in progress). `test_profile_order_filters.py` was
  updated the same way.
- `ProfileOrdersView`: the order card sheet's `onDismiss` bumps `profileReadReloadToken`, and `ProfileReadScreen` reads again
  while keeping its rows (MP `orderchanged`). New env key in `App/ProfileReadReload.swift`.
- `ActivityDetailView`: closing the registration sheet re-reads the detail (G-01a), so the footer and counts follow the new ticket.

## Files

New: `App/OrderRepaySection.swift`, `App/ProfileReadReload.swift`, `App/RegistrationWaitlistComposition.swift`,
`Core/RegistrationWaitlistLeaseService.swift`, `Tests/AppUnitTests/Fix1128bTeamRegCompositionTests.swift`,
`Tests/CoreTests/OfficialPlayerTargetApprovalTests.swift`.
Changed: `App/{AppCompositionRoot,AppSession,ActivityDetailView,OrderLifecycleView,ProfileOrdersView,ProfileReadScreen,
ReviewedPlayerWriteLeases,SessionRegistrationSheet,TeamComponents,TeamHomeView,TeamMembershipWriteComposition}.swift`,
`Core/{NearbyTeamService,OfficialActionCoordinator,OfficialActionProduction,ProfileOrderHistoryFilter,TeamCoordinator,
TeamHTTPService,TeamService,TicketWalletReading}.swift`, tests `Tests/CoreTests/{NearbyTeamHTTPWriteTests,TeamCommandWriterTests,
ProfileOrderHistoryFilterTests}.swift`, contract checks `test_operation_http_adapters.py`, `test_cb97_payment_gating.py`,
`test_official_action_contracts.py`, `test_official_action_production.py`, `test_profile_order_filters.py`,
`tools/check_nearby_write_repair.py` (each updated pin cites its gap). `AppSession.swift` and `AppCompositionRoot.swift` did
not grow.

## Tests (authored; Swift NOT_RUN)

- `Fix1128bTeamRegCompositionTests`: #6 command writer composed and admitted (APPLIED and REJECTED via the firewall),
  signed-out nil; #8 waitlist lease = 3 paths, merchant nil, join = status → join → status through the firewall,
  other-activity scope never sends, exact-body firewall; #9 device payment and reviewed order actions on, external checkout
  off; #17 `officialActionApproval` non-nil with every template, merchant nil, arrivals / complete pass the firewall,
  exact participation bodies.
- Core: `TeamCommandReceiptTests` (REJECTED message, UNKNOWN keeps the id, `code != 200`, seeded id = journal operation,
  adopt, service mapping and MP command fields), `NearbyTeamHTTPWriteTests.testHandleCommandStateRejectedAndUnknownAreNotSuccess`,
  `OfficialPlayerTargetApprovalTests`, `ProfileOrderHistoryFilterTests` rule table.

## Strings

No new user-visible keys. The team rejection shows the server's own text verbatim; the "Pay with" picker reuses the existing
`RegistrationPayMethodSection` copy.

## Owner actions

- No new owner values. Device payment in Release still needs the existing `owner-values.md` items:
  `QUESTIFY_WECHAT_APP_ID`, `QUESTIFY_WECHAT_PAY_MERCHANT_ID`, the WechatOpenSDK binary and
  `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED = 1`. Until then the order page shows the "WeChat Pay can't open yet" footnote, never a
  dead button.
- Device check against the CN backend (no deploy from here): a captain kick that the server REJECTS (for example a member
  already left) shows the server text; a sold-out ticket joins the waitlist; a v2 arrival on roam; a cancel from the order card
  refreshes the list.

## Gates (run here)

- `python3 tools/generate_project.py` ✓
- `python3 tools/check_scaffold.py` ✓ (AppSession / AppCompositionRoot ratchet unchanged)
- `python3 tools/check_design_consistency.py` ✓
- `python3 tools/check_a11y_lint.py` ✓
- `python3 tools/contract_ratchet.py --check`: the full run on `7270c627f` reported 53 failing against a baseline of 52, with
  1 new: `test_rm02_registration_pay`, which pinned `RegistrationPaySection(` inside `OrderLifecycleView`. That pin was updated
  for gap #9 in `1102c7654`, and the test now passes on its own. The full ratchet was not re-run after that commit. The earlier
  new failures were fixed and re-run on their own: `check_nearby_write_repair`, `test_operation_http_adapters`,
  `test_official_action_*` and `test_profile_order_filters`.
