# Receipt: cursor/swift6-app-r4 (Q10)

Base: `origin/ui/combined-r7` at `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (tip unchanged; not rebased).
The warning text below is the diagnostic those declarations still match in Acceptance run `45479937620` `debug-build` (`ci/acceptance` `3aa3fea10074`, before the Q6 annotations). This VM has no `swiftc` or `xcodebuild`. Nothing here was parsed or compiled.

No path string, admit predicate, request body, or gate changed. Forbidden view signatures were not edited. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited.

## Sites

- `App/ClubEnrollmentView.swift`: `@preconcurrency Equatable` and `@preconcurrency Hashable` on `ClubEnrollmentHostContext` (derived `==` reads main-actor `identity` and `profileIdentity`). Left the stored fields, `init`, and `permitsProfile`.
- `App/MerchantNPCTranscriptScroll.swift`: `@preconcurrency Equatable` on `MerchantNPCTranscriptScrollEvent` (derived `==` reads main-actor `scope`). Left `capture`, the policy, and the scroll view.
- `App/NativeWalkingNavigationFactory.swift`: `@preconcurrency Equatable` and `@preconcurrency Identifiable` on `WalkingSavedDestination` (Identifiable crosses the main actor at `id`; derived `==` reads main-actor `record` and `owner`). Left `id`, the stored fields, and the keychain queries.
- `App/TopicDetailView.swift`: copied `pinLine` into `line` before `onGeometryChange` (`pinLine` was read inside that Sendable closure). Left the pin comparison, the `tabsPinned` write, and `onDisappear`.
- `App/ClubProfileMediaEditor.swift`: copied `locale` into `albumLocale` for the `PhotosPicker` label (`locale` was read inside that Sendable closure). Left every other `locale` use, the selection binding, and `permitsAlbum`.
- `App/AuthChannelView.swift`: copied `reduceMotion` into `reduced` for the `keyframeAnimator` content closure (`reduceMotion` was read inside that Sendable closure). Left the scale and animation uses of `reduceMotion`, and the keyframe distances.
- `Core/MerchantMarketingConsentOriginal.swift`: left `nonisolated` on `path` and `resultPath` (the warning was those statics read from a nonisolated context). Left `accepts`, request building, and the path strings.
- `Core/MerchantMarketingConsentScopedTransport.swift`: left `send` and its call to `accepts`. No new annotation.
- `App/MerchantMarketingConsentRuntimeConfiguration.swift`: left `readPaths` reading the already-nonisolated client statics. Left the path set and the write-path check.
- `App/MerchantMarketingConsentSourceSelection.swift`: left the selection, revoke, and default-approval flow. No static was isolated.
- `App/ProjectTopicMediaHost.swift` `ProjectTopicImageCompositionRoute.field`: left the multipart predicate. `Core/ProjectTopicImageUpload.swift` `path` is now `nonisolated` and still `"api/common/uploadOSS"` (that static was main-actor isolated when the nonisolated route read it).
- `App/ProjectNodeImageCompositionRoute.swift`: left the route's own nonisolated `path` copy of `"api/common/uploadOSS"`. Left `Core/ProjectNodeImageUpload.swift` byte-frozen, so its `path` stays main-actor isolated.
- `App/ProjectStoryAudioCompositionRoute.swift`: left `accepts` reading `ProjectStoryAudioUploadClient.path`, already `nonisolated`, still `"api/common/uploadOSS"`.
- `App/ProjectStoryImageCompositionRoute.swift`: left `accepts` reading `ProjectStoryImageUploadClient.path`, already `nonisolated`, still `"api/common/uploadOSS"`.
- `App/ProjectEditCompositionRoute.swift`: left `path`, `isMerchantScoped`, and the request matcher. Those statics are on non-actor contracts, and the admit checks were not edited.
