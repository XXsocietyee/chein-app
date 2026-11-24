# Owner decisions, 2026-11-24 (binding for all workers)

| # | Topic | Decision | Implementation |
|---|---|---|---|
| 2 | Platform-pass order reads | Yes, show to players | Read gate ON |
| 3 | Refund requests | Count as money | TEST-only until "money on"; gate OFF in Release |
| 4 | Media upload | Auto-retry allowed | Bounded retry (idempotent upload only) |
| 5 | Merchant approvals | In the app | Merchant staff approve/reject screens, permission-checked |
| 6 | Host cancellation with refunds | Counts as money | TEST-only; gate OFF in Release |
| 7 | Story cast / voice | Fixture content for now | No live cast backend calls |
| 8 | Arrival lock | Must be at the stop (GPS), as in the MP | Next chapter unlocks only on arrival |
| 9 | Money display | Two decimals (¥12.50) | One shared formatter |
| 10 | Ported game-page kits (P4) | Pilot events only | Per-event gate, default OFF |
| 11 | TestFlight | Internal upload once acceptance is green | Coordinator does it |
| 12 | "Money on" | Not yet | All money writes TEST-only |

chengyin-ios: will be ARCHIVED (not deleted) after the other developer freezes it. Do not push to it.
