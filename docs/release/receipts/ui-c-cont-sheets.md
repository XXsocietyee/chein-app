# Receipt: ui/c-cont-sheets (continuity r1, items 6, 10 and the player-sheet audit)

Branch `ui/c-cont-sheets` from `origin/ui/main`. Swift is not installed here, so **nothing in this receipt has been compiled or run.** Every API used below already appears in the repo (`cyHeroSource`, `cyHeroDestination`, `cyHeroDestinationWithFallback`, `@QuestifyReduceMotion`, `CYMotion.standard`, `CYMotion.Duration.quick`, `CYRadius.*`, `EnvironmentKey`) or is SwiftUI on iOS 17 (deployment target `Package.swift: .iOS(.v17)`).

Skills: all three repos cloned into `/tmp/skills` and read (apple-design-motion/os/interaction, emil choreograph/gestures/animation-vocabulary/break-ui/write-swift, make-interfaces-feel-better).

Navigation structure: **unchanged.** No route, sheet or push was added or removed; every control opens the same thing as before. The only presentation change is "sheet/push now zooms from its control" through the existing `cyHero*` modifiers.

---

## Item 6: topic detail bottom bar → its sheets

**Files**
- `App/TopicXcxSections.swift`: `TopicXcxActionBar` gets `heroNamespace: Namespace.ID? = nil`; each bar button gets `TopicBarHeroSource` (立即报名 and 查看场次 → `.sessions`, 随时开玩 → `.selfPlay`, 去票夹 → `.tickets`, 确认价格 → `.pricing`). New types next to the bar: `TopicBarSheet`, `TopicBarHeroSource` (private), `TopicBarHeroDestination`, `TopicBarRecede`.
- `App/TopicDetailView.swift`: only the bar call site (`.safeAreaInset(edge: .bottom)`) and the four sheet presenters it opens (`showingTickets`, `showingSelfPlay`, `showingSessionSelection`, `showsPricing`), plus two `@State` lines (`barSheetOrigin`, `@Namespace barHero`) and one `TopicBarRecede` line before the inset. Nothing else in the file was touched. The `openSessions` closure and the session sheet's `onDismiss` are byte-identical to before (pinned by `test_topic_session_selection`).

**Approach**
- One element: the button is the `matchedTransitionSource`; the sheet's root content is the `navigationTransition(.zoom)` destination with the same id (`cyHeroSource` / `cyHeroDestination`). The system zoom animates the sheet out of the button's box with transforms; nothing reflows.
- Clip radius matches the real control: primary buttons `CYRadius.md` (`CYButtonSize.md.cornerRadius`), the 查看场次 text action `CYRadius.sm`.
- The session sheet is opened only by the bar (立即报名 / 查看场次), so it always zooms from the bar. `barSheetOrigin` records which bar button opened the self-play / tickets / pricing sheet: those sheets are also opened by the paywall 解锁 pill, the context 随时开玩 pill, the contact-save flow and the toolbar pricing entry, which leave `barSheetOrigin == nil`, so they keep the plain slide-up and never zoom out of a button the user did not touch. Each of those presenters clears it in `onDismiss`.
- 立即报名 (sign-up state) and 查看场次 (self-play state) open the same sheet but never appear together (`TopicXcxFacts.action`), so one `.sessions` id stays unique in the namespace.
- Page behind recedes: the sheets use fractional detents (0.60 / 0.80, `CYSheetDetent`), never `.large`, so iOS never scales the presenter. `TopicBarRecede` scales the topic **list** to 0.96 and rounds its corners from 0 to `CYRadius.xl` on `CYMotion.standard`, while any bar sheet opened from the bar is up. It sits **before** `.safeAreaInset`, so the bar (the zoom source) stays perfectly still and the return zoom lands on the real button. At rest: scale 1, radius 0 → identical to before.
- Reduce Motion: `cyHeroSource/Destination` are off (plain sheet slide, which the system already cross-fades under Reduce Motion), and `TopicBarRecede` does nothing (the system dim remains). iOS 17: plain sheet, recede still plays (it is a scale, not a zoom).

**Frames**
- First frame: the sheet's content is a snapshot at the tapped button's box, clipped to the button radius; the list is at scale 1 / radius 0 (exactly the resting page).
- Last frame: the sheet at its 0.60 detent, exactly as before this change (same content, glass, radius `CYRadius.sheet`); the list at 0.96 with `CYRadius.xl` corners, under the system dim. On dismiss (button, drag or swipe), both run backwards: the sheet shrinks into the button and the list returns to 1 / 0.

## Item 10: 积分 balance → points ledger

**Where it really is.** The 我的 header tile `member.card.points` (`App/MemberHomeHeader.swift`) is **not** tappable today: it is a read-only tile and has no link to the ledger. Making it a link would add navigation (owner approval needed), and that file is part of the 我的 tab root, which another worker owns. The existing balance → ledger link that the player reaches from 我的 is the 通行证与礼品 page's balance card (`PassMarketView.balanceCard`, `passMarket.points` → `WalletLedgerView(kind: .assetPoints)` through `PassMarketPointsBridge`). I made **that** link continuous. **Owner decision needed:** if 我的's 积分 tile should open the ledger, that is a new route; once approved the same two modifiers apply to it.

