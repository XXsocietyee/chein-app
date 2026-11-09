# D1 design spec — Welcome, consent gate, login, role picker (player = dark)

Brief: /private/tmp/bebrief/docs/release/ui-design-brief-v2.md. Kit branch `ui/kit` does not exist yet; this uses the existing `CY*` tokens and `.cyPrimary/.cySecondary` styles only (no look-alike components).

## 1 Welcome (no direct mini-program counterpart; base: role-picker rows, stub-roles.png / 057-role-picker-descriptions.png)
```
[ globe-menu ... ]            (top bar: one "..." menu)
  (mark)
  Make the city your          <- large heavy headline
  next adventure
  (role.player.detail, 1 line)
                              (flexible space)
 [ Register as a player   ]   <- ONE primary, full-width pill
 [ Register as a merchant ]   <- outlined secondary pill
        Browse as a guest      <- one quiet text row
```
- Stays: player register (primary), merchant register (secondary), guest browse, saved drafts, language, settings, upgrade notice.
- Demoted: Saved drafts, Settings, Language switcher -> single `ellipsis.circle` menu in the top bar (identifiers kept). Browse as a guest -> quiet text row under the pills.
- Visible controls besides primary: merchant, browse, menu = 3.
- States: upgrade-required label (unchanged key); Dynamic Type XL scrolls; zh/en via existing keys.
- Ref: 057-role-picker-descriptions.png (title + description rows, pill action on black).

## 2 Consent gate (UsageConsentGateView) — refs 012-privacy.png, 013-agreement.png
```
 Privacy and location (large)
 3-line summary
 > Details (DisclosureGroup -> full text)
 [Privacy guide  >][User agreement >]   (#1C1C1E card rows)
 (o) I have read and agree
 [ Agree and continue ]   primary pill
   Not now                quiet text
```
Same order as 012 (title, summary, guide link, action). Demoted: full body text into the disclosure; decline stays a quiet text button. New strings `authEntry.gate.summary/details` were referenced but missing from AuthEntry.xcstrings, supplied in `ui-strings-d1.json`.
States: check-required error inline; agree disabled until checked.

## 3 Login (LoginView, AuthChannelView, WeChat section) — mini login/privacy pages
Form kept (system), on black page with #1C1C1E rows; sign-in button becomes the single full-width primary pill; "Other sign-in" stays a quiet row; unavailable states (WeChat not configured, US pending, Apple not verified) shown as secondary-text rows, never red.

## 4 Role picker (ClubRoleAssignmentPicker) — refs 056/057/stub-roles
Rows: name (headline) + description (footnote secondary) + trailing "choose"/check, as in 057. Loading/error/empty rows kept.
