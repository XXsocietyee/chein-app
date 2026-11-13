# fixtures-g — DEBUG design fixtures for the G / parity player screens

Branch `ui/fixtures-g`. Base: `origin/ui/parity-b` `f1adac9e9`, which already contains g-partials (G1 + G7/G8).
The brief asked for a no-ff merge of `origin/ui/parity-a` (`ba26398e3`). The merge was clean, but it brings in parity-a
code (`App/MPParityDeepLinkEntry.swift`, `Core/MiniProgramPageLink.swift`, routing edits, tests). The brief's fallback
applies: the commit sits on parity-b alone, and the parity-a fixtures are TODO-after-merge (below).
Code only. No `xcodebuild` was run.

## What changed

- `App/DesignFixtures/GParityFixtures.swift` (new, wrapped in `#if DEBUG`). Each fixture mounts the REAL view. Its data
  comes from `GParityTransport`, a synthetic `HTTPTransport` that answers by path with mini-program envelopes
  `{code, msg, data}`. The reply bodies are copied from `PlayerGapRoutesTests`, `PlayerParityBRoutesTests`,
  `PlayGapPartialsTests` and `PlayRuntimeGapTests`. An unrouted path throws, like a lost connection.
  - G7/G8 and parity-b views get a `PlayerGapService` on that transport through `\.playerGapService`, the same way
    `SessionRootView` injects the real one. The account is `990001` and the token is synthetic.
  - G1 views get a `PlayRuntimeClient` on that transport, through `\.playRuntimeTopicClient` or the view's own
    `client` closure.
  - Signup unknown seeds the persisted slot `cy-team-event-command-v1:990001:SIGNUP:902` in `UserDefaults`, as a
    relaunch after a lost reply would. The normal signup fixture clears that slot first.
- `App/DesignFixtures/DesignFixtureRegistry.swift`: one line in the `default:` chain hands `g-*` ids to
  `GParityFixtures.make`. Launch with `--design-fixture <id>`.
- `App/DesignFixtures/DesignFixtureReleaseExclusionAudit.swift`: regenerated with `--write` (11 new symbols).
- `Questify.xcodeproj/project.pbxproj`: regenerated. The only change is the new file, which is in the Release
  `EXCLUDED_SOURCE_FILE_NAMES`.

## view → fixture id → states

Every fixture is a `List` titled with the state name and a footer reading 「DEBUG fixture · synthetic transport」.

| View (file) | Fixture ids | Normal | Non-happy |
|---|---|---|---|
| `OfficialSignupCommandSection` (PlayerGapViews) | `g-signup`, `g-signup-unknown` | submit button; a tap settles APPLIED (the receipt echoes the request id) | **unknown**: a persisted slot, with query / retry / cancel; nothing answers them |
| `OfficialRoamActiveCardView` | `g-roam-events`, `g-roam-events-empty` | two open events (`playerGap.roamEvents.many`) | **empty**: `[]`, so the card is hidden |
| `TeamInviteQRSection` | `g-team-qr`, `g-team-qr-refused` | tap 「load」 → code `AB23CD` (qrState UNAVAILABLE, no remote image) | **refused**: 403 「你不是该队伍成员」 after the tap |
| `TeamTrailSection` | `g-team-trail`, `g-team-trail-unavailable` | consent toggle + confirm; confirm → sharing, two teams after a sync | **unavailable**: `available:false`, so the section is hidden |
| `LeadMemberActionsSection` | `g-lead-member`, `g-lead-member-refused` | arrive + broadcast; broadcast → 「已发送给领队」 | **refused**: already arrived; broadcast 429 「发送太频繁，请稍后再试」 |
| `PlayerCodeAndJoinSection` | `g-player-code`, `g-player-code-empty` | join row 「西湖春日徒步 · 第二场」 + code button | **empty**: join `null`; the code reply is not http(s), so no image |
| `CityFavoriteNodesSection` | `g-city-favorites`, `g-city-favorites-empty` | two nodes, one with an address | **empty**: `[]` → empty text |
| `MerchantCityNodeRow` | `g-merchant-node`, `g-merchant-node-hidden` | node + star; tap → favorited | **hidden**: 404, so no node and no row |
| `AssetCreditText` | `g-asset-credit`, `g-asset-credit-hidden` | 「摄影 · 林夕」 | **hidden**: `{}` (unreviewed), so nothing is drawn |
| `ObjectCardRenameButton` | `g-card-rename`, `g-card-rename-refused` | pencil → alert → saved title `Lamp` | **refused**: 400 「标题不能超过 12 个字」 in the alert |
| `ActivityPublishPrecheckGate` | `g-publish-precheck`, `g-publish-precheck-denied` | 200 → the gated content row | **denied**: 403 → ContentUnavailable 「仅认证发布者可发布活动」 |
| `ClubPostLikeStateButton` | `g-like-state`, `g-like-state-unresolved` | tap → liked | **unknown**: the readback names another post → unresolved |
| `ClubHostRequestButton` | `g-host-request`, `g-host-request-refused` | tap → reread, no message | **refused**: 409 「当前没有可分配的主持人」 |
| `RoamPassportServerSummarySection` (PlayerParityBViews) | `g-passport`, `g-passport-unknown`, `g-passport-failed` | trips 12 / shops 5 / days 9 / 48250 m shown in km to one decimal | **unknown**: null distance and days → em dash. **failed**: the read throws → `RoamExperienceIssue` + retry |
| `SharedRunControlSection` | `g-shared-control`, `g-shared-control-hidden` | RUNNING · ONLINE · epoch 2, 3 teams, 4 stations, offline start, ledger read | **hidden**: 403 `GAME_FORBIDDEN` (not the organiser) → nothing |
| `SharedRunControlEntry` | `g-shared-entry`, `g-shared-entry-hidden` | row into the organiser panel | **hidden**: not the organiser → no row |
| `LeadMemberTicketScanButton` | `g-lead-scan`, `g-lead-scan-hidden` | scan button (the camera sheet needs a device) | **hidden capability**: no `PlayerGapService` → nothing |
| `OrientAlternativeEditorSection` | `g-orient-alt`, `g-orient-alt-unread` | SCAN / QUIZ (on, answer kept) / PHOTO rows; save → readback | **unknown**: `nodeAlternativeConfigsLoaded:false` → `parityB.alt.unread` + reload |
| `CircleThemeHostSection` | `g-circle-host`, `g-circle-host-hidden` | reviewed 2026-11-01 + pick button (opens the sheet) | **hidden**: not the host → nothing |
| `CircleThemeConfigureSheet` | `g-circle-configure`, `g-circle-configure-unsupported` | FITNESS candidates F1–F8, validated before saving | **unsupported**: theme `UNKNOWN` → `parityB.circle.unsupported` |
| `PlayTopicPrepSection` (PlayRuntimeGapViews) | `g-play-prep`, `g-play-prep-failed` | 「开局前准备 · 还有 3 项未勾选」 → sheet with the day window | **failed**: code 500 → 「开局前准备加载失败 · 轻点重试」 |
| `PlayThemeGameplayFlowSection` | `g-play-gameplay`, `g-play-gameplay-overflow` | QUEST_RESOLVE preview, 2 rewards, 4 / 6, confirm on | **overflow**: 8 / 6 → 「容量不足，需调整本次奖励」, confirm off |
| `PlayCoopHelpSheet` (PlayTeamBackpackView) | `g-coop-help`, `g-coop-help-stale` | free text hint, 5-point answer, usable skip; USE → content | **stale**: the quest key is gone → `playTeam.help.stale`; nothing is sent |
| `PlayTeamTradePreviewSheet` | `g-trade-preview`, `g-trade-preview-stale` | give 1 rope → preview ours 0 / 6, theirs 2 / 6 | **stale**: the preview revision is ahead and the reload finds nothing → `playTeam.trade.stale` |

