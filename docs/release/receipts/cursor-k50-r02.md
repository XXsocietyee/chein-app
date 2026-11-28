# K50-R2 · App Store review

Branch `cursor/1128-k50-r02` from `origin/ui/combined-r7` @ `d5702393c`. Base for the PR is `ui/combined-r7`. Checks: account deletion, Sign in with Apple parity (Guideline 4.8), UGC report/block (Guideline 1.2), the 18+ age rule, the privacy manifest against code that actually collects data, and permission purpose strings.

No legal sentence was written. Existing agreement text, the pinned blocked-row title, and the purpose strings already in `Config/Base.xcconfig` were the only copy used. `App/AppSession.swift` stays 7976 lines (ceiling 7977). `App/AppCompositionRoot.swift` stays 4173. Play configuration init order is still `devices`, `sensors`, `artworkHosts` (`App/ReviewedPlayerWriteLeases.swift`). No `String(localized:)`. `PlayerLaunch.merchantCenterEnabled` stays `false` outside DEBUG/TEST. Money switches were not edited. No `xcodebuild`.

Counts: **27** checks. **12** matches. **7** fixed. **8** owner-only.

| # | Check | Status | What was found |
|---|---|---|---|
| 1 | Account deletion on the reviewed China deployment | matches | Settings uses `AccountComplianceSettingsSection` when the coordinator exists. Precheck, notice, proof, apply, and sign-out are the same sheet. Apply stays behind `productionGatesEnabled` and market China. |
| 2 | Sign in with Apple accounts can delete (5.1.1(v)) | matches | `verificationMethod == APPLE` shows `DeregistrationAppleReauthSection`. Apply sends `identityToken` and `authorizationCode` and does not send `smscode`. |
| 3 | Phone accounts still delete with SMS | matches | The verify step sends a code to the bound phone and posts that code only. An Apple proof is not attached. |
| 4 | Unconfigured composition does not call apply | matches | A nil coordinator still opens `SettingsUnavailableFeatureView` for account deletion, including the cancellation notice. The checker does not request `api/user/deregister/apply`. |
| 5 | Blocked-row English title | fixed | `settingsNative.blocked.accountDeletion.title` was `Account` while zh-Hans stayed `账号注销`. Restored the pinned English `Account cancellation`. The refusal message was already intact. |
| 6 | WeChat-only accounts on iOS | owner-only | The app still shows the mini-program verification screen. An Open Platform code cannot satisfy mini-program `jscode2session`. No new proof was invented. |
| 7 | Revoke the Apple authorization code | owner-only | The app already sends `authorizationCode`. Exchange and `/auth/revoke` need the Sign in with Apple key on the server, not in git. |
| 8 | `tools/check_account_deletion_path.py` host assertions | owner-only | After the title restore, the script still fails because `Config/UnitedStates.Production.xcconfig` names the reviewed China host (one-app pin). That host was not emptied. |
| 9 | WeChat cannot appear unless Sign in with Apple is approved | matches | `weChatSignInApproved` is `appleSignInApproved`. `WeChatAppLaunch.gate` still requires `appleAlternative`. A gated channel draws nothing. |
| 10 | Sign-in order on the US storefront | fixed | `LoginView` branched on `operationalMarket`. The shipped composition pins that market to China for both storefronts, so a US storefront got the China order. Order now follows `storefrontMarket` (China: WeChat, phone, Apple; otherwise Apple, then phone). The Apple approval gate is unchanged. |
| 11 | Apple control itself | matches | System `SignInWithAppleButton`, shown only when `appleConfigurationVerified` and a sign-in service exist. Without the agreement, a tap opens the agreement sheet and does not start authorization. |
| 12 | Sign in with Apple on the App ID | owner-only | `Config/Questify.entitlements` is `com.apple.developer.applesignin` = `[Default]`. The portal switch is not in the tree. |
| 13 | UGC surfaces already in the 1.2 matrix | matches | Report and block stay on square, topics, activities, club posts and channels, IM, profiles, avatars, templates, merchant reviews, teams, external games, and workshop mods. `Tests/ContractChecks/test_ugc_1_2_completeness.py` still requires those routes in both grant lists. |
| 14 | Place player reviews | fixed | `api/comment/list` owner type 4 rows in `RoamPlaceExtrasSection` had no report or block. Each card now uses `UGCReviewSafetyFooter` (`.comment`, `api/comment/report`) and `UGCBlockedFilterContainer`. `memberID` is carried from the comment row. |
| 15 | UGC policy, objectionable-content rules, moderation SLA, named reviewer | owner-only | `docs/release/support-playbook.md` still has `[UGC_POLICY_PLACEHOLDER]`. No policy sentence was added. |
| 16 | 18+ rule already in the China agreement | matches | User agreement section 十 says the service is not for anyone under 18. The consent gate opens that document. The mini program has no separate age screen. `WP04OwnerDecisionGuardTests` forbids client age flags (`isAdult`, `birthDate`, and the same family). No gate was added. |
| 17 | Age-assurance screen, US legal text, App Store age questionnaire | owner-only | US-market legal text is still `.regionalTextNotProvided`. A birthdate gate would collect a new data type and invent a flow. The questionnaire is filled in App Store Connect. |
| 18 | Collected types that were already declared | matches | Phone, name, email, physical address, precise location, photos or videos, audio, other user content, user ID, device ID, purchase history, fitness, search history, gameplay content, customer support, and other data types (resident ID) still match the evidence in `Tests/ContractChecks/test_privacy_manifest_contract.py`. Each stays linked, not tracking, purpose App Functionality. |
| 19 | Product interaction | fixed | `AnalyticsEventClient` posts allow-listed events to `api/analytics/events/batch` with `actorScope` `member:<account id>` and an empty `anonymousId`. That type was missing from `Resources/PrivacyInfo.xcprivacy`. It is now declared: linked, not tracking, App Functionality. |
| 20 | AR world tracking | matches | `PlayKitSpatialRevealView` uses `ARSession` on device and does not upload a mesh. No surroundings type was added. |
| 21 | Tracking and required-reason APIs | matches | `NSPrivacyTracking` is false and tracking domains are empty. User Defaults `CA92.1` and `1C8F.1`, file timestamp `C617.1` and `3B52.1`, system boot time `35F9.1`. No disk-space or active-keyboard use. `tools/check_privacy_manifest.py` passes (17 collected types). |
| 22 | Nutrition labels in App Store Connect | owner-only | Not filed from this repo. `docs/release/app-privacy-answers.md` now lists Product Interaction and notes that the older English sentence saying `1C8F.1` is undeclared is stale. |
| 23 | Store listing says location is foreground-only | owner-only | `docs/release/app-store-pack.md` still says the app never tracks in the background. The purpose string and `UIBackgroundModes` (`audio`, `location`) describe a roam or orienteering run the person started. That listing is owner copy and was not rewritten. |
| 24 | Location, motion, and photo purpose strings | matches | Location names when-in-use use plus background recording during a roam walk or city orienteering run the person started, and says location is not shared with other players. Motion names step counts. Photo-library add names saving a walk card, medal card, or stamp slip. Full-library read stays out; picks use the system picker. |
| 25 | Microphone purpose string | fixed | The prompt named voice messages, NPC voice, and sound-peak measurement. It did not name recording a role's voice in the story editor (`ProjectEditCastVoiceRecorder`, uploaded when the take is kept) or a play-task audio clip (`audio_clip`, uploaded on submit). Both are now in the English xcconfig string and in en and zh-Hans in `Resources/InfoPlist.xcstrings`. Sound-peak measurement is still described as on-device, with no upload. |
| 26 | Camera purpose string | fixed | The prompt did not name a live photo for a place claim (`CityCameraCapture`). That use is now in the same English string, both catalog locales, and the in-app camera primer, which stays the same sentence as the system prompt. |
| 27 | Location primer vs the system prompt | fixed | `CYPermissionPrimerContent.locationPriming` said a chosen person receives the location. Personal sharing has no installed approval (`installReviewedPersonalLocationShareApprovals` has no caller), and the system prompt says location is not shared with other players. The primer body is now that system sentence in both languages. |

## Gates

- `python3 tools/check_scaffold.py` PASS
- `python3 tools/check_a11y_lint.py` PASS (0 new)
- `python3 -B tools/contract_ratchet.py --check` — 46 failing, baseline 46, new 0
- `python3 tools/check_appsession_ratchet.py` PASS (7976 / ceiling 7977)
- `python3 tools/check_privacy_manifest.py` PASS (17 collected types)
- `python3 tools/check_design_consistency.py` PASS
- Contract tests for the privacy manifest, purpose strings, auth entry order, WeChat gate, and UGC surfaces: OK
- No Swift toolchain in this environment, so XCTest was not run and `xcodebuild` was not run
