# fix-1128-publish receipt (lane mp-publish)

Branch `fix/1128-publish` from `origin/ui/combined-r7`. Audit: `origin/audit/1128-functions:docs/audits/1128-functions.md`.
Backend reference: hengyin `origin/us/r3-functional`. MP reference: `chengyinhub-xcx/pages/publish/temp`, `pages/templatedetail/*`.
No Swift compiler in this environment: the Swift is unbuilt; the gates below are the Swift-free checks.

## Audit items

| ID | Fix | Evidence (file:line) | Backend route (r3-functional) | Test |
|---|---|---|---|---|
| P0-7 | 互动 template authoring now has real read/submit approvals in a reviewed China player-write build, so `makeTemplateAuthoringRequestService` returns a service, `canSubmit` is true, and draft / publish are sent once through the original-request envelope. 使用此玩法模板 uses the same `templateAuthoringEditor(adopting:)` path (the adopted `originalTemplateId` is an allowed field). Results: COMMITTED draft → 模板草稿已保存 (`templateAuthor.draftSaved`); COMMITTED publish → 已提交，审核通过后展示; REJECTED → `templateAuthor.rejected` plus the server's `originalResult.msg` (kept on reopen); NOT_FOUND / RUNNING → uncertain + 读回 (envelope read). On success the completion opens 我的项目 → 模板 (MP `reLaunch myproject?type=template`). | App/MPFirstPublishApprovals.swift:15-50; App/AppCompositionRoot.swift:521 (read + submit selectors); App/AppSession.swift:4720-4745 (unchanged consumer); Core/TemplateAuthoringCoordinator.swift:36,114,239-240; Core/TemplateAuthoringRequestReceipt.swift (`rejectionMessage`); App/TemplateAuthoringView.swift:349-360 | `POST /api/template/author-requests/submit` → `ApiTemplateController.draft/publish` by `originalPath`; `POST /api/template/author-requests/read` (ApiAppGapsOriginalRequestController.java:75-96) | Tests/AppUnitTests/MPFirstPublishApprovalsTests.swift (paths, gating, US/no-writes off); Tests/CoreTests/TemplateAuthoringRequestRecoveryTests.swift (envelope body: protocolVersion, requestId, payloadSHA256, chunks → `originalPath` `api/template/draft` / `api/template/publish`, `fields.title`; draftSaved / acknowledged / rejected-with-reason / rejected-without-reason) |
| P1-26 | `PublishTabRootView` injects `topicEditorDestination`, so 用这个模板 on the 发布 tab pushes `pages/publish/fabu/index?id=<copied>&scope=` (the same editor the 首页 template pages open) instead of a blank page. | App/PublishTabRootView.swift:30-32,163-177; consumer App/DiscoveryTemplateDetailView.swift:931-937 | copy is the existing template use route; the editor reads `edit-detail` | MPFirstPublishApprovalsTests.testCopiedTemplateOpensTheFabuEditorQuery |
| P1-27 | Story image, story audio, node photo and the owned-cover author sheet get production approvals (reviewed China player-write build), with the same upload-result origins the working cover / gallery field uses (`RetainedImageOrigin.configured` + `CYStampImageOrigins`). The node approval carries an id, so it is cached per session identity (the client compares `currentApproval() == approval`). Injected fixture approvals still win. | App/MPFirstPublishApprovals.swift:52-91; App/AppCompositionRoot.swift:517-521; consumers App/AppSession.swift:3874-3960 | `POST /api/common/uploadOSS` (ApiCommonController.java:107); `GET /api/topic/cover/selection/current`, `POST /api/topic/cover/upload`, `/cover/selection`, `/cover/selection/status` (ApiAppGapsTopicController.java:37-56) | MPFirstPublishApprovalsTests.testTopicEditorMediaApprovalsMatchTheEditorSession / ...StaysOffWithoutPlayerWrites |
| P1-29 | 我的项目 → 模板 gets a `TemplateShelfReadApproval` lease (12 h, reused per session identity, re-issued after expiry/revoke), so `makeTemplateShelfReadTransport` / `makeOwnedMemberTemplateReader` / `templateShelfCoordinator` have a reader and a published template appears with its status. | App/MPFirstPublishApprovals.swift:93-104; App/AppCompositionRoot.swift:532; consumer App/AppSession.swift:4677-4705 | template my-list / detail multipart read (TemplateShelfReadRoute) | MPFirstPublishApprovalsTests.testTemplateShelfLeaseIsStablePerSessionAndRenewedAfterExpiry |

Scope note: every new approval is issued only when `productionGatesEnabled && playerWritesEnabled && market == .china`
(`MPFirstPublishApprovals.enabled`), the same switch as the MP-first club writes. The US market stays off, as the
editor media sources already require China. No pay, refund, payout or pricing route is admitted.

## Screens touched (OWNER RULE)

| MP page | Native view | MP sections | Optimizations |
|---|---|---|---|
| `pages/publish/temp` (result) | App/TemplateAuthoringView.swift | status + server reason (MP toast `res.msg`) added | system Section, footnote secondary text, a11y id |
| `pages/templatedetail/topic-preview` → `publish/fabu?id=` | App/PublishTabRootView.swift | 用这个模板 destination ✓ | native push, no new chrome |

## Strings

`templateAuthor.draftSaved` (en + zh-Hans) added to Resources/Localizable.xcstrings. `templateAuthor.rejected` already existed.

## Gates (final tree, 2026-11-28)

| Gate | Result |
|---|---|
| `python3 tools/generate_project.py` | 906 app-unit classes in 4 shards (new MPFirstPublishApprovalsTests included) |
| `python3 tools/check_scaffold.py` | PASS structural checks, 21276 bilingual keys |
| `python3 tools/contract_ratchet.py --check` | 52 failing, baseline 52, **new 0** |
| `python3 tools/check_design_consistency.py` | PASS |
| `python3 tools/check_a11y_lint.py` | PASS, 0 new |

`App/AppCompositionRoot.swift` stays at its 4175-line ratchet: the glue is `MPFirstPublishApprovals.fallback(...)` on the
existing assignment lines. `Tests/ContractChecks/test_template_authoring_contracts.py` lists the new accessibility id
`templateAuthor.rejectionReason` with the other identifiers (it is not a string key).

Not done here: Swift build / XCTest run (no compiler), live backend calls. P1-28 (IM image) and P2-6 are outside this worker's list.
