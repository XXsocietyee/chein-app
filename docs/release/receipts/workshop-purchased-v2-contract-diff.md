# Workshop purchased library: v1 (app) vs v2 (TEST r2 067da9748)

On r2 the backend answers every v1 path (`/api/workshop/purchased/list|detail|install/*|installed-text/detail`) with
409 `WORKSHOP_CONTRACT_UPGRADE_REQUIRED`. The coordinator decided the app adapts to v2. This file lists the differences;
the backend source is `ApiWorkshopController` and `WorkshopService` on hengyin `integration/backend-app-r2` 067da9748.

## What already moved in `ui/main`

- `WorkshopPurchasedService` and `WorkshopPurchasedReadRoute` now call `api/workshop/v2/purchased/list|detail`. The form
  fields are the same: `before_order_line_id` and `license_id`.
- **The responses still do not decode**, so the library shows its error state instead of the 409 (see below).

## Differences the app must adopt

| Area | App today (v1) | Backend v2 |
|---|---|---|
| List envelope | `schema: workshop-purchased-owned-v1`, `scope: PAID_INDIVIDUAL_PURCHASED_VERSION_METADATA_ONLY` (`WorkshopPurchasedContracts.swift:93`) | `schema: workshop-purchased-v2`, `scope: INDIVIDUAL`, `checkedAt`, `items`, `hasMore`, `nextBeforeOrderLineId` (number) |
| Detail | enveloped `{item: …}` | the bare license view (no envelope) |
| License id | must match `w18-paid-<N>` (`WorkshopPurchasedWire.license`) | `licenseId` = `workshop_order.order_no` (format chosen by the backend) |
| License view fields | app's v1 item | `licenseId, moduleId, purchasedVersionId, contentHash, termsVersion, termsHash, acquiredAt, status, commercialUse (ALLOWED/PROHIBITED), adaptation, translation, allowedRegions, themeLimit{unlimited,maximum}, merchantLimit, runLimit, acquisition: PAID, buyerKind: INDIVIDUAL, useDuration, updates, redistribution` |
| Install targets | JSON body `{licenseId, beforeDraftId}`; response `w18-paid-install-targets-v1` | form `license_id`, `before_draft_id`; response `workshop-targets-v2` with `items[{targetDraftId, targetRevision, targetPayloadHash, businessType: MEMBER_TEMPLATE, title}]`, `nextBeforeDraftId` |
| Install submit | command `w18-paid-private-text-install-command-v1` | raw JSON command with `schema: workshop-private-draft-install-command-v2`, `requestId, licenseId, purchasedVersionId, moduleId, contentHash, termsHash, targetDraftId, targetRevision, targetPayloadHash, businessType, commercialUse, planningRegion`. The raw bytes are retained, so a resubmit under the same id must be byte-identical. |
| Install outcome | `w18-paid-install-outcome-v1` | `workshop-private-draft-install-outcome-v2`: the command fields plus `state: INSTALLED_PRIVATE_DRAFT, ownedDraftId, installedAt, holdDeadline, mode: PRIVATE_COPY, professionalTemplateStatus, published:false, executable:false`. Unknown → `state: NOT_FOUND`. |
| Install status | JSON `{requestId}` | form `request_id` |
| Install history | JSON `{licenseId, beforeCommandKey: <hash>}`; response `w18-paid-install-history-v1` | form `license_id`, `before_command_key` (**number**); response `workshop-install-history-v2`, `items` = outcome objects, `nextBeforeCommandKey` (number). Decision: store and send the server's number, and keep the hash only for display or dedupe. |
| Installed text | JSON `{requestId, ownedDraftId}`; response `w18-paid-installed-text-v1` | form `license_id`, `request_id`; response `schema: w18-member-text-v1`, `bindings`, `title, description, ruleInstructions, merchantGuide, questionName, questionAnswer, hint1, hint2, answerReveal` |
| Approval | `workshopPaidInstallApproval` is never granted | Decision: free installs as a normal player write; paid installs under the TEST `moneyPayments` switch |

## Scope

This touches about 1,800 lines across `Core/WorkshopPurchased*.swift`, `Core/WorkshopPaidInstall*.swift` and
`Core/WorkshopPaidInstalledText*.swift`, their strict request matchers (`WorkshopPaidInstallRequest.accepts`,
`WorkshopPaidInstalledTextRequest.accepts`, `WorkshopPurchasedReadRoute`), and their tests and contract checks (some pin
byte hashes). Recommended as one dedicated Cursor task, with this table as the spec and the TEST fixture: 9003 holds one
paid ACTIVE license (order line 970201) installed into private draft 970301.
