# Receipt: native r2 M4 — in-app Island + Dynamic Island (`native-r2/island-r1`)

Spec: `docs/briefs/native-r2-motion-r1.md` §M4 (owner 11-26 09:05: invitations, messages, game and story hints, audio/video).
Base: `origin/ui/combined-r7`. Flag: `NativeR2Flags.island` (`nativeR2.island`, default on; `-nativeR2.island NO` restores the bottom toast,
the silent foreground push and the previous Live Activity layout). No new network requests: every source below re-uses a read the app already makes.
No compiler in the cloud: types and modifiers grepped against the repo / iOS 17 SDK; gates below.

## New files — `App/NativeR2/Island/`
| File | What |
|---|---|
| `IslandFlags.swift` | `NativeR2Flags.island` |
| `IslandItem.swift` | `IslandKind` (`.invitation .message .hint .media .status(IslandTone) .arrival`), `IslandTone`, `IslandText`, `IslandAction`, `IslandMedia`, `IslandItem` |
| `IslandCenter.swift` | `@MainActor @Observable` singleton: show / queue (max 5, status dropped first) / dedupe-in-place / update / withdraw / expand / tap / perform / dismiss; 4 s auto-dismiss, paused while a finger is on it, ×3 while VoiceOver runs |
| `IslandOverlay.swift` | black continuous-corner capsule anchored on the safe-area top (Dynamic Island iPhones: top 11 pt, 37 pt tall at rest, grows out of the hardware island via `.scale(anchor: .top)`; others: drops from under the status bar); compact ↔ expanded morph `.spring(response: 0.42, dampingFraction: 0.78)`; content `.blurReplace`; drag follows the finger up (dismiss), rubber-bands down (expand); `.sensoryFeedback(.impact(weight: .light))`; VoiceOver announcement + one focusable element with named actions + escape; Reduce Motion = opacity only |
| `IslandWindow.swift` | `.islandRoot()` modifier: `.environment(IslandCenter.shared)` + a pass-through `UIWindow` (level alert+1) per scene so the island sits above sheets; touches outside the island frame fall through |
| `CYToastIslandBridge.swift` | `cyToast` → `.status` island (tone, undo action) |
| `IslandSources.swift` | `IslandPushPresenter`, `IslandHintBridge` / `.islandHints`, `IslandMediaBridge`, `IslandUnreadBridge`, `IslandInviteBridge`, `IslandRoutes` |

## Root injection
- `App/QuestifyApp.swift:161` `.islandRoot()` on the root `Group` (all roots and fixtures).

## Wired sources (file:line)
| Kind | Source | Where |
|---|---|---|
| status | all 75 `.cyToast` call sites, unchanged — `CYToastModifier` / `CYToastVerbatimModifier` are now shims | `App/DesignSystem/CYSharedStates.swift:283-286` (key), `:333-336` (verbatim); pill path kept for flag off |
| invitation / message / arrival / status | foreground push: `willPresent` → island instead of the system banner (kept in Notification Center via `[.list, .badge]`); tap / primary action routes exactly like a banner tap | `App/MPParityDeepLinkEntry.swift:91`; `open(pagePath:)` helper `:106` |
| message | IM unread total rising on the existing `IMUnreadEntryBadge` read → "N new messages", Open → message center | `App/IMInboxViews.swift:187` |
| message | club channel unread (`byTab.channel`) rising on the existing scene-active `api/im/unread-summary` read | `App/NativeChannelForegroundUnreadEntry.swift:97` |
| invitation | cooperation invites awaiting my answer, from the strip's existing `api/coop/list` read; first read primes silently; View opens `pages/coop/invite-detail/index` | `App/IMCoopInviteStripView.swift:208` |
| hint | game hint ladder (NativeGameShell toolbar hint): revealed level → hint island, "下一条提示" reopens the ladder | `App/NativeR2/Games/NativeGameShell.swift:143` |
| hint | story / play stop hint ladder (`PlayHelpLadderPanel` host) | `App/PlayExperienceView.swift:1115` |
| media | story audio mini player: playing / paused → media island with play / pause (same `toggle()` + consent review); ended / failed / disposed withdraws | `App/NativeR2/Story/NR2StoryReaderParts.swift:233`, `:238` |
| arrival | city orientation run entering the 50 m highlight → arrival island, action opens the same punch sheet (`onPunch`) | `App/NativeR2/CityOrientation/CityOrientationRunView.swift:94` |

