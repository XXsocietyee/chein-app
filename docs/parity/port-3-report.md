# port-3 report (branch cloud/port-3, from origin/wip/gm-next)

Method: read each mini-program .wxml/.js (and the `cy-scene-roam-history` component behind history),
the page-map notes, and the native screen + Core types; listed gaps; implemented only what is safe to
do without a compiler. Nothing could be compiled or run here.

## Per page
- **stamp-camera -> RoamStampCameraView.swift**: audited. Camera permission/denied+Settings, pinch framing
  (RoamStampFramingState, percent label), 4:5 crop + EXIF-stripping redraw, upload + idempotent create,
  pending journal reconcile (`phase .unknown`), retake lock while pending, caption 30 limit are all present.
  Added: nothing. Missing: the mini-program's "back" action on a camera error that cannot open Settings
  (native only offers Settings; system back works). Not a behavior gap worth a hunk.
- **stamp-album -> RoamStampViews.swift**: audited. Count header, paging, continuation-retry vs whole-page
  error, empty state + camera CTA, FAB/toolbar camera all present. Added: nothing. Missing: collage
  (rotated scatter) layout and strict page validation (non-blank picUrl, total >= loaded). Strict
  validation NOT added: existing tests (RoamReceivedStampReadTests, RoamAlbumMetadataReadRouteTests)
  deliberately decode metadata-only rows with `picUrl:""`, so changing RoamAlbumPager would break them.
  (Notes mention StampAlbumCollageSlot in App/StampAlbumParityViews.swift; not re-audited.)
- **history -> RoamHistoryViews.swift**: audited against `scene-roam-history`. Summary strip, RunCard
  stats/medals/stamps, loading/error/empty/in-progress ("walk unfinished") states, retry present.
  Added: nothing. Missing: RunCard cover thumbnail (`photos[0]`) -- history photos are mini-program local
  file paths, unusable natively; per-card combined accessibility label (needs new string key).
- **citystamp -> RoamSubpageParityViews.swift**: ADDED the exchanged stamp photo on the print slip
  (`sgslip__photo`), which native never displayed although `RoamStampSlip.pictureURL` was already decoded.
  New: `Core/RoamStampSlipPhotoPort.swift` (https-only URL rule, same as album card),
  `RoamStampSlipPhotoView` appended to RoamSubpageParityViews.swift, hunk inserting it between the
  留于 row and 留给你的一句. Test: `Tests/CoreTests/Port3StampSlipPhotoTests.swift`.
  Still missing: 保存到相册 on the slip (needs fetching the remote image = new image-download transport,
  plus an addOnly PhotoKit writer for a non-share-card image; keys listed in port-3-new-strings.md);
  true pixel-coverage scratching (native uses a drag-distance approximation, plus accessible button).
- **capsule, monthly-recap, anniversary, exploration-export (subpackageTools/*)**: the mini-program
  checkout has NO `subpackageTools` directory and no page/component with those features
  (grep for 时光胶囊/月度回顾/那年今日/导出 finds nothing relevant), so there is no source to port.
  Not changed. capsule photo attachment remains blocked on a RetainedImage scope/destination (per notes).

## Could NOT verify
- Nothing compiled/tested. `Questify.xcodeproj/project.pbxproj` lists files explicitly: the local worker
  must add `Core/RoamStampSlipPhotoPort.swift` and `Tests/CoreTests/Port3StampSlipPhotoTests.swift`
  (SwiftPM picks them up automatically). The App change lives inside an existing file.
- `RoamStampSlipView` photo block: layout only reasoned, AsyncImage with `.scaledToFill` + frame clip.
