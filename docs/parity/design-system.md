# Chengyin Native iOS Design System & Track Adoption Guide (`design-system.md`)

> **Owner**: W3 — Design System + Parity Map  
> **Code Location**: `App/DesignSystem/CYDesignTokens.swift`, `App/DesignSystem/CYDesignComponents.swift`  
> **Authority Sources**: `/Users/fanning/chengyin-handoff/backend/docs/城瘾小程序_设计系统权威基准_20260801.md`, `/Users/fanning/chengyin-handoff/backend/chengyinhub-xcx/style/tokens.wxss`, and `/Users/fanning/chengyin-handoff/docs/worker-specs/COMMON.md`

---

## 1. Design Principles & Non-Negotiables (`COMMON.md` §3)

1. **System-First Components**: Prefer native SwiftUI controls (`NavigationStack`, `TabView`, `List`, `ContentUnavailableView`, `ShareLink`, `Menu`, `.sheet`, `.searchable`) over custom chrome. Add custom wrappers only where the app repeats a specific visual contract.
2. **Semantic Colours Only (Zero Raw Hex Outside `App/DesignSystem/` & `App/Theme/`)**:
   - Every view in W4–W8 must reference `CYColor.*` (or `DesignSystem.Colors.*`) so both **Light Mode** (`#F3F4F4` page / `#FFFFFF` surface) and **Dark Mode** (`#000000` page / `#0A0A0B` surface) render with verified **WCAG 2.1 AA contrast** (`>= 4.5:1` for normal text, `>= 3.0:1` for large text and UI components).
3. **Dynamic Type & Accessibility**:
   - Never hardcode fixed text frame heights. Use `CYTypography.*` (mapped to `Font.TextStyle`) and `@ScaledMetric` for icons/badges.
   - Respect `@Environment(\.accessibilityReduceMotion)` (all `CY*ButtonStyle` styles disable press-scale animations automatically when Reduce Motion is enabled).
   - Every interactive control and icon-only toolbar button must maintain a **`>= 44×44pt` hit target** (`CYSpacing.minTouchTarget`) and provide a clear `.accessibilityLabel(...)`.
4. **No WeChat Capsule Reservation**:
   - Never reserve right-top blank space for WeChat's `•••`/`⊗` pill. See `docs/parity/capsule-removal.md` for page-by-page replacements.

---

## 2. Token Reference (`App/DesignSystem/CYDesignTokens.swift`)

### 2.1 Semantic Colours (`CYColor` / `DesignSystem.Colors`)

