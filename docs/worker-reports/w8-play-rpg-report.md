# W8 Worker Report — Play: RPG Gameplay Parity, Story Participation & Sandboxed External Game Import

- **Task ID**: `task_85bca69cd6a6` (superseding `task_7b8be173080c`)
- **Branch**: `liboyang42-cpu/w8-play-rpg`
- **Worktree**: `/Users/fanning/orca/workspaces/native-ios/w8-play-rpg`

---

## 1. Mini-Program → Native iOS Parity Map

| Mini-Program Source (`chengyinhub-xcx`) | Native `Core/` Target | Native `App/` Target | Provenance |
|---|---|---|---|
| `pages/publish/fabu/theme-d20.js` (`PRESETS`, `ATTR_PRESETS`, `CLOCK_KINDS`, `ASPECT_PRESETS`, `WINDOWS`, `PREP_SUGGESTIONS`, `read`, `apply`, `setCheckEnabled`, `summary`, `clampAttr`, `newAttr`, `newClock`, `newAspect`, `move`, `playWindowOf`, `setPlayWindow`, `prepOf`, `setPrep`) | `Core/DiceRulesEngine.swift` (`DiceThemeD20Rules`) | `App/DiceD20View.swift` | Ported from mini-program |
| `pages/play/utils/d20-renderer.js` (20-face icosahedron geometry, opposite faces = 21, `orientFace`, `slerp`, dual-dice advantage/disadvantage settle) | `Core/DiceRulesEngine.swift` (`DiceD20Geometry`, `DiceD20RendererState`) | `App/DiceD20View.swift` (`DiceD20CanvasView`), `App/PlayJourneyContentViews.swift` | Ported from mini-program |
| `pages/play/components/playkit-diceroll/index.js`, `playkit-journey-check/index.js`, `playkit-view.js`, `advanced-game-config.js`, `game-preview-action.js` | `Core/DiceRulesEngine.swift` (`DicePlaykitRules`, `DiceD20TemplateValidator`, `DiceJourneyCheckRules`) | `App/DiceD20View.swift`, `App/PlayJourneyContentViews.swift` | Ported from mini-program |
| Deterministic seeded D20 check engine (`DiceSeededRNG`, `DiceCheckEngine`) | `Core/DiceRulesEngine.swift` (`DiceSeededRNG`, `DiceCheckEngine`) | `App/DiceD20View.swift` | `DESIGNED` (supplements server receipt flow with deterministic local preview & unit-testable PRNG) |
| `subpackageMember/character/index.js`, `utils/user-character.js` (`levels`, `stars`, `percent`, `scopeText`, `rpgSheet` momentum/clocks/facets/aspects, `registrationTopic`, `hasTopicRelation`, `failure`) | `Core/CharacterSheetRules.swift` (`CharacterCardAttribute`, `CharacterRpgSheet`, `CharacterCard`, `CharacterSheetPresenter`) | `App/CharacterSheetDetailView.swift`, `App/CharacterCardReadbackView.swift` | Ported from mini-program + existing native `CharacterCardReadback` |
| `pages/play/utils/theme-gameplay.js`, `theme-rewards.js`, `theme-trade.js`, `theme-player-ops.js`, `theme-backpack.js`, `theme-plans.js` | `Core/PlayThemeGameplay.swift` (`PlayThemeGameplayRules`, `PlayThemeRewardsRules`, `PlayThemeTradeRules`, `PlayThemePlayerOpsRules`, `PlayThemeChallengeRules`, `PlayThemePlansRules`, `PlayThemeGameplayCoordinator`) | `App/PlayThemeBackpackView.swift` | Ported from mini-program |
| `pages/play/poi-challenge/index.js` & `index.wxml` (`loading \| photo \| quiz \| done \| error`, `PREWRITE_REJECTIONS`, Haversine `<= radiusM + 30`, medal & `alreadyClaimed`) | `Core/ChallengePOI.swift` (`ChallengePOINode`, `ChallengePOIRules`, `ChallengePOICoordinator`) | `App/ChallengePOIView.swift` | Ported from mini-program |
| `pages/play/recap.js` (`buildPlayRecap`) | `Core/PlayRecap.swift` (`PlayRecapRules`) | Integrated into Play recap flow | Ported from mini-program |
| `utils/publish/story-rule-sentence.js`, `story-rule-form.js`, `pages/publish/components/story-rule-editor/index.js` | `Core/StoryRuleSentence.swift` (`StoryRuleSentenceEngine`, `StoryRuleEditorModel`) | `App/StoryRuleEditorView.swift` (`StoryRuleEditorView`) | Ported from mini-program |
| `pages/topic/components/project-join/index.js`, `pages/club/topic-story/index.js`, `subpackageA/pages/myproject/index.js` | `Core/StoryParticipation.swift` (`StoryProjectJoinState`, `StoryClubTopicRules`, `StoryParticipationCoordinator`) | `App/StoryRuleEditorView.swift` (`StoryParticipationView`) | Ported from mini-program |
| External game package import, manifest & signature validation, sandboxed `WKWebView` runtime, local sandbox store | `Core/ExternalGameImport.swift` (`ExternalGameManifest`, `ExternalGamePackageArchive`, `ExternalGameValidator`, `ExternalGameSandboxPolicy`, `ExternalGameBridgeHandler`, `ExternalGameStore`) | `App/ExternalGameImportView.swift` (`ExternalGameLibrarySection`, `ExternalGamePermissionConfirmationSheet`, `ExternalGameSandboxedWebView`), hosted inside `.game` tab of `App/PlayThemeBackpackView.swift` | `DESIGNED` (confirmed no external game import exists in `chengyinhub-xcx`) |

