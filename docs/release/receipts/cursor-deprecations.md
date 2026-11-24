# cursor/deprecations

Base: `ui/combined-r7` `aee32a61f0f69b880bc9e33811463ccc73351bbe`.
Mechanical swaps only. No restyle. `initial` was not set on any `onChange`, so those closures still run only after the value changes. The old single parameter was the new value and is now the second parameter.

The prompt named `CYSpacing.xs`. That member is not deprecated (`xs` is 4pt, `sm` is 8pt). The deprecated token marked `renamed: "sm"` is `CYRadius.xs`, and its value is already `sm` (8pt). Call sites of that alias were updated. The alias declaration in `App/DesignSystem/CYDesignTokens.swift` is unchanged.

## Counts

| Replacement | Replaced | Left |
|---|---:|---:|
| `CYRadius.xs` → `CYRadius.sm` (deprecated alias; prompt said `CYSpacing.xs`) | 23 | 0 call sites |
| `CYSpacing.xs` → `.sm` | 0 | 732 |
| `onChange(of:perform:)` → two-parameter `onChange` | 6 | 0 |
| `NavigationLink(isActive:)` → `navigationDestination` | 0 | 6 |
| `AVAudioSession.recordPermission` → `AVAudioApplication.shared.recordPermission` | 6 | 0 |
| `CLLocationManager.authorizationStatus()` → instance `authorizationStatus` | 0 | 3 |
| `Locale.languageCode` → `locale.language.languageCode?.identifier` | 2 | 0 |
| `kSecUseAuthenticationUIFail` → current keychain constant | 0 | 10 |

## Replaced

### `CYRadius.xs` → `CYRadius.sm` (23)

Same 8pt value. `App/PlayKitQuestoViews.swift` (3), `App/SquareCloudFeedViews.swift` (2), `App/MapPublicLayerCallerView.swift` (1), `App/StoryRuleEditorView.swift` (2), `App/RoamFinishReportView.swift` (2), `App/PassMembershipViews.swift` (1), `App/ModUpgradeView.swift` (1), `App/NativeAttributeAuthorViews.swift` (1), `App/NPCChatDataView.swift` (1), `App/CompleteWave1To3AndReformV9ShowcaseView.swift` (1), `App/PlayKitPersonalForms.swift` (1), `App/DesignSystem/CYSharedStates.swift` (1), `App/DesignSystem/CYSkeleton.swift` (1), `App/DesignSystem/CYMiniParity.swift` (1), `App/DesignSystem/CYMapChrome.swift` (2), `App/DesignSystem/CYSquareActivityPicker.swift` (1), `App/DesignSystem/CYShareComposerState.swift` (1).

### `onChange` (6)

- `App/NativeWebhookInboundLogView.swift` — `filter`
- `App/NativeWebhookDeliveryLogView.swift` — `filter`, `includePayload`
- `App/NativeWebhookSubscriptionEditor.swift` — `draft.replaceURL` (`enabled` stays the new value)
- `App/NativeWebhookManagementEntry.swift` — `scenePhase` (`phase` stays the new value)
- `App/ClubChannelMessagingView.swift` — `viewportState.pendingNewMessageCount`

### `AVAudioApplication.shared.recordPermission` (6)

- `App/ShopNPCVoiceProvider.swift`
- `App/PlayKitNativeSensorProvider.swift` (2: the `.soundPeak` switch and the `startAudio` guard)
- `App/PlayAudioClipView.swift`
- `App/MerchantNPCVoiceDevice.swift`
- `App/IMVoiceDevice.swift`

`requestRecordPermission` was not part of this swap.

### `locale.language.languageCode?.identifier` (2)

- `App/RoamLiveSessionView.swift` — `RoamLiveElapsedCopy.chinese`
- `App/MerchantBusinessRecordViews.swift` — refund-number copy label

Both still mean “language code is `zh`”. `locale.language.languageCode == nil` in `App/BundleOrderStatusView.swift` is already the current API.

## Left

### `CYSpacing.xs` (732)

Every Swift call site. Replacing with `.sm` would double the spacing from 4pt to 8pt.

### `NavigationLink(isActive:)` (6)

`navigationDestination(isPresented:)` on these rows can push a different screen, or none. `App/NativeFriendHomeView.swift` already records that a misplaced `navigationDestination(isPresented:)` never pushes.

- `Tests/AppUnitTests/ProfileFavoriteTopicReadTests.swift:195` — the chapter is a child link, not a replacement root. A stack destination can replace the detail instead of pushing the chapter.
- `App/NativeChannelManagementEntry.swift:14` — `NativeChannelManagementRouteState.binding` owns the visit id. The link is the row. A destination on the row is the misplaced case that does not push.
- `App/NativeChannelManagementViews.swift:119` — onboarding visit inside a `List` section.
- `App/NativeChannelManagementViews.swift:125` — welcome visit in the same section. Two `isPresented` destinations here can show the wrong child.
- `App/NativeChannelManagementViews.swift:325` — message visit inside a `Form`, next to a different conversation link. The child binding must not reopen an ancestor.
- `App/MemberHomeHeader.swift:344` — `earningsBinding` opens one ticket, and the destination reads that ticket. Moving the link can show the unavailable placeholder or the wrong earnings screen. `MemberBenefitsEarningsDestination` only closes the ticket for this link binding.

### `CLLocationManager.authorizationStatus()` (3)

The instance property requires a `CLLocationManager`. Constructing one changes when location authorization callbacks fire. These reads are the path that avoids a manager.

- `App/WalkingForegroundLocationProvider.swift:18` — used only while `manager` is nil. No manager exists until an explicit foreground fix.
- `App/RoamLocationSettingsDestination.swift:19` — read on a background queue. The comment keeps the class method so nothing constructs a `CLLocationManager`.
- `App/CloudB3Production.swift:162` — `PlayEmergencyLocationConformer` returns before creating a manager when status is not already authorized.

### `kSecUseAuthenticationUIFail` (10)

`kSecUseAuthenticationUISkip` is not the same constant: it silently skips items that need UI, and only `SecItemCopyMatching` may use it. `Fail` returns `errSecInteractionNotAllowed`. These dictionaries are also passed to `SecItemAdd`, `SecItemUpdate`, and `SecItemDelete`. The header replacement is `kSecUseAuthenticationContext` with `LAContext.interactionNotAllowed`, which is not a constant swap.

- `Core/ClubProfileLocalDraftStore.swift:198`
- `Core/ContentDraftSystemStorage.swift:46`
- `App/PrivateHomeKeychainJournal.swift:33`
- `App/PrivateHomeKeychainJournal.swift:56`
- `App/NativeWalkingNavigationFactory.swift:176`
- `App/NativeWalkingNavigationFactory.swift:193`
- `Tests/AppUnitTests/PlayRecoverySystemStorageTests.swift:28`
- `Tests/AppUnitTests/PrivateHomeSystemKeychainTests.swift:43`
- `Tests/AppUnitTests/PrivateHomeSystemKeychainTests.swift:57`
- `Tests/AppUnitTests/PrivateHomeSystemKeychainTests.swift:103`
