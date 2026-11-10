# Receipt: view state machines

- Added `App/DesignSystem/CYPhase.swift` (`CYPhase`, `CYPhaseKind`, `CYPhaseView`) and registered it in the generated project.
- Migrated boolean load flags to `CYPhase`: TopicDetailView, ActivityDetailView, SquareBrowserView, MessagingHistoryView (two machines), GlobalSearchView, RoamBrowserView.
- Player pattern grep (`isLoading &&`, `loading &&`, `error == nil &&`): the easy view-local hits were migrated; model-object flags (`model.isLoading`) are Core-owned and untouched.
- Docs: `docs/release/state-machines/views.md`.
- Verification: code-only. `check_scaffold.py` and `check_design_lint.py` pass; cloud build status recorded below.
- Cloud: Build - iOS green (145 warnings, same as base) on 89aac32af and 379ca525c. Test - iOS reports 2 GLTFKit2 module errors identical to the base commit 9a27f7915 (infra, not from this change).
