# CB291 subpackageMember/complaint/index

PAGE-READY on rc/20261108 (`86fa48b0c5833bbadd97c09f246ad05f7af1b8b0`). Native screen `App/ProfileComplaintPreparationView.swift`. Map status stays **gated**. No route was added or marked live. Core, tests, views, ui-strings JSON, the catalog, the project, and the ledger were not changed.

Wired contract, already on this RC:

- `POST api/coop/complaint/topics` is `CoopFlowRead.complaintTopics`. `ProfileComplaintPreparationController.load` reads it. Only a positive unique `topicId` is kept. `registrationId` is not a fallback. A missing or blank `topicName` stays nil.
- `POST api/coop/complaint/mine` is `CoopFlowRead.complaintProgress`. `ProfileComplaintProgressController.load` reads it. Rows keep `id`, `topicName`, `statusText`, `reason`, and `handleNote`. One row without a positive id rejects the array.
- `POST api/coop/complaint/report` is `CoopFlowMutation.complaint` (`topicId` + `reason` only). `requiresSeparateEnablement` stays true. `CoopFlowService` still defaults `dormantWritesEnabled` to false. `ProfileComplaintPreparationLink.submitterFactory` is nil, and the reader-only view init sets `submitter` to nil, so the report write stays hidden and sends nothing.

States already present:

- Loading is `ProfileComplaintPreparationController.isLoading` and `ProfileComplaintProgressController.isLoading`. Topics stay nil until a successful decode, so loading is not an empty list.
- Empty topics are `topics == []` with no issue and not loading. An empty progress payload is `rows == []` with no issue. That is a successful empty read, not a count of 0.
- Error is `ProfileComplaintReadIssue` (`.failed`, `.signIn`, `.unavailable`) and `ProfileComplaintProgressIssue` (`.signIn`, `.denied`). A progress failure outside 400/401/403/422 keeps the last rows and sets no issue.
- UNKNOWN is a missing topic name, a missing progress `statusText` / `reason` / `handleNote`, and `ProfileComplaintSubmitFailure` when no writer is injected. None of those is stored as 0. This page has no numeric count. A literal JSON 0 is not invented, and an unknown count is not shown as 0.

The current mini page (`subpackageMember/complaint/index.js`) submits from the form and leaves on success. It does not render case progress. The iOS progress read stays. The submit control stays hidden until a host injects a submitter. No legal, support, ICP, or UGC placeholder was replaced.

## Missing keys

Lookups the screen already passes to `Text`, `Button`, `Label`, or `LocalizedStringKey` have translated en and zh-Hans in `Resources/Localizable.xcstrings`. Accessibility identifiers (`profile.complaint.loading`, `profile.complaint.open`, `profile.complaint.retry`, and the other identifier-only strings) are not catalog keys.

These source sentences have no catalog key. They were not added to a ui-strings file, and no English wording was written for them.

| Source text | Where it is now |
|---|---|
| 网络异常，请重试 | Raw `ProfileComplaintTopicLoadFailureCopy.networkSubtitle`. The view prints that string. `playerJourney.parity.network` is a different page and is not used here. |
| 当前配置暂未启用此读取服务 | Raw unavailable subtitle in `ProfileComplaintTopicLoadFailureCopy.sourceSubtitle`. `profile.complaint.read.unavailable` is a different sentence. |
| 正在加载可投诉的活动 | No key. The skeleton uses `profile.loading` (`加载中…`). |
| 请选择要投诉的活动 | No key. `profile.complaint.chooseTopic` is `请选择活动`. |
| 请选择投诉类型（可选） | No key. `profile.complaint.kind` is the field title `投诉类型（可选）`. |
| 请详细描述遇到的问题… | No key. `profile.complaint.reasonHint` is the UTF-16 limit note. |
| 手机号/微信（可选，便于客服联系） | No key. `profile.complaint.contactHint` is the UTF-16 limit note. |
| 投诉没有提交 | No key. `profile.complaint.notSubmitted` is the gated “not sent from the app” line. |
| 选择投诉活动 | No key. |
| 选择投诉类型 | No key. |

## Tests

No new tests. Existing assertions were not weakened. `xcodebuild` was not run.

`python3 -B -m unittest Tests.ContractChecks.test_profile_complaint_preparation Tests.ContractChecks.test_w2_04_member_tools Tests.ContractChecks.test_w2_04_p2_member_tools` — 54 tests, 6 failures, all already on this RC and left as they are:

- `test_cancelled_refresh_does_not_unlock_stale_review` and `test_retire_clears_ephemeral_data` still look for the older one-line `retire` / `abandon` text. The live lines also clear `isNetworkFailure`.
- `test_local_only_and_not_submitted_are_visible` still expects `Text("profile.complaint.localOnly")`. The screen uses `profile.complaint.pageSubtitle` and `profile.complaint.notSubmitted`.
- `test_progress_reads_only_its_endpoint_and_never_writes` still forbids the letters `submit(` in the progress file. The gated writer was appended there earlier and still does not run unless a host injects it.
- `test_pinned_template_files_untouched_by_this_pass` and `test_wallet_notices_are_display_only` fail in template-shelf and ticket-wallet files. Those files are not this page.

Existing Swift coverage, not executed here: `ProfileComplaintPreparationTests`, `ProfileComplaintProgressTests`, `ProfileComplaintSubmitTests`, and `W20607ParityCompletionTests.testProfileComplaintNetworkVsGenericFailureSubtitles`.

## Left

- The report route stays off. Nothing sets `submitterFactory`. Do not mark `api/coop/complaint/report` live.
- `profile.complaint.sourceEmptyHint` and `profile.complaint.localOnly` are in the catalog and are not what the screen draws. `profile.complaint.empty` is only an accessibility identifier on `profile.complaint.sourceEmpty`.
- The network and unavailable subtitles stay raw Chinese strings, so they have no English catalog line.
- Progress has no empty illustration. A missing `statusText` uses `profile.complaintProgress.statusUnknown` (`状态待确认`), which is a label, not a count, so it is not an em dash.
- The view still does not read a page-phase enum. It already binds `isLoading`, optional `topics`, `issue`, and nil text. Views were not edited.
