# mount-g45: mount the G4/G5 player capability views

Base: `origin/ui/cloud-g-social-roam` 2d32e97f6 (ui/main ec2e42ba8 + G4/G5). Source list: the "not mounted" rows of
`docs/release/receipts/cloud-g-social-roam.md`. Mini-program reference: `chengyinhub-xcx` (`pages/play/merchant`,
`pages/roam`, `pages/search2/result`, `pages/publish/temp`, `subpackageA/pages/myproject`, `subpackageMember/*`).

## Wiring (AppSession.swift / AppCompositionRoot.swift unchanged: 8176 / 4307 lines)
- `App/AppSessionSocialRoam.swift`: `SocialRoamCapabilities` bundle (play-grant `PlayerCapabilityClient`, account id,
  token, `SquareService` for `me/posts|bookmarks` only while community read is configured, community-open flag,
  read-only public-home reader), `AppSession.socialRoamCapabilities()`, environment key `\.socialRoamCapabilities`
  (default nil), and `SocialRoamCapabilityRoot` modifier.
- `App/QuestifyApp.swift` `chain0`: one line, `.modifier(SocialRoamCapabilityRoot(session: session))`. The modifier
  observes the session, so sign-out / account switch drops the bundle at once.
- `App/SocialRoamMounts.swift`: one entry view/modifier per mount. Every entry draws nothing when the bundle is nil
  (signed out, unconfigured, fixtures, previews), so existing hosts and fixtures are unchanged without it.

## Mounts (view -> host screen -> entry id)

| View | Host screen (mp page) | Entry | Entry id |
|---|---|---|---|
| `SquareMineListView(.posts)` | 我的: `AccountView` after `MPParityAccountLinks` (`pages/member`) | `SquareMineAccountLinks` | `account.square.mine.posts` |
| `SquareMineListView(.bookmarks)` | same (`pages/mylike`) | same | `account.square.mine.bookmarks` |
| `MerchantSafetySummaryRow` | `PublicMerchantHomeView`, after the featured card (`subpackageMember/components/cy/profile/merchant-safety-summary`); hidden for offline examples | `PublicMerchantTrustSection` | `merchant.safety.summary` |
| `MerchantCorrectionSheet` | same (`merchant-correction-sheet`) | same | `merchant.publicHome.correction` |
| `MerchantSafetyRatingSheet` | play merchant page `PlayStoreDayMerchantView`, end of content (`pages/play/merchant` `cy-safety-rating-sheet`); the tap resolves `node.merchantId` (owner member id) through public-home to `mms_merchant.id`, as the mp sheet does | `PlayStoreDaySafetyRatingEntry` | `storeDayPage.safetyRating` |
| `GeocodedAddressButton` | same page, address card, only when the node has no coordinates (`open-address.js`) | `PlayStoreDayGeocodeEntry` | `map.geocode.open` |
| `RoamShopVisitorsStack` + `RoamShopVisitorsModel` | Roam: `RoamBrowserView` result rows, roam places (`sourceType` 1), one load per visible strip (`pages/roam` BL-70 `poi__who`) | `RoamPlaceVisitorsLine` + `RoamShopVisitorsLoad` | `roam.shop.visitors.1.<placeId>` |
| `MapWeatherOverlay` + `MapWeatherModel` | Roam map (`RoamBrowserView.roamMap`) for the searched area, cell centre only | `RoamMapWeather` (modifier) | (decorative, hidden from accessibility) |
| `RoamShareRevokeRow` | Roam share sheet `RoamHistoryShareView`, under the share-link notice | `RoamShareRevokeEntry` | `roam.share.revoke` |
| `TemplateAdoptButton` | public template detail `DiscoveryTemplateDetailView`, under the 采用/share CTA row (`pages/publish/temp` adoption, player scope '') | `TemplateAdoptEntry` | `template.adopt` |
| `TemplateLocationTodosSection` | topic editor `ProjectEditView` for a saved topic (`topic-template/binding-status`), scope = `ProjectEditOwner.rawValue` | `TemplateLocationTodosEntry` + `TemplateLocationTodosHost` (modifier on the editor form) | `template.location.bind.<slotKey>` |
| `TemplateProjectActions(.topic)` | My projects `CreatorContentProjectsView`, under each topic row; hidden for browse-only merchant lists, 'MERCHANT' scope in merchant mode (`subpackageA/pages/myproject` save-as) | `MyProjectSaveAsTemplateEntry` | `template.saveAs.<topicId>` |
| `UnifiedSearchResultsView` | search result page `GlobalSearchView.results`, above the footer (`pages/search2/result` content leg); topic/activity rows open the existing search destination | `UnifiedSearchEntry` | `searchMap.unified.open` |
| `MapPlaceSearchModel` | search map, city mode `SearchMapExplorerView`, under the city keyword field (`components/cy/map-address-search` remote leg); a row opens Maps, the explorer's area and reads are unchanged | `MapPlaceSuggestions` (modifier) | `searchMap.place.<id>` |

## Fixes needed to make the mounted views load
A `.task` on a `Group { if … }` that starts empty never runs (checked with a SwiftUI probe: Group, EmptyView, empty
`Section` and a Group of sections inside `List` never fire; an empty `VStack` and the `List` itself do). Two G4/G5
views loaded that way and would have stayed blank once mounted:
- `MerchantSafetySummaryRow`: `Group` -> `VStack(alignment: .leading, spacing: 0)`; mounted in one row with the
  correction button so an empty summary leaves no blank list row.
- `TemplateLocationTodosSection`: the read moved to `TemplateLocationTodosStore` (same "a failed read keeps the last
  confirmed view" rule), owned by `TemplateLocationTodosHost` on the editor form and passed through the environment.
  The section now takes the store; the bind path still re-reads after each bind.
New entries avoid the pattern: weather and place suggestions are modifiers on the always-present map / field, the
visitor load is a modifier on the result list, and the rating entry resolves on tap.

## Not mounted (deliberate)
- `TemplateProjectActions(.template)` (`{id}/market-submit`): the only mp host is the own template shelf
  (`subpackageMember/mytemplate`), and the native own-shelf screens keep their pinned contract that they never
  dispatch market-submit (`test_template_own_shelf_host_flow`, `test_w2_04_*`, `TemplateOwnShelfMarketPlan.isDispatchable == false`).
  Needs a product decision before it is mounted.
- `RoamSessionArchive.flush` (`api/roam/session/records`): not a view; it needs the live-roam finish recovery's
  pending tile records, which the native live roam does not keep yet.
- `TemplateAdoptionService.authorDetail` (`author-info` / `author-myinfo`): no view; no editor caller yet.
- `BundleAPIClient.orderReceipt`: follows a purchase, which stays unmounted (money).

## Gates
- `tools/generate_project.py`: 3520 native sources (2 new files). `tools/check_scaffold.py` PASS.
  `tools/check_appsession_ratchet.py` PASS (AppSession 8176, AppCompositionRoot 4307, both unchanged).
  `tools/check_design_lint.py` PASS.
- `swiftc -parse` clean on every changed Swift file.
- Contract checks that read any edited host file: 151 run; 19 fail identically on the base 2d32e97f6 (same failing
  test names), none new. Template own-shelf / member-tools contracts and `test_player_write_grant` pass.
- Not compiled or run here (integrator compiles); no simulator or UI test evidence.