## Not fixtured on this base

**Needs a production seam (BLOCKED for fixture-only work).** These four read `\.playRuntimeGap`, a
`PlayRuntimeGapProduction`. That is a `final class` that builds its client only from a signed-in `AppSession`
(account, token, regional API, `runtimeHTTPTransport`). No fixture path signs an `AppSession` in, so a fixture can
show only the hidden state. A protocol for the binding, or a DEBUG client override, would unblock them.
- `PlayCheckRuntimeSection` (server-rolled check card)
- `PlayContactSection`
- `PlayCompletedHistorySection`
- `PlayTeamBackpackSections`

Also blocked: `RoamActiveOfficialEventDestination` reads `@EnvironmentObject AppSession` (`roamExperienceReader`,
`officialEventReader`).

**Not views (N/A):** `FinishRouteAnalyticsModifier` (a ViewModifier that only tracks), `TeamTrailForegroundRecorder`,
`PlayCircleProduction` / `PlayRuntimeGapProduction` / `PlayRuntimeGapBridge` (composition).

**TODO-after-merge** (the view type is not on this base):
- parity-a (`origin/ui/parity-a` `ba26398e3`): `MPParityPageEntry` (`App/MPParityDeepLinkEntry.swift`).
- cloud-g6 (`origin/ui/cloud-g6` `c76902ef9`, `App/G6CapabilityViews.swift`): `G6PromotionCatalogSection`,
  `G6PromotionCatalogLoader`, `G6RevenueAllocationsEntry`, `G6RevenueAllocationsView`, `G6TopicCharactersSection`,
  `G6TopicCharactersLoader`, `G6RoamNPCPromptModifier`, `G6AIThemeDraftRecoverySection`.
- mount-g45 (`origin/ui/mount-g45` `b554d161c`, `BundleExitSwapView`, `CommunityTrustPlayerViews`,
  `MapSearchPlayerViews`, `PlayerCapabilityHost`): `BundleExitSwapView`, `MerchantSafetySummaryRow`,
  `MerchantCorrectionSheet`, `MerchantSafetyRatingSheet`, `ReportAppealSection`, `SquareMineListView`,
  `MapWeatherOverlay`, `GeocodedAddressButton`, `UnifiedSearchResultsView`, `RoamShopVisitorsStack`,
  `RoamShareRevokeRow`, `SquareMineAccountLinks`, `PublicMerchantTrustSection`, `PlayStoreDaySafetyRatingEntry`,
  `PlayStoreDayGeocodeEntry`, `RoamPlaceVisitorsLine`, `RoamShareRevokeEntry`, `TemplateAdoptEntry`,
  `TemplateLocationTodosEntry`, `MyProjectSaveAsTemplateEntry`, `UnifiedSearchEntry`, `TemplateAdoptButton`,
  `TemplateLocationTodosSection`, `TemplateProjectActions`.

## Gates (this tree)

- `python3 tools/generate_project.py`: 3522 native sources; the only project change is the new fixture file.
- `python3 tools/check_scaffold.py`: PASS.
- `python3 tools/check_design_lint.py`: PASS (no new raw hex, fixed font size or violet).
- `python3 tools/check_design_fixture_release_exclusion.py`: PASS. Release excludes 33 design-fixture sources, and
  the Release projection contains none of the 144 audited symbols.
- `xcrun swiftc -parse -D DEBUG` on the three edited fixture files: clean. This is a syntax check only, and the
  module was not type-checked. Every view initializer the fixtures call is already called the same way from
  production code. The integrator compiles.
