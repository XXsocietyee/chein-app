# Fix r9: close the r9 parity queues (Phase D, 2026-11-25)

**Base:** the newest `origin/ui/combined-r7`. **Sources:** `origin/audit/parity-r9-<area>:docs/audit/parity-r9/<area>.md`, fix-queue rows with owner **Claude App**. Rows with owner **Cursor Core** are Cursor's: don't do them, but if your App row needs a Core function that doesn't exist yet, add a thin mount hook and note it in your receipt.

**r9 baseline:**
| Area | Parity | P0 | P1 |
|---|---|---|---|
| member | 91% | 2 | 10 |
| account-publish | 91% | 2 | — |
| merchant-coop | 86% | 23 | 49 |
| club | 88% (about 85% release-effective) | 9 | 30 |
| player-content | 95% | 4 | 22 |
| play-roam | 98.6% | 0 | 13 |

**Order:** P0 first, then P1, then P2. One commit per row id, message `fix(r9-<area>): <row id> …`.

**Rules:**
- **MP-first:** copy what the MP does, citing the MP file:line in a code comment. Money stays TEST-only.
- **Native iOS:** system List / Form / sheets / ContentUnavailableView; Dynamic Type; nothing below `.caption`.
- **MP images:** use `MPAsset.*` (Gemini added 67 more on 11-25; see `docs/mp-assets/mapping.md` and `docs/release/receipts/gemini-mp-assets-r9.md`).
- **No compiler in the cloud:** grep every declaration before use. Avoid the known compile traps (`COORDINATOR-HANDOVER.md` §4):
  - generic static access;
  - duplicate type names;
  - `@Environment` declared in a struct other than the one that reads it;
  - inits that differ only by closure label (label the closure);
  - new enum cases missing from switches;
  - ternaries of function-ref vs nil inside big view bodies (use a typed computed property);
  - `try` must lead a `||` expression.
- **Gate:** `python3 tools/check_scaffold.py` must print `PASS structural checks`. Strings: add keys to `Resources/Localizable.xcstrings` AND to `docs/port/strings/fix-r9-<area>.json`.
- **Merging:** merge `origin/ui/combined-r7` before every push. For xcstrings conflicts take the key union (keep the tip's order, append yours). Push every 30–60 min to `fix/r9-<area>[-a|-b]` only.
- **Receipt:** `docs/release/receipts/fix-r9-<area>.md` with every row id, its status (fixed / partly / blocked), the SHA, and the app file:line.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
