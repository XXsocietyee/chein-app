# mp-prkeys — L1 missing keys + L5 coupons / free-explore pages

Branch `ui/prkeys`, based on `origin/ui/main` `3b319cbb9`. Plan source: `ui/docinv` `docs/release/receipts/docs-inventory.md` §B1, rows L1 and L5.
Code-only: no `xcodebuild`, no simulator, nothing compiled here. The integrator compiles.

## L1 — catalog keys

### Added to `Resources/Localizable.xcstrings` (en + zh-Hans, `extractionState: manual`)

| Page-ready doc | Keys | Count |
|---|---|---|
| `pages-address-address` | `profile.participants.{refreshing,loadFailed,serviceUnavailable}`, `participant.list.{deleteTitle,deleteBody,deleteIrreversible,deleteKeepsRegistration,deleteConfirm,deletedTitle,deletedDetail}` | 10 |
| `pages-coop-invite-detail-index` | `cooperation.detail.state.{loading,missing,invalidId,absentId,identity,errorTitle,listFailed,network,notFoundDetail,backToList}`, `cooperation.detail.countdown.{remaining,expired}` | 12 |
| `subpackageMember-couponInfo-couponInfo` | `couponManagement.{save,range.completed,network,dataError,retry}` | 5 |
| `subpackageMember-complaint-index` (source sentences that had no key) | `profile.complaint.{loadFailed.network,loadFailed.source,loadingTopics,chooseTopicPrompt,chooseKindPrompt,reasonPlaceholder,contactPlaceholder,submitFailed,pickTopicTitle,pickKindTitle}` | 10 |
| `Resources/WorldEnvironment.fragment.json` (merged unchanged with `tools/merge_localization_fragments.py`) | `world.environment.waitingSource`, `world.environment.unknown`, `world.expiry.waitingSource`, `world.party.waitingSource`, `world.equipment.waitingSource` | 5 |
| `subpackageMember-coupon-wallet-index` (L5) | `accountCollection.coupon.{permission,errorTitle,malformed,network,navigate,openInMaps}`, `accountCollection.coupon.availableFrom %@` | 7 |

Also added `paidAmount` and `saleUnknown` to the `Resources/FreeExploreBundleLaunch.xcstrings` table. The doc's names were `freeExploreBundle.paidAmount` and `freeExploreBundle.saleUnknown`, but that table uses bare keys. The 7 coupon-wallet rows were also mirrored into `docs/account-collection-localizations.json`.

### The inventory's count of 51 versus the keys actually missing

The inventory counted every dotted token under the docs' "Missing keys" headings. 24 of those tokens are not copy, so I did not catalog them:

- **search2 (20):** `searchMap.filter.*`, `searchMap.category.*`, `searchMap.more`, `globalSearch.category.loading`, and the rest. The doc itself says these are accessibility identifiers, and the code passes them only to `.accessibilityIdentifier(...)`. Every user-facing search lookup is already in the catalog.
- **complaint (3):** `profile.complaint.loading`, `profile.complaint.open`, and `profile.complaint.retry` are identifiers. To cover that row, I catalogued the 10 complaint source sentences that really had no key (table above).
- **coupon (1):** `batchCode.title` is an abbreviation of `couponManagement.batchCode.title`, which already exists. The doc lists `CooperationIssue.key` as a Swift symbol, not a key.

### Contract checks I had to update (for Cursor to review)

These checks asserted that a lane had *not* added keys. Each one was flipped to assert that the key is now present with en + zh-Hans. No other assertion changed.

- `Tests/ContractChecks/test_coop_invite_detail_page_ready.py`: `test_missing_keys_are_listed_and_absent_from_the_catalog` → `..._now_catalogued`
- `Tests/ContractChecks/test_coupon_info_page_ready.py`: same flip for the 5 `couponManagement.*` keys
- `Tests/ContractChecks/test_coupon_management_integration.py`: the `couponManagement.` count goes from 90 to 95
- `Tests/ContractChecks/test_c02_world_party_character.py`: the shared catalog must now equal the fragment entries; before, it had to be absent

## L5 — mini-program page → native file

