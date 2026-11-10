# PAGE-READY `pages/search2/index`

Lane CB268. Base `rc/20261108` `86fa48b0c5833bbadd97c09f246ad05f7af1b8b0`. Native host `App/GlobalSearchView.swift`. Map status: exists.

Player lanes stay topic, activity, and club. No merchant-only search copy was added. `pages/search2/index` was not added to `verifiedBaselineTargetsByRoute` and is not marked live. Views, ui-strings JSON, the catalog, the Xcode project, and the ledger were not edited. The model is in `Core/GlobalSearchRecommendedKeywords.swift`, which is already a member of the app target.

## Model

`GlobalSearchEntryReadiness` reads an existing `GlobalSearchResults` value. It does not open a session or a new endpoint.

- First read with no snapshot is `loading`.
- A configured entry with no search yet is `ready` (history, recommendations, map). That is not an empty result.
- A successful player snapshot with no player rows is `empty`. Each player count is `"0"`.
- Reader not configured uses the existing key `searchMap.notConfigured`. Every player lane failed uses `searchMap.allFailed`. Every player lane gated uses `searchMap.partialSignIn`. Any other caller-supplied issue key is passed through only when no snapshot exists.
- A mix of failed and gated player lanes, or one unresolved player lane beside successful empty lanes, is `unknown`.
- An unresolved player lane (failed or gated), including one that still has retained rows, has count text `—` (U+2014). The total is `—` if any player lane is unresolved. `GlobalSearchResults.count` is unchanged and can still be `0`.
- Merchant is outside this model. `countText` for `.merchant` is nil. Merchant rows are not added into the player total. A merchant failure does not make a successful player total unknown.
- An unread category directory is `unknown`, and its count text is `—`. A loaded directory with no rows is `empty` and `"0"`. Failure uses the existing key `searchMap.categoryFailed`.

## Missing keys

User-facing lookups in `App/GlobalSearchView.swift`, `App/SearchMapComponents.swift`, and `App/SearchMapFilterSheet.swift` are present in `Resources/Localizable.xcstrings`. No catalog key is missing.

`searchMap.kind.` is a prefix. The catalog already has `searchMap.kind.topic`, `searchMap.kind.activity`, `searchMap.kind.club`, and `searchMap.kind.merchant`.

These literals are accessibility identifiers. They are not catalog copy, and they are absent from every `Resources/*.xcstrings` table:

- `globalSearch.category.loading`
- `merchant.discover.entry`
- `searchMap.category.empty`
- `searchMap.category.failed`
- `searchMap.category.loading`
- `searchMap.category.retry`
- `searchMap.filter.apply`
- `searchMap.filter.cancel`
- `searchMap.filter.category`
- `searchMap.filter.end`
- `searchMap.filter.invalid`
- `searchMap.filter.max`
- `searchMap.filter.min`
- `searchMap.filter.reset`
- `searchMap.filter.start`
- `searchMap.guestGate`
- `searchMap.issue`
- `searchMap.keyword`
- `searchMap.more`
- `searchMap.submit`

## Tests

Authored in `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift`. Existing search tests were not edited.

- `testPlayerScopeIsTopicActivityAndClub`
- `testKnownZeroStaysZeroAndUnresolvedLaneIsEmDash`
- `testRetainedRowsDoNotTurnAFailedLaneIntoAConfirmedCount`
- `testSuccessfulCountsSumOnlyPlayerLanes`
- `testMerchantFailureDoesNotChangeASuccessfulPlayerTotal`
- `testPlayerDenialsUseExistingKeysAndDoNotBecomeEmpty`
- `testFirstReadLoadingErrorAndIdleEntry`
- `testUnreadCategoryDirectoryIsUnknownNotZero`

## Left

- `App/GlobalSearchView.swift` still appends `value.count(kind)`. A failed or gated lane with no rows still shows `0` on screen. `countText` is not called from the view.
- `GlobalSearchParityPresentation.resultTabs` still takes `Int` counts, defaults an omitted count to `0`, and hides a zero badge. Existing tests lock that. It cannot represent an unknown count.
- `GlobalSearchParityPresentation.placeholderCopy` and `emptyQueryHint` still mention 商家. They were not rewritten. The player field already uses `searchMap.placeholder.player`.
- `GlobalSearchResults.allFailed` still means all four kinds, including merchant. The player phase does not use that flag.
- Category recovery in `Core/SearchMapReading.swift` is unchanged. The directory phase above is a separate reading of the same loaded / failed / loading facts.
- No Swift test was executed here. `xcodebuild` was not run.
