# port-4 report (nothing compiled or run — no Swift toolchain in this environment)

Branch `cloud/port-4` from `origin/wip/gm-next`. Every symbol used was checked by grep. A local worker must compile and test.

## Source availability
The mini-program checkout has no `index.{wxml,js}` for `subpackageMember/character`, `orient-score`, `free-explore` or `invoice-apply`
(they are not in app.json or on disk). They were not touched: there is no source to diff against.

## Per page
- **pages/address -> ProfileParticipantsView.swift**: added the row caption "用于报名联系和到场核验" (key `profile.participants.rowPurpose`).
  Already present: loading/empty/error, pull-to-refresh, edit, delete, add. Still missing: row-tap "select" mode that returns a
  participant to the sign-up caller (needs a caller channel; no route may be added).
- **subpackageA infomation -> SocialGuideViews.swift / SocialGuideXcxParity.swift**: now render the existing `guideXcx.heroDetail` sub-line and
  `guideXcx.docsEmptyDetail` empty-state detail. I tried rendering unusable CMS rows as disabled cells and reverted it:
  `SocialAccountService.informationList` already drops them (`filter(\.isUsable)`) and tests rely on that. Still missing: the disabled
  "内容待完善，暂不可查看" rows, which need a service change and a test update.
- **pages/publish/simple -> PublishingModesViews.swift**: added `Core/QuickPublishFieldLimitsPort.swift` (title 30, story 500, stop name 30,
  stop story 300, idea 300, seed idea 60, max 3 AI stops) and `Tests/CoreTests/Port4QuickPublishFieldLimitsTests.swift`.
  NOT wired into the form: the quick-publish editing code lives in QuickPublishingJourneyOwner, which I did not touch. Still missing:
  wiring, the template-shelf `?idea=` seed, and the "quota exhausted" inline banner (quota model `exhausted` exists).
- **subpackageA myproject -> CreatorContentViews.swift**: no change. The "长按卡片可上下架 / 删除" hint (`myProject.longPressHint`, currently unused)
  would be misleading because the long-press menu is empty while the write endpoints are unapproved. Still missing: the "syncing latest"
  banner while keeping stale rows (the list now swaps to a spinner), ops sheet and writes (gated).
- **pages/template -> DiscoveryTemplateBrowserView.swift**: no change; browse/filter/search/empty/error already match. Still missing:
  cover-load-failure placeholder, `TopicTemplateUseSection` host embedding, use-template write (gated).
- **pages/play -> PlayExperienceView.swift**: not attempted. The 6.7k-line JS and 1.7k-line wxml could not be diffed reliably without a compiler,
  and the listed gaps are writes (backpack/RPG) or transports that don't exist (external-game download).

## Not verified
All Swift is uncompiled. New strings are in `docs/parity/port-4-new-strings.md`. I did not touch Resources, xcstrings, routes, endpoints, leases or gates.