---

## 2. Priority 3 — External Game Import (`DESIGNED`) & App Store Review Implications

### 2.1 Architecture Summary (`DESIGNED`)
1. **Placement**: Hosted inside the existing Play backpack `.game` tab (`App/PlayThemeBackpackView.swift` via `ExternalGameLibrarySection`), avoiding any new top-level navigation tab or page.
2. **Import Channels**: Supports importing a game package archive (`ExternalGamePackageArchive`) via HTTPS URL, QR code payload, or local file picker / share sheet.
3. **Strict Manifest & Package Validation (`ExternalGameValidator`)**:
   - Required fields: `id` (`^[a-zA-Z0-9._-]{3,64}$`), `name`, `version` (semver), `entry` (relative `.html` path), `permissions` (subset of `storage`, `haptics`, `audio`, `dice`), `contentRating` (`4+`, `9+`, `12+`, `17+`; `18+`/`adult`/`nsfw` rejected), `allowedDomains` (HTTPS hostnames only, no wildcards `*`), `sha256` (64-char hex digest of entry/files), and `signature` (HMAC-SHA256 / Ed25519 signature verified against trusted public keys).
   - Rejects path traversal (`..`, leading `/`, `\`, `:` or URL schemes in `entry` or archive file paths).
   - Rejects packages exceeding 10 MB (`maxPackageBytes = 10 * 1024 * 1024`).
   - Rejects forbidden permissions (`payment`, `iap`, `native_exec`, `contacts`, `camera`, `location_background`, `bluetooth`, `microphone`, `photos_write`).
   - Scans HTML/JS content for forbidden payment/IAP/eval patterns (`applepay`, `storekit`, `wx.requestpayment`, `alipay`, `eval(`, `new function(`).
4. **User Confirmation Sheet (`ExternalGamePermissionConfirmationSheet`)**:
   - Displays package name, version, source URL/QR/file origin, SHA-256 fingerprint, content rating badge, requested permissions, and allowlisted HTTPS domains before installation or execution.
5. **Sandboxed `WKWebView` Runtime (`ExternalGameSandboxedWebView` & `ExternalGameBridgeHandler`)**:
   - Uses `WKWebsiteDataStore.nonPersistent()` for ephemeral web storage isolation.
   - Injects a strict Content-Security-Policy (`default-src 'self' blob: data:; connect-src <allowlisted-https-domains>; object-src 'none'; frame-src 'none'`).
   - Blocks all navigation outside the package sandbox directory and the manifest's `allowedDomains` (HTTPS only).
   - Exposes only the versioned `questifyPlaykitBridge` (`v1`) message handler supporting `getInfo`, `rollDice`, `getStorage`, `setStorage`, and `haptic`, gated by the manifest's declared `permissions`.
6. **App Sandbox Persistence (`ExternalGameStore`)**:
   - Stores installed packages in an isolated directory (`Application Support/ExternalGames`), supporting list, install, update (preserving per-game `scopedStorage`), and remove.

### 2.2 App Store Review Guidelines Assessment

1. **Guideline 4.7 (Mini Apps, Mini Games, Streaming Games, Chatbots, Plug-ins, and Game Emulators)**:
   - **4.7.1 (HTML5 / JS Execution & No Native API Extension)**: Imported games run strictly as standard HTML5/JS inside a non-persistent `WKWebView` with a fixed, allowlisted `v1` bridge (`rollDice`, `haptic`, 64 KB key-value `storage`). Imported packages cannot access private APIs, arbitrary native frameworks, or extend native app capabilities.
   - **4.7.2 & 4.7.3 (Content Moderation, Age Rating & Privacy Disclosure)**: Every package requires an explicit `contentRating` (`4+` to `17+`, rejecting `18+`/NSFW) and cryptographic signature verification (`signature` + `sha256`). Before launching or installing any package, `ExternalGamePermissionConfirmationSheet` discloses the source, age rating, permissions, and network domains. **Coordinator Decision Needed Before Release**: Decide whether production builds restrict `trustedVerifyKeys` to official Chengyin-signed game packages only (recommended for initial App Store submission to avoid unmoderated third-party code execution) or integrate server-side review/signing before issuing package signatures.
   - **4.7.4 & 3.1.1 (In-App Purchase & Payments)**: `ExternalGameValidator` explicitly rejects any `payment`/`iap` permission and blocks HTML/JS bundles referencing `StoreKit`, `ApplePay`, `wx.requestPayment`, or external checkout flows. Imported games are free companion playkits and cannot sell digital goods or bypass StoreKit.

2. **Guideline 1.2 (User-Generated Content — UGC)**:
   - If users can share custom game packages via URL or QR code, Apple treats those packages as UGC.
   - To comply with Guideline 1.2:
     - Packages must be signed by the backend after automated + human moderation, or users must have an in-app **"Report / Block Game Package"** action that revokes the package ID via backend blocklist.
     - Age ratings above the host app's rating must be rejected at validation time.

3. **Guideline 5.1.x (Privacy — Data Collection and Storage)**:
   - **5.1.1 & 5.1.2 (Data Minimization & Purpose)**: Imported games run in `WKWebsiteDataStore.nonPersistent()` and have zero access to the user's authentication token, device identifiers, contacts, photos, or location.
   - The `questifyPlaykitBridge` (`v1`) never exposes `PlayExperienceSession.token`, user ID, or personal profile data to the `WKWebView`. Network connections (`connect-src`) are restricted to HTTPS domains explicitly declared in `allowedDomains` and approved by the user on the confirmation sheet.

---

## 3. Verification & Test Suite Results

- **Contract Check**:
  - `python3 -m unittest Tests/ContractChecks/test_personal_theme_backpack_contract.py` → **29 tests passed**.
- **Swift Package Unit Tests (`Tests/CoreTests/`)**:
  - `DiceRulesEngineTests`: Deterministic SplitMix64 `DiceSeededRNG`, `DiceThemeD20Rules`, `DiceD20Geometry` (icosahedron opposite faces sum to 21, quaternion slerp), `DicePlaykitRules`, `DiceD20TemplateValidator`, `DiceJourneyCheckRules`, `DiceCheckEngine`.
  - `StoryRuleSentenceTests`: `StoryRuleSentenceEngine` (`story-rule-sentence.js` parity), `StoryRuleEditorModel` (`story-rule-form.js` parity), `StoryProjectJoinState`, `StoryClubTopicRules`, `StoryParticipationCoordinator`.
  - `ExternalGameImportTests`: Rejects path traversal (`../`), oversized packages (`>10MB`), unsigned/tampered SHA-256 or signature, wildcard/non-HTTPS domains, forbidden payment/IAP permissions and scripts; verifies sandboxed store install/update/remove and `v1` bridge permission gating.
  - `RpgGameplayParityTests`: `PlayThemeGameplayRules`, `PlayThemeTradeRules`, `PlayThemeChallengeRules`, `PlayThemePlansRules`, `PlayThemeGameplayCoordinator` (`ARRIVAL_ISSUE`, `MANUAL_SIGN`, `TEAM_EXIT`, `authorityEpoch` conflict & `PENDING` receipt lock), `ChallengePOICoordinator` (Haversine `<= radiusM + 30`, `PREWRITE_REJECTIONS`, medal & `alreadyClaimed`), `PlayRecapRules`, and `CharacterCard` / `CharacterSheetPresenter`.
  - Existing `CharacterCardReadbackTests`, `PlayThemeBackpackTests`, `PlayGameSessionCompositionTests`.
