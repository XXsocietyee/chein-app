# Receipt: fix/r3-account-publish-a (wave ×10, Claude F-agent, account-publish half a)

- **Brief:** `origin/design/handoff-r2:docs/briefs/wave-x10.md`. Layer: App/ only (plus three contract pins and two doc catalogues).
- **Base:** `origin/ui/combined-r7` (7fdfad1f1), then `origin/restyle/r4-me-account` and `origin/restyle/r2-club-social` merged first (both clean), because they touch this half's files (AccountView, MemberHomeHeader, ProfileEdit*, ProfileParticipantsView, AccountCollectionFavoritesView, Settings*, AccountComplianceViews, SocialPublicProfileView, ClubHomeView).
- **Half a = the first 11 pages of the round-1 audit list** (`origin/audit/parity-account-publish`): member/index, userinfo, gerenziliao, mylike, address, addressinfo, crop, talent/list, shezhi, shezhi/about, shezhi/marketing.
- **Gap sources used:** the r7 fix queue `origin/audit/parity-r7-account-publish:docs/audit/parity-r7/account-publish.md` (Claude-owned rows for these pages), the round-1 audit, and `review/r7-rev-{a,b,c}` (no finding touches these files).
- **No compiler in the cloud.** Every API used was grepped on this branch before use. The coordinator's build is the first compile.
- **Strings:** `docs/port/strings/fix-r3-account-publish-a.json` (24 keys, xcstrings format). 6 of them **override** existing keys on purpose (A-COPY-r7 and A4-08): `social.interests` 兴趣标签, `profile.incompleteLink.backHome` 返回, `participant.form.save` 保存参与人信息, `participant.form.add` / `participant.form.edit` 参与人信息, `playerGap.cityFavorites.empty` 暂无收藏的据点. The other 18 are new.
- **Fixture routes:** `docs/port/accept/f-account-publish-a.txt`.

## Fixed, by page

| Page | ID | What changed | Files |
|---|---|---|---|
| member/index | A1-04 | Avatar is a 72 pt control (pen badge, VoiceOver 编辑个人资料) that pushes 个人资料. | MemberHomeHeader.swift, AccountView.swift |
| member/index | A1-07 | 积分 opens 积分明细 (`WalletLedgerView .assetPoints`) directly; an `info.circle` (44 pt, 如何获取积分) opens 积分任务 (`WalletPointsTasksView`) as a medium/large sheet. | MemberHomeHeader.swift, AccountView.swift |
| member/index | A1-09 | The ¥ 账户余额 block is a button that opens the wallet. | MemberHomeHeader.swift, AccountView.swift |
| userinfo | A2-03 | 关注 toggles in place: `SocialProfileInlineFollowButton` prepares + confirms the reviewed `.toggleFollow` command, reads 处理中… while it runs, flips to ✓ 已关注 on the acknowledged receipt with a success haptic, and shows an inline failure line. The separate 关系 row is gone for other members (kept for self / read-only viewers). | SocialPublicProfileView.swift |
| userinfo | A2-07 | 探索作品 images open a full-screen pager (i/n title, 关闭). | SocialPublicProfileView.swift |
| userinfo | A2-09 | Counters use `.cyText(.sectionTitle)` (MP 18 bold); the fallback avatar glyph uses a token, not `.font(.title2)`. | SocialPublicProfileView.swift |
| userinfo / addressinfo | A-COPY-r7 | 兴趣标签, 返回, 保存参与人信息, 参与人信息 (string overrides above). `objects.title` 藏品册 vs MP 藏品 left for the owner, as the queue says. | strings fragment |
| gerenziliao | A3-11-r7 | Save shows 正在保存资料 with a spinner, then the page's 资料已保存 status plus a success haptic for 0.9 s before going back. A failed save stays on the page with 资料没有保存成功 and 重试保存. | ProfileEditView.swift |
| gerenziliao | A3-09 (part) | Row chevron uses the system disclosure size (footnote semibold, tertiary), not `.font(.caption)`. | ProfileEditView.swift |
| mylike | A4-09-r7 | The `pages/mylike/mylike` link host (`MPFavoritesLinkHost`) wires topic and post taps through the same favourite navigation owners and destinations as 我的. | MPReviewedPageScreen.swift |
| mylike | A4-04 (topics) | Each favourite topic card has a share button (`PublicContentShareLink.topic`). | AccountCollectionFavoritesView.swift |
| mylike | A4-06 | Topics and posts auto-load the next page from the last row (加载更多 stays as the VoiceOver / failure fallback). | AccountCollectionFavoritesView.swift |
| mylike | A4-08 | Page-local 据点 tab key; empty copy 暂无收藏的据点; the 据点 list has a labelled loading state and a failure line with a 44 pt 重试 instead of a bare spinner / button. | AccountCollectionFavoritesView.swift, PlayerGapViews.swift |
| address | A5-04 | Toolbar refresh removed; pull to refresh is the one refresh. | ProfileParticipantsView.swift |
| address | A5-05 | The purpose line 用于报名联系和到场核验 is shown once as the section footer, not on every row. | ProfileParticipantsView.swift |
| addressinfo | A6-04 | Name and phone are native `LabeledContent` rows with a red `*` (VoiceOver hint 必填); the in-form hero header is gone (the inline nav title is the one title) and the purpose line heads the fields. | ParticipantFormView.swift |
| addressinfo | A6-05 | After a confirmed save: 参与人信息已保存 + success haptic for 0.7 s, then back. | ParticipantFormView.swift |
| crop | A7-04 | No `CYHeroHeader` / `cyHeroScreen()`. Standalone (`showsNavigationTitle: true`) the inline nav title reads 裁剪 or 裁剪 i/n; embedded in a host form a compact 裁剪 i/n header stands in. This also fixes a real bug: `cyHeroScreen()` blanked the **host page's** navigation title in ProjectStoryImageAuthorView and TemplateMediaReviewPanel. | MiniCropView.swift, MiniCropFixtureHost.swift |
| crop | A7-07 | VoiceOver adjustable action zooms the canvas in 25% steps; the value reads the zoom %. | MiniCropView.swift |
| crop | A7-08-r7 | Waiting state 正在准备图片 over the canvas until the frame is measured; the source error shows 图片没能打开，请重试或使用原图 (`pages.crop.error`) instead of the generic failure. | MiniCropView.swift |
| talent/list | A8-05 | The 帖文 tab no longer shows `CreativeSquareAuthorDeleteSection` or the bare "—" placeholder. | ClubHomeView.swift |
| shezhi | B-SZ-15-r7 | 邀请与收益 row after 我的收藏 for players, on the same `journeyPromo` binding as 我的 (hidden when the binding is absent or the viewer is a merchant). | SettingsView.swift |
| shezhi | B-SZ-12 | `shezhi?scene=` now lands on settings-profile → 个人资料, settings-feedback → 投诉建议, settings-likes → 我的收藏, settings-how-to-play → 城瘾玩法; settings-deregister unchanged; settings-identity-picker and unknown scenes open Settings. | MPReviewedPageScreen.swift |
| about | B-AB-04 | Product name 城瘾 (was 「chein - 城瘾」); QR glyph uses a token. | SettingsAboutView.swift |
| about | B-AB-05 | Copy-phone is a 44 pt button inside the contact row (status line under it); the bottom inset pill is gone. | SettingsAboutView.swift |
| marketing | B-MK-02 | No ComplianceHeader intro, no `marketingOriginal.scope` line, no `marketingOriginal.current.title` header, no per-channel `.detail` line. | AccountComplianceViews.swift |
| marketing | B-MK-05 (toast) | 已同意 / 已退订 toast once the server-confirmed row value matches the request. The confirm sheet itself stays (owner call). | AccountComplianceViews.swift |
| marketing | B-MK-06b | Merchant name `.cyText(.bodyMedium)`, initial tile `.cyText(.bodyMedium, weight: .bold)`, channel `.cyText(.body)`. | AccountComplianceViews.swift |
| marketing | B-MK-07-r7 | Signed-out link: 登录后查看营销消息设置 + 登录 (opens 我的, the sign-in home) instead of the unavailable state. | MPReviewedPageScreen.swift |

