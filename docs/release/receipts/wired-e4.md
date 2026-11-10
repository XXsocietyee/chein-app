# wired-e4 (SL4, ME)

## Part 1 (code read, no local compile; Xcode Cloud verifies)
- Member card (`App/MemberHomeHeader.swift`) at XL (non-AX): stats row and tiles stay HStack; stat labels `lineLimit(1)` + `minimumScaleFactor(0.8)`; AX sizes stack to columns. Acceptable -> 9.
- Creator application (`App/CreatorApplicationView.swift:65`): `creatorApplication.message` row renders only when `message` is non-empty (the empty dark row is gone).
- Login (`App/LoginView.swift`): password form is `#if DEBUG` only; Release `showsPasswordForm == false`, `submit()` guards on it, so Release signs in by phone code / Apple / WeChat only. Phone-code copy (`auth.phone.*`, `auth.channels.*`) matches `docs/auth-channels.md` (6-digit code, 60 s local cooldown, no auto-resend, 5-minute expiry note).

## Part 2 (wiring): PENDING
Core page models (ProfileParticipantListPage, SettingsLegalAgreementPage, DeregisterIndexPageModel, MemberHomePageModel, AccountCollectionFavoritesPageModel, SettingsAboutPageModel, SettingsHomePage, AssetCenterAnalysisPageModel, WalletIncomeDetailPageModel, ProfileInviteHistoryPageReady, OrderInfoPageModel, PointsHistoryPageModel) are not yet in origin/ui/main (checked at d7913357f).

## Part 3
WalletPayoutCapability stays OFF; no money-moving write is enabled.
