# Design report e4 (account and settings family), second pass

Branch ui/e4, based on origin/ui/main 357154584. Contact sheets and shots: /Users/fanning/chengyin-refs/design-reports/e4/ (contact-*.png from run1 EN baseline of 22 pages; batch-*-{en,zh,xl}.png for favorites, growth, leaderboard, settings, wallet income/assets, member, profile edit, complaint, privacy; zh + XL for leaderboard, wallet income/points/balance, about, collection, participants, template-mine).

## Done
- DEBUG fixtures for 22 pages: `--design-fixture e4-<name>` (profile-edit, profile-edit-error, settings-support, about, privacy, favorites, collection, complaint, member, participants, self-projects, self-growth, self-medals, template-mine, wallet-income/points/balance/assets/analysis/bank/withdrawals/tasks).
- Fixed crash in the favorites fixture (APIConfiguration rejects `.invalid` hosts; fixture now uses fixture.example).
- Growth center: layered 24pt hero card for points, scaled Dynamic Type score with tabular digits, success haptic and symbol bounce on badge unlock (system respects Reduce Motion).
- Leaderboard: removed the duplicate hero title (nav title already shows it).
- Wallet ledger/income rows stack at accessibility sizes (amount was squeezed to "+8._5" at XL); income colour uses a token.
- Settings language chooser is a compact menu; spinners replaced by CYSkeleton on wallet, collection, creator content, participants, growth.
- All of the above compiled and was verified on screen (EN, zh-Hans, XL).

## Findings, not fixed
- Segmented pickers (ledger filters, leaderboard metric/period) stay small at XL: system control behaviour.
- Collection title truncates at XL; the About page bottom button overlaps rows at XL.
- Many fixture pages show sparse data (wallet assets/income show amounts unknown), so they read as plain grouped lists: the fixtures lack imagery and numbers. Not ADA quality yet.

## Left (pages not restyled beyond the above)
Auth/login/role entry, deregister/GDPR, marketing consent, tickets wallet, member identity card, profile edit, complaint, creator pages: reviewed in baseline only, no restyle. No Pillow compare against mini-program screenshots was done.

## Benchmarks (Mobbin)
- Growth center: Cal AI Milestones https://mobbin.com/screens/40849b04-f210-49aa-8144-e830e38a2710 and WHOOP Achievements https://mobbin.com/screens/ee83cea3-9161-406c-961b-76910c776c88 (hero stat card, badge grid). Applied: hero card, unlock haptic.
- Wallet: Phantom https://mobbin.com/screens/23998a59-cff7-4166-9438-6741e841af50 (icon rows, signed amounts) and Lightyear https://mobbin.com/screens/e3d03be7-2a0d-47e3-bffe-e21cce6f9bbf (big balance, one action). Not applied.

## Self-score (six lenses, 1-10)
Growth center 7, leaderboard 6, wallet ledger 6, settings 6, favorites 6, rest not reworked (under 8: all of them, see Findings).

## Review round 2 (coordinator fix list)
- Edit profile: single title, 112pt avatar with pencil badge. Verified zh and XL.
- Crash (home screen shot): was the favorites fixture, fixed earlier.
- About: brand wordmark "Chengyin 城瘾" (no Questify), icon tile hero (brand mark loaded by UIImage so loose bundle PNG shows). Mark fix not re-shot.
- Settings: iOS-Settings style neutral 30pt rounded-square icon tiles on all rows (one accent, no rainbow). Verified.
- Ledger rows (points/balance/income): leading in/out icon tile, coloured amounts. Verified. Finance hero with balance not added: fixtures carry no balance data.
- Duplicate public-profile shots dropped from the batch list.
- Not done: Save button pinned at bottom of edit profile, grouped single card for fields, Mobbin settings/wallet benchmarks applied beyond those cited.

---
# Third pass (ADA rework), branch ui/e4
Shots: /Users/fanning/chengyin-refs/design-reports/e4/ (batch-auth-{en,zh}, batch-auth-phone-xl, batch-login-{en,zh}, batch-tickets-{en,zh,xl}, batch-profile-{en,zh,xl}, batch-settings-xl, batch-about-xl, batch-member-en, batch-complaint-en; contact sheets contact-*.png). Merge: origin/ui/main already an ancestor (nothing newer).

