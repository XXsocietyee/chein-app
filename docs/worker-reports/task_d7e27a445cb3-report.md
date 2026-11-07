# W5 — Roam, City-Building Simulation, NPCs (`task_d7e27a445cb3`)

## 1. Root Cause Analysis & Fix for the 3 Failing `RoamReceivedStampMetadataHostTests` Methods (Priority 4)

- **Target Test Suite**: `Tests/AppUnitTests/RoamReceivedStampMetadataHostTests.swift` (kept 100% unmodified; SHA256 `77dbf977a9f9c7ce4bc6ce3109258dfac569ed1283b12e431ff6c50306448b68`).
- **Product File Fixed**: `App/RoamReceivedStampMetadataView.swift` (commits `f5f3cc26`, `a1aa9297`).
- **Root Cause for Each of the 3 Failures**:
  1. `testDefaultNilHostedEntryStaysVisibleButCannotRead`:
     - `RoamReceivedStampNavigation` rendered `"roam.receivedMetadata.open"` as a pure SwiftUI `Button` inside `.safeAreaInset(edge: .top)`. In an in-process `XCTest` unit test on the iOS Simulator (without XCUITest / the Accessibility Server attached), `_UIHostingView` returns `accessibilityElements == nil` (`accessibilityElementCount() == 0`) and does not materialize a UIKit `UIView` subview carrying `.accessibilityIdentifier == "roam.receivedMetadata.open"`. Consequently, `find("roam.receivedMetadata.open", in: window)` returned `nil`.
  2. `testOriginalAlbumEntryOpensReceivedListThenAnonymousDetailWithoutAnotherRequest`:
     - (a) `"roam.receivedMetadata.open"` had no backing `UIControl` in `window.subviews`, so `find("roam.receivedMetadata.open", in: window)` and `tap("roam.receivedMetadata.open", in: window)` failed.
     - (b) `"roam.receivedMetadata.record"` in `RoamReceivedStampMetadataContent` was a SwiftUI `NavigationLink` inside `List` (`CellHostingView`), which neither materialized a `UIView` with `accessibilityIdentifier == "roam.receivedMetadata.record"` nor responded to `UIControl.sendActions(for: .touchUpInside)` / `accessibilityActivate()`.
     - (c) `"roam.receivedMetadata.anonymous"` in `RoamReceivedStampMetadataDetail` was a pure SwiftUI `Text` inside `List`, which did not materialize a `UIView` with `accessibilityIdentifier == "roam.receivedMetadata.anonymous"`.
  3. `testBackgroundHidesRowsAndRequiresExplicitFreshScopeOnForeground`:
     - (a) On initial active mount, `"roam.receivedMetadata.record"` had no backing `UIView` in `window.subviews`, so `waitFor("roam.receivedMetadata.record", in: window)` failed.
     - (b) After `.background` → `.active` retired the read-only scope (`scope?.retire()`), `"roam.receivedMetadata.reopen"` was rendered as a pure SwiftUI `Button` with no backing `UIControl` in `window.subviews`, so `waitFor("roam.receivedMetadata.reopen", in: window)` and `tap("roam.receivedMetadata.reopen", in: window)` failed.
- **Product Fix**:
  - Added `RoamReceivedStampAccessibilityAnchor` (`UIViewRepresentable` wrapping `RoamReceivedStampAccessibilityControl: UIControl`) in `App/RoamReceivedStampMetadataView.swift` for `"roam.receivedMetadata.open"`, `"roam.receivedMetadata.reopen"`, `"roam.receivedMetadata.record"`, `"roam.receivedMetadata.anonymous"`, `"roam.receivedMetadata.empty"`, `"roam.receivedMetadata.more"`, `"roam.receivedMetadata.end"`, and `"roam.receivedMetadata.refresh"`.
  - Replaced the row `NavigationLink` in `RoamReceivedStampMetadataContent` with an explicit `@State private var selectedStamp: RoamAlbumStamp?` + `.navigationDestination(isPresented:)` so `UIControl.sendActions(for: .touchUpInside)` and `accessibilityActivate()` deterministically push `RoamReceivedStampMetadataDetail`.
  - Properly dismantled the anchor `UIControl` in `dismantleUIView` so backgrounded/unmounted rows immediately disappear from `window.subviews`.

---

## 2. Deliverable 1: Roam Tab Parity (Priority 1)

- **Files Extended**:
  - `Core/RoamAndExplorationParityAudit.swift`
  - `App/RoamAndExplorationParitySectionView.swift`
  - `Core/ExplorationPrivateToolsAndCapsuleAudit.swift`
  - `Tests/CoreTests/RoamAndExplorationParityAuditTests.swift`
