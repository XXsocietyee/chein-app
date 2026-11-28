# mp-nav B lane — round 3 receipt (`mp/r3-nav-b`)

Works the open rows of `docs/release/receipts/mp-nav-r3.md` bottom-up (brief round3-1127 "B lanes"). One row per A-receipt row finished.

Skipped (bottom-up): "3. MP-account sync note" (A receipt OWNER REQUIREMENT 04:30) — still blocked on a backend field (`WeChatAppAuthService.Envelope` has no mini-program-origin field). M-08c partial was closed by the A lane at 15:xx.

| A-receipt row | MP → native | before | after | status |
|---|---|---|---|---|
| "pages/square/detail feed-play-card 试玩" (A receipt Re-scan 11-27 22:3x, open) | `pages/square/detail` index.js:186-193 `goPlay` → `wx.navigateTo('/pages/play/index?topicId=')` → App/SquareDetailView.swift `SquareDetailPlayCard`, App/SquareRelatedTopicView.swift, App/QuestifyApp.swift `chain3_6` | 试玩 pushed the related topic detail (play one step further), because `SquareRelatedTopicDestination` injects no play provider | new environment `squarePlayDestination` (default nil), set once at the session root to `SessionPlayRuntimeView(session:, destination: .journey(.topic(id)))` — the same page `pages/play/index?topicId=` lands on (MPReviewedPageScreen). 试玩 sets `playTopic`; `SquarePlayPushModifier` pushes play, fenced by the same square + topic read scopes as the topic push (stale selection → `SocialIssueView`), reset on post key / topic scope change. Fixtures and hosts without the session root keep the topic push. The topic id is the existing namespace-bound related topic (never `dataId` guessing). 查看主题 links elsewhere unchanged. Pin: Tests/ContractChecks/test_mp_nav_square_try_play.py. Level B, navigation only. Not compiled here | fixed |
| "pages/activity/detail → 票夹 (MP navigateTo subpackageMember/signup)" (A receipt Re-scan 11-27 21:3x, open; also "For other lanes") | MP activity detail registered CTA → `navigateTo subpackageMember/signup/index` → App/ActivityDetailView.swift `showsTicketWallet` | `.cySheet` + 关闭 (`SessionTicketWalletHost(onClose:)`), a popup for a page edge | `navigationDestination(isPresented: $showsTicketWallet)` push of `SessionTicketWalletHost(isPushed: true)` + `.cyPushedChrome()`, system back — same host as 首页 today's ticket and the landed `subpackageMember/signup/index` page. Footer pill, first tile and city CTA triggers unchanged; the unused `tileOpenedSheet` flag is no longer set for the wallet (registration sheet keeps it). Pins: Tests/ContractChecks/test_mp_nav_activity_wallet_push.py; test_activity_design_structure still passes. Level B, navigation only. Not compiled here | fixed |
| "pages/topic/index/index → pages/publish/fabu (owner 编辑, navigateTo)" (A receipt edge table, open, "flagged, not changed") | MP topic bar 编辑 → `navigateTo pages/publish/fabu/index?id=` → App/TopicDetailView.swift `showsEditor` | full-detent `.cySheet` wrapping its own `NavigationStack`, no close button (drag-only exit), while the same `topicEditorDestination` editor is already a push from template detail 用这个模板 (DiscoveryTemplateDetailView.swift:469/931): two presentations of one page | `navigationDestination(isPresented: $showsEditor)` push of `editorDestination(value.id, scope)` + `.cyPushedChrome()`, system back; ProjectEditView autosaves and keeps its own 放弃本地草稿 confirmation, so popping loses nothing; `showsEditor` resets with the other bar flags on topic key change. Owner gate (`TopicXcxFacts.ownerSaleRoute == .editor`) unchanged. Pin: Tests/ContractChecks/test_mp_nav_topic_editor_push.py. Level C (editor), navigation only. Not compiled here | fixed |
| "signed-out 我的 root ⋯ → 设置 (App/WelcomeView.swift:66)" (A receipt Re-scan 11-27 23:xx, status still `open`) | MP profile 设置 navigateTo pages/shezhi/shezhi → App/WelcomeView.swift | — | verified already a push: `navigationDestination(isPresented: $showsSettings)` → `SettingsView(isPushed: true).cyPushedChrome()` (WelcomeView.swift:67-68), as the A receipt "Open (carried)" note says (23:3x). Only the table cell was never updated; A lane can mark it done | verified, no change |

Remaining open A rows (this run, bottom-up): "3. MP-account sync note" still blocked on a backend field; "漫游护照与工具 hub sheet" is kept by owner Q9 (map home) and stays with the coordinator.

