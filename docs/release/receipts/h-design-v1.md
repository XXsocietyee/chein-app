# Receipt: `h-design-v1` — Combined Design Rollout Branch (HELD)

- **Branch**: `ui/h-design-v1` (**HELD** — do not merge; awaits owner approval and before/after preview)
- **Merge Order & Source SHAs**:
  1. Base: `origin/ui/h-tokens-v1` (`81e60e080245572b64a4601c3cfb535d77903cd5`) — based on `origin/ui/main` (`5ba7b0f2c5f10dea10905895da947c350b3e24ac`)
  2. Merged `origin/ui/h-components-v1` (`b77718d7f7555169b3b798ca228dd2f2a67d43c2`) — fast-forwarded cleanly onto `81e60e080`
  3. Merged `origin/ui/h-chrome-v1` (`6cefdb283bba79cd98024dbaed6d887f754eb1b8`) — merge commit `88cb01aa5` with 3 content conflicts resolved (detailed below)
  4. Checked against latest `origin/ui/main` (`5ba7b0f2c5f10dea10905895da947c350b3e24ac`) — already up to date (ancestor of `81e60e080`, zero additional conflicts)
- **Verification Scope**: Static checks only (`swiftc -parse`, `swiftc -parse -D DEBUG`, Python gates, and static contract tests). No `xcodebuild`, simulator build, or UI visual verification was run on this Mac.

---

## 1. Merge Conflicts & Resolutions

Merging `origin/ui/h-chrome-v1` (`6cefdb283`) onto `ui/h-components-v1` (`b77718d7f`) produced 3 file conflicts, all inside `App/DesignSystem/`. No other files conflicted.

### 1.1 `App/DesignSystem/CYConfirmSheet.swift` (line 105)

- **`ui/h-components-v1` (`HEAD`)**: `.background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))`
- **`ui/h-chrome-v1` (`6cefdb283`)**: `.background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))`
- **Resolution**: Kept `CYRadius.lg` (`16pt` nested card radius) with `CYColor.sheetCard`. Both branches migrated the consequence container fill from `CYColor.bgPage` to `CYColor.sheetCard`; `ui/h-components-v1` intentionally upgraded the nested sheet-card corner radius from `CYRadius.md` to `CYRadius.lg` (consistent with `CYSheetModal.swift`), whereas `ui/h-chrome-v1` only swapped the color token and left the pre-existing `CYRadius.md` untouched.

### 1.2 `App/DesignSystem/CYDomainPalette.swift` (lines 99–107)

- **`ui/h-components-v1` (`HEAD`)**:
  - Replaced `0x0F172B` slate-blue card shadow with neutral `CYRGB(hex: 0x000000, alpha: 0.05)` (`cardShadowColor`).
  - Added `floatShadowColor` (`isDark ? 0x000000 @ 0.28 : 0x000000 @ 0.10`), which is referenced by `CYDesignTokens.swift`, `CYSharedStates.swift`, and `CYSheetModal.swift`.
- **`ui/h-chrome-v1` (`6cefdb283`)**:
  - Replaced `0x0F172B` slate-blue card shadow with neutral `CYRGB(hex: 0x000000, alpha: 0.08)` (`cardShadowColor`).
- **Resolution**: Kept `CYRGB(hex: 0x000000, alpha: 0.05)` for `cardShadowColor` and retained `floatShadowColor`. Both branches eliminated the disallowed `0x0F172B` slate-blue shadow checked by `test_global_chrome_domain_contract.py`; `ui/h-components-v1`'s `0.05` alpha matches the unified shadow spec across `CYDesignComponents.swift` and `CYBusinessComponents.swift`, and retaining `floatShadowColor` preserves compilation for toast and modal shadows.

### 1.3 `App/DesignSystem/CYDomainTabBar.swift` (lines 216–242)

- **`ui/h-components-v1` (`HEAD`)**: Updated `CYTabBarAppearance.install()` unselected alpha from `0.45` to `let unselectedAlpha = Theme.MiniProgramChrome.tabUnselectedOpacity` (`0.6`) with doc comment noting `#7A5CFF` selected tint.
- **`ui/h-chrome-v1` (`6cefdb283`)**: Updated the same line from `0.45` to `let unselectedOpacity = Theme.MiniProgramChrome.tabUnselectedOpacity` with doc comment noting `Call once at launch`.
- **Resolution**: Kept `unselectedAlpha = Theme.MiniProgramChrome.tabUnselectedOpacity` and merged the doc-comment details (`0.6` opacity via `Theme.MiniProgramChrome.tabUnselectedOpacity`, `#7A5CFF` selected icon/label, call once at launch). Both branches made the same semantic change.

---

## 2. Sync with `origin/ui/main`

- Fetched latest `origin/ui/main` (`5ba7b0f2c5f10dea10905895da947c350b3e24ac`).
- `git merge FETCH_HEAD` returned `Already up to date.` because `origin/ui/main` is already the direct parent of `origin/ui/h-tokens-v1` (`81e60e080`). No functional changes from `ui/main` were displaced.

---

## 3. Verification Results (No Builds Run on This Mac)

All checks below passed on the combined branch:

1. **`swiftc -parse` on every changed Swift file** (`git diff --name-only 5ba7b0f2c..HEAD -- '*.swift' | xargs xcrun swiftc -parse`, plus `-D DEBUG`):
   - **PASS** (exit `0` for both standard and `-D DEBUG` fixture compilation checks)
2. **`python3 -B tools/check_design_lint.py`**:
   - **PASS** (`scanned 1634 App Swift files outside DesignSystem and Theme; allowlist 29 files (44 existing violations)`)
3. **`python3 -B tools/check_a11y.py`**:
   - **PASS** (`10 scoped screens, helper checked, 2 range views left, 3096 other App views not scanned`)
4. **`python3 -B tools/check_scaffold.py`**:
   - **PASS** (`page route table: 262 pages`, `4774 Swift source files, 16562 bilingual keys`, privacy manifest & release config checks passed)
5. **`python3 -B tools/contract_ratchet.py --check`**:
   - **PASS** (`contract ratchet: 186 failing, baseline 186, new 0, fixed 0`)
6. **`python3 -B tools/check_design_fixture_release_exclusion.py`**:
   - **PASS** (`App target Release excludes 38 design-fixture sources. Release projection contains none of the audited fixture symbols.`)
7. **Design, Chrome, Motion & Fixture Contract Tests**:
   - `python3 -B -m unittest Tests/ContractChecks/test_design_token_unification_contract.py Tests/ContractChecks/test_global_chrome_domain_contract.py Tests/ContractChecks/test_native_design_motion.py Tests/ContractChecks/test_activity_design_structure.py tools/tests/test_design_fixture_release_exclusion.py -v`
   - **PASS** (`Ran 40 tests — OK`)
