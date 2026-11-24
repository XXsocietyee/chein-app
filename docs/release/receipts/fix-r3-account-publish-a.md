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
