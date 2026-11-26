# Receipt: native-r2/sheets-r1 (M5: every sheet gets the backdrop motion)

Spec: `origin/design/handoff-r2:docs/briefs/native-r2-motion-r1.md` §M5 (owner 11-26: all pop-ups get this animation).
Branched from `origin/ui/combined-r7` @ `8f7d9c365`; last merged `origin/ui/combined-r7` @ `169f2904e`.

## Backdrop helper: reused from motion-r1 (one implementation)
- First check (start of run): `origin/native-r2/motion-r1` did not exist yet, so a first `CYSheet.swift` drew its own
  backdrop (commits `6ce041856`, `2eb3afd91`).
- Second fetch (before the first merge of combined-r7): `origin/native-r2/motion-r1` @ `3849e7e63` has the M2 helper
  `NativeR2SheetBackdrop` / `nativeR2SheetBackdrop(isPresented:)` / `nativeR2SheetBackdropSource()` /
  `NativeR2BackdropTracker` ("Shared with the sheets lane: reuse, don't fork").
- motion-r1 is **not merged** into `ui/combined-r7` yet, so its two files are **copied byte-identical** (same type
  names, same paths; git blob ids match, so the later merge is a no-op on these files):
  - `App/NativeR2/Motion/NativeR2SheetBackdrop.swift` (blob `bc0f7c997`)
  - `App/NativeR2/Motion/NativeR2Motion.swift` (blob `5393a5658`, needed for `NativeR2Flags.motion`; self-contained)
- `CYSheet.swift` no longer draws anything: its root host applies `nativeR2SheetBackdrop(isPresented:)` and every
  presented sheet reports its height with `nativeR2SheetBackdropSource()`. My earlier material-ramp drawing is gone.

