# Logic parity: UGC, safety and account rules (mini-program vs native)

Scope: App Store 1.2 (UGC: report / block / filter) and 5.1.1(v) (account deletion) logic.
Reference: `liboyang42-cpu/chengyin` branch `integration/20261106/backend-latest`, folder `chengyinhub-xcx` (read-only).
Native: `chengyin-app` branch `cloud/lp-b` (from `wip/rc2-base` e3ba3c1b), `Core/`.
Paths below are relative to `chengyinhub-xcx/` (MP) and `Core/` (native). Test files are in `Tests/CoreTests/`.

**Nothing in this document or in the added Swift was compiled or run.** The environment is Linux without a Swift toolchain.
The only mechanical check run was `python3 tools/check_scaffold.py` (structural; exit 0). Test files encode the
mini-program behaviour by reading it; they have never been executed.

Status legend: MATCH = native encodes the same rule; MISMATCH = native differs (fixed here unless noted);
MISSING = no native counterpart existed (added here unless noted); N/A-DEVICE = deliberate platform deviation;
NOT AUDITED = not examined in this run (see "Coverage gaps").

## 1. Report (reasons, picker, submission)

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 1.1 | Reason labels come from `GET api/v1/community/capabilities` `reporting.reasons[].label`; labels trimmed, blank labels dropped, none left -> "unavailable" | utils/content-report.js:15-21,43 | ContentReportReasonRules.swift:15 (new); policy decode in SquareReportContracts.swift:28-60 (stricter: whole policy rejected if any label blank/duplicate) | MISSING for the topic/template entries -> added. Square v1 policy: MATCH (stricter, intentional) |
| 1.2 | Topic report write: `POST api/topic/report {id, reason}` | utils/content-report.js:70-74 | ContentReportReasonRules.swift:6 (new). No other native reference to `api/topic/report` | MISSING -> constant + fields added; no transport wired (out of scope) |
| 1.3 | Template / personal template writes `api/template/report`, `api/template/personal-report` `{id, reason}` | content-report.js:75-84 | TemplateContentReportContracts.swift:11-12 | MATCH (test asserts path equality) |
| 1.4 | Reason is a label string; trimmed, <=64 UTF-16 (native contract) | content-report.js:46 | TemplateContentReportContracts.swift:18 | MATCH |
| 1.5 | Reason sheet: one open at a time (409), unloaded/aborted -> 499 silent, index must be an integer in range else 500 | utils/community-report-sheet.js:11-32 | ContentReportReasonRules.swift:42 `Sheet` (new) | MISSING -> added |
| 1.6 | Report tap re-entry guard, empty id ignored | content-report.js:25 | ContentReportReasonRules.swift:69 `Run` (new) | MISSING -> added |
| 1.7 | Outcome: code 200 accepted, else failure with server msg verbatim; cancel (499) silent | content-report.js:48-58 | ContentReportReasonRules.swift:88 (new) | MISSING -> added |
| 1.8 | Square post/comment report: idempotent v1 `/reports`, policy version pinned, evidence array, unique-readback, 409 if result mismatches | utils/community-post-api.js:119-203 | SquareReportContracts/Service/Coordinator/CaseStore.swift | PRESENT, NOT LINE-AUDITED |
| 1.9 | IM report: fixed reason literal, only the latest peer server message (never own/system/pending) | subpackageB/pages/im/chat/index.js (doReport) | IMConversationSafety.swift:16,48 | MATCH (taken from the file's own doc comments; MP page not re-read) |

## 2. Block / mute / ban

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 2.1 | IM block/unblock: `target_member_id`, target resolved from a fresh conversation read, direct chat only | subpackageB/pages/im/chat/index.js:1010 | IMConversationSafety.swift:30-60 | MATCH |
| 2.2 | Block / unblock confirmation copy (title, consequences, done card) | utils/danger-actions.js:474-497 | no copy table in Core | MISSING (copy belongs to App/ + String Catalog; not added, see Proposed changes) |
| 2.3 | Mute / ban semantics (channel or IM) | not in the assigned utils files | OrdinaryIMMuteRecovery.swift, NativeChannelModerationFlow.swift | NOT AUDITED |

## 3. Danger-confirmation text

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 3.1 | `postExcerpt`: collapse whitespace, trim, 12 UTF-16 units + "...", image-only fallback | utils/danger-actions.js:663 | DangerActionText.swift:10 (new) | MISSING -> added. Deviation: never splits a surrogate pair |
| 3.2 | `fillTemplate`: `{key}` placeholders, empty/missing -> neutral wording, never a bare placeholder | danger-actions.js:671 | DangerActionText.swift:26 (new) | MISSING -> added; fallback wording injected by caller (en / zh-Hans) |
| 3.3 | Per-action copy table (`irreversible`, consequences, done card, 50+ actions) | danger-actions.js:28-660 | none in Core | MISSING; UI copy, not logic. Needs a String Catalog pass in App/ |

## 4. Drafts, repost, recovery state machines

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 4.1 | Club profile edit draft: per-(member, club) slot, form allow-list, base fingerprint, conflict compare, expected-record write | utils/club-edit-draft.js:1-93 | ClubProfileLocalDraftStore.swift:11-80, ClubProfileLocalDraftFlow.swift:29,163 | MATCH in structure (allow-list, scope key, conflict state); byte-level key format differs by design (native namespaced) |
| 4.2 | Club post edit draft: exact byte comparison of text and image refs | pages/club (post edit) | ClubPostEditDraft.swift:4 | MATCH (existing tests) |
| 4.3 | Repost read side: `itemType: 'repost'` rows flattened, reposter fields | utils/club-post-repost.js:18-51 | ClubCommunityReadCursor.swift:9-35 | MATCH |
| 4.4 | Repost toggle: optimistic flip, undo endpoint, per-post in-flight guard, rollback with server msg verbatim, count never < 0, community rows excluded | club-post-repost.js:67-115 | ClubPostRepostToggle.swift:67,78 (new) | MISSING -> added. Deviation: a negative server `repostCount` is clamped to 0 |
| 4.5 | Repost state applies to every non-community row with the id | club-post-repost.js:54-59 | ClubPostRepostToggle.swift:94 (new) | MISSING -> added |
| 4.6 | Square comment recovery: one pending row per (member, post); body 1-2000; key 8-96; replay verbatim; 400/403/404 on first attempt = rejected, else unknown; 200 clears | utils/community-comment-recovery.js:1-57 | CommunityCommentRecoveryRules.swift:66,78,109 (new); club comment recovery already in ClubCommentOriginalContracts.swift:50 | MISSING for Square comments -> added (pure transitions, no storage) |
| 4.7 | Square publish progress machine (guideline ack, media register, create, publish, readback, unknown/rejected) | utils/community-submit-progress.js:6-226 | SquarePostVideoChain.swift, SquareWorkspaceService.swift:111,135 and others | NOT LINE-AUDITED (226-line machine; presence only) |

## 5. Cooperation invite

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 5.1 | View model: terms, deposit, contact, input, footer, project scope, decisionReady | utils/coop-invite-view.js | CooperationInvitePresentation.swift:5-108 | MATCH (existing tests) |
| 5.2 | Exact invite id (`parseInviteId`): ASCII digits, strip zeros, <= Int64.max | coop-invite-view.js:68-74 | CoopInviteRequestRules.swift:15 (new) | MISSING -> added |
| 5.3 | Per-target write key `owner:coop-invite:[type,scope,topic,to(,station)]` | utils/coop-invite-request.js:14-19 | CoopInviteRequestRules.swift:54 (new) | MISSING -> added |
| 5.4 | Receipt validation (CREATED / NOT_FOUND / UNAVAILABLE shapes, club vs merchant, station only for type 0) | coop-invite-request.js:20-33 | CoopInviteRequestRules.swift:88 (new) | MISSING -> added |
| 5.5 | Receipt must match request context | coop-invite-request.js:34-37 | CoopInviteRequestRules.swift:113 (new) | MISSING -> added |
| 5.6 | Write classification: success only with matching request id + boolean `replayed`; 409/408/5xx/lost = unknown; other 4xx and "招商写入已关闭" = failed | coop-invite-request.js:38-49 | CoopInviteRequestRules.swift:135 (new) | MISSING -> added |
| 5.7 | Readback paging: strict-decreasing cursor, hasMore <-> nextCursor | coop-invite-request.js:50-95 | CoopInviteRequestRules.swift:155 (new) | MISSING -> added |
| 5.8 | Supply-station confirmation (`supplyStationView`, `supplyStationConfirmation`) | coop-invite-view.js:84-110 | none found by grep (`supplyStation` only in unrelated files) | MISSING; not added (needs the CooperationInvite model changes outside this brief) |

## 6. Account deregistration (5.1.1(v))

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 6.1 | Status routing: PENDING -> cooling card; NORMAL/CANCELLED/FAILED -> precheck; else "unconfirmed" | utils/deregister-flow.js:127-135 | AccountComplianceContracts.swift:75-80 (`pending`, `startable`); DeregistrationStatusRules.swift:110 (new, explicit router) | MATCH (+ explicit router added) |
| 6.2 | Precheck shape: ELIGIBLE with blockers or BLOCKED without = error; blank blocker = error; method default SMS, unknown -> UNAVAILABLE | deregister-flow.js:22-25,154-161 | Coordinator only tests `eligible`/`blocked` (AccountComplianceCoordinator.swift:263); DeregistrationStatusRules.swift:19 (new) | MISMATCH -> rule added; **the coordinator still needs to call it** (not my file) |
| 6.3 | Cooling-off clock `executeAfterPassed` (ISO/offset, epoch s/ms, China-local strings) | deregister-flow.js:35-39 | DeregistrationStatusRules.swift:41 (new) | MISSING -> added; screen must call it |
| 6.4 | WECHAT verification via `wx.login` | deregister-flow.js:237-258 | AccountComplianceContracts.swift:80 `verificationAvailableOnThisDevice` | N/A-DEVICE (native cannot mint the mini-program login code; WECHAT/UNAVAILABLE show "unavailable" and record no consent) |
| 6.5 | SMS: phone read from profile, `api/sms/send`, masked last 4 | deregister-flow.js:184-215 | AccountDeregistrationParityTests / AuthChannel* | PRESENT, NOT LINE-AUDITED |
| 6.6 | Consent `account_cancellation_notice` / `account_cancel` AGREE recorded before apply | deregister-flow.js:239-241 | AccountDeregistrationOriginal.swift:87-92 | MATCH (native adds request-id readback) |
| 6.7 | Apply gate order and `canApply` | deregister-flow.js:178-231 | DeregistrationStatusRules.swift:82,92 (new) | MISSING -> added |
| 6.8 | Apply: `smscode` + `requestId`; native adds `impactRevision` | deregister-flow.js:261-263 | AccountDeregistrationOriginal.swift:105-117 | MATCH + stricter (impact revision pinned) |
| 6.9 | Unknown apply result -> read-only status reconcile; adopt PENDING only from the ELIGIBLE form; typed code/confirmation kept otherwise | deregister-flow.js:289-309 | AccountDeregistrationOriginal.swift:95 (`result` receipt by requestId); DeregistrationStatusRules.swift:104 (new) | MATCH in intent (native reads an exact receipt, stronger); local-form rule added |
| 6.10 | Cancel during cooling-off; success only when `status == CANCELLED`, then re-precheck | deregister-flow.js:317-348 | AccountComplianceContracts.swift:72 `cancellationConfirmed` | MATCH |
| 6.11 | Cancel allowed after cooling-off ends until batch executes | deregister-flow.js:34 | `pending` stays true; no clock | MATCH once 6.3 is surfaced |
| 6.12 | Notice text `cancellation_notice` v2.1 / `user_agreement` v2.2 | utils/agreement-docs.js:5-38 | SettingsSourceLegalCatalog.swift:16,34 | MATCH on titles/versions; **section text not diffed** |

## 7. Consent and agreement

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 7.1 | Usage consent versions `privacy_policy v2.1`, `user_service_agreement v2.2`; stale choice re-gates; decline keeps guest browsing | utils/compliance/usage-consent.js:5-8,147-151 | UsageConsentPolicy.swift:13-16 | MATCH |
| 7.2 | Pending AGREE rows keep a stable requestId until server confirms; version drift -> refuse | usage-consent.js:165-214 | UsageConsentPolicy.swift (UsageConsentRecordRequest) | MATCH in design (per file comment). Live dispatch gated by `liveRecordingApproved = false` (UsageConsentPolicy.swift:47) |
| 7.3 | Separate consent: voice | utils/compliance/separate-consent.js:6-8 | StoreCharacterContracts.swift:215-232 | MATCH |
| 7.4 | Separate consent: photo (`photo_model_processing` / `object_photo`) | separate-consent.js:3-5 | SeparateConsentSpecs.swift (new) | MISSING -> added |
| 7.5 | Separate consent decision: needs signed-in account, owner unchanged after dialog, decline stops only that feature | separate-consent.js:10-35 | SeparateConsentSpecs.swift:33 (new) | MISSING -> added |
| 7.6 | Consent withdrawal | no `eventType: WITHDRAW` in the assigned utils | n/a | NOT AUDITED (no MP rule found in scope) |

## 8. Access gates

| # | Rule | MP source | Native | Status |
|---|------|-----------|--------|--------|
| 8.1 | Merchant gate allow/deny/unknown: "请先登录" -> loginExpired, 401/403 -> deny, other -> unknown (never block on a broken reply) | utils/access-gate.js:22-35 | AccessGateDecision.swift:28 (new); `MerchantAccess.allows` exists (MerchantAccess.swift:46) | MISSING as a decision -> added |
| 8.2 | Club gate incl. `active` must be explicit, club id must match, permission string listed | access-gate.js:38-52 | AccessGateDecision.swift:51 (new) | MISSING -> added |
| 8.3 | Require-login continuation for guest writes | utils/auth/require-login.js | AuthChannelCoordinator.swift, AppSession (not mine) | NOT AUDITED |

## 9. Coverage gaps (honest)

Not examined: `utils/compliance/consent-client.js` (record/readback/timeout), `utils/auth/require-login.js`,
`utils/publish/publish-intent.js`, and the page-level code under `pages/club`, `pages/im`, `subpackageB/pages/im`,
`pages/square`, `pages/topic` (profanity / content-filter rules, mute and ban UI semantics, community
guideline ack wording). The brief's "content-filter rules" had no matching file in the assigned util list; none was invented.
Rows marked PRESENT / NOT LINE-AUDITED were located by name and doc comments only.

## 10. Proposed changes for files I may not touch

1. `Core/AccountComplianceCoordinator.swift:263` (and App deregistration view): replace `guard result.eligible` with
   `DeregistrationStatusRules.evaluatePrecheck(result)`; treat `.malformed` as the "could not confirm" state, `.eligible(.sms)` as
   today, `.eligible(.wechat/.unavailable)` as verification-unavailable. Show the "cooling-off ended, execution pending" copy when
   `DeregistrationStatusRules.executeAfterPassed(status.executeAfter, now:)` is true (keep the cancel button; it stays valid).
2. App deregistration view: gate the submit button on `DeregistrationStatusRules.canApply` and the tap on `applyGate`.
3. App report entries for topic / template / personal template: build the reason sheet from `ContentReportReasonRules.labels`,
   own selection with `ContentReportReasonRules.Sheet`, guard re-entry with `Run`.
4. App club feed: drive the repost button with `ClubPostRepostToggle` (endpoints `api/club/post/repost[/undo]`); the transport/service
   enable flag stays false until approved.
5. App merchant/club entry points: call `AccessGateDecision.merchant/club` before navigation; `.unknown` must not block.
6. Photo-model features: call `SeparateConsentFeature.photo` before sending photos to a model provider.
7. `AuthChannelCoordinator` / `ChannelDiscordMessaging`: no change proposed (not audited against MP).
8. String Catalog (en + zh-Hans) for the danger copy table and IM block/unblock confirmations (3.3, 2.2) and for
   the neutral `fillTemplate` fallback and `postExcerpt` image-only text.

## 11. Build note

`tools/check_scaffold.py` asserts that every `Core/*.swift` is listed in `Questify.xcodeproj/project.pbxproj`. Adding any Core file
therefore requires regenerating the project with `tools/generate_project.py` (deterministic; the diff is purely additive, 12 lines per
new Core source). I ran that generator rather than editing the file by hand; if another worker also adds Core files, expect an
additive merge conflict in `project.pbxproj` that is resolved by re-running the generator.