| Token | Light Mode | Dark Mode | WCAG AA Contrast (on Surface) | Usage |
|---|---|---|---|---|
| `CYColor.accent` | `#7A5CFF` | `#7A5CFF` | `4.38:1` vs `#FFFFFF` (`4.79:1` vs `#0A0A0B`) | Primary CTA fill, active indicator, selected pill (passes 3.0:1 UI/large text AA) |
| `CYColor.accentStrong` | `#6A4AF0` | `#6A4AF0` | `5.49:1` vs `#FFFFFF` | High-contrast solid violet fill for small/dense white text (passes 4.5:1 normal-text AA) |
| `CYColor.accentPressed` | `#6A4AF0` | `#8B70FF` | `5.49:1` / `6.40:1` | Pressed state for primary brand controls |
| `CYColor.accentText` | `#6A4AF0` | `#C4B5FD` | `5.31:1` (L) / `10.60:1` (D) | Inline links, active tab labels, accent badges |
| `CYColor.accentSoft` | `#EDE9FE` | `rgba(122,92,255,0.18)` | — | Soft brand tint surface for chips, monogram avatars |
| `CYColor.accentWarm` | `#E04F2E` | `#FF8266` | `4.52:1` (L) / `7.85:1` (D) | Secondary coral highlight (hot badges, RPG/play accents) |
| `CYColor.bgPage` | `#F3F4F4` | `#000000` | — | Root screen background |
| `CYColor.bgSurface` | `#FFFFFF` | `#0A0A0B` | — | Standard card & list section surface |
| `CYColor.bgSurfaceSubtle` | `#EEEEEE` | `#141416` | — | Secondary inset group / filter bar background |
| `CYColor.bgElevated` | `#FFFFFF` | `#1C1C1E` | — | Elevated cards, sheets, popovers |
| `CYColor.bgRaised` | `#E6E6E6` | `#2A2A2C` | — | Input fields, skeleton placeholders, disabled button fill |
| `CYColor.bgSurfaceStrong` | `#E4E4E4` | `#3B3B3D` | — | Pressed neutral surface, muted unread badge fill |
| `CYColor.textPrimary` | `#18181B` | `#F5F5F7` | `17.7:1` (L) / `18.1:1` (D) | Primary titles, body copy, key figures |
| `CYColor.textSecondary` | `#3F3F46` | `#D4D4D8` | `10.3:1` (L) / `13.0:1` (D) | Subtitles, card descriptions, secondary labels |
| `CYColor.textTertiary` | `#52525B` | `#A1A1AA` | `7.4:1` (L) / `7.6:1` (D) | Timestamps, footnotes, metadata |
| `CYColor.textPlaceholder` | `#71717A` | `#8E8E98` | `4.8:1` (L) / `5.9:1` (D) | Search/input placeholders (passes 4.5:1 AA) |
| `CYColor.textOnAccent` | `#FFFFFF` | `#FFFFFF` | `4.74:1` vs `#7A5CFF` | Label on solid `CYColor.accent` or `CYColor.dangerSolid` |
| `CYColor.successText` / `successSoft` | `#047857` / `#D1FAE5` | `#34D399` / `rgba(16,185,129,0.18)` | `5.5:1` (L) / `10.4:1` (D) | Verified, completed, active online status |
| `CYColor.warningText` / `warningSoft` | `#B45309` / `#FEF3C7` | `#FBBF24` / `rgba(245,158,11,0.18)` | `5.0:1` (L) / `11.8:1` (D) | Pending review, cooldown, expiring soon |
| `CYColor.dangerText` / `dangerSoft` / `dangerSolid` | `#B91C1C` / `#FEE2E2` / `#DC2626` | `#F87171` / `rgba(239,68,68,0.18)` / `#EF4444` | `6.4:1` (L) / `7.5:1` (D) | Errors, destructive actions, unread DM badges |
| `CYColor.infoText` / `infoSoft` | `#1D4ED8` / `#DBEAFE` | `#60A5FA` / `rgba(59,130,246,0.18)` | `6.7:1` (L) / `7.9:1` (D) | Informational banners, official notices |
| `CYColor.borderSubtle` / `borderStrong` | `rgba(15,23,42,0.08 / 0.16)` | `rgba(255,255,255,0.09 / 0.18)` | — | Hairline card borders and input outlines |

### 2.2 Dynamic Type Scale (`CYTypography` / `DesignSystem.Typography`)

| Token | Base Size (`wxss`) | SwiftUI `Font.TextStyle` Mapping | Weight / Design | Usage |
|---|---|---|---|---|
| `CYTypography.display` | `32pt` | `.largeTitle` | `.bold` (`.rounded`) | Hero greetings, achievement celebration headers |
| `CYTypography.pageTitle` | `26pt` | `.title` | `.bold` | Top-level screen inline header |
| `CYTypography.sheetTitle` | `22pt` | `.title2` | `.semibold` | Modal / bottom-sheet header |
| `CYTypography.sectionTitle` | `18pt` | `.title3` | `.semibold` | Section headers (`CYSectionHeader`) |
| `CYTypography.cardTitle` | `16pt` | `.headline` | `.semibold` | Card primary title |
| `CYTypography.body` / `bodyMedium` | `15pt` | `.body` | `.regular` / `.medium` | Primary narrative and article copy |
| `CYTypography.bodyCompact` | `14pt` | `.subheadline` | `.regular` | Secondary card descriptions, list subtitles |
| `CYTypography.label` | `14pt` | `.subheadline` | `.semibold` | Buttons, segmented tabs, form labels |
| `CYTypography.meta` | `12pt` | `.footnote` | `.regular` | Timestamps, distance, location hints |
| `CYTypography.caption` | `11pt` | `.caption` | `.medium` | Filter chips, status tags |
| `CYTypography.micro` | `10pt` | `.caption2` | `.semibold` | Unread badge counts, character counters |
| `CYTypography.dataXL` / `data2XL` | `28pt` / `34pt` | `.title` / `.largeTitle` | `.bold`, `.rounded`, `.monospacedDigit()` | Wallet balances, settlement totals, leaderboard scores |
| `CYTypography.numericBody` | `14pt` | `.subheadline` | `.semibold`, `.rounded`, `.monospacedDigit()` | Prices, countdowns, queue wait times |

