# 账号发布 r9：未关的非金钱 P0

基线 `ui/combined-r7`。审计 `origin/audit/parity-r9-account-publish:docs/audit/parity-r9/account-publish.md`。不打开密码登录，不加支付、报价或付费订单。

## 已关

| id | 状态 | 说明 |
| --- | --- | --- |
| C-F5b | 基线上已关 | `castConfig` 与 `look` 已在 `ProjectEditContract.topicCarryOver`，v2 创建和更新按 JSON 字符串提交。针在 `Tests/CoreTests/ProjectEditTests.swift` 的 `ProjectEditCastLookCarryTests`。本分支未再改。 |
| C-T3 | 本分支补完三处绑定 | 区段仍挂在 `TemplateAuthoringCompletionFields` 旁。状态不好时松一点的开启走 `TemplateAdvancedDraft.setLowHPRelax`。扫完回复仍走 `setScanReplyEnabled`。可触发的结果改为 `node-outcome-contract.js` 的 `extract`（`TemplateTriggerableOutcomes`），不再把 `outcomeRules` 的通过/没通过画在这个标题下。小程序 `temp/index.wxml:986` 的列表是路线结果，`outcomeRules` 是后面的结果反馈。 |

## 仍开

| id | 严重度 | 说明 |
| --- | --- | --- |
| C-T3c | P1 | 据点玩法形态。Core 已有 `TemplateAuthoringContract.TemplateCityNodeInteraction`（城市故事卡 / 隐藏菜单 / 拍照点 / 到店扫码）、草稿上的 `authoringFrom` 与 `interactionType`。个人模板的 `payload` 不带这两个字段。`from=citynode` 时 `TemplateAuthoringContract.request` 直接拒绝，避免走个人草稿/发布把据点玩法存错。个人 author-request 只转发 `/api/template/draft` 与 `/api/template/publish`，不能代发 `/api/merchant/city-node/template/submit`。选择器因此不挂上编辑页。 |

针：`Tests/CoreTests/TemplateAuthoringTests.swift` 的 `testTriggerableOutcomesFollowTheNodeContract` 与 `testLowHPRelaxUsesTheCoreSetterAndCityNodeStaysOffPersonalPublish`。
