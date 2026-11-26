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
| SwiftUI `.sheet(` call sites on `ui/combined-r7` @ `8f7d9c365` | 637 |
| `.sheet(` → `.cySheet(` | **631** |
| `.fullScreenCover(` → `.cyFullScreenCover(` | **22** (of 22) |
| Files changed by the codemod | 387 |
| Skipped: labels outside Apple's signature (possible type-inference change) | **0** |
| Skipped: byte-pinned files (sha256 contracts on protected deliveries; pin owner must opt in) | **6** sheets in 3 files, see below |
| Skipped: SwiftUI calls inside `Tests/` (codemod walks `App/` only and excludes any `Tests` path) | 3 (`Tests/AppUnitTests/RoamPlaceDetailReadLifetimeTests.swift:169`, `CoopFinancePresentationClosureTests.swift:50`, `RoamShareNativeLifetimeTests.swift:176`) |
| Not a presentation modifier, left alone (`kind.sheet(locale:)`, `CYSheetModalTokens.sheet(in:)`) | 2 |
| Contract literals following the rename (`--contracts`, `Tests/ContractChecks/*.py` strings that quote App source) | 113 in 70 files |
| Remaining after run (`--check`) | 0 |

### Skipped, byte-pinned (keep Apple's `.sheet`; no backdrop until the pin owner updates the hash)
| Call site | Pin |
|---|---|
| `App/CharacterCardReadbackView.swift:62` | sha256 manifest, `test_c02_world_party_character.test_sha256_manifest_covers_exclusive_sources` |
| `App/PublishingModesViews.swift:240, 271, 276, 981` | suffix sha256, `test_activity_publishing_wizard.test_untouched_publishing_slices_and_activity_handoff` |
| `App/WorkshopPaidInstalledTextView.swift:28` | sha256, `test_workshop_protected_text_lifecycle.test_all_product_bytes_match_original_protected_consumer_delivery` |

To opt them in: delete the entry from `BYTE_PINNED` in the script, re-run it, and update the three hashes with a
"presentation-only" note (precedent: the native r2 comment in `test_workshop_protected_text_lifecycle.py`).

Brief said 638 + 22; `ui/combined-r7` @ `8f7d9c365` has 637 SwiftUI `.sheet(` sites. Byte check: reversing the rename
reproduces every changed App file exactly (only the receiver name changes).

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
- Contract ratchet (`python3 tools/contract_ratchet.py`, branch vs a base worktree of `ui/combined-r7` @ `8f7d9c365`):
  base 239 failing → branch first pass 287 (48 new, all source contracts quoting `.sheet(` / `.fullScreenCover(` or
  sha256-pinning App files) → after `--contracts` + byte-pinned skips + one hand fix → **0 new, 0 fixed vs base**.
  Hand fix: `test_native_presentation_reuse.test_camera_and_scanner_remain_full_screen_and_cancelable` forbade any
  `.cySheet(` after the rename, which also matched the pre-existing `.cySheet(detents:)` chrome; it now forbids only
  presenting calls (`.cySheet(isPresented` / `.cySheet(item`).

## Not run here (Linux container)
Swift compile, simulator, screenshots, VoiceOver. The coordinator's `build_sim` is the first compile of this lane.
Risks to watch in that build: none expected from the codemod (signatures identical); in `CYSheet.swift` watch
`onChange(of:initial:)` on `Item.ID?` and the `ModifiedContent<SheetContent, PresentationBackdropRegistration>` closure types.
