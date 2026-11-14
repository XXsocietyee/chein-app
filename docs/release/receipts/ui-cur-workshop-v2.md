# ui/cur-workshop-v2

Handover 32. Parent `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46` (`origin/ui/main`).

`docs/release/receipts/workshop-purchased-v2-contract-diff.md` is not in that commit. curl NOT RUN. No SSH to TEST 8120 or 8121. No credentials copied. No response body was fetched, so this receipt does not contain a curl transcript.

Shapes below are pinned from the public hengyin sources kept beside this work (`WorkshopService.java` / `ApiWorkshopController.java`, commit `8390d99e3f7a54899c493ecb3d70e9aa8f57dbca`). They are the v2 field set the missing diff names. They are not a live server capture.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. `ReviewedAreaSwitch` is not redeclared. Paid installs call `ReviewedAreaSwitch.moneyPayments(apiHost:)`. The property `moneyPayments` is not called. `openMoney` stays false when the host is missing, the build is not TEST/DEBUG, or the host is `www.chengyinhub.com`.

Free owned and player writes stay on the existing player-write path. They are not moved behind the money switch.

swiftc is not on this Linux VM (`command -v swiftc` printed `swiftc missing`). No Swift typecheck was run. This receipt does not claim a green typecheck.

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` both passed.

## Pinned v2 shapes

Ajax envelope `{code, data}`. Reads are `application/x-www-form-urlencoded; charset=utf-8`. Install submit stays raw JSON.

| Route | Form | Data |
|---|---|---|
| `api/workshop/v2/purchased/list` | optional `before_order_line_id` | `workshop-purchased-v2`, `scope` `INDIVIDUAL`, `checkedAt`, `items` (license view), `hasMore`. `nextBeforeOrderLineId` only when `hasMore` (positive Int64, page 50). |
| `api/workshop/v2/purchased/detail` | `license_id` | Bare license view. No schema, scope, item, or checkedAt wrapper. The UI checkedAt is an em dash (`U+2014`). |
| `api/workshop/v2/purchased/install/targets` | `license_id`, optional `before_draft_id` | `workshop-targets-v2`, `INDIVIDUAL`, `checkedAt`, `items`, `hasMore`. `nextBeforeDraftId` only when `hasMore`, equal to the last item id. No licenseId on the envelope. |
| `api/workshop/v2/purchased/install/history` | `license_id`, optional numeric `before_command_key` | `workshop-install-history-v2`, `INDIVIDUAL`, `checkedAt`, outcome items, `hasMore`. `nextBeforeCommandKey` is the install row id, only when `hasMore`. |
| `api/workshop/v2/purchased/install/status` | `request_id` | Outcome. `NOT_FOUND` is only `{schema, requestId, state}`. |
| `api/workshop/v2/purchased/install/submit` | JSON body | Command schema `workshop-private-draft-install-command-v2`. |
| `api/workshop/v2/purchased/installed-text/detail` | `license_id` then `request_id` | `w18-member-text-v1`, empty `bindings`, plus title, description, ruleInstructions, merchantGuide, questionName, questionAnswer, hint1, hint2, answerReveal. Null strings are absent. |

License view: `licenseId` is `order_no`, `WKO_[a-f0-9]{32}`. The `w18-paid-<N>` requirement is gone. `moduleId` is a JSON number (stored as a decimal string). `purchasedVersionId` stays a bounded string. `contentHash` and `termsHash` are 64 hex chars. Status is `ACTIVE`, `SUSPENDED`, or `REVOKED`. `commercialUse` is `ALLOWED` or `PROHIBITED`. `adaptation` is `LOCAL_ADAPTATION` (the decoder also accepts `BIND_RESOURCES_ONLY`). `translation` is `PROHIBITED`. `allowedRegions` is 1–100 values of `[0-9]{6}`. `themeLimit` is `{unlimited:false, maximum>=1}`. `merchantLimit` and `runLimit` are `{unlimited:false, maximum:0}`. `acquisition` `PAID`, `buyerKind` `INDIVIDUAL`, `useDuration` `PERPETUAL_PURCHASED_VERSION`, `updates` `EXACT_PURCHASED_VERSION`, `redistribution` `PROHIBITED`, `contentUseStatus` `PRIVATE_DRAFT_INSTALL_AVAILABLE` or `LICENSE_DISABLED`, `purchaseActionStatus` `EXACT_VERSION_PURCHASED`. `permitsContentUse` and `permitsPurchase` stay false.

Target item: `targetDraftId`, `targetRevision`, `targetPayloadHash`, `businessType` `MEMBER_TEMPLATE`, `title` (may be empty, ≤256 utf8, no controls). Local `mode` `UNRESOLVED` and `destinationKind` `W18_PRIVATE_COMPONENT_ONLY` stay off the wire.

Command: `requestId` (UUID), `licenseId`, numeric `moduleId`, `purchasedVersionId`, `contentHash`, `termsHash`, `targetDraftId`, `targetRevision`, `businessType` `MEMBER_TEMPLATE`, `targetPayloadHash`, `planningRegion` `[0-9]{6}`, `commercialUse` bool.

Installed outcome: schema `workshop-private-draft-install-outcome-v2`, state `INSTALLED_PRIVATE_DRAFT`, the command fields, `holdDeadline`, `ownedDraftId` > 0, `installedAt`, `mode` `PRIVATE_COPY`, `professionalTemplateStatus` `MATERIALIZATION_REQUIRED`, `published` false, `executable` false. Other client states (`PREPARED`, `RESERVED`, `EXPIRED`, `CANCELLED`, `FAILED`) keep owned draft and installedAt nil.

Installed text is not decoded as the old protected document. Provenance (license, module, purchased version, owned draft, terms, rights) comes from the local reference. `version`, `checkedAt`, and `termsDocumentHash` are `—`. `sourceFields` equals `installedFields`. `matches` is request id + license + module + version + owned draft, plus those fields and `rights.matches(item)`.

Copy for the private-copy result is updated in `WorkshopPaidInstall.xcstrings` and `WorkshopPaidInstalledText.xcstrings` (en and zh-Hans). Unknown stays an em dash.

## Baseline

`docs/release/contract-failing-baseline.txt` was not raised. One line was removed because that pin now matches:

`test_workshop_protected_text_lifecycle.ProtectedTextLifecycleSourceContracts.test_all_product_bytes_match_original_protected_consumer_delivery`

`python3 tools/contract_ratchet.py --check` still exits 1. The 25 new failures are in files this branch does not touch (for example `SessionRegistrationSheet.swift` still lacks the string `test_activity_design_structure` expects). Six baseline ids are reported as now passing even though this diff does not add those tests: five lifecycle method names are already absent on `a2a9d82`, and `test_owned_fixture_normalization_accepts_only_exact_scene_hunks` passes against `WorkshopOwnedNavigationPresentationTests.swift`, which this branch does not edit. Those lines were left in place. `--update` was not run.

Workshop contract modules (`test_workshop_purchased`, `test_workshop_paid_install`, `test_workshop_paid_installed_text`, `test_workshop_protected_text_lifecycle`, `test_workshop_paid_lifecycle_closure`, `test_workshop_paid_reentry_closure`): 68 tests, one failure, `test_upgrade_button_matches_existing_single_request_guard_without_style_dependency`. That id is already in the baseline. The sheet file was not edited.
