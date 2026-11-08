# UI-11 report — accessibility + dark/light audit (NOT COMPILED)

Scope: audited screens edited by cloud/ui-01..ui-10 (read only, not merged) plus grep sweeps of App/. Presentation-only changes.

| File | Change | Reason | Theme | New strings |
|---|---|---|---|---|
| ClubEventCalendarView.swift | chevron.left/right -> chevron.backward/forward | RTL-safe month stepper | dark | none |
| ActivityPeopleSection, MerchantNPCFieldEntry, RoamPassportHistoryView, ProfileContactQREditor, MerchantCoopCenterView | chevron.right -> chevron.forward | RTL-safe disclosure arrows | both | none |
| PlayKitSensorChallengeView, RoamHistoryViews | fixed `.system(size:)` -> text style `.largeTitle` | Dynamic Type scaling | dark | none |
| ProfileCurrentAvatarView, QuestifyImageEntityCard, TemplateD6RehearsalView | fixed-size symbol font -> `.largeTitle` + `.imageScale(.large)` | Dynamic Type scaling | dark | none |

## Issues in files touched by other UI branches (NOT fixed; for owners)
- TemplateAuthoringMineView (ui-09), WalletCommerceViews (ui-05), HomeSearchTabParityViews (ui-01/02), WelcomeView (ui-06): `Image(systemName: "chevron.right")` should be `chevron.forward` for RTL.
- Not verified without a compiler: Dynamic Type XXL clipping and contrast on ui-02/05/07/08 edits; Cursor screenshots at XXL + dark/light recommended.

## Could not do
- No compile/screenshots, so contrast and XXL clipping were not measured.
- `ClubPostDiscussion.swift:192` size-1 fixture text left as is (hidden accessibility fixture).

Audit checks passing: icon-only toolbar buttons have accessibility labels; Reduce Motion is respected in sampled animations (exception: TopicXcxSections.swift:23 `withAnimation` in onChange has no reduceMotion guard — left, low risk).

Files touched: 11 code + this report. New components: 0. New string keys: 0.
