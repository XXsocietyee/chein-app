# Effects regression audit: 2026-11-28

**Owner question:** "Are all the previous effects included?"

**Short answer:** no. Most effects that shipped before the native rewrite are no longer visible in production. They are not deleted files. They were removed in three ways:

1. **Call sites swapped for plain views.** The native-r2 lanes on 11-26 replaced effect call sites with Apple components.
2. **Components made to draw nothing.** Commit `89e71d61d` changed nine decoration components so their body draws nothing (`EmptyView()` or a passthrough). Their call sites still look live.
3. **Legacy branches behind default-on flags.** Several effects now sit in a legacy branch that only runs when a default-ON native flag is turned off.

Most of these removals were **ordered by the brief**. `origin/design/handoff-r2:docs/briefs/native-r2.md` lines 31–35 say: "**Remove:** gradients, glows, orbs, foil, fog, glass, bursts and confetti … decorative motion (keep only system transitions, `.contentTransition`, `.sensoryFeedback`)". They are deliberate, not accidental. But they contradict:
- the later `design-principles.md` **P7** ("personality at moments … confetti, holo sheen") and **P30** ("a short celebration (confetti / symbol bounce) plays once … success haptic");
- every `docs/release/motion-spec-*.md` file, which still describes the old screens.

The motion-r1/r2 lanes then added a new, native-style set of moments. Those are mostly Live.

## Scope and method

- **HEAD:** `origin/ui/combined-r7` @ `7a7d2708a`.
- **BASE:** `d9115273d` (combined-r7 merge, 2026-11-24 22:45 PST). This is the last integration commit before `82bcf2c2d` "native r2 tokens" and the 11-26 native-r2 rounds.
- **No git tags exist** in this repo (`git tag` and `git ls-remote --tags origin` are both empty). There are no `old-origin/*` refs either. `handover-20261123-functional` and `v0.1.0-rc1` are not refs, so BASE stands in for them.
- **Deleted files:** `git diff --name-status BASE HEAD -- App Core LiveActivityWidget` shows 5 deleted Swift files. None is an effect file. The deleted `PublicCatalogViews.swift` and `PassRedeemCodeView.swift` were `CYMorphButton` call sites.
- **Status per effect:** each effect was traced from its symbol to a tab root in `App/QuestifyApp.swift`, or to a deep link or sheet.
- **Inventory sources:** `docs/release/motion-spec*.md`, `docs/design/haptics-map.md`, the receipts `native-r2-motion-r1.md`, `native-r2-motion-r2.md`, `ui-celebration.md` and `ui-onboarding.md`, `docs/roam-reduced-motion.md`, and the handoff-r2 briefs (`native-r2.md`, `native-r2-motion-r1..r3.md`, `design-principles.md`).
- **Read-only.** No app code was changed.
- **Unmerged round-3 lanes:** `design/r3-a11y`, `mp/r3-roam`, `mp/r3-mine`, `mp/r3-journey`, `mp/r3-activity`, `mp/r3-states`, `mp/r3-nav` and `mp/r3-publish` are 1–4 commits ahead of HEAD. Their diffs only add effects. For example, `mp/r3-journey` `dff569208` and `1b1573e4f` add success and warning haptics. None of them removes one.

### Status legend

| Status | Meaning |
|---|---|
| **Live** | Reachable from a production screen; draws or plays as designed. |
| **Live-degraded** | Reachable, but a no-op component inside it now draws nothing, or most call sites were removed. |
| **Neutered** | The component body was changed to `EmptyView()` or a passthrough (`89e71d61d`). It counts as **dropped**. |
| **Replaced** | A production call site existed at BASE and was swapped for a plain Apple view (commit given). The code may remain as Fixture-only or Orphan. It counts as **dropped**. |
| **Fixture-only** | Referenced only from `App/DesignFixtures/**` or `#if DEBUG --design-fixture`. |
| **Flag-off** | Runs only with a flag in its non-default state: either a default-OFF flag, or a "legacy path" that needs a default-ON flag set to `NO`. |
| **Orphan** | No call site at all, or a host that is never presented or fed. |

## Summary

| | Count |
|---|---|
| **N:** effects inventoried (rows below) | **148** |
| **K:** still reachable in production (Live 67 + Live-degraded 9) | **76** |
| **L:** dropped from production (Replaced 34 + Neutered 7) | **41** |
| **M:** Fixture-only (never wired, or only the fixture remains) | **11** |
| Flag-off (default-OFF flag, or a legacy path behind a default-ON flag) | 9 |
| Orphan / never shipped / not built | 11 |

Each row has exactly one status: 76 + 41 + 11 + 9 + 11 = 148.
- 32 of the 76 reachable effects were added after BASE (native-r2 motion r1/r2, island, Live Activities, widgets, games, P21/P30). The other 44 are BASE effects that survived, mostly on the City board, play runtime, tickets, the 3D medal and haptics.
- Of the effects that were Live at BASE, most of the user-visible ones are in L.
- Most **Replaced** rows also survive as Fixture-only or Orphan code. They are counted under L only.

**What the owner will notice:**
- the first-launch onboarding pager is gone;
- the roam tab root is no longer the City board;
- there is no GO hold or GO wave;
- there is no confetti or particles anywhere;
- the ticket verify flip and tear are gone;
- there is no tab-switch haptic;
- there is no skeleton shimmer or stagger;
- the purchase motion is gone;
- the badge and stamp slam overlays are gone.

The new native motion is **Live**: route draw-on, rolling numbers, edge glow, stamp ink press, the mini-bar zoom, the island, the Live Activities and the city-orientation finish.

## Effects table

Paths are relative to `App/` unless they start with `Core/`, `LiveActivityWidget/` or `docs/`. Line numbers refer to HEAD unless marked BASE.

**Lanes** come from the round-3 lane table in `docs/briefs/round3-1127.md`:

| Lane | Area |
|---|---|
| shell / coordinator | `QuestifyApp`, flags, `App/DesignSystem` kit bodies |
| ds-consistency | design-system kit |
| mp-home | Home |
| mp-roam | Roam |
| mp-journey | play, free-explore, city-orientation |
| mp-mine | Me, badges, wallet |
| mp-club | Club |
| mp-activity | tickets, pass, purchase |
| a11y-dt | Reduce Motion |
| native-b | `App/NativeR2/**` |

### A. Launch and onboarding

| # | Effect | Where it was | Status on combined-r7 | Evidence | Reduce Motion fallback? | Recommendation | Owning lane |
|---|---|---|---|---|---|---|---|
| A1 | Onboarding pager `OnboardingFlow` (5 steps, page spring, copy transitions, selection haptic, dots) | BASE `WelcomeView.swift:33-46` → `CYOnboarding.swift:102-307` | Replaced (`95fe28012`) | Only caller is `DesignFixtures/OnboardingFixtures.swift:44`. `WelcomeView.swift:9` says "OnboardingFlow stays in the design kit, unused by the app". | Yes, in code (`CYOnboarding.swift:129,242,346`) | **Restore adapted:** a `TabView(.page)` pager in front of the native welcome: SF Symbol demos with `symbolEffect`, Dynamic Type copy, `.sensoryFeedback(.selection)` per page. Drop the custom orb and disc look. | shell / mp-nav |
| A2 | Hero city disc (drag and gyro 3D tilt, breathing, ripple) | `CYOnboarding.swift:372-512` | Fixture-only | Reachable only through A1 | Yes (`:390,403-405,488-490`) | Drop (decorative; brief line 31) | — |
| A3 | Metal ripple `cyOnboardWave` (`CYOnboardingWave.metal`) | `CYOnboardingLight.swift:212,232` | Fixture-only | Called only inside A1 (`CYOnboarding.swift:408,574`). The `.metal` files are not in `project.pbxproj`; `tools/generate_project.py:10-12` needs `CY_ENABLE_METAL=1`. | Not found | Drop | — |
| A4 | `OBWordmarkBloom`, `OBBurst` (25 particles), `OBLanternWindows` parallax | `CYOnboardingLight.swift` | Fixture-only | Only inside A1 (`CYOnboarding.swift:503,510,576,670`) | Partial (`:503`) | Drop | — |
| A5 | Onboarding demos: `StampSeal` slam, `AvatarOrbit`, GO hold ring with tick haptics | `CYOnboarding.swift:543-815` | Fixture-only | Only inside A1 | Yes (`:610,640,768,781,814`) | Restore adapted as A1 page content (symbol bounce plus haptic) | shell |
| A6 | Signed-out Me `WelcomeHero` card fan (spring drift) | BASE `WelcomeView.swift:186-240` | Replaced (`b16f12b43`, `95fe28012`) | The struct is gone. Signed-out Me is `ContentUnavailableView` (`WelcomeView.swift:86-101`). | n/a | Drop (the native empty state is correct) | — |
| A7 | Welcome sample-route draw-on (`NativeR2DrawOn`, 2 s) | new (`2082414fc`) | **Live** | `QuestifyApp.swift:532` → `WelcomeView.swift:110` → `WelcomeSampleRouteMap.swift:55` | Yes (`:9,55`; `NativeR2Motion.swift:21`) | Keep | — |
| A8 | Welcome consent row animation and `.selection` haptic | `cda1f41a8` | **Live** | `WelcomeView.swift:135,184` | Yes (`:135`) | Keep | — |
| A9 | Welcome primary press `.impactMedium` | BASE `WelcomeView.swift:172` | Replaced (`95fe28012`) | Not on HEAD | n/a | **Restore as-is** (`.sensoryFeedback(.impact(weight:.medium))` on 创建账号) | shell |
| A10 | Launch screen (LaunchBackground plus LaunchMark) | `Config/Info.plist:13` | **Live** (static, same as BASE) | No splash or launch overlay at BASE or HEAD | n/a | Keep | — |

