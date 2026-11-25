# Receipt: fix/r3-account-publish-b (wave ×10, Claude F-agent, account-publish half b)

- **Brief:** `origin/design/handoff-r2:docs/briefs/wave-x10.md`.
- **Base:** `origin/ui/combined-r7` (7fdfad1f1).
- **Restyle branches merged first:** `restyle/r4-me-account`, `restyle/r3-merchant-creator`, `restyle/r6-system-rest` and `restyle/r1-player-front`. The r1 merge had one conflict in `Tests/ContractChecks/test_global_chrome_domain_contract.py`, resolved by keeping both rule blocks.
- **Scope:** pages 12–22 of the round-1 audit (`audit/parity-account-publish`): privacy, agreement, deregister, pass reveal, fabu, temp, activity, template-intro, square detail, team detail and team join.
- **Gap source:** the r7 fix queue `audit/parity-r7-account-publish:docs/audit/parity-r7/account-publish.md`, Claude-owned items. The `review/r7-rev-{a,b,c}` reviews have no findings on these files.
- **Layer:** App only. No Core types were changed.
- **Strings:**
  - New keys are in `docs/port/strings/fix-r3-account-publish-b.json`. They use the `fixr3.*` prefix and the default table.
  - The `config.gameplay.category.*` keys were added directly to `Resources/ConfigR4.xcstrings`, because that is a feature table, not Localizable.
- **Acceptance routes:** `docs/port/accept/f-account-publish-b.txt`.

## Fixed

