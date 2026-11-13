# Integration batch 6: ext-games, IM preview UI, tab pill (2026-11-13)

Integrator branch `integ/next`, pushed to `ui/next` and `ui/main` (fast-forward only).

## Merged

| Branch | Head | Notes |
| --- | --- | --- |
| `ui/cur-tabpill` | `8d2e7087a` | `ui/main` already had the glide plus the iOS 26 side inset. Kept that, took the seeded `landed` init. |
| `ui/cur-im-preview-ui` | `4567bbc00` | Recipient preview row on conversation messages. |
| `ui/cur-ext-games` | `d8e7a3b4d` | External game review flow and Ed25519 verify. Monetization stays NONE. |

## Integration fixes

- `ChinaReviewedRouteCapability`: kept both sides: the batch 5 owner grants plus `externalGameOwnerGrant` / `externalGameGrantKey`.
- ext-games parsed but did not compile. Three one-line fixes:
  - `ExternalGameSession`: a local `host` shadowed `host(from:)`, so it now calls `Self.host(from:)`.
  - `ExternalGameImportTests:325`: argument order.
  - `admitsExternalGame` now uses `ReviewedProductionGateLeases.externalGamePaths`; it was unqualified from another type.
- IM preview security condition: the only App call site passes `Int64(message.conversationID)`, where `message` is the
  decoded `MessagingMessage` server record. `test_im_preview_lease_conversation_source.py` now accepts an integer-width
  conversion of a record field. It still rejects route, selection and input sources (checked with a planted negative case).
- `WorkshopPurchasedNormalAccountTests` (coordinator decision: the app is right, and merchant/club accounts keep their real
  role):
  - The harness builds `PlayExperienceSession` with the wire role instead of the `"player"` default.
  - The hosted case expects `context.session.role == role`.
  - `AppSession` is injected above the `NavigationStack`, as the app does, so the pushed detail can resolve it.
  - The ci138 contract string follows.
