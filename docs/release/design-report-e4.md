# Design report e4 (account and settings family) — INTERIM, second pass blocked on build lock

Branch ui/e4. Merged with origin/ui/main 357154584 (compiles there).

## Done (blind, NOT yet compiled by me)
- DEBUG fixtures for 22 pages: `--design-fixture e4-<name>` (profile-edit, profile-edit-error, settings-support, about, privacy, favorites, collection, complaint, member, participants, self-projects, self-growth, self-medals, template-mine, wallet-income, wallet-points, wallet-balance, wallet-assets, wallet-analysis, wallet-bank, wallet-withdrawals, wallet-tasks).
- Growth center score uses a scaled metric (Dynamic Type safe) with tabular digits.
- Settings language chooser is a compact menu (was a 3-row inline list).
- Wallet ledger income amount uses the success token instead of raw green.
- Spinners replaced by CYSkeleton on wallet, collection, creator content, participants, growth.

## Left
- Screenshots (EN / zh-Hans / XL) and Pillow compare: held by LOAD 80 (no builds for e4 until GO). A baseline batch of all 22 fixtures is queued (list: chengyin-refs/design-reports/e4/list1.txt) and runs when the lock frees.
- Pages not yet looked at on screen: auth/login/role entry, deregister/GDPR, marketing consent, tickets wallet, leaderboard, member card.

## Benchmarks (Mobbin)
- Growth center: Cal AI Milestones (https://mobbin.com/screens/40849b04-f210-49aa-8144-e830e38a2710) hero stat plus badge grid; WHOOP Achievements (https://mobbin.com/screens/ee83cea3-9161-406c-961b-76910c776c88) dark layered achievement cards. Borrowed: layered 24pt hero card for points, success haptic and symbol bounce on badge unlock.
- Wallet: Phantom (https://mobbin.com/screens/23998a59-cff7-4166-9438-6741e841af50) icon rows with right-aligned signed amounts; Lightyear (https://mobbin.com/screens/e3d03be7-2a0d-47e3-bffe-e21cce6f9bbf) big balance with one primary action. Planned, not yet applied.