**Files**
- `App/PassMarketViews.swift`: `@Namespace pointsHero`; the card label is `cyHeroSource("passMarket.points", cornerRadius: CYRadius.lg)` (the card's own radius); the destination gets `cyHeroDestinationWithFallback` and `.environment(\.walletLedgerZoomArrival, true)`.
- `App/WalletCommerceViews.swift`: `walletLedgerZoomArrival` environment key (default false) and, in `WalletLedgerView`, everything below `balanceHero` wrapped in one `Group` whose opacity is 0 until 0.25 s, then eases in over `CYMotion.Duration.quick` (0.20 s). Only when the flag is on, on iOS 18, without Reduce Motion; every other entry to the ledger is unchanged.

**Approach / frames**
- First frame: the ledger page at the card's box with `CYRadius.lg` corners; its balance header (same number, `data2XL`) occupies the box where the card's `dataXL` number was, so the number scales rather than cross-fades. The chips, 任务 link and history rows are transparent.
- ~50%: history starts fading in (0.25 s into a ~0.45 s system zoom), finishing at about the end of the zoom.
- Last frame: the ledger exactly as before.
- Back (button or edge swipe, interruptible, follows the finger): the system zoom shrinks the page back into the card; the history stays visible (content that exists only at the end does not re-hide on pop, matching the system's own zoom).
- iOS 17: `cyHeroDestinationWithFallback` gives the short rise-and-fade push it gives every other zoom destination. Reduce Motion: the plain push, history visible at once.

**Known limitation:** `balanceHero` only exists after the first ledger page has loaded. On a cold network the first frame of the zoom carries the loading skeleton (faded with the history), and the balance header pops in when the page lands. It cannot be prefilled from the card without changing the ledger's data source, which is out of scope.

## (+) Audit of other player sheets opened from one visible control

**Done: activity detail footer pill** (`App/ActivityDetailView.swift`). 立即报名 opens the registration sheet; the registered-state pill opens the ticket wallet sheet. The pill is now `cyHeroSource(… cornerRadius: CYRadius.pill)` and the sheet content is the zoom destination. The first tile (`performPrimaryAction`) opens the same sheets; it sets `tileOpenedSheet`, so those openings keep the plain slide-up (cleared on dismiss). The pill's action closures are unchanged (pinned by `test_activity_design_structure`). Only one pill exists at a time, so one id. No recede here: these sheets are `.large`, where iOS already recedes the page (adding mine would double it).

**Skipped, with reasons**
| Candidate | Why skipped |
|---|---|
| Activity detail share (toolbar ⬆ → `CatalogShareCardView`) | Source is a toolbar item; `matchedTransitionSource` inside a navigation bar item is not reliable before iOS 26 and the item is a system glass button. Not cheap or clearly better. |
| Activity detail 写评价 (two openers: section row and button) | Two different controls open it; a review composer is a form task, not an object growing out of a control. |
| Topic 写评价 sheet, club-transfer picker, contact sheet, result sheet (TopicDetailView) | Not opened from the bottom bar; the rest of TopicDetailView belongs to another worker. |
| Ticket wallet detail 出示票券 → full-screen pass | Already zooms (`presentHero`); untouched. |
| Ticket wallet list → detail | A push, already supports `heroNamespace` from hosts; not a sheet. |
| Settings: sign-out confirm, club picker (`SettingsAccountEntries`) | Confirmation and picker sheets from full-width list rows; HIG keeps confirmations as standard modals, and a row-wide source adds no spatial information. Settings is also under the 我的 tab root. |
| Profile edit text / preference editors (`ProfileEditView`) | Presenters are mounted on a zero-size `Color.clear` owner, not on the row control; wiring the row as a source means restructuring the presenter (not cheap), and it is editor territory. |
| Notifications: channel retry/save confirm, club default review, messaging home sheets (`NativeChannelNotification*`, `NativeClubNotificationDefaultView`, `MessagingHomeView`) | Confirmations (keep standard), row-action sheets from swipe/long-press (no single visible control), and the messaging home is a tab root owned by another worker. |
| 我的 票夹 pill → ticket pass | `AccountView`/`MemberHomeHeader` are the 我的 tab root (other worker). Good candidate for them. |

## Skill rules applied
- apple-design-motion, motion-animation.md: "zoom navigationTransition + matchedTransitionSource (iOS 18) … handles sheet presentation natively" and "Sheet with zoom source 350–420 ms, system-controlled": the system zoom carries the timing; no custom durations invented.
- apple-design-motion core rules: "Interruptible + velocity handoff", "Animate transform/opacity only", "Honor reduced motion": zoom and recede are transforms; the system zoom is interruptible and follows the dismiss drag; Reduce Motion falls back to the plain presentation.
- emil animation-vocabulary: "Origin-aware animation — an element animates out of its trigger, like a popover growing from the button that opened it" (items 6, +); only when that trigger really opened it (`barSheetOrigin`, `tileOpenedSheet`).
- emil choreograph, Step 1 (cast lead / support / static) and Hard Rule 1 ("one entrance per container"): lead = the sheet / ledger page; support = the receding page (same start, same spring family, "TOGETHER"); the ledger history is the only delayed part, because it exists only at the end. No stagger on the history rows (Hard Rule 2: high-frequency list).
- emil gestures: "the user must be able to catch a sheet mid-close and drag it back": no custom gesture; the system sheet drag drives both the zoom and the recede binding.
- make-interfaces-feel-better: matched corner radii (the zoom clip uses the control's own radius token; the recede uses `CYRadius.xl`).
- apple-design-os: "Sheets use detents … prefer the platform's native sheet patterns": detents, grabber and glass unchanged.
- Brief continuity rules: one element by id; end-only content fades in after ~50% (ledger history 0.25 s of ~0.45 s); at rest every screen is identical (recede scale 1 / radius 0; ledger history opacity 1).

## Gates
- `check_scaffold.py`: PASS. `check_design_lint.py`: PASS (0 violations).
- `contract_ratchet.py --check`: 185 failing, baseline 184, new 1 — **identical to untouched `origin/ui/main` 6ceb69fc7** (same single pre-existing failure `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`, unrelated). My first pass added 3 failures (pinned source strings in `test_topic_session_selection` / `test_activity_design_structure`, and a hero id that the scaffold read as a localization key); fixed by keeping those lines byte-identical and inverting the origin flag, and renaming the id to `footer.primary`.
- Not run: Swift build, simulator, screenshots (no Swift toolchain here).

## LOCAL VERIFICATION CHECKLIST (integrator)
Build first; this branch was never compiled. Watch for: `TopicXcxActionBar` call sites outside TopicDetailView (only one exists today), and the `Group { … }.opacity` wrapper in `WalletLedgerView.body` (type-checker time).

Topic detail (iOS 18+ simulator, player dark):
- [ ] Sign-up topic: 立即报名 → session sheet zooms out of the button; list behind scales to 0.96 with rounded corners; the bar stays still. Drag the sheet down → it shrinks back into 立即报名 and the list returns to full size.
- [ ] Self-play topic: 随时开玩 → self-play sheet zooms from it; 查看场次 (text action) → session sheet zooms from the text.
- [ ] Signed-up topic: 去票夹 → ticket wallet sheet zooms from it. Locked/pricing topic: 确认价格 → pricing sheet zooms from it.
- [ ] Paywall 解锁 pill and contact-save → self-play sheet: plain slide-up, no zoom from the bar, no recede.
- [ ] Fast repeated taps on a bar button: one sheet, no stuck recede.
- [ ] Drag the sheet half way and let go (cancelled dismiss): sheet and list both settle back to presented.
- [ ] Sheet to 0.80 detent and back: recede stays put; nothing jumps.
- [ ] Session sheet dismiss still reloads the topic (onDismiss kept).
- [ ] Topic id changes while a sheet is up (`onChange(of: key)`): sheet closes, list returns to scale 1.
- [ ] Long and short button titles (EN/ZH), large Dynamic Type: zoom clip matches the button's box.
- [ ] Light and dark (merchant preview of a topic): recede corners show the page background, no black flash beyond the window colour.
- [ ] Reduce Motion: plain sheet, no zoom, no scale; the system dim only.
- [ ] VoiceOver: focus moves into the sheet and returns to the button on close.
- [ ] iOS 17: plain sheets; recede scale still animates.

Points ledger (通行证与礼品 → balance card):
- [ ] Card zooms into the ledger; balance number lands on the ledger header; chips + history fade in from about half way.
- [ ] Back button and edge-swipe (cancel half way, then complete): zoom back into the card; nothing missing on the ledger when the swipe is cancelled.
- [ ] Cold network (slow load): skeleton fades in with the history; header appears when loaded. Empty ledger (empty state), failed ledger (issue view), long history scrolled then back.
- [ ] Any other ledger entry (wallet home 积分 row, fixtures): no fade, identical to before.
- [ ] Missing card (no `pointBalance`): card hidden as before.
- [ ] Reduce Motion: plain push, history visible at once. iOS 17: rise-and-fade push.
- [ ] VoiceOver: focus lands on the ledger title; returns to the card on back.

Activity detail footer:
- [ ] 立即报名 pill → registration sheet zooms from the pill; registered pill → ticket wallet zooms from it; both shrink back on close (including the wallet's own close button).
- [ ] The first tile opening the same sheets: plain slide-up.
- [ ] Cancelled activity (disabled pill): no zoom, no sheet.
