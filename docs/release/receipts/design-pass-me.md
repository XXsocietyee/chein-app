# Design pass: me + publish + onboarding (`design/pass-me`)

Base: `origin/ui/combined-r7` @ `fc95e6a19`; merged `origin/comp/r1-kit` (already contained). `origin/comp/r1-island-steps`
does not exist on the remote and no branch has a `CYStepChecklist`, so this lane added it (below) in `App/NativeR2/Components/`.
Principles read from `origin/design/handoff-r2:docs/briefs/design-principles.md`. Story-flow theme and merchant out of scope.

No compiler in the cloud: APIs checked by grep against existing usages (iOS 17 target: `symbolEffect(.bounce, value:)`,
`sensoryFeedback(_:trigger:condition:)`, `DisclosureGroup(isExpanded:)`, `ViewThatFits`, `ControlSize.mini`). Needs an
Xcode build on the coordinator machine.

## New component

| What | Where |
|---|---|
| `CYStepChecklist` + `CYStepChecklistItem` (R-steps): header (icon, title, "2 of 5 complete", ring), current step highlighted with the one primary **开始/Start** and a live status line with spinner ("保存中…"), remaining steps with secondary Start, collapsible **已完成 (n)** with a one-line trailing summary per done step, optional Reset. Ring becomes a bouncing checkmark at completion. Reduce Motion drops spring + bounce; VoiceOver: header is one element (title + "n of m complete"), current row `.isSelected`, done rows valued "Done". `ViewThatFits` stacks the Start under the title when English is long (P12). Preview included. | `App/NativeR2/Components/CYStepChecklist.swift` |
| `CYStepProgressHeader`: the checklist header alone, for wizards that keep their own pages. | same file |
| Strings (zh-Hans + en): `comp.steps.*`, `passme.ticket.startsIn` | `docs/port/strings/design-pass-me.json` → `Resources/Localizable.xcstrings` (+9 keys, append-only) |

## Screens: failed principles → fix

| Screen | Failed | Fix |
|---|---|---|
| First-run checklist on 我的/Passport (`MotionR2ChecklistSection`) | P4 (done steps vanished, no "what's next"), P3 (no action) | Now a `CYStepChecklist`: first open step is current with Start that switches to its tab (story → 首页, punch/stamp → 漫游, club → 俱乐部, via `rootTabSwitch`; hidden when no switch), done steps fold into 已完成 (n). `App/NativeR2/Motion/MotionR2Flows.swift` (R10 section) |
| Activity publish wizard chrome | P4 (bare progress bar, no "1 of 3") | `ProgressView` replaced by `CYStepProgressHeader` titled with the current step + ring; step buttons kept for jump-back; ids kept. `App/ActivityPublishingWizardView.swift` |
| Activity publish success | P7 (completion silent) | Success haptic with the result sheet. `App/PublishingModesViews.swift` |
| 发布 tab: 继续上次的草稿 | P4 (no sense of how far the draft got) | Trailing ring "n/3" over the quick setup's parts (name · story · places). `App/PublishRootContent.swift` |
| Passport badge rail | P8 (identical `rosette` glyph, not tappable objects), P1 (count as a `LabeledContent` trailing value) | Badge count is a rolling `CYLiveCounter` hero (label small above, like the stamp count); each badge uses its own `ClubBadgeArt` (MC-30 rule) and taps to the badge wall, where detail has Share + collection. `App/PassportView.swift` |
| Public profile · 我的勋章 | P1 (count buried in `LabeledContent`) | Large monospaced rolling count, label above, one VoiceOver element. `App/ProfileSelfMedalsSection.swift` |
| Ticket wallet card tag | P2/P5 (upcoming ticket within hours still a static date) | When `usableFrom` has a clock time and is < 24 h away: "距开始 / Starts in" + `CYCountdown` (same clock as the event Live Activity). Date-only values keep the MP「M月D日开始」tag. `App/TicketWalletView.swift` |
| Settings · legal document, post governance, privacy media list | P10 (spinner alone) | `ProgressView("mpd.common.loading")` (正在加载… / Loading…). `App/SettingsLegalDocumentView.swift`, `App/SettingsPostGovernanceView.swift`, `App/SettingsPrivacyLocationView.swift` |

## Audited, passing (no change)

- **Badge wall / badge detail** (`ObjectBadgeWallView`, `ObjectBadgeDetailView`): P8 already met — own art, name, condition/obtained date, Share button, 我的收藏 collected/locked; P1 ring + counts in the header.
- **Wallet / points ledger** (`WalletCommerceViews`): P1 balance hero (`balanceHero`, unknown = em dash); earnings hero.
- **Passport stamps**: P1 rolling stamp count + grid, "See all" exit (P8).
- **Sign-in** (`LoginView`): P3 one prominent action (Apple button or phone), P10 `auth.channels.appleWorking` / `auth.phone.verifying`, errors say what to do.
- **First launch** (`WelcomeView`): P3 one prominent 创建账号, P12 scroll at accessibility sizes, consent inline.
- **Settings root**: native `Form`, no fixed text widths (fixed frames only on icons/QR).

## Follow-ups (not done in this pass)

- Topic quick setup and club create wizard (4-step, `ClubPlayerSurface`) should adopt `CYStepChecklist`/`CYStepProgressHeader` (P4); their pages are contract-frozen / covered by UI tests, so left for the owners.
- Unused older `ProfileBadgesView` (no call sites) can be deleted.
- `motion2.checklist.value %lld %lld` is no longer referenced (kept in the catalog).

## Gates

`check_scaffold.py` PASS (5231 files, 19779 keys) · `check_a11y_lint.py` PASS (0 new) · `check_typography_lint.py` PASS ·
`check_design_lint.py` PASS · `contract_ratchet.py --check` 104 failing = baseline, new 0. `generate_project.py` run for the new file.

## References (self-found, add to design-principles reference log)

- **Apple Fitness Awards** (P8): each award is a distinct object with its own art, count and date, tap → detail with share; informs giving every Passport badge its own `ClubBadgeArt` and a tap exit.
- **Apple Wallet event passes** (P2/P5): a pass shows a relative "starts in" near the event time and the same time appears on the Lock Screen Live Activity; informs the ticket-card countdown.
- **iOS Settings / Health "Getting started" cards** (P4): checklist rows that stay visible with checkmarks after completion rather than disappearing; informs folding done first-run steps into 已完成 (n).
- **Duolingo / Notion onboarding checklists** (P4/P3): one highlighted next item with a single CTA, the rest quiet.
