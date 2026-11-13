# Cloud stubs — IM row 29

Branch `ui/cloud-stubs-im`. Parent `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Stub-ledger row 29 only. `SessionMessagingHome` calls `IMCoopInviteStripFactory.make(reader: session.cooperationReader)` and puts that closure in `\.imCoopInviteStrip`. The reader is the `CooperationSessionReader` the session already owns. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged.

The strip loads through `CooperationSessionReader.inviteList()`, which is one `POST api/coop/list` (`CooperationService.invitations`). It does not call `inbox`, so `api/coop/pool/mine`, `api/coop/pool/received`, and `api/coop/candidates/received` stay off this path. A fixture reader still projects `inbox.invitations`. Opening a card uses the existing detail read, which rereads `api/coop/list`. No coop write was added.

Row 30 `IMInviteReminderBinding` is not implemented. There is no server preference and no owner decision for APNs. Nothing assigns `\.imInviteReminder`. `IMInviteReminderToggle` still hides its switch when that binding is nil, so the control stays hidden while the strip can show.

`tools/check_design_lint.py` and `tools/check_scaffold.py` were run before push. This VM has no Swift compiler, so the new `CooperationTests.testInviteListReadsOnlyCoopList` was not executed. The contract check `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py` was run. The contract-failing baseline was not raised.

## 中文

分支 `ui/cloud-stubs-im`。父提交 `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`。

只补 stub-ledger 第 29 行。`SessionMessagingHome` 用会话里已有的 `CooperationSessionReader` 调用 `IMCoopInviteStripFactory.make(reader: session.cooperationReader)`，并写入 `\.imCoopInviteStrip`。`App/AppSession.swift` 与 `App/AppCompositionRoot.swift` 没有改动。

邀请条走 `CooperationSessionReader.inviteList()`，只发一次 `POST api/coop/list`（`CooperationService.invitations`）。这条路径不调用 `inbox`，因此不会请求 `api/coop/pool/mine`、`api/coop/pool/received`、`api/coop/candidates/received`。夹具读者仍投影 `inbox.invitations`。点开卡片沿用现有详情读取，会再读一次 `api/coop/list`。没有新增合作写入。

第 30 行 `IMInviteReminderBinding` 没有实现。没有服务端偏好，也没有 APNs 的产品决定。没有任何地方赋值 `\.imInviteReminder`。绑定为空时 `IMInviteReminderToggle` 仍不画出开关，所以开关保持隐藏，邀请条可以显示。

推送前已跑 `tools/check_design_lint.py` 与 `tools/check_scaffold.py`。本机没有 Swift 编译器，新增的 `CooperationTests.testInviteListReadsOnlyCoopList` 没有执行。已跑合同检查 `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py`。没有提高合同失败基线。
