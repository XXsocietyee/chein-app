"""Activity presentation source guards. These do not compile Swift or prove UI behavior."""
import json
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


def app(name):
    return (ROOT / "App" / name).read_text()


class ActivityDesignStructureTests(unittest.TestCase):
    def test_detail_sections_prioritize_real_summary_then_description_map_tickets(self):
        source = app("ActivityDetailView.swift")
        order = [source.index(value) for value in (
            "E1ActivityHero(summary:detail.summary)",
            # mp-home r3 continue: MP detail has no map section; the facts (集合点 opens Maps) follow the hero.
            "ActivityDetailMetaSection(facts:",
            "ActivityTicketCard(ticket:ticket)",
            "if showsMoreInfo { moreInfoSections(detail) }",
        )]
        self.assertEqual(order, sorted(order))
        # The description is still a real-source section, now behind the "more info" disclosure.
        self.assertLess(source.index('Section("activity.about")'), source.index("ActivityAssociatedPlaysSection"))
        fold = source.split("private func detailContent", 1)[1].split("private func moreInfoSections", 1)[0]
        self.assertNotIn("Map(initialPosition", fold)
        self.assertNotIn("E1ActivityInfoCard", fold)
        self.assertIn(".listStyle(.insetGrouped)", source)
        self.assertIn(".listSectionSpacing(CYSpacing.xl)", source)

    def test_primary_action_preserves_allowed_detail_and_registration_gate(self):
        source = app("ActivityDetailView.swift")
        # native-r2 city orientation (3ec3d687f): a topic-linked allowed detail may render the city event list
        # behind the flag; both branches still only receive the allowed detail.
        ALLOWED = ("case .allowed(let detail):\n"
                   "                    if NativeR2Flags.cityOrientation, detail.summary.linkedTopicID != nil {\n"
                   "                        cityEventDetail(detail)\n"
                   "                    } else {\n"
                   "                        detailContent(detail)\n"
                   "                    }")
        self.assertIn(ALLOWED, source)
        # The city CTA is built only behind the same registrationEnabled gate, guest sign-in first.
        self.assertIn("cta: registrationEnabled ? cityEventCTA(detail) : nil", source)
        city_cta = source.split("private func cityEventCTA(", 1)[1].split("/// Secondary sections", 1)[0]
        self.assertIn("if let guestSignIn { guestSignIn() } else { tileOpenedSheet = true; showsRegistration = true }", city_cta)
        self.assertIn("var registrationEnabled=false", source)
        self.assertIn(".safeAreaInset(edge:.bottom,spacing:0)", source)
        # mp-home r3 (19:50 sweep): the footer goes through showsFooter, which keeps the registrationEnabled gate and hides the dead MP "—" pill.
        self.assertIn("if showsFooter(detail) { registrationAction(detail) }", source)
        self.assertIn("guard registrationEnabled else { return false }", source)
        self.assertEqual(source.count('accessibilityIdentifier("activity.openRegistration")'), 1)
        # MP scene-play-activity-detail/index.wxml:149-153: a cancelled activity is a disabled pill, the host
        # footer is 取消活动并退款, signup shows noTicketText or 立即报名 and is disabled when it cannot confirm,
        # and every other state is a disabled actionText pill.
        # index.js:396-399: a guest hits ensureLoginFor('signup') before the registration page opens.
        self.assertIn('Text(verbatim: CoreLoopCopy(locale: locale).t("取消活动并退款", "Cancel event & refund"))', source)
        self.assertIn('accessibilityIdentifier("activity.openRegistration.blocked")', source)
        self.assertIn("} else if primaryAction == .signUp {\n                CYPillButton(LocalizedStringKey(primaryAction.titleKey)) {\n                    if let guestSignIn { guestSignIn() } else { showsRegistration = true }\n                }", source)
        self.assertIn("} else if primaryAction == .unavailable {\n                CYPillButton(LocalizedStringKey(primaryAction.titleKey)) {}\n                    .disabled(true)", source)
        # A registered or cancelled activity never reopens the registration sheet.
        self.assertIn("if action != .cancelled, walletAvailable { showsTicketWallet = true }", source)
        # r11 R7-PC-B1-13: the allowed gate is unchanged; the sheet also gets the topic-page ticket resolved by name
        # (MP pages/topic/index/index.js:1312-1351).
        self.assertIn("if let access,case .allowed(let detail)=access {\n                SessionRegistrationSheet(activity:detail)", source)
        sheet = app("SessionRegistrationSheet.swift")
        self.assertIn("creationPolicy:Self.freeWhenUnapproved(session.registrationCreationPolicy(activityID:activity.summary.id))", sheet)
        self.assertIn("if case .disabled = issued { return .free }", sheet)
        self.assertIn("registrationApproval: RegistrationProductionApproval? = nil", app("AppSession.swift"))
        self.assertIn('registrationStorefront: @escaping () -> String? = { nil }', app("AppSession.swift"))
        # The primary action must not be attached to an error/loading/club-gate root.
        self.assertLess(source.index("private func detailContent"), source.index(".safeAreaInset"))

    def test_existing_accessibility_identifiers_are_preserved(self):
        sources = "\n".join(app(name) for name in (
            "ActivityBrowserView.swift", "ActivityDetailView.swift", "ActivityPresentationComponents.swift"
        ))
        for identifier in (
            "activity.list.error", "activity.list.retry", "activity.list.empty", "activity.list.loadMore",
            "activity.list.content", "activity.row.\\(item.id)", "activity.detail.error",
            "activity.detail.retry", "activity.detail.clubGate", "activity.detail.name",
            "activity.detail.content", "activity.detail.readOnly", "activity.openPlay",
            "activity.openRegistration", "activity.ticket.price.\\(ticket.id)",
            "activity.ticket.soldOut.\\(ticket.id)", "activity.ticket.inventoryUnknown.\\(ticket.id)",
        ):
            # Empty/error states pass their ids as component parameters (messageIdentifier/actionIdentifier).
            self.assertTrue(('accessibilityIdentifier("' + identifier + '")') in sources
                            or ('Identifier: "' + identifier + '"') in sources, identifier)

    def test_only_source_artwork_is_presented_through_shared_safe_loader(self):
        source = app("ActivityPresentationComponents.swift")
        self.assertIn("QuestifyCardArtwork.safeURL(item.imageURL)", source)
        self.assertIn("QuestifyCardArtwork.safeURL(summary.imageURL)", source)
        for forbidden in ("AsyncImage", "URLRequest", "Authorization", "Image(\"", "https://"):
            self.assertNotIn(forbidden, source)
        loader = app("QuestifyMotionComponents.swift")
        self.assertIn('parts.scheme == "https"', loader)
        self.assertIn(".accessibilityHidden(true)", loader)

    def test_nullable_ticket_values_do_not_gain_invented_availability_or_currency(self):
        source = app("ActivityPresentationComponents.swift")
        self.assertIn("E1Money.yuan(ticket.price, locale: locale)", source)
        self.assertIn('ticket.price == 0 ? copy.t("免费", "Free")', source)
        self.assertIn(".accessibilityElement(children: .combine)", source)
        self.assertIn("if ticket.isSoldOut", source)
        self.assertIn("else if let left = ticket.remainingInventory", source)
        self.assertIn('copy.t("已售罄", "Sold out")', source)
        self.assertIn('copy.t("余票待确认", "Availability unconfirmed")', source)
        self.assertIn("ActivityPresentation.nonempty(ticket.description)", source)
        prices = app("ActivityBrowserView.swift")
        self.assertIn('appLocalized("activity.currencyUnconfirmed", locale: locale)', prices)
        self.assertIn('Text("activity.priceUnknown")', prices)
        for forbidden in (".currency(", "remainingInventory!", "Timer", "Date()", "rating", "countdown"):
            self.assertNotIn(forbidden, source)

    def test_semantic_type_wraps_and_shared_motion_respects_reduce_motion(self):
        source = app("ActivityPresentationComponents.swift")
        self.assertEqual(source.count("dynamicTypeSize.isAccessibilitySize"), 2)
        self.assertIn(".fixedSize(horizontal:false,vertical:true)", source)
        self.assertIn("QuestifyMetadataLine(label:", source)
        self.assertIn(".buttonStyle(QuestifyCardButtonStyle())", app("ActivityBrowserView.swift"))
        self.assertIn("@QuestifyReduceMotion private var reduceMotion", app("QuestifyMotion.swift"))
        for name in ("ActivityBrowserView.swift", "ActivityDetailView.swift", "ActivityPresentationComponents.swift"):
            content = app(name)
            # Restyled list cards clamp title/meta to two lines (home-card rules); nothing else may truncate.
            content = content.replace(".lineLimit(2)", "") if name == "ActivityPresentationComponents.swift" else content
            for forbidden in ("minimumScaleFactor", ".lineLimit(", "repeatForever", "sensoryFeedback", "accessibilityContrast", "environment(\\.accessibilityReduceMotion"):
                self.assertNotIn(forbidden, content)
            # Any animation must go through the shared reduce-motion resolver.
            for animation in re.finditer(r"withAnimation\(", content):
                self.assertTrue(content[animation.end():].startswith("CYMotion.resolve("), (name, "unresolved withAnimation"))

    def test_source_metadata_is_not_reinterpreted(self):
        source = app("ActivityPresentationComponents.swift")
        self.assertIn("nonempty(summary.addressName) ?? nonempty(summary.address)", source)
        self.assertIn("ActivityPresentation.nonempty(summary.startDate)", source)
        self.assertIn("address != place", source)
        self.assertIn("Text(verbatim:name)", source)
        self.assertNotIn("DateFormatter", source)
        self.assertNotIn("TimeZone(", source)
        # Dates are only re-displayed through the shared card formatter, never parsed here.
        self.assertIn("QuestifyCardText.date(item.startDate, locale: locale, displayTimeZone: timeZone)", source)

    def test_loading_search_pagination_and_map_contracts_remain(self):
        browser = app("ActivityBrowserView.swift")
        for required in ("appliedQuery = keyword", "let operation = generation", "generation == operation", "guard current()", "hasMore = result.count >= 10", "existing.insert($0.id).inserted", "try await reader.activities(page: next, keyword: appliedQuery)"):
            self.assertIn(required, browser)
        detail = app("ActivityDetailView.swift")
        self.assertIn(".task(id:id) { await loads.run { await load() } }", detail)
        self.assertIn(".onDisappear { loads.cancel();", detail)
        self.assertIn("try await reader.activityDetail(id:id)", detail)
        self.assertIn("detail.summary.hasValidCoordinates", detail)
        self.assertIn("try await reader.activityDetail(id:id)", detail)
        self.assertNotIn("Map(", app("ActivityPresentationComponents.swift"))

    def test_no_new_business_actions_or_requests_in_presentation_components(self):
        source = app("ActivityPresentationComponents.swift")
        for forbidden in ("Button", "NavigationLink", "Task", "URLSession", "URLRequest", "@State", "@EnvironmentObject", "payment", "createOrder", "submit"):
            self.assertNotIn(forbidden, source)

    def test_new_copy_is_bilingual_and_available_for_catalog_merge(self):
        additions = json.loads((ROOT / "docs/activity-design-localizations.json").read_text())
        self.assertEqual(len(additions), len({entry["key"] for entry in additions}))
        for entry in additions:
            self.assertTrue(entry["en"].strip())
            self.assertTrue(entry["zh-Hans"].strip())
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())["strings"]
        known = set(catalog) | {entry["key"] for entry in additions}
        for name in ("ActivityBrowserView.swift", "ActivityDetailView.swift", "ActivityPresentationComponents.swift"):
            source = re.sub(r'\.accessibilityIdentifier\("(?:\\.|[^"\\])*"\)|(?:message|action)?[Ii]dentifier: "[^"]*"|\bid: "[^"]*"', "", app(name))
            keys = set(re.findall(r'"((?:activity|registration)\.[A-Za-z0-9.]+)"', source))
            self.assertFalse(keys - known, (name, keys - known))


if __name__ == "__main__":
    unittest.main()
