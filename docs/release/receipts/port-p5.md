# Receipt: port package P5 (small contract fixes + owner rulings)

- Worker: Claude cloud agent (reassigned from Gemini by the owner, 2026-11-24; Gemini pushed nothing).
- Branch: `port/p5-contracts`, based on `origin/ui/combined-r6` (f1115875e).
- Sources: chengyin-ios `63dad0d7` (#155, verify-1119), `285bf132` (#164, ShopNPC), and branch `fix/owner-decisions-1122` (`01eb60ad`, `2504350d`).
- Brief: `design/handoff-r2:docs/briefs/port-p5-gemini.md`; plan `port/plan-r1:docs/port/ios-port-plan.md` §2.2 C7/C15, §4 P5, §5.

## Clusters done

| Item | What | Where |
|---|---|---|
| MC-055 | `ClubRecord.viewerCanGovern: Bool?`; `canGovern = viewerCanGovern ?? (isOwner \|\| viewerIsAdmin)`. A wrong type (e.g. `"true"`) throws, as in the source. `ClubGovernanceViews` already reads `canGovern`, so it needed no edit. | `Core/ClubContracts.swift` |
| FE-G5 | Entitlement `included` / `extraSpendText` / `reserveRequired`, all optional; a wrong type becomes nil. The row shows 已含, or the server's spend text, plus 需预约. | `Core/TicketWalletContracts.swift`, `App/TicketWalletDetailView.swift` |
| FE-G6 | `TicketWalletEntitlement.displayStatusLabel`: an empty or blank `statusLabel` falls back to the local status name, so the row is no longer blank (was `TicketWalletDetailView.swift:317`). | same |
| PG-006 | `comment/add` sends `request_id` (16–64 chars from `[A-Za-z0-9_-]`). The coordinator creates one per draft and reuses it when the same draft is sent again; an edited draft gets a new one; it is cleared on acknowledgement. Unknown outcomes stay locked, as before. | `Core/ContextualReviews.swift` |
| OR-023 | `IMConversationTitlePolicy.usesAssistantTitle(_:)`: a type 2 conversation is always titled 城瘾小助手 (`messaging.system`). Inbox search uses it now. The reply notice copy becomes 「城瘾小助手不接收回复」 through `p5.json`. | `Core/IMConversationReplyPolicy.swift`, `App/MessagingHomeView.swift`, strings |
| C15 ShopNPC | On retry, the two request bodies are compared as decoded JSON, not as bytes (dictionary key order is not stable). | `Tests/CoreTests/ShopNPCModernOutcomeTests.swift` |
| Owner ruling: money | There is now ONE shared `MoneyDisplay` (`Core/RegistrationUIForm.swift`) behind ONE switch, `MoneyDisplay.current`. **It defaults to `.twoDecimals`, today's behaviour**, because the owner has not confirmed the rule (plan §7 Q3). Setting `.oneDecimal` gives the 11-22 rule: ¥39.0 and ¥29.9, but two places when the second is non-zero (¥0.01, ¥12.35). `RegistrationUIMoney` reads the switch. | `Core/RegistrationUIForm.swift` |
| Owner ruling: V-23 | `ClubActivityReportExposure.playerEntryVisible = false`. The 「举报活动」 button on club calendar and activity rows is off. The flow, selection types, tests and backend calls stay in place, unused. | `Core/ClubActivityReportSelection.swift`, `App/ClubEventCalendarView.swift` |

PG-086 (players never see the verification number) needs no code change; it is recorded in the source branch only.

## Files
- **Copied verbatim:** none; P5 is all hunks.
- **Adapted by hand (owned):** `Core/ClubContracts.swift`, `Core/TicketWalletContracts.swift`, `Core/ContextualReviews.swift`, `Core/IMConversationReplyPolicy.swift`, `Core/ClubActivityReportSelection.swift`, `Core/RegistrationUIForm.swift`, `App/TicketWalletDetailView.swift`, `App/MessagingHomeView.swift`, `App/ClubEventCalendarView.swift`.
- **Not touched, though plan-listed:**
  - `App/ClubGovernanceViews.swift`: it already uses `club.canGovern`.
  - `App/IMDriftEntries.swift`: no OR-023 site in it; it has only a comment.
- **Changes against the source:**
  - The money switch defaults to the current behaviour (the source hard-switched to one decimal).
  - In `.twoDecimals`, `plain` rounds half-up to 2 places, as `MerchantMoney` does today.
  - FE-G6 also treats a whitespace-only label as empty.
  - New UI text uses `.cyText(.caption)`, which the typography lint requires.

## Tests ported / added
- `ClubContractTests.testServerGovernanceBitWinsAndAbsentFallsBackToOwnerOrAdmin` (MC-055)
- `TicketWalletTests.testPerkTermsAreOptionalAndMalformedValuesStayHidden` (FE-G5), plus a new `testEmptyEntitlementStatusLabelFallsBackToLocalStatus` (FE-G6)
- `IMConversationReplyPolicyAppTests.testSystemConversationUsesAssistantTitleAndReplyHint` (OR-023). It **needs `p5.json` merged** to pass the `im.reply.systemNotice` assertion.
- `ShopNPCModernOutcomeTests`: the JSON compare (#164)
- `ClubActivityReportSelectionTests.testOwnerDecision1122KeepsTopicActivityReportEntryOffPlayerScreens` (V-23)
- `ContextualFlowTests.testReviewRequestIDIsOptionalAndValidated` and `testSameDraftReusesRequestIDOnRetryAndEditedDraftGetsNewOne` (PG-006). This test file is the existing test home of the owned `ContextualReviews.swift`; the changes only append.
- `RegistrationUIFormTests.testMoneyDisplaySwitchDefaultsToCurrentTwoDecimals` and `testMoneyDisplayOneDecimalRuleUsesOneDecimalUnlessTheSecondIsNonZero`. These are the source's 11-22 cases, run against `.oneDecimal` explicitly. This test file is the existing test home of the owned money formatter; the changes only append. The existing two-decimal assertions are unchanged and still hold.
- Not ported: `Verify1119PlayTests` (play items belong to P2/P4; it has no P5 case).

## New types and API (for the local integrator's compile order; all in Core, no new files)
- `ClubRecord.viewerCanGovern`
- `TicketWalletEntitlement.included`, `.extraSpendText`, `.reserveRequired`, `.displayStatusLabel`
- `ContextualReviewDraft.requestID`, `init(rating:contents:requestID:)` (the parameter has a default, so existing calls still compile), `.isValidRequestID(_:)`, `.makeRequestID()`
- `IMConversationTitlePolicy`
- `MoneyDisplay` (`Rule`, `current`, `minimumFractionDigits(_:)`, `maximumFractionDigits`, `plain`, `yuan`, `text`)
- `ClubActivityReportExposure`

## Mount hooks provided / needed
- **Needed, OR-023 list rows:** `MessagingConversationName` in `App/MessagingComponents.swift` (not owned by P5; used by 8 views) still prefers the counterparty nickname. Whoever owns or integrates that file adds one line at the top of `body`:
  `if IMConversationTitlePolicy.usesAssistantTitle(conversation) { Text("messaging.system") } else if let name = …`
  Until then the inbox *search* uses 城瘾小助手, but a type 2 row with a nickname shows the nickname.
- **Needed, money call sites** (to move onto `MoneyDisplay` when the owner confirms; P5 changes only the shared formatter, as plan §4 says):
  - Core: `MerchantContracts.swift:228` (`MerchantMoney`), `MerchantLedgerParity.swift:22`, `MemberHome.swift:136`, `WithdrawalHistory.swift:107`, `CoopFinanceProfit.swift:161`, `ClubOpsCustomerPresentation.swift:155`, `TopicPricingXcx.swift:45`, `ClubEnrollmentContracts.swift:170` (already one-or-two decimals), `G6CapabilitySource.swift:317`.
  - App: `OrderCardComponents.swift:112`, `ActivityBrowserView.swift:152`, `WorkshopCommerceView.swift:389`, `CoopFinanceSummarySection.swift:39`, `InvoiceLaunchPresentation.swift:255`, `MemberHomeHeader.swift:411`, `ExternalGameReviewScreens.swift:107` (TEST purchase label).
  - The chengyin-ios ruling also converted `HomeFeedView`, `TopicBrowserView`, `PublisherLifecycleViews`, `CooperationFlowWorkbench`, `MerchantBusinessValue`, `MerchantSettlementEntryPresentation` and `OwnedOrderRead`.
  - None of these files is in P1–P4.
- **Provided:** `IMConversationTitlePolicy` and `MoneyDisplay` (above).

## Route rows for P2
None. P5 adds no endpoint. `request_id` is an optional field on the existing, reviewed `api/comment/add`.

## Strings
`docs/port/strings/p5.json`:
- `im.reply.systemNotice` overrides an existing key: zh 「城瘾小助手不接收回复」 (was 「系统通知不支持回复」), en "Chengyin Assistant does not accept replies".
- `ticketWallet.perk.included` (已含 / Included) and `ticketWallet.perk.reserveRequired` (需预约 / Reservation required) are new.

## Acceptance
- `.github/workflows/acceptance.yml` does not exist yet on any branch, so no cloud run was possible.
- `swiftc` is **not available** in this cloud container, so `swiftc -parse` was **not** run. Instead, brace, paren and bracket balance was checked for every changed Swift file (all 0).
- Python gates run locally on this branch:
  - `tools/check_typography_lint.py`: **PASS**.
  - `tools/check_scaffold.py`: **FAIL**, only on `ticketWallet.perk.included` and `ticketWallet.perk.reserveRequired` missing from `Localizable.xcstrings`. This is expected: the brief forbids editing the catalog, and these keys come from `p5.json` when the integrator merges it.
  - `tools/check_contextual_flows.py`: fails at line 21 (`ContextualTopicPicker`), **identically on the base** (not new).
  - `tools/contract_ratchet.py --check`: **187 failing against a baseline of 184, with 3 new failures.** The base `ui/combined-r6` gives 185, with 1 new failure.
    - Already on the base, not caused by P5: `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`.
    - Caused by P5, 2 new failures, both because `ticketWallet.perk.included` and `ticketWallet.perk.reserveRequired` are missing from the catalog:
      - `test_localization_key_catalog_contract…test_no_looked_up_key_is_missing_from_every_catalog`
      - `test_native_design_motion…test_new_copy_is_bilingual_and_does_not_require_catalog_write`
    - These 2, and the scaffold failure above, clear when the integrator merges `docs/port/strings/p5.json` into `Localizable.xcstrings`. Nothing else in P5 fails a gate.
- Fixtures to screenshot: `docs/port/accept/p5.txt`.
- MP functions checked present: OR-023 title and reply copy, FE-G5/G6 entitlement row, PG-006 idempotent review submit, MC-055 governance bit, V-23 entry off. Missing: OR-023 list-row title, pending the mount hook above.

## Could not do
- Cloud acceptance run (the workflow is missing) and `swiftc -parse` (no compiler).
- `docs/owner-decisions/20261122-ios.md` (plan §5) is left to P6b, which owns the archive.
