# cur-be-gap-im

App branch `ui/cur-be-gap-im` from `ui/main` `cf28847602bc393ebcead93ca35d85633d23801b`.

Backend branch `feature/be-gap-im` from `integration/backend-app-r2` `2e6f6651ce6ca4205a5204a3758d62f9c355017b`.

## What the player can open

Club detail, posts tab, **Channel tools** (`beGapIm.entry`). The row is on the same signed-in club page as club chat. It is not a debug flag.

Each button calls the live route and shows the server payload, or the server error. A missing id does not leave the device. A write is shown only as the fields the server returned. Unknown text is `—`.

| Path | Screen |
| --- | --- |
| `/api/im/audit-log` | Audit log. Also issued to the existing channel audit screen. |
| `/api/im/chain` and `/api/im/channel` | Chain info and check-in status. Create/join/close/check-in writes are issued to the existing screens. |
| `/api/im/file/message`, video, voice, attachment | Message file reads authorization, preview, voice and the attachment. |
| `/api/im/members/{}/roles`, `/api/im/roles/{}/members` | Role list is on this screen. Create is issued to the existing role screen. Member replacement stays on that screen's exact route when the id is known. |
| `/api/im/moderation`, revoke | Moderation actions. Timeout, kick and ban are issued to the existing moderation screen. |
| `/api/im/notification-requests` and the five channel-platform receipt prefixes | Receipts, using the record id. |
| `/api/im/poll/create-receipt` | Poll receipt. Also issued to the existing poll screen. |
| `/api/im/webhook`, `/api/im/webhook/context` and the Core client's subscription/endpoint children | Webhook context, and an explicit create button. |
| `/api/channels` | Channel directory for this club. |
| `/api/channel/{}/board/{}` | Board list plus `.../version` for the board key. |
| `/api/im/appeals/{}/evidence`, `/api/im/appeals/{}/withdraw` | Appeal evidence and withdraw. Both require the appeal id and a note. |

`ReviewedAreaSwitch` is new. `moneyPayments`, `payout`, `merchantWrites` and `passwordLogin` are false on `www.chengyinhub.com` and true only for TEST/DEBUG against another host. `externalGames` uses that same rule. This screen does not call those switches.

`AppSession.swift`, `AppCompositionRoot.swift` and `RegionalLaunchConfiguration.swift` were not edited. The contract baseline was not raised. Capability mark counts were not changed.

Grants were appended in `ChinaReviewedRouteCapability.beGapImOwnerGrant` and the static routes in `ReviewedPlayerWriteLeases.beGapImRoutes`. The two files were not reformatted.
