# Chengyin design principles (living document)

Owner 11-27: references are examples, not specs. Extract why they work, apply the principle to every surface where it fits, and keep adding references found independently. Every design lane reads this file first. Story-flow theme stays on hold; everything else is in scope. Native Apple components, MP-first content, zh-Hans + en (US) both must read well.

## Principles

| # | Principle | What it means in practice | Learned from |
|---|---|---|---|
| P1 | **One glance, one number** | Each surface leads with the single value that matters (distance, minutes left, people in, points), large and monospaced; label small and secondary above it; supporting values in a quiet row below. | Widget sheet (12,572 watching), Fitbit walk (0.01 mi hero), adidas/WHOOP stat rows |
| P2 | **Alive, not static** | Values that change while you look roll (`numericText`), timers tick by themselves (`Text(timerInterval:)`), progress fills; deltas carry color (+318 this hour in green). Nothing looks frozen while something is happening. | Widget sheet, Live Activity references, Strava acquiring-GPS state |
| P3 | **One primary action** | At any moment one obvious next step (Start / 加入 / 开始 / Pause), visually dominant; secondary actions quieter or in a menu. | Step checklist (current step "Start"), Runna (Pause big, Next Lap secondary), GroupMe (I'm in vs Can't go), AllTrails pause FAB |
| P4 | **Progressive disclosure with memory** | Show what's next; fold what's done into a compact "已完成 (n)" with a one-line summary each; a progress ring says "2 of 5". The past stays reachable, never in the way. | Step checklist card |
| P5 | **Same object, every size** | A run, an event, a team, a quest looks recognisably the same as a list row, a card, a detail page, a widget, a Live Activity pill and a notification — same icon tile, color, hero value. Transitions morph between them (`matchedGeometryEffect` / zoom). | Widget sheet (pill/medium/large of one item), shared island |
| P6 | **Other people are present** | Show who is here/going/done: avatar stacks, "3 friends in", host avatar, a friend's name on the live status. Social facts sit next to the action they affect. | Shared island (friends), Partiful guest list, Apple Invites, GroupMe attendees, DICE choose a friend |
| P7 | **Personality at moments, calm everywhere else** | Surfaces are quiet (system backgrounds, one accent per object). Personality — stickers, taped notes, confetti, holo sheen, playful copy — appears at moments that matter: invites, rewards, firsts, completions. | Shared island stickers, Runna 1K badge + confetti, Not Boring unlock, Discord/Cal AI badges, earlier motion r2 refs |
| P8 | **Rewards are objects you keep** | An achievement is a thing (badge/stamp/medal) with a name, the number behind it, and two exits: share it, see the collection. Never a toast that disappears. | Cal AI "First Drop", Discord badge, Runna 1K, Duolingo star |
| P9 | **The map is the stage, the panel is the script** | Map full-bleed; a draggable panel holds live stats and the one action; map controls minimal (MP: no locate button). Route draws in, position pulses. | Strava, AllTrails, WHOOP, adidas, Runna |
| P10 | **Status before content** | Before data is ready, say what's happening in words ("Acquiring GPS", "Writing…", "生成中…"), never a blank or a spinner alone; errors say what to do. | Strava acquiring GPS, step checklist live status |
| P11 | **Invites are cards, answers are one tap** | An invite reads as a small card (what · when · where · who), with two answers and a gentle "later" (Tuck). Saying yes updates everyone's view. | Shared island, GroupMe, Partiful, Apple Invites, Lex RSVP |
| P12 | **Language-proof layout** | Every element survives English being 2× longer than Chinese and vice versa: wrap, `ViewThatFits`, adaptive stacks, no fixed widths on text. | US launch requirement |

## Where each principle applies (lanes must cover every row)

| Surface | Principles to apply now |
|---|---|
| Explore / home feed / search | P1 (event cards lead with time-to-start or distance), P5, P6 (friends going), P10 |
| Roam (free walk) + map | P9, P1/P2 (distance, time, places revealed), P3 (Pause), P5 (same run in widget + island), P7 (reveal moments), P8 (stamps) |
| City orientation run | P9, P4 (stops as steps), P2 (deadline countdown), P6 (team progress), P3 |
| Games (all types) | P1/P2 HUD, P3, P7/P8 result + reward, P10 |
| Events / activities | P11 (invite card + RSVP), P6 (attendees), P2 ("starts in"), P5 (event in list/detail/island/widget) |
| Clubs + community feed | P6, P11 (club event cards), P2 (live member/like counters), P7 for first post / milestones |
| Channels / messages | P6 (presence, typing), P2 (unread, live), P11 (plan/invite messages as cards inside chat), P10 |
| Me / passport / wallet | P8 (stamps, medals as objects + collection), P1 (wallet balance hero), P5 |
| Publish / club setup / onboarding | P4 (step checklist), P3, P10, P7 at completion |
| Widgets, Live Activities, notifications | P1, P2, P5, P6, P11 (all of them are the "small sizes" of in-app objects) |
| Every screen | P12, accessibility (Dynamic Type, VoiceOver, Reduce Motion) |

## How lanes use this

1. Read the principles and the row for your surfaces.
2. For each screen: list which principles it fails today (one line each in the receipt), fix with native components, keep MP content/behaviour.
3. Add any new reference you rely on to the table above (why it works + which principle), so the next round learns from it.

## Reference log

- 11-26: owner's 20 X motion references (motion r2 R1–R18), rybinandy Drift (story text on blurred image — story theme on hold), widget sheet tobiadonadon_.
- 11-27: gdwwyn shared Dynamic Island; dimtri_G step checklist; Mobbin (self-found): adidas Running, WHOOP, Strava, Runna, Fitbit, AllTrails live tracking; Canopi, Lex, Partiful, Apple Invites, GroupMe, DICE plans/invites; Runna, (Not Boring) Weather, Duolingo ABC, Cal AI, Discord, pillowtalk reward moments.
