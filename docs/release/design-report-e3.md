# Design report e3 (SOCIAL) — INTERIM, paused for machine overload

Branch ui/e3. Status: NOT COMPILED, NO SCREENSHOTS.

Done:
- App/DesignFixtures/E3Fixtures.swift + registry hook: e3-inbox, e3-inbox-empty, e3-inbox-error, e3-chat, e3-poll, e3-social, e3-coop, e3-club-community (wrap existing offline DEBUG hosts under .roleTheme(.player); variants via the hosts' own launch args).
- Baseline list for the first batch is ready (11 shots: inbox x3, chat, poll, social profile/invites/guide, coop list/detail, club community).
- Build fixes needed on rc base (both outside my family; drop on merge if rc fixes them): Core/UGGameplay.swift missing `return` in submitData(slots:); App/GrowthLeaderboardView.swift duplicate score(alignment:).

Left: all restyling (IM inbox/chat/message detail/safety, group poll, club apply/create/calendar/posts/stories/community/roster/activity list, coop browser/invite/invite-detail/nearby, social profile/invites, notices) plus the batches and contact sheet.
