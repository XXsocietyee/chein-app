# UI-04 report — Clubs / channels / IM (NOT COMPILED)

Theme: dark (player surfaces). Base `origin/wip/gate-allowlist`. Presentation-only; no logic, contract, or identifier changes.

| File | What changed | Follows | Theme | New keys |
|---|---|---|---|---|
| App/ClubChannelMessagingView.swift | Raw `.red/.orange/Color.accentColor` replaced by `CYColor` tokens (danger/warning/accent text + soft fills) for sender avatar, role badge, ban badge, send-failed state, swipe tint; decorative failed icon hidden from VoiceOver | Pattern: token-only colours, dark/light safe | dark | none |
| App/NativeChannelTextComposer.swift | Reply-unavailable text uses `Theme.Color.danger(in: domain)` instead of `.red` | same | dark | none |
| App/NativeChannelReportSheet.swift | Note-too-long uses danger token; progress spinner gets VoiceOver label (existing key) | same | dark | none |
| App/NativeChannelMessageActionSheet.swift | Edit/recall validation text uses danger token (added `themeDomain` env read) | same | dark | none |

## Not done
- Not compiled/screenshotted (no Swift toolchain here).
- No previews added: touched views need coordinators/flows that cannot be faked safely without compiling.
- Channel list, IM inbox, bubble layouts already use native List/Form/ContentUnavailable and Theme tokens; left unchanged to keep diffs small.
- Role-theme forcing (`preferredColorScheme`) is UI-01's scope.

Files touched: 4 (+ this report). New component files: 0. New string keys: 0.
