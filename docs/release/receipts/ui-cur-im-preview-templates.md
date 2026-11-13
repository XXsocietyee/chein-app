# IM recipient-preview templates (contract §7 item 18)

Branch `ui/cur-im-preview-templates`. Parent `c50b449dd6d2f8083416ba99b17232f018d86b4f` (`integ/next: channel follow-ups - blacklist lease, run team id`).

`BusinessRuntimeTransport` still matches a route only when the method and path are exact. A static `{id}` string is not a concrete message id, so it cannot be placed in that table. `IMPreviewTemplateLease` is the issuer. The shipped session does not call it: `imMediaRoutes` still omits the six preview features, and `App/AppSession.swift` was not edited. `previewEnabled` stays off until a later change passes an issued concrete route into the transport.

## Templates and verbs

All six are GET. The placeholder is one `{id}` segment. The id is ASCII digits only, no leading zero, greater than zero, and at most **19** characters (`BusinessRuntimeRouteTemplate.maximumIdentifierLength`, the length of `Int64.max`).

| Verb | Template | Feature |
|---|---|---|
| GET | `api/im/file/message/{id}/authorization` | `imFilePreviewStatus` |
| GET | `api/im/file/message/{id}/preview` | `imFilePreview` |
| GET | `api/im/video/message/{id}/authorization` | `imVideoPreviewStatus` |
| GET | `api/im/video/message/{id}/preview` | `imVideoPreview` |
| GET | `api/im/voice/message/{id}` | `imVoicePlayback` |
| GET | `api/im/voice/message/{id}/authorization` | `imVoicePlaybackStatus` |

These are the paths `IMFileService`, `IMVideoService`, and `IMVoiceService` already build. `/api/native/channels/read-through` is not a template: this app has no per-message seen-by model.

## Lease

`ReviewedProductionGateLeases.imPreviewLease` issues one lease per template, viewer context (market, base URL, namespace, account, epoch, role, token), and conversation id. It is cached for one hour for that triple, and only for a China player or club account after player writes are on. A template outside `IMPreviewRouteTemplates.all` is refused.

`issue` returns one concrete `BusinessRuntimeRoute` only when the verb is that template's GET, the path matches, the captured id equals `messageID`, and `messageConversationID` equals the conversation stored on the lease. A lease for conversation A does not authorize a message whose conversation is B, and it is not reused for another template. The same viewer check refuses a different account.

Refusal issues nothing (`nil`): path traversal (`..` and extra segments), encoding (`%2f`, `%2F`, `%5c`, `%5C`, and any other `%`), an empty id, a non-digit, a leading zero, an id longer than 19 digits, the wrong verb, the wrong conversation, the wrong viewer, a message id that does not match the path, and an expired lease (`now >= expiresAt`).

## Registration

`ReviewedPlayerWriteLeases.imPreviewTemplates` is `IMPreviewRouteTemplates.all`. `ChinaReviewedRouteCapability.imRecipientPreviewGrant` is the same six paths in the existing `{}` pattern form, and `admitsChinaProductionCall` consults that set. The patterns were already members of `channelsSocialOwnerGrant` and already marked `.missing`. No mark changed. `missingCount` stays 370. `liveInProductionCount` stays 627. `wiredPatternCount` stays 677. `docs/release/contract-failing-baseline.txt` was not edited.

Money, payout, merchant writes, and password login for `www.chengyinhub.com` were not turned on.

## Checks

`python3 tools/generate_project.py` completed. `python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. This VM has no `swiftc`, so the new tests were not compiled or executed. They are written to parse.

Tests: `testBoundViewerAndConversationIssuesTheConcreteGet`, `testPathTraversalRefusesAndIssuesNothing`, `testEncodedSlashAndBackslashRefusesAndIssuesNothing`, `testWrongConversationRefusesAndIssuesNothing`, `testWrongVerbRefusesAndIssuesNothing`, `testExpiredLeaseRefusesAndIssuesNothing`, `testCatalogStaysOnTheMissingOwnerGrant`, `testFactoryIssuesOnlyCatalogTemplatesForTheBoundConversation`.

## 中文

分支 `ui/cur-im-preview-templates`。父提交 `c50b449dd6d2f8083416ba99b17232f018d86b4f`。

传输层仍按动词和路径精确匹配。静态的 `{id}` 不是具体消息编号，不能放进那张表。签发的是 `IMPreviewTemplateLease`。现有会话没有调用它，六条预览功能仍不在 `imMediaRoutes` 里，`AppSession` 没有改，预览开关仍是关的。

六条都是 GET：文件与视频的 `authorization` 和 `preview`，语音的 `message/{id}` 和 `authorization`。编号只允许数字，不能有前导零，必须大于 0，最长 **19** 位。已读回执 `/api/native/channels/read-through` 不是模板。

租约同时绑查看者上下文和会话编号。会话 A 的租约不能给会话 B 里的消息签发预览，也不能换一条模板复用。路径穿越、`%2f` / `%2F` / `%5c`、错误动词、错误会话、过期租约都返回空，不签发。

两条登记都指向这六条模板。路由标记仍是 missing。缺失数仍是 370，已上线数仍是 627，wired pattern 仍是 677。没有抬高 contract-failing baseline，也没有为正式域名打开支付、提现、商家写或密码登录。

本机没有 Swift 编译器，测试只保证能被解析，没有编译，也没有跑。
