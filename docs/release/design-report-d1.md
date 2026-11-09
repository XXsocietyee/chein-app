# D1 design report (onboarding) — PARTIAL

## Done: Welcome (builds, 0 errors)
Shots: /Users/fanning/chengyin-refs/design-reports/d1/shot-212424.png (zh, first round), shot-213632.png (en, with hero). Compare: design-reports/d1/compare-welcome.png.
- Hero: restrained collage of three tilted placeholder cards (map / ticket / fork.knife) replaces the small map badge; text and buttons grouped beneath.
- Subtitle is not new copy: it is the existing app key `role.player.detail` (no new strings added for Welcome).
- Demoted into the single `...` menu (identifiers kept): Saved drafts (`ownerDraft.guestEntry`), Settings (`welcome.settings`), Language switcher (LanguageSwitcher, EN / 简体中文). Login keeps its own LanguageSwitcher toolbar item (unchanged); Home keeps its (unchanged).
- Visible controls: primary player pill, outlined merchant pill, guest text row, menu = 3 besides primary.
- Compare critique: the only mini-program reference (stub-roles.png) is the "role management unavailable" error state, not a true welcome; it matches in theme (black page, heavy title, white pill) but not in structure. There is no mini-program Welcome counterpart. Our hero has no real imagery yet (placeholders).

## Consent gate (UsageConsentGateView) — shot-215243.png (en, dark)
- Now forced to the player theme at the view root (`.themeDomain(.player)`), so it is dark in the real sheet path too; LoginView got the same.
- Summary + details disclosure + two document links at the top; toggle, ONE primary pill and quiet "Not now" pinned to the bottom safe area; the "saved on this device" footnote moved under the details disclosure.
- `authEntry.gate.summary` / `.details` already exist in the catalog on rc/20261108; they are also in docs/release/ui-strings-d1.json. For the screenshot only I injected them into Resources/AuthEntry.xcstrings locally and reverted that file before committing.

## Login (LoginView) — shot-220013.png (zh-Hans, Dynamic Type accessibility-extra-large, dark)
Dark page, #1C1C1E rows, no clipping at XL. The fixture has no auth channels, so it shows the unavailable states (secondary-text rows, not red). Demoted: none removed; language stays in the toolbar globe.

## Fixtures
App/DesignFixtures/OnboardingFixtures.swift, registered in DesignFixtureRegistry: welcome, welcome-menu (lists the `...` menu entries, since a Menu cannot be opened programmatically), consent, login-player. DEBUG only.

## Welcome tweaks after review
Brighter centre card, 1px hairline borders, hero ~10% shorter. Not re-screenshotted after the tweak (built, shown in the consent/login runs only via the same target).

## Open
- Role picker (ClubRoleAssignmentPicker): restyled, builds, but NOT screenshotted: it needs ClubGovernanceAccess + a read model that cannot be built from a synthetic fixture without touching Core. The mini-program reference (stub-roles.png) is the unavailable state.
- welcome-menu, Welcome XL/zh and role-picker shots not taken; small-phone safe-area check not done. Checklist items 7-9 are verified only for consent (en) and login (zh XL).
