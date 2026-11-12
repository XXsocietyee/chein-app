# mp-prroam — Package L4 (P0) Roam / Play / IM / collectibles page models

Branch `ui/prroam` from `origin/ui/main` (3b319cbb9). Layout side only: SwiftUI views and catalog keys.
No Core, network, reducer or test file was edited. CODE-ONLY: no xcodebuild, simulator or Swift run.
Source of truth: `liboyang42-cpu/hengyin` `chengyinhub-xcx` (local read-only checkout). No screenshots taken or shared.

## Page → native file mapping

| mp page | Native view(s) | Core page model now read | What was matched |
|---|---|---|---|
| `pages/roam/index` (护照 tab) | `App/RoamHomeTabsView.swift` (`RoamHomePassportView`) | `RoamHomeIndexPassportPresentation` | Four stats come from the presentation texts. Loading keeps the same stat row with `—` per reading (mp R-02 `pp-stats` placeholder) instead of a spinner; error keeps `RoamExperienceIssue` + retry; unknown `—`, known `0`/`0.0` numeric. `.numericText` transition, Reduce Motion drops the animation. Goals / capsule tiles are now hidden when `privateToolsReader` is nil (capability absent ⇒ hidden). Tile tap-navigation untouched (ui/rbug). |
| `pages/play/index` | `App/PlayTaskSummaryView.swift`, `App/PlaySessionView.swift` | `PlayIndexPageReadiness` | Unknown progress is the em dash (`playx.progress` / `play.progress` label + `—`, VoiceOver reads `play.progress.unknown`). Identifier `referenceTask.phaseOnly` kept on the static text (UI test). `PlayExperienceView.swift` itself not edited (ui/mpflows). |
| `subpackageB/pages/im/chat/index` | `App/MessagingHistoryView.swift` | `IMChatSessionWire.fromReader` / `.failed` → `IMChatSessionPage` | Page model recorded per first-page read. `IMChatSessionPhase.unknown` (empty first page that still reports `hasMore`) now shows a distinct unknown state (`messaging.history.unknown`) instead of "No messages yet". Send / read receipt / poll unchanged (still hidden by the model). |
| `subpackageB/pages/im/list/index` | `App/IMInboxViews.swift` (`IMInboxRow`, `IMUnreadBadge`) | `IMListPageReady.rowUnreadBadge` (tab totals were already wired in `MessagingHomeView`) | Row badge: absent unread is a quiet `—` capsule (VoiceOver "Unknown"), real 0 shows no badge, `99+` kept. Entry badges keep hiding an unknown total. |
| `subpackageP3/pages/badge-wall/index` | `App/ObjectBadgeWallParityViews.swift` | `ObjectBadgeWallPageState.project(_:).counts` | When the medal collection never arrived (`isPartial`), the header shows `— / —` + `badgeWall.state.unknownDetail` with `badgeWall.count.unknown` identifier, instead of dropping the header. Known walls unchanged (ring + collected/locked). |
| `subpackageP3/pages/stamp-album/index` | `App/RoamStampViews.swift`, `App/StampAlbumParityViews.swift` | `StampAlbumIndexPageModel.project(pager)` | Headline `{{total}} 枚` from `totalText`: ready = literal, unknown = `—` (never a guessed 0); next-page loading keeps the read headline. Unknown + no rows shows `stampAlbum.unknownDetail` (`roam.experience.album.unknown`) instead of the empty album. Capture stays hidden. |
| `subpackageP3/pages/stamp-camera/index` | `App/RoamStampCameraView.swift` | `StampCameraPageContract`, `StampCameraPageReady.captionUnits` | Create button and 投一张换一张 exchange rows hidden while `mediaUpload` / `stampExchange` are false (previously exchange rows rendered because the session always passes a closure). Caption counter reads the measured UTF-16 units. |
| `pages/club/detail/index` | `App/ClubDetailView.swift` | `ClubDetailPageModel.resolve` → `ClubDetailPageContent` | Only source-present facts are forwarded (level 0 / missing count no longer become `0`); non-ready fallback is `—`, not `club.memberCount`. Overview facts are the mp `.ov-facts` three-cell grid (主理人 / 俱乐部类型 / 所在城市) from `leaderText` / `typeText` / `cityText`, stacking at accessibility sizes; ids `club.detail.factsGrid`, `club.detail.fact.leader`, `club.detail.fact.type`, `club.detail.fact.city`. Money switches untouched. |
| `pages/crop/index` | `App/MiniCropView.swift`, `App/TemplateImageCropView.swift` | `CropPageModel.facts(session:)`, `CropPageModel.facts(hasOpener:…)` | Batch position from `progressText` (`—` when unknown, nothing for one image); confirm/use-original gated by `canConfirm` / `canUseOriginal`; confirm title from `confirmKey`; empty / unknown / error states use `pages.crop.*`. Canvas stays mounted while loading so the frame is still measured. Template crop failure copy uses `pages.crop.error`. Upload stays off. |
| `pages/club/topic-detail/index` | `App/ClubGovernanceViews.swift`, `App/ClubTopicDetail+Port.swift` | `ClubTopicDetailPort` (already wired) | No change needed for layout; see Left. |
| `pages/club/topic-story/index` | `ClubGovernanceStoryView`, `App/ClubNodeAnswerContent.swift` | `ClubStoryPresentation` (already wired) | Already complete per page-ready note; no change. |

