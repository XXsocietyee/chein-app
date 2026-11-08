# UI-10 report — shared states and chrome (NOT COMPILED)

| Screen / file | What changed | Follows | Theme | New string keys |
|---|---|---|---|---|
| `App/DesignSystem/CYSharedStates.swift` (NEW) | `CYSkeletonBlock` (quiet shimmer, off under Reduce Motion), `CYLoadingStateView` (skeleton cards, one VoiceOver label), `CYOfflineBanner` (inline, optional retry, 44pt target, wraps at large Dynamic Type), `.cyToast(message:)` (bottom capsule, auto-dismiss). Dark and light `#Preview`s with synthetic data. | Revolut pattern (mini-program has no equivalent) | both (colours via `CYColor` only) | `cy.state.loading`, `cy.state.offline.title`, `cy.state.offline.retry` |
| `docs/release/ui-strings-ui-10.json` (NEW) | en + zh-Hans strings for the keys above | — | — | 3 |

## Not done
- Components are NOT wired into existing screens (kept diff small and non-breaking; no signatures changed). Adoption by screens is for the topic agents/integrator.
- Existing `CYEmptyStateView` / `CYErrorStateView`, tab bar and nav bar were not modified. Confirmation sheets were not added: native `.confirmationDialog`/sheet + `presentationDetents` already fit.
- Pull to refresh: system `.refreshable` already used; no custom component.
- Not compiled; Swift APIs were copied from neighbouring code patterns. Toast `Binding<LocalizedStringKey?>` requires `LocalizedStringKey` equality only via `message != nil` (no Equatable needed).

Files touched: 3 (all new). New component files: 1. New string keys: 3.
