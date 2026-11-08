# Re-point report 08

Branch `cloud/rp-08` from `origin/wip/gate-allowlist` (0a84de0c). NOT COMPILED. No Swift files added: no route in this chunk has a production equivalent that maps to the existing iOS types without inventing data.

Caveats: commit `014fc0d8` is not in the `chengyin` checkout; production was read as `origin/master` 5e23cd52 (no `native/*`, `onboarding`, `progress/*`, `reward-pledge`, `state-requests`, `city-orientation` routes there). Line numbers are from that commit and may differ from the Appendix. be-gNN branches are NOT deployed; names marked `check` or `not confirmed` were found by file grep only.

| iOS route | production equivalent / evidence | note | status | closest undeployed branch |
|---|---|---|---|---|
| `/api/native/blacklist/list` | — | none on production (`/api/im/block`,`/unblock` only; no list) | TRUE-GAP | cloud/be-g13 (not deployed) |
| `/api/native/blacklist/current` | — | none on production | TRUE-GAP | cloud/be-g13 |
| `/api/native/blacklist/receipt` | — | none on production | TRUE-GAP | cloud/be-g13 |
| `/api/native/blacklist/unblock` | POST /api/im/unblock, form `target_member_id`, response `AjaxResult{msg}` only (`ApiImController.java:217`); mini-program calls /api/im/block (xcx grep `api/im/block`) | iOS contract needs peer_id+expected_block_id+request_id JSON and a receipt with outcome; production returns no block id/receipt, so a receipt would have to be invented | NEEDS-OWNER | cloud/be-g13 |
| `/api/native/blacklist/settle` | — | none on production | TRUE-GAP | cloud/be-g13 |
| `/api/native/channels/read-through` | — | none | TRUE-GAP | cloud/be-g13 |
| `/api/native/device/enroll` | — | none; mini-program has no device enrolment | TRUE-GAP | cloud/be-g37 `ApiNativeDeviceController` (check) |
| `/api/native/device/enrollment-challenge` | — | none | TRUE-GAP | cloud/be-g37 `ApiNativeDeviceController.java:21` |
| `/api/native/device/revoke` | — | none | TRUE-GAP | cloud/be-g37 (check) |
| `/api/native/device/status` | — | none | TRUE-GAP | cloud/be-g37 (check) |
| `/api/native/home` | — | none; no mini-program equivalent | TRUE-GAP | cloud/be-g01 `ApiPrivateHomeController.java:22` |
| `/api/native/home/return` | — | none | TRUE-GAP | cloud/be-g01 `ApiPrivateHomeReturnController.java:20` |
| `/api/npc/chat/delete` | POST /api/ai/npc/chat/data/delete, no params, `{deleted:n}` (`ApiAiNpcController.java:411`) | iOS string is a default-blocked sensitive path in the regional deny-list (App/RegionalEndpointAllowlistSectionView.swift:74), not a call; hard-deletes all NPC chats. Unblocking is a policy call | NEEDS-OWNER | — |
| `/api/official/v2/events` | GET /api/official/v2/events/{id}/publish-check is served (`ApiOfficialEventController.java:272`) | iOS string at AppCompositionRoot.swift:3922 is only the prefix of that served route; no bare route needed | ALREADY-SERVED (no change) | — |
| `/api/official/v2/organizer-invites/{}/{})` | POST .../organizer-invites/{partyId}/accept|decline, JSON body optional (`ApiOfficialEventController.java:154,164`) | Appendix artefact (description-text row). Real iOS path (OfficialActionContracts.swift:107) already equals the served path | ALREADY-SERVED (no change) | — |
| `/api/onboarding/get` | — | none; xcx component has `TODO(backend)` for merchant onboarding (club-topic-onboarding/index.js:14) | TRUE-GAP | cloud/be-g31 (route not confirmed) |
| `/api/onboarding/submit` | — | none | TRUE-GAP | cloud/be-g31 (route not confirmed) |
| `/api/pay/create` | closest: POST /api/registration/pay (`ApiRegistrationController.java:233`, already in Adapt5 deny-list) | Deny-list string, not a call; money movement, out of scope | NEEDS-OWNER | — |
| `/api/play/advanced/time-window` | — | none | TRUE-GAP | cloud/be-g26 `ApiPlayG26Controller` |
| `/api/play/city-orientation` | — | none | TRUE-GAP | cloud/be-g26 (base read not confirmed) |
| `/api/play/city-orientation/answer` | — | none | TRUE-GAP | cloud/be-g26 `ApiPlayG26Controller.java:57` |
| `/api/play/city-orientation/receipt` | — | none | TRUE-GAP | cloud/be-g26 `ApiPlayG26Controller.java:70` |
| `/api/play/egg/collect` | — | none; eggs removed (ApiConfigController.java:48 comment) | TRUE-GAP | no be-gNN branch found |
| `/api/play/route-action` | nearest: GET /api/play/route-state (`ApiPlayProgressController.java:1007`) | different semantics: takes topicId/activityId, iOS sends sessionId/memberId/actionId and checks them in response | TRUE-GAP | cloud/be-g26 |
| `/api/privacy/progress` | — | none | TRUE-GAP | cloud/be-g35 `ApiPrivacyProgressG35Controller.java:21` |
| `/api/progress/meter` | — | none | TRUE-GAP | cloud/be-g26 `ApiProgressG26Controller.java:28` |
| `/api/progress/requests` | — | none | TRUE-GAP | cloud/be-g26/g28 |
| `/api/progress/requests/{}` | — | none | TRUE-GAP | cloud/be-g26 `:41`, g28 `:26` |
| `/api/project/state-requests/context` | — | none; xcx `ui-state-request.js` is a UI helper, not this ledger | TRUE-GAP | cloud/be-g30 |
| `/api/project/state-requests/read` | — | none | TRUE-GAP | cloud/be-g30 |
| `/api/project/state-requests/submit` | — | none | TRUE-GAP | cloud/be-g30 |
| `/api/registration/original-event` | — | none | TRUE-GAP | cloud/be-g35 `ApiRegistrationOriginalEventG35Controller.java:33` |
| `/api/registration/pay` | POST /api/registration/pay, param `id` (`ApiRegistrationController.java:233`) | iOS ref is the Adapt5 deny-list (Adapt5HighRiskWriteSupplement.swift:11); payment, not repointed | NEEDS-OWNER | — |
| `/api/reward-pledge` | — | none | TRUE-GAP | cloud/be-g10/g16/g19 |
