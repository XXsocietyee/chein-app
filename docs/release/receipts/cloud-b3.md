# Cloud B3 — production conformers for the layout binding stubs

Branch `ui/cloud-b3-stubs`, rebased onto `origin/ui/next` `b87ab5aad675eda15e5dc2cc25e10f4debadfdce`.

`ui/mpdrift` already declared `AIGCFilingNumberKey`, `IMReportProgressUnreadKey`, `PlayEmergencyLocationProviderKey`, `PlayThemePresentationFacts`, and `PlayThemePresentationReaderKey`. This branch fills those existing symbols. It does not declare them again. `PlayThemeFactsStore` maps `PlayThemeLookTokens` through the existing `CYThemeLook(style:palette:neon:)`.

This branch adds a production reader only where an existing Core route already returns the field. It does not invent a filing number, a coordinate, a score, a price, a count, an NPC, or a replay body. Purchases, claims, payout, withdrawal, and virtual goods stay off. Governance reads and mutations stay off. No route was marked live.

`tools/check_design_lint.py` passed. `tools/check_scaffold.py` passes catalogs, release config, privacy, design lint, and project equivalence, then stops on the AppSession ratchet. That ratchet already fails on `origin/ui/next`: `AppSession.swift` is 8206 lines against 8181, and `AppCompositionRoot.swift` is 4784 lines against 4498. This branch does not add lines to either file. This VM has no Swift compiler, so nothing was compiled.

## Conformers

| Stub | What production does |
|---|---|
| `PlayThemePresentationReading` | `PlayNodesResult.themeFacts` reads optional `topicAiGenerated`, `productType`, `topicCover`, and `look_json` from the same `/api/play/nodes` object. A bad look or cover does not fail the route. `PlaySessionReader` reports a result only after that read commits. `PlayThemeFactsStore` keeps those facts for the account and session epoch that produced them and publishes the existing `PlayThemePresentationFacts` through `\.playThemePresentationReader`. `facts(topicID:)` is nil until that topic has been read. `topicAiGenerated` counts only as JSON `true`. `productType` skips the card pack only when present and not `2`. Cover URLs are http(s) with a host and no userinfo. `look_json` may be an object or a JSON string. Unknown style is no look. Unknown palette becomes `DEFAULT`. Unknown neon becomes `YELLOW_CYAN`. |
| `PlayEmergencyLocationProviding` | `PlayEmergencyLocationConformer` is injected at the player root. A tap returns a held fix when the host has one (this session does not), otherwise one `requestLocation` while the app is active, location services are on, the when-in-use purpose string is present, and authorization is already when-in-use or always. `0,0` and non-finite values are dropped. It does not call `requestWhenInUseAuthorization` or `startUpdatingLocation`. |
| `imReportProgressUnread` | `ReportProgressUnreadReader` counts unread `SquareGovernanceNotification` rows whose payload action starts with `REPORT_`, first page only. `AppSession.squareGovernance()` still builds the service with reads disabled, so the count is nil and the badge stays hidden. It does not turn reads on. `markOpened()` does not send `POST /api/v1/community/notifications/{id}/read`: the production mutation grant does not include mark-read, and this reader does not invent a review id. |
| `aigcFilingNumber` | `SquareService.aigcFilingNumber` reads `data.aigcFilingNo` from the existing `POST api/config/features`. Only a JSON string is kept, trimmed, capped at 64 characters. A number or bool is not turned into a filing number. Empty is nil. The root task injects the string. Feature flags are unchanged. |
| `ProfileParticipantListFactsReading` | `ProfileParticipantHost.Reader` (the reader `AccountView` already passes) and `ProfileSessionReader` both call `ProfileService.participantListFacts`. `total` stays nil when the payload omits it. Rows are the same list as `participants()`. |
| `OrientScoreEntryProviding` | `AppSession` builds `OrientSessionService` with contract `.currentC6` (the frozen contract cannot discover a session) on the session's existing transport and returns a loader only when API configuration exists. The loader calls `current(topicID:activityID:)` and then `score` only when that response contains exactly one session. Zero or more than one returns nil. It does not call sync, settle, appeal, or dispute. |
| Information-list receipt | `SocialAccountService.informationListReceipt` is the body and HTTP status of the same bodyless `POST api/common/infomation_list`. `informationList()` is unchanged and still drops envelope `total`. `routeMarkedLive` stays false. 401 still signs the caller out. |
| Square detail and comments bodies | `SquareService.detailBody` and `commentsBody` return the success envelopes of `POST api/creativesquare/info` and `POST api/comment/list`. `detail(id:)` and `comments(postID:)` are unchanged, including their zero default for a missing count. The bodies are what `SquareXcxPresentation.resolvePost` and `resolveComments` read. |
| Topic list body | `TopicService.listDocument` is the same `POST api/topic/list` as `list()`, plus the success envelope. `TopicPage` is unchanged. `list()` now returns `listDocument(...).page`. |
| Official events receipt | `OfficialEventService.eventsReceipt` is the body and status of `GET api/official/events`. `events()` is unchanged. 401 still signs the caller out. Other statuses are returned so a malformed payload can be classified instead of being collapsed into the decoded-row error. |

Injection is `CloudB3RootModifier` on `SessionRootView.chain0`: theme facts, the SOS provider, the filing string, and the report unread count.

## Written reasons (no conformer)

These stay unwired. A conformer here would have to invent a payload, turn money on, or send a write this tree does not have.

