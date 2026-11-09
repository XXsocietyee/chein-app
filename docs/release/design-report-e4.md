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
