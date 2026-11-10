# wired-e4 (SL4, ME)

## Part 1 (code read, no local compile; Xcode Cloud verifies)
- Member card (`App/MemberHomeHeader.swift`) at XL (non-AX): stats row and tiles stay HStack; stat labels `lineLimit(1)` + `minimumScaleFactor(0.8)`; AX sizes stack to columns. Acceptable -> 9.
- Creator application (`App/CreatorApplicationView.swift:65`): `creatorApplication.message` row renders only when `message` is non-empty (the empty dark row is gone).
- Login (`App/LoginView.swift`): password form is `#if DEBUG` only; Release `showsPasswordForm == false`, `submit()` guards on it, so Release signs in by phone code / Apple / WeChat only. Phone-code copy (`auth.phone.*`, `auth.channels.*`) matches `docs/auth-channels.md` (6-digit code, 60 s local cooldown, no auto-resend, 5-minute expiry note).

## Part 2 (wiring, merged origin/ui/main d7913357f; no local compile)
| page | view | model call | status |
| --- | --- | --- | --- |
| pages/address | App/ProfileParticipantsView.swift | `ProfileParticipantListCoordinator.project(list:)` -> `phase` for empty state, `ProfileParticipantListCard.phoneText` (em dash for blank phone) | wired (reader gives no total, so no total shown) |
| pages/shezhi/shezhi | App/SettingsView.swift | `SettingsHomePage.marketText` for the market row | wired (market row only) |
| pages/shezhi/about | App/SettingsAboutView.swift | `SettingsAboutPageModel(information:market:)` -> `version.text`, `build.text`, `contactPhone`; `SettingsHomePage.marketText` | wired |
| pages/deregister | App/AccountComplianceViews.swift | `DeregisterIndexPageModel.statusText` for the server status fallback (em dash for unknown) | wired (status mark only) |
| pages/member/index | App/MemberHomeHeader.swift | `MemberIdentitySnapshot.friendCountText/followCountText/fansCountText` and `MemberHomePageModel.unknownDisplay` (was raw Int, so an unready counter could show 0) | wired (stats row only) |
| pages/mylike | App/AccountCollectionFavoritesView.swift | `AccountCollectionFavoritesPageModel.resolvePosts` needs the raw payload `Data`; reader returns decoded `TopicSummary` with count already coerced to 0 | NOT wired: needs a Core reader change |
| assetcenter/analysis | App/WalletIncomeAnalysisView.swift | `AssetCenterAnalysisPageModel(rows:)` | NOT wired: the view has its own per-month presentation; swapping would change the layout |
| assetcenter/income-detail | App/WalletCommerceViews.swift | `WalletIncomeDetailPageModel.money` | NOT wired: the detail sheet shows no separate amount surface |
| pages/agreement | App/SettingsLegalDocumentView.swift | `SettingsLegalAgreementPage` | NOT wired: type is missing from Core. CB524 (c5150bf32) added it to `Core/SettingsIdentityApplications.swift` but a later change to that file dropped it, while `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` still references it |
| myinvite | App/SocialInviteHistoryView.swift | `ProfileInviteHistoryPageReady` | NOT wired: type does not exist anywhere in the tree |
| orderinfo | App/OrderLifecycleView.swift | `OrderInfoPageModel` | NOT wired: type does not exist anywhere in the tree |
| points-history | App/ProfileWeeklyPointsSection.swift | `PointsHistoryPageModel` | NOT wired: type does not exist anywhere in the tree |

## Part 3
WalletPayoutCapability stays OFF; no money-moving write is enabled.
