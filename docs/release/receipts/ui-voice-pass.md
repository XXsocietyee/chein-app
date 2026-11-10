# ui-voice-pass receipt (W3-7, DES-e5; NOT COMPILED locally; cloud Build is the gate)

Scope: copy only (catalog values, kit inline copy, test pins). No behaviour, gating, data or tab changes; the five-tab bar is untouched (W1-1 not approved). Voice table: ux-strategy.md section 4.6.

## Changed (Resources/Localizable.xcstrings, EN + zh-Hans, keys unchanged unless noted)
- GO / Go: new key `GO` (was an unresolved key rendering "GO"): Go / 走起. `roam.live.start`, `roam.w208.tab.start`, `roam.w208.intro.start`: Start roaming / 开始漫游 -> Go / 走起. `roam.w208.recovery.recovered` follows.
- Stamp success: `roam.poi.checkIn.success` (was "Check-in successful!" / 打卡成功！), `scan.stamp.created`: Stamped. You were here. / 盖章成功，算你来过.
- Ticket in: `ticketWallet.status.verified` Verified / 已核验 -> You're in / 已入场.
- Offline: `scan.fail.offline.title`, `cy.state.offline.title`: You're offline / 你离线了.
- Empty passport: `roam.experience.historyEmpty`, `roam.experience.albumEmpty` -> Your first stamp is waiting / 第一枚章在等你.
- Unknown = em dash: `roam.passport.unknown` (was Unavailable / 暂无可靠数据) -> "—" with new `roam.passport.unknown.a11y` (Unknown / 未知) as the VoiceOver label; live HUD `RoamLiveCoverageCopy.unknown` and `RoamLiveElapsedCopy.unknown` -> "—"; `official.card.collectiveUnknown` "--%" -> "—".
- "unavailable / 暂不可用" off tab roots: `club.unavailable`, `discovery.unavailable`, `roam.notConfigured(+Hint)`, `roam.live.notApprovedHint`, `roam.experience.liveHint|mediaUnavailable|imageUnavailable`, `cy.cachedImage.failed`, `roam.noCoordinates`, `auth.notConfigured` reworded (didn't load / isn't ready yet / 没加载出来 / 还没准备好).
- Empty copy: `roam.w208.entry.empty`, `roam.chapters.empty`, `discovery.emptyGames`, `club.emptyEvents`, `club.tab.empty.detail`, `club.tab.empty.merchant.detail`, `profile.badges.empty` (徽章 not 勋章), `wallet.empty`.
- No "please" (EN) on Welcome/sign-in: `auth.channels.*`, `auth.expired`, `auth.networkError`, `auth.storageError`, `profile.retryHint`. No 您: `roam.area.explanation`.
- Kit inline copy: `CYPermissionKind` location title is the primer line (Turn on location. Walk, and it lights up. / 打开定位，走到哪，亮到哪); Not now = 以后再说; off-state titles 定位没开 / 相机没开; `CYPhase` announcements.

## Tests/assertions updated (new copy is the right copy)
`RoamPlaceReadStatusViewTests` (unknown placeholder "—"), `RoamHomeTabsFlowTests` (走起 tab), `RoamExperienceFlowTests` (Go button absent; empty title), `test_cy_cached_async_image.py`. `docs/release/ui-strings-voice.json` lists the two new keys.

## Left as is
- Exclamation marks remain only in game cue strings (`playkit.*`, `templateReaction.*`, `playx.poi.completed`): game surfaces, not tab roots or peaks.
- Hold hint "按住 · 点亮" has no host surface yet (no key added); `roam.fog.revealed` is area-based, not a tile count, so not forced into "点亮 1 格".
- Core presentation strings (e.g. `HomeIndexParityPresentation.emptyStateTitle` 暂无内容) are outside UI-owned files. Deep club/merchant/admin screens still carry 暂无/暂不可用; only tab roots, peaks and shared kit were swept.
- Pre-existing red: `test_localization_key_catalog_contract`, `test_merchant_business_access_lifetime`, `test_roam_camera_context` fail identically on the base tree.

## Checks
swiftc -parse on touched Swift files clean; check_catalog_coverage gaps 0; check_scaffold PASS; check_design_lint PASS. Cloud: appended below.
