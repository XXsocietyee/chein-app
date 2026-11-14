# ui-cur-appeal-images — content appeal image attachments

Parent: `ui/wp-02` `c943799a66e32b9a910e66892d30ea080c31bc4e`.
Mini-program read from public `liboyang42-cpu/hengyin` `8390d99e3f7a54899c493ecb3d70e9aa8f57dbca` (default-branch blob the code search returned):

- `chengyinhub-xcx/subpackageA/pages/myproject/index.js` `addAuditAttachment` / `removeAuditAttachment` / `appealAudit`
- `chengyinhub-xcx/app.js` `chooseImage` (`skipCrop: true`)
- `chengyinhub-xcx/utils/transport/upload-client.js` `uploadAll`
- `chengyinhub-admin` `ApiCommonController.uploadOSS`, `AuditAppealDTO`, `AuditTaskServiceImpl.normalizeAppealAttachments`

This is a content appeal. No money switch was opened. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay closed on `www.chengyinhub.com`.

## Rows

| row | native | test | status |
|---|---|---|---|
| PAGE-subpackageA/pages/myproject/index appeal images | `App/PlayCreatorTailViews.swift` attachment rows + `AppealImagePicker`; `Core/PlayCreatorTailFlows.swift` `uploadImages` | `PlayCreatorTailRoutesTests.testAppealImagesUploadInOrderAndAFailureDoesNotSubmitEmpty` | DONE (client). Live TEST round trip NOT RUN |
| API-POST /api/common/uploadOSS | `Core/PlayCreatorTailRoutes.swift` `PlayerGapService.uploadAppealImage` | same test (method, bizType-then-file, 15s timeout, url order) | DONE (client) |
| API-POST /api/audit/appeal attachments | `CreatorAuditAppealCommand.body` `attachments`, frozen from the draft after upload | same test | DONE (client) |

## What was ported

| | source | app |
|---|---|---|
| Route | `uploadPath` default `/api/common/uploadOSS`. Multipart field name `file`. `chooseImage` with no `cropScale` and `skipCrop` sets `bizType=image_free`. | `POST api/common/uploadOSS`. Part order is `bizType` then `file`, the same order as `ProjectStoryImageUploadClient` (the existing `chooseImage` port). Picker is the existing `RetainedNativeImagePicker` (`selection = .ordered`). |
| Count | `addAuditAttachment` returns at 6. `chooseImage` count is `6 - current`. Concat then `slice(0, 6)`. Server `MAX_APPEAL_ATTACHMENTS = 6`. | `CreatorAuditAppealFlow.maximumImages = 6`. The picker limit is the slots left. |
| Size | `upload-client` `MAX_UPLOAD_FILE_SIZE = 10 * 1024 * 1024` when the size is known. `chooseImage` does not pass `fileSizes`, so that check is skipped there; the comment ties it to `spring.servlet.multipart.max-file-size=10MB`. | A known JPEG over 10MB is refused locally (`oversize`) and is not uploaded. The shared sanitizer still caps a decoded image at 8MB, and the shared batch cap is 24MB. |
| Time | concurrency 3, 15s per file, 60s for the batch. `onDone` runs the callback only when `failures` is empty. | One file at a time, so the stored order is the pick order (`results[index]` in the source). 15s request timeout, 60s batch deadline. One failure stores none of that batch. |
| Value | default `mapResult` is `data.url`. http Aliyun OSS hosts are rewritten to https. A missing url fails with “上传结果缺少文件地址”. `reviewState` other than `APPROVED` fails. | The appeal `attachments` array is those urls, in pick order, trimmed and de-duplicated when the command is frozen. The app does not invent `media-asset:{id}`. The server (`normalizeAppealAttachments`) accepts `media-asset:{id}` or a site upload url and stores `media-asset:{id}`. |
| Appeal body | `{ requestId, bizType, bizId, reason, attachments }` | Same fields on `CreatorAuditAppealCommand.body`. Ids (the urls) are attached only after every picked file in the batch uploaded. |

A failed upload sets `imageProblem` and `offersAppeal` stays false, so submit does not run and does not report success with an empty list. Dismissing the error allows a text-only appeal, which the mini-program also allows. `reviewState=REJECTED` shows the server `reviewReason`, or the localized “did not pass review” line when that reason is empty. An unknown upload result is an em dash.

## TEST fixture — curl NOT RUN

The seed belongs in hengyin (the TEST database), not in this app. cursor[bot] cannot push `liboyang42-cpu/hengyin`. No SSH to 8120 or 8121. This SQL was not executed. No response was fetched.

`ApiProjectController.lifecycleState`: `is_draft=1` → `draft`; `status=2` → `rejected`; `status=0` → `pending`; `user_status!=1` → `offline`.
`contentTimeline` sets `canAppeal` only when there is no appeal, no open task (`status` 0 or 3), `cms_topic.status=2`, `del_flag=0`, and the newest non-report `audit_task` for that `TOPIC` is `status=2`.

```sql
-- Owner: the signed-in TEST member (wp-02 used 9003). :topicId is one of their cms_topic rows.
UPDATE cms_topic
SET status = 2, is_draft = 0, del_flag = 0
WHERE id = :topicId AND member_id = :memberId AND del_flag = 0;

INSERT INTO audit_task
  (biz_type, biz_id, submitter_id, source_type, status, submitted_at, snapshot_json, version, create_time)
SELECT 'TOPIC', :topicId, :memberId, 'user_publish', 2, NOW(), '{"bizType":"TOPIC"}', 1, NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM audit_task
  WHERE biz_type = 'TOPIC' AND biz_id = :topicId AND status IN (0, 3)
);
```

`chengyin.audit.o5b.appeal-attachments.enabled` defaults to false (`AuditTaskServiceImpl`). While it is false, a non-empty `attachments` array is rejected with “暂不支持上传申诉附件” (HTTP 400). The client shows that message and does not treat it as success. Turning the switch on is a backend config change, not an app money switch. TEST OSS was already noted as absent on wp-02.

```
curl NOT RUN
```

## Gates

`swiftc` is not on this VM (`command -v swiftc` and `command -v swift` are empty). No typecheck is claimed. `swift test` was not run.

`python3 tools/check_scaffold.py`: pass (release config, privacy manifest, page route table, structural checks).
`python3 tools/check_design_lint.py`: pass (1614 App Swift files; allowlist unchanged).