### B. Rewards and celebrations

| # | Effect | Where it was | Status on combined-r7 | Evidence | Reduce Motion fallback? | Recommendation | Owning lane |
|---|---|---|---|---|---|---|---|
| B1 | Celebration queue `CYCelebrationCenter` / `.cyCelebrations` (one at a time, dedupe, haptic cues, VoiceOver announcement) | BASE: four producers (GrowthCenter, RoamBrowser, RoamLiveSession:359, ObjectBadgeViews:418) | Live-degraded (one producer left) | Hosts at `GrowthCenterView.swift:107` and `RoamBrowserView.swift:291`. The only producer is `GrowthCenterView.swift:313`. | Yes (`CYCelebrationViews.swift:78,231,235`) | Keep the engine. Re-feed it from stamp and badge unlocks (B2, B3). | mp-mine |
| B2 | Stamp slam overlay `CYStampSlamView` (seal drop, particles, ink ring, count flip) | BASE `RoamStampCameraView.swift:161,271` | Flag-off (legacy path, `nativeR2.freeExplore`=NO) | The enqueue survives only in `legacyBody` (`RoamStampCameraView.swift:173,284-286`). `body` routes to `NativeStampCaptureView` (`:46-50`; `c0df8238f`). | Yes (`CYCelebrationViews.swift:273,309,326,437`) | Superseded by R1 ink press plus D-cyStampSlam (Live). Drop the overlay. | — |
| B3 | Badge unlock cover `CYBadgeUnlockCover` (rise, medal land, share) | BASE `GrowthCenterView:101,306`, `ObjectBadgeViews:418,431` | Live-degraded | mineTab → `PassportView.swift:16` → `AccountView.swift:77,264` → `GrowthCenterView.swift:313` → `CYCelebrationViews.swift:207`. The badge-detail producer was removed in `0b4c30f6a`, and its bloom and foil are no-ops (B5, B8). | Yes (`CYCelebrationViews.swift:489-588`) | **Restore adapted:** fire it again from a badge unlock in `ObjectBadgeViews`. Inside, replace the bloom with `symbolEffect(.bounce)` plus R2 holo sheen. | mp-mine |
| B4 | Confetti `CYConfettiBurst` | BASE: BundlePayResult:118, ClubMemberWelcomeSheet:58, NativeChannelCheckin:136, PlayRewardBadgeViews:16, CYAlbum:430 | **Neutered** (`89e71d61d`) | `DesignSystem/CYSignature.swift:192-194` body is `EmptyView()`. Three call sites were removed (`ca414a9fc`, `ad06ffc86`, `bfea7b414`). `PlayRewardBadgeViews.swift:16` still calls it and gets nothing. | BASE yes; now n/a | **Restore adapted** (P7/P30): a single short `Canvas` confetti, once, at completions only (roam finish, journey settle, badge unlock), `accessibilityHidden`, and a fade under Reduce Motion | ds-consistency + coordinator (brief conflict) |
| B5 | Particles `CYBurst` (dust and confetti) | BASE: stamp slam, join reward | **Neutered** (`89e71d61d`) | `DesignSystem/CYBurst.swift:34-36` | n/a | Drop (B4 covers the need) | — |
| B6 | Roam summary `CYRoamSummaryView` + `CYRollingStat` + `CYRouteDraw` | BASE `RoamLiveSessionView.swift:349` | Replaced (`a1519ed20`) | `.roamSummary` is enqueued only in `E4CelebrationFixtures.swift:87-96`. The replacement is `RoamFinishReportView` (see H8). | Yes | Drop: H8 is the native equivalent. Optionally add `CYRouteDraw` → `NativeR2DrawOn` to the report map. | mp-roam |
| B7 | Celebration share sheet | BASE: three hosts | Live (badge cover only) | `CYCelebrationViews.swift:519` | Static | Keep | — |
| B8 | `CYStarBloom` (horizon arc, glow, orbiting stars) | BASE: inside B3 | **Neutered** (`89e71d61d`) | `DesignSystem/CYStarBloom.swift:36-38` | n/a | Drop (use a symbol bounce plus sheen in B3) | — |
| B9 | Club join reward `CYJoinReward` (seal, burst, ring) | BASE `ClubActionPanel.swift:75` | Replaced → Orphan (`35852c11d`) | No `CYJoinReward(` call. `ClubActionPanel.swift:492-502` plays `CYHaptics.success` only. | Yes (unused) | **Restore adapted:** `symbolEffect(.bounce)` on the joined check plus the existing success haptic | mp-club |
| B10 | Club member welcome: stamp slam, confetti, orbit dots | BASE `ClubMemberWelcomeSheet.swift:56-59` | Replaced (`ad06ffc86`) by a spring-in, bounce and `.success` | `ClubMemberWelcomeSheet.swift:64-66,80,131` | Yes (`:64,130`) | Keep the replacement (native) | — |
| B11 | Channel check-in confetti | BASE `NativeChannelCheckinView.swift:136` | Replaced (`bfea7b414`) by a bounce and `.success` | `NativeChannelCheckinView.swift:113-114` | Yes | Keep the replacement | — |
| B12 | `.cyStampSlam` (scale 1.35→1 spring plus heavy impact) | `CYCollectible.swift:163-181` | **Live** | Play reward: `SessionPlayRuntimeView.swift:32` → `PlayExperienceView.swift:700` → `PlayRewardBadgeViews.swift:17`. Stamp created: `RoamCreatedStampView.swift:130`. | Yes (`:172,180`) | Keep | — |
| B13 | `CYCelebrationMoment` / `CYRingPulse` | `CYCollectible.swift:78-160` | Fixture-only (also at BASE) | `AlbumFixtures.swift:28`, `E5bFixtures.swift:17-27` | Yes | Drop (never wired up) | — |
| B14 | `CYBadgeTile`, `CYCountRing` count-up | `CYCollectible.swift:184-` | Fixture-only (also at BASE) | `AlbumFixtures.swift:268` | Yes | Drop | — |
| B15 | Album unlock `.cyUnlockCelebration` | `CYAlbum.swift:419-437` | Fixture-only (also at BASE) | `AlbumFixtures.swift:279` | Haptic only | Drop | — |
| B16 | Album page turn `CYAlbumPager` (3D spine), `CYFlipCard`, `.cyFoilSheen`, `CYNewPulseBadge` | BASE `ObjectBadgeViews:194-439`, `ObjectCardViews:145`, `RoamStampViews:370` | Flag-off for stamps (legacy, `freeExplore`=NO); Replaced for badges and cards (`046f727ce`, `d9d0bd767`, `0b4c30f6a`, `53c20f5b4`) | `RoamStampViews.swift:34-37` routes to `NativeStampAlbumView` | Yes (`CYAlbum.swift:172-401`) | **Restore adapted:** keep a `symbolEffect(.pulse)` "NEW" badge and the R13 tilt on detail. Drop the 3D spine. | mp-mine |
| B17 | `.cyLockedSilhouette` | BASE `ObjectBadgeViews:304` | Replaced → Fixture-only (`d9d0bd767`) | `AlbumFixtures.swift:248,271` | static | Restore as-is (static grey and `.secondary` locked state; this is not motion) | mp-mine |
| B18 | Gyro foil `cyFoil` (medals, album cards, crafted medal) | BASE: 23 sites | **Neutered** (`89e71d61d`) | `DesignSystem/CYFoil.swift:16-17` returns content. There are 14 inert call sites, e.g. `JourneyReportViews.swift:1373`, `CYBadgeCraft.swift:115`. | n/a | **Restore adapted:** route `cyFoil` to `MotionR2HoloSheen` plus `cyTiltHold` (one implementation, reward-only, Reduce Motion static) | native-b |
| B19 | Play medal deck `CYMedalDeck` (swipe-cycle plus haptic) | `CYMedalStack.swift:160-223` | **Live** | `PlayExperienceView.swift:700` → `:1907` | Yes (`:201,221`) | Keep | — |
| B20 | Finish medal screen `CYMedalScreen` (rays, count-up) | BASE: city-orientation finish | Flag-off (legacy, `cityOrientation`=NO) (`a77f76fff`) | `PlayExperienceView.swift:318-319` | Yes | Superseded by H5 and R11/R12. Drop. | — |
| B21 | Chapter gate / end card `CYChapterGate`, `CYChapterEndCard` | BASE `ChapterStoryView` | Flag-off (legacy, `storyFlow`=NO) (`4a6129aff`) | `ChapterStoryView.swift:192-209,318,335` | Yes | Hold (story flow is paused by the owner) | — |
| B22 | Play verdict overlay `CYPlayVerdictOverlay` | BASE: same (never fed) | Orphan | `PlayExperienceView.swift:1222,1447`: `verdict` is never assigned | Yes | **Restore adapted:** set `verdict` on a stop pass or fail; the overlay already has haptics and Reduce Motion | mp-journey |
| B23 | In-place result `CYResultButton`, `CYDeltaNumber` | r3 kit | **Live** (City board) | `CityClaimFlow.swift:253`, `CityChallengeFlow.swift:213,269`, `CityPropertySheet.swift:142` | Yes (`CYInPlaceResult.swift:65-285`) | Keep. `CYResultToast`, `CYStreakRow` and `CYMomentSeal` are fixture-only or orphan: drop. | — |
| B24 | Passport stamp hero zoom (`cyPassportStampHost`, title rise) | `CYStampContinuity.swift:66-119` | **Live** | `AccountView.swift:88`; sources at `PassportView.swift:358,375` | Yes (`CYMotion.swift:612-621`) | Keep | — |
| B25 | Share composer (template, tint and ratio animations, swatch scale, haptics) | `CYShareComposer.swift:23-172` | **Live** | `ActivityDetailView.swift:244` → `CatalogShareCardView.swift:41`; `RoamFinishReportView.swift:95` | Yes (`:27,58,97,160`) | Keep | — |
| B26 | Level-up moment `CYLevelUpMoment` | BASE `GrowthCenterView:103` | Replaced (`efc9a3667`), now haptic only | `GrowthCenterView.swift:302-303` | n/a | **Restore adapted:** route level-up through B1 (`symbolEffect(.bounce)` plus `.success`) | mp-mine |