**Contract pins updated** (they pinned the old behaviour, not a contract): `test_profile_draft_review_restore` (save guard now keeps the failure on the page), `test_profile_self_edit_return` and `test_profile_self_medals` (关注 is `SocialProfileInlineFollowButton`, still the reviewed `.toggleFollow` command). `docs/account-collection-localizations.json` gained the two new `accountCollection.*` keys (catalogue test).

## Local checks (text-only; no Swift compiler here)

- `tools/check_typography_lint.py`: PASS (no new raw fonts, back chevrons, hidden backs or large titles).
- ContractChecks for every test that names a touched file: all pass except failures that already fail on the merge base `7ab351990` with the same counts: `check_member_home_pkg02`, `check_wallet_earnings_overview`, `test_appsec_review`, `test_c11_ops_support_projections`, `test_category_roam_registration`, `test_club_operations_contracts` (missing `flutter_source`), `test_design_system_component_contracts`, `test_design_token_unification_contract`, `test_journey_role_view`, `test_merchant_project_workspace_entry`, `test_play_experience_contracts`, `test_play_gameplay_mode_separation`, `test_profile_avatar`, `test_profile_reload_discard`, `test_social_guide_templates`, `test_workshop_paid_professional`. Zero new failures.
- Acceptance run: not available from this session (the workflow is not on this branch). The coordinator's compile + acceptance is pending.

## Left open, with reasons

