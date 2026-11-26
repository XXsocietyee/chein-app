# Receipt: design P1 · L5 Story, audio, passport (`design/p1-story-audio`)

Base: `origin/ui/combined-r7`. Checked `fix/backlog-p0`, `native-r2/island-r1` (already in r7), `native-r2/motion-r1` (already in r7), `native-r2/sheets-r1` (receipt-only diff): none touch the L5 files, so this builds on the r7 tip.
Gates: `python3 tools/check_scaffold.py` PASS structural checks, `python3 -B tools/check_a11y_lint.py` PASS. No compiler in the cloud: every API grepped (iOS 17 target).

- **P-077 done.** Passport stamp grid shows real album thumbnails (`AsyncImage` of the stamp's `picUrl`, circles, caption as the VoiceOver label). Locked seals fill the rest of the grid only while the album has fewer than 12. A "See All" row (`passport.stamps.open`) pushes the existing `RoamAlbumMetadataDestination`. Files: `App/PassportView.swift` (`PassportStampThumbnail`, `thumbnail(_:index:)`) and `App/AccountView.swift` (passes the album reader, routes See All).
- **P-078 done.** The count is the album total from `session.roamAlbumMetadataReader.album(page: 1, pageSize: 12)`. That is the same `api/roam/stamp/list` read the MP stamp album and the roam passport already make; no new endpoint. The number rolls with `.numericText`, and Reduce Motion sets it instantly. If the album is unconfigured or fails, the count falls back to the old device-local `RoamPassportHome.stamps` with "of 12". Unknown is still an em dash.
- **P-082 done (reader side).** Under `nativeR2.storyFlow`, `ChapterStoryView` applies the domain of the page that opened it (`@Environment(\.themeDomain)`) instead of forcing `.player`, so the route and the reader are always one domain. r1 keeps `.player`. The host itself goes `.game` → `.player` in L4 (P-049, `PlayExperienceView.swift`); after that, both follow the system Light/Dark setting.
- **P-083 partial.** Code complete, but dormant in production.
  - Info.plist adds the `audio` background mode.
  - `NativePlatformAudioDriver.continuesInBackground` / `storyNarration()` ignores only the background signal. Calls, unplugged headphones and media reset behave as before. The default stays false, so the unit tests are unchanged.
  - The reader keeps the mini player mounted and keeps its clip when the app leaves the foreground. A playing or paused clip is not suspended.
  - `NR2StoryNowPlaying` publishes `MPNowPlayingInfoCenter` (title, elapsed, duration, rate) and remote commands (play, pause, toggle, next clip, ±15 s, change position).
  - **Why partial:** production `PlatformConsumerSessionOwner()` (AppSession.swift:657) has no audio builder, so story audio has no driver today. Injecting `NativePlatformAudioDriver.storyNarration()` there turns on audio downloads. That is an owner/coordinator call under "no new requests", so it was not done here.
- **P-084 done.**
  - The mini player gets a playhead line, elapsed time and an animated waveform symbol (off under Reduce Motion), plus a `.symbolEffect(.replace)` play/pause.
  - Tapping the bar opens `NR2StoryFullAudioPlayer` via `cySheet`, at medium and large detents. It has a `Slider` scrubber with elapsed and remaining time, −15 s / play-pause / +15 s, next clip and a speed `Menu` (0.75–2×, `.numericText`), with `.sensoryFeedback` on seek.
  - The controls switch to a vertical stack at accessibility sizes (`ViewThatFits`). VoiceOver labels are on every control, and failures and the end of a clip are announced.
  - Position, length and speed come through the new App-only `PlatformAudioTransporting` seam on the driver; Core is unchanged.
- **P-085 done.**
  - The raw-host `confirmationDialog` (`platform.audio.review` with the URL host) is replaced by one plain question: "播放故事音频？" / "Play story audio?".
  - Hosts are still gated by `PlatformMediaPolicy` (pre-approved origins). After the first yes (`@AppStorage play.nr2.storyAudio.consented`), later clips call Core's per-clip `approveSelectedMedia()` before `toggle()`, so the Core consent rule is unchanged.

Strings: `docs/port/strings/native-r2-story-audio.json` (15 keys, zh-Hans + en) merged into `Resources/Localizable.xcstrings`.
Contract tests updated to the new intended behaviour:
- `test_chapter_audio_current_selection.py`: r2 background mount and selection. It was already failing on r7 and now passes.
- `test_app_store_privacy_launch_contracts.py`, `test_cb51_diagnostics.py`, `test_wp11_session_location.py`: `UIBackgroundModes` is now `audio` + `location`. There is still no Always location.

Not run: Xcode build, simulator, `Tests/AppUnitTests`.
