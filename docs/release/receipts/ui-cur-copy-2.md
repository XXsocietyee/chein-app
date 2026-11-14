# ui-cur-copy-2

Task 70. Branch `ui/cur-copy-2` from `origin/ui/main` `3ac970ec20191014b4b9a8779a3a94b961e99c9c`. No other feature branch was merged. `ui/main` was not pushed.

Player copy was read over HTTPS from public `liboyang42-cpu/hengyin` commit `73f4f7be45aa5b49381baa2c1aff57e1b2245fad` (`master`, `fix: 平台自玩路线走查第四轮`). Tree `chengyinhub-xcx`. That repo has no glossary file. The terms below were checked against the Chinese in that tree and against `docs/release/glossary.md` in this app. No translation was invented.

`swiftc` is not on this machine. No typecheck was run.

## On this tip

| Handover | Where | Strings |
|---|---|---|
| 45 `ui/cur-appeal-images` `ad108e43e` | `Resources/PlayCreatorTail.xcstrings` keys `audit.attach.*` | Compared with `subpackageA/pages/myproject/index.wxml` and `utils/transport/upload-client.js` at the hengyin commit above. |
| 47 `ui/cur-fixtures-4` `ffa4129c4` | `App/DesignFixtures/Cur4Fixtures.swift` | The handover receipt says no new copy. The footer is the DEBUG label `DEBUG fixture ·`. Unknown rows already draw `—`. |
| WP-11 follow-up `ui/cur-wp11-followups` `ce5e28999` | countdown labels in `App/PlayKitScreen.swift` and `App/PlayAdvancedTeamViews.swift` | Already on this tip. An unknown remaining time is `—`. A decoded `0` was not rewritten. No catalog key changed. |

These Chinese lines already match the mini-program and were left as they are:

| Key | zh-Hans | Where it was read |
|---|---|---|
| `audit.attach.add` | 添加申诉图片 | `myproject/index.wxml` |
| `audit.attach.hint` | 最多6张，须本人上传并通过内容安全审核；以平台校验为准 | same wxml |
| `audit.attach.remove` | 移除附件 | same wxml (`移除附件` plus the index) |
| `audit.attach.oversize` | 文件过大，请压缩或更换文件后上传（单个文件最大10MB） | `upload-client.js` `oversizeMessage` at 10MB |
| `audit.attach.pending` | 文件已提交审核，通过后请重试此文件 | `upload-client.js` |
| `audit.attach.rejected` | 媒体审核未通过，可重新提交审核 | `upload-client.js` |
| `audit.attach.missing` | 上传结果缺少文件地址 | `upload-client.js` |
| `audit.attach.uploading` | 提交中 | `提交中` occurs in `chengyinhub-xcx` (loading copy). Not rewritten. |

English on those keys is sentence case and does not use a glossary term that disagrees with the Chinese. It was left.

## Left, not in the glossary and not in the mini-program

| Key | en | zh-Hans |
|---|---|---|
| `audit.attach.dismiss` | Dismiss the upload error | 关闭上传错误 |
| `audit.attach.item` | Attachment | 附件 |

`关闭上传` does not occur in `chengyinhub-xcx` at that commit. `附件` appears only inside longer lines (`移除附件`, `原申诉及附件意图`), not as this label. `docs/release/glossary.md` has neither pair. Both were left.

## Terms changed

None.

## Not on ui/main

These tips are not ancestors of `3ac970ec2`. Their strings were not copied in.

| Handover | Branch |
|---|---|
| 41 | `ui/cur-appstore` |
| 42 | `ui/cur-a11y` |
| 43 | `ui/cur-tests` |
| 44 | `ui/cur-fixtures-3` |
| 48 | `ui/cur-visual-parity` (PR 1231 calls that note handover 48) |
| 49 | `ui/cur-visual-parity-2` |
| 50 | `ui/cur-copy` |
| 51 | `ui/cur-states` |
| 52 | `ui/cur-deeplinks-2` |
| 53 | `ui/cur-push` |
| 54 | `ui/cur-analytics` |
| 56 | `ui/cur-perf` |
| 62 | `ui/cur-search` |
| 65 | `ui/cur-fixtures-6` |
| 66 | `ui/cur-uitests-2` |
| 68 | `ui/cur-release-config` |

These branches are also not on this tip. Their receipts do not name a handover number, so they are listed by branch: `ui/cur-appearance`, `ui/cur-errors`, `ui/cur-permissions`, `ui/cur-compliance`, `ui/cur-fixtures-5`, `ui/cur-uitests`, `ui/cur-store-shots`, `ui/cur-logs`.

No remote receipt names handovers 46, 55, 57, 58, 59, 60, 61, 63, 64, 67, or 69. They were not reviewed. `ui/cur-rm-01` is task 75, outside this range, and is not on this tip.

`ReviewedAreaSwitch` was not redeclared. Money stays behind that switch. `www.chengyinhub.com` stays closed. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` were not edited. `docs/release/contract-failing-baseline.txt` was not raised.
