# Finish 2: contract-backlog-3 REAL defects

Branch `ui/e2p` from `origin/rc/20261108` (`1b9db04ca`). Code-only: no xcodebuild/simulator; the integrator compiles.

| defect | fix | contract module |
|---|---|---|
| Blacklist original identities / historical copy | `App/NativeBlacklistView.swift`: pending original shows peer, block and request IDs (monospaced, selectable); review sheet shows expected block + request ID; result shows `blacklist.historical` plus peer and request ID. | test_i03_notification_blacklist_closeout: green |
| Channel appeal receipt-not-reversal, locator, facts | `App/NativeChannelAppealEntry.swift`: renders `result.acceptedNotReversed`, `result.currentSeparate`, `locator.unavailable` (gated on `flow.locatorUnavailable`), `input.explanation`/`input.required`/`input.limit`, `progress.actionID`/`serverStatus`, action facts reasonCode/scopeType/scopeID, recovery explanation + request ID, attachments/unsupported-evidence notes, event-time label, VoiceOver refresh action. Unknown values stay as em dash; the `unknown` legend keys only explain it. | test_native_channel_appeal_localization: green |
| Template metadata hints | `App/MerchantOperationsEditor.swift`: `scopeHint` and `omissionHint` as section footers in the editor and the review. | test_merchant_template_metadata: green |
| Shop NPC copy over-promises | `Resources/Localizable.xcstrings`: `shopNPC.pauseNotice` / `shopNPC.retryNotice` restored to the reviewed fragment copy (restore never sends; server may have received it; retry reuses the request ID and does not prove the earlier one was cancelled). EN + zh-Hans. | test_shop_npc_interruption: green |

Test re-pins (stale, with evidence): in `test_native_channel_appeal_localization.py`, `retry.confirmation`, `recovery.journalUnavailable` and `session.unavailable` expectations now match the reviewed catalog copy (15e7e3204), which is more explicit about no automatic resend.

Ratchet: 259 -> 252 failing, new 0, 7 fixed (baseline updated). `check_scaffold.py` and `check_design_lint.py` PASS.

Not verified: Swift compile and rendering (no xcodebuild), VoiceOver behavior, layout of the added footers/captions.