## Run 11-28 (hourly, half split per "B lanes: collision fix" 15:45)
Merged `origin/mp/r3-nav` (clean). Open rows in `mp-nav-r3.md`, file order: (1) "漫游护照与工具" hub sheet (line 40, kept by owner Q9, coordinator) → A half; (2) "3. MP-account sync note" (line 339) → B half. Row (2) still blocked: `WeChatAppAuthService.Envelope` (Core/WeChatAppAuth.swift:83) decodes only `code`, `token`, `data` and `api/login/wechat/app` exposes no mini-program-origin field. No code change possible without that backend field; not crossing the middle.

**Half done** (B half = one row, blocked on the backend field). Run stopped.

## Run 11-28 ~17:xx UTC (hourly)
Merged `origin/mp/r3-nav` (fa99a37a7) and `origin/ui/combined-r7` (42e9a8aa8), both clean. Open rows in `mp-nav-r3.md` unchanged: (1) "漫游护照与工具" hub sheet → A half (coordinator, owner Q9); (2) "3. MP-account sync note" → B half, still blocked: `WeChatAppAuthService.Envelope` (Core/WeChatAppAuth.swift:83) decodes only `code`, `token`, `data`; no mini-program-origin field from `api/login/wechat/app`. No `cursor-k50-p*` lane-layout receipts exist on any branch yet.

**Half done** (B half blocked on the backend field). Run stopped.

## Run 11-28 ~18:xx UTC (hourly)
Merged `origin/mp/r3-nav` (26f67441e, fast-forward). Brief re-read (B lanes, collision fix 15:45, K50): no `cursor-k50-p*` lane-layout receipt exists on any branch yet. Open rows in `mp-nav-r3.md`, file order: (1) "漫游护照与工具" hub sheet (line 40) → A half (owner Q9, coordinator); (2) "3. MP-account sync note" (line 339) → B half.

| A-receipt row | MP → native | before | after | status |
|---|---|---|---|---|
| "3. MP-account sync note" (A receipt OWNER REQUIREMENT 04:30, line 339, "Not done (blocked on backend field)") | WeChat login result → Core/WeChatAppAuth.swift `Envelope`, App/AppSession.swift:3446, App/WeChatAppAuthSection.swift `LinkedMiniProgramAccountNoteModifier`, App/QuestifyApp.swift:548 | blocked: the envelope had no mini-program-origin field | closed app-side by Cursor K40 (`0c3aaee3e`, receipt `cursor-k40-account.md` O-12 item 3): decodes `linkedMiniProgram` as a Bool only (missing / non-Bool → false), shows one dismissible line 已使用小程序账号登录 / "Signed in with your mini-program account" (`.subheadline`, 44 pt `.borderless` dismiss, `.bar` inset) after WeChat sign-in; phone and Apple never show it; presentation only, cleared on logout/expiry. Pins: `test_wechat_app_auth.py`, `WeChatAppAuthTests`, `WeChatLaunchAndAppLinkTests`. Per "Cursor's K-wave rows are skipped by both lanes" no lane change made. Remaining backend item (hengyin, not this lane): store `union_id` on MP `/api/login/code` so the flag can become true | verified, done by Cursor K40 — A lane can mark it done |

**Half done** (B half empty; the only other open row is the A half's hub sheet, owner Q9). Run stopped.

## Run 11-28 ~19:xx UTC (hourly)
Merged `origin/mp/r3-nav` (clean; brings `cursor-k50-r01/r03/r08` receipts). Brief re-read (B lanes, collision fix 15:45, K50, sweeps 17:30 / 18:30): no new mp-nav finding after the 17:30 `ia-tabs` P2 (fixed by A). No `cursor-k50-p*` lane-layout receipt exists on any branch; the `k50-r*` receipts name no mp-nav row. Open rows in `mp-nav-r3.md`, file order: only (1) "漫游护照与工具" hub sheet (line 40) → A half (owner Q9, coordinator). B half empty.

**Half done.** Run stopped.

## Run 11-28 ~20:xx UTC (hourly)
Merged `origin/mp/r3-nav` (d37453ed7, clean). Brief re-read (B lanes, collision fix 15:45, K50, sweeps through 18:30): no new mp-nav coordinator finding; sweep index still build b954de71c. No `cursor-k50-p*` lane-layout receipt exists on any branch. Open rows in `mp-nav-r3.md`, file order: only (1) "漫游护照与工具" hub sheet (line 40) → A half (owner Q9, coordinator). B half empty.

**Half done.** Run stopped.
