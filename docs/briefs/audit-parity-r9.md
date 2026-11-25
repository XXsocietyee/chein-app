# Audit r9: re-measure MP parity (Phase D, 2026-11-25)

**Reviewer-only:** don't edit product code. Base: the newest `origin/ui/combined-r7` (at least `ebf6c160c`). MP source: `hengyin/chengyinhub-xcx`.

Same page list, method and parity formula as r8 (`origin/audit/parity-r8-<area>:docs/audit/parity-r8/<area>.md`). For every MP page, score:
- every function: request, flow, states;
- every visible string;
- every image slot (`MPAsset` vs MP image);
- navigation edges.

**New in r9:**
1. **Start from the r8 fix queue.** For each r8 row, mark it `fixed (<sha> app file:line)`, `partly` (say what is missing), or `open`. Check the code, not the receipts.
2. **MP-first rule** (`owner-decisions-1124.md`): never use the owner "owner decision". If the MP sends the request or has the flow, it is an app fix (owner Claude App or Cursor Core). The only exceptions are money (pay, refund, payout, withdrawal, paid orders: mark `money, TEST-only, not a gap`) and a feature the MP truly lacks (cite the MP evidence).
3. **Contract coverage per area** on `ebf6c160c` (Cursor's checker): member 103/21/52, account-publish 84/11/27, merchant-coop 134/20/38, club 109/6/14, player-content 183/21/40, play-roam 128/15/26 (matched / missing endpoint / missing test). Report your area's row; do not re-run it.
4. **Native-iOS check:** flag custom chrome where a system List / Form / sheet / ContentUnavailableView is expected, text below `.caption`, and missing Dynamic Type.

**Output:** `docs/audit/parity-r9/<area>.md` on branch `audit/parity-r9-<area>`, containing:
1. The area parity % and the r8 → r9 delta.
2. The P0/P1/P2 counts, open vs fixed since r8.
3. A fix queue with columns: id | severity | MP file:line | app file:line | what to do | owner (Claude App / Cursor Core). Rows must be small enough for one agent-hour each.
4. "Go-live blockers": P0s only.

Push within 60 minutes; commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The repo is PUBLIC: no MP screenshots, no secrets.
