# Design report e3 (SOCIAL) — second pass, BLIND (NOT COMPILED, NO SCREENSHOTS)

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
