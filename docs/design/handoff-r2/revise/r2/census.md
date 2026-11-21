# CF-15 · touch-target census (verify-r1 5.7, 2026-11-16)

Rule: every control has a 44 × 44 pt target; the visual may be smaller. Kit components were checked on their main component (visual ≥ 44 or a `hit 44` child); raw text links (›, 修改, 添加…, 重试, 更多 …) got an invisible `hit 44` sibling when no ancestor within 3 levels was ≥ 44 high.

| Page | Frames | Kit controls checked | Kit components below 44 without a hit area | Raw text links | Links given a 44 target |
|---|---:|---|---|---:|---:|
| C1 | 171 | Editor/Row 905, Chapter Card 285, Field 247, Nav Bar 165, Add Row 161, Bottom Bar 158, List Item 155, Save Chip 143, Sheet Header 132, Swatch 90, Sample Tile 88, Option Row 56, Handle 46, Switch Row 42, Seam 41, Rule/Sentence 34 … | none | 159 | 105 |
| C2 | 272 | Field 783 (min 27 high inside rows), PopUp 415, Card 303, Nav Bar 193, Switch Row 163, Switch 157, Handle 149, Answer Option 133, Add Row 120, List Item 117 … | Editor/Switch 51×31 (always inside a ≥ 44 row: the row is the target), Editor/Tool Chip 36 high (22), Editor/Drop Line (indicator, not a control) | 288 | 133 |
| C3 | 161 | Nav Bar 70, Row 62, Add Row 46, Step Bar 43, Field 43, Bottom Bar 43, List Item 41, Sheet Header 34 … | Editor/Switch (1, inside a 56 row) | 45 | 28 |

Follow-up for code: `Editor/Tool Chip` is 36 pt visual — give it `.frame(minHeight: 44).contentShape(.rect)`; Field/PopUp at 27 pt are compact inline values inside 50+ pt rows (the row is the target).