### C. Roam, map and city

| # | Effect | Where it was | Status on combined-r7 | Evidence | Reduce Motion fallback? | Recommendation | Owning lane |
|---|---|---|---|---|---|---|---|
| C1 | Roam tab root = City Monopoly board (pin springs, hold-to-start, haptics) | BASE `QuestifyApp.swift:310` | Replaced by `RoamMapHomeView` (`nativeR2.mapHome` default ON). The board is now a full-screen cover behind the 城市 button. | `QuestifyApp.swift:312-334`; `RoamMapHomeSheet.swift:35-47,412-416` | n/a | Keep the native root (owner rule 2). Make the 城市 entry prominent. | mp-roam |
| C2 | Map-home panel `.snappy` detents and camera fit | new | **Live** (no Reduce Motion) | `RoamMapHomePanel.swift:35,56,88`; `RoamMapHomeView.swift:147` | **None** in `NativeR2/MapHome/*` | **Add a Reduce Motion fallback.** Add a `.selection` haptic on the place-card change. | mp-roam / a11y-dt |
| C3 | Map-home official route polyline | new | **Live** (static) | `RoamMapHomeView.swift:116` | n/a | **Restore adapted:** reuse `NativeR2DrawOn` when the route is selected | mp-roam |
| C4 | GO hold pill, ring and heavy-impact haptic ladder `CYGoHoldPill` / `CYGoPuck` | BASE `RoamLiveSessionView.swift:494` | Replaced (`a1519ed20`) → Fixture-only | Plain `Button { commitGo() }` at `RoamLiveSessionView.swift:695`. `CYGoHold` is only referenced from `DesignFixtures/RoamFixtures.swift:189,193`. | Yes (`CYGoHold.swift:18,32,55,63`) | **Restore adapted:** keep `.borderedProminent` 走起 and add `.sensoryFeedback(.impact(weight:.heavy))` on commit plus a `symbolEffect(.bounce)` on the figure.walk symbol. No custom pill. | mp-roam |
| C5 | GO commit wave `CYGoWave` | BASE `RoamLiveSessionView.swift:528` | Replaced (`a1519ed20`) → Fixture-only | `RoamFixtures.swift:204` | — | Drop (R8 edge glow can mark the start instead) | — |
| C6 | Live-roam celebration particles | BASE `RoamLiveSessionView.swift:359` | Replaced (`a1519ed20`) by `symbolEffect(.bounce)` plus `.success` | `RoamLiveSessionView.swift:602,664` | Toast yes (`:608,615`); bounce relies on system symbol effects (unverified) | Keep the replacement | — |
| C7 | Live-roam pause haptic, settle success, reveal toast | BASE | **Live** | `RoamLiveSessionView.swift:598,602,608-620`, via the map home `showsLive` | Yes (`:68,608,615,620`) | Keep | — |
| C8 | Fog-of-war reveal (`CYFogEngine`, `RoamFogMapView`, wipes, dashes, pulse, reveal haptics) | BASE: same gate | Flag-off (compile-time constant), **never shipped** | `RoamLiveSessionView.swift:262`; `Core/PersonalFogLedger.swift:11` `liveRevealEnabled = false` | Yes (`RoamFogMapView.swift:72,81,168-175`; `CYFogEngine.swift:78`) | Owner decision. If it is wanted: a MapKit `MapPolygon` overlay for covered tiles (native), not a custom shader. | mp-roam (decision: owner) |
| C9 | `CYFogLayer` drifting vignette plus boost spring | BASE `RoamLiveSessionView.swift:435,437` | **Neutered** (`89e71d61d`) and call site Replaced (`a1519ed20`) | `DesignSystem/CYRoamKit.swift:157-159` `EmptyView()` | was yes | Drop | — |
| C10 | Night tab bar `CYNightTabBar` (floating pill, matchedGeometry) | BASE `QuestifyApp.swift:378` | Replaced (`95fe28012`) → Fixture-only | `QuestifyApp.swift:474-492` system `TabView`; `Cur9Fixtures.swift:54`, `IAFixtures.swift:31` | Yes | Drop (owner rule 2) | — |
| C11 | Night glass `cyNightGlass` | BASE: 5 sites | **Neutered** (`89e71d61d`), one call left | `DesignSystem/CYNightGlass.swift:10-15`; `RoamExperienceComponents.swift:212` | n/a | Drop (materials come from the system) | — |
| C12 | Map chrome glass buttons `CYGlassLabel` / `CYGlassCapsule` | BASE `RoamBrowserView:504,509`, `PlayExperienceView:694` | Replaced (`d0bbdd3ca`, `3d8015537`) and body flattened | `DesignSystem/CYMapChrome.swift:77-85,115-120` | n/a | Drop (use `MapUserLocationButton` and `.mapControls`) | — |
| C13 | City hold-to-start `CityHoldButton` (0.8 s fill plus medium impact) | BASE tab root | **Live** (City board cover) | `CityRoamRootView.swift:401`; `CityHoldButton.swift:40-51` | Yes (`:16,40,43`) | Keep | — |
| C14 | City pins: selection scale and haptic | BASE tab root | **Live** (City board) | `CityMapLayer.swift:156,236-238` | Yes (`:212`) | Keep | — |
| C15 | City drawer and property sheet fly-in and detents | BASE | **Live** | `CityRoamRootView.swift:108,433`; `CityPropertySheet.swift:405-501` | Yes (`:379-382,465,492`) | Keep | — |
| C16 | City Monopoly haptic ticket player | BASE | **Live** | `CityRoamRootView.swift:168` → `CityMonopolyHapticPlayer.swift:40` | Yes (`:20-23`) | Keep | — |
| C17 | City D20 dice throw (drag/spin, TimelineView tumble, seal) | BASE | **Live** | `CityChallengeFlow.swift:149` → `CityRoamRootView.swift:138-143` → `CityMomentHost` → `CityDiceMoment` (`:467,490,496`) | Yes (`CityDiceKit.swift:116-150`) | Keep | — |
| C18 | City claim / upgraded / place-lost moments (photo flight, seal, heavy impact, numeric headline) | BASE | **Live** | `CityClaimFlow.swift:350`; `CityChallengeFlow.swift:277,337-394`; `CityRoamRootView.swift:165` | Yes (`CityMomentView.swift:38-183`) | Keep | — |
| C19 | City Defended moment | BASE: same | Orphan (never constructed) | Only the case exists (`CityChallengeFlow.swift:24,324`); fixture `CityKitFixtures.swift:211` | Yes | Restore as-is when the server sends a defend outcome (backend) | mp-roam |
| C20 | City live-on-map (matched capsule → pause pill) | BASE: flag-off | Flag-off (`cityLiveOnMapV1` default false) | `CityLiveOnMap.swift:21-24`; `CityRoamRootView.swift:180,218` | Yes | Hold (P21 mini bar covers this) | — |
| C21 | Home City rail focus `scrollTransition` | BASE | **Live** | `SessionHomeFeedView.swift:156` → `CityHomeRail.swift:56,67,86` | Yes (`:17,56`) | Keep | — |
| C22 | `CYCityBoard` ring, turn HUD, `CYCityDie` 3D tumble | BASE `PlayExperienceView:427` | **Live** (play runtime with a city game) | `PlayExperienceView.swift:532-533` → `CityGamePanel.swift:99-106` → `CYCityBoard.swift:23,79-82` | Yes (`:79-83`) | Keep | — |
| C23 | Hold-to-roll dice `CYHoldToRollButton` (wobble plus dice haptic) | BASE `PlayJourneyContentViews:59` | **Live** via `PlayRuntimeGapViews.swift:76`. The journey copy is Flag-off (legacy, `games`=NO). | `PlayExperienceView.swift:1472-1475` | Yes (`CYDiceGestures.swift:94-150`) | Keep | — |
| C24 | Shake-to-roll `cyOnShake` | BASE | **Live** | `NativeR2/Games/ChanceKits.swift:59,151,398`; `MotionR2Games.swift:161` | n/a (input) | Keep | — |
| C25 | Press wave and Metal `cyWave` distortion (`cyPressWave`, `CYTouchRipple`) | BASE `HomeFeedView.swift:756` (ripple only; Metal never compiled) | Replaced (`3250a067a`) → Orphan | Only use left is `CYWave.swift:236`, inside the unused style. `.metal` is not in pbxproj. | Yes (`CYWave.swift:3-6`) | Drop (the system button highlight is enough) | — |
| C26 | Edge glow sweep `cyEdgeGlow` (ticket present) | BASE `TicketPassPresentView:55`, `TicketPassSheet:63` | **Neutered** (`89e71d61d`); call sites Replaced (`da7f2c201`, `84fd0d480`) | `DesignSystem/CYEdgeGlow.swift:40-42,112-115` | was yes | Superseded by R8 `MotionR2EdgeGlow` (Live). **Delete the dead CYEdgeGlow** to avoid two implementations. | ds-consistency |
| C27 | Story mood edge pulse `cyThemeEdge` | BASE `ChapterStoryView:110` | Flag-off (legacy, `storyFlow`=NO) | `ChapterStoryView.swift:146,651` | Yes | Hold (story paused) | — |
| C28 | 3D medal showroom (SceneKit turntable, GLTFKit2 GLB) | BASE: same | **Live** | Mine → `AccountView.swift:131` → `ObjectBadgeWallView` → `ObjectBadgeViews.swift:122` → `ObjectBadgeWallParityViews.swift:99,325-364`; deep link `QuestifyApp.swift:854` | Yes (idle spin stops, `:305,325-330`) | Keep | — |
| C29 | `gold-matcap` 3D material asset | BASE: same | Orphan | `MPAsset.swift:731`, no reader | n/a | Drop or wire into C28 materials (owner) | — |
| C30 | AR spatial reveal (ARKit/SceneKit), own-media GLB preview | BASE | **Live** (game kits; chain partly unverified) | `PlayKitPersonalForms.swift:206`, `NativeR2/Games/CameraKits.swift:566` → `PlayKitSpatialRevealView.swift:44,112`; `SettingsPrivacyLocationView.swift:213` | Yes (`PlayKitSpatialRevealView.swift:20,44,112`) | Keep | — |

