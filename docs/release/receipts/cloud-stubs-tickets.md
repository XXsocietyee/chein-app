# Cloud stubs — ticket wallet completion (ledger row 5)

Branch `ui/cloud-stubs-tickets`, parent `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Stub ledger row 5 only: `TicketWalletCompletionReading` / `\.ticketWalletCompletionReader`. Read only. No other ledger row is filled. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged (8176 and 4307 lines, both already at the ratchet ceiling). No new route, no live-route mark, no payment, payout, withdrawal, or virtual goods. The contract-failing baseline is not raised. `tools/check_scaffold.py` and `tools/check_design_lint.py` pass. This VM has no Swift compiler, so the new Core test was not executed.

## What the list row now says

`POST /api/registration/list` was already the wallet read (`TicketWalletService.list`). `TicketWalletTicket` now decodes `topicCompleted` from that same object. The request body is unchanged (`owner_type` only). A bad flag does not drop the row and does not add a row.

| JSON `topicCompleted` | Stored state | Filter bucket | Card line |
|---|---|---|---|
| missing, or `null` | `absent` | 全部 only | hidden (completed state stays hidden) |
| `false` | `upcoming` | 即将开始 | hidden |
| `true` | `completed` | 已通关 | 已通关 / Completed |
| anything else (`1`, `"yes"`, object, array) | `unknown` | 全部 only | — (VoiceOver: Completion unknown / 通关状态未知) |

`topicCompletedFlag` is `true` / `false` / `nil`. `nil` is what the existing filter already keeps out of both 即将开始 and 已通关. Tickets are the server rows only.

`TicketWalletDecodedCompletionReader` returns that flag. `TicketWalletCompletionRootModifier` sets `\.ticketWalletCompletionReader` on the player root, next to `CloudB3RootModifier`, so every wallet (account sheet, home, activity, journey) gets it without a session or composition edit. With no reader, the filter and the caption stay hidden.

## Copy (EN + zh-Hans)

Table `Resources/MpFresh.xcstrings` (not `Localizable.xcstrings`):

| Key | en | zh-Hans |
|---|---|---|
| `mpfresh.ticketWallet.completion.unknown` | — | — |
| `mpfresh.ticketWallet.completion.unknownLabel` | Completion unknown | 通关状态未知 |

已通关 on the card reuses `mpfresh.ticketWallet.filter.completed` (Completed / 已通关). The menu labels 全部 / 即将开始 / 已通关 were already in that table.

## Files

- Changed: `Core/TicketWalletContracts.swift`, `App/TicketWalletView.swift`, `App/TicketWalletCompletionBinding.swift` (comment only), `App/QuestifyApp.swift` (one modifier), `Resources/MpFresh.xcstrings`, `Tests/CoreTests/TicketWalletTests.swift`, `Questify.xcodeproj/project.pbxproj` (regenerated).
- Added: `App/TicketWalletCompletionReader.swift`.
- Not touched: `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `Core/TicketWalletService.swift` (the list decode already goes through `TicketWalletTicket`).

## 中文

只补账本第 5 行。票夹筛选 全部 / 即将开始 / 已通关 读的是 `POST /api/registration/list` 上的 `topicCompleted`，只读，不新造票。字段缺失或 `null` 不显示已通关；不是布尔值时卡面显示破折号「—」，旁白为「通关状态未知」。`AppSession` 与 `AppCompositionRoot` 没有加行。合同失败基线没有上调。
