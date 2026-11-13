# cloud-stubs-square

Branch `ui/cloud-stubs-square`. Parent `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Rows 18 and 19 only. Share links, route maps, deletion, and bookmarks stay unwired. `App/AppSession.swift` and `App/AppCompositionRoot.swift` were not edited. No follow route was added. The contract-failure baseline was not rewritten.

## 18 — `SquareCompletedActivityProviding`

The activity picker reads `GET` `SquareActivityPicker.completedPath` (`api/play/my-completed`) with `for_public_reference=true`. `PlayerJourneyService.completedForPublicReference` builds that request and decodes `[CompletedPlayRecord]`. `SquareActivityPicker.publicReferenceRows` turns those records into picker rows.

This read does not open the history grant. `completed(token:)` still requires `readsEnabled`, and the session factory still constructs `PlayerJourneyService` without turning that flag on. A missing or non-positive activity id is dropped. A missing name is an em dash (`—` / `—`). A missing count stays nil, and the existing picker draws that nil as an em dash. A literal `0` stays `0`. No preview image is invented.

`SquareCompletedActivityConformer` calls `PlayerJourneySessionReader.completedForPublicReference()` on the session's existing reader. A signed-out caller, a changed account, or a changed session epoch does not keep the rows. 401 still signs that reader out. The call does not post, upload, or select a route snapshot.

## 19 — `SquareAuthorFollowStateProviding`

`SquarePost.isFollowTheUser` is `SquareStravaCard.followed`. That card already reads `isFollowTheUser` / `viewerFollowing`. Missing, or any value other than true/false/`1`/`0`, stays nil. Nil is not stored as false.

`SquareAuthorFollowConformer` answers `isFollowing(memberID:)` from that flag for the signed-in account and session epoch. The avatar menu still opens the existing reviewed `toggleFollow` editor (`SocialActionRequestBuilder` → `api/user/follow/action`). No second follow client was added. When that write's receipt includes `followed`, the same flag updates. An unknown outcome does not flip it.

## Injection

`CloudSquareStubModifier` on `SessionRootView.chain0` sets `squareCompletedActivities` and `squareAuthorFollowState`. It does not set `squareShareLink`, `squareRouteMap`, or `squareDeletion`.

## Copy

No new catalog keys. Unknown counts and a missing activity name use the existing em dash in English and zh-Hans.

## Checks

`python3 tools/generate_project.py`, `python3 tools/check_scaffold.py`, and `python3 tools/check_design_lint.py` passed. `python3 tools/check_player_journey_screens.py` passed. The square detail, mylike, participation-schedule, and square structure contract tests that pin these files passed. This VM has no Swift toolchain, so the new Core tests were not executed and the app was not compiled.
