# cloud-b4

Public catalog reader. Branch `ui/cloud-b4-catalog`. Base `origin/ui/next` `2ad670779246cad4bc36cb4e4fcf1b4f44ac3859`. Not merged to `main`, `rc`, or `ui/main`.

## What is wired
| Piece | File | Behavior |
|---|---|---|
| Reader | `Core/PWaveP3ThemeCollection.swift` through `PublicCatalogHost` | Posts form fields to `/api/public-catalog/list`, `/api/public-catalog/filters`, and `/api/public-catalog/info` only |
| Screen | `App/PublicCatalogViews.swift` | Keeps `PublicCatalogView`, `PublicCatalogCardRow`, and `PublicCatalogDetailView`, and feeds them from list, filters, and info. No quote, order, or pay control |
| Host | `PublicCatalogHostWiring` in that view file, presented from `NativeEntryLandingView` | Shipped session leaves `host` nil, so the screen sends nothing. An absent capability hides the UI |
| Universal link | `PublicCatalogLink` via `NativeEntryLinkPolicy` and `UniversalLinkParser` | `/catalog`, `/catalog/list`, `/catalog/filters`, `/catalog/info?id=` when a caller supplies a verified origin. Default origins stay empty |

Map, ids, and city list are not links and are not called by this host. Money stays off: `PublicCatalogHost.moneyEnabled`, `PublicCatalogViews.moneyEnabled`, and `PublicCatalogHostWiring.moneyEnabled` are false. `quote`, `order`, and `pay` throw `writesNotAvailable` and send nothing. A link query named `pay`, `quote`, `order`, `price`, `amount`, `buy`, or `payment` is rejected.

Unknown price (`priceState=UNKNOWN`, a missing amount, or a numeric string) is an em dash (`—`) from `PWaveCatalogCard.priceText` and `PublicCatalogPrice`, including when the payload also contains `priceFrom: 0`. A literal JSON 0 with any other price state stays `0`. The unit is hidden while the price is unknown. The screen does not substitute a fake number.

The reader is injected and still refuses a production endpoint. This change does not open a live session and does not mark the China reviewed routes live.
