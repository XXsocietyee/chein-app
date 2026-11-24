# F-agents, round 2 (2026-11-24): continue on your own `fix/r3-<area>-<half>` branch

1. **Sync.** Check out your branch, then `git merge origin/ui/combined-r7`, which now has Cursor's Core K1–K10, W1 wiring and C7 MP assets.
   - Resolve conflicts in favour of the newer Core API.
   - Merge `origin/ui/combined-r7` again before your final push.
2. **Finish what's left in your round-1 receipt** (`docs/release/receipts/fix-r3-<area>-<half>.md`).
3. **MP assets (owner requirement).** Use `docs/mp-assets/mapping.md` and `App/MPAssets/MPAsset.swift`.
   - Wherever your pages show a brand, feature or category icon, a badge, an illustration, a cover default, a map marker, an avatar default or a tab icon, use the MP asset exactly (`MPAsset.<name>`).
   - Only system-control glyphs (close, share, search, chevrons, more) stay SF Symbols.
   - Tick the rows you applied in your receipt.
4. **Review findings.** Fix rows owned by Claude for your area in `origin/review/r7-rev-a`, `-b` and `-c` (`docs/review/r7-*.md`), plus any P1 rows of `origin/audit/parity-r7-<area>` still open.
5. **Owner decisions.** Follow `docs/briefs/owner-decisions-1124.md`: two-decimal money, the GPS arrival lock, the pilot gate for game kits, money stays TEST-only, cast on fixtures.
6. **Don't touch** the call sites Cursor is now wiring (`cursor/wire-<area>`); they are listed in `docs/release/receipts/cursor-core-<area>.md`. If you need one, note it in your receipt.
7. **Rules:**
   - Same as `wave-x10.md`: no compiler in the cloud, so grep every API on `origin/ui/combined-r7`.
   - Use `Section { } header: { } footer: { }`, never `Section("key") { } footer:`.
   - No WebP or other non-PNG/JPG/PDF/SVG assets.
   - Strings go in `docs/port/strings/fix-r3-<area>-<half>.json` (xcstrings format, en AND zh-Hans).
   - Push every 30–60 minutes.
   - Update your receipt with a "Round 2" section.
