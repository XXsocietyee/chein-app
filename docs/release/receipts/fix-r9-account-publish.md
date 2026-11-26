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
| A1-02 | open | — | App/QuestifyApp.swift | tabbed self profile as 我的 root: next round |
| A8-02 / A8-03 | open | — | App/ClubHomeView.swift | square posts into club-hub feed: next round |
| C-T2b | blocked | — | App/OwnedTemplateConfigurationView.swift | `TemplateAuthoringSupportPhase` / `TemplateAdoptionConfirmation` exist in Core (TemplateAuthoringDomain.swift:61-69) but nothing produces them (no support-matrix read, no adoption state). Needs a Core producer (Cursor); the view keeps host.loading / failed + 重新加载 |
| C-A8b | blocked | — | App/PublishingModesViews.swift:461-466 | wire already sends the activity span (PublishModesDomain.swift:124-130), but the wizard still requires ticket start/end (ActivityPublishingWizard.swift:271-272). Dropping the fields needs that Core check relaxed first (Cursor) |
| C-T5 (rest), C-F4 (rest), C-F16-r7, C-F2 (rest) | open | — | | each moves/changes a control pinned by 6-58 XCUITests plus source contracts (e.g. 58 `textFields["projectEdit.name"]`); needs a simulator run to land safely |
| C-A9-r7, Mode switch, A3-10, C-I5 (rest), B-SZ-10 | open | — | | P2 |

## Round 3 (r10 audit: `origin/audit/parity-r10-account-publish:docs/audit/parity-r10/account-publish.md`)

Merged `origin/ui/combined-r7` @ 2aa2141f8 (native-r2 restyle) in 6a7407cb1. Conflicts: `App/TeamComponents.swift`
(kept the tip's native spacing + the r9 `memberAvatar` AsyncImage) and `Resources/Localizable.xcstrings` (key union,
ours wins on overlap; 0 overlapping keys differed). Own r9 additions moved off CY tokens (`.bar`, `.red`, literal spacing).
Gate: `python3 tools/check_scaffold.py` → PASS structural checks. Contract checks touching changed files: no new failures vs. base
(`test_pages_privacy_index_page_ready` and `test_run130_topic_media_source_adapter` fail on base too).

| Row | Status | SHA | App file | MP source | Note |
|---|---|---|---|---|---|
| P0 | none | — | — | — | audit lists no P0 |
| N-12 | fixed | 178b4ac5d | App/UsageConsentGateView.swift | privacy/index.wxml:10, :22 | `Form`; drawn checkbox → `Toggle` (**iOS has no checkbox: closest Apple control**); 同意 `.borderedProminent`, 暂不同意 `.borderless`; nav title shown. XCUITest reads it as `switches[...]` |
| N-24 | fixed | a41514783 | App/SquareDetailView.swift:286 | square/detail act-share | `ShareLink` straight to the system sheet; custom half sheet removed; analytics kept |
| C-F7d | fixed | 2b94d90c5 | App/MPGap/AccountPublish/AccountPublishR9Mounts.swift; App/ProjectEditDetailForms.swift:91 | fabu/index.wxml:1324-1334; theme-runtime-structure.js:200-201, :215-227 | `Toggle` 由工作人员开幕 per chapter (not 序章); reason/summary subtitle; Core refusal as footer |
| N-07 | fixed | 59d575d2c | App/ParticipantFormView.swift | addressinfo.wxml:49 | `ContentUnavailableView`, `ProgressView`, 保存 as toolbar `.confirmationAction` (offline section is shared infra, left) |
| N-08 | fixed | 2dda6eae1 | App/MiniCropView.swift | crop/index.wxml:26 | states → `ContentUnavailableView`/`ProgressView`; buttons → `.borderedProminent/.bordered/.borderless`. **Canvas stays custom (no Apple crop control)** |
| N-17, N-05, N-20-23, N-26, N-27, N-09a/b, N-01-04, N-06, N-10, N-11, N-13, N-14, N-28 | fixed on tip | 2aa2141f8 | | | already native on `ui/combined-r7` (grep: no CY chrome left; `cyRootHeader` is `.navigationTitle`) |
| A2-02b/A2-10, C-T6b, C-T8b, A1-08, A3-06/A6-02, B-MK-05, C-S10b, Team avatars, C-F14b, C-F1b | fixed (r9) | see round 1-2 | | | audit ran on 82bcf2c2d, before these landed |
| C-F8b / N-18 | open | — | App/ProjectEditView.swift:1046-1047 | fabu topic-detail-sheet chooseMedia | `PhotosPicker` needs a topic-image uploader + write approval wired through AppSession (Core destinations exist); too much unbuilt plumbing without a compiler. Next round or Cursor |
| C-F2 (rest), C-F4 (rest), C-T5 (rest), C-F16-r7 | open | — | | | move controls pinned by many XCUITests; needs a simulator run |
| A1-02, A8-02/A8-03, A7-02 (rest) | open | — | | | next round |
| C-T2b, C-A8b, C-T3c | blocked | — | | | need Core (Cursor) |
| N-15, N-16, N-19, N-25, N-29 | open | — | | | P2 native, remaining CY offline banners / ProjectEdit bar / gap views |
