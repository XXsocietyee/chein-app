# wire-2 report (branch cloud/wire-2 from origin/wip/port-build)

Nothing here was compiled or run (no Swift toolchain in the cloud container). Every symbol was checked by grep.
No routes, leases, endpoints, gates, Resources/xcstrings, AppSession/AppCompositionRoot/QuestifyApp touched. No existing test edited.
New strings: `docs/parity/wire-2-new-strings.md` (raw keys show until added).

## Wired
1. **topic/merchantinfo** (`App/MerchantContentViews.swift` recruit view, +`App/MerchantTopicDetailSection+Wire2.swift`, `Core/MerchantTopicDetailFacts.swift`):
   - stat bar (hours / open dates / mileage; rating and merchant-count cells omitted exactly as the recruit page filters them),
   - 节点介绍 template shelf (`cmsMemberTemplate`: image with placeholder, players, minutes),
   - 任务向导 chapters: chapter meta line (time / stop count / play count) and numbered node list with swipeable photo gallery + description.
   All from the already-read `topic` object; no new reads. Images: plain https only (same rule as slip photo).
   Tests: `Tests/CoreTests/Wire2MerchantTopicDetailFactsTests.swift`.
2. **subpackageRoam/citystamp** (`App/RoamSubpageParityViews.swift` hunk, `App/RoamStampSlipPhotoSaver.swift`, `Core/RoamStampSlipSavePolicy.swift`):
   "保存到相册" row under the slip picture. Tear-first and no-picture checks mirror `onSave`; add-only permission via the existing
   `RoamSharePhotoLibraryWriter` (requested only on tap); denied -> existing settings button. Tests: `Wire2StampSlipSavePolicyTests`.
3. **publish/simple**: `QuickPublishingJourneyOwner.draftBinding` setter and `adopt` now apply `QuickPublishFieldLimits.clamped`
   (title 30, story 500, stop name 30, stop story 300). 3-stop AI cap was already enforced by `parseAI`/`adopt`.
4. **pages/address**: `ProfileParticipantsView` gained optional `onSelect: ((Int) -> Void)?` (default nil, so all current call sites unchanged);
   when a sign-up caller supplies it a row tap returns the participant id instead of opening detail. No caller passes it yet.

## Not wired
- merchantinfo **QR voucher section**: the source issues `api/merchant/chapter-node/poster-code` from a live checkin sheet for the merchant's own node.
  The native app already reaches the same poster via the "nodes" document (`.poster(nodeID:)` -> `MerchantContentCodeView`); embedding a second issuer
  in the recruit view would need a new lease/read context, so it was left. Also not done: my-chapter-applications offer/circle status lines, cover image.
- publish/simple: template-shelf `?idea=` seed (`seededIdea` exists, no caller channel), "quota exhausted" inline banner, on-screen character counters.
- infomation: disabled "内容待完善" rows — need `SocialAccountService.informationList` to stop filtering unusable rows, which existing tests rely on; left.
- address: no caller currently opens the list in select mode (needs the sign-up flow to pass `onSelect`).

## Unverified
Compilation of everything. Specifically: `let` bindings inside the ViewBuilder bodies (`wire2Facts`, `rowLabel`); `Text` interpolation keys with two `%lld`;
`@Sendable` default fetch closure under strict concurrency in `RoamStampSlipPhotoSaver`; `TabView(.page)` inside a List/ScrollView; Photos add-only
behavior on device; whether `startDate/endDate` strings from the API are China-local (assumed; only the date part is read).
Run `Wire2*Tests`.
