# P-wave Core (P7, P1, P4, P5)

Source: `origin/wip/be-brief` `docs/release/zip-v35` (先读我-给App端AI.md, then UI优化施工清单.md §24). Display order is P7 battle report, P1 invite landing, P4 play-mode choice, P5 seats in a ticket. Backend execution in that package is `NOT_RUN`. This slice is Core only.

A feature stays hidden unless a server fact and a capability are both present. The bindable phases are `loading`, `empty`, `error`, `unknown`, and `ready`. `loading` is bindable only after the client capability is present, and it stays hidden because the server fact has not arrived. `UNKNOWN`, null, a missing number, a numeric string, and an object whose fields the zip does not name are `.unknown`. They are never stored as 0. A literal JSON 0 stays 0.

No App view, DesignSystem file, Theme file, or `RegionalLaunchConfiguration.composition` is changed. `composition` remains `makeComposition(reviewed: nil)`. The reader takes an injected transport, refuses `endpointClass == .production`, and refuses the live hosts this repo already names (`chengyinhub.com`, `chengyinhub.cn`, and `47.103.124.64`). It does not open a live session. Fixtures live only under `Tests/CoreTests`. There is no skip control and no gem wallet.

## Gaps (the zip text does not define these; they were not invented)

### P7 `GET /api/play/player-journey/report`

- `score` and `rank` are names only. Nested fields are not defined, so an object is unknown rather than flattened.
- No duration field. `elapsedSource = UNAVAILABLE_OTHER_RUN` is the unknown-elapsed case. Any other elapsed amount is also unknown.
- No JSON token for “本局新获得”. `rewardsScope = TOPIC_ACTIVITY` is the theme/activity backpack and is not labeled as a grant earned this run. Other `rewardsScope` values are not labeled that way either.
- No `runState` token that means success, so a success settlement is not shown. Raw `runState` is kept when it is a string.
- No positive token that means “this is one run”. `LEGACY_TOPIC_SCOPE` is not one run. `UNATTRIBUTED_RUN` does not fill current content. Other `scopeKind` values are not promoted into either claim.
- No fields for the work title, city, completion / early-close / assisted-skip result, completed-node count separate from `rank`, hint deduction, or the card/reward list.
- The carrier key for `RUN_NOT_FOUND` / `RUN_SCOPE_MISMATCH` is not named. An exact string anywhere in that response is an error, and another run is not opened.
- `rank` is the theme completed-node rank from the prose, not a puzzle net score. The report table does not include `scoreBasis`, `scope`, or `period`; those P9 query fields are not added to this payload.

### P1 `POST /api/referral/landing/referral` and `POST /api/referral/landing/gift`

- `target`, `product`, and `nextAction` have no field list. Presence is recorded. Contents are not projected. Phone, email, `memberId`, and the credential are not copied onto the fact.
- Inviter fields other than `nickname` and `avatar` are not defined and are dropped.
- The state token that authorizes “朋友送你一局” is not defined, so that headline is not produced. `state = VALID` uses “朋友邀请你一起玩”.
- Gift wire tokens for 过期 and 撤销 are not defined (`CLAIMED` is). Reclaim is not offered for any gift state.
- `registrationState` values other than `UNKNOWN` are not defined. No value draws “已获免费/保证可报名”.
- The field that carries `NOT_ON_SALE` is not named. `freeSelfPlay = true` stays a free entry in any case, which is the prohibition the zip states. A missing `freeSelfPlay` is not `false` and does not open a free entry.
- `expiresAt` and `claimExpiresAt` formats are not defined. The raw string is kept. The string `UNKNOWN` is not parsed as a date.
- `recipientBound` is read only when it is a JSON boolean.
- These two POSTs are reads (`{token}` only). The later claim API and its `requestId` are not part of this landing contract. No invite-landing route is named.
- The login header is not named. The reader uses the existing raw `Authorization` session token, separate from the landing credential.

### P4 `GET /api/play/player-journey/choices`

