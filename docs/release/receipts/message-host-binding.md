# NativeChannelMessageHostBindingTests (2 failures): root cause

Code-only; nothing was built or run. Verdict: the rig was stale. I found no production defect, and the double send is unexplained (below).

## Production does not double-send on timeout-then-remount
- `NativeChannelTextCoordinator` has exactly one wire-send site, `dispatch` (Core/NativeChannelTextCoordinator.swift). It runs only after the journal has persisted the intent (`saveBeforeDispatch`) and re-read it.
- A timeout never resends. The `catch` branch runs `probe`, which calls `confirmOriginal` (the send-receipt route).
- Remount: `activate()` only restores the journal intent. `checkReceipt()` only queries. `retryOriginal()` needs an explicit user action and a typed NOT_FOUND.
- No transport layer retries: `NativeChannelTextTransport`, `NativeChannelDispatchTransport` and `NativeChannelMessageOriginalWireBridge` each forward once.
- I found no path that could send the same key twice. I could not reproduce or explain the observed `[key, key]` by reading. A run is needed to capture a stack at the second `send` case in `MessageHostWire`.

## Rig drift (fixed in the test file only; no assertion removed)
1. The mock send-receipt answered the pre-proof shape (`found:true`, no `state`, no `original_send_proof`). `NativeChannelTextService.readOriginalSend` now requires `state == "APPLIED"` plus a matching `original_send_proof`, including the request_hash. The old shape reads as `.unknown`, so `checkReceipt()` could never return true. The mock now emits the proof (hash from `NativeChannelOriginalSendDigest`) and a typed `NOT_FOUND` otherwise.
2. Test 1: acknowledging a send does not refresh history. The page does that on change. The harness never did, so `history.messages` stayed empty and `snapshot(for:)` was nil. The test now calls `flow.history.load()` before the history assertions.
3. Test 2: after a timeout `dispatch` runs one automatic receipt query by design ("Timeout ... is never a resend instruction. Query only."). The mock gets `receiptReady = false` until the remount, so the first query is NOT_FOUND and `sendNew` returns false as asserted. The `lookedUp` expectation is now `[key, key]`: one automatic query plus one remount check. This follows the documented probe and is not a weakened guarantee; `sent == [key]` is unchanged and still proves one send.

## Baseline
The test file and Core are unchanged since the reviewed snapshot f9ca1f424. The failure predates rc 201bf147f; earlier triage docs list it as pre-existing.
