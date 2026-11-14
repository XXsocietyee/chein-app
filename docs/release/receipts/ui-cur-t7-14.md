# ui-cur-t7-14 receipt

Visual and layout rebuild of Template 7 (profile, passport, badges, growth, leaderboard) and Template 14 (settings, legal, QR, account deletion). Branch `ui/cur-t7-14` is cut from `origin/ui/h-design-v1` at `5d652cc08ac5ccc668db315fc57253b909b9e058`. `ui/h-design-v1` was not moved. `ui/cur-t1-2`, `ui/cur-l10n-qa`, and `ui/main` were not merged. Design source was read from `origin/docs/design-md` at `b9193733e6539da09f016d134465b00c53a82317` and was not copied onto this branch.

Player surfaces stay on the dark domain palette. Merchant surfaces stay light. The reserved ring tint is used only on the player avatar ring (`palette.avatarRing` when `themeDomain == .player`). Buttons, cards, tags, and body text do not use it. Radius names used: `Theme.Radius.sm`, `md`, `lg`. No `CYRadius.card`. No slate-blue inks. Data bindings, grants, APIs, and money switches are unchanged. `RegionalLaunchConfiguration`, `AppSession`, `AppCompositionRoot`, and the contract baseline were not edited. Unknown values stay an em dash (`—`).

Copy: existing catalog keys were kept. No new Chinese sentences were invented. Settings row order was not rewritten. Extra native rows (notifications, language, region, sound, NPC, merchant hub) stay where they already were. The sign-out row label uses `CYColor.textPrimary`. The confirm sheet still passes `isDestructive: true, confirmIdentifier: "settings.signOut.confirm"` because that source string is pinned.

## Template 7

| Swift type | Mini-program route | Section order (existing, kept) | Shared components |
|---|---|---|---|
| `AccountView` + `PassportView` + `MemberIdentityCardSection` | `pages/member/index/index` | Identity card (avatar, name, level, city, streak, ticket CTA, three counters) → stamp album → badge rail → public profile / edit → collection links → benefits → messages, teams, invites, play guide → location and complaints. Passport hides the duplicate messages and sign-out rows. | `cyDomainCard`, `cyDomainPageBackground`, `CYDomainPrimaryButtonStyle`, `CYSkeleton`, `CYOfflineBanner`, `CYLoadingStateView`, `CYInlineError`, `CYListRow`, `CYTypography.data` / `numericBody`, `appNavigationTitle` + large title |
| `ProfileEditView` + `ProfileCurrentAvatarView` | `pages/gerenziliao/gerenziliao` | Existing editor sections and field order. Values wrap. Avatar ring on the current-avatar circles. | `appNavigationTitle` + large title, `palette.avatarRing`, `CYColor.bgRaised` |
| `SocialPublicProfileView` + `SocialIssueView` / `SocialReadScreen` | `pages/userinfo/userinfo` | Header (avatar, name, counters, intro) → existing tab sections (posts and related links). | `cyGroupedSurface`, `cyHeroScreen`, `CYEmptyState` (offline on `URLError`), `CYOfflineBanner` (fixture offline example), `CYPillButton`, large title `social.profile` |
| `AccountCollectionFavoritesView` + `AccountCollectionIssueView` | `pages/mylike/mylike` | Existing favorites sections. Category metadata wraps. Network issue uses `CYStateKind.offline`; login and not-configured stay generic. | `CYStateLayout`, `CYListRow`, large title |
| `CharacterCardReadbackView` | `subpackageMember/character/index` | Existing phases: loading, empty, error, unknown, ready. No offline phase was added. `PlayExperienceError` has no network case. | large title only; existing state views kept |
| `GrowthCenterView` + `GrowthCenterIssueView` | growth center (`subpackageP3`) | Score → footprint → badges. Empty badges use `growth.badges.empty` and the existing explore action. | `CYEmptyState` (`.offline` for `.network`, `.failure` otherwise), `CYTypography.data2XL`, `cyDomainPageBackground`, large title |
| `GrowthLeaderboardView` | leaderboard (`subpackageP3`) | Existing podium then list. First-place disc uses the player avatar ring. | `CYTypography.dataXL`, `palette.bgRaised`, large title |
| `RoamStampAlbumView` (`RoamStampViews`) | stamp album | Existing album grid. Empty collection remains the locked slot grid. No extra empty sentence. | `palette.actionPrimaryBg` / `actionPrimaryFg` on the capture control, large title `roam.experience.album`, existing `roam.experience.offline` / error notices |
| `ObjectBadgeWallView` | badge wall | Existing wall. Medal glyph size stays. | large title `profile.badges.title`, existing domain page background |
| `RoamMonthlyRecapView` / `RoamAnniversaryView` / `RoamRecapShareFace` | monthly recap and anniversary | Existing recap face. The route count uses `CYTypography.data2XL` and wraps. | `CYTypography.data2XL` |