### D. Shared motion kit, loading, commerce and tickets

| # | Effect | Where it was | Status on combined-r7 | Evidence | Reduce Motion fallback? | Recommendation | Owning lane |
|---|---|---|---|---|---|---|---|
| D1 | Press scale `CYPressableStyle` / `.cyPressable` | BASE: 75 uses in 46 files | Live-degraded (23 uses in 14 files) | e.g. `PlayHUD.swift:343`, `CityHomeRail.swift:55`. Removed in `351198266`, `63c28ff09`, `da7f2c201`, `84fd0d480`, `a72d8c1ed`, `58a1d349c`, … | Yes (`CYMotion.swift:258-260`) | Drop where `List`/`Button` rows replaced it (system highlight). Keep on cards. | — |
| D2 | Hero zoom `cyHeroSource` / `cyHeroDestination` (`.navigationTransition(.zoom)`) | BASE: 28 sources, 25 destinations | Live-degraded (22/22) | Live: Club (`ClubHomeView.swift:282→145`), Passport, Roam home/stamps/history, badges, cards. Lost on Activity browser/detail and Official routes (`58a1d349c`), Pass market (`84fd0d480`), Topic (`1a987bb8e`). | Yes (`CYMotion.swift:336,356`) | **Restore as-is** on Activity → detail, Official route → detail and Pass market → detail. The zoom is a system API and fits P5 and owner rule 2. | mp-home / mp-activity |
| D3 | Ticket detail → full-screen pass zoom | — | **Live** | `TicketWalletDetailView.swift:44→194` | Yes | Keep | — |
| D4 | Wallet row → ticket detail zoom `CYOptionalHeroDestination` | spec `motion-spec-tickets.md:20` | Orphan (no caller passes `heroNamespace`; inert at BASE too) | `TicketWalletDetailView.swift:190`; callers `TicketPassSheet.swift:54`, `AccountView.swift:398`, `SessionTicketWalletHost.swift:51` | Yes | **Restore adapted:** pass the namespace from the wallet list | mp-mine |
| D5 | `cyHeroParallax` | BASE: BundleDetailView | Replaced (`ca414a9fc`) → Fixture-only | `MotionLabFixture.swift:95,190` | Yes | Drop (owner rule 2: one optional header image) | — |
| D6 | `cyScrollReveal` | never adopted | Fixture-only | `MotionLabFixture.swift:98` | Yes | Drop | — |
| D7 | `cyStickyHeader` | never adopted | Fixture-only | `MotionLabFixture.swift:103` | n/a | Drop (the native nav bar does this) | — |
| D8 | Staggered list entrance `cyStaggeredAppear` | BASE: 26 uses in 16 files (Home, Passport, Bundle, Club directory, Publish, Activity, search, favourites, badges) | Replaced (`3250a067a`, `63c28ff09`, `ca414a9fc`, `351198266`, `a72d8c1ed`, `58a1d349c`) → Fixture-only | Only inside `CYListChoreography` (`CYLoadingChoreography.swift:80`) → `E4LoadingFixtures.swift:46` | Yes (`CYMotion.swift:481`) | Drop (lists use the system insertion). `motion-spec-loading.md:26` is stale. | — |
| D9 | `cyRowTransition` insert/delete | BASE: 8 uses | Replaced → Fixture-only | `CYLoadingChoreography.swift:79` | Yes | Drop (the default `List` animation) | — |
| D10 | `CYContentSwap` skeleton → content crossfade | never adopted | Fixture-only | `MotionLabFixture.swift:71` | Yes | Drop (R17 `motionR2LoadIn` is the live equivalent) | — |
| D11 | `cyRefreshable` (light tick plus 0.45 s spinner floor) | BASE: 7 files | Live-degraded (1 site) | `AccountView.swift:82`. Home, Bundle, Activity, Official and Publish use plain `.refreshable`. | n/a (haptic) | **Restore as-is:** a one-word swap back to `cyRefreshable` on the 5 tab-level lists (keeps the system control, adds the haptic) | mp-home / mp-publish / mp-activity |
| D12 | `cyEntrance` | BASE: 6 uses | Live (1 site) | `CYShareComposerState.swift:177` | Yes | Keep | — |
| D13 | `cyHeroTitleRise` | BASE | **Live** | `E1ActivityDetailParts.swift:93` ← `ActivityDetailView.swift:405` | Yes (`CYMotion.swift:638`) | Keep (pair it with D2) | — |
| D14 | Shaped pulsing skeleton `CYSkeleton` | BASE: 382 uses in 259 files | Replaced: the component now draws a `ProgressView` (`351f40779`, `8f1ab21e6`); 172 uses remain. mp-states sweeps (`112cdaa03`, `f93598cd6`, …) removed about 210 more. | `DesignSystem/CYSkeleton.swift:18-35` | n/a | **Restore adapted** on feed-type screens only (Home, Club directory, Activity list): `.redacted(reason:.placeholder)` on the real row layout, per brief line 20. No custom shimmer. | mp-states |
| D15 | `.redacted(.placeholder)` | BASE: 2 real sites | **Live** (9 sites) | `CYSharedStates.swift:25`, `MotionR2Metrics.swift:219`, `NativeStampAlbumView.swift:250`, … | static | Keep and extend (D14) | — |
| D16 | `cySkeletonTiming` (delay and minimum display) | BASE: 6 | **Live** (4) | `AccountCollectionFavoritesView.swift:153,365`; `CYPhase.swift:105` | n/a | Keep | — |
| D17 | `CYListChoreography`, `CYSegmentedContent`, `CYStatNumber` count roll | BASE `CYStatNumber` in WalletEarningsOverview | Replaced (`8bd25cb04`) → Fixture-only | `E4LoadingFixtures.swift:34,44,46` | Yes | Drop (`nativeR2RollingNumber` replaces `CYStatNumber`) | — |
| D18 | Join morph `CYMorphButton` and orbit dots | BASE: 15 uses in 9 files | Live-degraded (4 sites: `ContentLandingScreen.swift:84`, `HostTipViews.swift:80`) | Lost: PassMarket (`84fd0d480`), JourneyLanding (`e5bb4c8a0`), ChannelRedeem (`ad06ffc86`), VideoBounty (`9e02e49a6`) | Yes (`CYMorphButton.swift:26-99`) | Drop. `.borderedProminent` plus ProgressView is the standard. Make the remaining 4 consistent. | ds-consistency |
| D19 | Club join stage `CYClubJoinStage`, club card morph | BASE `ClubActionPanel` | Replaced (`35852c11d`) → Fixture-only / Orphan | `D4Fixtures.swift:90` | Yes | Drop (B9 covers it) | — |
| D20 | Glass carousel `CYGlassCarousel` / `CYCarouselRail` | BASE: Home feed, `TicketWalletView:338` | Replaced (`3250a067a`, `8c9408404`); its glass is Neutered (`89e71d61d`) → Fixture-only | `CarouselFixtures.swift:45`; `CYGlassCarousel.swift:319-357` no-ops | Yes | Drop. Home uses `ScrollView(.horizontal)`; add `.scrollTargetBehavior(.viewAligned)` (system snap). | mp-home |
| D21 | `CYHeroBanner` (auto-paging banner, `.selection` per page, `scrollTransition`) | BASE `HomeFeedView:231` | Replaced (`3250a067a`, `4ee2a3be1`) → Orphan | `#Preview` only (`CYHeroBanner.swift:89`) | — | **Restore adapted:** Home banner (MP order, P-home) as `TabView(.page)` with page dots and `.sensoryFeedback(.selection)` on page change | mp-home |
| D22 | Pass tilt `cyPassTilt` | BASE: TicketPassSheet, E1TicketCard | **Live** (E1TicketCard) | `E1TicketCard.swift:161` ← `TicketWalletDetailView.swift:385` | Yes (`CYTicketPass.swift:172-188`) | Keep | — |
| D23 | Ticket foil sheen `cyFoilSheen(trigger:)` | BASE: 15 uses in 8 files | Live-degraded (7 uses in 4 files) | `E1TicketCard.swift:38`; `RoamStampViews.swift:439` | Yes (`:226,233`) | Keep. Do not re-add it to lists. | — |
| D24 | Spinning foil edge `cyPassFoilEdge` | BASE | **Live** (ready tickets) | `E1TicketCard.swift:40` | Yes (`CYPassVerified.swift:166`) | Keep | — |
| D25 | Ticket verified flip and perforation tear (`CYPassFlip`, `CYPassTear`, `CYPassVerifiedFace`) | BASE `TicketPassSheet` | Replaced (`84fd0d480`) → Orphan | No callers | Yes (unused) | **Restore adapted:** on staff verification, `contentTransition(.symbolEffect(.replace))` `qrcode` → `checkmark.seal.fill`, `.sensoryFeedback(.success)` and R8 edge glow. No 3D flip or tear. | mp-activity |
| D26 | Code reveal `cyCodeReveal` | BASE `TicketPassPresentView` | Replaced (`da7f2c201`, now `.opacity`) → Orphan | `TicketPassPresentView.swift:27` | Yes | Drop (the opacity transition is fine) | — |
| D27 | `cyPassStack`, `cyScrollSheen`, `CYStatusRibbon` | never adopted | Orphan | No callers at BASE or HEAD | Yes | Drop. Update `motion-spec-tickets.md`. | — |
| D28 | `cyBrightnessBoost` (QR) | BASE | **Live** | `TicketPassSheet.swift:264`, `TicketPassPresentView.swift:49`, `CouponCodeView.swift:62` | Reads the setting (`CYTicketPass.swift:356`) | Keep | — |
| D29 | `CYPassFromCard` card → pass morph | never adopted | Fixture-only | `E1TicketFixtures.swift:153` | Yes | Drop | — |
| D30 | Purchase kit `CYPayButton`, `CYBuyBar`, `CYAnimatedPrice`, `CYResultMark` | BASE: BundleOrderSummary, BundleDetail, BundlePayResult, BundleRedeemResult | Replaced (`ca414a9fc`) → Orphan | Used only inside their own file (`CYPurchaseMotion.swift:223,243`) | not checked | **Restore adapted:** keep `.borderedProminent` plus ProgressView. Add `.contentTransition(.numericText)` on the price and `symbolEffect(.bounce)` plus `.success` on the pay-result `ContentUnavailableView` symbol (P30). | mp-activity |
| D31 | Scan kit (`CYScanStage`, `CYViewfinder`, `CYScanSweep`, `CYCountUp`, `CYScanResultCard`) | BASE: `CYScanSweep` in VerificationCodeView | Replaced (`cc9769c52`) → Fixture-only | `QRScanFixtures.swift:36` | not checked | Drop (there is no camera scanner; ProgressView is correct) | — |
| D32 | `CYScratchCard` | BASE: 4 | **Live** (5) | `NativeR2/Games/ChoiceKits.swift:239`; `PlayKitDecisionProgressViews.swift:237` | Yes (`CYScratchCard.swift:14,34,144`) | Keep | — |
| D33 | `CYPressScaleStyle` | BASE: 5 uses in 4 files | Replaced (`3250a067a`, …) → Orphan | No callers | Yes | Drop | — |
| D34 | `cyStaggerAppear` (signature variant) | BASE | **Live** | `JourneyLandingViews.swift:95` | Yes (`CYSignature.swift:160`) | Keep | — |
| D35 | Sliding tab indicator `matchedGeometryEffect` (club detail, album, MP parity tabs, template detail, live roam) | BASE: 27 uses in 18 files | Replaced (`b47382ab8`, `c14786a0f`, `41e4c2bc1`, `a1519ed20`) by `Picker(.segmented)` | 27 uses in 14 files remain (City, IM inbox, JourneyLanding, MotionR2Flows) | Yes (`CityChallengeFlow.swift:195,218`) | Keep the replacement (segmented `Picker` animates natively) | — |
| D36 | Modal motion `CYModal`, `CYPromptModal`, `cyModalOverlay` | BASE: 5 | **Live** (5) | `MerchantProjectsView.swift:233`, `PlayAreaPopupCloseSurfaces.swift:375`, `RoamNearbyParityExtras.swift:201` | Yes (`CYSheetModal.swift:316,526,668`) | Keep (consider `.sheet` per owner rule 2) | — |

