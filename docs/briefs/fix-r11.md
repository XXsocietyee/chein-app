# Fix r11: close the r11 audit queues (2026-11-26)

Repo moved: **`https://github.com/XXsocietyee/chein-app`** (the old `liboyang42-cpu` repo is gone). Base: the newest `origin/ui/combined-r7`.

**Sources:** the r11 audit reports, one per area, each with a **Fix queue** section:
`git show origin/audit/parity-r11-<area>:docs/audit/parity-r11/<area>.md` for area in club, play-roam, player-content, account-publish, member.
MP source of truth: `origin/mp-source:chengyinhub-xcx/` (do not use gh / GitHub search; the old hengyin repo is gone).

**Product rules (owner, 11-26):**
- First release = **player side + clubs**. Merchant center is gated off (`PlayerLaunch.merchantCenterEnabled`, false in Release). Skip rows that are merchant-only; mark them `merchant release` in the receipt.
- **Money is ON in Release** (payment, refund, host-cancel refund, payout, withdrawal). Rows marked "money" are now in scope: wire them like the MP. Virtual goods (StoreKit products) stay off.
- **MP-first:** do what the MP does; cite MP file:line in a code comment.
- **No visual redesign.** The owner paused design work. Use plain Apple components (List/Form/sheets/ContentUnavailableView, Dynamic Type) and existing helpers; do not restyle screens, add motion, or change themes.

**Order:** P0 first, then P1, then P2 of your slice. One commit per row id: `fix(r11-<lane>): <row id> …`.

**No compiler in the cloud.** Grep every type/member before use. Known traps (`COORDINATOR-HANDOVER.md` §4): generic static access; duplicate type names; `@Environment` in a different struct than the reader; inits differing only by closure label; new enum cases missing from switches; ternary of function-ref vs nil in big view bodies; `try` leading a `||`; no shadowing `@State` with if-let; no `private` members used across files; structs with private stored properties need an explicit init if built from another file; keep long view modifier chains split into computed properties (type-check timeouts).

**Gates before every push:** `python3 tools/check_scaffold.py` (PASS structural checks), `python3 -B tools/check_a11y_lint.py` (PASS), `python3 -B tools/contract_ratchet.py --check` (new 0; if your change intentionally changes a pinned contract, update that test with a comment citing the MP file). New files → `python3 tools/generate_project.py`. Strings → `Resources/Localizable.xcstrings` (zh-Hans + en).

**Merging:** `git fetch origin` then merge `origin/ui/combined-r7` before every push (xcstrings conflicts: key union). Push every 30–45 min to your lane branch `fix/r11-<lane>` only. Never push `ui/*`, `main` or `ci/*`.

**Receipt:** `docs/release/receipts/fix-r11-<lane>.md` — every row id in your slice: fixed / partly / blocked / merchant release, SHA, app file:line.

Trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Lanes

| Lane | Branch | Slice |
|---|---|---|
| club-a | `fix/r11-club-a` | club.md fix queue: every P0 and P1 row |
| club-b | `fix/r11-club-b` | club.md fix queue: P2 rows |
| roam | `fix/r11-roam` | play-roam.md fix queue: all rows (P1 first; JLAND/CAP/START first) |
| content | `fix/r11-content` | player-content.md fix queue: all rows, P0 first |
| acct | `fix/r11-acct` | account-publish.md fix queue: all rows, P0 first |
| member | `fix/r11-member` | member.md fix queue: all rows |

Before each row, check the same id is not already fixed on `origin/ui/combined-r7` (another lane or a late r10 push).
