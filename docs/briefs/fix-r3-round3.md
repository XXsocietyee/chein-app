# F-agents, round 3 (2026-11-24 evening): continue on your own `fix/r3-<area>-<half>` branch

**New base:** `origin/ui/combined-r7` `b0ac0108d`. It builds clean and includes:
- your round 2;
- Cursor's App wiring (L1–L6);
- the owner decisions (D1–D8);
- the MP-contract coverage (M1–M6);
- Swift 6 and deprecation cleanup;
- Gemini rounds 5–6.

## 1. Re-apply what the merge dropped (first)
Cursor's wiring and your round 2 overlapped. Conflicting hunks were resolved toward Cursor's wiring, and these files were restored whole to one side:
- **Cursor side (your round-2 edits there are gone):**
  - `SettingsView`, `MerchantVerifyRecordsSections`, `PlatformConsumerSessionOwner`;
  - `RoamPOIActions`, `JourneyReportViews`, `TeamHomeView`, `TicketWalletView`;
  - `TopicXcxSections`, `ClubDetailView`, `ClubKit/ClubWorkbenchKit`.
- **Your side:** `MPParityPassSession` (member-a), `WalletIncomeAnalysisReader` (player-content-b).
- **Duplicates removed:** `ClubMPAvatar` and `ClubMoneyText` now live only in `ClubKit/ClubMPArt.swift`. `ClubMoneyText.twoDecimals` is an alias of `display`.

Steps:
1. `git merge origin/ui/combined-r7`.
2. For each of YOUR round-2 commits: `git diff <your-round-2-commit>^ <your-round-2-commit>` → is each hunk's effect present on the new base? If not, re-apply it **on top of Cursor's wiring**. Reuse Cursor's APIs (e.g. `RoamPOIActionModel.ownerID` journal, `MerchantVerificationAppendList`, the environment `registrationPreselectedTicketID`). Don't re-add a second implementation.
3. List what you re-applied in your receipt ("Round 3 · re-applied").

## 2. Then continue
- Anything still open in your receipt.
- MP assets on your pages (`docs/mp-assets/mapping.md`), now including the template-detail shelf tabs, leaderboard memojis and member-journey icons.
- Open Claude rows in `review/r7-rev-*` and the P1 rows in `audit/parity-r7-<area>`.
- Gemini's flow gaps for your area: `docs/mp-gap/flows-g1.md`, `flows-g2.md` (edges marked "Claude").

## Rules (unchanged, plus)
- Before using any type or initializer, grep its CURRENT declaration on the new base. Signatures changed in this merge.
- Never declare a type name that already exists anywhere in App/ or Core/: grep first.
- Strings must be xcstrings-shaped, with en + zh-Hans.
- Merge `origin/ui/combined-r7` again before your final push. Push every 30–60 minutes.
