# Audit r8: re-measure MP parity on the current build (2026-11-25)

**Reviewer-only:** don't edit product code. Base: `origin/ui/combined-r7` (the newest SHA). MP source: `hengyin/chengyinhub-xcx`.

For your area, use the same page list and method as round 1 / r7 (`origin/audit/parity-r7-<area>:docs/audit/parity-r7/<area>.md`). For every MP page, score:
- every function: request, flow, states;
- every visible string;
- every image slot (`MPAsset` vs MP image);
- navigation edges.

**Output:** `docs/audit/parity-r8/<area>.md` on branch `audit/parity-r8-<area>`, containing:
1. The area parity % (same formula as r7) and the r7 → r8 delta.
2. The P0/P1/P2 counts.
3. A fix queue with columns: id | severity | MP file:line | app file:line | what to do | owner (Claude App / Cursor Core / owner decision).
4. A "go-live blockers" list: P0s only.

Push within 60 minutes; commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The repo is PUBLIC: no MP screenshots, no secrets.