| ID | Why not here | Who |
|---|---|---|
| A1-01 own-profile composer | Gemini row (unpark AP-G01). | Gemini |
| A1-02, A1-08, A3-06/A6-02, A8-02/A8-03, B-SZ-11, B-SZ-13, B-MK-05 (confirm sheet) | Owner decisions in the r7 queue. | owner |
| A2-02 merchant subject → merchant home | `SocialPublicProfile` has no role / merchant field to branch on. **Core request (Cursor):** decode the subject role (or a `isMerchant` / merchant id) from `api/user/public-info`, then the view swaps to `PublicMerchantHomeView`. | Cursor → Claude |
| A2-03 (发消息 half) | 发消息 still pushes the reviewed `.startChat` editor: the profile view has no session handle to open the IM chat from a `conversationID`. Needs an `onOpenChat(conversationID)` hook from the hosts. | Claude follow-up |
| A2-08 club posts in 帖文 | M; needs an author-filtered club feed reader passed into the profile. | Claude follow-up |
| A2-10-r7 coop bar | Gemini row (parked AP-G02). | Gemini |
| A3-01 uploads | Cursor row (compose `ProfileAvatarDependencies`; upload-grant approval). | Cursor |
| A3-05 phone bind | Owner must rule a native bind path. | owner |
| A3-09 (chips half) | Showing preference names needs the category list the picker loads; left as the count. | Claude follow-up |
| A3-10 hero section on 个人资料 | M visual; low value next to the native Form rule. | Claude follow-up |
| A4-01 据点 → place detail | Gemini row; no POI detail screen exists. | Gemini |
| A4-04 (据点 share) | No public POI share link exists in Core (`PublicContentShareLink`). **Core request.** | Cursor |
| A4-05 post card with images + ··· menu | M; the shared card change would also touch square files outside this half. | Claude follow-up |
| A5-01 dead `onSelect` | Kept: WIRE-2 documents it as the select-mode hook for a sign-up caller; removing it is a Core/flow decision. | coordinator |
| A6-01 bound phone read-only | The app only has the masked phone (`ProfileEditCoordinator.phoneDisplay`); using it needs the real bound number. **Core request.** | Cursor |
| A7-01/03/05 overlay | Gemini row (fix and unpark `MiniCropGapOverlay`). | Gemini |
| A7-02 one cropper for all pickers | L; avatar / cover / template croppers each own their export path. | Claude follow-up |
| A7-06 `canUseOriginal` | Cursor row (Core). | Cursor |
| A7-08-r7 (重试 half) | `MiniCropSession` has no per-image retry. **Core request:** `retryCurrent()` / `reset()` (also needed for 还原). | Cursor |
| A8-06 管理 on owned cards | M; needs the roster-management sheet hosted from the list. | Claude follow-up |
| A8-09-r7 club hub share | No talent/list universal link in `PublicContentShareLink`. **Core request:** `clubHub(tab:)`. | Cursor |
| A8-10-r7 feed paging | Cursor row. | Cursor |
| B-SZ-05, B-SZ-09, B-SZ-14-r7 | Cursor rows (Core phases / refetch). | Cursor |
| B-SZ-10 regroup Settings sections | M structural change of the whole Settings form; best done with the owner's Settings decisions (B-SZ-11/13). | Claude follow-up |
| B-MK-01 master 接收营销消息 toggle | Comes from hand-off MC-43, not the MP; each flip goes through a per-row confirm sheet (owner call B-MK-05), so a master toggle needs a batch write in Core first. | owner + Cursor |
| B-MK-06 merchant logo | Cursor row (decode `merchantLogo`). | Cursor |

## MP-asset consistency

- The 我的 avatar pen badge uses the SF Symbol `pencil` as a stand-in. The MP uses `/subpackageMember/images/icon_pen.svg`. `cursor/mp-assets` does not exist yet, so there is no `MPAsset` accessor; swap it when C7 lands (TODO in MemberHomeHeader.swift).
- Every other glyph added here is a system control (info, share, close, copy, checkmark, chevron).

## In-flight branches skipped

- `restyle/r4-me-account`, `restyle/r2-club-social`: merged first, built on.
- `restyle/r1`, `r3`, `r5`, `r6`: visual only, no file overlap with these fixes.
- `gap/g2-ops` (parked AccountPublish views): not touched.
- `cursor/*`, `port/*`: no overlap.