- **`IMInviteReminderBinding`.** `SquarePreference` is only `interactionEnabled`, `mentionEnabled`, and `socialEnabled`. There is no coop-invite preference. A local stand-in would not be the server preference, and enabling it would prompt for notification permission without that contract.
- **`IMReviewAuditReading`.** No Core route returns an audit status and timeline for a task id. No record is synthesized.
- **`PlayThemeReplayBinding`.** `Core/PlayThemeRecords.swift` does not port `POST api/play/theme/replay` because that write clears the server run. No request body and no `replayAllowed` are decoded. The button stays hidden.
- **Club topic-story AI label.** `TopicDetail` does not decode `publishMode`. Missing is not treated as `ai_simple`.
- **`ProjectNodeNPCAuthoring`.** No topic-node NPC load or save exists in Core. Merchant node authoring is a different hidden surface. Photo look and voice stay deferred, as `mp-mpflows` already says.
- **Node `xpValue`.** Merchant content checks forbid persisting `xpValue`, and the play node wire does not carry a saved exploration value. No number field is added, and no default XP is filled in.
- **Personal best.** No personal-best field exists on `PlayThemeHistoryRow` or `PlayThemeResultCard`. `CYMedalScreen.Record` is not on this base. The record card stays hidden.
- **Chapter time, clue, and cover.** `PlayChapter` decodes `chapterId`, `name`, `description`, and `audioUrl` only. Stops completed and chapter index already come from the snapshot on the layout branch. No time, clue, or cover is guessed.
- **Verdict timer and author result media.** The runtime does not report that a timer expired, and the node read has no author result text or images. `timedOut` is not forced.
- **Date-range sheet.** The editor still uses the two single-date sheets. This is not a data stub, and no range is invented.
- **`VideoBountyBinding`, `PassMarketBinding`, `PassDetailBinding`, `PassGiftClaimBinding`, `PassMembershipBinding`, `PassLibraryBinding`, `revealAccountKey`.** Those protocols are not on this base. Product, quote, points, gift, and library rows are not fabricated. Cash pay, claim, and unlock stay off.
- **`JourneyLandingBinding`, `JourneySeatsBinding`, `JourneyPromoBinding`, `JourneyReportBinding`, `JourneySettleBinding`.** `PWaveReader` refuses a production host. Claim, invite, cancel, rating, and referral writes stay unavailable. No landing, seat, report, or settle rows are invented. `MPParityRoute` is not on this base, so deep links are not remapped onto it.
- **`RoamPlaceExtrasBinding`.** No production reader for official place game facts, cited quotes, photo credit, or place reviews is on this base. No place card is filled with sample copy.
- **Activity signup, team join, roam session footprint** listed under `mp-mpmissing` audit leftovers. Payment and ticket purchase stay off. Join codes, applicant lists, and footprint cards are not filled with sample rows.
- **Orient extras** (session chooser, leaderboard, recovery, manual review, appeal per entry). The loader above does not pick among sessions and does not call those writes. No leaderboard is invented.
- **Coupon edit.** `CouponManagementContract` is `/api/coupon/mypublishlist`, `/api/coupon/publish`, and `/api/coupon/stop`. There is no update. `couponManagement.save`, `.network`, `.dataError`, and `.retry` are not given a fake submit. Publish is not turned on.
- **Coupon wallet 403 and `availableFrom`.** No permission phase is added. The existing "Not yet started" copy stays, because a UI test pins it. No start date is invented.
- **Free-explore price, paid amount, and refund quote.** `FreeExploreBundleLaunchModel` has no price. `grants.pricing` stays nil. `readRefundQuote` is not called. The paid row is not given a number. Payment, payout, and withdrawal stay off.
- **Complaint catalog keys and Core W8Text switches** (`profile.complaint.*`, `characterCard.*`, `orientScore.*`). Those catalogs are on the layout branches, not on this base. Switching Core to keys that are not in this tree would show the key strings. The Chinese fallbacks are left as they are.
- **mylike `likeNum`.** The topic list body is now available for `resolveTopics`. `TopicSummary` is not changed to pretend a missing like count is unknown by substituting another number.
- **Topic duration and unknown `productType`.** `TopicXcxFacts.duration(nil)` is not replaced with a made-up duration.
- **Official organizer nil read.** The console still substitutes an empty organizer state for a nil read. This branch does not replace that with a fabricated status or control.
- **Search counts.** `GlobalSearchParityPresentation.resultTabs` still takes `Int` counts. No count is invented, and the merchant placeholder copy is not rewritten on this base.
- **`mp-prroam` leftovers** (stamp-camera assertion flip, missing `ui-strings` JSON, roam passport summary, IM coordinator, badge-wall coordinator, crop shape, club director sheets). `GET /api/roam/passport/summary` is not a reader on this base. Local roam `history()` is left in place. Contract assertions are not flipped to claim wiring that is not here. Crop and director actions are governance and layout, not a payload this branch can decode.
- **`mp-prkeys` contract-count review.** The coupon key-count flips live on `ui/prkeys`. They are not re-applied here.

## Merge note

The mpdrift symbols stay where `ui/next` declared them. `CloudB3RootModifier` writes the existing environment values. `PlayThemePresentationReading` stays in `App/PlayThemePresentation.swift`. `PlayEmergencyLocationProviding` stays in `App/PlayInPlayTools.swift`. Do not add a second `PlayThemePresentationFacts`, `PlayThemePresentationReaderKey`, `PlayEmergencyLocationProviderKey`, `IMReportProgressUnreadKey`, or `AIGCFilingNumberKey`.

`ProfileParticipantListFactsReading` and `OrientScoreEntryProviding` are not in the layout files. `OrientScoreEntryBinding.makeLoader` is a separate static. `ParticipationDetail` still does not expose `productType` or the activity id `_resultEntry` needs, so `makeLoader` stays nil and the entry stays hidden. The `AppSession` loader is only for a caller that already has a topic id and an activity id.

Layout protocols that are now on `ui/next` and are listed under written reasons stay unwired. A conformer would still invent a payload, turn money on, or send a write this tree does not grant.
