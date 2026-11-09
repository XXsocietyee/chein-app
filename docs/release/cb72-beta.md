# CB72 — Internal and external TestFlight plan

Plan only. Checked against `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499` (2026-11-09 PT). This file was not created in App Store Connect. It was not started. Merging it does not invite testers, sign a build, upload a build, or submit a build.

Marketing version stays `0.1.0`. Build stays `1`. That pair is `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`. This plan does not run `tools/bump_version.py` and does not pass `--apply`.

Signing and submission stay owner decisions. Password login, bank-card withdrawal, and virtual goods stay off.

## Disabled workflow this plan follows

`origin/cursor/cb45` at `8f19f66ce6340fd0fb6fecf689ffab073f250f18` already drafts the unsigned archive. Its own note records base `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. The draft files are `docs/release/xcode-cloud-unsigned-archive.md` and `docs/release/xcode-cloud-unsigned-archive.workflow.json` on that branch. They are not on `rc/20261108`. This plan does not merge them, edit them, enable them, or add a post-action.

| Field | Value on that draft |
|---|---|
| Name | CB45 unsigned archive |
| Status | draft |
| Created in App Store Connect | no |
| Started | no |
| Enabled | no |
| Start | manual only. No branch, pull-request, tag, or schedule trigger |
| Project / scheme | `Questify.xcodeproj` / `Questify` |
| Configuration | Release |
| Action | one Archive action |
| Post-actions | none. No internal TestFlight distribution. No external TestFlight distribution. No App Store submission |
| Signing environment | `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, empty `CODE_SIGN_IDENTITY`, `AD_HOC_CODE_SIGNING_ALLOWED=NO` |
| Team, bundle id, API URL | not set |
| Version | stays `0.1.0` (`1`) |

A manual start of that draft, if the owner ever starts it in a later change, still produces an unsigned archive and still has an empty post-action list. An unsigned archive is not an installable TestFlight build. Internal and external groups both wait for a later owner decision that removes the unsigned override, puts the team only in gitignored `Config/Local.xcconfig` on the signing machine, and adds a distribution post-action in App Store Connect. CB45 does not do those steps. This plan does not do them either.

`origin/cursor/cb9` at `a7a11b9234b966b9c4d3e7fcc82ebe5d74b068ca` is the earlier build-and-test draft named by the CB45 note (`docs/release/xcode-cloud-setup.md` on that branch). That draft says not to add an Archive action. This plan does not edit `cursor/cb9` and does not add an Archive action to it. The archive draft remains the CB45 workflow: unsigned, disabled, and without a TestFlight post-action.

## Build under test

| Item | Value for this plan |
|---|---|
| App | Questify |
| Display name setting | `INFOPLIST_KEY_CFBundleDisplayName = Questify` |
| Marketing version | `0.1.0` |
| Build | `1` |
| Scheme archive configuration | Release |
| Committed bundle id | `invalid.example.questify.ios` in `Config/Base.xcconfig` |
| Committed API URL | empty `QUESTIFY_API_BASE_URL` |
| Committed realm | empty `QUESTIFY_SESSION_REALM` |
| Market default | `QUESTIFY_MARKET = CN` |
| Shipped composition | `makeComposition(reviewed: nil, build: .current)` |
| What to Test copy | templates on the CB45 branch: `docs/release/notes/en.md` and `docs/release/notes/zh-Hans.md`. The owner fills them. They are not submitted copy |

`com.chengyinhub.chengyinApp` and team `9VHY8N755R` are not in the tree (`docs/release/ship-prep.md`). No committed xcconfig sets `DEVELOPMENT_TEAM`. Export compliance stays an owner decision (`ITSAppUsesNonExemptEncryption` is unset). Account deletion stays the blocked settings row on the unconfigured composition. This plan adds no legal copy, no US API URL, and no request to the legacy server `47.103.124.64` named in `docs/release/ship-prep.md`.