## Done this pass
- Phone sign-in (AuthChannelView): large-title nav, +86 country chip + phone field, six code boxes over a real oneTimeCode field (selection haptic per digit, success haptic on sign-in), resend text button with cooldown, one primary pill, system Apple button only when Apple is verified (capability absent => hidden), legal footnote with agreement/privacy links. Fixture `--design-fixture e4-auth-phone`.
- Login (LoginView): Form replaced by a dark page: brand glyph, large title, username/password in one rounded card, status lines, primary CTA pinned to the bottom inset.
- Profile edit: 112pt avatar with edit badge, nickname/phone/introduction in ONE grouped card (was three slabs), pinned Save on a bar material with bottom inset, duplicate hero title removed.
- Ticket wallet: ticket cards with generated gradient art (no ticket image exists in the model), status chip over art, perforation + side notches, stub with date/place and QR glyph (icon only; no fake code), stub omitted when it would be empty, expired/cancelled dimmed. Fixture `--design-fixture e4-tickets`.
- Settings: iOS Settings style 30pt icon tiles (neutral raised tile, one accent). About: brand tile, centred name and tagline.
- Account compliance review step: warning is now an icon + bold label.

## Not done / left
- Deregister and marketing consent: no DEBUG fixture possible (AccountComplianceService is concrete and needs a session; Core is out of scope), so only the review-warning tweak was made, unshot. Marketing toggle rows with explanations not restyled.
- Creator pages, member card, complaint: baseline only. No Pillow compare against mini-program images. Apple button could not be shown in the fixture (not verified in DEBUG).
- About at XL hyphenates "Ver-sion"; segmented pickers stay small at XL (system).

## Benchmarks (Mobbin, new this pass)
- Phone verification: BeReal https://mobbin.com/screens/e3a5efc8-36c8-4110-9fe5-d2f015f6dd20 (large separate code digits), LinkedIn https://mobbin.com/screens/23c00131-3879-4a3d-b491-ae2ea2d1b0e0.
- Login with Apple: Cal AI https://mobbin.com/screens/6709ced3-1d48-4f8b-be64-f32378588965 (stacked pill buttons, honest legal checkboxes), Bevel https://mobbin.com/screens/243bd4cc-742f-4952-b665-d56d49e702b5 (single primary, legal footnote).
- Edit profile: Venmo https://mobbin.com/screens/8386c124-fc56-4721-aced-cc1ee1693a6a (avatar edit badge, pinned Save), Partiful https://mobbin.com/screens/33a8a45b-511d-4eb6-8bb4-738a06c1272e.
- Ticket: Luma https://mobbin.com/screens/fd60dbd4-6f2f-43e8-a2a8-dbf6954b3f59 and Once https://mobbin.com/screens/6086eb13-6fe5-4ae0-8a86-b9d94546aeac (dark ticket, QR in white tile).

## Self-score (delight / interaction / inclusivity / visuals / innovation / social)
Phone sign-in 8/8/8/8/6/8 -> 8. Login 7/8/8/7/5/8 -> 7 (sparse, no Apple in fixture). Ticket wallet 8/8/8/9/8/8 -> 8. Profile edit 7/8/8/8/6/8 -> 8 (avatar card still shows system empty copy). Settings 7/8/7/8/5/8 -> 7. About 7/7/6/8/5/8 -> 7 (XL hyphenation). Under 8: login, settings, about, plus all not-restyled pages (deregister, marketing, member, creator, complaint).

## Fixture-data follow-up (coordinator note)
- DEBUG-labelled ledger data added to the wallet fixture transport (`designLedger`, only under `--design-fixture`): balance, points and income rows across Sep-Nov 2026 with amounts, after-balances and currency.
- Wallet balance and points ledgers: large 44pt rounded balance hero (unknown stays an em dash), rows grouped by month, signed amounts. Shots: batch-balance-{en,zh,xl}, batch-points-{en,zh}, batch-income-en, batch-assets-en.
- Profile edit pinned Save + one grouped card: done in the earlier commit (batch-profile-*). About brand mark renders (batch-about-{en,zh}).
- Self-score: wallet balance 8, points 8, income 7 (rows grouped by day, no hero), About 8.