| ID | Page | What changed | Files |
|---|---|---|---|
| B-PV-02 | privacy | 首页城市自动定位 is now one system `Toggle`. It starts from the latest `home_city_location` consent row (no row reads as off). Turning it on confirms first, then records AGREE; turning it off records REVOKE. 撤回授权 is now a plain disclosure row, not a pill. | App/SettingsPrivacyLocationView.swift |
| B-PV-05 | privacy | `.secondary` → `CYColor.textSecondary` on the privacy page. The holds row uses `.cyText(.bodyCompact)`. | App/SettingsPrivacyLocationView.swift, App/SessionLocationHoldsSection.swift |
| B-PV-06 | privacy (roam sheet) | A partial withdrawal (server revoked, local cleanup pending) or a failed one shows an inline row 撤回尚未完成，请重试 with 重试. The revoke logic moved into `performRoamRevoke()`; its behaviour is unchanged. | App/AccountComplianceViews.swift |
| B-AG-01 | agreement | The top version block is gone. There is one footer 「版本 x · 生效日期 y」, which wraps to two lines at large text sizes. The version identifier is kept for UI tests. | App/SettingsLegalDocumentView.swift; contract test_native_ui_accessibility_semantics updated |
| B-AG-03 | agreement | Section heading uses `.cyText(.cardTitle)`; the extra `lineSpacing` is dropped. | App/SettingsLegalDocumentView.swift |
| B-DR-02 | deregister | A BLOCKED card with the neutral title 暂时无法注销, 「请先处理以下事项：」, one row per blocker and 「我已处理，重新检查」 in place of 刷新状态. Blockers are no longer listed twice. | App/AccountComplianceViews.swift |
| B-DR-05 | deregister | `.headline`/`.subheadline`/`.footnote` → `.cyText(.cardTitle/.body/.bodyMedium/.meta)`. | App/AccountComplianceViews.swift |
| B-DR-06 (partial) | deregister | `.freshLogin` is now an empty state 登录后查看账号注销条件, with the existing explanation as detail. | App/AccountComplianceViews.swift |
| B-DR-07 | deregister | The Settings search results for 注销账号 and 漫游定位 open the same sheet as the Settings rows, through `AccountComplianceSheetStack`. | App/SettingsView.swift, App/AccountComplianceViews.swift |
| B-DR-08 | deregister | Step circles use the accent fill (`actionPrimaryBg`) with `textOnAccent` digits and checks. | App/AccountComplianceViews.swift |
| B-DR-09-r7 | deregister | MP copy: 我已阅读并理解注销后果, 获取验证码 / 重新发送, 短信验证码 and 确认申请注销. 正在核验注销条件 shows under the skeleton, and 注销条件核验失败 titles a failed read. | App/AccountComplianceViews.swift, strings fragment |
| B-PR-02 | pass reveal | The MP gold wash (#2A1E08→#8A6414→#D4A72C→#F2CF63) rises over the lower 62 %. After the reveal the key breathes slowly (PhaseAnimator); with Reduce Motion it stays still. | App/PassMembershipViews.swift, App/DesignSystem/CYNight.swift (passGold0–3) |
| B-PR-04 | pass reveal | Eyebrow tracking 3.5, white at 72 %. Title and line are white on the wash. The CTA is the MP inverse 50 pt white pill. | App/PassMembershipViews.swift |
| B-PR-05 | pass reveal | The stage tap/drag skip and the press dim are removed; only the toolbar 跳过 skips. | App/PassMembershipViews.swift |
| B-PR-06-r7 | pass reveal | `.toolbarBackground(.hidden, for: .navigationBar)`. | App/PassMembershipViews.swift |
| **C-F6 (P0)** | fabu | The built 到访方式 editor (`FreeExplorationVisitConfigView`) is mounted in `ProjectEditView` for saved free-explore topics. It is composed through an app-root environment factory (`session.freeExplorationVisitConfigModel`). Reads need `PlayRuntimePortRouteGate.freeExploreVisitConfigRead`; writes need the write gate and the editor's approved author authority (`canSubmit && !canSimulate`). **Both gates stay default off**, so the row is hidden until they are turned on. | App/FreeExplorationVisitConfigView.swift, App/ProjectEditView.swift, App/QuestifyApp.swift |
| C-F12 (rest) | fabu | All 14 raw `.font(.…)` in the detail forms are now `.cyText` tokens. | App/ProjectEditDetailForms.swift |
| C-F15-r7 | fabu | 这份主题加载失败 with one full-width 重新加载 (the `projectEdit.reload` identifier is kept). | App/ProjectEditFlowParity.swift |
| C-F18-r7 | fabu | 下一步 uses `CYPillButtonStyle(.primary)`, matching the bar. | App/ProjectEditView.swift; test_project_edit_review_availability BUTTON pin updated |
| C-T5 (partial) | temp | 保存草稿 moved into the bottom bar as a secondary action, keeping its identifier. | App/TemplateAuthoringView.swift |
| C-T8 | temp | Gameplay picker categories follow the MP: 问答 (text, choice, photo) / 互动 (manual, preference) / 挑战 (scan, gps, sensor). | App/TemplateGameplayPickerSheet.swift, Resources/ConfigR4.xcstrings |
| C-T10 | temp | `.font(.caption)` → `.cyText(.caption)`. | App/TemplateAuthoringView.swift |
| C-T11 (partial) | temp | The raw "Request: uuid" line shows in DEBUG builds only. | App/TemplateAuthoringView.swift |
| C-A7 | activity | The activity form uses the single `.topicEditor` domain, which was `.merchant` before; its sheets already used it. | App/PublishingModesViews.swift (outside the hash-pinned slices) |
| C-I5 (partial) | template-intro | Literal spacings are replaced by CYSpacing tokens. | App/TemplateAuthoringIntroExperience.swift |
| C-S9 | square detail | Reaching the end of the comments loads the next page (MP onReachBottom). The button stays for VoiceOver. | App/SquareDetailView.swift; Tests/AppUITests/SquareFlowTests.swift |
| C-D9 | team detail | 重新加载 shows only after a failed read or when no detail is loaded; pull-to-refresh is unchanged. | App/TeamHomeView.swift |
| C-J3 | team join | 加入队伍 now joins directly and reads 加入中… while the request runs. The join review sheet is suppressed when a submit authority exists; without one, the review sheet still explains why. Other team actions keep their review sheets. | App/TeamHomeView.swift; Tests/AppUITests/TeamFlowTests.swift (2 tests drop the confirm tap; names kept because planning contracts reference them) |

## Left open (with reasons)

| ID | Sev | Reason / next owner |
|---|---|---|
| B-PV-02 (presence) | P1 | There is no read of the current nearby-presence state, so an "off-only Toggle" would claim a state we don't know. The button is kept. **Cursor:** add a presence-visibility read. |
| B-PV-07-r7 | P2 | The launch gate runs signed out, where `pendingRecords(accountID:)` has no account. **Cursor:** add a "record owed" signal that is visible before sign-in. |
| B-DR-03 / B-DR-04 | P1 | Owned by Cursor (Core). |
| B-DR-06 (rest) | P1 | 登录 CTA: the compliance sheet has no sign-in hook. There is also no DENIED step in `ComplianceStep`. **Cursor:** add a `.denied` step; the App will then show 当前身份不能查看注销条件 + 刷新. |
| B-PR-03 | P2 | Replacing the reveal in the path needs the parity router to support replace-top; `mpParityRouteDestination` only pushes. |
| C-F2 (rest) | P1 | The starter sheet has no place-picker target (`ProjectNodePlacePickerHost` takes chapter/node or a pending target only). The 3 XCUITests type coordinates and need a fixture place reader. Recommend one change that covers the host, the fixture and the tests. |
| C-F4 (rest) | P1 | Moving 存到本机 into ⋯ breaks about 20 XCUITests that tap `projectEdit.saveLocal` in the bar. This needs a coordinated test update in the acceptance loop. |
| C-F8 | P1 | PhotosPicker for the story/node image URL fields is size M, and the fields are pinned by story-media contracts. Not attempted in this window. |
| C-F14 | P2 | 「还有 N 项未填」 needs the MP `ticketMissing` rule in Core (EditorTicketSummary has no required-field count). **Cursor.** |
| C-F16-r7 | P2 | A vertical-axis TextField changes the XCUI element type that `ProjectEditFlowTests` queries (`textFields["projectEdit.name"]`). |
| C-T2 (rest), C-T12-r7 | P1 | These need Core signals: an adoption-pending error kind, and a support-matrix read with loading and error states. **Cursor.** |
| C-T5 (rest) | P1 | 保存到此设备 was not moved into ⋯ because 6 XCUITests tap `templateAuthor.saveLocal` in the form. |
| C-T6 (rest), C-T13-r7, C-I8-r7 | P1 | `from=fabu|citynode` and `scope=MERCHANT` need `templateAuthoringEditor(scope:origin:)` in AppSession/Core. In the app, the fabu-bound flow saves a draft and then 返回 binds it. **Cursor/Core.** |
| C-T9 | P2 | `TemplateAuthoringField` already passes `limit` (30) to the editor field; nothing to change found. |
| C-A8 | P2 | Core validation (`ActivityPublishingWizard` ticketStart/ticketEnd) requires per-ticket times, so dropping the fields would block publishing. **Cursor:** default the ticket window to the activity span. |
| C-A9-r7, C-I9-r7, C-S4, C-S8, C-S10, C-D10, C-J5, C-J6 | P2 | Polish; not reached. C-D10 already loads on demand. |
| Gemini / owner items | — | C-F1, C-F5, C-F7, C-D2, C-D11, C-J2, C-T3, C-A4 (Gemini, parked MPGap) and B-PV-04, C-F17 (owner) were not touched. |

## Skipped because in-flight branches cover them

- `restyle/*`: visual only, and merged into this branch first (r1, r3, r4, r6).
- `gap/g2-ops`: compile fixes for the parked `App/MPGap/AccountPublish` views (C-A4, C-D2, C-J2, C-F5); not touched here.
- `cursor/*` and `port/*`: none touch these screens beyond what r7 already has. `cursor/mp-assets` does not exist yet, so no MPAsset swaps were made. The pass reveal key emblem is still `PassKeyEmblem`, which uses no SF Symbol for brand art.

## Checks run in the cloud

- `tools/contract_ratchet.py --check` on the merged base, before my edits: 195 failing, 11 new against the 184 baseline. All 11 come from the restyle merges.
- After my edits, the 2 new failures I introduced were fixed: `test_native_ui_accessibility_semantics` (legal footer pin) and `test_settings_native` (one NavigationStack). Final run on `aae081a4a`: **195 failing, baseline 184, new 11**. This is the same set as the merged base, so this branch adds 0 new failures.
- `tools/check_typography_lint.py`: PASS.
- `tools/check_appsession_ratchet.py`: PASS. `AppSession.swift` is untouched.
- `tools/check_scaffold.py` fails on `origin/ui/combined-r7` as well (pre-existing); no new Swift files were added.
- `contract_ratchet.py --check` against `origin/ui/combined-r7` (`82388e4a5`), which itself fails 199 (15 new vs the 184 baseline):
  - This branch fails 201. The only added failure is `test_localization_key_catalog_contract`: the `fixr3.*` keys used by the views are still only in the string fragment, by the fragment rule, and the test passes once the coordinator merges `docs/port/strings/fix-r3-account-publish-b.json` into `Localizable.xcstrings`.
  - A second new failure (`test_bk_backend_sync`, which pins the 收藏 condition literal) came from my C-S11 edit, which I reverted.
- `check_a11y_lint.py`: 12 new findings. None are in files this branch changed in round 2; they come from the round-1 restyle merges (Square cloud, merchant and search views) shifting baseline keys. combined-r7 alone passes.
- **Not compiled.** The coordinator should watch for:
  - `phaseAnimator` (iOS 17) in PassMembershipViews.
  - `FreeExplorationVisitConfigModel` (`@Observable`, `@available(macOS 14)`) created in an `AppSession` extension.
  - `Toggle(isOn: Binding(get:set:))` in SettingsPrivacyLocationView.
  - `if a && b && c, d || e` in TeamHomeView.

---

## Round 2 (2026-11-24)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round2.md`, plus `wave-x10.md` and `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` at `82388e4a5` (Cursor Core K1–K10, W1 wiring, C7 MP assets). I merged it again before the final push; nothing had changed.
  - Conflict in `tools/check_typography_lint.py`: took combined-r7's version.
  - Conflict in `App/FreeExplorationVisitConfigView.swift`: took combined-r7's version.
- **C-F6 (round 1 P0), decided by the newer Core API:** combined-r7 now mounts 到访方式 in `ProjectEditView` through `ProjectEditCoordinator.visitConfigModel(topicID:)` (W1, `cursor-r7-wiring.md`).
  - My round-1 mount was a duplicate, so I removed it: `FreeExplorationVisitConfigEntrySection`, the environment factory and the `QuestifyApp` `.environment` line.
  - Both gates still default off.
- **Cursor call sites:** no `cursor/wire-account-publish` branch exists. I used only the Core APIs listed under "F-agent App changes" in `cursor-core-account-publish.md`, and none of the call sites W1 wired.

### Fixed in round 2

| ID | Page | What changed | Files |
|---|---|---|---|
| B-DR-03 (App) | deregister | The phone `TextField` is gone. 获取验证码 calls `sendBoundPhoneSMS`, which sends to the bound phone from `/api/user/info`, with Core's 60-second suppression. The send notice shows inline, using Core's 「验证码已发送至尾号 xxxx 的手机号」. `DeregistrationBoundPhone.missingMessage` shows inline under the button and is no longer duplicated in the top error row. | App/AccountComplianceViews.swift |
| B-DR-04 (App) | deregister | The notice step calls `precheckAndAgree(…, recordConsent: false)`, so it only reads. Both apply buttons pass `recordNoticeConsent: true` and the displayed document version, so AGREE is recorded after SMS, as in the MP. | App/AccountComplianceViews.swift |
| C-J2 (mount) | team join | After a `TICKET_REQUIRED` rejection on an activity team (`ownerType == 2`), the primary action becomes 去买这一场的票. It pushes `pages/activity/baoming/baoming?activityId=<ownerId>` through `MPReviewedPageScreen`, which opens the activity detail with the registration sheet. | App/TeamHomeView.swift |
| C-S4 (rest) | square detail | Each comment avatar has the MP 加号 follow button (`MPAsset.FeatureIcon.iconJia`, 44 pt target). It shows only when the follow state is known to be "not following" and the commenter is not the viewer. | App/SquareDetailView.swift |
| C-S8 | square detail | An inline 关注 sits at the end of the post head. It shows when the viewer is known not to follow the author, the author is not the viewer, and the post has no play cover (the MP rule). `SquarePostContent.onFollow` defaults to nil, so other screens are unchanged. | App/SquareComponents.swift, App/SquareDetailView.swift |
| C-D10 | team detail | 二维码 opens a 队伍二维码 sheet (medium/large detents). The sheet reads the code as it opens, and 重试 shows only after a failure. `TeamInviteQRSection` gained `loadsOnAppear` (default false), so the gap fixture is unchanged. | App/TeamHomeView.swift, App/PlayerGapViews.swift |
| C-J5 | team join | The invitation actions sit in a bottom `CYFooterBar` (`safeAreaInset`), as in the MP `.tj-bar`. These actions are 查看队伍, 加入队伍 or 重新加入, the retry notice, 去买这一场的票, and the closed state. Identifiers are unchanged. | App/TeamHomeView.swift |
| C-J6 | team join | A seat row shows joined seats filled and open seats dashed, as in the MP `team-seats.js`. Open seats come from `seats.available`, else from `max − joined`; each side is capped at 12. The seats pop in 70 ms apart, and Reduce Motion shows them at once. VoiceOver reads one combined label. | App/TeamSeatFactsViews.swift, App/TeamHomeView.swift |

### MP assets applied (`docs/mp-assets/mapping.md`)

- [x] `MPAsset.Other.keyIntro0…13` / `keyIdle0…11` (pass reveal). `PassKeyFrames` plays the MP sprite sheets: 3 columns of 585×780 frames, an 83-frame intro once at 18 fps, then a 72-frame idle loop at 12 fps. A repeat visit or a skip lands on the idle loop, and Reduce Motion shows idle frame 0. This replaces the drawn shards and `PassKeyEmblem` on the reveal (it also closes the "bundled MP frame sheets" half of B-PR-02).
- [x] `MPAsset.FeatureIcon.dMbico1` / `dMbico2` (publish/activity template rows): 人数 and 「N分钟」, read from the row's raw `players` / `duration`, and drawn only when present.
- [x] `MPAsset.FeatureIcon.iconTagCheck` (publish/temp): marks an added tool or module in the template editor. It replaces `checkmark.circle.fill`.
- [x] `MPAsset.FeatureIcon.iconJia` (square/detail comment follow).
- [x] `MPAsset.AvatarDefault.dProfile`:
  - Square post and comment avatar fallback (`SquareAuthorAvatar`, shared with the square list).
  - Team member rows: Core decodes no `memberAvatar` yet, so every row shows the MP default.
- [ ] `MPAsset.FeatureIcon.subpackageMemberImagesIconStar` (publish/activity wxml:245): commented out in the MP, so not applied.
- [ ] `MPAsset.FeatureIcon.iconDate3` (publish/activity date row): the app uses the system `DatePicker`, which has no icon slot. This is the native iOS rule.
- [ ] `MPAsset.MapMarker.mapPin` (fabu route map): the MP now draws round numbered pins (`play-marker-draw`) and uses `map-pin.png` only as a fallback. The app's numbered circle matches the live MP look.
- [ ] `MPAsset.BannerCover.sampleWindow` / `pagesPublishImagesMer1` (node-game preview samples): the app has no preview-sample surface yet.
- [ ] `MPAsset.Other.glassKey` (membership card key): this is the membership page, which is half a.
- [ ] `MPAsset.BadgeMedal.medalGold/Silver/Bronze` (completion share card): see C-S10 below.
- Kept as SF Symbols, as system-control glyphs: share (`iconShare`), disclosure chevron (`iconRight`), ellipsis, close.

### Owner decisions (`owner-decisions-1124.md`)

- **#9 two-decimal money:** my pages show no money. The fabu and activity ticket prices are 积分, and membership prices are half a. Nothing changed.
- **#3, #6, #12 money stays TEST-only:** no money writes on these pages, and no new gate.
- **#8 GPS arrival lock, #10 pilot gate for game kits, #7 cast on fixtures:** none of these surfaces is on my pages. The fabu cast block (C-F5) is Gemini's parked MPGap view.

### Review findings

`review/r7-rev-a`, `-b` and `-c` have no Claude-owned row on these pages:
- REV-A rows are play-runtime rows for Cursor.
- REV-B Claude rows are P3/P5 (topic detail, IM, ticket wallet).
- REV-C rows are Gemini's or the integrator's.

Of the r7 parity P1 rows still open, this round closed B-DR-03, B-DR-04 and the C-J2 mount, which depended on Core.

### Still open after round 2 (with reasons)

| ID | Sev | Reason / next owner |
|---|---|---|
| C-D12-r7 | P1 | `TeamCommandWriter` (query, retry, cancel) has **no caller**. `TeamCoordinator` submits through `TeamHTTPService`, so the writer's `savedRequestIDs` is always empty, and 查询原请求 / 终止 would always return `.unknown`. I did not add buttons that cannot work. **Cursor:** route the team command submit through `TeamCommandWriter` from `TeamCoordinator`, and expose `query()`, `retry()` and `cancel(fields:)` on the coordinator (or on `TeamScreenModel`). The App will then add the three buttons and `TeamCommandRecoveryCopy.abortNote` next to 核对上次操作结果. |
| B-DR-06 (rest) | P1 | Still no `.denied` in `ComplianceStep`, and the compliance sheet has no sign-in hook (Cursor). |
| C-T6 (rest), C-T13-r7, C-I8-r7 | P1 | `AppSession.templateAuthoringEditor` still takes only `adopting:`; there is no `scope:` / `origin:` (the AppSession ratchet applies). Cursor/Core. |
| C-T2 (rest), C-T12-r7 | P1 | No adoption-pending kind and no support-matrix read on r7 (Cursor). |
| C-F2 (rest), C-F4 (rest), C-T5 (rest), C-F16-r7 | P1/P2 | Each needs a coordinated XCUITest change. Tests/ belongs to Cursor (see round 1 for the identifiers). |
| C-F8 | P1 | PhotosPicker for the story and node image fields is size M, and those fields are pinned by story-media contracts. Not reached. |
| C-S11 (App) | P2 | Already correct: the star shows only for `communityV1`, which is exactly `showsBookmark`. `test_bk_backend_sync` pins the literal `post.generation == .communityV1`, so the call site keeps it. **Cursor:** if you want the shared rule there, update that regex and switch the call site together. |
| C-S10 | P2 | On detail, a completion post already gets the C-S1 play card, because `sportName` becomes `referenceTitle`. The MP medal pill (`medal-gold/silver/bronze`) needs `medalGold`, `medalSilver` and `medalBronze` on `SquarePost`. **Cursor:** decode them. The App will then add the pill with `MPAsset.BadgeMedal.*`. |
| Team member avatars | P2 | **Cursor:** decode `memberAvatar` on `TeamMember`. Until then the row shows `d_profile`. |
| B-PV-02 (presence), B-PV-07-r7, B-PR-03, C-F14, C-A8 | — | Unchanged from round 1. These wait on Core signals or the router. |
| C-A9-r7, C-I9-r7 | P2 | Polish; not reached. |

### Acceptance and strings

- `docs/port/accept/f-account-publish-b.txt` gained these routes:
  - `fr3-pass-reveal-paid` and `fr3-pass-reveal-first`: new DEBUG fixtures in `PublishDesignFixtures`.
  - `publish-template-select`: its rows now carry `players` and `duration`.
  - `g-team-qr` and `g-team-qr-refused`.
- New strings in `docs/port/strings/fix-r3-account-publish-b.json` (en and zh-Hans):
  - `fixr3.team.buyTicket`
  - `fixr3.activity.templateMinutes %lld`
  - `fixr3.square.follow`
  - `fixr3.team.qr`, `fixr3.team.qr.a11y` and `fixr3.team.qr.title`
  - `fixr3.team.seats.a11y %lld %lld`

### Checks run in the cloud (round 2)

- `check_typography_lint.py`: PASS.
- `check_appsession_ratchet.py`: PASS. `AppSession.swift` is untouched.
- Contract tests: the `test_team*`, `test_square*`, `test_pkg19_login_deletion_chain` and `test_auth_entry_parity` suites are all OK.
- **Not compiled.** The coordinator should check:
  - `Layout` (`FlowSeats`, iOS 16) in TeamSeatFactsViews.
  - `TimelineView(.animation(minimumInterval:paused:))` in `PassKeyFrames`.
  - `if case .error? = view` in `TeamInviteQRSection.failed`.
  - The `@ViewBuilder` `invitationActions` if/else-if chain in TeamHomeView.
  - `MPReviewedPageScreen` pushed from `TeamDetailView`: it needs the `AppSession` environment object, which the app root provides.

---

## Round 3 (2026-11-24 evening)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round3.md`, plus `wave-x10.md`, `fix-r3-round2.md` and `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` at `b0ac0108d`. The merge had no conflicts.

### Round 3 · re-applied

I checked every round-1 and round-2 commit of this branch, hunk by hunk, against the new base (`git diff origin/fix/r3-account-publish-b HEAD -- <file>`). Only `App/TeamHomeView.swift` lost hunks, because it was restored to Cursor's side. In the other files the base only added to my edits: Cursor/Gemini marketing rows, membership glass key, `@preconcurrency`, and the iOS 18 `symbolEffect` guard.

| ID | What was missing on the base | Re-applied on top of Cursor's wiring |
|---|---|---|
| C-J5 | The invitation actions were back inside the scroll view. | `invitationActions(detail:invitationCode:)` again sits in a bottom `CYFooterBar` (`safeAreaInset`). Cursor's `model.rememberRecovery(action)` in `joinDirectly` is kept, so 加入队伍 still captures the recovery fields. |
| C-J2 | 去买这一场的票 after `TICKET_REQUIRED` on an activity team was gone. | It is back in the footer branch and uses the same `TeamSeatPresentation.showsBuyTicket` and `MPReviewedPageScreen("pages/activity/baoming/baoming")`. |
| C-J6 | `TeamJoinSeatRow` was not mounted. | It is mounted again on the invitation page, above `TeamSeatFactsCard`. |
| C-D10 | 二维码 was back to the inline `TeamInviteQRSection`. | `TeamInviteQRSheetButton` is restored (the sheet reads the code when it opens; `loadsOnAppear` is still on the base). |
| — | Kept from Cursor | `teamRecoveryButtons` (C-D12 query / retry / cancel + `abortNote`), the `teamCommandWriter` environment and `rememberRecovery`. This closes my round-2 open item C-D12-r7. |

`App/SettingsView.swift` (B-DR-07 search sheet) and `App/SquareDetailView.swift` (C-S4, C-S8, C-S9, C-S11) still had my hunks, so nothing was re-applied there.

### Fixed in round 3

| ID | Source | What changed | Files |
|---|---|---|---|
| flows-g2 `publish/activity/index.js` `redirectTo ?` | Gemini flow gap (MISSING-ROUTE for Claude) | MP `onResultSheetClose` redirects to `myproject?type=club_activity`. Closing the activity result sheet now pushes the project list with the 活动 filter selected (`PublishingProjectsView(initialType: "activity", readOnly: true)`). This uses the same condition as the result card's existing 项目 link: a signed-in owner whose session is current and who can read projects. Otherwise the sheet just closes, as before. `initialType` applies once, on first appearance, and loads through the existing `onChange(of: type)`. | App/PublishingModesViews.swift (ActivityPublishingView, outside the hash-pinned slices), App/PublishingManagementViews.swift |

### Flow gaps on my pages (`docs/mp-gap/flows-g1.md`, `flows-g2.md`)

| Edge | Status |
|---|---|
| `agreement/index.js` `redirectTo ?` | The MP falls back to `redirectTo(origin)` only when `navigateBack` fails, i.e. the page was opened with no stack. In the app, the agreement page is always pushed or presented, so system back is always present. No change needed. |
| `publish/activity/index.js` `redirectTo ?` | **Fixed** (above). |
| `publish/temp/index.js` `reLaunch myproject?type=template` | Already covered. `TemplateAuthoringSaveFlow` / `TemplateAuthoringPublishCompletion` turn the pushed editor into the own-template library once the result panel closes. |
| `publish/fabu/index.js` `redirectTo next` (result sheet → `topic/merchantinfo`) | Already covered. `ProjectEditView.submissionResult` hands off to `submittedResource` (the publisher lifecycle host). |
| `publish/fabu/index.js` `navigateTo fabu?mode=` (复制为新草稿 on a mode switch) | **Open, Cursor.** The app has no mode switch after the draft has content. The MP flow copies the draft (`_buildCopiedDraft`: runtime config references, tickets re-moded, categories, pending materials) into a new draft. This needs a Core draft-copy API on `ProjectEditCoordinator`. The App will then add the 复制并切换 confirm. |
| `team/detail` & `team/join`, `square/detail`, `subpackagePass/reveal` | `[OK]` in flows-g1. |

### MP assets

`docs/mp-assets/mapping.md` has no new rows on my pages since round 2. The rows for template-detail shelf covers, leaderboard memojis and member-journey icons all map to `DiscoveryTemplateDetailView`, the official leaderboard and the member-journey screens, which are not on my half's page list (pages 12–22). The round-2 ticks stand.

### Review findings

`review/r7-rev-a`, `-b` and `-c` have no Claude-owned row on any file of my pages (checked again on the fetched branches).

### Still open after round 3 (with reasons)

| ID | Sev | Reason / next owner |
|---|---|---|
| B-DR-06 (rest) | P1 | There is still no `.denied` in `ComplianceStep` and no sign-in hook on the compliance sheet. **Cursor.** |
| C-T6 (rest), C-T13-r7, C-I8-r7 | P1 | `TemplateAuthoringCoordinator.operationScope` now exists, but it reaches only the shelf requests (`TemplateAuthoringShelf`). Save and publish (`TemplateAuthoringContract` save fields) do not carry `scope=MERCHANT`, and `AppSession.templateAuthoringEditor` still takes only `adopting:`. Setting the scope in the App alone would show a merchant editor that saves as a player. **Cursor:** put the scope on the save and publish requests, and add `from:` / `scope:` to the editor factory. |
| C-T2 (rest), C-T12-r7 | P1 | There is still no adoption-pending kind and no support-matrix read. **Cursor.** |
| C-F2 (rest), C-F4 (rest), C-T5 (rest), C-F16-r7 | P1/P2 | Each needs a coordinated XCUITest change in Tests/, which belongs to Cursor. The identifiers are listed in round 1. |
| C-F8 | P1 | Story text and image blocks already use the `storyImages` picker (选择替换图片 / insert before). What remains is the rich-story gallery rows (`ProjectEditRichStoryForms` :56, :62), which are still URL `TextField`s pinned by the story-media contracts. This is size M and needs a compile pass; not attempted blind. |
| C-S10 | P2 | `SquarePost` still has no medal fields. **Cursor:** decode them. |
| Team member avatars | P2 | `TeamMember` still has no `memberAvatar`. **Cursor.** |
| C-A9-r7 | P2 | Kept as is. Design hand-off r1 CF-58 makes real-name its own pushed page, shown only when needed; it is not inline as in the MP. **Owner/design** to overrule if the MP layout should win. |
| C-I9-r7 | P2 | The owner-final (2026-10-22) floating cover field is a full-screen canvas with an orbit, drag physics and glass edges. Contract tests pin the card identifiers (`creatorIntro.example.*`). This is size M+, and I did not attempt it without a compiler. |
| B-PR-03 | P2 | The parity router still only pushes; it has no replace-top. |
| B-PV-02 (presence), B-PV-07-r7, C-F14, C-A8 | — | Unchanged. These wait on Core signals. |

### Checks run in the cloud (round 3)

- `contract_ratchet.py --check`: 217 failing (baseline 184, new 33). `origin/ui/combined-r7` `b0ac0108d` gives the identical 33-name set, so this branch adds **0** new failures.
- `check_typography_lint.py`: PASS.
- `check_appsession_ratchet.py`: PASS.
- `check_a11y_lint.py`: 17 new against the baseline, which is the same 17 as `origin/ui/combined-r7`. None are in files this branch touches.
- Contract tests:
  - `test_original_publishing_request_recovery` and `test_publishing_modes`: OK.
  - `test_team_*`: OK, except `test_team_postjoin_navigation.test_separate_readonly_route_does_not_weaken_action_lock`, which also fails on the base. Cursor's C-D12 changed `pending != nil` to `let pending =`, so the pinned literal no longer matches. **Cursor:** update that pin.
  - `test_activity_publishing_wizard.test_untouched_publishing_slices_and_activity_handoff`: fails on the base too. The Swift 6 `@preconcurrency` edit is in the hash-pinned suffix.
- **Not compiled.** The coordinator should check:
  - `.navigationDestination(isPresented:)` on `ActivityPublishingView`. Every host pushes it inside a NavigationStack: the publish menu, the deep link and the fixtures.
  - `if let account, let service, let openResource { … }` inside that destination's `@ViewBuilder`.
  - `PublishingProjectsView(…, readOnly: true, initialType: "activity")`: the argument order follows the declaration, and `designPreview` is DEBUG-only and sits after `initialType`.

---

## Round 4 (2026-11-25)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round4.md`, plus `wave-x10.md` and `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` at `4ef0a2840`. The merge had no conflicts.
- **Scope:** the same pages 12–22. Gemini is out of quota, so this round also covers MP alignment (flows, images, copy) for these pages.
- **Layer:** App only. No Core types were changed.

### 1. Flows (`flows-g1.md`, `flows-g2.md`)

| Edge | Status |
|---|---|
| `subpackagePass/reveal/index.js:120` `redirectTo ?` (MISSING-ROUTE for Claude) | **Fixed.** In the MP, both 跳过 and 开始 call `_go()`, which redirects to membership (or to the library after a paid order). In the app, 跳过 only jumped to the end of the animation. Now 跳过 opens the same page as 开始. With no destination bound, it still ends the intro. |
| reveal `redirectTo` = no way back to the interstitial (B-PR-03, P2) | **Fixed.** Once 开始 or 跳过 has opened membership or the library, coming back from that page also closes the reveal, so the user lands on the page underneath. The parity router still only pushes, so the reveal briefly shows before it closes; a real replace-top would need a router change. |
| `square/detail/index.js:161` `navigateTo ?` (goUserInfo → `userinfo`) | Already covered. The avatar opens the MP menu: 关注 when known not following, then 访问个人主页, which pushes `SocialPublicProfileView`. **Changed:** the extra `查看作者主页` row under the post is removed; the MP has none, and the avatar menu is the only entry. |
| `publish/fabu/index.js:3363` `navigateTo ?` / `:8500` `redirectTo ?` | Unchanged from round 3. `:8500` (result sheet → next) is covered by `ProjectEditView.submissionResult`. `:3363` (复制为新草稿 on a mode switch) still needs a Core draft-copy API. **Cursor.** |
| `publish/temp/index.js:3520` `reLaunch myproject?type=template` | Covered (round 3). |
| `publish/activity/index.js:738` `redirectTo ?` | Fixed in round 3. |
| `agreement/index.js:52` `redirectTo ?` | No change needed (round 3). |
| privacy, deregister, team detail, team join | `OK` in flows-g2; checked again, nothing to change. |

### 2. Image parity

The MP's `cy-icon` glyphs (`plus`, `clock`, `tab-me`, `lock`, `info`, `warning`, `check`, `more`) are drawn line icons. They are not shipped images and have no row in `docs/mp-assets/mapping.md`, so they stay SF Symbols. The table lists every image slot (`src=`, default and fallback images, and `cy-empty` art).

| Page | MP image slot | App now | Status |
|---|---|---|---|
| privacy | `mediaPreviewUrl` (own media, remote) | remote image | ok (no default) |
| agreement | none | — | — |
| deregister | `cy-empty kind="no-permission"` (glyph `lock`) | `CYEmptyState` glyph | ok (glyph, not an image) |
| pass reveal | `cy-frames` intro / idle sheets (`frames.js`) | `MPAsset.Other.keyIntro0…13`, `keyIdle0…11` | ok (round 2) |
| pass reveal | merchant `cy-empty kind="empty"` → `empty_state_bg` + `empty_state_figure` | `MPAsset.EmptyState.emptyStateBg` + `emptyStateFigure` (via `CYEmptyState(systemImage: "tray")`) | **fixed** (was the SF Symbol `key`) |
| fabu | remote node, story, cast and material images via `img.fit` | remote images | ok (no default asset) |
| fabu | route map pins | numbered circles | ok (MP draws numbered pins; `map-pin.png` is only a fallback; round 2) |
| temp | `/pages/publish/images/icon_tag_check.svg` | `MPAsset.FeatureIcon.iconTagCheck` | ok (round 2) |
| temp | `formData.imgUrl \|\| defaultCover` (`gameTemplateCover` → `/images/interaction-templates/*.svg`) | `MPAsset.BannerCover.blindTaste`, `silentOrder`, `diyDrink`, `musicCorner`, `midnightRadio`, `lowCarbon`, `dailyCitySign` | **fixed.** Matched by title first, then by the first enabled mechanic section, as in the MP (`TemplateInteractionDefaultCover`). |
| temp | option, question, medal and scene images (`choice.img`, `questionImg`, `medalImg`, …) | remote images / pickers | ok (user content) |
| activity | `/images/icon_right.png` | SF `chevron.right` | ok (system-control glyph per mapping) |
| activity | `d_mbico1.png` / `d_mbico2.png` | `MPAsset.FeatureIcon.dMbico1` / `dMbico2` | ok (round 2) |
| activity | `icon_date3.png` | system `DatePicker` | kept (native iOS rule, round 2) |
| activity | `subpackageMember/images/icon_star.png` | — | commented out in the MP |
| activity | collaborator `item.avatar \|\| d_profile.png` | — | **open.** The app's 合作者 row shows a count only; the draft holds member ids and no profile data. Rendering rows needs a collaborator profile read (**Cursor**). |
| activity | template row `item.imgUrl` | remote image | ok |
| template-intro | featured covers (remote) | remote | ok |
| square detail | post avatar `memberAvatar \|\| d_profile.png` | `MPAsset.AvatarDefault.dProfile` fallback | ok (round 2) |
| square detail | comment avatar + `icon_jia` | `dProfile`, `MPAsset.FeatureIcon.iconJia` | ok (round 2) |
| square detail | `cy-empty kind="empty"` (社区暂未开放, 这条帖文暂不可用) | `CYEmptyIllustration(kind: .generic)` | **fixed** (was `doc.text.magnifyingglass`) |
| square detail | `cy-completion-share-card` medal gold/silver/bronze | — | open (C-S10; `SquarePost` has no medal fields; **Cursor**) |
| square detail | share `icon_share` | SF `square.and.arrow.up` | ok (system-control glyph) |
| team detail | seat strip `memberAvatar \|\| d_profile.png` + 队长 crown | `TeamDetailSeatStrip` with `MPAsset.AvatarDefault.dProfile` | **fixed** (new; the detail page had no seat strip) |
| team detail | member rows `memberAvatar \|\| d_profile.png` | `dProfile` | ok (round 2; Core decodes no avatar) |
| team detail | QR `qrSheet.qr` | remote | ok |
| team join | seats `cy-icon tab-me` / `plus` | SF `person.fill` / `plus` | ok (glyphs) |

### 3. Copy

Overrides are in `docs/port/strings/fix-r3-account-publish-b.json` (en + zh-Hans). One feature-table edit was made in place, as in round 1.

| Key | Was | Now (MP) | Where in the MP |
|---|---|---|---|
| `mp.reveal.linePaid %@` | 到 %@ · 价格都是 ¥0 | 到 %@ | reveal/index.js `_paidCopy` |
| `fixr3.square.commentsFailed` (new) | (generic 加载失败) | 评论加载失败 | square/detail wxml |
| `fixr3.square.moreCommentsFailed` (new) | (generic) | 更多评论加载失败 | square/detail wxml |
| `team.member.unnamed` | 玩家 | 城瘾玩家 | team/detail wxml + js |
| `team.loading` | 正在核对队伍状态… | 正在确认队伍状态… | team/detail wxml |
| `team.leave` | 查看退队确认 | 退出队伍 | team/detail wxml |
| `team.disband` | 查看解散确认 | 解散队伍 | team/detail wxml |
| `team.invite.copy` | 复制邀请码 | 复制加入码 | team/detail QR sheet |
| `team.invite.copied` | 邀请码已复制，尚未发送邀请。 | 加入码已复制 | team/detail js |
| `team.invite.previewOnly` | 复制邀请码后发给队友 | 复制加入码后发给队友 | (same term as the MP) |
| `team.join.empty` / `.emptyDetail` | 没有找到这支队伍 / 请让邀请你的人重新发送邀请链接 | 邀请暂时不可用 / 请让队长重新分享后再试 | team/join js |
| `fixr3.team.seat.captain` (new) | — | 队长 | team/detail seat crown |
| `settingsNative.legal.effectiveDate` | 生效日期 | 生效日期： | agreement wxml footer |
| `member.media.denied` (MemberProfile table, edited in place) | 暂时无法显示你的媒体，请刷新重试 | 当前账号暂不能读取本人媒体，请刷新重试 | privacy wxml |
| `member.media.signedOut` (MemberProfile) | 登录后查看我的媒体 | 登录查看本人媒体 | privacy wxml |
| `member.media.type.model` (MemberProfile) | 3D 模型 | 模型 | privacy js |
| activity section header (inline `CoreLoopCopy`) | 活动介绍 | 活动说明 | activity wxml |

Checked and already equal to the MP: deregister (rounds 1–3), the square detail error shells and the avatar menu, template-intro, the pass reveal copy (other than the paid line), and the team recovery buttons.

Not done: **fabu** (about 2,000 lines of wxml), plus the temp editor's game-module sub-forms. A full pass is size L. I compared titles and primary buttons only, and those match.

### 4. P2 / P1 rows

- **B-PR-03:** closed (see Flows).
- **Pass reveal timeline:** the MP DOM timeline is gradient 3000, eyebrow 3400, title 3550, line 3750 and button 4050 ms. The app used the old shard timings (1500–2450 ms), so the text showed before the key had formed. It now matches the MP. 跳过 shows at 600 ms and goes away when the 83-frame intro ends (MP `idleOn`).
- **Still open, unchanged from round 3 (Core/Cursor or test-coordinated):** C-F14, C-F16-r7, C-A8, C-S10, B-PV-07-r7, and the P1s B-DR-06 (rest), C-T2/C-T12, C-T6/C-T13/C-I8, C-F2/C-F4/C-T5 (rest) and C-F8.
- **C-A9-r7 and C-I9-r7:** unchanged, for the reasons given in round 3.

### 5. Accessibility lint

`python3 -B tools/check_a11y_lint.py` reports 1 new finding: `App/ClubKit/ClubWorkbenchKit.swift:261`, an unlabeled share `Image` inside `glyph`. It is already on `origin/ui/combined-r7` `4ef0a2840` and sits in the club area, so I did not change it, to avoid a cross-area conflict. **Club F-agent:** add `.accessibilityHidden(true)` after `.contentShape` (the parent button has a label). Every image added this round is `.accessibilityHidden(true)`, placed after the Image-only modifiers. The seat strips read as one combined label.

### Not compiled. The coordinator should check:

- `.onChange(of: route) { _, next in … }` on `PassRevealView`. `MPParityRoute` is `Hashable`.
- `@Environment(\.dismiss)` added to `PassRevealView`.
- `SquareIssueView(error:retry:title:)`: the new `title` var (default nil) comes after `retry`. Existing trailing-closure calls still bind to `retry`.
- `TemplateAuthoringCoverHeader(…, defaultCover:)` and `TemplateInteractionDefaultCover` (uses the public `TemplateAdvancedDraft.enabled(_:)`).
- `TeamDetailSeatStrip`: `ForEach(Array(members.enumerated()), id: \.offset)` inside the file-private `FlowSeats` layout.