## What was built
| Piece | Where |
|---|---|
| `NativeR2Flags.sheetBackdrop` (`nativeR2.sheetBackdrop`, default on; off = plain system `.sheet` / `.fullScreenCover`, host is a pass-through, nothing registered). The shared modifier additionally requires `NativeR2Flags.motion` | `App/NativeR2/Motion/CYSheet.swift` |
| `PresentationBackdrop` (`@MainActor @Observable`): set of presentations up from one layer → `isPresenting`; activate/deactivate with a sheet-like spring (`response 0.5, damping 1`), instant under Reduce Motion | same |
| `cyPresentationBackdropHost()`: injects the model (`\.presentationBackdrop`) and applies motion-r1's `nativeR2SheetBackdrop(isPresented: isPresenting)` (blur 2 → 16 pt by detent fraction, wash white 0.92 → 0.15 / dark black 0.6 → 0.1, Reduce Motion = wash only, hit-testing off, hidden from VoiceOver) | same + `NativeR2SheetBackdrop.swift` |
| `cySheet(isPresented:onDismiss:content:)`, `cySheet(item:onDismiss:content:)`, `cyFullScreenCover(isPresented:onDismiss:content:)`, `cyFullScreenCover(item:onDismiss:content:)` — Apple's exact generic signatures (`@ViewBuilder`, `@escaping`, `Item: Identifiable`) | `CYSheet.swift` |
| Registration starts when the binding flips (not on content appear) and ends as the dismissal starts; content `onDisappear` is the safety net | same |
| Nested sheets: each presented content is its own host, so a sheet presented from a sheet blurs the sheet under it (`nativeR2SheetBackdropSource()` sits outside the inner host, so it reports to the presenter's tracker) | same |
| Root host installed once on the `WindowGroup` root (covers the session root and every fixture root) | `App/QuestifyApp.swift` |

Sheets keep system detents, grabber and dimming. `.alert`, `.confirmationDialog`, `.popover` untouched.
Name note: `CYSheetModal.swift` already has a styling modifier `cySheet(detents:selection:)`; the new overloads differ
by argument labels (`isPresented:` / `item:`), so there is no ambiguity.

## Codemod
Script: `tools/codemod_cy_sheet.py` (idempotent; `--check` exits 1 if anything is left; `--json` summary).
Lexes Swift (line/nested block comments, `"…"`, `"""…"""`, raw `#"…"#` strings) so only code is touched; rewrites
only the receiver name; a call is rewritten only if its labels ⊆ {isPresented | item, onDismiss, content}.

| Count (at `ui/combined-r7` @ `169f2904e` merged) | Value |
|---|---|
| SwiftUI `.sheet(` call sites in `App/` | 636 |
| `.sheet(` → `.cySheet(` | **630** |
| `.fullScreenCover(` → `.cyFullScreenCover(` | **22** (of 22) |
| Skipped: labels outside Apple's signature (possible type-inference change) | **0** |
| Skipped: already followed by motion-r1's local `.nativeR2SheetBackdrop(` (would blur twice) | 0 now; 3 once motion-r1 merges (`NativeGameShell` result, `PlayExperienceView` punch + stage result — verified against `origin/native-r2/motion-r1`) |
| Skipped: byte-pinned files (sha256 contracts on protected deliveries; pin owner must opt in) | **6** sheets in 3 files, see below |
| Skipped: SwiftUI calls inside `Tests/` (codemod walks `App/` only and excludes any `Tests` path) | 3 (`Tests/AppUnitTests/RoamPlaceDetailReadLifetimeTests.swift:169`, `CoopFinancePresentationClosureTests.swift:50`, `RoamShareNativeLifetimeTests.swift:176`) |
| Not a presentation modifier, left alone (`kind.sheet(locale:)`, `CYSheetModalTokens.sheet(in:)`) | 2 |
| Contract literals following the rename (`--contracts`, strings in `Tests/ContractChecks/*.py` that quote App source) | 114 in 71 files (+1 hand fix) |
| First run on `8f7d9c365` / re-run after merging `169f2904e` | 631 + 22 / +3 newly merged sites |
| Remaining after run (`--check`) | 0 |

### Skipped, byte-pinned (keep Apple's `.sheet`; no backdrop until the pin owner updates the hash)
| Call site | Pin |
|---|---|
| `App/CharacterCardReadbackView.swift:62` | sha256 manifest, `test_c02_world_party_character.test_sha256_manifest_covers_exclusive_sources` |
| `App/PublishingModesViews.swift:240, 271, 276, 981` | suffix sha256, `test_activity_publishing_wizard.test_untouched_publishing_slices_and_activity_handoff` |
| `App/WorkshopPaidInstalledTextView.swift:28` | sha256, `test_workshop_protected_text_lifecycle.test_all_product_bytes_match_original_protected_consumer_delivery` |

To opt them in: delete the entry from `BYTE_PINNED` in the script, re-run it, and update the three hashes with a
"presentation-only" note (precedent: the native r2 comment in `test_workshop_protected_text_lifecycle.py`).

Brief said 638 + 22; `8f7d9c365` had 637 SwiftUI `.sheet(` sites, `169f2904e` has 636 (r9-player-content dropped one). Byte check: reversing the rename
reproduces every changed App file exactly (only the receiver name changes).

## Gate scripts updated for the rename (string literals only)
`tools/check_a11y_lint.py` (treat `cySheet` / `cyFullScreenCover` as view-builder containers like `sheet`),
`tools/check_media_destinations.py`, `tools/check_merchant_template_assist.py`,
`tools/check_native_navigation_completion.py`, `tools/check_native_verification.py`,
`tools/check_search_map_date_picker.py`.

## Gates (after merging `169f2904e`)
- `python3 tools/generate_project.py` → project regenerated (3 new files under `App/NativeR2/Motion/`).
- `python3 tools/check_scaffold.py` → `PASS structural checks: 5170 Swift source files, 19337 bilingual keys, references, scheme, read-only expected project equivalence`
- `python3 -B tools/check_a11y_lint.py` → `PASS accessibility lint: 0 new, 0 current` (`cySheet` / `cyFullScreenCover` added to its view-builder container list).
- Contract ratchet on `8f7d9c365` (branch vs a base worktree): base 239 failing → first pass 287 (48 new, all source
  contracts quoting `.sheet(` / `.fullScreenCover(` or sha256-pinning App files) → after `--contracts`, the byte-pinned
  skips and one hand fix → **0 new, 0 fixed vs base**. Hand fix:
  `test_native_presentation_reuse.test_camera_and_scanner_remain_full_screen_and_cancelable` forbade any `.cySheet(`
  after the rename, which also matched the pre-existing `.cySheet(detents:)` chrome; it now forbids only presenting
  calls (`.cySheet(isPresented` / `.cySheet(item`).
- Contract ratchet `--check` after the merge: in progress at this push (branch vs base worktree @ `169f2904e`; the repo baseline file is stale: 186 listed vs ~240 actually failing on combined-r7)

## Not run here (Linux container)
Swift compile, simulator, screenshots, VoiceOver. The coordinator's `build_sim` is the first compile of this lane.
Risks to watch in that build: none expected from the codemod (signatures identical); in `CYSheet.swift` watch
`onChange(of:initial:)` on `Item.ID?` and the `ModifiedContent<SheetContent, PresentationBackdropRegistration>` closure types.
When motion-r1 merges: its two copied files are identical (no conflict); re-run `python3 tools/codemod_cy_sheet.py --contracts`
and its three local-backdrop sheets are logged as skipped instead of rewritten.
