# State kit K (built by executor A+B, 2026-11-15)
Figma page R3 `91:33`, section `217:4466` "K 状态组件 · State kit". All colours are bound to the Color variables, so an instance shows the light theme inside a frame set to MP-Light (81:1), and the dark theme inside MP-Dark (81:0).

| Kit | Node | Variants / text props |
|---|---|---|
| K2/K3/K4/K5 `K/State` | 217:4511 | Kind=Error/Empty/Lock/Info · title, sub, showSub, action, showAction |
| K1 `K/Skeleton` | 217:4574 | Type=list/card/detail/amount/metric |
| K6 `K/Inline Error` | 217:8259 | title, sub, action, showSub, showAction |
| K7 `K/Strip` | 217:8268 | text |
| K8 `K/Result Pending Banner` | 217:8272 | title, message, primary, secondary, showButtons |
| K9/K10 `K/Alert` | 217:8315 | Tone=Default/Destructive/Destructive · Input · title, message, cancel, confirm, placeholder |
| Sheet header | 217:8316 | title, showClose, showGrabber |
| K11 `K/Result` | 217:8336 | Kind=Success/Fail · title, sub |
| K13 `K/Option Row` | 217:8351 | Selected=true/false · label, sub, showSub, showSep |
| K12 `K/QR` | 217:8352 | name, desc |

Helper prelude for composing frames: `prelude.js` in this folder (set `const PAGEID='…'` first). Set text props with setProperties using the base name (the prelude's `setP` maps it).
