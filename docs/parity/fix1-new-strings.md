# FIX1 new strings (inline copy, for FIX2 to catalog)

FIX1 did not edit `Resources/*.xcstrings`. New user-facing strings use inline zh/en pairs (`W8Text.t`, `CoreLoopCopy.t`
or a local `chinese ? zh : en`). Move them to catalog keys when convenient; wording that is legally sensitive is
marked and needs the owner's review (FP-O7).

| Where | zh-Hans | en | Notes |
|---|---|---|---|
| `App/OrderLifecycleView.swift` (re-consent banner) | 活动报名的数据共享同意已更新，需要重新同意后才能支付。 | The activity sign-up data-sharing consent has changed. Agree again before paying. | Suggested key `orderLifecycle.issue.reconsentRequired` (the view builds `orderLifecycle.issue.<rawValue>` keys; the case now exists) |
| `App/OrderLifecycleView.swift` (button) | 同意并继续 | Agree and continue | `orderLifecycle.reconsent` |
| `App/ExternalGameImportView.swift` (menu) | 举报或屏蔽 | Report or block | |
| `App/ExternalGameImportView.swift` | 举报此游戏包 | Report this game | |
| `App/ExternalGameImportView.swift` | 屏蔽此游戏及创作者 | Block this game and its creator | |
| `App/ExternalGameImportView.swift` (dialog) | 屏蔽后将关闭并无法再导入或运行此游戏及其创作者的其他游戏包。 | Blocking closes this game and stops you importing or running it or other packages from its creator. | |
| `App/ExternalGameImportView.swift` (buttons) | 屏蔽 / 取消 | Block / Cancel | |
| `Core/ExternalGameImport.swift` (`blockedByUser`) | 你已屏蔽「{name}」，无法导入或运行 | You blocked "{name}" on this device, so it cannot be imported or run | |
| `App/SettingsSupportSafetyEntry.swift` | 客服与安全 / 内容规范 / 联系客服 / 查看客服联系方式 | Support and safety / Content rules / Contact support / Show support contact | |
| `App/SettingsSupportSafetyEntry.swift` (clause) | 平台不容忍违规、骚扰或令人反感的内容与用户。你可以在内容旁的菜单中举报或屏蔽，也可以联系客服。违规内容与账号将被审核并处理。 | We do not tolerate objectionable content or abusive users. Report or block from the menu next to content, or contact support. Reported content and accounts are reviewed and acted on. | **Legally sensitive, draft.** Proposed user-agreement clause key `usage.consent.objectionableContent`; no SLA is stated (FP-O7). |
