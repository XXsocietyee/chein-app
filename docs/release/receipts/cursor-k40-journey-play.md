# cursor/1128-k40-journey-play

Re-check of the journey-play rows only. Sources: `origin/design/handoff-r2:docs/briefs/round3-1127.md`,
`origin/audit/1128-plan:docs/audits/1128-plan.md` (journey domain, including J-07 and the 19 node templates),
`origin/audit/1128-functions:docs/audits/1128-functions.md` (mp-journey play rows),
`origin/audit/1128-ada:docs/audits/1128-ada.md` (mp-journey screens). No other domain.

Base `origin/ui/combined-r7` @ `a7c956335` (same tip at branch time). Proof is
`RegionalLaunchConfiguration.shippedComposition` (reviewed deployment) in
`Fix1128bPlayReleaseCompositionTests.testReleasePlayLeaseAdmitsAdvancedStateAndLeaderboard`
and the existing `testShippedChinaAdmitsPlayRuntimeAndKeepsMoneyClosed` read list.
No Swift compiler here, so those tests are written, not executed. The Swift-free gates below were run.

Money switches were not edited. Merchant routes stay off the play grant. `App/AppSession.swift` stays 7977 lines.
Play configuration init order stays devices, sensors, artworkHosts. No `String(localized:)`. No secrets, deploys, or SQL.
No backend branch: `api/play/advanced/state` and `api/play/advanced/leaderboard` are already
`liveInProduction` in `ChinaReviewedRouteCapability`. Egg collect stays off (the MP never calls it).

## Fixed this run

| Row | What changed | Proof |
|---|---|---|
| **J-08f / J-09h** (J-07 leaderboard modifier) | `api/play/advanced/state` and `api/play/advanced/leaderboard` join `playRuntimeReadPaths` (GET, query, no body). Kit refresh, recovery, and the per-node board already call these reads; Release was refusing them before they left the device. | composition test sends both GETs through `RuntimeDependencyFactory` and refuses a POST |
| **J-09b** | Legacy puzzle section (shown only while the server hint ladder is off) now confirms and calls `requestReveal` → `POST api/play/puzzle/reveal`. City orientation, hints on, unlocked node. The ladder's ANSWER row still uses `help/use`. | `test_release_play_reads_admit_advanced_state_and_legacy_reveal` |

## Already fixed

| Row | Status | Where |
|---|---|---|
| J-02a, J-06d, J-06e, J-07 #3, J-12b, J-11c photo/scan | already fixed | `36e0608e2` devices `[.photo, .scan, .location, .motion]`, `.mediaUpload`, `api/common/uploadOSS` |
| J-06f, J-09d, J-09e, J-09i | already fixed | `36e0608e2` templated preference / tag / 人生 OS paths and `.preference` / `.tags` |
| J-07 #2 / #6 / #7 artwork | already fixed | `36e0608e2` `playArtworkHosts` (API host). CDN origins stay an owner value (`QUESTIFY_IMAGE_ORIGINS`) |
| J-05a, J-05b, J-09f | already fixed | `36e0608e2` `api/play/ending` and `api/play/leaderboard`; ranking failure is soft |
| J-19, J-03 / J-17 sheet | already fixed | `5a46897aa` operator notes stripped; stage-end sheet opens only when its read is on. Story-flow theme stays paused |
| J-07 #12–14, J-06g, J-12a sensors | already fixed | `837ba4d05` `playSensors` `[.acceleration, .soundPeak, .heading]`; motion and kit sensor factories follow that set. Microphone and motion usage strings are already in `Config/Base.xcconfig` |
| J-09a, J-10b | already fixed | `ea509286a` puzzle hint and hint unlock |
| J-11a, J-11b, J-11c | already fixed | `e983dce01` store-day proof and consent; "导航去这里" |
| J-11d | already fixed | `ceeeb450e` reviewed play route carries `registrationId` |
| J-16 | already fixed | `productionPlayCircle` is asked first (`SessionPlayRuntimeView`); circle routes are on the play grant |
| J-04a | already fixed | `4ef826127` shop NPC text and voice reach the server; the server flag decides. Reply-audio clone stays off |
| J-12d | already fixed | `uploadAudio` uses `.mediaUpload` and `uploadOSS`, both on since `36e0608e2` |
| J-13e, J-02c nav | already fixed | `AppSession` builds `PlatformConsumerSessionOwner(maps: appleMaps)` and the play host passes `mapsFactory` |
| J-15 | already fixed | `9e0847026` recap export is a play runtime GET |
| J-18 | already fixed | `4a96d2701` `.leader` and the lead tools. `settle` still requires the money switch |
| J-02d | already fixed | punch-sheet meta is the address; description stays because the MP prints it |
| J-06a, J-06b, J-06c submit, J-08e, J-09c, J-09g | already fixed | the audit already marked these closed; the submit paths are still the ones Release admits |
| J-10a | already fixed | stays off. The MP never calls `api/play/egg/collect`. `journeyCollect` remains false |
| J-13a | already fixed | run map draws `UserAnnotation` and follows the user on open |
| J-07 templates 1–19 submit | already fixed | photo, artwork hosts, and sensors above. Scan replies can upload. Countdown's "—" clock is J-08c |
| Functions audit, play rows | already fixed | continuation, nodes, store-day check-in, hint, circle, and the lead bar match the grants above. Payment and ticket rows stay with the money lane |
| ADA mp-journey | already fixed | closed on the mp-journey r3 pass (map controls, idle HUD, reserve form, settle dots). Not restyled again |

## Owner-only

| Row | Why it stays |
|---|---|
| J-04c | Dialogue is repointed at `api/ai/npc/chat`, and `journeyAsks` stays false while the story-flow theme is paused. The path is not added here |
| J-07+ | Multi-question, experience-card reward, and photo AI review are open product decisions |
| J-08a / J-12c | Steps need `NativePlatformAcceptance` with `legalReviewed`, a purpose version, and an https privacy URL. The type says the shipped dependency stays nil until that acceptance exists |
| J-08b | Mascot, woodfish, and stickerbook are not in the current MP source |
| J-08c | The kit deadline has no server clock, so the phone does not tick it. The stage-shell time bar needs an owner call |
| J-13b / J-13c / J-13d | Walking directions require owner-verified WGS84 regions. The planner rejects unverified regions, GCJ-02, driving, and transit before it runs |
| J-14 | The app card renders `aiScore` when a photo receipt includes `score > 0`. The backend still does not emit `aiScore` |

## Not restyled

J-01 (segmented ring, six-card grid), J-02b (3D pack), J-04b (humanoid figure; no stage view exists to wire), J-08d (sensor ring meter, flowing route highlight). J-02c's collapsing header and J-06c's half-sheet stay as they are; their sends and the nav row are already on.

## Deferred-merchant

None in this lane. Shop NPC player chat is on (`4ef826127`). Merchant voice-clone playback and merchant authoring stay gated. No `api/merchant/` path was added to the play grant.

## Gates

Run on this tree:

- `check_scaffold.py` PASS (AppSession ratchet PASS, 7977 lines, 21685 bilingual keys)
- `check_a11y_lint.py` PASS (0 new)
- `contract_ratchet.py --check` 46 failing, baseline 46, **new 0**, fixed 0
- `generate_project.py` not run (no new Swift files)

`Tests/ContractChecks/test_play_experience_contracts.py` `test_release_play_reads_admit_advanced_state_and_legacy_reveal` passed (init order devices → sensors → artworkHosts, both reads, reveal call, both string languages).
