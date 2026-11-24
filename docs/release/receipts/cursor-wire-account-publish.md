# cursor/wire-account-publish

Base: `origin/ui/combined-r7` `82388e4a5e7391e0c5a286735d6b30613a860ae8`.

Merged before any wiring edit, in this order:

- `origin/fix/r3-account-publish-b` `a6ac8cb058fde11949090f6cb796c652b35b9faa` (fast-forward).
- `origin/fix/r3-account-publish-a` `75657eb094bbb53b92fd89098317c4795d940a9a`.

The only merge conflict was `App/SessionLocationHoldsSection.swift`. The privacy holds row stays `.cyText(.bodyCompact)` from account-publish b (B-PV-05). Account-publish a and b screen work is otherwise kept. No restyle in this branch.

This VM has no `swiftc`. This receipt does not claim a parse. Tests were not executed.

Not edited: `project.pbxproj`, `tools/current_ci_manifest.json`, money paths, gate defaults. `TeamCommandWriter` is still nil while the player write grant is off, so the recovery buttons do not send until that grant is on.

## Call sites

| What | Where | Wiring |
| --- | --- | --- |
| Drop the deregister phone field | `App/AccountComplianceViews.swift` verify section | Kept from `a6ac8cb05`. There is no phone `TextField`. 获取验证码 calls `sendBoundPhoneSMS(explicitlyRequested:intent:)`. A missing bound phone shows `DeregistrationBoundPhone.missingMessage`; a sent code shows `state.smsNotice`. The code field stays. |
| Switch the consent order | Same file, precheck and both apply buttons | Kept from `a6ac8cb05`. Precheck passes `recordConsent: false`. Both apply buttons pass `recordNoticeConsent: true` and `document?.version`. Step `.blocked` shows the blocker card and does not show the agree control. |
| Refetch settings on appear | `App/SettingsView.swift` `refreshAccountProfile` | On appear, and again when the account id changes, `SettingsAccountProfileClient.refresh(memberID:token:)`. `sessionFact` uses that read. HTTP/business 403 passes `accessDenied: true`. The denied row (`retriesProfileOnTap`) taps the same read and shows `SettingsAccountProfileClient.deniedCopy` / `deniedRetry`. The role card is not painted from the cached session account before this read returns. |
| Open the club manage tab | `App/SettingsAccountEntries.swift` `openClubHost` | `isOffered(toRole:isClubLeader:)` takes `isClubLeader` from `SettingsAccountProfile`. The button calls `SettingsClubHostRouter.resolve` (a second tap is dropped while the read is in flight). `applyForHost` opens host status. `createClub` opens `ClubOperationsWorkspaceView(target: .create)`. `openManage` opens `ClubDetailView` with `requestedTab` `SettingsClubHostRoute.manageTab`. `App/AppSession+MemberPopups.swift` `loadSettingsClubEntry` and `App/AppSession+PopupsClose.swift` still return `SettingsClubPickerOutcome`. |
| Page the cross-club feed | `App/ClubCommunityViews.swift` `ClubCommunityViewModel`; `App/ClubCommunityFixture.swift` | The model keeps a `ClubCommunityFeedCursor`. On `.feed`, `snapshot = try feedCursor.accept`. `canLoadMoreFeed` is `cursor.hasMore` while not loading. The progress row also runs when `clubID == nil`, and `loadMoreFeed` calls `.feed(limit: 20, beforeID:)`. The fixture feed body includes boolean `hasMore`. |
| Show the merchant logo | `App/AccountComplianceViews.swift` `merchantMark` | A non-empty `row.merchantLogo` is the row image. `""` keeps the initial tile. |
| Three team-recovery buttons | `App/TeamHomeView.swift` `teamRecoveryButtons`; writer from `App/SessionTeamViews.swift` | Beside 核对上次操作结果: 查询原请求, 按原输入重试, 终止尚未执行的请求, and `TeamCommandRecoveryCopy.abortNote` (`.caption`). They call `TeamCommandWriter.query`, `submit` (path `api/team/command`, same key and fields captured at confirm), and `cancel`. `checkOutcome()` is unchanged and stays synthetic-only. |

`App/SquareDetailView.swift`, the join ticket CTA, and the A3-01 avatar gate were not touched.

## Strings

`docs/port/strings/cursor-core-account-publish.json` is xcstrings-shaped (`sourceLanguage`, `strings`, `version` `1.0`). All 8 keys have `en` and `zh-Hans`. `Resources/Localizable.xcstrings` was not edited.
