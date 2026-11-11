# Contract-test regressions from the restyle

Four contract tests passed on base rc 201bf147f and failed after the restyle. In each case the protected behaviour is still in the view; only the pinned snippet was stale. No view files changed and no assertion was weakened.

| Test | Cause | Pin update |
|---|---|---|
| test_w2_04_orders `test_detail_uses_source_detail_copy_and_default_loading_elsewhere` | `ProfileReadScreen` now renders loading through `CYLoadSlot(label: ...)` instead of a bare `ProgressView`. The `issueCopy?.loadingKey ?? "profile.loading"` fallback is unchanged. | Pins `label: LocalizedStringKey(issueCopy?.loadingKey ?? "profile.loading")`. |
| test_activity_topic_navigation `test_existing_session_destination_and_lifetime_are_retained` | `ActivityDetailView` moved to a single `phase` state. `onDisappear` still cancels loads and bumps the generation. | Pins `.onDisappear { loads.cancel(); generation += 1; if phase.isLoading { phase = .idle } }`. |
| test_wallet_product_search_GrokR1 `test_loading_and_lifecycle_contracts` | `WalletScreen.loading` is now derived from `phase`. `markLoading()` replaces `model.loading = true`, and it runs in the same position (after `clear()`, before the scope capture and the Task). | The order list and the negative-control test use `model.markLoading()`. |
| test_accessibility_identifier_boundaries `test_ticket_notice_query_targets_text_not_decorative_image` | The UI test now finds the notice by its copy across all element types with `revealText(...)`. The view still keeps the identifier on the Text, with the info image `accessibilityHidden`. | Pins `revealText("Redemption codes are not available...")`, forbids `app.images["ticketWallet.redemption.notice"]`, and asserts the decorative image stays hidden. |

All four pass. `test_w2_04_orders.test_detail_state_card_and_sections` also fails, but it fails identically at base 201bf147f. It is not on the regression list and is untouched here.
