# Fix r8: close the r8 audit P0/P1 rows owned by Claude App (2026-11-25)

**Branch:** `fix/r8-<area>` from the newest `origin/ui/combined-r7`. Your queue is `origin/audit/parity-r8-<area>:docs/audit/parity-r8/<area>.md` (player-content: also its `player-content-groups/*.md`).

**Take every row whose owner is "Claude App", P0 first, then P1, then P2:**
- **"Mount the compiled view" rows** (App/MPGap screens that compile but aren't reachable): wire them from the MP-equivalent entry point, following the MP's navigation.
- **Missing states, copy, image slots** (`MPAsset`) and navigation edges listed in the row.
- Don't take rows owned by "Cursor Core" or "owner decision". Instead, if your App work needs a Core piece, list it in your receipt under "for Cursor".

**Other agents in the same area:**
- The round-4 F-agents (`fix/r3-<area>-a|b`) work in the same area on flows, images and copy. Before editing a file, `git log origin/fix/r3-<area>-a origin/fix/r3-<area>-b -- <file>` to see if they touched it, and keep your hunks small.
- Merge `origin/ui/combined-r7` again before every push.

**Rules:**
- Same as `wave-x10.md`.
- Grep every current declaration before use; never redeclare an existing type name.
- Strings must be xcstrings-shaped, with en + zh-Hans.
- `.accessibilityHidden` goes after Image-only modifiers.
- Money stays TEST-only.
- Push every 30–60 minutes. Write the receipt `docs/release/receipts/fix-r8-<area>.md` with the ids closed, the files, and the "for Cursor" list.
