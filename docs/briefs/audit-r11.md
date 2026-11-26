# Audit r11: re-measure player + club parity after fix round r10 (2026-11-26)

**Reviewer-only:** don't edit product code. Repo `https://github.com/XXsocietyee/chein-app`.

- **App:** the newest `origin/ui/combined-r7` (at least `b9a9d4d29`; all 11 r10 lanes merged through round 3).
- **MP source:** branch `origin/mp-source`, folder `chengyinhub-xcx/` (hengyin master snapshot 2026-11-24). Read it with `git show origin/mp-source:chengyinhub-xcx/<path>` or check it out in a separate worktree. Do NOT use `gh` / GitHub code search; the old hengyin repo is gone.
- **Previous report:** `origin/design/handoff-r2:docs/audit/parity-r10/<area>.md` (player-content: `parity-r10/player-content-groups/*.md`). Same page list, method and parity formula. Receipts for r10 fixes: `origin/ui/combined-r7:docs/release/receipts/fix-r10-*.md`.

**Scope (owner 11-26):** player side + clubs. Merchant-only rows: mark `merchant release`, don't count them. Money is ON in Release (payment, refund, host-cancel refund, payout, withdrawal); virtual goods off. No visual redesign: score function and MP behavior, plus "uses Apple components", not looks.

**For every row of the r10 report:** re-check it in code on the new tip (not from commit messages). Status: fixed (cite file:line and SHA) / partly / open / regressed. Then scan each MP page once more for rows the r10 report missed.

**Output:** `docs/audit/parity-r11/<area>.md` on branch `audit/parity-r11-<area>` (from `origin/ui/combined-r7`, docs only):
1. Parity table per MP page (r10 → r11, Δ) and area total.
2. Open P0 / P1 / P2 counts.
3. **Fix queue** (one row per open item, P0 first): id, MP file:line, app file:line, what to change, size (S/M/L). This is the input for fix round r11, so make each row actionable by an agent without a compiler.
4. Regressions found (if any) with the commit that caused them.

Push when done. Trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