`App/AppSession.swift` compiles `canUsePassword` to `false` in every non-DEBUG build. The TestFlight configuration is Release, so the password control stays out of the shipped binary. Testers do not type a password. `.maestro/sign-in.yaml` already refuses that control (`docs/release/smoke-flows.md`). Those Maestro flows were not executed for this plan.

## Internal TestFlight

Audience: App Store Connect users the owner already trusts (Account Holder, Admin, App Manager, Developer, Marketing, or another internal role Apple accepts on that team). The owner confirms Apple’s current internal cap before adding anyone and stays inside it. The usual cap is 100. This plan names no tester and sends no invite.

When it can start: only after the owner, in a change outside this file and outside the disabled CB45 workflow, signs a Release archive of `0.1.0` (`1`) and uploads it. Until that decision, the internal group has no build. Beta App Review is not required for an internal group. That does not authorize this branch to upload.

What the internal group exercises, on a device, once a signed build exists:

| Id | Journey | Pass condition on `0.1.0` (`1`) |
|---|---|---|
| `tf-smoke-01-auth-and-session-gate` | Auth, regional scope, single-flight 401, account-deletion row | Consent and session gate open. Password login stays off. The account-deletion row stays the blocked explanation and does not call apply. |
| `tf-smoke-02-city-roam-and-stamp-unlock` | City roam, tile fog, stamp unlock | Map and stamp path open with when-in-use location only. No always-location prompt and no background location mode. |
| `tf-smoke-03-story-walking-and-durable-recovery` | Story-ordered walking and command-journal recovery | Leave and relaunch restores the in-progress walk without a blank screen. |
| `tf-smoke-04-npc-chat-and-tts-audio` | NPC chat and TTS playback | Dialogue and playback start and stop. Microphone permission is requested only for this journey. |
| `tf-smoke-05-merchant-store-and-apply-wizard` | Merchant store, two-step redemption, apply wizard | Store and wizard open. Virtual goods stay off. No IAP purchase is completed. |
| `tf-smoke-06-club-enrollment-and-settlement` | Club access, schedule, enrollment, settlement readback | Readback opens. Bank-card withdrawal stays off and cannot be submitted. |

These six ids are the canonical set in `Core/TestFlightInternalAndExternalSmokeMatrixContract.swift`. Each row needs a device note from the owner or an internal tester: build, device, iOS version, result, and a screenshot for any failure. A green unit test is not that note. `CrashResilienceAndMetricKitDiagnosticsAudit.evaluate()` returning ready is not a device soak.

The four Maestro flows in `docs/release/smoke-flows.md` (launch, consent, welcome, sign-in) are a simulator check the owner may run before inviting anyone. They clear state, type nothing, and do not tap a password, code, WeChat, Apple, or payment control. They were not run in this workspace.

Internal exit: the owner writes an internal go, or a no-go, against the checklist below. An internal go is what allows the owner to consider an external group. It does not create the external group.

## External TestFlight

Audience: people who are not App Store Connect users, invited by email. A public link stays off until the owner turns it on. The owner confirms Apple’s current external cap before inviting anyone and stays inside it. The usual cap is 10,000. This plan creates no group and sends no email.

When it can start: only after an internal go on the same `0.1.0` (`1`) build, plus a separate owner decision to submit that build for Beta App Review. The first external build of a version waits for that review. Submission stays an owner action in App Store Connect. The CB45 post-action list stays empty, so external distribution is not a result of enabling or starting that workflow.

External testers run the same six journeys. The owner may mark a shorter subset in the What to Test templates. Those templates stay on the CB45 branch until the owner copies the words into App Store Connect. This plan does not submit them. The notes the owner pastes keep the three off lines already in the templates:

- Password login stays off.
- Bank-card withdrawal stays off.
- Virtual goods stay off.

The same notes omit a US API URL, legal copy, a signing certificate, a provisioning profile, and a team id.