## Catalog (EN + zh-Hans) added to `Resources/Localizable.xcstrings`

From the page-ready ui-strings JSON in history (not merged to ui/main): `roam.nearbyEvents.teamsFailed`, `roam.nearbyEvents.teamsLoading`, `roam.home.passport.metric.unknown`, `im.list.unknown`, `badgeWall.state.{loading,empty,error,unknown,unknownDetail,signIn,denied,malformed,retry}`, `badgeWall.count.{unknown,known}`, `stampAlbum.unknown`, `stampAlbum.scopeExpired`.
Listed missing in the crop page-ready doc: `pages.crop.{loading,empty,error,unknown,busy,retry}`.
New for this layout: `im.chat.unknown.title`, `im.chat.unknown.hint`, `im.list.unread.unknown`, `stampAlbum.unknownDetail`.

## Checks

- `tools/check_design_lint.py` PASS, `tools/check_scaffold.py` PASS (14738 bilingual keys). No new files, so `tools/generate_project.py` was not needed.
- Contract checks touching edited files: unchanged versus base except two snapshot assertions that pinned the pre-wiring state and now fail by design:
  - `Tests/ContractChecks/test_pages_crop_index.py::test_missing_keys_are_listed_and_not_added_to_the_catalog` (asserts `pages.crop.*` are NOT in the catalog).
  - `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py::test_model_keeps_unknown_as_a_dash_and_hides_missing_writes` (asserts the view does NOT reference `StampCameraPageReady`).
- Pre-existing errors on base (unchanged): cb224, cb225, club_detail_page_ready, object_badge_3d_preview, object_badge_wall_page_state (missing ui-strings JSON fixtures on ui/main).

## Left for Cursor (logic)

1. Flip the two snapshot assertions above to the wired state (keys present; view reads `StampCameraPageReady`).
2. Restore the page-ready `docs/release/ui-strings-*.json` files the contract checks load (present in history, absent on ui/main).
3. Roam: home journal still local `history()`, not `GET /api/roam/passport/summary`.
4. IM chat: `IMChatSessionCoordinator` is not driven by the view (the view keeps its own read; it now records the coordinator's projection via `IMChatSessionWire`). IM list loading/error still come from `MessagingReadScreen`, not `IMListPageCoordinator`.
5. Badge wall: loading/error/hidden come from `ProfileReadScreen`, not `ObjectBadgeWallPageCoordinator`; failure keys (`badgeWall.state.signIn/denied/malformed`) are catalogued but not mounted.
6. Crop: circle mask (`round`) and `merchantLight` are not passed into `MiniCropView` (no shape/merchant input); `MiniCropGeometry` still treats `UNKNOWN` ratio as free. `MerchantImageCropView` / `CreatorCropExportView` not wired.
7. Club topic detail: director sheets, primary footer, overview-link gating on `canViewVerify` / `canDirect` / `canManageSessions`, and `.endTopic` `cancellationEpoch` remain (logic + governance, not layout).
8. Integrator must compile: no Swift build was run here.
