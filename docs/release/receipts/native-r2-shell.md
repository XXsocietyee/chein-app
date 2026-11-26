# Receipt: native-r2 / shell (root tab bar + welcome)

Branch `native-r2/shell`, from `origin/ui/combined-r7`. Brief: `docs/briefs/native-r2.md` (design/handoff-r2).
Gate: `python3 tools/check_scaffold.py` → `PASS structural checks`. No compiler in the cloud; every API below was grepped
in the repo or is standard SwiftUI/UIKit at the stated availability. A simulator build by the coordinator is still required.

## 1. Player tab bar → system `TabView`
- `App/QuestifyApp.swift` `SessionRootView.playerTabs`:
  - iOS 18+: `TabView(selection:)` with five `Tab(_:systemImage:value:content:)` items:
    首页 `house` · 漫游 `map` · 发布 `plus.circle` · 俱乐部 `person.2` · 我的 `person.crop.circle`
    (title keys `tabBar.home/roam/publish/club/mine`, unchanged).
  - iOS 17 (deployment target 17.0): same five tabs via `.tabItem { Label(key, systemImage:) }.tag(...)`.
  - Removed: `CYNightTabBar` pill overlay, `.cyDomainTabBar(.player)` gradient/forced dark bar, the tab-switch haptic,
    `CYTabBarAppearance.install()` (custom colours/fonts on `UITabBar.appearance()`). Tint = system accent
    (the coordinator's `tabSelectedTint` is `Color.accentColor`).
  - Kept: `rootTabBar.tab.player.0…4` via `cyTabBarAccessibilityIdentifiers` (sets the `UITabBarItem` identifiers, works for
    both paths) and on the iOS 17 `.tabItem` labels; `selectedTab`, deep-link `replayDeepLink`, `rootTabSwitch`,
    `cyHideTabBar` (system `.toolbar(.hidden, for: .tabBar)`), per-tab visibility, `.id(session.account?.id)`, offline banner.
- `App/DesignSystem/CYDomainTabBar.swift`: `CYDomainTabBarStyle` is now a pass-through (system bar for every role; the merchant
  root still calls it, so its gradient is gone too). `CYTabBarAppearance` deleted (no other callers). New
  `RootTab.nativeSystemImage` (App side; `Core/RootTab.systemImage` untouched).
- `App/DesignSystem/CYNightTabBar.swift`: `cyFloatingTabBarClearance` keeps its bottom safe-area padding (behaviour fix N3) and the
  system `.scrollEdgeEffectStyle(.soft, for: .bottom)`; the painted gradient fade `CYTabBarScrollEdgeFade` is removed.
  `CYNightTabBar` itself is left in place for design fixtures only.

## 2. Welcome → Apple-style welcome screen (`App/WelcomeView.swift`)
- `NavigationStack` › `ScrollView` on `Color(uiColor: .systemBackground)`: app icon (bundle primary icon, SF Symbol fallback),
  large title `nativeR2.shell.welcome.title` (欢迎来到城瘾 / Welcome to chein), three feature rows (SF Symbol + `.headline` +
  `.subheadline` secondary) reusing the onboarding copy: `map` 走到哪，亮到哪 · `checkmark.seal` 盖个章，算你来过 · `person.2` 一个人逛，不如一群人.
- Bottom inset: consent row (`fixr9.ap.consent.readAndAgree` 我已阅读并同意《用户服务协议》《隐私保护指引》 + two links
  `authEntry.gate.openAgreement` / `authEntry.gate.openPrivacyGuide` opening `SettingsLegalDocumentView` in a sheet), then
  `创建账号` (`.borderedProminent`, `.controlSize(.large)`, `welcome.player`) and `先逛一逛` (`.borderless`, `welcome.browse`).
- Toolbar: the existing `…` menu (`welcome.more`, `welcome.settings`, `ownerDraft.guestEntry`, language).
- Both entry points (launch, with 先逛一逛; signed-out 我的 tab, without) now use this one layout. Removed: onboarding pager,
  dark orb/backdrop, Metal wave, morph pill, `WelcomeHero` fanned cards, custom `RoleButtonStyle`.
  `OnboardingFlow` / `CYOnboarding*.swift` / `CYOnboardingWave.metal` are left as files (design fixtures still reference them)
  but the app no longer mounts them; `tools/generate_project.py` inputs unchanged.

### Consent / auth behaviour (unchanged)
- 创建账号 always opens `LoginView(intent: .player)`, which still enforces `UsageConsentSignInRequirement`
  (`authEntry.gate.requiredForSignIn` / `.review`). It is NOT disabled by the checkbox, so `EntryUsageConsentFlowTests`
  (decline → welcome.player → requiredForSignIn) keeps passing.
- The launch sheet `UsageConsentGateView` (`authEntry.gate.*` identifiers) is untouched.
- The welcome checkbox mirrors `UsageConsentPolicy.granted`; ticking calls the same `agree(agreementChecked: true)` the gate's
  同意 does; unticking calls `decline()` (MP declineUsageConsent). It re-reads the policy on appear, after any sheet closes,
  on scene activation and on `UserDefaults.didChangeNotification`. New identifiers: `welcome.consent.checkbox`,
  `welcome.consent.agreement`, `welcome.consent.privacyGuide`, `welcome.legal.close`, `welcome.features`, `welcome.title`.
- `onboarding.completed.v1` is still set on 创建账号 / 先逛一逛.

## Notes / closest-Apple choices
- MP checkbox is a square; we use `circle` / `checkmark.circle.fill` (iOS selection style) in a plain `Button` — no Apple
  checkbox control exists on iOS.
- App icon uses a continuous rounded-rect clip (the icon mask), the only corner radius on the page.
- iOS 18 `Tab` has no label view, so tab identifiers rely on the UIKit `UITabBarItem` pass (same mechanism as before).
- Not converted in this lane: `CYChromeBars.swift` (`CYNavBar`, footer buttons) is used by other lanes' screens; merchant root
  tab labels (`HomeSearchTabParityViews.swift`, not owned) still use MP icon assets.

## Strings
- `docs/port/strings/native-r2-shell.json` → merged into `Resources/Localizable.xcstrings` (1 key).
