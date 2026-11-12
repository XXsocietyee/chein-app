# cloud-clubops (U3 / L6)

Branch `ui/cloud-clubops` from `origin/ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`. Each named view reads its Core page model. Unknown money and counts render as an em dash (U+2014). A literal 0 stays 0. Merchant and coop stay off the player shell: `WelcomeView.showsMerchantChoice` is false, and the account cooperation row is behind that flag. `merchantSurfaceHiddenInV1` stays true. Payment, payout, withdrawal, virtual goods, and password login stay off. `App/RegionalLaunchConfiguration.swift` was not edited. No new route is marked live. No Xcode or simulator run on this machine.

## Page → native file

| page | native file | what matches | what is left |
| --- | --- | --- | --- |
| club/checkin-detail | `App/ClubGovernanceViews.swift` (`ClubCheckinRailView`) | `ClubCheckinDetailPage.bind`. Rail `stateKind` comes from phase `.error`. Registration id and paid amount still come from `Facts`. Refund dispatch stays off (`showsRefundAction` forces `sourceCanRefund` false). `ClubOwnerRefundPanel` remains the locked explanation. | State-title catalog keys from the page-ready note are not added. Xcode not run. |
| club/customer-detail | `App/ClubOpsCustomerViews.swift`, call site in `App/ClubGovernanceViews.swift` | `ClubCustomerDetailPage.project`. Metric tiles use page counts (`displayText`, em dash when unknown). Paid amount uses `ClubCustomerDetailPaidAmount` (withheld keeps the hidden sentence, unknown is an em dash). | `memberId` preselect and unused page catalog keys stay unused. DEBUG fixture stays DEBUG-only. |
| club/event-ops | `App/ClubOpsEventView.swift` | Already reads `ClubOpsEventAccess` (loading / denied / failure / ready). No separate `*Page` type. | Cancel and attendance stay on `ClubOpsEventWriteGate.notAvailableYet`. |
| club/governance | `App/ClubOpsGovernanceSections.swift` | Ban, members, and cases call `ClubOpsGovernancePage.project` with the matching include flag. Counts use `displayText` (em dash, never a stand-in 0). A hidden projection does not blank a roster the host already loaded. | Page-level catalog keys from the page-ready note are not added. Recovery copy stays. |
| club/group-code | `App/ClubGovernanceViews.swift` | Already calls `ClubGroupCodePage.project`. Headcount uses `displayText`. The call stays outside the host-status and check-in slices. | Group-code page keys from the page-ready note are not added. |
| club/notify | `App/ClubGovernanceViews.swift`, `App/ClubOpsNotifySections.swift` | Audience calls `ClubNotifyPage.project`. Send stays behind `broadcastOffered`. Delivery calls `ClubNotifyDeliveryPage.project`. A nil count is an em dash. Retry stays behind `campaign.canRetryFailed` and `delivery.retryOffered`. | Broadcast and retry still do not claim success. Event-audience grant is unchanged. |
| club/roles | `App/ClubOpsGovernanceSections.swift` (`ClubOpsRoleSection`) | Reads `ClubOpsRoleRoster`. Empty delegation is a known zero (`delegableMemberCount == 0`). | No `*Page` type. Unused `clubOpsGov.roles.emptyBody` / `assign.caption` stay unused. Role-name fallback stays the catalogued “角色”. |
| club/settlement | `App/ClubOpsSettlementViews.swift`, `App/ClubSettlementDetail.swift` | Summary and detail already read `ClubOpsSettlementSummary` / the detail presentation. A missing amount is now a visible em dash; the existing unverified / unknown keys stay as accessibility labels. Owner withdraw stays a lock chip. | Direct-ledger Chinese literals and payout date are not drawn. No payout. |
| coop/finance | `App/CoopFinanceProfitView.swift` | Already reads `CoopFinanceProfit`. Nil amounts are an em dash. | Row label “查看{topicName}的结算详情” and “结算信息待补充” are not added. |
| coop/invite | `App/CooperationContextualViews.swift` | Club member counts come from `CoopInviteIndexReadiness.Count` (unknown, blank, and `"00"` are an em dash). A known integer, including 0, keeps the `%lld` string. Merchants still have no member count. `inviteSendOffered` and `shareOffered` stay false. | Missing catalog keys (`toId`, `originApplyId`, `merchantName`, `share`, `coopInvited`, `originalRequest`, `countdown`) are not invented. |
| coop/invite-detail | `App/CooperationInviteDetailView.swift` | Already calls `CooperationInviteDetailPage.project`. The slot line shows text only when both slot counts are `.text`. | Countdown keys are not added. |
| coop/list | `App/CooperationBrowserView.swift` | Already calls `CoopListPageCoordinator.project`. Counts are accessibility values. | `pages.coop.list.index.*` keys are not added. The player account row that opened this screen is behind `showsMerchantChoice` (false). Merchant fixture hosts can still build the screen. |
| coop/settlement-detail | `App/CoopSettlementDetailView.swift` | Already reads `CoopSettlementDetailModel`. Nil amounts are an em dash. | Payout date is not drawn. No payout. |
| coop/withdraw | `App/CoopWithdrawShellViews.swift` | Explains offline support and opens `WithdrawalSupportContactView`. Does not submit `/api/withdrawal/apply`. | Withdrawal stays off. |
| coop/withdraw-records | `App/CoopWithdrawShellViews.swift` | Forwards to the existing wallet records view or shows failure plus retry. | Does not enable a withdrawal write. |
| assetcenter/analysis | `App/WalletIncomeAnalysisReader.swift`, `App/WalletIncomeAnalysisView.swift` | `pageModel` is `AssetCenterAnalysisPageModel`. Empty plus partial is `.unknown`; a confirmed empty slice is `.empty`. The view shows `moneyText` (em dash) for unknown and empty. The income route stays `api/user/balance/list`. | DEBUG host is not mounted. Month chart is unchanged. |
| assetcenter/earnings | `App/WalletCommerceViews.swift`, `App/WalletEarningsOverview.swift` | Home asset rows use `WalletFundsStageClassifier`. Unknown, loading, failed, signed-out, and unconfigured phases use `WalletFundsStagesInline`. Known amounts keep the existing card. The em dash is `WalletIncomeDetailPageModel.unknownMoney`. | DEBUG earnings menu host stays DEBUG-only. `WalletPayoutCapability.isOn` stays false. Session wallet still passes `showsCooperationFinance: false` and `showsWithdrawalSupport: false`. |
| invoice/apply | `App/InvoiceLaunchApplyView.swift` | `InvoiceLaunchApplyPage.project`. Non-finite amounts use `InvoiceLaunchApplyAmount` (em dash). Known amounts, including 0, stay the two-place formatter. Apply shows only when `showsApplyAction` (still false while payment and the host write switch are off). | The “apply unavailable” sentence is omitted while writes are off. No second sheet. Apply is not enabled. |
| invoice/titles | `App/InvoiceLaunchTitlesView.swift` | `InvoiceLaunchTitlesPage.facts`. Tax uses `taxText` (unmasked is an em dash). Pending save hides edit, delete, and add. The saved request id is the accessibility value. | Sign-in and pending catalog keys listed in the page-ready note are still missing and were not invented. |
| invoice/title-edit | `App/InvoiceLaunchTitleEditor.swift` | `InvoiceLaunchTitleEditorRead.screen`. A pending save locks the form on the saved request id (`unknownText` when the id is empty). Masked tax is a caption and never enters `$tax`. Save dismisses only after `model.save` returns success. | No fake write success. |
| invoice/detail | `App/InvoiceLaunchDetailView.swift` | Amounts go through `invoiceLaunchDisplayedAmount` (`InvoiceLaunchApplyAmount`). A missing order title is an em dash. | Issuer, reconciliation, support, and 重新申请 are not added. Cancel still requires `model.cancel` success. |
| invoice/index | `App/InvoiceLaunchHistoryView.swift` | Rows still use `InvoiceLaunchHistoryRules`. Amounts go through the same apply-amount display. Withdraw success is announced only after `model.cancel` returns success. | Issuer name is not shown. Payment stays off. |

