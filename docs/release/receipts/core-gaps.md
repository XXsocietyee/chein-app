# core-gaps

Branch `ui/e1`. Pure Core and Core tests. No route, capability or safety switch changed. `ReleaseMoneyWriteSwitch` stays all false. `reviewed` stays nil logic. `WalletPayoutCapability` stays off. `WelcomeView.showsMerchantChoice` stays false. Not compiled here: the integrator runs `xcodebuild` and the tests.

| item | state |
| --- | --- |
| `SettingsLegalAgreementPage` (+ `SettingsLegalAgreementFixtureData`, DEBUG) | restored from 3eb64f029 into `Core/SettingsIdentityApplications.swift`, with `docs/release/ui-strings-pages-agreement-index.json`. The existing `SettingsLegalAgreementPageTests` and `test_pages_agreement_index.py` read it again. `api/agreement/get` stays hidden. |
| `ProfileInviteHistoryPageReady` | new, `Core/ProfileInviteHistoryPageReady.swift`. `phase(loading:error:pagination:scan:)`. Missing total is an em dash. |
| `OrderInfoPageModel` | new, `Core/OrderInfoPageModel.swift`. `phase(orderID:signedIn:configured:loading:issue:detail:now:)` and a coordinator overload. Reads only; no cancel, refund or pay. |
| `PointsHistoryPageModel` | new, `Core/PointsHistoryPageModel.swift`. `load(direction:loading:failure:rows:total:pageSize:)`. Direction filter is local because the server ignores it. Existing `wallet.*` keys only. |
| `NearbyMerchantPage` | new, `Core/NearbyMerchantPage.swift`. `resolve(phase:rows:)`. Total is an em dash until a loaded read; "0" only for a loaded empty read. Meter suffix kept. |
| Square optional counts | `SquarePost.likeCount/commentCount` and `SquareComment.likeCount` are `Int?`; nil is unknown. `SquareCountDisplay` renders nil as an em dash. Three views (`SquareDetailView`, `SquareComponents`, `SquareXcxPostCard`) changed only at those count call sites. |
| `ClubTabPageModel` reader | `ClubService.homeBody`, `ClubReading.clubHomeBody()` (default nil), `ClubSessionReader` implements it. `ClubTabPageModel.project(homeBody:)`. |
| `ClubEditPage` raw body | `ClubService.detailBody`, `ClubReading.clubDetailBody(id:)` (default nil), `ClubSessionReader` implements it. |
| favorites payload | `AccountCollectionPostPage.rawPayload` is set by `AccountCollectionService.favoritePosts`. Feeds `AccountCollectionFavoritesPageModel.resolvePosts`. |

Not wired: `AppSession` does not forward `clubHomeBody` / `clubDetailBody`, so the default nil (unknown) applies until a wire task adds that. No view reads the new page models yet.
