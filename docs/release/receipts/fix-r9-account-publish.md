# Receipt: fix-r9-account-publish (Claude App rows)

Branch `fix/r9-account-publish`. Source: `origin/audit/parity-r9-account-publish:docs/audit/parity-r9/account-publish.md`.
Round 2 merged `origin/ui/combined-r7` @ 82bcf2c2d (native-r2 tokens). Gate: `python3 tools/check_scaffold.py` → PASS structural checks.
No compiler in the cloud: Swift unbuilt; contract checks touched by these rows re-run (no new failures vs. base).

| Row | Status | SHA | App file | Note |
|---|---|---|---|---|
| C-T3 | fixed | e1dafdb5b | App/TemplateAuthoringView.swift | round-4 rows mounted; citynode 玩法形态 needs a Core field (Cursor) |
| A7-08b | fixed | 06a7477e2 | App/MiniCropView.swift | 重试 → retryCurrent() |
| A3-06 / A6-02 | fixed | 565ebba9a, 9270aa999 | App/ParticipantFormView.swift; App/ProfileEditView.swift:820 | MP saveInfo/saveAddress save on tap. Profile review/compare sheet removed; UI tests + contracts updated |
| B-PV-04 | fixed | a51182d9f | App/UsageConsentGateView.swift | 我已阅读并同意 gates 同意 |
| A6-01b | fixed | 885531d50 | App/ParticipantFormView.swift | bound phone read-only |
| A4-04b | fixed | cc5349192 | App/PlayerGapViews.swift; App/ClubHomeView.swift | ShareLink via PublicContentShareLink |
| A1-08 | fixed | b16f12b43 | App/QuestifyApp.swift | ContentUnavailableView 登录后查看我的主页 + 登录 |
| C-T8b | fixed | ae8faa8c1, 9dd748d79 | App/TemplateGameplayPickerSheet.swift | 推理 group |
| A2-02b / A2-10 | fixed | bc03633cf | App/SocialPublicProfileView.swift | merchant home swap + 发起合作 bar |
| C-T6b | fixed | 591d656cd | App/AppSession.swift; App/MPReviewedPageScreen.swift | from / scope=MERCHANT |
| A7-02 (rest) | partly | 8030f38c8 | App/ProfileLocalCoverSection.swift | cover 16:9 via MiniCropView; template crop still on TemplateImageCropView |
| C-F1b | fixed | 5230eaa6a | App/ProjectEditRichStoryForms.swift | gallery + branch editors; cell upload waits on C-F8 Core destination |
| B-MK-05 | fixed | 3f81e65d5 | App/AccountComplianceViews.swift:755 | send on toggle, toast 已同意 / 已退订 |
| C-S10b | fixed | 2d9330c58 | App/SquareDetailView.swift:712 | MPAsset medal pill |
| Team avatars | fixed | 085c11af4 | App/TeamComponents.swift:142 | AsyncImage, d_profile fallback |
| C-F14b | fixed | f6ede0224 | App/ProjectEditView.swift:344 | `* 还有 N 项未填`; identity cells = 0 (not collected here) |
| A1-02 | open | — | App/QuestifyApp.swift | tabbed self profile as 我的 root: next |
| A8-02 / A8-03 | open | — | App/ClubHomeView.swift | square posts into club-hub feed |
| C-F2 (rest), C-F4 (rest), C-T5 (rest), C-T2b | open | — | | |
| C-A9-r7, C-A8b, Mode switch, A3-10, C-F16-r7, C-I5 (rest), B-SZ-10 | open | — | | P2 |