| mp page | Native file | Matched now |
|---|---|---|
| `subpackageMember/couponInfo/couponInfo` | `App/CouponManagementView.swift` (`CouponManagementEditor`) | The create sheet now reads `CouponInfoSettingsPage.project(...)`, with capability built from the existing `canRead`/`canSimulate` and `canReviewPublish` (it turns nothing on). The phases (loading, empty, error, unknown, ready) draw `page.stateKey`. Error offers `page.retryKey`. Unknown offers `page.recoveryKey` (recover pending commands, never a resend) plus a read-only section of em-dash values. Publish review appears only for `publishGranted` on a new definition and is enabled only by `showsPublishAction`. No save action exists. The mini-program toast 时间设置完成 now shows inline as `couponManagement.range.completed` after a confirmed range, with Reduce Motion handled through `CYMotion.resolve`. |
| `subpackageMember/coupon/coupon` | `App/CouponManagementView.swift` (list and detail) | The list row always draws remaining: an em dash when unknown, a literal 0 as `0`. A failed read no longer draws the empty state under the error notice. Detail counts and amount go through `CouponInfoCount.display` / `CouponInfoAmount.from(...).displayText`. |
| `subpackageMember/coupon-wallet/index` | `App/AccountCollectionCouponsView.swift`, `App/AccountCollectionCouponDetailView.swift`, `App/AccountCollectionComponents.swift` | Network and failure issues on the wallet use mini-program copy: title 优惠券暂时没能打开, with a network or malformed detail. A server message still wins. The row now draws the shop name and address when present. An unknown end date shows `—` (still omitted for an invalid coupon, whose pill already says so). Detail has a 导航 button that hands the shop coordinate to Maps through the existing `NativePlatformMapOpener`. It is hidden when either axis is missing or 0, matching the mini-program's `Number(lat) && Number(lng)`. The `accountCollection.coupon.futureStart` identifier and its "Not yet started" copy are unchanged, because a UI test reads them. |
| `subpackageMember/coupon-qr/index` | `App/CouponCodeView.swift` | The countdown binds `model.remainingText`: hidden or unknown shows `—`, a displayed 0 stays `0`. It uses a numeric content transition, or none under Reduce Motion. New identifier: `couponCode.remaining`. |
| `subpackageMember/free-explore/index` | `App/FreeExploreBundleLaunchView.swift` | The view switches on `FreeExploreBundlePageReady.screen(...)`, mapping the model lane, failure, and kept catalog/order: stale, loading, empty, load error (with reload), unknown (recover/retry card, or a spinner if nothing has arrived), and ready. Ready keeps the existing chapter, store, and time flow, adds a refresh-failed banner that keeps the last record instead of zeroing it, a `saleUnknown` note when no catalog arrived, and a `paidAmount` row (`—` when unknown). Purchase and unsubscribe stay hidden (`showsPurchase`/`showsUnsubscribe` are false). |

Payments, payout, withdrawal, redemption, and virtual goods stay off. No route was added or marked live. No DEBUG fixture was touched. All existing accessibility identifiers are kept.

## Still needs logic (Cursor)

- **Coupon wallet 403:** `AccountCollectionIssue` has no permission case. A 403 still arrives as `.server`/`.failure`. `accountCollection.coupon.permission` is catalogued but unused until Core adds the phase.
- **`accountCollection.coupon.availableFrom %@`** is catalogued but not drawn, because the UI test pins the existing "Not yet started" copy on `futureStart`.
- **couponInfo edit:** there is no update contract, so `couponManagement.save`, `.network`, `.dataError`, and `.retry` are catalogued but unused. The page model still uses `couponManagement.refresh` for retry, and submit failures are not split into network versus data.
- **Free-explore:** `FreeExploreBundleLaunchModel` exposes no price, paid amount, or refund quote, so `Snapshot.priceText`/`paidAmountText`/`quote` are nil and the paid amount row shows `—`. `readRefundQuote` is still not called.
- **Complaint:** `ProfileComplaintTopicLoadFailureCopy.networkSubtitle` / `sourceSubtitle` in Core still return raw Chinese. The new `profile.complaint.loadFailed.*` keys are ready for Core to return instead. The other 8 complaint keys are ready for the form placeholders and pickers.
- **Participants and coop invite detail:** the new keys are catalogued. Wiring `ProfileParticipantListPage` and `CooperationInviteDetailPage` into their views belongs to other packages.
- The `couponManagement.` count of 95 and the flipped assertions above need Cursor's agreement.
- `tools/current_ci_manifest.json` was not refreshed for this new receipt file.

## Checks run here

- `tools/generate_project.py`: no project change (no new Swift files)
- `tools/check_design_lint.py`: PASS
- `tools/check_scaffold.py`: PASS
- `tools/check_catalog_coverage.py`: gaps 0, untranslated 0
- Coupon, account-collection, coop-invite-detail, address, complaint, c02-world, and localization contract checks: OK
- Swift: not compiled here
