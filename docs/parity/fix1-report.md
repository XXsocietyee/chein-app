# FIX1 report (fix wave 1, blockers, endpoints, UGC safety)

Base `7c2d22f6` (`origin/wip/gm-plan`), branch `wip/gm-fix1`. Skipped: every OWNER-ONLY and BACKEND-GAP item.
No `.gitleaksignore`, workflow, `.xcstrings` or `reviewed:` default was changed.

## Evidence

Built and tested at `3efdcbb7`; the commit after it only adds this file.

- Build (`Questify`, Debug, iOS Simulator, `CODE_SIGNING_ALLOWED=NO`): `** BUILD SUCCEEDED **`, `BUILD_EXIT=0` (`/private/tmp/fix1-build-final.log`).
- AppUnit (`Questify-iPhone17-W2`), `/private/tmp/fix1-test-final.log`:
  - `AccountDeregistrationHostLifetimeTests`: `Executed 12 tests, with 0 failures (0 unexpected)`
  - `ClubOrdinaryAdmissionCompositionTests`: `Executed 2 tests, with 0 failures (0 unexpected)`
  - `G1ProductionGatesEndToEndTests`: `Executed 9 tests, with 0 failures (0 unexpected)`
  - total `Executed 23 tests, with 0 failures (0 unexpected)`, `** TEST EXECUTE SUCCEEDED **`, `TEST_EXIT=0`
- Core (`swift test --disable-sandbox --filter ...`), `/private/tmp/fix1-core-final.log`: `Executed 224 tests, with 0 failures (0 unexpected)`, `CORE_EXIT=0`
  (RegionalConfiguration, AccountDeregistration*, AccountCompliance, OrderLifecycle*, NativeAttributeAuthorRouteTable, ChannelDiscordMessaging, ChannelSafetyFailClosed, WorkshopDigitalChannelPolicy, NativeEntryRouting, ScanRouter, ExternalGameImport, DeregistrationStatusRules).
- Python contract checks: new files all pass. The whole `Tests/ContractChecks` suite was run at base and at the branch (5652 vs 5683 tests); the only failure present on the branch and not on base was `test_order_lifecycle_production` (two cases), which was a real regression from the first FP-E4 draft and was fixed in `3efdcbb7`. The remaining failures are the same ones that fail on base (for example `test_profile_reload_discard`, 5 hash-pin cases, and `test_new_bilingual_keys_are_keyed_additions`).

## Per-ID status and commits

