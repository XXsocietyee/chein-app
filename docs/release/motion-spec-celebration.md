# Motion spec: celebration queue + state kit

Branch `ui/e4`. Source: `/Users/fanning/chengyin-refs/specs/ux-strategy.md` section 4 "Cross-cutting systems" (4.2 error tone, 4.4 celebration engine, 4.6 voice) and 1.3 "The five delight peaks". Built independent of the pending tab-IA decision: nothing here is mounted in a live screen, no tab or route changes. Code only, cloud-verified, no Core, Tests or Config edits, no new catalog keys (kit copy goes through `CYKitCopy`, same as `CYStateKit`).

Code: `App/DesignSystem/CYCelebrationEngine.swift`, `App/DesignSystem/CYCelebrationViews.swift`, `App/DesignSystem/CYStateView.swift`, `App/DesignFixtures/E4CelebrationFixtures.swift` (+ one line in `DesignFixtureRegistry.swift`).

## 1. Celebration engine
`CYCelebrationState` is a pure value type: `reduce(action, now:) -> [effect]`. No SwiftUI, timers or haptic generators inside, so ordering and spacing can be unit-tested later with a fake clock (Tests are out of scope for this lane).

| Piece | Rule |
| --- | --- |
| Kinds | `.stamp`, `.badge`, `.roamSummary` (the spec's `.ticketTorn` and `.clubJoined` callers are not built yet; the enum extends by one case and one timeline row) |
| Queue | One celebration on screen at a time. Priority is kind order (stamp, then badge, then summary), FIFO inside a kind. A badge therefore waits for the stamp that triggered it, even if it arrived first |
| Gap | 0.45 s of nothing between one leaving and the next arriving |
| Dedupe | The same payload key (`stamp:<id>`, `badge:<id>`, `roam:<id>`) plays once per session; a re-delivered success is ignored |
| Haptic spacing | Every cue is pushed to at least 150 ms after the previous one (spec text said +120 ms; the 120 ms `CYHaptics.play()` cooldown would have dropped it). The runtime plays cues from one serial task and re-checks the real gap, so timer jitter cannot squeeze two together |
| Clock | `now` is injected (`systemUptime` at runtime). `nextDeadline` tells the runtime when to call `.tick` (auto-dismiss, next item) |
| Unknown values | `CYUnknown.count/decimal/text`: nil, negative or non-finite is an em dash, never 0. A walk that really covered 0 passes `0` |
| Sound | None. No asset, no `AVAudioSession`. The haptic map carries the beat; the spec's sounds stay optional |

### Timelines (per kind)
| Kind | Motion | Haptics (from present) | Ends |
| --- | --- | --- | --- |
| Stamp slam | Overlay on a 45 % dim. Seal drops 40 pt in 0.2 s, squash 1.0 to 0.92 to 1.0 on `spring(0.32, 0.55)`, ink ring grows 1.0 to 1.6 and fades over 0.5 s, line fades in over 0.20 s | `.impactHeavy` 0.22 s, `.success` 0.40 s | Auto at 1.8 s (4 s with VoiceOver on); tap dismisses |
| Badge unlock | Full-screen cover. Medal lands on `spring(0.6, 0.58)` from 1.4x over a radial gold glow (background, not overlay); one `CYConfettiBurst` (1.9 s max) from 0.3 s; eyebrow, name, Share primary, Keep tertiary | `.impactMedium` 0.30 s, `.success` 0.45 s | Keep, swipe down, or VoiceOver escape |
| Roam summary | Large-detent sheet. Three numbers roll up on `.numericText` over 0.60 s, staggered 50 ms (3 concurrent animations, the budget) | `.success` once at 0.80 s | Done or sheet drag |

Copy (voice guide): "Stamped. You were here." / 盖章成功，算你来过; "New badge · {name}" / 新徽章 · {name}; "Share badge" / 分享徽章; "Keep in passport" / 收进护照; "This walk: 2.4 km · 31 tiles · 2 stamps" / 这一趟：…; "Share this walk" / 分享这一趟. Exclamation marks: none (the voice guide allows them at the peaks; the built copy does not need them).

### Reduce Motion (`@QuestifyReduceMotion`, including `--uitesting-reduce-motion`)
- Stamp: no drop, squash or ink ring; the finished seal cross-fades in over `CYMotion.reduced`; auto-dismiss 1.6 s; one `.success`.
- Badge: medal and glow at rest, no confetti (`CYConfettiBurst` already draws nothing); one `.success`.
- Roam: numbers shown final, `.opacity` content transition; one `.success`.

### VoiceOver
- Each celebration posts one announcement when it is presented (`AccessibilityNotification.Announcement`): stamp line (+ place), "New badge · name", the full "This walk" line with dashes for unknowns.
- Surfaces are modal and expose an escape action. The stamp's auto-dismiss stretches to 4 s when VoiceOver is on. Roam stats read as unit + final value, never a mid-roll number. The badge name is a header; the medal and confetti are hidden.

### Host
`.cyCelebrations(center, onShare:)` mounts all three surfaces (overlay, `fullScreenCover(item:)`, `sheet(item:)`) once, high in the tree, and mirrors Reduce Motion, VoiceOver and locale into the center. `onShare == nil` hides Share and Keep/Done become the one primary, so no dead button ships before `CYShareCard` is wired. A late binding callback only dismisses its own event (`dismiss(ifCurrent:)`), never the next one.

### Not built
Route draw on the summary (needs the map layer), passport mini-page flip, notification nudge row, ticket tear and club join callers, share card rendering. None of them block the engine; each is a view on top of `CYCelebrationPayload`.

## 2. CYStateView (empty / offline / server)
One layout: glyph 44 (`@ScaledMetric`), title 20 semibold, body 15 secondary, one pill, optional text link, always inside the content area. `compact` tightens spacing for an inline failed section on a live screen.

| State | Title / body (en) | zh-Hans | Pill |
| --- | --- | --- | --- |
| Offline | You're offline / Your map and lit tiles are here; new content waits for the network. | 你离线了 / 地图和已点亮的格子还在；新内容等网络回来 | Retry / 重试 |
| Server | Something broke on our side / We've logged it. Try again. | 这边出了点问题 / 已经记下来了，再试一次 | Retry / 重试 |
| Empty | Caller-owned words, caller-owned next action (required argument) | | caller |

Tone rules are code, not prose: `CYStateTone.violations(in:)` flags "unavailable", 暂不可用, sorry, please, successfully, oops, 抱歉, 请稍后, 请求失败, 网络连接失败, 暂无数据, "no data" and exclamation marks. The built-in offline and server copy is clean by construction.
- No mock data in production: the view takes strings and closures, never rows or counts. All sample content lives in `#if DEBUG` fixtures and is labelled "Offline example".
- Unknown is an em dash: `CYUnknown.count(nil)` is "—". The state-empty-compact fixture shows it next to an inline state.
- Relationship to existing kit: `CYEmptyState` / `CYErrorState` / `CYStateLayout` (illustrated, 132 pt art) keep their callers untouched. `CYStateView` is the strategy's W1-7 component; adopting it on the four tab roots waits for the IA decision.

## 3. Wiring
Wired nowhere live. No existing screen was changed: the places that show empty or error states today use `CYEmptyState` / `CYErrorState`, and swapping them would change their look, so they were left alone. The only non-new-file edits are the fixture registry line and the regenerated `project.pbxproj`.

## 4. Fixtures (DEBUG, `--design-fixture <name>`; add `-zh` for Simplified Chinese)
| Name | Shows |
| --- | --- |
| `celebration-stamp` | stamp slam, haptic log with timestamps, Replay |
| `celebration-badge` | badge cover (Share + Keep) |
| `celebration-roam` | summary with all three numbers rolling |
| `celebration-roam-unknown` | unknown km as a dash that does not roll, a real 0 stamps as 0 |
| `celebration-queue` | roam, badge, stamp enqueued 25 ms apart in that order; plays stamp, badge, summary with a visible 0.45 s gap and haptics >= 150 ms apart |
| `state-offline`, `state-server`, `state-empty`, `state-empty-compact` | the three states, plus the inline form beside live content |

Add `--uitesting-reduce-motion` to any of them for the fallback.
