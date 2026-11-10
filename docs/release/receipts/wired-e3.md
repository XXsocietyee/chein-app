# wired-e3 (SL3)

Branch `ui/e3`, merged with `origin/ui/main` 44dd09c36. No local build was run; cloud checks are read per push.

## Wired (view reads the model property)
| page | model | view change |
| --- | --- | --- |
| club/apply | `ClubHostApplyPageModel` | host-done limit row reads `.allowance.displayText` (em dash unknown, 0 only real 0) |
| club/checkin-detail | `ClubCheckinDetailPage.bind` | rows gated on `.showsContent`; registration id and paid amount read from `Facts` |
| club/create | `ClubCreatePageModel.interpret` | record count and host-application link (cursor/wire9, cherry-picked) |
| club/customer-detail | `ClubCustomerDetailCount` | metric tiles read `.displayText`; removed wire10's App-local `ClubCustomerDetailPage` that shadowed the Core type |
| club/detail | `ClubDetailPageModel.resolve` | member count em dash, channels entry hidden without capability (re-applied by hand: cursor/wire11 conflicted with the current hero) |
| club/governance | `ClubOpsGovernancePage.project` | ban section count (cursor/wire13) plus call site now passes scope, capability, document |
| club/group-code | `ClubGroupCodePage.project` | session headcount (cursor/wire14) |
| club/join-requests | `ClubJoinRequestsPageReady.pendingCountText` | intro exposes it as accessibility value, gated on visibility |
| club/notify | `ClubNotifyPage.unknownDisplay` | unknown audience count shows an em dash instead of blank |
| coop/invite-detail | `CooperationInviteDetailPage.project` | slot line reads `slotCount`/`slotCapacity` |
| coop/list | `CoopListPageCoordinator.project` | invitation/application counts and new-invite gate |
| talent/im list | `IMListPageReady.unreadTotalText` | segment badges (unknown is an em dash, real 0 shows no badge) |

## Partial
- club/edit `ClubEditPage`: `make(readback:write:...detailBody:blockersBody:)` needs the raw detail body, which the view does not hold. Only the locked-summary quota now shows an em dash instead of 0. cursor/wire12 uses an API that does not exist (`make(quota:canDissolve:)`) and was not taken.

## Not wired
- `ClubTabPageModel` (pages/talent/list): `project(homeData: [String: Any]?)` needs the raw home payload; `ClubHomeView` only has decoded records. Needs a reader change.
- `IMChatSessionPage`: exposes `unreadDisplay`/`messageCountDisplay`, but the chat view renders neither; wiring would add UI (layout change). `pollVisible`/`readReceiptVisible` are fixed false and were not used to gate live controls.
- `NearbyMerchantPage`: the type does not exist in Core and no `origin/cursor/*` branch holds it.

## Not taken from cursor
- cursor/wire7 (club/apply): its Core `ClubHostApplyPageModel` conflicts with the existing, richer one; redone by hand.
