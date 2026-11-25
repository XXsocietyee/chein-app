# Receipt: cursor/k7e-fixes-2

Parent: `ebf6c160ce73880807c07cf3cc10aa829e83d75e` on `ui/combined-r7`. This branch was cut from that SHA and was not rebased. Check `45557373770` failed to compile two test files. Those sites were still present. The 39 contract-ratchet failures were not touched.

`App/AppSession.swift` and `App/AppCompositionRoot.swift` were not edited. Ceilings were not raised. `Questify.xcodeproj/project.pbxproj` and `tools/current_ci_manifest.json` were not edited. Money stays off. This VM did not run `swiftc` or `xcodebuild`. Nothing here was parsed or compiled.

## Sites

| Site | Change |
|---|---|
| `Tests/CoreTests/ClubPageContractPinTests.swift` `testClubDetailFollowPinsMemberIdAndFollow` | The test is `@MainActor`, the same way neighboring contract tests isolate a synchronous main-actor call. `PlayerGapService.init(baseURL:accountID:token:transport:)` and `makeRequest(_:method:query:json:form:)` are unchanged. The follow request is still POST `api/user/follow/action` with `follow_member_id=42` and `follow=1`. |
| `Tests/CoreTests/ClubPageContractPinTests.swift` `testPlanFallbackSharedControlPinsGetActivityId` | Same `@MainActor` isolation. The shared-control request is still GET `api/game/session/shared/control` with `activityId=91`. |
| `Tests/CoreTests/WiringR6ClientTests.swift:47` | `try` on `XCTUnwrap(request.httpBody)` inside the existing `conversation_id=12` assertion. |
| `Tests/CoreTests/WiringR6ClientTests.swift:48` | `try` on `XCTUnwrap(request.httpBody)` inside the existing `read_to` assertion. |
| `Tests/CoreTests/WiringR6ClientTests.swift:102` | `try` on `XCTUnwrap(request.url)` inside the existing nil-query assertion. |
| `Tests/CoreTests/WiringR6ClientTests.swift:155` | `try` on `Dictionary(uniqueKeysWithValues:)` and on `XCTUnwrap(list.url)`. The query assertion is still `merchantRowId`, `registrationId`, `pageNum`, and `pageSize`. |
| `Tests/CoreTests/WiringR6ClientTests.swift:165` | `body?.keys` is mapped to `[String]` before `Set`, the same way `StoreCharacterTests` compares dictionary keys. The asserted names are still `merchantRowId`, `registrationId`, `rating`, `content`, `imageUrls`, and `requestId`. |