| ID | Status | Commit | Test |
|---|---|---|---|
| FP-B1 | Done: `Config/Questify.entitlements` (Sign in with Apple only), `CODE_SIGN_ENTITLEMENTS` on the app target's Debug and Release. App ID capability stays FP-O1. | `4be7b4e3` | `test_entitlements_contract.py` |
| FP-B4 | Done as a draft from code evidence: Name, EmailAddress, PhysicalAddress, PurchaseHistory, Fitness, DeviceID added; PaymentInfo not added. Owner confirms the final list (FP-O4). | `4c4f71ad` | `test_privacy_manifest_contract.py` |
| FP-B5 | Composition proof only: reviewed China composition gives Settings a real coordinator and reads `GET api/user/deregister/status`; unreviewed composition stays on the unavailable fallback. The release flag value is the owner's (FP-O6); the shipped `RegionalLaunchConfiguration.composition` is still the unconfigured one. | `197de30f` | `G1ProductionGatesEndToEndTests` (2 new), `test_deletion_settings_composition.py` |
| FP-E1 | Already satisfied: `usernamePassword` is not an implemented capability, so it is never `.available`. Pinned, no code change. | `75935e02` | `RegionalConfigurationTests` |
| FP-E2 | Done: receipt derived from `GET status` (ACCEPTED only after this client sent `apply` and status is PENDING; otherwise UNKNOWN, never a guessed rejection). Seam: `AccountDeregistrationOriginalClient.receiptSource = .resultEndpoint`. Limit: after a cold launch the receipt stays UNKNOWN because `status` cannot attribute an application to a request id; `recoverDeregistrationStatus` still shows the PENDING state. Existing /result fixtures set `.resultEndpoint`, assertions unchanged. | `cc9439c7`, `88020e7e` | `AccountDeregistrationRebaseSafetyTests` (2 new) |
| FP-E4 | Done: stale or revoked consent is now `.reconsentRequired` (was generic `.ineligible`), with an explicit "Agree and continue" action that POSTs the signup consent and re-reads it; `pay/app` is never called by it. The request builder lives in `OrderLifecycleRequestContract` to keep the dispatcher free of consent-write literals. | `d69ac51c`, `3efdcbb7` | `OrderLifecycleProductionTests` (2 new) |
| FP-E5 | Partly done: route/method table and dormancy pinned. **Not done:** re-pointing definitions to `GET /api/topic/attributes`, because its response shape is not verified here and the author service decodes versioned definitions. Author POST stays dormant (no approval, no capability by default). | `42520cde` | `NativeAttributeAuthorRouteTableTests` |
| FP-E6 | Done for the club catalog (metadata only, no consumer): verified routes renamed, the rest moved to `nativeOnlyEndpoints`. The address base was a PREFIX row (real paths MATCH). Map public layers, merchant offer withdrawal, play egg, follow list and original event stay gated (no route). | `42520cde` | `test_club_catalog_routes.py` |
| FP-E7 | Done: AN-1 route table checked in as `Tests/ContractChecks/fixtures/backend_route_status.csv`; every default grant must be MATCH; NO-BACKEND allowlist entries are a reviewed baseline (37 today); one construction site. Mutation-checked. | `6d3a033e` | `test_allowlist_routes_have_backend.py` |
| FP-C3 | Done: `NativeContentTarget` intents for activity, club, topic, template, post, POI, roam session from the mini-program source paths; canonical positive `id` only; no origin enabled; landing view shows the unsupported screen. | `28b331ba` | `NativeEntryRoutingTests` (2 new) |
| FP-C5 | Done: the fixture used a `.invalid` host, which `APIConfiguration` rejects by design; fixture host changed, assertions and the guard unchanged. | `b362918e` | `ClubOrdinaryAdmissionCompositionTests` |
| FP-C7 | Done as a pure router (`ScanRouter`), not wired into a scanner view. Door scan stays off. | `78344e6f` | `ScanRouterTests` |
| FP-C10 | Done: `gated` status, `tools/check_page_map_gated.py`, 14 rows moved from `exists` to `gated`; `PushTapRouter` seam that routes nothing until a reviewed payload key is given. Not wired into `AppSession` (G1-owned). | `a9d848d8`, `3b4f5045` | `test_page_map_gated_status.py`, `NativeEntryRoutingTests` |
| FP-H2 | Already satisfied: the club channel block dispatches `api/im/block` (MATCH) and caches locally only after confirmation. `api/ugc/block` has no backend route, so it is not used. Added the no-service case. | `d2fcde66` | `ChannelSafetyFailClosedTests` |
| FP-H3 | Partly done: Settings > Support and safety row (draft objectionable-content clause, link to the server-provided support contact, no SLA). **Not done:** report entries for topics, topic reviews, activity reviews, club discussion comments and avatars. They need reviewed transport grants composed in `AppSession`; see `fix1-ugc-report-gaps.md`. Clause text, SLA and contact are FP-O7. | `139a8b38` | `test_ugc_surfaces_report_entries.py`, `test_settings_support_safety_entry.py` |
| FP-H4 | Done: Report (share sheet with a plain summary, no invented address) and Block (package and creator, persisted, blocks import and run) in the runner; `allowedDomains` default empty; non-manifest domains refused. | `db86d63d` | `ExternalGameImportTests` (3 new) |
| FP-H5 | Done as assertions: a digital-product approval can only name `APPLE_STOREKIT` on `IOS`; workshop commerce has no WeChat or wallet path. | `f77f45e9` | `WorkshopDigitalChannelPolicyTests`, `test_digital_goods_storekit_only.py` |

New user-facing strings are listed in `fix1-new-strings.md` for FIX2.
