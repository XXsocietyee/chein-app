# CB96 — localisation gaps after the UI merges

Base `origin/rc/20261108` (`576e869a995c280f325799ad8ea9a2729ac30781`). Branch `cursor/cb96`.

The UI merges already on this RC left user-facing copy in Swift (`ChannelCopy`, `CoreLoopCopy`, and `zh`/`en` ternaries) and one `LocalizedStringKey` default that had no catalog entry. Those strings are now keys in `Resources/Localizable.xcstrings`, with the English and Simplified Chinese that the screens already showed. Call sites read the catalog through `appLocalized` or `Text`. `Resources/Localizable.xcstrings` was not reformatted: the diff only inserts entries.

`club.channel.rules.body`, `club.channel.rules.title`, and `club.channel.rules.accept` are the channel sheet's existing sentences, copied unchanged. This note does not add a UGC policy, a support contact, legal text, or a China ICP number. Placeholders in the support playbook and community guidelines stay as they are.

Screens that already had an exact pair now use that key instead of a second copy:

- Retry on `CYErrorState` uses `action.retry`.
- Wallet “All” uses `wallet.all`.
- Wallet “Pending settlement” uses `wallet.pendingSettlement`.
- “No income this month” uses `wallet.analysis.noSources` in `WalletIncomeAnalysis`.
- “Muted” uses `im.inbox.mutedLabel`.
- The disabled photo attachment uses `d7.channelChat.photo`.

`ui/d6` was already on `origin/rc/20261108` when this branch was cut. It was not merged again. `ui/d7` was not merged. `tools/check_scaffold.py`, `tools/current_ci_manifest.json`, and `.github/workflows/ios-ci.yml` were not edited.

## Keys added (28)

| Key | en | zh-Hans |
|---|---|---|
| `Couldn't load this. Check your connection.` | Couldn't load this. Check your connection. | 无法加载这个内容。请检查网络连接。 |
| `club.channel.announcementReadOnly` | Announcement · read only | 公告 · 只读 |
| `club.channel.attachment.add` | Add attachment | 添加附件 |
| `club.channel.attachment.link` | Link | 链接 |
| `club.channel.backToList` | Back to channel list | 返回频道列表 |
| `club.channel.membersCount %lld` | Members & roles · %lld | 频道成员与身份组 · %lld |
| `club.channel.mute` | Mute channel | 频道免打扰 |
| `club.channel.rules.accept` | Accept Channel Rules & EULA | 我已阅读并同意频道公约 |
| `club.channel.rules.body` | Before posting or moderating, you must agree to our zero-tolerance policy against objectionable content, harassment, and spam. Reported content is reviewed within 24 hours and violators will be removed or banned. | 参与频道发言与治理前，请确认遵守社区安全准则：严禁发布违法违规、骚扰辱骂、欺诈广告及令人反感的内容。被举报内容将在 24 小时内由安全团队审核并处理，违规成员将被删帖并移出或封禁。 |
| `club.channel.rules.prompt` | Review the channel rules to post | 发言前请先阅读频道公约 |
| `club.channel.rules.review` | Review rules | 查看公约 |
| `club.channel.rules.title` | Club Channel Rules & Safety EULA | 俱乐部频道公约与安全守则 |
| `club.channel.unmute` | Unmute channel | 取消频道免打扰 |
| `club.leave.confirmTitle %@` | Leave “%@”? | 退出「%@」？ |
| `club.leave.memberEventsEnd` | Member-only event spots end immediately; payments already made are not refunded automatically | 会员专属活动的报名资格立即失效，已付款项不随退出自动退回 |
| `club.leave.notKept` | This can’t be undone; your membership and join date won’t be kept | 此操作不可撤销，当前的成员身份与加入时间不会保留 |
| `club.leave.removedFromGroup` | You’ll be removed from the group and lose member-only content | 你会被移出团群，看不到成员专属内容 |
| `merchant.publicHome.gameFacts` | Store content and original reply | 店内内容与原回复 |
| `official.inbox.capacity %lld` | Capacity %lld | 承接名额 %lld |
| `profile.orders.viewDetails` | View details | 查看详情 |
| `wallet.assets.availableBalanceLabel` | AVAILABLE BALANCE | 可提现/可用余额 |
| `wallet.assets.disputedLabel` | Disputed | 争议中 |
| `wallet.assets.myAssets` | My assets | 我的资产 |
| `wallet.assets.withdrawableLabel` | Withdrawable | 可提现 |
| `wallet.ledger.referenceID` | Reference ID | 流水编号 |
| `wallet.ledger.timestamp` | Timestamp | 记录时间 |
| `wallet.monthIncome.title` | Income this month | 本月收入明细 |
| `wallet.more` | More | 更多 |

## Scaffold

```
python3 -B tools/check_scaffold.py
missing_keys: 0
untranslated_values: 0
key_identifier_mismatches: 0
gaps: 0
PASS design lint: scanned 1458 App Swift files outside DesignSystem and Theme; allowlist 11 files (13 existing violations)
PASS structural checks: 4351 Swift source files, 14374 bilingual keys, references, scheme, read-only expected project equivalence
SCOPE: this script does not run Swift/Xcode, previews, simulator/device, accessibility or live backend checks; see separate evidence
```
