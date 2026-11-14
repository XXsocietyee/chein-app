# Dark mode and Dynamic Type (ui-cur-appearance)

Branch `ui/cur-appearance` from `origin/ui/main` `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0`. Scope is the screens that landed after `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`: strings, WP-03, WP-04, CL-01, and the batch-7 compile fixes. No new color and no new font. Existing `CYColor` and `CYTypography` tokens only. Unknown values stay `—` (U+2014). Money stays closed. `ReviewedAreaSwitch` was not redeclared. `AppSession`, `AppCompositionRoot`, and `RegionalLaunchConfiguration` were not edited. No new Swift file, so `generate_project.py` was not required.

`CYColor` already resolves a light and a dark pair from the trait collection (`dynamic` / `CYDomainPalette.resolving`). Player roots force dark and merchant roots force light. Text uses Dynamic Type text styles (`CYTypography`). At accessibility sizes, a row that was a horizontal pair stacks, and copy wraps instead of staying on one line.

## Screens touched

| Screen | Where | What changed |
| --- | --- | --- |
| WP-03 store decoration | `MerchantOperationsHomeView` | `MerchantOpsWp03Panel` (page `.decor`) uses `CYTypography` / `CYColor` / `CYSpacing`. Loading keeps the en / zh-Hans “Loading” line and stacks the spinner above it at accessibility sizes. A missing value is `—`. |
| WP-03 character review | `MerchantStoreCharacterView` | Same panel (page `.npc`) on `CYColor.bgPage`, inset with `CYSpacing`. |
| WP-03 store team | `MerchantBusinessHomeView`, `MerchantBusinessPage` | Same panel (page `.team`). |
| WP-03 coupon summary | `CouponManagementView` | Same panel (page `.coupon`). |
| WP-03 chapter invite | `MerchantContentHomeView`, `MerchantContentRecruitView` | Same panel (page `.chapter`). |
| Author square delete | `SquareDetailView`, `AccountCollectionFavoritesView`, `ClubHomeView` feed, `CoopRelationDiscoveryView` | `CreativeSquareAuthorDeleteSection`. Post id and Delete sit in a column at accessibility sizes. Colors and type were already CY tokens. |
| Square author unknown | `SquareDetailView` | Member id `0` stays `—` and wraps. |
| Coop invite receipts | `CoopFlowNewInvitationView` (`CoopInviteReceiptSections`) | State, request id, invite id, and station name use CY type and color. A missing field is `—`. Retry is full width at accessibility sizes. |
| Coop read receipt | `CooperationInviteDetailView` (`CoopInviteReadReceiptRow`) | Same tokens. The failed state spaces with `CYSpacing` and the retry is full width at accessibility sizes. |
| Missing author square | `ClubHomeView`, `CoopRelationDiscoveryView` | A nil reader stays `—`. |

## Screens left

Strings (`ui-cur-strings`) changed catalogs only (`Localizable`, `MerchantAuthoring`). No screen. CL-01 changed the matrix, `SUPPLEMENT.md`, and citation tests. No screen. Batch-7 made `MerchantOpsWp03Phase` visible and added `markInviteRead` to an existing lock key. The lock key is not a screen; the panel is listed above.

Left as they were, on the same files: merchant chapter title (`.font(.title2)`), square comments and actions, the club feed under the new section, the relation list under the new section, and the account / session navigation that only passes `authorSquare`. No other screen was restyled.

## Checks

`python3 tools/check_design_lint.py` PASS (1614 App Swift files; allowlist unchanged). `python3 tools/check_scaffold.py` PASS (catalogs, release config, privacy, design lint, project equivalence, AppSession ratchet, page route table). This VM has no `swiftc`, so the Swift files were not parsed or compiled.

## 中文

分支 `ui/cur-appearance`，基线 `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0`。只动 `a2a9d82` 之后落到 `ui/main` 的界面：文案补齐、WP-03、WP-04、CL-01，以及 batch-7 的编译修复。没有新颜色，也没有新字体。未知仍是破折号 `—`。支付仍关闭。没有重新声明 `ReviewedAreaSwitch`，也没有改 `AppSession`、`AppCompositionRoot`、`RegionalLaunchConfiguration`。没有新增 Swift 文件。

改过的界面：WP-03 装修、形象、团队、优惠券、章节邀请上的面板；广场作者删除（详情、喜欢、俱乐部帖文、商家关系）；广场作者未知；合作邀请的原请求和据点；邀请已读回执；作者广场未接通时的破折号。

没有改的界面：文案任务和 CL-01 没有页面。batch-7 的锁键不是页面。同一文件里原有的章节标题、广场评论、俱乐部信息流、关系列表其余部分，以及只是把作者广场传下去的导航，都保持原样。其余页面没有改样式。

`check_design_lint.py` 与 `check_scaffold.py` 通过。本机没有 `swiftc`，没有解析，也没有编译。
