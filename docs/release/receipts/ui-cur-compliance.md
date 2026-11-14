# ui-cur-compliance

Branch `ui/cur-compliance`. Parent `6feee423adc8962d7613f8ba93b77ffdc93ea1c4` (`origin/ui/main` at branch time).

Mini-program read over HTTPS from `liboyang42-cpu/hengyin` commit `73f4f7be45aa5b49381baa2c1aff57e1b2245fad` (`chengyinhub-xcx`). No SSH.

`swiftc` is not installed on this machine. `swiftc -parse` did not run. XCTest did not run. `docs/release/contract-failing-baseline.txt` was not edited. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited. No method was added to those files. `ReviewedAreaSwitch` was not redeclared. Money, payout, merchant writes, and password login stay closed. No second account-deletion path was added.

## Changed

| Surface | What changed | Source |
|---|---|---|
| User agreement | Section 一 now ends “本协议在你明确选择同意后对你生效。” The other twelve sections were already the same text. | `chengyinhub-xcx/utils/agreement-docs.js` `user_agreement` v2.2 |
| Cancellation notice | Blocker 2 is “存在处理中的微信零钱提现或待审核的银行卡提现”. `SettingsNativeTests` pins that sentence. | `agreement-docs.js` `cancellation_notice` v2.1 |
| Account deletion | Same `AccountComplianceSheet` path. Pending copy is “注销申请已提交”, the in-cooling-off sentence, or the after-cooling-off sentence. The withdraw button reads “撤销注销申请”. A missing `executeAfter` is “—”. After the cooling-off clock the time label is “冷静期结束时间”. | `pages/deregister/components/scene-settings-deregister/index.wxml` |
| Privacy gate | `UsageConsentGateView` follows the mounted `cy-privacy-gate`: title “隐私保护”, lead “我们只在你使用相关功能时处理必要信息。”, “继续即表示同意”, both document links, “同意并继续”, “暂不同意”. Tapping agree still stores both current versions (`agreementChecked: true`), which is what `agreePrivacy` passes. The checkbox is gone. Maestro flows and `EntryUsageConsentFlowTests` follow that. | `components/cy/privacy-gate/index.wxml`, `index.js` (`agreeUsageConsent(event, true)`) |
| Privacy settings | `SettingsPrivacyLocationView` shows the sheet sentence, then home-city on/off, nearby sharing, roam withdrawal, and own media. On confirms with the existing home-city dialog, then `recordHomeCityLocationAgree`. Off calls new `recordHomeCityLocationRevoke` (`privacy_policy` / `home_city_location` / `REVOKE`). A failed or unavailable write stays on screen as “首页城市定位设置未保存，请重试”. | `pages/shezhi/components/privacy-sheet/index.wxml`, `pages/privacy/index.wxml` `setHomeCityLocation` |
| Privacy protection | The page title stays “隐私保护”. The hero uses the same short lead. The legal reader is still `SettingsLegalDocumentView`. | `pages/privacy/index.wxml` title and lead |
| Data export (NPC chat) | The existing copy-as-text button label is “导出我的对话记录” / “Export my chat records”. The readable-text shape was already `chat-export.js`. `tools/add_mp_drift_localizations.py` keeps that pair. | `subpackageMember/components/cy/npc-chat/index.wxml`, `chat-export.js` |

English and zh-Hans are both set on every new catalog key. `tools/check_scaffold.py` and `tools/check_design_lint.py` passed. No new Swift file, so `tools/generate_project.py` was not required.

## Skipped

| Requested surface | Reason |
|---|---|
| Minor protection flow | The mini-program has no age gate and no guardian screen. The only user-facing line is agreement section 十, “城瘾暂不面向未成年人提供注册和使用服务…”, already in `SettingsSourceLegalCatalog.userAgreement`. Backend `MinorGuardian` classes are not a mini-program flow. None was added. |
| Anti-addiction | No `防沉迷` page, timer, or curfew in `chengyinhub-xcx`. None was added. |
| Privacy-policy body | `agreement-docs.js` says the privacy policy is WeChat’s official guide (`wx.openPrivacyContract` on `pages/privacy`). That body is not in the repo. The existing reader still returns `.missing(.pendingSourceText)` unless `privacyPolicyApproved` is already true. The gated v2.1 paragraphs were not rewritten and no clause was added. |
| Exploration-record export | `subpackageTools/exploration-export` is already JSONL with the same range, “结束（不含）”, “准备导出”, and “这个范围内没有记录” copy. No new format. |
| Second deletion path | Not added. Cancellation stays on `AccountComplianceSheet`. |

`pages/privacy/index.wxml` still has an older checkbox for the route page. Settings mounts `cy-privacy-gate`, which does not. The app follows the mounted gate.

## 中文

读的是 hengyin `73f4f7be45aa5b49381baa2c1aff57e1b2245fad`。

用户协议第一节改为“本协议在你明确选择同意后对你生效。”注销须知第二条改为微信零钱提现或待审核银行卡提现。注销仍走原来的申请页：待处理文案、撤销按钮、缺失的执行时间用“—”。

隐私闸对齐 `cy-privacy-gate`：一句说明、继续即表示同意、两份文件、同意并继续、暂不同意。设置里的隐私与定位补上定位说明，以及首页城市定位的开启和关闭。关闭走同一条同意记录的 `REVOKE`。

没有未成年人保护流程，也没有防沉迷。协议第十条原文还在，没有另做年龄门。隐私政策正文不在小程序仓库里，没有新写条款。探索记录导出本来就是 JSONL。AI 对话导出按钮改为“导出我的对话记录”，仍是复制可读文本。

本机没有 `swiftc`，没有跑 Swift 测试。没有改 `AppSession`、`AppCompositionRoot`、`RegionalLaunchConfiguration`，也没有抬高 contract-failing baseline。
