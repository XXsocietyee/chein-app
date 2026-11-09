# CB225 — stamp album collage gallery

Base: `rc/20261108`. Branch: `cursor/cb225`. Page: `subpackageP3/pages/stamp-album/index/index`.

`StampAlbumIndexPageModel` in `Core/RoamExperienceCoordinators.swift` projects loading, empty, error, and unknown for the existing `RoamAlbumMetadataReadRoute` list read and `RoamAlbumPager`. Unknown and empty totals are an em dash (`—`, U+2014). A numeric string is not shown as `0`. The visible row count does not replace a missing total.

`registersRoute`, `marksRouteLive`, `opensHost`, `showsCapture`, and `showsMerchantChoice` stay false. Capture stays hidden because `RoamExperienceCapabilities.mediaUpload` is false. No route was added and none was marked live.

Evidence: `Tests/CoreTests/StampAlbumIndexPageModelTests.swift`, `Tests/ContractChecks/test_cb225_stamp_album_index_page.py`, `docs/release/ui-strings-subpackageP3-pages-stamp-album-index-index.json`, and DEBUG `StampAlbumIndexFixtureData`. The view file was not edited. `xcodebuild` was not run.
