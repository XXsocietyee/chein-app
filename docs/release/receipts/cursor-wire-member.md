# Receipt: cursor/wire-member (L1)

Owner: Cursor. Wire the member Core call sites named in `docs/release/receipts/cursor-core-member.md`. Screen chrome from the merged fix branches stays.

Base checked before any edit: `origin/ui/combined-r7` is `82388e4a5e7391e0c5a286735d6b30613a860ae8`, which matches the expected prefix `82388e4a5e73`.

Merged before the wiring commit:

- `origin/fix/r3-member-a` fast-forwarded to `ee151b7f5` (`fix-r3 member-a r2`).
- `origin/fix/r3-member-b` merged as `a19ade657` (`merge: bring fix/r3-member-b screen work onto wire-member`).

No restyle. No new folder, so `tools/generate_project.py` is unchanged. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. No new xcstrings fragment: reused `profile.loading` and `ticketWallet.loading`. Money stays on the existing TEST-only paths. No new gate.

This VM has no `swiftc`. Nothing here was parsed or compiled. Python contract checks were executed against the changed call sites. A green contract check is a source pin, not a Swift parse.

## Left as already wired

- `App/CouponCodeView.swift` already has `case .notMine`. Not edited.
- `publishListScope` on the coupon list was already set before `load()` by member-a (`CouponManagementView` list `.task` / `.refreshable`, and the deep link passes `.merchant` only when `query["scope"] == "MERCHANT"`).
- Server terms were already wired by member-a: `MPParityPassSession.membershipContent` passes `terms: overview.terms`, and `PassMembershipViews.termFacts` uses the server coverage, seat (`mp.member.fact.seat`, 适用范围), period, renewal, and refund lines, with the fixed OR-024 lines only when that server text is empty.
- Optional invoice `id` was already wired by member-a: `MPReviewedPageScreen` `subpackageMember/invoice/index` mounts `InvoiceLaunchDetailView` when `reviewedID(query)` is a positive decimal, and `InvoiceLaunchHistoryView` on the bare path. `id=0` and a non-canonical id stay on the history list.

## Wired in this commit

| call site | what the screen now does |
|---|---|
| `App/CouponManagementView.swift` detail | `CouponManagementDetailView` takes the same `CouponPublishListScope` and sets `model.core.publishListScope` before both `load()` paths (toolbar reload and `.task`). |
| `App/TemplateAuthoringMineView.swift` | `applyShelfScope()` writes `coordinator.operationScope` and `coordinator.shelfReader.operationScope` to `"MERCHANT"` when the parent `themeDomain` or `roleTheme` is `.merchant`, otherwise `nil`. Called at the start of `refresh()`, `loadMore()`, and `prepare()`. The pinned `.task(id: sessionRevision)` line still begins `rows = []; cardFacts = [:]; review = nil; rowStates = [:]; await refresh()`. Player chrome is unchanged. |
| `App/ProfileOrdersView.swift` | The history screen opts into `profileOrderHistory(pageNum:)`. Page 1 replaces the list. A bottom sentinel appends the next page while `ProfileOrderPage.hasMore` is true, dropping a late page when the owner filter or a reload bumps `historyGeneration`. `try await reader.profileOrders()` remains the single unpaged fallback for a reader that does not offer the page method. `orders()` itself is unchanged and still sends no `status`. |
| `Core/ProfileReading.swift` `ProfileSessionReader` | New `profileOrderHistory(pageNum:)` calls `ProfileService.orderHistory` and does not pass `expectedAccountID`, matching `profileOrders()`. |
| `Core/OwnedOrderRead.swift` `OwnedOrderSessionReader` | New `profileOrderHistory(pageNum:)` calls `orderHistory` with the session account id. `ProfileSelfOrdersScopedReader` does not gain the method, so that screen stays on `profileOrders()`. |
| `App/TicketWalletView.swift` cover | `TicketWalletRow` shows `ticket.coverURL` only as an https URL with no user, password, fragment, whitespace, or backslash, and at most 512 UTF-8 bytes. `AsyncImage` fills the cover. The ticket illustration remains only when that URL is absent. |
| `App/TicketWalletView.swift` focus | When `focusId` is missing from the usable list, one `.task` loop calls `reader.ticketDetail(id:)`. A matching id opens the existing detail, which reads the ticket again. A mismatch or read error keeps the existing missing state. No `Task {` and no `.task(id:)`. |

`ProfileOrderPageReading` is an App protocol. `ProfileSessionReader` and `OwnedOrderSessionReader` conform to it. The name was unused in `App/` before this commit. `ProfileReading` itself does not gain `orderHistory`, so fixtures and `orders()` stay unpaged.

## Contract checks

Passed after the wiring edits: `test_profile_order_filters`, `test_ticket_wallet_read_lifetime`, `test_native_design_motion.NativeDesignMotionGuards`, `test_template_own_shelf_host_flow.TemplateOwnShelfHostFlow.test_card_facts_share_the_state_lifetime`, and `test_owned_template_pagination`.

Two pins still fail, and this commit does not edit the files they read:

- `test_same_my_list_response_keeps_card_fact_fields` asserts `MERCHANT` is absent from all of `Core/TemplateAuthoringShelf.swift`. That string is already on `origin/ui/combined-r7` from the Core member contract (`operationScope == "MERCHANT"`).
- `test_read_capability_does_not_enable_authoring` splits `func listMine()`. The method on this base is `func listMine(scope:)`.