## Safety that stayed

- `WelcomeView.showsMerchantChoice = false`. Account cooperation (`account.cooperation`) renders only inside that flag, so the player build does not show it.
- `ReleaseMoneyWriteSwitch` payment, payout, withdrawal, and virtual goods stay false.
- `WalletPayoutCapability.isOn = false`.
- DEBUG fixtures were not referenced from production views.
- Accessibility identifiers already on these screens were kept.

## Follow-up on the same branch

- Notify preview reads `ClubNotifyPage.previewRecipient`. A known count, including 0, stays the people line. Unknown is an em dash.
- `docs/release/ui-strings-pages-club-customer-detail-index.json` is restored so the customer-detail page-ready check can load it. Each row names table `ClubOpsCustomer`. The four `club.customerDetail.page.*` keys are in that catalog in EN and zh-Hans.
- `docs/release/ui-strings-subpackageA-pages-assetcenter-analysis-index.json` is restored so the analysis page-ready check can load it. Those keys were already in the wallet catalogs.
- `test_club_ops_customer.ClubOpsCustomerCatalog.test_every_table_key_used_in_swift_exists` still fails on the pre-existing dead constants `clubOps.customers.unknown` and `clubOps.customers.unknownLabel` (`docs/release/receipts/contract-backlog-1.md`). Those rows were not added.
- Swift and Xcode are not installed here, so there is no `xcodebuild` or simulator run.
