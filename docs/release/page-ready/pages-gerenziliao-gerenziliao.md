# pages/gerenziliao/gerenziliao — CB279

PAGE-READY on rc/20261108. Native screen `App/ProfileEditView.swift`. Map status stays **gated**. No route was added or marked live. Core, tests, views, catalogs, the project, and the CI manifest were not changed.

Wired contract: empty-multipart `POST api/user/info` reads the signed-in self row (`ProfileEditService.read` → `ProfileEditSnapshot`). `POST api/user/update` saves the reviewed JSON body (`ProfileEditService.save`). Wire fields already decoded and preserved: `id`, `nickname`, `introduction`, `avatar`, `wechat`, `casePics`, `caseIntroducton`, `tagIds` (or `sysCategoryList` when `tagIds` is omitted), and display-only `phone`. `ChinaReviewedRouteCapability` already marks `api/user/info` and `api/user/update` liveInProduction; this lane did not edit that table.

States already present: loading is `ProfileEditCoordinator.isBusy` (the form shows `profile.edit.busy`); empty is no session (`profile.edit.signIn`), an unconfigured service (`profile.edit.unavailable`), an empty editable string (`profile.fieldEdit.empty`), and an unbound phone (`profile.phone.unbound`); error is `profile.edit.loadFailed` / `refreshFailed` / `rejected` / `notSent` plus a nonblank `ProfileReadFailure.message`; UNKNOWN is `ProfileEditWriteError.outcomeUnknown`, which keeps the account locked and sets `profile.edit.unknown`. A matching read after an unacknowledged write stays `profile.edit.readbackUnconfirmed` and does not unlock.

Unknown display stays an em dash, never a stand-in 0. An empty masked phone is drawn as `—`. `ProfilePreferenceRemoval.parse` returns nil for a non-numeric `tagIds` string and `[]` only for a blank string, so a known empty selection is 0 and an unreadable one is not stored as 0. A literal image count of 0 stays 0.

Missing capabilities stay hidden. No phone binding, email field, or avatar upload was added. Password login stays off outside DEBUG (`AppSession.canUsePassword` is false in non-DEBUG). `website` is on the member DTO and is not round-tripped; the mini input is commented out, so it stays absent. Email is not in this contract.

Missing EN+zh-Hans keys: none. The 131 `profile.*`, `context.preferences.*`, and `action.*` lookups used by this editor, including coordinator status keys, already have translated en and zh-Hans in `Resources/Localizable.xcstrings`, `Resources/ProfileCurrentMediaUI.xcstrings`, `Resources/ProfileCurrentReview.xcstrings`, or `Resources/ProfileNicknameRead.xcstrings`.

Left: the preference count on the form still uses `compactMap` in `ProfileEditView`, so an unreadable `tagIds` can still render `0` until a view change uses `ProfilePreferenceRemoval.parse`. The avatar row shows `profile.avatar.notAvailable` when no avatar transport is composed; it is not a silent upload control. Phone binding, email, and `website` stay off. Views were not edited.

Existing tests stay: `ProfileEditTests`, `ProfileReadFailureRecoveryTests`, `ProfileEditServiceTests`, `ProfileEditAvatarGateTests`, `ProfileFieldLimitTests`, `ProfileCasePortfolioTests`, and `ProfileEditRefreshTests`. No new tests. No assertion was weakened. Swift was not compiled. `xcodebuild` was not run. No Xcode Cloud result is claimed.
