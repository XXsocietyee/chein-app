# PAGE-READY — subpackageMember/invoice-title-edit/index

新增与编辑发票抬头. Native view: `App/InvoiceLaunchTitleEditor.swift` (unchanged). Map status stays `exists`. No route was marked live.

Source checked: mini-program `chengyinhub-xcx/subpackageMember/invoice-title-edit/index.js` and `index.wxml`, `chengyinhub-xcx/utils/user-invoice.js` `title` / `titlePayload`, and `UserInvoiceServiceImpl.titleView`. The public title object is `id`, `titleType`, `titleName`, `taxNoMasked`, `isDefault`.

## Model

`InvoiceLaunchTitleEditorRead` in `Core/InvoiceLaunchTitleRules.swift` binds that existing list and the existing save journal (`InvoiceLaunchPending.kind == .saveTitle`). It does not send HTTP and does not add a path.

| Screen | When |
|---|---|
| loading | Edit id, titles not back yet. An unconfirmed save does not skip the load. |
| empty | Login required, or the invoice feature is off. An empty title list is not this state and is not shown as 0. |
| error | Titles read failed, or the edit id is not in the list. |
| UNKNOWN | The form is ready and a title-save journal is still open. The request id is the journal's, including when it is absent. |
| ready | New title (no positive id), or the id was found, and no title-save is pending. |

A query id of `0`, a blank, or a padded number is a new title, not id 0. Create does not wait for the list. The blank form is company, empty name, default off. That off is the mini-program blank draft, not a missing number stored as 0.

## Unknown text

Missing id text and a missing, empty, or non-mask `taxNoMasked` render as `—` (U+2014), never `0`. A mask the contract already accepts (`91******1234`, `******`) stays that mask. A literal title name `0` stays `0`. The editable tax string stays empty. A raw tax number on the JSON object is not copied.

## Missing keys

These are not in `titleView`. The model does not invent them.

- `taxNo` — stored encrypted; the public read returns `taxNoMasked` only. Edit requires the person to type the full tax number again.
- `phone` — not on `UserInvoiceTitle` and not on this page.
- `email` — not on `UserInvoiceTitle` and not on this page.
- `memberId` — owner is the session, not a field on the title view.
- `delFlag` — not in the public view.
- `createTime` — not in the public view.
- `updateTime` — not in the public view.

## Left

`App/InvoiceLaunchTitleEditor.swift` still keeps its own fields and still saves through `InvoiceLaunchPresentation`. It does not read this screen. Strings, the page catalog, the Xcode project, and the CI ledger were not edited. `xcodebuild` was not run. This machine has no Swift toolchain, so the new tests were not executed.
