# F-agents, round 4 (2026-11-25): continue on your own `fix/r3-<area>-<half>` branch

**Base:** `origin/ui/combined-r7` (merge it first). It has your round 3, Cursor's round 4 (W2 wiring, the a11y zero baseline, Swift 6) and Gemini round 7.

Gemini is out of quota for about 4 hours, so **you also take Gemini's MP-alignment work for your pages.**

1. **Flows.** Every edge marked "Claude" or "Gemini" for your pages in `docs/mp-gap/flows-g1.md` / `flows-g2.md`: which tap leads where, back targets, after-success targets. Make the app match the MP.
2. **Image parity.** For every MP page in your half, list each image slot the MP shows (`src=`, `background-image`, icon components, default and fallback images). Make the app show the same `MPAsset` (`docs/mp-assets/mapping.md`, `App/MPAssets/MPAsset.swift`). Only system-control glyphs stay SF Symbols. Record the table in your receipt.
3. **Copy.** Every user-visible Chinese string on your pages must equal the MP text (titles, buttons, empty/error/toast). Put overrides in your strings fragment: xcstrings shape, en + zh-Hans. Existing keys may be overridden.
4. **P2 rows** owned by Claude for your area in `audit/parity-r7-<area>`, then any open P1.
5. **Keep the a11y lint at 0:** `python3 -B tools/check_a11y_lint.py`. Put `.accessibilityHidden(true)` AFTER Image-only modifiers (`.resizable()`, `.renderingMode()`).

**Rules:** same as before. Grep every current declaration before use, never redeclare an existing type name, push every 30–60 minutes, and add a "Round 4" section to your receipt.
