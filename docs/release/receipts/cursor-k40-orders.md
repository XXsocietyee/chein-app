# K40 · orders, tickets, wallet, refunds (`cursor/1128-k40-orders`)

Rechecked the orders / tickets / wallet / refund rows in `docs/briefs/round3-1127.md` and `origin/audit/1128-{functions,plan,ada}`. Base pin `a7c956335` (still the tip of `origin/ui/combined-r7` at push). Money switches were not moved. `PlayerLaunch.merchantCenterEnabled` stays off in Release. `AppSession.swift` stays 7977 lines. Play init order stays devices, sensors, artworkHosts.

Counts: **30** rows rechecked, **18** already fixed, **2** kept because the mini program does not have them, **1** closed here, **9** owner-only because a money switch would have to move.

## Closed here

| Row | What the player can do now | Proof |
|---|---|---|
| Planning G-09 entry QR (MP `signup/index.js` V-02, `QR_REFRESH_LEAD_MS` 30s, `QR_RETRY_MS` 5s) | While the ticket code is on screen it renews 30s before expiry. The current code stays up during the request and after a failed renew until the last 5s. A dead code, a failed renew inside that window, or an ended registration does not mint another code. A scanned chapter (registration still active) still renews. The open pass re-reads on the same 30s lead, so a merchant scan can flip the chip from ready to verified. The ticket face no longer shows a countdown; the city voucher still does. | `Core/VerificationCodePresentation.swift` `TicketEntryCodeRefresh`, `renewTicket`. `Tests/CoreTests/VerificationCodePresentationTests.swift` (`testTicketRenewsSilentlyThirtySecondsBeforeExpiry`, `testTicketRenewKeepsAScannedChapterAndStopsWhenRegistrationEnds`, `testTicketRenewFailureKeepsTheCodeThenStopsInsideFiveSeconds`, `testTicketRefreshScheduleMatchesTheMiniProgramLead`). Clock-skew test still proves a jump past expiry does not issue. `App/TicketPassSheet.swift` sleeps `TicketEntryCodeRefresh.leadSeconds`. |

No backend change. `api/verify/dyncode/issue` and `api/registration/info` are the same routes. Nothing here 404s.

## Already fixed, or kept because the mini program does it

| Row | Verdict |
|---|---|
| O-01 / gap #28 order state vs `utils/order-status.js` | Already ported @`7270c627f`. `showsUnusedPass` uses `serverNow` @`4279642dd`. |
| O-02 orders reload after cancel / cancel-refund | Sheet `onDismiss` reloads page 1 @`7270c627f`. |
| G-01a activity detail after a free registration | Sheet dismiss re-reads the detail @`7270c627f`. |
| G-04 refunded / cancelled order links back to sessions, no rebooking | @`ee49714c9`. `OrderLifecycleTests` asserts `reorderActivityID`. |
| T-04 wallet 我的队伍 opens the team page | @`b7aa64a86` (`ticketTeam.manage`). The roster list stays read-only. |
| O-06 ticket wallet states, session time, entry QR | List and `dyncode/issue` already on. Pass-card rows @`27099b8ae`. |
| O-08 withdrawal contact (WeChat id + Copy, no payout request) | Bundled reader @`56a76d956`. No withdrawal write. |
| O-15 coupons, O-18 points ledger, O-23 support from an order | Reads already on in the Release composition (K13 receipt). |
| P1-2 pay result confirmed by one registration read | @`17c574000`. The pay itself stays behind the empty approval list. |
| P1-4 pinned 审核支付 | Removed @`17c574000`. The pinned button is cancel / refund. |
| Order list, detail, unpaid cancel, paid cancel-refund | Reads work. `allowsReviewedCancellationAndRefund` is already true. Not flipped here. |
| Pay channel `.app` (`/api/registration/pay/app`) | @`eea73b432`. Approvals stay `[]`. |
| Order re-pay Pay-with row, `devicePaymentApproved` | @`1d05b0d90`. `externalCheckoutApproved` stays false. `approvals` stays `[]`. |
| Ticket-wallet error is one `ContentUnavailableView` | @`64748a2c2` (handoff `e4-tickets-error`). |
| ADA e4-tickets pass card (cover, perforation) | @`27099b8ae`. Upcoming / Past stays out: the mini program has one list. |
| ADA e4-wallet-balance CN¥ / ¥ and dates | Shared `LocaleDisplay.money` @`0c1782ffb`. |
| ADA t5-order-center lookup form | The page is the order list with `.searchable` @`0c6c4ab9e`. |
| Order detail shows used / verified | `verificationStatus == 1` is `.completed` / "verified" on the summary and the timeline (`Core/OrderLifecycleContracts.swift`). Profile rows use `profile.orders.verified`. |
| O-03 hide participation a week after it ends | Kept. The mini program does not do this either. |
| O-04 host card and a refund-rules table | Kept. The mini program is one organizer line plus prose. |

## Owner-only (a money switch would have to move)

These stay off. Turning them on means changing `approvals`, `externalCheckoutApproved`, a payment lease, or a backend money-write refusal.

| Row | Why it stays |
|---|---|
| P0-1 paid registration | The create lease still rejects a positive amount. The sheet stays on free registration. |
| P0-2 WeChat Pay end to end | Params are handed to the adapter when a provider exists. Release order `approvals` is still `[]`, so no provider is built. |
| P0-3 Stripe / Apple Pay wire | The request is not sent while checkout is unapproved. The backend still binds form `id`, not the JSON body. |
| P0-4 Alipay app pay | No caller, and checkout is unapproved. |
| P1-3 route pay by the quote currency | Same unpaid checkout. |
| P1-6 / G-08b bundle refund and transfer | The backend throws `moneyWriteDisabled` on every write. Not a 404. |
| P2-1 / G-06 / G-08a self-play and pass purchase | `selfPlayExternalCheckoutApproved` and the pass pay caller stay off. |
| Gap #9 / O-05 / O-07 re-pay and new pay | Needs the empty `approvals` list filled and `externalCheckoutApproved` set. `devicePaymentApproved` is already true and was left true. |
| G-02 waitlist through offer → pay → ticket | Join can be built, but the offer opens pay, which is the same empty approval list. |

## Gates

`python3 tools/check_scaffold.py` PASS (appsession ratchet PASS, 7977 lines).
`python3 tools/check_a11y_lint.py` PASS (0 new).
`python3 tools/contract_ratchet.py --check` 46 failing, baseline 46, new 0, fixed 0.
`python3 -m unittest Tests.ContractChecks.test_verification_code_presentation` OK.
`swiftc` and `swift test` are not on this machine. The new cases are in `Tests/CoreTests`.
`tools/current_ci.py check` already fails on `a7c956335`: the committed ledger's file hashes do not match the tree (replacement reviews still pin older hashes). The ledger was not rewritten.

No secrets, no deploy, no executed SQL. Merchant center was not turned on.