External testers use the feedback and crash process below. They do not receive a signing identity, a checkout, or a way to reach the disabled workflow.

## Feedback

Channels, and only after the owner has uploaded a signed build:

1. TestFlight’s own screenshot-and-comment feedback.
2. The crash list Apple shows for that uploaded build in App Store Connect and the Xcode Organizer.
3. A mailbox the owner names at invite time. This plan does not choose the address and does not commit one.

No other collector is added. This plan does not add a crash-upload endpoint.

Each report records:

| Field | Required content |
|---|---|
| Build | `0.1.0` (`1`) until the owner chooses a later pair |
| Group | internal or external |
| Device and iOS | model and version the tester names |
| Locale | zh-Hans or en, or the locale the tester names |
| Journey | one of the six ids, or `outside-matrix` |
| Steps | what the tester did |
| Expected / actual | one sentence each |
| Attachment | TestFlight screenshot when the tester sent one |

Severity:

| Level | Condition | Owner next step |
|---|---|---|
| Blocker | Crash on a required journey; hang over the 250ms main-thread budget on a required journey; data loss; password login, bank-card withdrawal, or virtual goods is reachable; the build contacts `47.103.124.64` or a US API URL | Stop new invites. No-go for the group that saw it and for every later group. |
| Major | A canonical journey cannot be finished, or a blank screen blocks it | Hold external. Keep the internal group on this build only when the owner writes that down. |
| Minor | Copy, layout, or a control that does not block a journey | Record. A minor does not clear and does not block go by itself. |
| Question | A request to sign, submit, add legal copy, delete an account, or turn an off gate on | Record. Those stay owner decisions. This beta branch does not implement them. |

Before a note is copied into a tracker, drop session tokens, verification codes, phone numbers, bank card numbers, names, and precise location traces. `CrashResilienceCheckDescriptor` already requires `stripsUserPIIBeforePersist`. Tester feedback follows the same rule. Do not ask a tester to record a payment sheet or a bank form.

Triage order:

1. Confirm the report is for `0.1.0` (`1`) and for the group that installed it.
2. Attach it to a journey id, or mark `outside-matrix`.
3. If it claims an off gate is reachable, treat it as a blocker and stop invites before any other reproduction.
4. Reproduce on a device the owner controls, on that same build. The in-repo MetricKit evaluator is not that reproduction.
5. The owner writes go, hold, or no-go on the checklist. This file does not close the report.

## Crash triage

Use this order, and only for a signed build the owner has uploaded. This plan does not upload dSYMs and does not call `altool`, `notarytool`, or Transporter.

1. TestFlight crash feedback attached to the tester’s comment.
2. App Store Connect crash organizer for `0.1.0` (`1`).
3. Xcode Organizer for the same build and the dSYM from the owner’s signing machine. The dSYM stays on that machine.
4. MetricKit payloads already modeled in `Core/CrashResilienceAndMetricKitDiagnosticsAudit.swift`.

Classify a payload as one of the four categories in `MetricKitDiagnosticCategory`:

| Category | Payload the audit names | Hold rule |
|---|---|---|
| `crashDiagnostic` | `MXCrashDiagnostic` | One crash on a required journey is a blocker until the owner waives it in writing. |
| `hangDiagnostic` | `MXHangDiagnostic` | A main-thread hang over `250` ms on a required journey is a blocker. The audit’s budget is `maxMainThreadBlockMs <= 250`. |
| `cpuExceptionDiagnostic` | `MXCPUExceptionDiagnostic` | A repeating CPU exception on a required journey is a major, and a blocker when it prevents the journey from finishing. |
| `diskWriteExceptionDiagnostic` | `MXDiskWriteExceptionDiagnostic` | A disk-write exception on a required journey is a major, and a blocker when it loses the walk journal or the session. |

