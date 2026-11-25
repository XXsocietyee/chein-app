# cursor-wire2-member

Base `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (`origin/ui/combined-r7`, "Integrate F-agent round 2"). Tip had not moved. No rebase. Branch `cursor/wire2-member`. No pull request.

Source receipt: `docs/release/receipts/cursor-mp-cov-member.md`. Contracts already on this base were not rebuilt. The 3 endpoints and the 4 tests in `Tests/CoreTests/MiniProgramMemberContractTests.swift` were not edited. No new endpoint.

`PlatformPass.moneyEnabled` stays false. `MPParityBindings.moneyEnabled` stays false. Cancel, confirm, and refund-apply still throw `PlatformPassWriteRefusal.unreachable` before any transport send. No pay sender. No money write was turned on.

This VM has no `swiftc`. This receipt does not claim a parse.

## Call sites moved

| site | contract | what the tap does |
|---|---|---|
| `App/PassMarketViews.swift` `PassOrderRefusedWrites` resume (`canResume`, 继续付款) | `PlatformPass.passOrderConfirmPath` then `confirmPassOrder` | Throws. Sends nothing. Does not call pay. |
| same view, cancel (`canCancel`, 取消订单) | `PlatformPass.passOrderCancelPath` then `cancelPassOrder` | Confirmation sheet, then the method throws. Sends nothing. |
| same view, refund (`canRefund`, 申请退款) | `PlatformPass.passOrderRefundApplyPath` then `refundApplyPassOrder` | System Form sheet, trimmed reason, then the method throws. Sends nothing. |
| `App/SocialPublicProfileView.swift` `SocialProfileInlineStartChatButton.startWithContract` | `ProfileIMStartContract.request` and `ProfileIMStartContract.conversationID` | Form body `target_member_id`, header `content-type: application/x-www-form-urlencoded;`. A positive `conversationId` opens the existing chat destination. |

The pass-order gate note `mp.passOrder.gated` stays on screen. The reader is `AppSession.makePlatformPassReader()` (the read-only pass transport). A missing reader does not build a second sender. `QuestifyApp` only publishes that session into `passOrderWriteSession`.

`QuestifyApp` publishes `profileIMStartWire` (base URL, token, existing `runtimeHTTPTransport`). The inline 发消息 button uses it. Fixtures that do not install the wire still use the reviewed coordinator.

## Left as they were

- Hosts with no IM destination still open `SocialActionEditorView(purpose: .startChat)`. That editor is not the profile form send.
- `MPParityPassSession` and `MPParityBindings.moneyText(_:)` were not edited.
- SettingsView, MerchantVerifyRecordsSections, PlatformConsumerSessionOwner, RoamPOIActions, JourneyReportViews, TeamHomeView, TicketWalletView, TopicXcxSections, ClubDetailView, and ClubWorkbenchKit were not edited.
- `project.pbxproj` and `tools/current_ci_manifest.json` were not edited.
