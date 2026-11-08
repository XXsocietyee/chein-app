# ADAPT-1 — new user-visible strings

None. The adapter files add no UI and no `Resources/*.xcstrings` entries.

Wire-only literals (not UI, not localizable): `"[位置]"` (type-3 `content`, which the backend overwrites with `"[位置] " + name`), `"："` (separator between report label and note, part of the `reason` text sent to the backend), `"app-derived-im-conversations-v1"` (App-side marker).

A future caller that wires these in must supply localized report-reason labels (e.g. `NativeChannelReportReason.title`) itself; the adapter takes the label as a parameter.
