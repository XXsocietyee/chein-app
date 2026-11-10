# PAGE-READY `pages/topic/pricing/partner/index`

合作方分润预览页. Native screen `App/PublisherLifecycleViews.swift` `PublisherPartnerView`. Map status on `rc/20261108` is already `exists` (`docs/parity/page-map.csv`). This note does not change that status, does not add a route, and does not mark a route live.

Base `86fa48b0c5833bbadd97c09f246ad05f7af1b8b0` (`rc/20261108`). Branch `cursor/cb258`.

Core and tests only. Views, `Resources/Localizable.xcstrings`, `docs/release/ui-strings*.json`, the Xcode project, and `tools/current_ci_manifest.json` were not edited. Payment, payout, and withdrawal were not enabled. `xcodebuild` was not run. This machine has no `swift` toolchain, so the new tests were not executed.

## What rc already had

- Read contract: `PublisherLifecycleHTTP.partner(topicID:type:id:)` loads `POST api/topic/pricing/preview`, then either `POST api/club/detail` or the existing owner-member `PublicMerchantHome` read. It does not call `api/merchant/public-detail`.
- Those two pricing paths were already `liveInProduction` in `Core/ChinaReviewedRouteCapability.swift`. This change does not edit that table.
- Invalid terms, a duplicate partner, a mismatched club id, a merchant home that is not the owner member, a dormant read grant, and a credential change during the read already fail closed. Those tests were left as they were.
- `testMissingFloorNeverBecomesZero` already keeps a missing floor from becoming 0 and keeps a literal JSON 0 as 0.
- The view already shows loading (`publisherPricing.loadingPartnerInformation`), an invalid link, an empty profile line (`publisherPricing.noProfileYet`), and a load failure through `PublisherLifecycleCopy.error`.

## What was missing

The merchant branch stored only `id`, `memberId`, `name`, and `description`. `PublicMerchantHome` already carries the other facts the page reads: `address`, `businessTime`, `availableTime`, `suitActivityTypes`, `demand`, `capacity`, and `sysCategoryList`. They never reached the profile, so the existing screen could only show the name.

`TopicPricingXcx.merchantPartnerProfile` now copies those fields, and `partner` uses it. A missing `capacity` is omitted. A JSON `0` stays `0`. Blank category names are dropped. No new path is requested.

`TopicPricingXcx.partnerMoneyText` renders a missing, blank, non-numeric, or `UNKNOWN` amount as `—` (U+2014). A literal `0` stays `"0"`.

`TopicPricingXcx.partnerPreviewPhase` names the read: `loading`, `empty`, `error`, `unknown`, `ready`. Loading wins. A failure is `error`. No inspection and no failure is `unknown`. `empty` means the identity loaded and none of the detail rows the page already shows are present. A member count or capacity of `0` is a row, not an empty profile. This classifier does not open a route and the view does not call it yet.

## Player-first entry

This page was not added to the player tabs. `SessionTopicDetailView` does not set `topicPricingDestination`, so the player topic page keeps the pricing sheet hidden. The owner link "定价与合作条款" stays on `PublisherLifecycleProjectLinks`, which is the publishing host, not the player-first tab bar.

## Missing keys

Catalog lookups in `PublisherPartnerView`: **none missing**. All 35 keys below are in `Resources/Localizable.xcstrings` with translated `en` and `zh-Hans`. `python3 tools/localization_usage_audit.py` on this tree reported `key_missing_everywhere: 0`.

`publisherPricing.address`, `publisherPricing.availableTimes`, `publisherPricing.capacity`, `publisherPricing.category`, `publisherPricing.charging`, `publisherPricing.city`, `publisherPricing.clubType`, `publisherPricing.fixed`, `publisherPricing.fixedFee`, `publisherPricing.freeHosting`, `publisherPricing.goBackAndOpenItAgain`, `publisherPricing.hostingMerchant`, `publisherPricing.leader`, `publisherPricing.level`, `publisherPricing.loadingPartnerInformation`, `publisherPricing.locked`, `publisherPricing.members`, `publisherPricing.noProfileYet`, `publisherPricing.openingHours`, `publisherPricing.paidHosting`, `publisherPricing.partnerClub`, `publisherPricing.partnershipNeeds`, `publisherPricing.partnershipTerms`, `publisherPricing.people`, `publisherPricing.perPerson`, `publisherPricing.referral`, `publisherPricing.revenueShare`, `publisherPricing.settlement`, `publisherPricing.share`, `publisherPricing.suitableRoutes`, `publisherPricing.termsFreezeWhenSalesOpenSettlement`, `publisherPricing.termsFreezeWhenSalesOpenSettlement44`, `publisherPricing.theLineupFreezesWhenSalesOpen`, `publisherPricing.thisPartnerLinkIsNoLonger`, `publisherPricing.whenSalesOpen`.

Keys and copy this page still does not have:

| Missing | Why it is still missing |
|---|---|
| `chargeType` | `PublisherPartnerView` reads this profile field. `PublicMerchantHome` does not declare it. It was not invented. A missing charge is not stored as `0` and is not shown as free or paid hosting. |
| Catalog key for `TopicPricingXcx.partnerLockedNote` | The sentence `阵容已锁定，以下为该合作方在本主题中的结算条款。` is a Chinese constant. It is not in `Localizable.xcstrings`. The view does not show it. |
| Catalog key for `PublisherLifecycleCopy.error` | The partner load failure uses the hardcoded pair `未能核实信息，操作未提交。请刷新；真实操作尚未启用。` / `Information could not be verified. No operation submitted. Refresh; live actions remain disabled.` A server `rejected` message is still passed through. |

`TopicPricingXcx.lineupLockedNote` is the parent pricing page's sentence, in the same file, and is also not a catalog key. It is not a row on this screen.

## Tests

Added, not executed here:

- `TopicPricingXcxTests.testPartnerMoneyUnknownIsDashAndZeroStaysZero`
- `TopicPricingXcxTests.testPartnerPreviewPhaseCoversLoadingEmptyErrorAndUnknown`
- `TopicPricingXcxTests.testMerchantPartnerProfileProjectsHomeFactsWithoutChargeOrZeroFill`
- `PublisherLifecycleTests.testMerchantPartnerProjectsHomeFactsAndDoesNotInventChargeOrCapacity`

Existing partner tests were not edited, including `testPartnerTermsComeFromFreshLineup`, `testInvalidPartnerTermsDoNotLoadProfile`, `testClubPartnerUsesJSONAndRequiresExactReturnedClubID`, `testMerchantPartnerResolvesOwnerMemberWithoutLegacyRowRequest`, and `testDormantPricingGrantCannotInvokeMerchantReader`.

## Left

- `PublisherPartnerView` still formats a share as `\(shareRate ?? "—")%` and a fixed fee as `¥` plus `fixedFee ?? "—"` plus `publisherPricing.perPerson`. It does not call `partnerMoneyText`. A nil amount therefore still appears as `—%` or `¥—` until a view pass.
- The view still keeps its own loading flag, `noProfileYet`, and error string. It does not bind `partnerPreviewPhase`.
- The locked-note sentence is still not on screen, and it still has no catalog key.
- `chargeType` is still absent from the home contract.
- Confirming a final price stays on the existing dormant publisher review. No payment, payout, or withdrawal switch was turned on.
- `api/topic/pricing/preview` and `api/topic/pricing/confirm` stay at the marks they already had. No route was added.