A missing payload stays `unclassified`. An unclassified crash is not a clean soak. The historical “24-hour crash-free soak” line in `docs/ios-current-status.md` is not evidence for this build. This plan records no soak.

Each crash row the owner keeps: signature, category, journey id or `outside-matrix`, build `0.1.0` (`1`), count, first-seen time, whether it reproduced on the owner’s device, and a confirmation that the stored note has no token, phone number, bank number, or precise location. Symbolication secrets stay out of git.

## Go / no-go

Every box starts open. The owner checks one only in a later note that cites evidence. Checking a box in this file is not that evidence. Merging this plan checks nothing.

### Frozen for this change

- [ ] Version is still `0.1.0` (`1`) in `Config/Base.xcconfig`.
- [ ] `tools/bump_version.py` was not run.
- [ ] No Swift, xcconfig, workflow, or `tools/current_ci_manifest.json` edit is in this change.
- [ ] The CB45 workflow is still disabled, manual-only, unsigned, and has an empty post-action list.
- [ ] No archive was produced, no build was uploaded, and nothing was submitted to App Store Connect or TestFlight.
- [ ] Password login, bank-card withdrawal, and virtual goods stay off.
- [ ] No US API URL, no legal copy, and no request to `47.103.124.64`.

### Owner decisions still open

- [ ] Whether to sign at all.
- [ ] Team id, written only in gitignored `Config/Local.xcconfig` on the signing machine.
- [ ] Bundle id. The committed id remains `invalid.example.questify.ios` until the owner changes it in a later change.
- [ ] Whether any beta build may use the reviewed China host. The shipped composition stays `reviewed: nil` until that decision.
- [ ] Export compliance answer.
- [ ] Whether account deletion ships. The in-app row stays the blocked explanation until that decision.
- [ ] Internal group membership.
- [ ] External group membership, and whether a public link exists. Default for this plan: public link stays off.
- [ ] What to Test text, taken from the CB45 templates and pasted by the owner into App Store Connect.
- [ ] The feedback mailbox, if the owner wants one besides TestFlight.

### Internal go

All of the following, with device evidence, before any external invite:

- [ ] The owner has signed and uploaded `0.1.0` (`1`) by a path other than the empty CB45 post-action list.
- [ ] The installed build is Release, and password login is absent.
- [ ] Bank-card withdrawal cannot be submitted.
- [ ] Virtual goods cannot be purchased.
- [ ] The build does not contact `47.103.124.64` and does not use a US API URL.
- [ ] All six journey ids have a device note, or the owner has waived a named id in writing.
- [ ] No open blocker in the crash list for this build.
- [ ] Feedback notes in the tracker contain no token, phone number, bank number, or precise location.

### External go

Internal go, plus:

- [ ] A separate owner decision to submit this build for Beta App Review.
- [ ] The owner has submitted that review. This plan has not.
- [ ] What to Test, in en and zh-Hans, still says password login, bank-card withdrawal, and virtual goods stay off.
- [ ] The external group is email-only, or the owner has written down why a public link is on.
- [ ] The same off-gate and crash checks were repeated on the build Apple made available to that group.

### No-go

Any one of these stops the group that hit it and every later group:

- The disabled CB45 workflow is treated as a TestFlight upload.
- A signing identity, provisioning profile, team id, or API secret is committed.
- `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` changes without an owner decision. This plan does not change them.
- Password login, bank-card withdrawal, or virtual goods is reachable on the installed build.
- The build contacts `47.103.124.64` or a US API URL.
- A required journey crashes, hangs past the 250ms budget, or loses the session or the walk journal, and the owner has not waived that signature in writing.
- Someone submits this branch to App Store Connect or TestFlight.

## Not run

`xcodebuild`, archive, `codesign`, `altool`, `notarytool`, Transporter, the App Store Connect API, `tools/bump_version.py`, `tools/current_ci.py refresh`, Maestro, a simulator, a device soak, and deploy were not run. No tester was invited.
