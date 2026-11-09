# D1 design report (onboarding) — PARTIAL

## Done: Welcome (builds, 0 errors)
Shots: /Users/fanning/chengyin-refs/design-reports/d1/shot-212424.png (zh, first round), shot-213632.png (en, with hero). Compare: design-reports/d1/compare-welcome.png.
- Hero: restrained collage of three tilted placeholder cards (map / ticket / fork.knife) replaces the small map badge; text and buttons grouped beneath.
- Subtitle is not new copy: it is the existing app key `role.player.detail` (no new strings added for Welcome).
- Demoted into the single `...` menu (identifiers kept): Saved drafts (`ownerDraft.guestEntry`), Settings (`welcome.settings`), Language switcher (LanguageSwitcher, EN / 简体中文). Login keeps its own LanguageSwitcher toolbar item (unchanged); Home keeps its (unchanged).
- Visible controls: primary player pill, outlined merchant pill, guest text row, menu = 3 besides primary.
- Compare critique: the only mini-program reference (stub-roles.png) is the "role management unavailable" error state, not a true welcome; it matches in theme (black page, heavy title, white pill) but not in structure. There is no mini-program Welcome counterpart. Our hero has no real imagery yet (placeholders).

## Also in tree (built, NOT yet visually verified)
Consent gate (UsageConsentGateView), Login / AuthChannelView / WeChat section, role picker restyle; fixed iOS 18-only `toolbarVisibility` -> `.toolbar(.hidden, for: .navigationBar)`. New strings in docs/release/ui-strings-d1.json.

## Not done / open
- ui/kit not on origin; no `--design-fixture` registry, so consent/login/role picker screens are unreachable for screenshots and no compare images exist for them.
- Menu-open, Dynamic Type XL and zh/en shots for Welcome not captured: design-run.sh shuts the simulator down after one screenshot, so I cannot open the menu. Checklist items 7-9 unverified.
