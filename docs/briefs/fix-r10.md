# Fix r10: close the player + club parity queues (2026-11-26)

Repo moved: **`https://github.com/XXsocietyee/chein-app`** (the old `liboyang42-cpu` repo is gone). Base: the newest `origin/ui/combined-r7`.

**Sources (on this branch, `design/handoff-r2`):**
- `docs/audit/parity-r10/club.md` (P0 17, P1 62)
- `docs/audit/parity-r10/play-roam.md` (P0 1, P1 39) — queue in §5
- `docs/audit/parity-r10/account-publish.md` (P0 3, P1 51) — queue in §4
- `docs/audit/parity-r10/member.md` (P0 2, P1 11) — queue in §4
- `docs/audit/parity-r10/player-content-groups/{B-topic,C-activity,D-subpackages}.md` (P0 6, P1 29)
- MP source of truth: the mini-program pages cited in each row (paths are in the reports).

**Product rules (owner, 11-26):**
- First release = **player side + clubs**. Merchant center is gated off (`PlayerLaunch.merchantCenterEnabled`, false in Release). Skip rows that are merchant-only; mark them `merchant release` in the receipt.
- **Money is ON in Release** (payment, refund, host-cancel refund, payout, withdrawal). Rows marked "money" are now in scope: wire them like the MP. Virtual goods (StoreKit products) stay off.
- **MP-first:** do what the MP does; cite MP file:line in a code comment.
- **No visual redesign.** The owner paused design work. Use plain Apple components (List/Form/sheets/ContentUnavailableView, Dynamic Type) and existing helpers; do not restyle screens, add motion, or change themes.

**Order:** P0 first, then P1, then P2 of your slice. One commit per row id: `fix(r10-<lane>): <row id> …`.

**No compiler in the cloud.** Grep every type/member before use. Known traps (`COORDINATOR-HANDOVER.md` §4): generic static access; duplicate type names; `@Environment` in a different struct than the reader; inits differing only by closure label; new enum cases missing from switches; ternary of function-ref vs nil in big view bodies; `try` leading a `||`; no shadowing `@State` with if-let; no `private` members used across files; structs with private stored properties need an explicit init if built from another file; keep long view modifier chains split into computed properties (type-check timeouts).

**Gates before every push:** `python3 tools/check_scaffold.py` (PASS structural checks), `python3 -B tools/check_a11y_lint.py` (PASS), `python3 -B tools/contract_ratchet.py --check` (new 0; if your change intentionally changes a pinned contract, update that test with a comment citing the MP file). New files → `python3 tools/generate_project.py`. Strings → `Resources/Localizable.xcstrings` (zh-Hans + en).

**Merging:** `git fetch origin` then merge `origin/ui/combined-r7` before every push (xcstrings conflicts: key union). Push every 30–45 min to your lane branch `fix/r10-<lane>` only. Never push `ui/*`, `main` or `ci/*`.

**Receipt:** `docs/release/receipts/fix-r10-<lane>.md` — every row id in your slice: fixed / partly / blocked / merchant release, SHA, app file:line.

Trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Lanes

| Lane | Branch | Slice |
|---|---|---|
| club-a | `fix/r10-club-a` | club.md: every P0 row, first half in table order |
| club-b | `fix/r10-club-b` | club.md: every P0 row, second half; then the gate-05 / badges-01 / group-code / notify release-dead rows |
| club-c | `fix/r10-club-c` | club.md: P1 rows, first half in queue order |
| club-d | `fix/r10-club-d` | club.md: P1 rows, second half in queue order |
| roam-a | `fix/r10-roam-a` | play-roam.md §5: the P0, then P1 first half |
| roam-b | `fix/r10-roam-b` | play-roam.md §5: P1 second half, then P2 |
| content-a | `fix/r10-content-a` | player-content-groups/B-topic.md: all P0 + P1 |
| content-b | `fix/r10-content-b` | player-content-groups/C-activity.md + D-subpackages.md: all P0 + P1, then P2 |
| acct-a | `fix/r10-acct-a` | account-publish.md §4: P0, then P1 first half |
| acct-b | `fix/r10-acct-b` | account-publish.md §4: P1 second half, then P2 |
| member | `fix/r10-member` | member.md §4: all P0 + P1, then P2 |

If two lanes need the same file, keep your hunk small and merge `origin/ui/combined-r7` often; the coordinator merges lanes in the order they push.