### 2.3 4pt Spacing Grid (`CYSpacing`) & Corner Radii (`CYRadius`)

- **Spacing (`CYSpacing`)**:
  - `xxs = 2`, `xs = 4`, `sm = 8`, `md = 12`, `lg = 16` (`pageHorizontal`), `xl = 20`, `xxl = 24`, `xxxl = 32`, `hero = 40`, `jumbo = 48`.
  - `minTouchTarget = 44` (enforced on all interactive controls).
- **Corner Radii (`CYRadius`, always paired with `.continuous` squircle style)**:
  - `xs = 8` (chips/tags), `sm = 12` (secondary buttons/inputs), `md = 16` (standard cards), `lg = 20` (featured cards), `xl = 22` (wallet hero card), `sheet = 24` (bottom sheets), `pill = 999` (primary pill buttons & badges).

---

## 3. Reusable Components & View Modifiers (`App/DesignSystem/CYDesignComponents.swift`)

### 3.1 Card Container (`CYCard` & `.cyCardSurface(...)`)

```swift
// Container usage:
CYCard(variant: .elevated, radius: CYRadius.md, padding: CYSpacing.lg) {
    VStack(alignment: .leading, spacing: CYSpacing.sm) {
        Text(topic.title)
            .font(CYTypography.cardTitle)
            .foregroundStyle(CYColor.textPrimary)
        Text(topic.subtitle)
            .font(CYTypography.bodyCompact)
            .foregroundStyle(CYColor.textSecondary)
    }
}

// Modifier usage on any existing layout:
HStack { ... }
    .cyCardSurface(variant: .surface)
```

### 3.2 Section Header (`CYSectionHeader`)

```swift
CYSectionHeader(
    "精选路线",
    subtitle: "本周城市热门探索",
    actionTitle: "查看全部"
) {
    openAllRoutes()
}
```

### 3.3 Button Styles (`.cyPrimary`, `.cySecondary`, `.cyDestructive`)

```swift
Button("立即报名") {
    submitRegistration()
}
.buttonStyle(.cyPrimary) // Full-width #7A5CFF pill, >=44pt height, Reduce-Motion aware

Button("稍后再说") {
    dismiss()
}
.buttonStyle(.cySecondary(fullWidth: false))

Button("取消报名") {
    confirmCancel()
}
.buttonStyle(.cyDestructive)
```

### 3.4 Empty State (`CYEmptyStateView`) & Error State with Retry (`CYErrorStateView`)

```swift
// Empty state (single primary CTA rule):
CYEmptyStateView(
    systemImage: "ticket",
    title: "还没有票",
    description: "去首页发现路线或报名场次，票会在这里出现。",
    actionTitle: "去发现路线"
) {
    switchToHomeTab()
}

// Error state with user-readable reason + retry:
CYErrorStateView(
    title: "参与记录没能打开",
    message: "请检查网络连接后重试",
    retryTitle: "重试"
) {
    Task { await reload() }
}
```

### 3.5 Unread Badge (`CYUnreadBadge`) & Avatar (`CYAvatarView`)