### E. Native-r2 motion r1 / r2 (new set; all added after BASE)

| # | Effect | Where it was | Status on combined-r7 | Evidence | Reduce Motion fallback? | Recommendation | Owning lane |
|---|---|---|---|---|---|---|---|
| E1 | M1 finish route thumbnail draw-on and metric roll | `800446269` | **Live** | `CityOrientationFinishSummaryView.swift:24,124,226-247` | Yes (`:226`) | Keep | — |
| E2 | M1 route replay `NativeR2RouteReplayView` and `NativeR2ArrivalMark` | `800446269` | **Live** (when at least one leg is walked) | `CityOrientationFinishSummaryView.swift:97,266-274` → `NativeR2RouteReplay.swift:35,149,276` | Yes (`:81,103-127,281`) | Keep | — |
| E3 | M1 live-run segment and team-trail draw-on, banner and peek rolls | receipt | **Live** | `CityOrientationRunView.swift:54,151,185,219,283,439,449` | Yes (`NativeR2Motion.swift:22,91`) | Keep | — |
| E4 | M1 free-explore path draw-on, M3 pin symbol replace, M3 unlock bounce | receipt | Flag-off (`nativeR2.freeExploreMapHome` default OFF; `4ae25d75f`, owner rule MP card pack) | `PlayExperienceView.swift:118-124`; `NativeFreeExploreMapView.swift:40,216`; `NativeFreeExploreArrivalSheet.swift:39` | Yes | **Restore adapted** onto the live card-pack path: use the unlock bounce in `FreeExplorationExperienceView` when a stop unlocks | mp-journey |
| E5 | M2 sheet backdrop (punch sheet, story result) | receipt | **Live** (story-gated part on hold) | `PlayExperienceView.swift:892,894,1450-1452` | Yes (wash only; `NativeR2SheetBackdrop.swift:39,55`) | Keep | — |
| E6 | M2 game-result backdrop → M5 global `cySheet` backdrop | `800446269` → `7222465af`, `03033d614` | Replaced by the global backdrop on about 696 sheets | `NativeGameShell.swift:159`; `CYSheet.swift:22,73-76`; `QuestifyApp.swift:166` | Yes | Review: the receipt said "all other sheets untouched". Owner/coordinator to confirm the global blur is intended. | coordinator |
| E7 | M3 run banner symbol replace, 50 m bounce, punch bounce, refused `.error`, stamp-created bounce | receipt | **Live** | `CityOrientationRunView.swift:88,270-271`; `CityOrientationNavComponents.swift:126`; `CityOrientationPunchSheet.swift:109-110`; `NativeStampCaptureView.swift:58,133` | Yes | Keep | — |
| E8 | R1 stamp ink press, heavy impact, contour draw | `MotionR2Rewards.swift:44` | **Live** | `NativeStampCaptureView.swift:134-136` | Yes (`MotionR2Rewards.swift:104`) | Keep | — |
| E9 | R2 holo sheen on the scratch prize | receipt | **Live** (games) | `NativeGameKitsC.swift:358` via `PlayKitScreen.swift:166` | Yes (`MotionR2Core.swift:84`) | Keep | — |
| E10 | R2 `MotionR2RewardReveal` (spin → holo card) | `MotionR2Rewards.swift:123` | Orphan (`#Preview` only, `:298`) | The planned wrap of `NativeGameRewardBadge` was not done (`NativeGameShell.swift:302`) | Yes (`:134`) | **Restore as-is:** the one-line wrap that the receipt names | native-b |
| E11 | R2 sheen and R13 tilt on badge detail | `ProfileBadgesView.swift:105-106` | Orphan host (`ProfileBadgesView` has no caller; badges open `ObjectBadgeWallView`, `AccountView.swift:131`) | `grep "ProfileBadgesView("` → none | Yes | **Restore adapted:** move the two modifiers to the live badge detail in `ObjectBadgeViews.swift` | mp-mine |
| E12 | R3 scratch tiles kit | `MotionR2Games.swift:31` | Orphan (`#Preview` only) | no 3-prize payload | Yes | Hold until a backend payload exists | — |
| E13 | R3 `.selection` tick per quarter on the G-004 scratch | receipt | **Live** | `NativeGameKitsC.swift:341` | haptic | Keep | — |
| E14 | R4 snow globe | receipt | **Live** (games) | `NativeGameSensorKit.swift:175-177` | Yes (`MotionR2Games.swift:145`) | Keep | — |
| E15 | R5 tab symbol bounce | `MotionR2Flows.swift:11` | Flag-off (`nativeR2.motion2.tabBounce` default false; iOS 17 path only) | `QuestifyApp.swift:486-490,888-891` | Yes | See F1 (pair with the tab haptic) | shell |
| E16 | R6 gift box (stamp exchange) | receipt | **Live** | `NativeStampCaptureView.swift:213-215` | Yes (`MotionR2Rewards.swift:235`) | Keep | — |
| E17 | R7 resizing permission primer sheet | receipt | **Live** | `CYPermissionPrimer.swift:324-333` | Yes (`MotionR2Flows.swift:105`) | Keep | — |
| E18 | R8 edge glow (punch, payment, finish) | receipt | **Live** | `CityOrientationPunchSheet.swift:85`; `PaymentProviderReturnSheet.swift:33`; finish `:184` | Yes (`MotionR2Core.swift:136`) | Keep | — |
| E19 | R9 confirm card → pill → island | receipt | **Live** | `PaymentProviderReturnSheet.swift:19-21`; `MotionR2Flows.swift:188` | Yes (`:183`) | Keep | — |
| E20 | R10 first-run checklist and marks | receipt | **Live** (restyled to `CYStepChecklist`, `5b5151327`) | `AccountView.swift:206`; marks at `CityOrientationPunchSheet.swift:83`, `NativeStampCaptureView.swift:82`, `ClubHomeView.swift:366` | Yes (`CYStepChecklist.swift:77-179`) | Keep | — |
| E21 | R11 mood gradient hero and R12 flame fill | receipt | **Live** | `CityOrientationFinishSummaryView.swift:136` → `MotionR2Hooks.swift:18-28` | Yes (`MotionR2Metrics.swift:42,82,151`) | Keep | — |
| E22 | R13 tilt on stamp detail | receipt | **Live** | `RoamStampViews.swift:557` | Yes (`MotionR2Core.swift:57`) | Keep | — |
| E23 | R14 rank roll and row moves | receipt | **Live** (when a board exists) | `CityOrientationFinishSummaryView.swift:292,316` | Yes (`MotionR2Metrics.swift:180,204`) | Keep | — |
| E24 | R15 magazine stack | — | Not built (story paused) | receipt | — | Hold | — |
| E25 | R16 capture menu | receipt | **Live** | `CityOrientationPunchSheet.swift:308-310` | Yes (`MotionR2Flows.swift:322,326`) | Keep | — |
| E26 | R17 passport redacted → fade | receipt | **Live** | `PassportView.swift:105` | Yes (`MotionR2Metrics.swift:221`) | Keep | — |
| E27 | R18 membership plan symbol morph | receipt | **Live** (deep link) | `PassMembershipViews.swift:242` ← `MPParityKit.swift:198-199,302` | Yes (`MotionR2Metrics.swift:247`) | Keep | — |
| E28 | Motion r3 (60 rows, `nativeR2.motion3`) | brief `native-r2-motion-r3.md` (handoff-r2 `0903de85b`) | Not implemented (no code, branch or receipt) | `git grep motion3` on all remotes → none | — | Schedule as a lane, or close the brief | coordinator |
| E29 | P21 mini bar → full-screen HUD zoom morph | new | **Live** (every tab) | `QuestifyApp.swift:466-468` → `ActiveSessionMiniBar.swift:259,266-268,339-358` | Yes (`:259,268,275-278,322-324`) | Keep | — |

