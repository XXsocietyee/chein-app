# D3 CYPhase adoption (viewstate-candidates)

Branch `ui/e1` worktree DES-e1, merged `origin/ui/main` first. Code-only; cloud Build lane is the gate.

| File | Result |
|---|---|
| TopicDetailView, SquareBrowserView, MessagingHistoryView | already on `CYPhase` (see `docs/release/state-machines/views.md`) |
| ActivityDetailView | `access`/`loading`/`failed` -> `phase: CYPhase<ActivityDetailAccess, Void>`; `access` is now `phase.value`; exhaustive `switch` in `body`; ids/keys unchanged |
| WalletCommerceViews | `WalletScreen` `value`/`failed`/`loading`/`requiresLogin`/`unavailable` -> one `phase: CYPhase<Value, WalletReadFailure>`; read accessors kept, external `loading = true` -> `markLoading()` |
| ClubChannelMessagingView | private `LoadPhase` enum -> `CYPhase<LoadedContext, String>`; same three renders, ids/copy unchanged |
| SessionHomeFeedView, MerchantOnboardingView, MerchantCityNodeHubView, AccountView, RegistrationSheetView, PlayExperienceView | not migrated: their >=3 `@State` hits are independent presentation flags (`showsX`, confirmations) or model-owned state, no loading/error boolean cluster to fold |

Behaviour: unchanged. Mapping keeps the old guards (`generation == operation`, stale success leaves `idle`, disappear while loading -> `idle`, cancellation never fails). Unknown values untouched.

Cloud: first push (3474f19) Xcode Cloud run was cancelled before producing check-runs; re-pushed to retrigger.