```swift
// Unread count badge (caps at "99+", hides automatically when count <= 0):
CYUnreadBadge(count: unreadCount, style: .danger)

// Muted channel dot indicator:
CYUnreadBadge(count: channelUnread, isDotOnly: true, style: .muted)

// HTTPS Avatar with automatic monogram fallback & online indicator:
CYAvatarView(
    url: URL(string: member.avatarURL),
    name: member.nickname,
    size: .md,
    showAccentRing: member.isLeader,
    isOnline: member.isOnline
)
```

---

## 4. Track-Specific Adoption Guide (W4–W8)

### W4 — Core Loop (Home, Search, Topic/Activity Detail, Checkout, Ticket Wallet, Teams)
- **Unified Search (`App/GlobalSearchView.swift`)**: Use `CYColor.bgSurfaceSubtle` for filter pills and `CYEmptyStateView` when a keyword returns 0 results across `全部 / 路线 / 活动 / 俱乐部 / 商家`.
- **Checkout & Ticket Wallet (`App/RegistrationSheetView.swift`, `App/TicketWalletView.swift`)**: Use `CYTypography.dataXL` for total payable amounts (`¥` + `.monospacedDigit()`) and `.buttonStyle(.cyPrimary)` for the sticky bottom CTA bar.

### W5 — Roam, City, NPC & Merchant Storefront
- **Map HUD & Cards (`App/RoamBrowserView.swift`, `App/NearbyTeamViews.swift`)**: Use `CYColor.bgGlass` with `.background(.ultraThinMaterial)` for floating map pills, and `CYCard(variant: .elevated)` for bottom-sheet POI / team preview cards.
- **Merchant Workbench (`App/MerchantHomeView.swift`, `App/MerchantMarketingView.swift`)**: Use `CYTypography.numericBody` and `CYTypography.dataXL` for 30-day stage counts, queue wait times, and redemption totals.

### W6 — Clubs, Discord-Style Channels & IM Messaging
- **Discord-Style Channel List (`App/ClubDetailView.swift`, `App/MessagingHomeView.swift`)**:
  - Group channels under `CYSectionHeader` categories.
  - Render active/unread channels with `CYColor.textPrimary` (`CYTypography.label`) and trailing `CYUnreadBadge(count: unread, style: isMuted ? .muted : .danger)`.
  - Render read channels with `CYColor.textTertiary` (`CYTypography.bodyCompact`) and muted channels with `CYUnreadBadge(count: unread, isDotOnly: true, style: .muted)`.
  - Use `CYAvatarView(size: .sm, isOnline: ...)` in member rosters and chat rows.

### W7 — Me, Profile, Orders & Revolut-Style Wallet
- **Revolut-Style Wallet Hero Card (`App/WalletCommerceViews.swift`, `App/WithdrawalSupportLandingView.swift`)**:
  - Use `CYCard(variant: .elevated, radius: CYRadius.xl, padding: CYSpacing.xl)` for the primary balance card.
  - Render the primary balance with `CYTypography.data2XL` (`monospacedDigit()`) and stage breakdowns (`待入账` / `可提现` / `已入账`) using `CYTypography.numericBody` and `CYColor.successText` / `CYColor.warningText`.
  - Pair primary withdrawal CTA (`.buttonStyle(.cyPrimary(fullWidth: false))`) with secondary history/rules actions (`.buttonStyle(.cySecondary(fullWidth: false))`).

### W8 — Play Runtime, RPG, Templates & External Games
- **Play Runtime & Dark Immersive Surfaces (`App/PlayExperienceView.swift`, `App/CharacterCardReadbackView.swift`)**:
  - Force `.preferredColorScheme(.dark)` only inside dedicated dark-only narrative chapters if required; otherwise rely on `CYColor.bgSurface` (`#0A0A0B` in dark mode, `#FFFFFF` in light mode) so cards, attribute bars, and node preview sheets remain legible in both appearances.
