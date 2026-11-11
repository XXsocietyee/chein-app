# square-optional-count-tests

Branch `ui/e1s`, base `5e2aeabb1`. Core tests only; not compiled or run here (no builds by instruction).

- Searched `Tests/` for old-contract expectations of `SquarePost.likeCount/commentCount` and `SquareComment.likeCount` as `Int` (compared with 0, 0-valued text, `SquareCountDisplay`). None found: `SquareDetailInteractionTests`, `CoreGapReaderBodyTests` and `AccountCollectionTests` already assert nil -> em dash, known 0 -> "0". No existing test was changed.
- Added `SquareOptionalCountModelTests`: model-level nil vs 0 for post and comment (omitted, null, negative, numeric string = nil; literal 0 = 0), `likeNum` alias, `SquareCountDisplay.text`.
- Not resolved: the 8 Square detail failures, 2 NativeChannel original-writer journal failures and 1 SquareReport case-reference failure reported by the integrator. Exact failing test names were not available; waiting for them.
