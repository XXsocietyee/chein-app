# Cloud stubs — orient score entry (ledger row 11)

Branch `ui/cloud-stubs-orient`. Parent `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Stub-ledger row 11 only. Row 27 (`OrientScoreReviewFactory.makeSubmitter`, appeal / dispute) is not built. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged.

## What the payload already has

`ParticipationDetail` is the `/api/registration/info` object. The same object already carries the ids `_resultEntry()` reads (`chengyinhub-xcx` `scene-member-participation-detail` and `utils/user-character.js` `registrationTopic`). They are now stored on the detail. No id is copied from the registration id, and a topic id is not reused as an activity id.

| Field | Where it is read |
|---|---|
| `topicID` | Owner type 1: `cmsTopic.id` only when it equals `ownerId`. Owner type 2: `cmsActivity.topicId` only when `cmsActivity.id` equals `ownerId`. A top-level `topicId` that is present and is not 0 must match, or the topic id is dropped. |
| `activityID` | Owner type 2: that same `cmsActivity.id`. Owner type 1: `0` after the topic id matches. The mini program sends activity id `0` for owner type 1. `OrientSessionService.current` already treats `0` as self-play, not as an activity record. |
| `productType` | `cmsActivity.productType` when that object is present, otherwise `cmsTopic.productType`. Only a JSON integer or an exact digit string is kept. A bool is not turned into 1. |

An id that is missing, zero (except the owner-type-1 self-play activity id above), fractional, or inconsistent stays nil. A registration with none of these fields decodes with all three nil, and the loader stays nil.

## Loader

`OrientScoreEntryBinding.makeLoader` takes the detail and the signed-in `AppSession`. `OrientScoreEntryProduction` returns a loader only when `productType` is 1, both ids are present (`activityID` may be 0), and `memberId` on the order equals `session.account.id`. Otherwise it returns nil and does not call the provider.

When those hold, the loader is the existing `AppSession` `OrientScoreEntryProviding` method in `App/CloudB3Production.swift`. That method calls `OrientSessionService.current(topicID:activityID:)` and then `score` only when the current response has exactly one session. It does not call sync, settle, appeal, or dispute.

The entry view asks for `AppSession` only after `canAskSession` is true, so a participation fixture that has no product type and no member id does not require the environment object.

## Checks

`python3 tools/check_design_lint.py` passed. `python3 tools/check_scaffold.py` passed (catalogs, release config, privacy, design lint, project equivalence, AppSession ratchet, page route table). This VM has no Swift compiler, so the new `ParticipationOrientScoreEntryTests` were not executed.