### F. Haptics, sound, island, Live Activities and widgets

| # | Effect | Where it was | Status on combined-r7 | Evidence | Reduce Motion fallback? | Recommendation | Owning lane |
|---|---|---|---|---|---|---|---|
| F1 | Tab-change `.selection` haptic | BASE `QuestifyApp.swift:380` `.cyHaptic(.selection, trigger: selectedTab)` | Replaced (`95fe28012`) | `QuestifyApp.swift:472` "No custom bar, pill or haptic". `motion-spec.md:49` still lists it. | n/a | **Restore as-is:** `.sensoryFeedback(.selection, trigger: selectedTab)` on the system `TabView` (Apple API, no custom bar) | shell |
| F2 | Chips and segments `.selection` | BASE: about 80 | **Live** (about 80; two lost: `MPParityKit:494` `c14786a0f`, `OfficialEventsBrowserView:49` `58a1d349c`) | e.g. `AccountView.swift:72`, `ClubHomeView.swift:73`, `GlobalSearchView.swift:526` | n/a | Restore the two lost ones as-is | mp-mine / mp-activity |
| F3 | Hero banner page `.selection` | BASE `CYHeroBanner:56` | Replaced → Orphan (`3250a067a`) | see D21 | n/a | With D21 | mp-home |
| F4 | City selection and consent `.selection` | BASE | **Live** | `CYCityKit.swift:176`; `WelcomeView.swift:184`; `RegistrationSheetView.swift:1568` | n/a | Keep | — |
| F5 | `.success` (join, stamp, badge, sign-in) | BASE | **Live** | `ClubActionPanel.swift:493,502`; `NativeStampCaptureView.swift:58`; `QuestifyApp.swift:500` | n/a | Keep | — |
| F6 | `.warning` on blocked registration | BASE `RegistrationSheetView:501` | **Live** | `RegistrationSheetView.swift:684` | n/a | Keep | — |
| F7 | `.impactLight` on pull-to-refresh | BASE: 6 | Live-degraded (1) | see D11 | n/a | With D11 | — |
| F8 | `.impactMedium` on dice roll | BASE `PlayRPGComponents:114` | **Live** | `PlayRPGComponents.swift:114`; `ChanceKits.swift:152,399` | n/a | Keep | — |
| F9 | `.impactHeavy` on GO press | BASE `RoamLiveSessionView:494` | Replaced (`a1519ed20`) | see C4 | n/a | With C4 | mp-roam |
| F10 | Haptic routing through `HapticsService` (in-app toggle `scene_sound_haptics`, 120 ms cooldown) | `docs/design/haptics-map.md` rules 2–3 | Live-degraded: `.sensoryFeedback` grew from 74 to 166 uses (all of Games, Motion r2, Island) and bypasses the toggle | `CYMotion.swift:51-64` (only `cyHaptic` / `CYHaptics.play` are routed); `IslandOverlay.swift:39` | n/a | **Restore adapted:** add `.cySensoryFeedback(_:trigger:)` that checks `HapticsService.isEnabled` (`.sensoryFeedback` with a `condition:` closure), then codemod the 166 sites. Otherwise the Settings toggle is a lie. | ds-consistency |
| F11 | Sound effects | — | None bundled (no `.caf`, `.wav`, `.mp3` or `.m4a`). Settings `sound` and ambience toggles (`Core/SettingsSoundPreferences.swift:5`) have no consumer: Orphan. | `AVAudioPlayer` is used only by IM voice, NPC voice, play BGM (`PlayBackgroundMusic.swift`) and story audio | n/a | Owner decision: hide the dead toggles, or add system sounds at the P30 moments | mp-mine (settings) |
| F12 | In-app island overlay (spring morph, blurReplace, variableColor, light impact) | new | **Live** (`nativeR2.island`) | `QuestifyApp.swift:169` → `IslandWindow.swift:12` → `IslandOverlay.swift:21-39,206` | Yes (`:37-44,90,206`) | Keep | — |
| F13 | Play/roam Live Activity and Dynamic Island (timer text, progress) | new | **Live** | `AppSession.swift:1336,6195` → `QuestLiveActivityCenter.swift:223-226`; `CityOrientationRunView.swift:114` | System | Keep. The free-explore context is Flag-off with E4. | — |
| F14 | Event countdown, plan/invite and story-audio Live Activities | new | **Live** (story audio is story-gated) | `TicketWalletView.swift:177` → `QuestLiveActivityCenter.swift:97`; `QuestifyApp.swift:10`; `QuestPlanActivityCenter.swift:131`; `IslandSources.swift:103-124` | System | Keep | — |
| F15 | Widgets (next stop, countdown, streak, city, community; `numericText`) and control widgets | new | **Live** once the user adds them (data feed not verified) | `LiveActivityWidget/QuestLiveActivityWidgetBundle.swift:11-21`; `QuestBoardWidgets.swift:57,400`; `QuestControlWidgets.swift:8,22` | System | Keep | — |
| F16 | Games: shell score `numericText`, wrong-reply bounce, `.success`/`.error`, reward badge ripple, kit symbol effects and sensor haptics | comp/r1-games | **Live** (`nativeR2.games`) | `NativeGameShell.swift:210,318,366,446`; `NativeGameHUD.swift:129,145`; `NativeGameKitsC.swift:113-739`; `NativeGameSensorKit.swift:139-289` | **Partial:** `NativeGameKitsC.swift:113,119,222,666` and `NativeGameSensorKit.swift:213,275,289` have no guard | Add a Reduce Motion guard on those `numericText` sites | native-b / a11y-dt |
| F17 | P30 result moment (roam finish report, journey settle, city finish) | new | **Live** | `RoamFinishReportView.swift:93,105,232` ← `RoamLiveSessionView.swift:543`; `JourneyReportViews.swift:1064`; `CityOrientationFinishSummaryView.swift:187` | Yes | Keep. Add B4 confetti once (P30). | mp-roam / mp-journey |

