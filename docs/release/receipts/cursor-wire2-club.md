# cursor-wire2-club

Base `origin/ui/combined-r7` `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (message starts "Integrate F-agent round 2"). Tip had not moved. No rebase. Branch `cursor/wire2-club`. No pull request.

Source: `docs/release/receipts/cursor-mp-cov-club.md` and `docs/mp-contract-coverage/club.md`. That scan found no in-scope `request(` rows under `api/club`. The settlement call sites it named are already on contracts that exist on this base. Zero call sites moved. No endpoint was added. Settlement was not flipped to GET. Members, governance, and `coopStatus` were not taken.

No `swiftc` run. This receipt does not claim a parse. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. No secret and no mini-program screenshot.

## Sites checked

| Site on this base | Already calls | Contract | Moved |
|---|---|---|---|
| `App/ClubPayoutReceiverView.swift:157` `ClubPayoutReceiverView.load` | `PayoutReceiverService.settlementClubs` | `POST api/club/settlement/mine` body `{}` | no |
| `App/ClubPayoutReceiverView.swift:237` `ClubSettlementMineView.load` | `PayoutReceiverService.settlementClubs` | `POST api/club/settlement/mine` body `{}` | no |
| `App/ClubPayoutReceiverView.swift:354` `ClubPersonalSettlementView.load` | `PayoutReceiverService.settlementSummary(clubID:personal:)` | `POST api/club/settlement/summary` body `{clubId, personal}` | no |
| `App/CooperationFlowFixtures.swift:34` | fixture arm `case .clubSettlementSummary` | synthetic `topics` object; no HTTP | no |

The coverage receipt cited those three view calls at lines 143, 222, and 319 on base `aee32a61`. On this base they are the lines above. Each still goes through `PayoutReceiverBridge` into the same Core methods. `PayoutReceiverRoute.settlementMine` and `.settlementSummary` both use the route default method `POST` (`Core/PayoutReceiverClient.swift`).

`personal: true` is passed only when the screen is the personal settlement:

- `MPParityRoute` sets `personal` from `query["personal"] == "1"` (`App/MPParityKit.swift`).
- The mine list opens `ClubPersonalSettlementView(clubID:personal: true)` (`App/ClubPayoutReceiverView.swift:218`). That is the same navigation as `pages/club/settlement/index?clubId=&personal=1`.
- The view property defaults to `false`. `CoopFlowRead.clubSettlementSummary` still adds `personal: true` only when its Bool is true (`Core/CooperationFlowService.swift`). The fixture arm still matches that case.

A club settlement link with no `personal=1` and a governance context does not use `settlementSummary`. It mounts `ClubGovernanceReadView(operation: .settlement)`, which posts `api/club/settlement/summary` with `{clubId}` (`ClubGovernanceRead.settlement`, `AuthRequestBuilder.makeFormRequest` sets `POST`). That path was left in place.

`CoopClubSettlementDetailView` and `CoopSettlementDetailView` already call `reader.read(.clubSettlementSummary(clubID:personal:))`. `MerchantSettlementDetailLink` sets `personal` only when `query["personal"] == "1"`. Those screens are not in the coverage receipt's call-site list. They were not edited.

## Left as they were

- `PayoutReceiverService.settlementClubs` and `settlementSummary` signatures and bodies.
- `CoopFlowRead.clubSettlementSummary` (POST, not in `usesGet`).
- `ClubGovernanceRead.settlement` (POST `{clubId}`).
- `ReleaseMoneyWriteSwitch.payoutEnabled`.
- Signatures of `SettingsView`, `MerchantVerifyRecordsSections`, `PlatformConsumerSessionOwner`, `RoamPOIActions`, `JourneyReportViews`, `TeamHomeView`, `TicketWalletView`, `TopicXcxSections`, `ClubDetailView`, and `ClubWorkbenchKit` (`ownerStage` kept). `TopicClubShareLink` still uses `Self.clubCode(trimmed)` and `init(clubCode: String?)`.
