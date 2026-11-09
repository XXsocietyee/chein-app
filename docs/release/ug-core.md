# UG-01…UG-10 Core

Source: `origin/wip/be-brief` `docs/release/zip-v35` (先读我-给App端AI.md, then UI优化施工清单.md §10–§12, `content-schema.v1.json`, and the contract vectors). Backend execution in that package is `NOT_RUN`. This slice is Core decoding, capability flags, and tests.

A feature stays hidden unless the caller grant is present. `game.hangman`, `game.qa`, and `media.image` are the only server keys this package names for these items. A declared missing key hides that feature. `supported == null` (UNDECLARED or MALFORMED) is unconfirmed: it is not rendered as unsupported and it does not block the read. Hint ladder, free quota, receipt, skip, and clue transform produce no capability key. Their grant is an explicit caller set and defaults to empty.

`UNKNOWN`, null, a missing number, and a numeric string are `.unknown`. They are never stored as 0. A literal JSON 0 stays 0. `NOT_SCORED` does not render a score, including a literal 0.

No App view, DesignSystem file, Theme file, or `RegionalLaunchConfiguration.composition` is changed. `composition` remains `makeComposition(reviewed: nil)`. The reader takes an injected transport, refuses `endpointClass == .production`, and refuses the live hosts this repo already names (`chengyinhub.com`, `chengyinhub.cn`, and `47.103.124.64`). It does not open a live session. Fixtures live only under `Tests/CoreTests`. Help use, skip, hangman submit, and accusation submit throw `writesNotAvailable`. There is no skip control and no gem or coin wallet. Points are the existing redeemable ledger. A paid workshop install does not complete; the reason is `PAID_INSTALL_AUTHORITY_UNAVAILABLE`.

## Gaps (the zip text does not define these; they were not invented)

- `PlayHelpViewVO` does not list the player counter. `remainingFreeUses` is the policy-vector input name. A present integer is kept. A missing key stays unknown and is not defaulted from `hintFreeUsesPerRun`.
- `helpReceipt` is named in the UI list and is not a schema definition. Only the keys that list names are read. The client does not compute `netScore`.
- Accusation outcome copy is the string `winScreen` or `loseScreen` after submit. An object screen has no named text field, so no string is chosen. `recordAs` is not shown.
- Unreadable progress is a missing or non-boolean `early`. The client does not derive it from `clueGateSatisfied`.
- Skip stays without a control because runtime verification is `NOT_RUN`. Server `usable` on a `SKIP` layer is recorded and does not become a button. Reveal is not skip.
- `PlayDurableRecovery` is local storage. It is not given network authority. UG-09 classifies the wire receipt beside it.
- The hangman catalog and renderer are not marked synced. The client does not judge, store, or cut `answer`, `aliases`, or `format`.
- A non-empty `hintLadder` with no explicit N reads as 0 only inside `UGRunQuota`, which is the named server rule. Conflicting explicit N values stay a conflict. Root does not win. The player counter is not that rule.
- Client capability key strings for UG-05 through UG-10 are not in the schema. No `hint.ladder` or `accusation` key was added.