Passport stamp states: loading `CYLoadingStateView`, offline `CYOfflineBanner` when history throws `URLError`, error `CYInlineError("roam.experience.readFailed")`. A failed or offline count stays `—`, not `0`.

Member identity states: loading skeleton plus `member.card.loading`; offline `CYOfflineBanner` when identity throws `URLError` and the user is still signed in; signed-out / failed / unavailable keep `member.card.signedOut`, `member.card.failed`, `member.card.unavailable`.

## Template 14

| Swift type | Mini-program route | Section order (existing, kept) | Shared components |
|---|---|---|---|
| `SettingsView` + `SettingsTileLabelStyle` + `SettingsSignOutEntry` | `pages/shezhi/shezhi` | Account card → identity applications → play guide → favorites → privacy and location → notifications → usage consent → market → language → score appeal → invoice → merchant hub → NPC → post governance → support → legal / about / cancellation entries → sign out. Mini-program order is the prefix. Native extras stay. | `cyDomainPageBackground`, `palette.cardFill` / `bgRaised`, `CYColor.textPrimary` sign-out label, large title. Tile hues are ignored by the label style. |
| `SettingsAboutView` | about | Brand mark → links → contact → attributions. | `CYCoverArt`, `Theme.Radius.xl`, large title |
| `PrivacyProtectionView` | `pages/privacy/index` | Existing policy sections. Missing bundle uses `authEntry.privacy.guideUnavailable`. | `CYEmptyState`, `cyHeroScreen`, `cyGroupedSurface` |
| `SettingsLegalDocumentView` | `pages/agreement/index` | Title, version, then section headings and lines. Headings and lines wrap. | large title, `fixedSize` vertical |
| `AccountComplianceSheet` header (`AccountComplianceViews`) | `pages/deregister/index` and marketing sheet | Existing cancellation and marketing destinations. Header icon is neutral, not a rainbow tile. Flow unchanged. | `CYColor.bgRaised`, `Theme.Radius.md` |
| `CouponCodeView` | coupon QR | Name card → phase (review, ready, loading, waiting, paused, failed, used, expired, invalid, unavailable, disabled, service disabled). No separate offline phase exists on the model, so none was added. QR bitmap stays on white. | `cyDomainCard`, `cyDomainPageBackground`, `CYLoadingState`, `CYEmptyState` (`couponCode.missing`, `u9cde.coupon.failed`), large title |

## Found and not rebuilt

These screens exist. No parallel type was added.

- Group code: `ClubGovernanceEventView` inside `App/ClubGovernanceViews.swift`. Left in place so the club surface (other templates) is not restyled.
- City-node QR: `VerificationCodeView`. Existing loading, phase text, and retry stay. No offline enum exists, so none was invented.
- Crop: `TemplateImageCropView` / `MiniCropView`.
- Exploration export: `RoamExplorationExportView`.
- Object cards: `ObjectCardViews`.
- Marketing receipt body: `MarketingConsentOriginalReceiptView`. The compliance sheet header that hosts it was restyled; the receipt body was not rewritten.

## Fixtures

DEBUG hosts already on the Release exclusion list:

- `d4-growth` content, `d4-growth-failure` (`GrowthCenterFixtureReader.Scenario.failure`, HTTP 503 → unavailable), `d4-growth-offline` (`Scenario.network`, throws `URLError.notConnectedToInternet`).
- Existing badge empty/error and stamp empty fixtures were not removed.
- No new network call. `isOfflineExample` remains the synthetic marker and is not treated as a full-screen offline replacement on the growth reader.

## Checks

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed. No `swiftc`. Design-lint allowlist dropped `AccountComplianceViews` and `RoamPassportToolsViews` after their fixed-size font hits were removed. `SettingsView` still names `SettingsTint.purple` four times; the label style does not paint that tint. `ObjectBadgeViews` keeps its medal glyph size and its allowlist entry.
