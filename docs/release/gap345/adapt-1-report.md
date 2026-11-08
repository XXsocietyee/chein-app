# ADAPT-1 report — `/api/im/*` adaptation (branch `cloud/adapt-1`)

Base `origin/wip/wave4-final`; plan `docs/release/gap345/im.md` (from `origin/cloud/gap-1`); backend `hengyin@4ac8c249` (detached, read-only, never pushed).
**Nothing was compiled or run** (no Swift toolchain in this environment). Every symbol was grepped, but a first Xcode/SwiftPM build is still required.

## Re-verification against backend source
All claims for the rows below were re-read in `ApiImController.java` / `ImServiceImpl.java` and held:
- `mute`: `ApiImController.java:170-179` form `conversation_id`,`muted`; `setMuted` idempotent (`ImServiceImpl` ~1283); returns `AjaxResult.success()` (no `data`).
- `read`: `:137-150` params `conversation_id`,`read_to`; `read_to==null` marks the whole conversation read; `markRead(…, readTo)` clamps and never regresses.
- `conversations`: `listConversations` rows `{conversationId,type,lastMsgType,lastMsgText,lastMsgAt,unread,muted,counterparty}`; `muted` is 0/1.
- `report`: `:264-265` form `message_id`,`reason`; own message refused; `success("举报已提交")`.
- `send` type 3: `sanitizeUserCard` keeps only `cardType,name,address,lat,lng` (location), **rebuilds `content` as `"[位置] " + name`**; type 13 → `"不支持的消息类型"`.
- Errors: business failures are HTTP 200 with `{code:<n>,msg}`; token failures arrive as `code 401`.
Corrections to the doc: none material. Additions it did not state: (1) the backend overwrites `content` for type 3, so the response check must expect `"[位置] "+name`, not the sent content; (2) the other backend report path caps `reason` at 64 chars (`MAX_REPORT_REASON_LENGTH`); the `/api/im/report` path (`reportContent`) shows no cap, DB column limit not read.

## Design
Existing types (`IMExpandedService`, `OrdinaryIMMute*`, `NativeChannelReportFlow`, `NativeChannelNotification*`, `IMStaticLocation`) and all existing tests are **untouched** (tests pin `last_message_id`, JSON report, type 13, the `data` receipt). New parallel adapter `Adapt1IMBackendAdapter` (`Core/Adapt1IM*.swift`):
- injectable `HTTPTransport`; `writesEnabled` default `false`, `enabledPaths` default `[]`; allowlist is the fixed set `api/im/{conversations,read,mute,report,send}`, intersected with what the caller enables; any other path cannot be enabled;
- not referenced from `AppSession`, `AppCompositionRoot` or `QuestifyApp`; no leases/approvals, no mock data in production code, no secrets, no xcstrings edits.

## Rows
| Row | Status | What |
|---|---|---|
| 75 `mute` boolean (A1) | **Done** | `setMute(_ OrdinaryIMMuteIntent)`: form POST; accepts `{code:200,msg}`; then one `conversations` readback requiring `row.muted == requested`; mismatch, missing row, absent `muted` or readback failure ⇒ `IMCapabilityGap.unknownOutcome` (no retry grant); business error surfaces as `MessagingReadFailure` with no readback. Returns existing `OrdinaryIMMuteReceipt.applied` only after the readback proves it. |
| 43 `mute-state` (A2) | **Done** | `muteState(scope:)` → new `Adapt1MuteCurrent` (source `app-derived-im-conversations-v1`); existing `source=="original-ordinary-im-mute-state-v1"` check untouched. |
| 74 `read` cursor (A3) | **Done (cursor field); receipt not possible** | `readCursor`: `read_to` instead of `last_message_id`; then `conversations` `unread` readback. Returns `.acceptedUnverified(unreadAfter:)` — deliberately **not** `APPLIED`; needs backend B-read. |
| 74 notification ack (A4) | **Done** | `ack(_ NativeChannelNotificationCommand)` re-sends the `.ack` command's values as multipart form (`last_message_id`→`read_to`). Other operations are rejected. `.mute` JSON `minutes` **not adapted** (no backend duration, B-mute). |
| 76 `report` message (A5) | **Done (submit only)** | `reportMessage`: form `message_id`,`reason` = label (+`：`note, note truncated so total ≤ 64 UTF-16 units). Returns `.submittedUnreceipted`; no applied state, receipt lookup `governance/reports/requests/{id}` still has no backend (B-report). `NativeChannelReportFlow` itself is **not** switched (it pins JSON + receipt). |
| 77 `send` static location (A6) | **Done, needs product acceptance** | `Adapt1StaticLocationCard.wireFields` (type 3, `cardType:"location"`), `read` (accepts the server-rebuilt card), `sendStaticLocation` (checks client id, conversation, sender, card equality; any mismatch ⇒ unknownOutcome). `datum` is not transmitted: reader assumes `WGS84` (App-side assumption). |
| 78 `messages`, voice/file/video, all other rows | **Not done** | Outside the Adaptation plan (PARTIAL/MISSING; backend tasks B-*). |

## Tests added (`Tests/AppUnitTests`, `@testable import Questify`, no network)
`Adapt1IMTestSupport.swift` (scripted transport, JSON fixtures shaped like the real `AjaxResult`/`listConversations`/`ImMessage` output, multipart field parser), `Adapt1IMMuteTests`, `Adapt1IMReadAckTests`, `Adapt1IMReportLocationTests`: defaults off, exact allowlist, wire fields/encoding/auth header, success with bare `{code:200,msg}`, readback match/mismatch/missing/failed, business error and 401 mapping, no readback after failed write, ack from command, non-ack rejected, report text cap, location card round-trip and every mismatch case, existing strict mute contract still rejects the bare body, type-13 path untouched.
Registered in `Questify.xcodeproj` (3 Core files in the app target, 4 test files in the unit-test target) by script; the diff is purely additive.

## Unverified / risks
- Not compiled; not run. Possible compile slips: implicit labeled-tuple conversions in test arrays, `XCTAssertEqual` autoclosures with `try`.
- pbxproj edit is by hand/script (generated IDs); open once in Xcode to confirm it loads. CoreTests (SwiftPM) gets the Core files automatically; the new tests are only in the Xcode unit-test target.
- Production deployment of `4ac8c249` is unverified (receipt shows `19408d49`); all behavior is deployment-pending-verification.
- Readback assumes `/conversations` lists the row (hidden/deleted rows ⇒ unknownOutcome).
- `reason` column limit on `/api/im/report`, fastjson number formatting of `lat/lng`, and message `status` of `0` on the returned entity were read from source, not observed.
