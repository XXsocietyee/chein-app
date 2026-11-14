# ui-cur-fixtures-6

Rebased onto `origin/ui/main` `3ac970ec20191014b4b9a8779a3a94b961e99c9c`. The four commits below were replayed, so their SHAs on this branch differ from the original branches. Those original branches were not moved. The exclusion list and the Xcode project keep both `Cur4Fixtures.swift` and `CurFixtures6.swift`.

Task 65. Branch `ui/cur-fixtures-6` from `origin/ui/main` `6feee423adc8962d7613f8ba93b77ffdc93ea1c4`.

This branch contains those four commits, merged with the octopus strategy. None of those branches was pushed.

| Handover | Branch | Commit |
|---|---|---|
| 59 errors | `ui/cur-errors` | `28ffaab4681a7e173601dd5df9c2f64b56a94f1a` |
| 60 permissions | `ui/cur-permissions` | `8faf4e06f3be646c784a6738b53492dbe49fe2e9` |
| 61 compliance | `ui/cur-compliance` | `6f78a9eefdad3a7168494b6e521606bfaf3ec50f` |
| 62 search | `ui/cur-search` | `d5751e50ab3e4cb07de00de3e6be1dbaf091d5b4` |

Launch: `--design-fixture <name>`. Registry: one line in `DesignFixtureRegistry.make` calls `CurFixtures6.make`. Add `-zh` for a zh-Hans locale. Host for the compliance coordinator is `https://fixture.example`. Token is never set. `ReviewedAreaSwitch` is not redeclared. Money, payout, merchant writes, and password login are read with `apiHost` `www.chengyinhub.com`, so those four stay closed. `paymentSucceeded` for `FEATURE_CLOSED` and `CASH_CLOSED` is false.

`swiftc` is not on this machine. No parse and no typecheck were run. This is not a green typecheck. `docs/release/contract-failing-baseline.txt` was not edited. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited.

