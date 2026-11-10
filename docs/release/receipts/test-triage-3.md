# Test triage 3 (code-only; no builds or test runs)

Base: origin/ui/main (ee3ffb8d9) vs last cloud-green origin/rc/20261108 @ 201bf147f.
Method: located each failing test and the production types it exercises, then diffed those files
between 201bf147f and ui/main. Core/ and Tests/ have zero changes in that range; Resources only gained
1465 added lines in Localizable.xcstrings (no deletions or edits; the per-feature .strings tables are untouched).

| Class | Verdict | Action | SHA |
|---|---|---|---|
| NativeChannelAppealEntryLocalizationTests | pre-existing / environment | None. Reads `NativeChannelAppealDetails` table from en/zh-Hans lproj bundles; table and test untouched by e1..e5. Likely local lproj/bundle resolution in the test host. | n/a |
| NativeChannelPinLocalizationTests | pre-existing / environment | None. `NativeChannelPinLocalization` (App/NativeChannelMessagePinsView.swift) and `NativeChannelMessage` table untouched; resolves via `String(localized:locale:)` so it depends on test-host localization. | n/a |
| NativeChannelMessageHostBindingTests | pre-existing | None. `NativeChannelMessageHostBinding` and Core untouched. | n/a |
| NativeAttributeAuthorProjectHostTests | pre-existing | None. `NativeAttributeAuthorProjectHost` and `NativeAttributeAuthorCoordinator` (Core) untouched. | n/a |
| IMConversationRowActionsAppTests | pre-existing | None. `IMConversationRowReviewModel` untouched; `MessagingReadScreenModel` untouched. fd2d0f315 only moved the loading view in MessagingComponents to `CYLoadSlot` (view-only, no model change). | n/a |
| ClubCommunityLifecycleTests | pre-existing | None. `ClubCommunityViewModel` (App/ClubCommunityViews.swift) untouched; tests only drive the model. | n/a |

No other `*Localization*` class appears in the failing lists. No test expectation was changed and no
copy assertion was affected by our restyle (no existing key was edited), so nothing was weakened. If a
real run still shows these red, the cause is outside the UI-owned files and needs a trace from a run.