## Real Dynamic Island / Live Activity (ActivityKit, existing widget extension)
- `Core/QuestLiveActivityContent.swift:9` kind `.story`; `:11` `QuestLiveActivityMode` (`orientation`, `explore`); `:31-34` optional `mode`, `nextDistanceMeters`, `mediaTitle`, `mediaPlaying` (optional → old encoded state still decodes; init params appended with defaults, existing call sites unchanged).
- `App/QuestLiveActivityCenter.swift:28` `setPlayContext(mode:nextDistanceMeters:)` (rounded to 10 m), `:37` `clearPlayContext()`, `:44` `storyAudio(title:isPlaying:)` (elapsed carries across pauses), `:58` `endStoryAudio()`; `:98`/`:122` decorate `.play` content on show / end. Core mapping untouched.
- Start / update / end callers: orientation run `App/NativeR2/CityOrientation/CityOrientationRunView.swift:89` (distance to next control point) and `:83` (clear); free explore `App/NativeR2/FreeExplore/NativeFreeExploreMapView.swift:54` / `:56`; story audio via `IslandMediaBridge` (`NR2StoryReaderParts.swift:233`, `:238`).
- `LiveActivityWidget/QuestLiveActivityWidget.swift`: expanded `.leading` (title + glyph) / `.trailing` (`Text(timerInterval:)` clock) / `.center` (next stop or clip, new) / `.bottom` (metrics: + "to next stop" distance, story playing state) at `:15-28`; `compactLeading` / `minimal` = tinted glyph by kind+mode `:29`, `:34`; `compactTrailing` = run timer, else next-stop distance / clue fraction / story pause glyph `:31`, `:235-250`; `.keylineTint` `:37`. Symbols / tints match the in-app island.

## Strings
- `Resources/Localizable.xcstrings` + `docs/port/strings/native-r2-island-r1.json` (27 keys `island.*`), merged with `tools/merge_localization_fragments.py`.
- `LiveActivityWidget/Localizable.xcstrings`: `liveActivity.orientation.title`, `.explore.title`, `.story.title`, `.story.playing`, `.story.paused`, `.play.nextDistance`.

## Gates
- `python3 tools/generate_project.py` (globs `App/NativeR2/**/*.swift`; the 7 Island files are in the project).
- `python3 tools/check_scaffold.py` → `PASS structural checks`.
- `python3 -B tools/check_a11y_lint.py` → `PASS accessibility lint: 0 new`. combined-r7 arrived with 9 unlabeled-image findings from other lanes; fixed as one-line decorative marks: `App/ClubStoryViews.swift:151`, `App/DesignSystem/CYHeroBanner.swift:81`, `App/DiscoveryComponents.swift:90`, `App/NativeChannelCheckinView.swift:307`, `App/NativeR2/FreeExplore/NativeStampAlbumView.swift:268`, `App/NativeR2/MapHome/RoamMapHomePlaceCard.swift:195`, `App/NativeR2/Story/NR2StoryRouteSections.swift:175`, `App/PassportView.swift:211` (label), `App/NativeR2/Games/ChoiceKits.swift:214` (`Image(decorative:scale:)` for the share render).

## Deviations / notes (closest Apple behaviour, no look-alikes)
- **Accept / Decline:** coop and push invitations show **View / Later**; accept and decline need the invite page's confirmation and `CoopFlowHandle`, so View opens that page. Team invites have no received-invite read (only the inbound `/team/join` link, already routed); game seat invites have no caller (`PWaveReader.seatInvitations`). No new fetch was added for them.
- **Message avatars / artwork:** SF Symbols only; loading remote avatars would be a new image request.
- **Media progress ring:** `PlatformAudioPlayback` exposes no duration, so the island and Live Activity show elapsed time (`Text(timerInterval:)`) and an animated waveform instead of a ring. Video has no island source yet.
- **IM messages:** the app has no realtime channel; message islands fire when an existing read (unread total, channel unread summary) goes up while the app is open, and on foreground push.
- **VoiceOver:** a runtime `LocalizedStringKey` with interpolated arguments cannot be resolved outside `Text`; its announcement falls back to the kind name (the focusable island still reads the full text).
- **Needs a device check (no simulator here):** the island window's status-bar style and the 51 pt safe-area threshold used to detect Dynamic Island iPhones.