## Reduce Motion coverage (reachable effects)

- **Covered:** every Live effect has a Reduce Motion path except these:
  - **C2:** map-home panel and camera. `App/NativeR2/MapHome/*` has no `accessibilityReduceMotion` at all.
  - **F16:** game-kit `numericText` at 7 sites.
  - **C6:** the live-roam `symbolEffect(.bounce)` relies on the system symbol-effect behaviour (unverified).
- **`accessibilityReduceMotion` / `@QuestifyReduceMotion` usage** went from 105 / 240 at BASE to 152 / 209 at HEAD. The drop in `@QuestifyReduceMotion` follows the removed effects.
- **Two Reduce Motion stacks now coexist:**
  - Motion r1/r2 reads the system `accessibilityReduceMotion` only.
  - The older kit reads `@QuestifyReduceMotion`, which also honours the in-app setting and `--uitesting-reduce-motion`.
  - So the in-app "reduce motion" setting does not turn off the motion r1/r2 moments.
  - **Fix:** make `MotionR2.live` and `NativeR2DrawOn.run(reduceMotion:)` read `@QuestifyReduceMotion`. Owner: a11y-dt plus native-b.

## Ranked restore list

Ranked by what the owner sees, multiplied by how cheap a native-style fix is. Every item stays inside owner rule 2: Apple components and APIs, Dynamic Type, no custom tracking or fonts, a Reduce Motion fallback, and a motion-spec line in the receipt (design-principles "Motion spec format").

