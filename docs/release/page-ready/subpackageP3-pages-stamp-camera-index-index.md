# CB224 page-ready: subpackageP3/pages/stamp-camera/index/index

Map status stays partial. This lane fills only the non-view gaps on `rc/20261108`.

`StampCameraPageReady` and `StampCameraPageContract` live in `Core/RoamStampCaptureCoordinator.swift`, beside the existing create coordinator. Loading, empty, error, and unknown are explicit. Unknown text is an em dash (U+2014). A missing album total, a non-positive created id, and a numeric string stay unknown. A confirmed empty album stays empty. A measured caption length of 0 stays `0`.

Create and exchange stay hidden while `RoamExperienceCapabilities.mediaUpload` and `stampExchange` are false. The list path is the existing `RoamAlbumMetadataReadRoute`, and only when a reader is already present. `registersRoute` and `marksRouteLive` stay false. No new route is marked live.

EN and zh-Hans keys, plus the view's accessibility identifiers, are in `docs/release/ui-strings-subpackageP3-pages-stamp-camera-index-index.json`. `StampCameraPageFixtureData` is compiled only under `#if DEBUG`.

Tests: `Tests/CoreTests/StampCameraPageReadyTests.swift` and `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py`. Existing caption, media-destination, and created-stamp lookup tests are unchanged.

Left: the row stays partial. Camera and stamp writes stay off. `RoamCreatedStampReadLifetimeTests` was not run. No view, `Localizable.xcstrings`, project, or CI manifest edit. `xcodebuild` was not run.