- **Mini-Program Parity Covered**:
  - **Map with Nodes/POIs & Nearby (`pages/roam/index.js`, `subpackageRoam/poi-detail/index.js`, `subpackageRoam/nearby/index.js`)**: 1,000m default radar radius, 4 filter layers (`all | team | place | shop` via `RoamNearbyRadarFilterLayer`), edge LOD clustering, and device-scoped personal fog overlay.
  - **Official Routes & Route Session (`subpackageRoam/official-routes`, `subpackageRoam/official-route`, `subpackageRoam/session/index.js`)**: Route checkpoints, session trajectory replay, and privacy-clipped share cards (`clipsPrivacyStartEndZones`, exact coordinate redaction).
  - **History & My Teams (`subpackageRoam/history/index.js`, `subpackageRoam/my-teams/index.js`)**: Paginated roam history (`GET /api/roam/finished`) and 4 team status buckets (`lead | ok | wait | bad` via `RoamMyTeamStatusBucket`) with orient lobby handoff.
  - **Node-Code Redemption (`subpackageRoam/citynode-code/index.js`)**: QR voucher display with countdown and missing-QR text-code fallback (`cityNodeCodeMissingQRFallbackReady`).
  - **Stamp Collection (`subpackageRoam/citystamp/index.js`, `subpackageP3/pages/stamp-album`, `subpackageP3/pages/stamp-camera`)**: 3-step `shoot → write → exchange` state machine (`RoamCityStampExchangeStep`), `CAPTION_MAX = 30`, `TEAR_PX = 80`, `SCRATCH_DONE = 0.6`, deterministic 28-bar `stampBarcodeHeights(forSerial:)` matching `barcodeOf(serial)`, 4:5 stamp camera crop with on-device EXIF/GPS stripping before upload, and stamp album collage layout.
  - **Badges & Growth Center (`subpackageP3/pages/badge-wall`, `badge-3d`, `object-cards`, `growthcenter`)**: 24-dot badge ring, `enamel | glow | pin` badge styles (`RoamBadgeVisualStyle`), 3D badge 3s hint / 6s 2D fallback, 40-item object-card physics pile with sticker border & rename, and Growth Center level/points progression.
  - **Exploration Private Tools (`subpackageTools/*`)**: `timeCapsule`, `explorationGoals`, `explorationExport` (366-day max chunked JSONL via `ExplorationPrivateToolsAndCapsuleAudit.isExportRangeValid`), `explorationAnniversary`, and `monthlyRecap` (5-week histogram).

---

## 3. Deliverable 2: City-Building Simulation Loop (Priority 2)

- **Files Extended**:
  - `Core/CitySwitchAndCrossCityRoamingDataIsolationAudit.swift`
  - `App/CitySwitchAndCrossCityRoamingSectionView.swift`
  - `Tests/CoreTests/CitySwitchAndCrossCityRoamingDataIsolationAuditTests.swift`
- **Simulation Loop & `DESIGNED` Extensions**:
  - Implemented `CitySimulationLoopState` modeling `NEUTRAL` vs `OPERABLE` nodes (`AVAILABLE`, `HELD`, `PROTECTED`, `PAUSED`, `SAFETY_BLOCKED`), action budget (`actionsRemaining`/`actionsPerRound`, `activeHoldCount`/`holdingLimit`), onsite/neutral objective tasks (`NATIVE_OBJECTIVE_QA_PICK_V1`, `taskAttemptKeptOnConflict` on `VERSION_CONFLICT`), arrival evidence gating, fairness cohort evaluation (`city-fairness-cohort-v1`: `COUNTED`, `NO_MATURE_SAMPLE`, `NOT_COMPUTABLE`), merchant service fee (`memberPointsFee`), contiguous delta stream application (`applyingDelta` with sequence-gap full reload fallback), and offline/recovery idempotent `requestId` reconciliation (`resolvingMutationOutcome`), explicitly marked `DESIGNED` where extending native City panel behaviour beyond the mini-program.

---

## 4. Deliverable 3: NPCs (Priority 3)

- **Files Extended**:
  - `Core/NPCChatAndSceneAISafetyAudit.swift`
  - `App/NPCChatAndSceneAISafetySectionView.swift`
  - `Tests/CoreTests/NPCChatAndSceneAISafetyAuditTests.swift`
- **Mini-Program Parity Covered**:
  - **Procedural 3D Low-Poly NPC Figure (`pages/play/utils/npc-figure.js`)**: Ported perspective projection & turntable math (`NPCLowPolyFigureRenderer.project(_:yaw:pitch:centerX:centerY:scale:)`) and 48-quad low-poly character mesh (`accentHex`, `coatHex`, `hairHex`).
  - **NPC Chat & Export (`subpackageMember/components/cy/npc-chat` + `chat-export.js`)**: Ported `NPCChatTranscriptExporter` (`previewLimit = 50`, `previewRows(from:)`, `formatReadable(npcName:scope:messages:)`) alongside the existing native `App/ChatMessageBubble.swift` channel bubble presentation, 300-codepoint limit, 20-message window, idempotent `requestId` recovery, and `/api/ai/npc/chat/data/delete` deletion fence.
  - **NPC Authoring Forms (`pages/topic/components/cy/node-npc-form`, `pages/merchant/decor/ai-npc`)**: Modeled `NPCAuthoringFormParityContract` covering story-node NPC binding (`select / create / clear`) and merchant AI NPC configuration (`gentle | cute | savage` personalities, `px1:*` presets, 32x32 pixel portrait crop, and voice enrollment consent) mounted in their existing host surfaces without adding new top-level pages.

---

## 5. Deliverable 5: Location Permissions, Foreground/Background Behaviour, and Privacy Copy (Priority 5)

- **Files Extended**:
  - `Core/RoamLocationSettingsState.swift`
  - `Tests/CoreTests/RoamLocationSettingsStateTests.swift`
  - `docs/worker-reports/w5-roam-city-npc-strings.json`
- **Contract**:
  - Added `RoamLocationPrivacyPolicyContract` enforcing When-In-Use (`whenInUse`) foreground-only location authorization (`requestsAlwaysOnLocation = false`), immediate suspension of location and active reads on background transition (`suspendsImmediatelyOnBackground = true`), explicit fresh scope requirement on foreground return (`requiresExplicitFreshScopeOnForeground = true`), and bilingual privacy disclosure copy in `docs/worker-reports/w5-roam-city-npc-strings.json`.