| Rank | Item | Change | Lane |
|---|---|---|---|
| 1 | F1 tab haptic | One modifier: `.sensoryFeedback(.selection, trigger: selectedTab)` at `QuestifyApp.swift` `playerTabs`. Also decide on E15 (turn on `tabBounce` after a simulator check, or delete it). | shell |
| 2 | B4 completion confetti | Owner/coordinator must first resolve the brief conflict: native-r2 "remove confetti" vs P7/P30 "confetti once". If confetti is approved: restore the `CYConfettiBurst` body (one `Canvas`, about 1.2 s, once, `accessibilityHidden`, a fade under Reduce Motion). Adopt it at three moments only: roam finish (F17), journey settle, badge unlock (B3). | coordinator → ds-consistency |
| 3 | B3 / E11 / B26 badge moments | Re-feed `CYBadgeUnlockCover` from the live badge unlock in `ObjectBadgeViews`. Move the R2 sheen and R13 tilt from the dead `ProfileBadgesView` to the live badge detail. Route level-up through the celebration queue. | mp-mine |
| 4 | D2 hero zoom on lost lists | Activity → detail, Official route → detail, Pass market → detail. These are system `.navigationTransition(.zoom)` modifiers, and `cyHeroSource` / `cyHeroDestination` already exist. | mp-home / mp-activity |
| 5 | C4 / F9 GO commit | Keep the `.borderedProminent` 走起 button. Add a heavy-impact `.sensoryFeedback` and a symbol bounce. Optionally add R8 edge glow on the start. | mp-roam |
| 6 | F10 haptic toggle | One `cySensoryFeedback` wrapper that respects `HapticsService`, then a codemod. A correctness issue, not just polish. | ds-consistency |
| 7 | D21 / F3 Home banner | `TabView(.page)` banner with page dots and `.selection` per page (also closes a round-3 MP-order item). | mp-home |
| 8 | D25 / D30 ticket and purchase moments | Ticket verified: QR → `checkmark.seal` symbol replace, `.success`, edge glow. Pay result: `numericText` price, bounce and `.success` on the `ContentUnavailableView` symbol. | mp-activity |
| 9 | D11 / F7 pull-to-refresh tick | `.refreshable` → `cyRefreshable` on the 5 tab-level lists. | mp-home / mp-publish / mp-activity |
| 10 | E10 / B22 orphans that need one line each | Wrap `NativeGameRewardBadge` in `MotionR2RewardReveal`. Assign `verdict` in `PlayExperienceView` so `CYPlayVerdictOverlay` plays. | native-b / mp-journey |
| 11 | A1 onboarding | A short native `TabView(.page)` intro in front of the welcome (3 pages, SF Symbol demos with `symbolEffect`). Needs an owner OK, because `95fe28012` removed it on owner instruction ("everything native"). | shell / mp-nav |
| 12 | E4 free-explore unlock bounce | Reuse it on the live card-pack path. | mp-journey |
| 13 | C2 / F16 / two-stack Reduce Motion | Add Reduce Motion to the map home and the game kits. Unify on `@QuestifyReduceMotion`. | a11y-dt / native-b |
| 14 | D14 loading on feeds | `.redacted(.placeholder)` on real rows for Home, Club directory and the Activity list, instead of a bare `ProgressView`. | mp-states |
| 15 | C3 map-home route draw-on | Reuse `NativeR2DrawOn`. | mp-roam |

### Deliberately not restored (drop, with reason)

| Items | Reason |
|---|---|
| Fog, night glass and glass chrome (C8–C12) | Brief line 31; system materials and the MapKit controls replace them. C8 needs an owner decision because it never shipped. |
| Glass carousel (D20) | Brief line 31; system materials replace it. |
| Metal shaders (A3, C25) | Never compiled into the app (`.metal` is not in pbxproj). |
| Custom tab bar (C10) | Owner rule 2. |
| `CYSkeleton` pulse (D14) | Replaced by `.redacted`. |
| Stagger and row transitions (D8, D9) | System list animations replace them. |
| Press scale and morph on list rows (D1, D18, D33) | The system highlight replaces them. |
| Parallax, sticky header, scroll reveal (D5–D7) | The native nav bar replaces them. |
| Particles and bloom (B5, B8) | B4 covers the need. |
| Never-wired kit pieces (B13–B15, D6, D7, D10, D27, D29) | Never shipped. |
| Scan kit (D31) | There is no camera scanner. |

### Cleanup (not a restore)

- **Dead code still compiles:** the neutered bodies and orphaned kits (`CYEdgeGlow`, `CYBurst`, `CYStarBloom`, `CYFoil`, the `CYGlassCarousel` parts, `CYPurchaseMotion`, the `CYPassVerified` flip and tear, `CYHeroBanner`, the `CYWave` press styles, the `OnboardingFlow` kit).
- **Recommendation:** after the owner decides on the restore list, delete what is dropped. Then there is one implementation per effect: `MotionR2EdgeGlow` vs `CYEdgeGlow`, `MotionR2HoloSheen` vs `cyFoil`.
- **Stale docs:** mark the specs as historical or rewrite them. Affected: `docs/release/motion-spec.md` (tab haptic, Home stagger, hero zoom table), `motion-spec-carousel.md`, `-loading.md`, `-purchase.md`, `-qr.md`, `-tickets.md`, `-roam.md` (GO circle, fog drift), `-onboarding.md` (pager as shipped), and `receipts/ui-celebration.md` ("Nothing live" is wrong for BASE). Lane: ds-consistency.

## Key commits

| Commit | Date | What it removed |
|---|---|---|
| `89e71d61d` | 11-26 | "光晕/箔片/粒子/雾/玻璃装饰改为空操作" (glow, foil, particles, fog and glass decorations made no-ops). 9 DesignSystem bodies → `EmptyView`/passthrough: CYBurst, CYEdgeGlow, CYFoil, CYGlassCarousel, CYMapChrome, CYNightGlass, CYRoamKit fog, CYSignature confetti, CYStarBloom. |
| `95fe28012` | 11-26 | native-r2/shell: system TabView (no night tab bar or tab haptic) and the Apple-style welcome (no onboarding pager). |
| `a1519ed20` | 11-26 | P-040 live roam: Map plus system sheet. No GO hold, wave, particles or fog layer; the roam summary went to RoamFinishReportView. |
| `3250a067a` | 11-26 | Home: no hero banner, glass carousel, press wave, stagger or `cyRefreshable`. |
| `84fd0d480`, `da7f2c201` | 11-26 | Ticket pass: no flip, tear, foil, tilt, edge glow or code reveal. |
| `ca414a9fc` | 11-26 | Bundle and purchase: no pay button, buy bar, animated price, result mark, parallax, stagger or confetti. |
| `351f40779`, `8f1ab21e6` | 11-26 | `CYSkeleton` → `ProgressView`. mp-states r3 sweeps removed about 210 more call sites. |
| `c0df8238f`, `4ae25d75f`, `a77f76fff`, `4a6129aff` | 11-26/27 | Native flows that put the stamp slam, the free-explore map motion, the medal screen and the chapter gate on legacy flag paths. |
