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


# THIRD PASS (ADA rework)

Merged origin/ui/main (already up to date at start of pass). Branch ui/e3.

## Benchmarks (new Mobbin searches, ios)
- Community group detail: Partiful club profile https://mobbin.com/screens/7c595947-0cb2-424d-8dd0-0bd981fdc1b1 (gradient cover tile, big name + tagline, action tiles); Reddit Communities https://mobbin.com/screens/d5f8357a-24e8-49ab-a401-a07406cdfd50 (round join pill on each row); Venmo group https://mobbin.com/screens/e91634c3-acc1-46b1-82b4-22af17ff8a7f (single primary action). Borrowed: full-bleed generated cover with gradient scrim and title over it, avatar stack + member count, one pinned join pill with spring + success haptic.
- Event calendar: Partiful calendar https://mobbin.com/screens/e3941f00-7e94-45bd-985d-58777aa969b1 (month grid + "events on this day" list with thumbnails); Lightyear https://mobbin.com/screens/0a47d994-69b2-4abe-b9d5-b7a1fb06db56. Borrowed: filled selected-day circle, dot under days with events, thumbnail agenda cards with attendee stack.
- Chat conversation: Airbnb https://mobbin.com/screens/e4d0a5f6-335f-46cc-8d78-504b77fcc308 (avatar header, sent bubbles right, quiet composer), Snapchat https://mobbin.com/screens/69be095b-3b2b-4599-a1b9-41d30f0b8005 (rich event card inside chat), Slack https://mobbin.com/screens/4da9f869-47ae-4ac4-b54e-e49a8102e24a. Borrowed: avatar+name header, pill composer with round send, rich cards at bubble width.
- Friends list: Savee followers https://mobbin.com/screens/24a8b4dc-a3b8-42ad-8471-ff03bb0bcb4e (avatar, name+handle, white Follow pill on black), Alta https://mobbin.com/screens/085af4e5-0e66-43fc-8779-510ed2ee9094 (search pill + mutuals). Borrowed: Follow/Following/Requested/Friends pill states, search pill.
- Notification list: Linktree https://mobbin.com/screens/9550a60a-c074-4bbb-844f-24c18e134860 (filter chips, Today grouping, unread dot), Ro https://mobbin.com/screens/3a78b2df-aebe-475c-89b6-df853ef212aa (icon tile + title/body/age). Borrowed: chips, Today/Earlier groups, tinted symbol tile, unread dot.

## What changed in production views
- ChatMessageBubble (shared by IM chat): iMessage-style: sent = accent blue fill (white text), received = elevated grey, consecutive same-sender messages group (tight inner corners, tight spacing, avatar + one timestamp only on the last of a run, sender name only on first of a group run). MessagingHistoryView computes the runs.
- Chat header: principal item is now generated avatar + conversation name. Composer: round accent send button (grey while empty) with animation; plus entry kept only when the poll entry exists (no dead buttons).
- Coop invite detail: topic name is a generated-cover hero card (parse-checked, built in the last batch).
## Fixtures (DEBUG, labelled "DEBUG fixture · synthetic data", generated cover art)
e3-club-detail (hero cover, avatar stack, segmented tabs, pinned join CTA with spring/haptic), e3-club-apply (cover picker, chips, one primary), e3-club-calendar (month grid + agenda), e3-club-feed (stories rings + photo post cards, unknown counts as em dash), e3-chat-rich (grouped bubbles, location / voice / file / video cards, composer), e3-invite (status chip, terms card, one primary), e3-notices, e3-people (follow states). e3-chat now has 5 grouped messages.
New kit in App/DesignFixtures/E3Fixtures.swift (E3PressStyle, E3Avatar, E3AvatarStack, E3FollowButton, E3PersonRow, E3NoticeRow, E3LocationCard/VoiceCard/FileCard/VideoCard, E3MonthGrid, E3PostCard, e3Card). It lives in the DEBUG fixtures file because new files need project-file entries (out of my scope): production screens do not use these components yet.
Motion/haptics: press spring (E3PressStyle), symbolEffect bounce on like/join, sensoryFeedback success/selection/impact, grid selection spring; all spring animation gated on Reduce Motion.

## Honest status / under 8
Real production club detail, apply/create, calendar, stories, notices and friends views were NOT re-laid-out onto the new kit (only fixtures show the target design; they depend on Core readers and project-file additions); the rich IM cards likewise live in fixtures only. Scores below are for the fixtures; production pages score lower until adopted.
Self-score (delight/interaction/inclusivity/visuals/innovation/social, avg): club detail 8, apply 8, calendar 8, feed 8, chat rich 8, chat (real, bubbles) 8, invite 8 (real hero 7), notices 8, people 8. Production club detail / calendar / notices / friends: 6, under 8, reason above.
Pillow compare: no mini-program reference screenshots exist for these pages.
Contact sheets: /Users/fanning/chengyin-refs/design-reports/e3/contact-125959.png (first batch), contact-131157.png (XL after stacking fixes); final batch b2 (EN + XL) listed in the final message.

## Final batch result (contact-133847.png, contact-131157.png, contact-125959.png)
- Verified in shots (zh-Hans is the simulator default language, so all non-"-en" shots are zh-Hans): club detail, apply, calendar, feed, rich chat, invite, notices, people, real chat (grouped bubbles, accent sent fill, avatar only on last of run, one time stamp per run), and AX-XL for notices / people / invite / rich chat / club detail (rows stack; follow button drops under the name).
- NOT verified: English shots. The `-AppleLanguages "(en)"` launch args failed to launch the app in design-batch.sh (springboard shots), so EN is parse/logic-checked only (strings use Locale.pick). Fixed after the last shot and only parse-checked: file card stacks at accessibility sizes (it wrapped per character at AX-XL).
