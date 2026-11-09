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
