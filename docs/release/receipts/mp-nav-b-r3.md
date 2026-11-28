# mp-nav B lane — round 3 receipt (`mp/r3-nav-b`)

Works the open rows of `docs/release/receipts/mp-nav-r3.md` bottom-up (brief round3-1127 "B lanes"). One row per A-receipt row finished.

Skipped (bottom-up): "3. MP-account sync note" (A receipt OWNER REQUIREMENT 04:30) — still blocked on a backend field (`WeChatAppAuthService.Envelope` has no mini-program-origin field). M-08c partial was closed by the A lane at 15:xx.

| A-receipt row | MP → native | before | after | status |
|---|---|---|---|---|
| "pages/square/detail feed-play-card 试玩" (A receipt Re-scan 11-27 22:3x, open) | `pages/square/detail` index.js:186-193 `goPlay` → `wx.navigateTo('/pages/play/index?topicId=')` → App/SquareDetailView.swift `SquareDetailPlayCard`, App/SquareRelatedTopicView.swift, App/QuestifyApp.swift `chain3_6` | 试玩 pushed the related topic detail (play one step further), because `SquareRelatedTopicDestination` injects no play provider | new environment `squarePlayDestination` (default nil), set once at the session root to `SessionPlayRuntimeView(session:, destination: .journey(.topic(id)))` — the same page `pages/play/index?topicId=` lands on (MPReviewedPageScreen). 试玩 sets `playTopic`; `SquarePlayPushModifier` pushes play, fenced by the same square + topic read scopes as the topic push (stale selection → `SocialIssueView`), reset on post key / topic scope change. Fixtures and hosts without the session root keep the topic push. The topic id is the existing namespace-bound related topic (never `dataId` guessing). 查看主题 links elsewhere unchanged. Pin: Tests/ContractChecks/test_mp_nav_square_try_play.py. Level B, navigation only. Not compiled here | fixed |
