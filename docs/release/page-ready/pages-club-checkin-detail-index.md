# pages/club/checkin-detail/index

Lane CB245. Map status: exists. Native screen: `App/ClubGovernanceViews.swift` (not edited).

The read contract is already live: `api/club/crm/checkin/detail` (`ClubGovernanceRead.checkin`). This lane does not add a route and does not mark one live. Refund, payment, payout, and withdrawal stay off. `showsMerchantChoice` is false.

`ClubCheckinDetailPage` in `Core/ClubCheckinRail.swift` binds that existing read. A missing client capability stays hidden. Phases are loading, empty, error, unknown, and ready. UNKNOWN, null, a missing number, and a numeric string display as an em dash (`—`) and are not stored as 0. A literal JSON 0 stays 0. `serverCanRefund` records a JSON boolean only; `showsRefundAction` and `refundDispatchEnabled` stay false.

Tests added in `Tests/CoreTests/ClubCheckinRailTests.swift`. Existing rail tests are unchanged. `swift test` was not run: this environment has no Swift toolchain. `xcodebuild` was not run. No Xcode Cloud result is claimed.

## Missing EN+zh-Hans keys

These keys are referenced by `ClubCheckinRail.StateKind.titleKey` and are absent from `Resources/Localizable.xcstrings`. The catalog was not edited. The Chinese lines are the literals already returned by `title`.

| Key | EN | zh-Hans |
|---|---|---|
| `club.checkin.state.missing` | Check-in record not found | 核销记录不存在 |
| `club.checkin.state.denied` | You cannot view this check-in record | 无权查看该核销记录 |
| `club.checkin.state.error` | Check-in detail failed to load | 核销详情加载失败 |

`club.gov.empty` (empty phase) and the existing `club.checkin.rail.*`, `club.gov.field.*`, and `club.refund.*` keys used by this page already have both EN and zh-Hans.

## Left

- `ClubGovernanceViews` still renders `ClubCheckinDetailRows` and `ClubOwnerRefundPanel`. It does not read `ClubCheckinDetailPage`, and it does not pass `stateKind` into the rail.
- The three keys above are not in the string catalog, so the state titles remain Chinese literals.
- Owner refund dispatch stays gated off. This lane does not install `ClubOwnerRefundApproval`.