`python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. `python3 tools/check_design_fixture_release_exclusion.py` PASS. `python3 tools/generate_project.py` registered `App/DesignFixtures/CurFixtures6.swift`.

## Errors (59)

`cur6-errors` and `cur6-errors-zh` list `BackendErrorCatalog.playerFacing`, which is what the pledge notice shows.

| Row | Sentence |
|---|---|
| blank, `0`, the word `unknown`, message `0`, message `unknown` | em dash `—` |
| `UNKNOWN` | its own sentence |
| `WEBHOOK_CONTEXT_UNAVAILABLE` | the generic sentence. The raw code is not shown |
| message `途中彩蛋已下线` | the mapped sentence |
| `501`, `601`, and the codes named in `docs/release/receipts/ui-cur-errors.md` | the catalog sentence in English or zh-Hans |

The footer prints the production host and the four area flags, then `FEATURE_CLOSED false` and `CASH_CLOSED false`, then those two sentences. A decoded integer `0` is not this row. That `0` is on the shelf and the chat export.

## Permission pre-prompts (60)

Each card is `CYPermissionPrimer` for that kind. Not now does not request access. Open Settings is the denied primary title. The last tap is labelled on the fixture only.

| Name | Card |
|---|---|
| `cur6-permit-location` | location, before the system prompt |
| `cur6-permit-location-denied` | location off |
| `cur6-permit-camera` | camera, before the system prompt |
| `cur6-permit-camera-denied` | camera off |
| `cur6-permit-notification` | notifications, before the system prompt |
| `cur6-permit-notification-denied` | notifications off |
| `cur6-permit-photos` | save to Photos, before the system prompt |
| `cur6-permit-photos-denied` | Photos denied. Body is the installed denial sentence |

`cur6-invite-unknown` mounts `IMInviteReminderToggle` with presentation unknown. The line is `—`. Settings is absent. `cur6-invite-denied` is off and offers the notification Settings button.

The older `permission-primer` and `permission-primer-denied` names still mount the location step card.

## Compliance (61)

| Name | Screen |
|---|---|
| `cur6-gate` | `UsageConsentGateView`. Lead, both document links, agree, decline. No checkbox |
| `cur6-privacy` | `PrivacyProtectionView` with consent missing. Short lead. Withdraw is absent |
| `cur6-privacy-granted` | same page with consent granted. Withdraw is present |
| `cur6-privacy-location` | `SettingsPrivacyLocationView` with no coordinator. Sheet sentence, home-city on/off, presence, roam, own media. A tap on home city reports that the setting was not saved. That line is after the tap |
| `cur6-agreement` | user agreement. Section 一 ends “本协议在你明确选择同意后对你生效。” The body is the source Chinese text |
| `cur6-cancellation-notice` | cancellation notice. Blocker 2 is “存在处理中的微信零钱提现或待审核的银行卡提现” |
| `cur6-privacy-policy-missing` | privacy policy reader. The body is still missing. No clause was added |
| `cur6-deregister-pending` | pending, no `executeAfter`. The time is `—`. Copy is the in-cooling-off sentence. The button is “撤销注销申请” |
| `cur6-deregister-cooling` | pending, `executeAfter` `2099-01-01 00:00:00`. The time is shown. Still in the cooling-off sentence |
| `cur6-deregister-ended` | pending, `executeAfter` `2000-01-01 00:00:00`. The label is “冷静期结束时间”. The after-cooling-off sentence is shown. Withdraw stays |
| `cur6-deregister-unknown` | status `UNKNOWN`. The unknown step copy is shown. No invented time |
| `cur6-chat-export` | `NPCChatDataExportButton` “导出我的对话记录” / “Export my chat records”. A null time is `—`. `createTime` `0` stays `0`. `retentionDays` `0` is decoded and is not a day count on the button |
| `cur6-chat-export-empty` | no records. The button is absent. The fixture shows `—` |

`e4-deregister`, `e4-deregister-blocked`, and `e4-marketing` still mount the review, blocked, and marketing sheets. `consent` still mounts the gate.

## Search filters (62)

| Name | Screen |
|---|---|
| `cur6-search-list` | search-list `SearchMapFilterSheet`. One sort chip, 最近 / Recent. No 最热. No city tag, city role, or `sort_type` |
| `cur6-search-list-zero` | same sheet with minimum and maximum `0`. `GlobalSearchQuery.matches` does not treat a minimum of `0` as active. `String` of that `Double` is `0.0` in the field |
| `cur6-search-map` | map sheet. 商家标签, 城市角色, categories, dates, price. Sort is 最热 (`sort_type` 2). 最近 stays the other choice |
| `cur6-search-map-empty` | map sheet, categories loaded and empty |
| `cur6-search-map-failed` | map sheet, category load failed, retry is present |
| `cur6-shelf-topics` | discovery topics. Chips come from shelf tags, including 全部 and 全部分类. 风味巡游 is 1800 seconds. 风味巡游·夜市 is the same theme by prefix and is 4000 seconds. 城市藏宝猎人 has `totalTime` `0` and `locationCount` `0`, both shown as `0`. A missing `totalTime` is not shown as `0`. A missing stop count uses `topic.countUnknown` (“Unknown” / “未知”), which is the existing row, not a new em dash. 野生邻居观察局 is dropped |
| `cur6-shelf-topics-empty` | only the hidden theme. The topic shelf is the empty state |
| `cur6-shelf-topics-failed` | topic read throws HTTP 503 |
| `cur6-shelf-games` | game shelf. 闭眼味觉师 duration `0` does not match 5 分钟内 and is not drawn as `0` minutes (`durationMinutes` skips `0`). 街角谜题 duration `5` does match. A lower id of the same title is dropped. `G12｜不应出现` is dropped. Pack type 1 is dropped. Home `total` is the decoded `0` |
| `cur6-shelf-games-empty` | no shelf games and an empty home |
| `cur6-shelf-off` | reader not configured. The title is `discovery.unavailable` (“Discovery didn't load” / “发现页没加载出来”) |

`template-topics` and `template-games` still use `DiscoveryFixtureReader`. Those sample names are not shelf themes.

## Skipped

| Screen | Reason |
|---|---|
| Unseen `WEBHOOK_*` codes listed in `ui-cur-errors.md` | Not mapped. One of them is on `cur6-errors` as the generic sentence |
| Play-only 300-meter location modal and the WeChat capsule settings path | Not copied onto the global card in handover 60 |
| Camera overlay and spatial-reveal Open Settings | Shown only after the OS status is denied or restricted. The pre-prompt is `cur6-permit-camera` |
| Share-card Open Settings after a Photos denial | The denied card is `cur6-permit-photos-denied` |
| Minor protection and anti-addiction | No mini-program screen. None was added in handover 61 |
| Privacy-policy body | Not in the mini-program repo. `cur6-privacy-policy-missing` shows the missing reader |
| Exploration-record export | Already JSONL. No new screen |
| A second account-deletion path | Not added. Cancellation stays on `AccountComplianceSheet` |
| Search-list 最热 | Not in the rendered search2 sheet. Not added back |
| Sending list 最近 as activity `sort_type` | Forbidden. The chip is not a `sort_type` |
| A discovery sort, pack chips, topic API category chips, 推荐 as the all chip, a forced 竞技对抗 chip, a 场景 dimension, result chips 主题模板 and 玩法模板, and the extra topic content shelves | Not on the shelf. Not added |

`swiftc` did not run. Screenshots were not taken.
