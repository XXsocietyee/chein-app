# ADAPT-6 report (workshop / rewards gap-6 adaptation)

Status: **uncompiled** (no Swift toolchain in the cloud container). Every symbol was grepped; nothing was built or run.
Backend verified against the `/home/user/hengyin` checkout at `147754ba`. The task named `4ac8c249`, which is **not present** in that checkout (`git cat-file` fails), so the controller reads below are against `147754ba` and the doc's line numbers may differ.

## Rows
| Row | Result |
|---|---|
| 56 `/api/{}/cancel` | **Partly done.** Re-verified: `ApiTopicController.topicCancel` POST `/cancel` takes `id, reason, scope, cancellationEpoch(Long, optional)`, login required, errors via `AjaxResult.error(msg)`; `ApiActivityController.activityCancel` takes `id, reason, scope`. The interpolation is replaced by an exhaustive switch (`PublisherCancelRoute`, `Core/PublisherCancelAdapter.swift`); `template` is refused (`forbidden`) in `paidPlayers`, and in `descriptor` it yields an empty path that no grant allows, so `confirm` returns `.notSent`. **Not done:** sending `cancellationEpoch` on the real cancel call. That needs an epoch field on `PublisherLifecycleAction.cancel` or the review. The enum is pinned by existing tests, which I would have to change, so I added only the pieces: `PublisherCancelPreviewData`, `PublisherCancelFields.cancel` and `PublisherLifecycleHTTP.cancelPreviewData`. None of them is wired into the coordinator. |
| 57 `/api/{}/cancel_preview` | **Done.** Topic `cancel_preview` returns `{paidPlayers, cancellationEpoch}`; activity returns `{paidPlayers}` only. `paidPlayers` behaviour is unchanged. |
| 42 `api/rewards/pledge/` | **Done.** Removed the `hasPrefix` branch from the `form` guard. Only the four `api/coupon/*` routes remain allowed. The call site stays on line 516, which `backend_route_status.csv` references. |
| Rows 1-3 (PARTIAL workshop owned) | **Not done.** `claim_id`, cursor paging and the read metadata have no backend counterpart (the doc says they need a backend `claimId`). I found no part that is independent and safe. |
| Rows 4-55 | MISSING, out of scope. |

## Tests
New `Tests/AppUnitTests/Adapt6PublisherCancelTests.swift` (registered in `Questify.xcodeproj`, like `Core/PublisherCancelAdapter.swift`). Fixtures mirror the controllers' `AjaxResult` shapes. They cover: literal routes, template refusal, topic epoch parsing, activity having no epoch, a missing or negative count, cancel fields, and the reward staff route list. Existing tests were not modified.

## Unverified / follow-ups
- Nothing compiled; the pbxproj edits were made by hand (two file refs, two build files, group and sources-phase entries).
- `Tests/ContractChecks/fixtures/backend_route_status.csv` still lists `api/{}/cancel` and `api/{}/cancel_preview` as NO-BACKEND. It is generated, so I left it for regeneration. Its line numbers `PublisherLifecycleHTTP.swift:77` and `:80` are unchanged.
- `Tests/AppUnitTests` assumes the Core sources are compiled into the `Questify` target (the pbxproj lists them there).
- Not verified: the `MERCHANT` scope handling in the activity cancel; the coordinator still forces `scope == nil` for activities.
- Safety gates, `reviewed:nil`, and AppSession / AppCompositionRoot / QuestifyApp are untouched.