- A choice object’s fields (mode id, progress, hint scope, score scope, seat count) are not defined. The Core records the array length only and does not mark any mode submittable.
- `requiredCapabilities: null` or a missing key is not “no capability required” (the manifest rule in §23.3; §24.3 names the field and does not restate null). An empty array’s meaning is not defined; it is treated as declared but not satisfied, so the feature stays hidden.
- The shared hint/score pool has no wire token. §25.1 says it is not implemented. `PER_MEMBER` is honored only as an exact string value, because its field name is not given. Shared deduction is not offered.
- `runtimeScope`, `worldMode`, and `routeMode` have no schema. Only JSON strings are kept.
- `teamModeSource = CURRENT_TOPIC_COLUMN` means that column is not frozen. Other values do not become “frozen”.
- No field for an in-progress run (“继续本局”) or for a competitive-board capability.

### P5 seats

- The summary is described as “原单N / 核销事实 / 邀请摘要”, and `free = (N - 1) - pending - claimed`, but those JSON keys are not named. `free` is not computed. Pending, claimed, used, and N are not displayed.
- The field that carries `PENDING` / `CLAIMED` is not named, so those tokens are not read from an invented key.
- The invitation-row container key is not named. An array of objects is projected. Nested rows under an unnamed key are not.
- Only `expiresAt` (raw string) and `originalPaid` (JSON boolean) are read. `originalPaid` does not satisfy play admission.
- `seatNo`’s JSON type is not defined. The unsent draft keeps a caller string and does not transmit it.
- The page must not default the TTL to 168 hours. `expiresAt` is read as returned.
- Invite, claim, cancel, and release are not available. The migration has not run, and the release protection was sent back for in-progress-only checks. Same-`requestId` replay is equality on the unsent draft only.

### Shared

- Client capability key strings for P7, P1, and P5 are not in the zip. The grant is an explicit caller set and defaults to empty, so the shipped app shows nothing until a caller passes it. P4 additionally requires the server’s `requiredCapabilities` strings to be present and supported.
- P2, P3, P6, P8, and P9 are the later slice below. P9 member rank stays hidden until the server sends the rank fields; the zip still says that rank is not implemented.
- No production base URL is checked in. Pointing this reader at a live host is refused.

## Later slice (P2, P3, P6, P8, P9)

Same rules as the first slice. A caller grant only allows the read to be sent. The feature stays hidden until `requiredCapabilities` is a non-empty list this build supports. A missing key, null, or an empty list is not an empty success. `UNKNOWN`, null, a missing number, and a numeric string stay unknown and display as an em dash. A literal JSON 0 stays 0. Writes that would issue a link, remind, quote, order, pay, activate, claim, or publish are refused and send nothing.

- P2 reads `GET /api/marketing/affiliate/summary?limit=20`. Credential bodies are not stored. `held.amountFen` null is not a balance. `payout.available` must be JSON true, and false does not open withdrawal. `amountUnavailableReason=MULTIPLE_CURRENCIES` does not become one total.
- P3 posts ordinary form fields to the six public-catalog paths. It does not send a JSON body, pad sample chapters, turn a null group or school flag into “不接待”, or report an arrival reminder. `priceState=UNKNOWN` does not fall back to another price.
- P6 reads the product list, one product, and orders. Purchase stays hidden: this client does not quote or decide sale from the tier. Catalog price is not the deal price. A fixed term is not described as renewing, and no trial is added. Order rows stay the frozen snapshot.
- P8 reads the memory and theme-history session ids. Moment bodies are not copied. Other private photos stay hidden when the consent fact is missing or is `NO_PRIVATE_PHOTO_SHARE_CONSENT_FACT`.
- P9 quest rank is shown only for `scope=quest`, `period=all`, and `scoreBasis=COMPLETED_NODES`. Between-teams rank needs `orient.team.board.enabled` true and is not a member rank. Member rank needs that switch, `memberRankBasis=COMPLETED_TASK_COUNT`, and each member’s `doneTaskCount`, `rank`, `ranked`, and `mine`. `doneTaskIds` are not a rank.
