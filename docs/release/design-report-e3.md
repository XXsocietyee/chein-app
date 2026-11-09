# Design report e3 (SOCIAL) — second pass, final

Branch ui/e3, base merged with origin/ui/main 357154584 (clean merge; my duplicate fix commits dropped by the merge, nothing of mine conflicts).
Builds were held by the owner (LOAD 80) so everything below is parse-checked only (`swiftc -parse`), not built.

## Done (restyle, family-wide)
- Player grouped surface (`cyGroupedSurface`: hidden list chrome, CYColor.bgPage ground) on ~100 Form/List screens: IM (read-all, row actions, safety, expanded, files/video/voice, messaging home/history/detail), group poll (via `nativeChannelScreen`), clubs (home, detail, directory, members, public roster/activity list, calendar, enrollment, governance, management, ops, stats, welcome, check-in, community), coop (browser/read screen, flow editors/workbench, finance, settlement, withdraw shell, discovery, pool editor), social (public profile, invite history, guide, actions), friends (home, directory, metadata, removal, invite entries), channels (history, pins, search, notifications, onboarding, moderation, roles, report sheet), square report + progress, follow list.
- Shared read containers (ClubReadScreen, SocialReadScreen, MessagingReadScreen): CYSkeleton loading instead of spinner, page-ground background; accessibility ids kept.
- Group poll result: CYStatusChip for open/closed and "your vote", vote review is the single primary action, monochrome result bars.
- Raw colours replaced with CYColor tokens (accentColor, red, yellow, secondary fills) in 14 files; violet no longer used outside the selected tab in these screens.

## Fixtures (DesignFixtureRegistry, `--design-fixture <name>`)
e3-inbox, e3-inbox-empty, e3-inbox-error, e3-chat, e3-poll, e3-social (+ `--uitesting-social-destination invites|guide`), e3-coop, e3-club-community. Further pages are reached through those hosts' own launch args.

## Left
- Compile + EN / zh-Hans / XL contact sheets for every page above (batch list prepared at scratchpad b1.txt: 8 shots).
- Pillow comparison against mini-program screenshots.
- Deeper hierarchy work (one primary action, extra buttons removed) on club detail, IM expanded cards, coop invite detail, notices; fixtures for club apply/create/calendar/roster/stories.
- Contact sheet path: none yet (/Users/fanning/chengyin-refs/design-reports/e3/).

## Benchmarks (Mobbin, ios)
- Club detail / directory: Partiful (https://mobbin.com/screens/7c595947-0cb2-424d-8dd0-0bd981fdc1b1) gradient cover tile + name + tagline; Cal AI Groups (https://mobbin.com/screens/e9595ac2-f0b8-4b49-93ab-9fe58cb1deea) round cover, title + member count, trailing action. Borrowed: generated gradient cover art (CYCoverArt, deterministic by name) for clubs/conversations without a photo.
- Inbox: Reddit Inbox (https://mobbin.com/screens/1fdb305e-6646-4ab9-a965-90918b3b8619) tight rows, avatar, name + preview, unread dot; Discord DMs (https://mobbin.com/screens/af9da111-b574-44f9-924c-cb6c9269cc0f) avatar badges. Borrowed: gradient avatars, unread badge.
- Chat bubbles: stray per-message list row removed; bubble + timestamp + gradient avatar (own = high-contrast fill, received = elevated).

## Round 2 fixes after coordinator review
Black row boxes on public profile (per-row page background from SocialReadScreen) removed; chat header row removed; retry buttons are CYPillButton secondary with icon; coop owed-deposit red strip -> tinted warning callout with icon.

## Self-score (1-10, lenses: delight/interaction/inclusivity/visuals/innovation/social)
Inbox 7, inbox empty 8, inbox error 7, chat 6, poll 6, social profile 6 (pending re-shoot), coop list 6, club community 6. Under 8: all but empty; reasons: grouped lists remain, no swipe actions / motion layer yet, no real photography in fixtures.

## Final status
- Last build + batch: BUILD_EXIT=0 at ui/e3 commit "inbox name priority..." ; contact sheets: /Users/fanning/chengyin-refs/design-reports/e3/contact-123413.png (EN/zh inbox, XL inbox, chat, poll detail, coop zh, social zh, club), contact-115821.png (EN + XL: inbox, chat, poll, social, coop), contact-111255.png / contact-103801.png (zh baseline).
- Verified in shots: single title on messages, no black row boxes on profile, chat without stray row, pill retry, amber owed callout, gradient avatars, EN + zh + AX-XL for inbox/poll/social/coop.
- Fixed AFTER the last shot (parse-checked only, not re-shot): inbox row flat layout so Official chip / mute mark / time no longer wrap ("10/ 1") and AX name wraps instead of truncating.
- Fixtures added: e3-poll-detail (direct poll result + vote).
- Pillow comparison: no mini-program reference screenshots exist for IM / clubs / coop / social in docs/xcx-wechat-review-board-shots, so none done.
## Pages left / under 8
Chat (7: fixture has one message; grouping, tails not added), poll (7), social profile (6), coop list (7), club community (6: plain action list on error fixture), inbox (8). Not restyled beyond grouped surface + tokens: club detail/apply/create/calendar/stories/roster, IM expanded cards (file/voice/video/location), coop invite detail, notices, friends. No motion/haptic layer added beyond existing swipe actions.
