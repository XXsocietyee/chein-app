# Receipt: combined-r6 (six round-2 parity-fix branches on combined-r5)

Branch `ui/combined-r6`, cut from `origin/ui/combined-r5` @ `65eb1def4`. Local Mac, Xcode (`arm64`, `ONLY_ACTIVE_ARCH=YES`, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`), MobileBuildMCP DerivedData `Questify-bd74775b3cfe`, simulator `Questify-iPhone17-Lane2` (`2337B386-AC5F-4417-B8B8-012A8DB888BD`, iOS 27). Free disk kept above 6 GB (`9.9 GiB` after cleaning old DerivedData). `ui/main` was not touched.

## 1. Merges (no squash, in order)

| # | branch | head | merge commit | conflicts |
|---|---|---|---|---|
| 1 | `fix/parity2-club` | `a16f32e77` | `115234b51` | none |
| 2 | `fix/parity2-play-roam` | `f716b89a1` | `f3f30c376` | `Resources/Localizable.xcstrings` |
| 3 | `fix/parity2-player-content` | `fe831fed7` | `5b9a3c214` | `Resources/Localizable.xcstrings` |
| 4 | `fix/parity2-member` | `89c22000b` | `1455be242` | `Resources/Localizable.xcstrings`, `tools/typography_lint_baseline.json` |
| 5 | `fix/parity2-account-publish` | `d07897ec5` | `c0d9e28fb` | `Resources/Localizable.xcstrings`, `tools/typography_lint_baseline.json` |
| 6 | `fix/parity2-merchant-coop` | `e0b948a32` | `78499f3ae` | `Resources/Localizable.xcstrings` |

## 2. Conflict resolutions

- **`Resources/Localizable.xcstrings`** (5 merges): 3-way JSON merge per key (union of keys; when both sides changed a key, take the fix branch's value). Zero keys were modified by both sides in any merge; validated JSON parsing after each merge; `17,180` bilingual keys at the end; `check_scaffold.py` bilingual check passes (`missing_keys: 0`, `untranslated_values: 0`).
- **`tools/typography_lint_baseline.json`**: kept `ours` during merges 4 and 5, then regenerated once after all 6 merges via `python3 -B tools/check_typography_lint.py --update` (`6d0a87028`). Counts vs `combined-r5`: raw text style `1173 → 1143`, `Theme.Font` `63 =`, raw size `67 =`, back chevron `12 → 10`, hidden back `7 → 3`, large title `11 → 7`. No count went up.
- **`Questify.xcodeproj/project.pbxproj`** (merge 6): auto-merged cleanly.

## 3. Build and compile fixes

App (`Questify`) and `QuestifyAppUnitTests` required `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES` in `extraArgs` (the project leaves `ONLY_ACTIVE_ARCH=NO`, which otherwise tries to precompile `x86_64` against the `arm64`-only `GLTFKit2.framework`).

| commit | fix |
|---|---|
| `e3fb84b57` | `Core/PlatformPass.swift`: `PlatformPassHolding.init` captured `self` in `daysRemaining` closure before `self` was fully initialized; extracted local `resolvedTotal`. |
| `3355a081e` | Core tests updated for deliberate r2 parity changes: `Tests/CoreTests/ProfilePublicInfoRouteTests.swift` (`SocialPublicProfile.joinDate` from `createTime` per A1-05) and `Tests/CoreTests/MerchantServiceTests.swift` (`s.events` now admits `MERCHANT_FINANCE` with `.finance` via `canReadEvents`, so denial tested with `MERCHANT_FINANCE` lacking `.finance`/`.verifyRecordRead`). |

## 4. Gates (before vs after)

| gate | `ui/combined-r5` (before) | `ui/combined-r6` (after) |
|---|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (`4942` Swift files, `17039` keys, `264` pages) | PASS (`4945` Swift files, `17180` keys, `264` pages) |
| `python3 -B tools/check_typography_lint.py` | PASS (`1173 / 63 / 67 / 12 / 7 / 11`) | PASS (`1143 / 63 / 67 / 10 / 3 / 7`) |
| `python3 -B tools/contract_ratchet.py --check` | `185` failing / baseline `184` (new 1: `test_workshop_paid_professional…bounded_paging`) | `185` failing / baseline `184` (same 1 pre-existing failure, **0 new**) |
| Core `swift test --disable-sandbox` | `27` unique failing (baseline `27`) | `17,016` tests, **`27` unique failing** (after `3355a081e`; `IMFileInterruptionRecoveryTests` passed; **0 new**) |
| AppUnit (`QuestifyAppUnitTests-Shard01..04`) | `72` unique failing (baseline `72`) | `6 / 15 / 25 / 24` → **`70` unique failing** (**0 new**) |

## 5. P0 verification on TEST

TEST = `https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech` on Lane2 (`2337B386-AC5F-4417-B8B8-012A8DB888BD`), signed in as account `9009` (player). Screenshots and per-area notes: `/Users/fanning/chengyin-refs/combined-r6-verify/<area>/index.md` (local only, not committed).

| area | r2 P0s marked fixed | verified | broken / open | can't-test | notes |
|---|---|---|---|---|---|
| club | 0 | 0 | 0 | 0 | Carry-over spot-check `CLB-detail-02` (`pages/club/detail/index?id=7001` → `活动` tab) still stays on `正在加载俱乐部…` as in r5. |
| play-roam | 0 | 0 | 0 | 0 | All remaining P0s owner-gated or blocked-backend. |
| player-content | 3 | 2 | 0 | 1 | `PC-B-1-8` (topic 993006) & `PC-C-1-9` (session detail) system back + bar icons verified; `PC-B-1-3` (已截止) can't-test on TEST (no past-`endDate` topic in `/api/topic/list`; unit-tested in `TopicXcxFactsTests`). |
| member | 1 | 0 | 0 | 1 | `MKT-7-2` can't-test on TEST (account 9009 has no free-explore bundle order with a reservation; `BundleCommerceMountTests` covers contract). |
| account-publish | 1 | 1 | 0 | 0 | `A3-01` (`pages/gerenziliao/gerenziliao`) verified: `探索作品` and `联系二维码` show un-gated `图片上传暂未开放，已保存的图片保持不变。`. |
| merchant-coop | 0 | 0 | 0 | 0 | All remaining P0s partial, deferred, or owner-gated. |
| **total** | **5** | **3** | **0** | **2** | |

## 6. Backend items

New round-2 items appended to `docs/release/backend-needed-r6.md` (round-1 items remain in `docs/release/backend-needed-r5.md`).
