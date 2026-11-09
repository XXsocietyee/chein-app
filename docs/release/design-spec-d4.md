# Design spec D4 — clubs / channels + me / settings

Theme: player = dark (page black, `#1C1C1E` cards) via `.cyDomainPageBackground()` / `.cyDomainCard()`. Violet only on the selected tab (already neutral in `CYColor.accent`; stray `Color.accentColor` in club code is replaced by `CYColor.accent`). Tabular numerals for counts. Em dash for unknown.
References: `/private/tmp/be-v2/docs/evidence/…` (`P` = player-e2e-20260927, `M` = merchant-deep-20260928). Contact sheets: `/private/tmp/design-reports/d4/ref-*.png`.

## 1. Club directory (`ClubDirectoryView`, `ClubRow`) — P/021, P/034, M/003
```
 Clubs                                (large heavy title)
 [ search ]
 ┌───────────────────────────────┐
 │  ░░░ cover / people glyph ░░░ │   rounded 20, soft depth
 │ (logo)                        │
 │ Club name                     │   heavy 20
 │ Interest group · Shanghai     │   secondary
 │ 5 members · 1 upcoming        │   tabular numerals
 │ ┌ Host · name ──────── ★ ┐    │   host strip (inset capsule row)
 │                   [ Join ]    │   ONE pill per card (Join / Open)
 └───────────────────────────────┘
```
Stays: order name → type · city → counts → host → join state. States: loading skeleton (existing `ClubReadScreen`), empty `ContentUnavailableView`, error + retry pill (P/034), signed-out sign-in.
Demoted: none (create-club stays in the host flow reached from the clubs home; no control added).

## 2. Club detail (`ClubDetailView`) — M/005, M/004
Cover hero → logo → heavy name → 3 meta lines (type, members, join policy) → membership status → ONE full-width pill (join / apply / leave; leave is destructive-quiet) → tab bar posts/events/overview.
Join / apply / leave confirmation = bottom sheet with detents (`CYConfirmSheet`, already used) — M/006, M/007, M/022. Restyle: leave consequences list is the existing copy; primary = red pill only for leave.
Demoted: the viewer-status rows fold into one status chip row.

## 3. Channels (`ClubChannelMessagingView`) — Discord-style, existing structure
Channel list = horizontal/leading list of `# name` rows with unread count; transcript = grouped message rows (avatar + name + role chip + time, consecutive messages from same author collapse under one header); composer = rounded field + circular send button pinned above keyboard.
Changes: `Color.accentColor/orange` → neutral `CYColor` tokens, message group spacing 4/12, composer capsule field, send = circular primary (near-white on black).
States: empty channel, rules-locked composer, read-only announcement, offline retry on failed send (existing).

## 4. Enrollment / governance / operations (`ClubEnrollmentView`, `ClubGovernanceViews`, `ClubOperationsViews`) — M/021–M/030, M/054–M/064
Keep forms; apply player page background + card sections (`.scrollContentBackground(.hidden)` + `cyDomainPageBackground`), one primary per screen via `.cyPrimary` for submit, destructive discard confirm through bottom sheet. Four missing keys get EN + zh-Hans (`ui-strings-d4.json`).

## 5. Me / Settings (`SettingsView`) — P/059, P/063, P/064, P/081
Grouped list in order of reference: 个人资料 → 城瘾玩法 → 我的喜欢 → 隐私与定位 → 营销消息 → 用户服务协议 → 账号注销 → 关于 → [退出账号]. Native Form with section headers (Account, Preferences, Privacy & notifications, About & legal, Account deletion), page background black, rows rounded cards. Sign-out is the last section (destructive, text-only), confirmed by a bottom sheet. Account deletion stays reachable (own section directly above sign-out).
States: signed-out (no account sections), load failure per row keeps existing messages.

## 6. Growth / leaderboard / stamp album / badges — P/038–041
Large heavy page title + subtitle, score card (big tabular number + unit), rank rows (rank numeral, avatar, name, points), empty/error states as `ContentUnavailableView` with one retry pill. Existing readers untouched.
