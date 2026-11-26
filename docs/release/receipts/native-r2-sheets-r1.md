# Receipt: native-r2/sheets-r1 (M5: every sheet gets the backdrop motion)

Spec: `origin/design/handoff-r2:docs/briefs/native-r2-motion-r1.md` §M5 (owner 11-26: all pop-ups get this animation).
Branched from `origin/ui/combined-r7` @ `8f7d9c365`.

## Backdrop helper: reuse check
- `origin/native-r2/motion-r1` **does not exist** on the remote at the time of this run (fetched all heads), and no
  branch under `origin/native-r2/*` or `ui/combined-r7` has a `PresentationBackdrop` / sheet-backdrop helper.
- So this lane owns the single implementation: `App/NativeR2/Motion/CYSheet.swift`, type `PresentationBackdrop`.
  **motion-r1 (M2) must reuse it, not add a second one**: for its punch / game-result / stage-result sheets it only
  needs `cySheet(...)` (already applied by the codemod) — the detent-fraction drive is in here.

## What was built
| Piece | Where |
|---|---|
| `NativeR2Flags.sheetBackdrop` (`nativeR2.sheetBackdrop`, default on; off = plain system `.sheet` / `.fullScreenCover`, no host effect, nothing registered) | `App/NativeR2/Motion/CYSheet.swift` |
| `PresentationBackdrop` (`@MainActor @Observable`): active presentations of one layer + their detent fraction (sheet height ÷ layer height), `intensity` 0…1 (small detents ≥ 0.4) | same |
| `cyPresentationBackdropHost()`: injects the model through `\.presentationBackdrop` and draws the M2 backdrop on that layer: `.blur(2 pt × intensity)` + top-heavy `.ultraThinMaterial` ramp (mask 1 → 0.12, reads ~16 pt at the top, ~2 pt at the bottom) + gradient white 0.92 → 0.15 (dark: black 0.6 → 0.1); hit-testing off, hidden from VoiceOver | same |
| Reduce Motion: gradient only, no blur ramp, set instantly (`withAnimation(nil)` when `UIAccessibility.isReduceMotionEnabled`; scoped to the backdrop, other animations untouched) | same |
| Animation: the sheet's spring (`.spring(response: 0.5, dampingFraction: 1)`), starts when the binding flips (not on content appear) and fades as the dismissal starts | same |
| `cySheet(isPresented:onDismiss:content:)`, `cySheet(item:onDismiss:content:)`, `cyFullScreenCover(isPresented:onDismiss:content:)`, `cyFullScreenCover(item:onDismiss:content:)` — Apple's exact generic signatures (`@ViewBuilder`, `@escaping`, `Item: Identifiable`) | same |
| Nested sheets: every presented content is its own host, so a sheet presented from a sheet blurs the sheet under it | same |
| Root host installed once on the `WindowGroup` root (covers the session root and every fixture root) | `App/QuestifyApp.swift` |

Sheets keep system detents, grabber and dimming. `.alert`, `.confirmationDialog`, `.popover` untouched.
Name note: `CYSheetModal.swift` already has a styling modifier `cySheet(detents:selection:)`; the new overloads differ
by argument labels (`isPresented:` / `item:`), so there is no ambiguity.

## Codemod
Script: `tools/codemod_cy_sheet.py` (idempotent; `--check` exits 1 if anything is left; `--json` summary).
Lexes Swift (line/nested block comments, `"…"`, `"""…"""`, raw `#"…"#` strings) so only code is touched; rewrites
only the receiver name; a call is rewritten only if its labels ⊆ {isPresented | item, onDismiss, content}.

| Count | Value |
|---|---|
| `.sheet(` → `.cySheet(` | **637** |
| `.fullScreenCover(` → `.cyFullScreenCover(` | **22** |
| Files changed by the codemod | 390 |
| Skipped: labels outside Apple's signature (possible type-inference change) | 0 |
| Skipped: not a presentation modifier (`kind.sheet(locale:)`, `CYSheetModalTokens.sheet(in:)`) | 2 (silent, not SwiftUI) |
| Skipped: SwiftUI calls inside `Tests/` (left as Apple's `.sheet`; codemod only walks `App/` and excludes any `Tests` path) | 3 (`Tests/AppUnitTests/RoamPlaceDetailReadLifetimeTests.swift:169`, `CoopFinancePresentationClosureTests.swift:50`, `RoamShareNativeLifetimeTests.swift:176`) |
| Remaining after run (`--check`) | 0 |

Brief said 638 + 22; `ui/combined-r7` @ `8f7d9c365` has 637 SwiftUI `.sheet(` sites (the other two `.sheet(` hits are
non-SwiftUI methods above). Byte check: reversing the rename reproduces all 390 files exactly.

## Gate scripts updated for the rename (string literals only)
`tools/check_a11y_lint.py` (treat `cySheet` / `cyFullScreenCover` as view-builder containers like `sheet`),
`tools/check_media_destinations.py`, `tools/check_merchant_template_assist.py`,
`tools/check_native_navigation_completion.py`, `tools/check_native_verification.py`,
`tools/check_search_map_date_picker.py`.

## Gates
- `python3 tools/generate_project.py` → project regenerated (new file included).
- `python3 tools/check_scaffold.py` → `PASS structural checks: 5168 Swift source files, 19333 bilingual keys …`
- `python3 -B tools/check_a11y_lint.py` → FAIL 9 unlabeled-image — **identical on base `ui/combined-r7`** (pre-existing, not from this lane).
- `tools/check_media_destinations.py` (`SquareBrowserView showImages: false`) and the FAIL lines of
  `check_native_navigation_completion.py` — identical on base (pre-existing).
- Contract ratchet: see below.

## Not run here (Linux container)
Swift compile, simulator, screenshots, VoiceOver. The coordinator's `build_sim` is the first compile of this lane.
Risks to watch in that build: none expected from the codemod (signatures identical); in `CYSheet.swift` watch
`onChange(of:initial:)` on `Item.ID?` and the `ModifiedContent<SheetContent, PresentationBackdropRegistration>` closure types.
