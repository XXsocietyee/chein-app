# IM recipient preview on the conversation

Branch `ui/cur-im-preview-ui`. Merge parents: `04b244ff992b9b908b477ace5b5437c50d565759` (`origin/ui/main`) and `f4d67c77e9d331db7427ebd22d5a060cb3b2d846` (`ui/cur-im-preview-templates`). The merge commit is `962513dacfe19c7279e345fc354d951acd5434da`. No rebase and no force-push.

`ReviewedAreaSwitch` is not defined on this tree, so the merge did not add a second one. `PlayTeamBackpackCommandSnapshot` is not on `ui/main`; the existing `PlayTeamBackpackSnapshot` was left unchanged.

## Call site

`IMRecipientPreviewBoard.issuedRoute` in `App/IMRecipientPreviewRow.swift` calls `IMPreviewTemplateLease.issue` once for each template in `IMPreviewRouteTemplates.all` (the six GETs: file authorization, file preview, video authorization, video preview, voice message, voice authorization).

`IMRecipientPreviewRow` asks for those lines. `MessagingHistoryView` mounts that row on each message bubble and system notice. `NativeChannelMessageBubbleView` mounts it on each channel message. The row is not removed when the lease is closed or `issue` returns nil.

`messageConversationID` is `Int64(message.conversationID)`, where `message` is the decoded `MessagingMessage`. It is not the screen route id, `lease.conversationID`, or another message.

A lease stored for conversation A and a message whose `.conversationID` is B produces the refused state and an em dash, not a preview path. A missing lease and a nil `issue` result (including an expired lease) use the em dash and the not-issued label. They are not the issued state. Loading, empty, error, and refused each keep all six rows.

## Strings and fixtures

English and zh-Hans live in `Resources/IMRecipientPreview.xcstrings`. DEBUG fixtures: `--design-fixture im-preview` (conversation 11 issues the six GETs) and `--design-fixture im-preview-refused` (lease for 11, message in 22).

## Checks

`python3 tools/generate_project.py` completed. `python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. `python3 tools/check_design_fixture_release_exclusion.py` PASS. This VM has no `swiftc`, so the Swift files were not parsed, compiled, or tested.

`docs/release/contract-failing-baseline.txt` was not raised. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited. Money, payout, merchant writes, and password login for `www.chengyinhub.com` were not turned on.

Source test: `IMRecipientPreviewConversationSourceTests.testMessageConversationIDIsTheDecodedMessageConversationID`.

## 中文

分支 `ui/cur-im-preview-ui`。合并父提交是 `04b244ff992b9b908b477ace5b5437c50d565759` 与 `f4d67c77e9d331db7427ebd22d5a060cb3b2d846`。合并提交是 `962513dacfe19c7279e345fc354d951acd5434da`。没有变基，也没有强推。

`messageConversationID` 的表达式是 `Int64(message.conversationID)`。`message` 是解码后的 `MessagingMessage`。会话页路由、租约上缓存的会话号、邻条消息都不是这个参数。

`IMRecipientPreviewBoard.issuedRoute` 对六条 GET 模板调用 `IMPreviewTemplateLease.issue`。消息气泡和频道消息都挂上这一行。租约关闭或签发结果为 nil 时显示破折号和「未签发」，不当成预览成功。会话 A 的租约不能预览会话 B 的消息，那一行是「已拒绝」加破折号。加载、空、失败、拒绝都保留六行。

中英文字符串在 `Resources/IMRecipientPreview.xcstrings`。DEBUG 夹具是 `im-preview` 与 `im-preview-refused`。

本机没有 `swiftc`，没有解析，没有编译，也没有跑测试。没有抬高 contract-failing baseline，没有改 `AppSession`、`AppCompositionRoot`、`RegionalLaunchConfiguration`，也没有为 `www.chengyinhub.com` 打开支付开关。