## Round 2 (2026-11-24)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round2.md` + `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` (Core K1–K10, W1, C7). One conflict, `tools/check_typography_lint.py`: took combined-r7's (newer) version. Re-checked before the final push: no newer combined-r7 commits.
- **Review findings (`review/r7-rev-a`, `-b`, `-c`):** no row names a file or page of this half. Nothing to fix.
- **Cursor wiring:** no `cursor/wire-account-publish` branch exists. The App-side items Cursor handed to the F-agent in `cursor-core-account-publish.md` § "F-agent App changes" for this half's pages are done below (B-SZ-05, B-SZ-09/14, B-MK-06, A8-10). The deregister / team / square rows of that list are half b's pages.
- **New files:** `App/AppSession+SocialConversation.swift`, `App/AccountPublishMPGlyph.swift` (`AccountPublishMPGlyph`, `AccountPublishMPRowIcon`, `AccountPublishLevelBadge`; names prefixed to avoid colliding with other agents' helpers), `App/AppSession+SettingsAccountProfile.swift`. Both are under the existing `App/*.swift` glob.

### Fixed in round 2

| ID | What changed | Files |
|---|---|---|
| B-SZ-14-r7 | Settings re-reads `POST /api/user/info` (`SettingsAccountProfileClient.refresh`) on appear and on account change; the fresh role drives the page facts and the identity rows (session role stands in until it answers; a late answer after sign-out / account switch is dropped). | SettingsView.swift, AppSession+SettingsAccountProfile.swift |
| B-SZ-09 | 403 ⇒ `sessionFact(accessDenied: true)`; the header shows 当前身份不能查看账号信息 / 点击刷新并确认当前账号权限 as a 44 pt button that reads again (`retriesProfileOnTap`). | SettingsView.swift |
| B-SZ-05 | 成为俱乐部主理人 uses `SettingsClubPickerService.resolveHostRoute(isClubLeader:)` with the fresh `isClubLeader`, and `isOffered(toRole:isClubLeader:)` hides the rows for a leader. Owned club ⇒ `ClubDetailView(requestedTab: .manage)`; leader without a club ⇒ the club create workspace sheet (`ClubOperationsWorkspaceView(target: .create)`; falls back to host status when operations are not composed); otherwise host status; failure ⇒ toast. The several-clubs chooser is gone (MP opens the first). `loadSettingsClubEntry` is untouched. | SettingsAccountEntries.swift |
| B-MK-06 | Marketing merchant tile shows `merchantLogo` (https only) over the initial; `""` keeps the initial. | AccountComplianceViews.swift |
| A8-10-r7 | 发现 home feed (no club) pages: `ClubCommunityFeedCursor` in the view model, reach-bottom row (`club.community.feed.loadMore`) calls `.feed(limit: 20, beforeID:)`. A next page (posts or feed) now appends instead of blanking the list first. Fixture feed payload gains `"hasMore": false`. | ClubCommunityViews.swift, ClubCommunityFixture.swift |
| A4-05 | 收藏 post cards show images (`showImages: true`); 取消收藏 moved into a ··· `Menu` on the card (`ProfileFavoriteRemovalEntry(presentsAsMenu: true)`, same reviewed flow and sheet; the default button style is unchanged for the removal UI-test fixture). | AccountCollectionFavoritesView.swift, ProfileFavoriteRemovalView.swift |
| A3-09 (chips) | 路线偏好 shows the chosen preference names as chips under the count, from the picker's own `discoveryCategories(type: 1)` read; unknown ids are skipped, a failed read shows only the count. | ProfileEditView.swift |
| A2-03 (发消息) | 发消息 acts in place: `SocialProfileInlineStartChatButton` prepares + confirms the reviewed `.startChat` command (`api/im/start`), reads 处理中…, and pushes the acknowledged `conversationId` into the IM chat (`MessagingHistoryView`, same as the `im/chat` link). Hosts opt in through the `\.socialConversationDestination` environment (`AppSession.socialConversationDestination`): the `pages/userinfo` link host and 我的 → 邀请记录 profiles. Other hosts (square, club, fixtures) have no destination and keep the reviewed editor, so `purpose: .startChat` stays. Failure: 没能打开会话，请重试 inline. | SocialPublicProfileView.swift, SocialInviteHistoryView.swift, AccountView.swift, MPReviewedPageScreen.swift, AppSession+SocialConversation.swift |
| A7-06 | Already closed on combined-r7: `CropPageFacts.canUseOriginal` drives 使用原图. No change. | — |

### MP assets applied (`docs/mp-assets/mapping.md` rows)

- [x] `MPAsset.FeatureIcon.iconQaPerson` — Settings signed-out profile row and the 403 row
- [x] `MPAsset.FeatureIcon.iconFlagBlue` — 成为俱乐部主理人 (full colour, not template)
- [x] `MPAsset.FeatureIcon.iconShop` — 成为商家
- [x] `MPAsset.FeatureIcon.iconLcCompass` — 城瘾玩法
- [x] `MPAsset.FeatureIcon.iconHeart` — 我的收藏
- [x] `MPAsset.FeatureIcon.iconLcGift` — 邀请与收益
- [x] `MPAsset.FeatureIcon.iconLcLockKeyhole` — 隐私与定位
- [x] `MPAsset.FeatureIcon.iconLcMessageSquareText` — AI 对话记录 (both the Settings row and the compliance-section row)
- [x] `MPAsset.FeatureIcon.iconLcTicket` — 营销消息与优惠券
- [x] `MPAsset.FeatureIcon.iconLcShieldAlert` — 帖文处置与申诉
- [x] `MPAsset.FeatureIcon.iconLcMegaphone` — 投诉建议
- [x] `MPAsset.FeatureIcon.iconPrivacy` — 我的申诉
- [x] `MPAsset.FeatureIcon.iconAgreement` — 发票; 关于 用户服务协议 / 隐私保护指引; Settings legal rows other than 用户服务协议
- [x] `MPAsset.FeatureIcon.iconLcScrollText` — Settings 用户服务协议
- [x] `MPAsset.FeatureIcon.iconLcUserRoundX` — 账号注销
- [x] `MPAsset.FeatureIcon.iconLcInfo` — 关于
- [x] `MPAsset.FeatureIcon.iconLogout` — 退出账号
- [x] `MPAsset.FeatureIcon.iconHeadset` — 关于 联系我们 (fallback row and the phone row)
- [x] `MPAsset.BrandLogo.cyLogoMark` — 关于 logo (was the bundled `SettingsBrandMark` over cover art)
- [x] `MPAsset.FeatureIcon.iconPen` — 我的 avatar pen badge (round-1 TODO closed)
- [x] `MPAsset.FeatureIcon.iconSet` — 我的 toolbar settings button
- [x] `MPAsset.BadgeMedal.group2` … `group5` — 我的 level pill for `levelId` 2–5
- [x] `MPAsset.AvatarDefault.dProfile` — 我的 header and 个人主页 head when there is no avatar (replaces the lettermark, as the MP does for players)
- [x] `MPAsset.FeatureIcon.object3d` — 我的 藏品 row tile
- [x] `MPAsset.BannerCover.pagesMylikeImagesMer1` — 收藏 据点 row without a cover
- Kept SF Symbols (system-control glyphs per the brief): `pagesMylikeImagesIconUp` (share), `pagesGerenziliaoImagesDel` and `pagesAddressImagesDClose` (delete / close ✕), chevrons, the ··· menu.
- Not applied, no matching surface here: `dSctb` and `pagesGerenziliaoImagesMer1` (upload tile / hero; uploads are blocked on A3-01 and the native Form has no hero), `medal3d` / `stamp3d` (no album pile on the native 我的), `subpackageMemberImagesIconQaPerson` (经营团队 row is merchant-side, not on this page), the `subpackageMemberImagesTags*` set (tag library, used by the preference picker owned by `ContextualPickers.swift`), `iconBell` (talent/list has no messages button on the native 俱乐部 root; the tab bar owns 消息), the `images_cards_*` club-card glyphs and `defaultCover` (drawn inside `App/DesignSystem/CYClubCards.swift`, shared with the club area: left to the club F-agents to avoid a collision).

### Owner decisions (1124)

- #9 two-decimal money: the only money on these pages is 我的 ¥ 账户余额, already `.currency(code: "CNY").precision(.fractionLength(2))` (`MemberBalanceDisplay`). There is no shared Core money formatter on combined-r7 yet. **Core request (Cursor):** one shared formatter; `MemberBalanceDisplay` should then call it.
- #12 / #3 / #6 money TEST-only: no money write on these pages. #8 arrival lock, #10 game-kit gate, #7 cast fixtures: not on these pages.

### Checks

- `tools/check_typography_lint.py`: PASS.
- `tools/check_a11y_lint.py`: 11 "new" items left, all pre-existing on combined-r7 (12 there) and none in this half's files; this branch removed SocialPublicProfileView:523 and the baselined MemberHomeHeader `person.fill` lettermark.
- ContractChecks naming any App file this branch changed (294): 18 fail on `origin/ui/combined-r7` and the same 18 on this branch. Zero new failures.
- No compiler here; every API was grepped on this branch (`SettingsAccountProfileClient`, `SettingsClubPickerService.resolveHostRoute`, `ClubCommunityFeedCursor`, `ClubOperationsWorkspaceView`, `ClubR1WrapLayout`, `QuestifyCardArtwork.safeURL`, `PlayerFeedRemoteImage`, `MPAsset.*`).

### Still open after round 2

| ID | Why | Who |
|---|---|---|
| A2-02 | Still no role / merchant field on the public profile read. | Cursor |
| A2-03 (发消息, other hosts) | Square / club / activity hosts can opt in with one `.environment(\.socialConversationDestination, session.socialConversationDestination)` line on their `SocialPublicProfileView`; those files belong to other areas. | other areas' F-agents |
| A4-04 (据点 share), A8-09-r7 | No POI / club-hub link in `PublicContentShareLink`. | Cursor |
| A6-01 | Core keeps only the masked phone (`ProfileBoundPhoneDisplay`); `DeregistrationBoundPhone` exists but belongs to the compliance (deregister) session. Needs a profile-side bound-phone value. | Cursor |
| A7-08-r7 (重试) | `MiniCropSession` still has no per-image retry. | Cursor |
| A3-01, A1-01, A2-10, A4-01, A7-01/03/05 | Unchanged (Cursor upload grant / Gemini unparks). | Cursor / Gemini |
| A2-08, A3-10, A7-02, A8-06, B-SZ-10 | Unchanged from round 1 (M/L, or wait on the owner's Settings calls). | Claude follow-up |
| Owner rows | Unchanged (A1-02, A1-08, A3-05, A3-06/A6-02, A8-02/03, B-SZ-11/13, B-MK-01, B-MK-05 sheet). | owner |

## Round 3 (2026-11-24 evening)

Base: merged `origin/ui/combined-r7` `b0ac0108d` (clean merge, no conflicts).

### Round 3 · re-applied
I checked every round-1/round-2 commit of this half against the new base, file by file (`git diff <c>^ <c>` vs HEAD, then a line-level look at every file the integration changed). Only Settings lost hunks: `SettingsView` and `SettingsAccountEntries` were restored to Cursor's side.

| Lost hunk (round 2, `69d2f8243`) | Re-applied on Cursor's wiring | File |
|---|---|---|
| B-SZ-04 signed-out row icon → `MPAsset.FeatureIcon.iconQaPerson` | yes | SettingsView.swift |
| B-SZ-09 403 row icon → `iconQaPerson`; second tap dropped while the read runs; 44 pt row | yes, on Cursor's `refreshAccountProfile()` / `accountProfileLoading` (no second profile read added) | SettingsView.swift |
| 城瘾玩法 → `iconLcCompass`; 邀请与收益 → `iconLcGift` | yes | SettingsView.swift |
| 成为俱乐部主理人 → `iconFlagBlue` | yes, on Cursor's `SettingsClubHostRouter` button (routing unchanged) | SettingsAccountEntries.swift |
| B-MK-06 merchant logo only from a safe https URL | the other half's `merchantMark` kept; it now goes through `QuestifyCardArtwork.safeURL` (was `URL(string:)`, any scheme) | AccountComplianceViews.swift |

Not re-applied, because Cursor's version already does it: the fresh `POST /api/user/info` on appear and on account change (B-SZ-14-r7), the `.denied` phase (B-SZ-09), and the host route (B-SZ-05, now `SettingsClubHostRouter`, with the create workspace pushed instead of shown as a sheet).

Still present on the base, checked: A4-09-r7 `MPFavoritesLinkHost`, B-SZ-12 scene links, B-MK-07-r7 signed-out link state, A2-03 `socialConversationDestination`, A8-10-r7 feed cursor, the 收藏 / 申诉 / 投诉建议 / 隐私 MP assets, and every other file of this half (no hunk lost).

### Fixed in round 3
| ID | Change | File |
|---|---|---|
| MP asset `iconLcStore` (mapping row 247) | Merchant 品牌中心 card shows the MP store icon in place of the initial (shezhi.wxml:14) | SettingsView.swift (`SettingsAccountCard.brandMark`) |

### Flow edges (Gemini `flows-g1/g2`, "for Claude") in this half
| Edge | Result |
|---|---|
| `shezhi.js:158` merchant → `merchant/decor` | Already routed: `ProfileSettingsProfileAccess` target `.brand` opens `MerchantOperationsDocumentView(destination: .decor)`. |
| `shezhi.js:167` → `promo` | Done in round 1 (B-SZ-15-r7). |
| `talent/list.js:122` storeCard → `market/passes` | Already mounted: `MPPassExploreCard` on the 帖文 tab (ClubHomeView.swift:77). |
| `talent/list.js:583` 创建俱乐部 (leader → create, else apply) | Already handled by `ClubOperationsEntryButton(target: .create, hostApplication:)`. |
| `mylike.js:660` post / topic | Done (A4-09-r7). |
| `mylike.js:435` → `poi-detail` | A4-01, Gemini (no POI detail screen). |
| `address.js:44` → addressinfo | In-app: `ProfileParticipantsView` pushes `ParticipantFormView`. |

### Review / audit rows
- `review/r7-rev-a/b/c`: no Claude-owned row for this half's pages (B-14 is messaging; F-C24 is owner).
- `parity-r7` P1 (Claude) for this half: all done, except A2-02, A4-04, A6-01, which still wait on Core (see below), and A7-02 (L).
- A8-06 (管理 on owned cards): **closed, no change.** The current MP `talent/list` (UI-19, 2026-09-18) has no 管理 on club cards; cards only open the club page.

### MP assets left as SF Symbols (rule: system-control glyphs)
- `iconUp` (mylike 分享) stays `square.and.arrow.up`.
- `dClose` stays `xmark`.

### Checks
- `tools/check_a11y_lint.py`: 17 new / 130 current, the same as the base without this round. None in this half's files.
- No new string keys this round.

### Still open after round 3
| ID | Why | Who |
|---|---|---|
| A2-02 | `SocialPublicProfile` still has no role / merchant field. | Cursor |
| A4-04 (据点 share), A8-09-r7 | `PublicContentShareLink` has no POI / club-hub link yet. | Cursor |
| A6-01 | No profile-side bound-phone value. | Cursor |
| A7-08-r7 (重试) | `MiniCropSession` has no `retryCurrent()`. | Cursor |
| A3-01, A1-01, A2-10, A4-01, A7-01/03/05 | Upload grant / Gemini unparks. | Cursor / Gemini |
| A7-02 | L: one cropper for avatar, cover and template. | Claude follow-up |
| A2-08, A3-10, B-SZ-10 | P2. B-SZ-10 waits on the owner's Settings calls (B-SZ-11/13). | Claude follow-up / owner |
| Owner rows | Unchanged. | owner |

## Round 4 (2026-11-25)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round4.md` (+ `wave-x10.md`, `owner-decisions-1124.md`). Gemini is out of quota, so this round also covers the MP-alignment work for this half's pages.
- **Base:** merged `origin/ui/combined-r7` `4ef0a2840` (clean; the branch then matched the base file for file, so no round-3 hunk was lost).
- **No compiler here.** Every API used was grepped first: `MPAsset.BannerCover.subpackageMemberImagesMer1`, `.pagesGerenziliaoImagesMer1`, `MPAsset.BadgeMedal.medal3d`, `MPAsset.FeatureIcon.dSctb`, `MPAsset.AvatarDefault.dProfile`, `AccountPublishMPGlyph`, `palette.bgPage`, `CYColor.bgPage`, `ProfileEditSnapshot.nickname`, `participant.list.editShort`.

### 1 · Flows (`flows-g1` / `flows-g2`, edges for Claude on this half's pages)
| Edge | Result |
|---|---|
| `addressinfo.js:222` / `:225` after save: `navigateBack`, else `redirectTo` / `reLaunch` 参与人列表 | Matches. Every in-app way into the form (participant list, the `pages/addressinfo` link via `mpParityRouteDestination`, sign-up) is a push, so the MP's first choice (`navigateBack`) always applies: 参与人信息已保存 + haptic, then `dismiss()`. The app has no single-page stack, so the fallback never applies. |
| `address.js:44` → addressinfo; `mylike.js:435` / `:660`; `shezhi.js:158` / `:167`; `talent/list.js:122` / `:583` | Re-checked; unchanged since round 3 (done, or A4-01 for Gemini: no POI detail screen). |
| flows-g1 rows for these pages | None. The g1 `[GAP-CLAUDE]` rows that mention `gerenziliao` / `address` are on the topic page (another area). |

### 2 · Image parity (each MP image slot on this half's pages)
| MP page · slot | MP source | App now | File |
|---|---|---|---|
| member/index · hero cover | cyp `index.js:399` `heroImg` default `/subpackageMember/images/mer1.jpg` | **New:** `MPAsset.BannerCover.subpackageMemberImagesMer1` as the identity card's row background, fading into `bgPage` (MP `.pc-page-fade`; merchant gets the light veil) | MemberHomeHeader.swift |
| member/index · settings | `icon_set.png` | `MPAsset.FeatureIcon.iconSet` (round 2) | AccountView.swift |
| member/index · avatar / pen | `d_profile.png`, `icon_pen.svg` | `MPAsset.AvatarDefault.dProfile`, `MPAsset.FeatureIcon.iconPen` (round 2) | MemberHomeHeader.swift |
| member/index · level | `group2–5.png` | `MPAsset.BadgeMedal.group2…5` (round 2) | MemberHomeHeader.swift |
| member/index · 收集册 勋章 pile | `album/medal-3d.png` | **New:** the 勋章 (badge wall) row icon is `MPAsset.BadgeMedal.medal3d` (was SF `medal`) | ProfileAccountLinks.swift |
| member/index · 收集册 藏品 pile | `album/object-3d.png` | `MPAsset.FeatureIcon.object3d` (round 2) | AccountView.swift |
| member/index · 收集册 邮票 pile | `album/stamp-3d.png` | Not applied: on 我的 the 邮票 entry is the Passport stamp grid (`PassportView.swift`, restyle-owned design: foil seals per stamp). No row to put the pile art on. | — |
| member/index · merchant 经营团队 / 工作台 | `icon_qa_person.svg`, `icon_tab_workbench.svg` | Not on the player 我的 (merchant workspace, other area). | — |
| member/index · route cover default | `route_free_cover.png` | No route-cover card on the native 我的 (orders / projects open their own pages). | — |
| userinfo · hero cover | same `mer1.jpg` default | **New:** 120 pt decorative cover row heading the profile head section | SocialPublicProfileView.swift |
| userinfo · avatar default | `d_profile.png` | `dProfile` (round 2) | SocialPublicProfileView.swift |
| gerenziliao · hero | `/pages/gerenziliao/images/mer1.jpg` (js:71) | **New:** `MPAsset.BannerCover.pagesGerenziliaoImagesMer1` behind the centred avatar, faded | ProfileCurrentAvatarView.swift |
| gerenziliao · avatar default | `avatarSrc \|\| /images/d_profile.png` | **New:** `dProfile` (was SF `person.fill`) | ProfileCurrentAvatarView.swift |
| gerenziliao · upload tile | `d_sctb.png` (wxml:121, :140) | **New:** 添加作品图片 / 上传二维码 rows use `MPAsset.FeatureIcon.dSctb` (was SF `photo.badge.plus` / `qrcode.viewfinder`) | ProfileAvatarDraftSection.swift |
| gerenziliao · delete ✕ | `del.png` | SF `xmark` kept (system control) | — |
| gerenziliao · `cy-icon` edit / image / chevron | design icon set | SF Symbols (system controls) | — |
| mylike · empty | `cy-empty kind=empty` → `empty_state_bg.svg` + `empty_state_figure.svg` | **New:** 主题 and 帖文 empties pass `tray`, so `CYEmptyIllustration.generic` draws `MPAsset.EmptyState.emptyStateBg` + `emptyStateFigure` (were SF `heart` / `bookmark`) | AccountCollectionFavoritesView.swift |
| mylike · 据点 cover default | `mer1.jpg` | `MPAsset.BannerCover.pagesMylikeImagesMer1` (round 2) | PlayerGapViews.swift |
| mylike · share / heart | `icon_up.png`, `cy-icon heart` | SF `square.and.arrow.up`, ··· menu (system controls, round 3) | — |
| address · delete ✕ | `d_close.png` | SF `xmark` kept (mapping row 126 says keep) | — |
| addressinfo | no image | — | — |
| crop | only the image being cropped | — | — |
| talent/list · 站内消息 | `/images/icon_bell.svg` | Not applied: the native 俱乐部 root has no messages button; the tab bar owns 消息. | — |
| shezhi · every row | `icon_*` set | All `MPAsset.FeatureIcon.*` (rounds 2–3), including `iconLcStore` on 品牌中心 | SettingsView.swift etc. |
| about · logo / rows | `cy_logo_mark.png`, `icon_agreement`, `icon_headset` | `MPAsset.BrandLogo.cyLogoMark`, `iconAgreement`, `iconHeadset` (round 2) | SettingsAboutView.swift |
| marketing · merchant logo | `merchantLogo` (remote) | https-only remote logo over the initial (round 3) | AccountComplianceViews.swift |

### 3 · Copy (MP text; fragment `docs/port/strings/fix-r3-account-publish-a.json`)
- The fragment is now in full xcstrings shape (`sourceLanguage`, `strings`, `version`); round 1–3 wrote a bare key map, and **the round-1 overrides of existing keys were not applied at integration** (`social.interests`, `profile.incompleteLink.backHome`, `participant.form.save` still read the old values in `Localizable.xcstrings`). They stay in the fragment as overrides.
- **Dropped** two round-1 overrides that were wrong: `participant.form.add` is also the list's / sign-up's 新增参与人信息 button, and `participant.form.edit` is the detail page's pill. Instead the form's nav title now uses `profile.participants.title` (参与人信息, MP addressinfo.json) for add and edit.
- **New keys (2):** `participant.list.deleteShort` 删除 (swipe action, MP address.wxml), `settings.deregister.row` 账号注销 (Settings row, MP shezhi.wxml:34; the deregister page keeps `compliance.cancellation`).
- **Overrides (17):** `profile.favoriteRemoval.open` 取消收藏, `.explanation` 确定要取消收藏吗？, `.failed` 取消没成功，可以再试一次, `.unknown` 取消结果未确认，请稍后再点确认; `accountCollection.favorites.unknown` 收藏加载失败; `participant.form.saving` 正在保存参与人信息, `.phoneHint` 请输入正确的手机号, `.rejected` 参与人信息没有保存, `.rejectedHint` 参与人信息暂时没有保存，请重试; `profile.edit.saved` 资料已保存, `.saveFailed` 资料没有保存, `.unavailable` 资料暂时不可用, `.reload` 重新加载; `club.tab.feed.noClub` 还没有帖文; `club.emptyNearby` 同城范围暂未确认; `settingsNative.legal.privacy_policy` 隐私保护指引; `social.followingCount` 关注.
- **Code copy changes:** 主题 empty drops the 遇到想体验的城市主题… hint (MP has none); swipe 编辑 uses `participant.list.editShort`; Settings 关于 row drops 版本、协议与联系; 关于 page drops the tagline and the 查看服务条款 hint (MP shows logo + 城瘾, and the two agreement rows by name only).
- **Left, with reason:** keys in other tables (`MemberProfile`: `member.card.failed` 主页资料没加载出来 vs MP 资料加载失败) need that table's own fragment, which the brief's one-fragment rule doesn't cover; `accountCollection.signInRequired` / `.failed` and `localCopy.*` are shared with coupons / other pages, so overriding them would change those pages too.

### 4 · Audit rows (`parity-r7-account-publish`, Claude, this half)
| ID | Result |
|---|---|
| A3-10 (P2) hero section on 个人资料 | **Done:** cover (above), centred avatar with the MP default, and the saved nickname (城瘾玩家 when empty) under it. 更换背景 stays on the profile page's local-cover section (`ProfileLocalCoverSection`), not repeated here. |
| A1-09, A2-07, A2-09, A3-09, A4-06, A4-08, A5-04, A5-05, A6-04, A6-05, A7-07, A7-08-r7, A8-05, B-AB-04/05, B-MK-05/06b/07-r7, B-SZ-12 | Done in rounds 1–3 (checked on the base). |
| A8-06 | Closed in round 3 (the current MP has no 管理 on cards). |
| A2-08 (P2, M) | Still open: Core has no author-filtered club feed (`ClubCommunityRequest` only has `posts(clubID:)` and `feed`). **Core request (Cursor):** a member-scoped club post read. |
| A8-09-r7 (P2) | Still blocked: `PublicContentShareLink` has no club-hub link. |
| A5-01 (P2) | Left for the coordinator (WIRE-2 keeps `onSelect` as the sign-up select hook; the second picker is in `RegistrationSheetView`, another area). |
| B-SZ-10 (P2, M) | Waits on the owner's Settings calls (B-SZ-11/13). |
| Open P1 for this half | All still wait on Core, re-grepped this round: A2-02 (no role on `SocialPublicProfile`), A4-04 (no POI share link), A6-01 (no profile-side bound phone), A7-08-r7 重试 (no `MiniCropSession.retryCurrent()`). |

### 5 · Checks
- `tools/check_a11y_lint.py`: **1 new, and it is not in this half:** `App/ClubKit/ClubWorkbenchKit.swift:261` (the club share glyph; the label sits on the parent `ShareLink`). It is already on `origin/ui/combined-r7` and belongs to the club F-agents, so I left it to avoid a conflicting edit. This half's files add 0.
- `tools/check_typography_lint.py`: PASS.
- ContractChecks naming any App file changed this round: the same failures as on the base, with the same assertions (`check_member_home_pkg02`, `test_category_roam_registration`, `test_design_system_component_contracts` (raw colours in GrowthLeaderboardView / PlayExperienceView), `test_profile_avatar`, `test_profile_reload_discard`, `test_social_account_contracts`, `test_social_guide_templates`, `test_ugc_1_2_completeness`). Zero new failures.

### Files changed in round 4
MemberHomeHeader.swift, SocialPublicProfileView.swift, ProfileAccountLinks.swift, ProfileCurrentAvatarView.swift, ProfileAvatarDraftSection.swift, AccountCollectionFavoritesView.swift, ProfileParticipantsView.swift, ParticipantFormView.swift, AccountComplianceViews.swift, SettingsSupportSections.swift, SettingsAboutView.swift; `docs/port/strings/fix-r3-account-publish-a.json`.
