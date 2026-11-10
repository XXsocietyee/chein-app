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


# FOURTH PASS (production views)

Merged origin/ui/main (already up to date). Kit (E3Avatar, E3AvatarStack, E3FollowButton, E3PersonRow, E3NoticeRow, E3Location/Voice/File/VideoCard, E3MonthGrid, E3PostCard, e3Card, E3PressStyle) moved out of the DEBUG fixtures into App/ClubComponents.swift (production, no project-file change needed).
## Now in REAL views
- ClubDetailView: full-bleed cover hero with scrim, join-policy chip and name over it (grows with Dynamic Type), member meta line.
- ClubEventCalendarView: filled selected-day circle, event dot, thumbnail event rows with chevron.
- ClubStoryViews: photo-led covers (generated art fallback), stop-number chip over cover.
- IM rich cards (NativeChannelMessageBubbleView, MessagingMessageDetailView, IMStaticLocationCardView): voice / file / video / location are cards (IMVoiceCardLabel etc. in IMExpandedViews.swift), same NavigationLink routes and privacy gate (map only on tap).
- ProfileFollowListView, NativeFriendDirectoryView: avatar rows (48pt), name + meta, trailing state icon; plain list.
- Notices: system tab uses the already restyled IMInboxRow (bell avatar).
## Fixtures
e3-club-detail now renders the REAL ClubDetailView (D4ClubFixture); new e3-club-events, e3-club-overview (real tabs), e3-club-story (real ClubStoryFixtureHost). Old synthetic design kept as e3-club-detail-spec.
## Batch (contact-142424.png): EN worked after escaping parens as \(en\) in the list (design-batch.sh uses eval, so bare "(en)" is a syntax error; this is why EN shots failed).
Verified: club detail EN/zh/XL, overview, chat, inbox, social, story. Hero fixed AFTER shot for XL (chip overlapped cover icon): not re-shot.
## Not done / honest scores
Club apply/create and notices have no real-view change beyond tokens; follow list, friend directory, calendar month grid, IM rich cards have no fixture reaching the real view (need hosts in non-UI files) so unverified by shot. Scores: club detail 8, story 7, calendar 7 (events fixture empty), IM cards 7, follow/friends 7, apply 6, notices 7. Under 8 as listed.
Re-shot after hero fix (contact-144713.png, EN + XL zh): builds, hero grows with type; at XL the chip still sits over the decorative cover icon (cosmetic).


# FIFTH PASS (real-view fixtures, rework)

Merged origin/ui/main (twice, conflict in MessagingHistoryView resolved: CYIMCoverArt + run-grouped avatar tail).

## Benchmarks (new Mobbin searches, ios)
- Community detail: Venmo group https://mobbin.com/screens/e91634c3-acc1-46b1-82b4-22af17ff8a7f (avatar + name + single primary action), Reddit Communities https://mobbin.com/screens/d5f8357a-24e8-49ab-a401-a07406cdfd50 (round Join pill on rows), Cal AI Groups https://mobbin.com/screens/e9595ac2-f0b8-4b49-93ab-9fe58cb1deea. Borrowed: avatar stack + member count under the hero, one primary join action.
- Notification center: Expedia Inbox https://mobbin.com/screens/bfa3457c-e3a6-44ee-8ae2-58c6fd869078 (blue unread dot, underline tabs), Reddit Inbox https://mobbin.com/screens/67818216-72aa-4a0e-ad61-6ffe747d79f6 (section headers by recency), Snapchat https://mobbin.com/screens/418c887e-3d28-4a8b-bae0-3d3a6b825741 ("Today" header). Borrowed: Today / Yesterday / Earlier sections, unread dot on avatar, underline tab bar.
- Contacts / follow list: Polarsteps https://mobbin.com/screens/da1692c8-35d7-46a0-a97a-4847675449fa (Following / Requested pills, location meta), Alta https://mobbin.com/screens/11a14887-d736-46fb-bb2d-54a5b3153d26 (avatar rows, trailing pill). Borrowed: outlined state pill with check mark on follow rows.
- Group join request: Cal AI https://mobbin.com/screens/2853cdcc-3872-44fd-97ef-c0bcb9f3b1c3 (floating-label fields, one dark Continue), Discord https://mobbin.com/screens/f71c99bd-aa7a-45bc-bbbf-8b26ee4e1932 (one primary + one quiet alternative).
- Event calendar: Lightyear https://mobbin.com/screens/9949ee8e-90d7-4ec5-a721-e823204135e0 (date tile at row start), Partiful https://mobbin.com/screens/5fb14339-0f69-418c-919a-1c1912925c49 ("events on this day" with thumbnails, friendly empty day). Borrowed: month/day badge on the cover tile, empty-day state with icon.

## Done in code
- Fixtures reaching REAL views (App/DesignFixtures/E3Fixtures.swift, DEBUG): e3-real-friends (NativeFriendDirectoryView with a stub NativeFriendDirectoryServing), e3-real-follow (ProfileFollowListView with a stub ProfileFollowListReading), e3-real-imcards (real ChatMessageBubble + IMStaticLocationCardView / IMVoiceCardLabel / IMFileCardLabel / IMVideoCardLabel). Club apply/create are reached by existing d4-enroll / d4-ops-create (real ClubEnrollmentView / ops create); notices by e3-inbox (real MessagingHomeView).
- Club detail: member avatar stack + count under the hero (generated avatars, count unknown shows nothing), custom underline tab bar (matchedGeometryEffect, selection haptic, 44pt, Reduce Motion gated) replacing the segmented picker.
- Inbox / notices: Today / Yesterday / Earlier day sections, unread dot on avatar, existing swipe actions kept.
- Calendar: month/day date badge on each agenda cover, friendly empty-day state, header trait.
- Follow list: state pill (check + outline when followed) instead of a bare circle icon; friend directory row shows nickname under a remark.
- EN shots: launch arg `-preferences.language en` (design-batch list lines contain no backslashes).

## Fifth pass, final batch (after machine restart; full rebuild OK)
Merged origin/rc/20261108. 16 shots, one run: EN x8 (club detail, events, story, inbox, real friends, real follow, real IM cards, club apply/enroll), zh x4, AX-XL x4. Contact sheet: /Users/fanning/chengyin-refs/design-reports/e3/contact-211604.png.
Verified: EN renders with `-AppleLanguages (en)` list lines. Inbox shows Today/Earlier sections + unread dot; friends rows with star; follow list with state pill; IM voice/file/video/location cards.
Issues seen: at AX-XL the club-detail chip overlaps the member-count line and the IM file/video cards wrap tightly (cosmetic, same as before); inbox row at AX-XL stacks fine. Scores unchanged: club detail 8, inbox 8, friends 8, follow 8, IM cards 7, calendar 7, apply 7.

## Remaining list (handoff)
Done: kit in production; real club detail/events/story/inbox/friends/follow/IM cards shot in EN/zh/XL (see above).
Left: (1) wiring rows for SL3 SOCIAL from docs/release/view-requests.md (the 91-row version was not on any remote branch; file had 6 lines); receipts docs/release/receipts/wired-e3.md not started. (2) AX-XL club-detail chip overlap; IM file/video card tight wrap. (3) calendar (7) and apply/create (7) rework to 8. (4) Pillow before/after sheet. (5) No Mobbin repeat needed (5 cited in fifth pass).
Scores: club detail 8, inbox 8, friends 8, follow 8, IM cards 7, calendar 7, apply 7.
