"""W2-06 activity detail / registration checkout parity guards.

Source guards only: these do not compile Swift or prove UI behavior. Mini-program
sources: subpackageMember/components/cy/scene-play-activity-detail and
pages/activity/baoming.
"""
import json
import os
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
# Pre-merge key file; after the catalog merge every key must live in Localizable.xcstrings.
KEYS_JSON = pathlib.Path(os.environ.get(
    "W2_06_KEYS_JSON",
    "",
))
SWIFT_FILES = (
    "App/ActivityDetailView.swift",
    "App/RegistrationSheetView.swift",
    "App/RegistrationFixtureSupport.swift",
    "App/ActivityFixtureSupport.swift",
    "Core/ActivityDetailHeaderPresentation.swift",
    "Core/RegistrationCheckoutPresentation.swift",
    "Core/RegistrationConfirmedReadback.swift",
)
# SwiftUI Text("key \(x)") placeholders for the interpolated values used in these files.
INTERPOLATION_FORMATS = {"count": "%lld", "meetingPoint": "%@"}


def read(path):
    return (ROOT / path).read_text()


def ordered(test, source, tokens):
    positions = [source.index(token) for token in tokens]
    test.assertEqual(positions, sorted(positions), tokens)


class ActivityDetailParityTests(unittest.TestCase):
    def test_meta_rows_follow_cancellation_and_precede_about(self):
        source = read("App/ActivityDetailView.swift")
        # Ready body only. The page-level cancelled state reuses activity.detail.cancelled
        # and does not show the meta rows or 关于这场活动.
        fold = source.split("private func detailContent", 1)[1].split("private func moreInfoSections", 1)[0]
        ordered(self, fold, (
            "E1ActivityHero(summary:detail.summary)",
            # mp-home r3: MP shows the cancelled notice right under the hero, before the native info card.
            'accessibilityIdentifier("activity.detail.cancelled")',
            "E1ActivityInfoCard(detail:detail)",
            "ActivityDetailMetaSection(facts: ActivityDetailHeaderFacts(detail: detail))",
            "detail.summary.hasValidCoordinates",
            'Section("activity.about")',
            'E1IconHeader(systemImage: "ticket"',
            'accessibilityIdentifier("activity.more.toggle")',
            "if showsMoreInfo { moreInfoSections(detail) }",
        ))
        # MP scene-play-activity-detail: activity-meta follows the cancellation notice and precedes 关于这场活动.
        self.assertLess(fold.index('accessibilityIdentifier("activity.detail.cancelled")'), fold.index("ActivityDetailMetaSection("))
        self.assertLess(fold.index("ActivityDetailMetaSection("), fold.index('Section("activity.about")'))
        # R7-PC-C1-7: 关于这场活动 stays in the first fold, above people, not behind 更多信息.
        self.assertLess(source.index('Section("activity.about")'), source.index("ActivityPeopleSection(people:"))
        more = source.split("private func moreInfoSections", 1)[1].split("private func profileAction", 1)[0]
        self.assertNotIn('Section("activity.about")', more)
        self.assertNotIn("ActivityDetailMetaSection(", more)
        meta = source.split("private struct ActivityDetailMetaSection")[1].split("enum ActivityLocationAccessibility", 1)[0]
        for token in ('"activityParity.header.category"', 'facts.categoryText ?? "—"',
                      '"activityParity.header.meetingPoint"', 'case .mapOnly', 'case .unconfirmed',
                      'case .unconfirmed: Text(verbatim: "—")',
                      'Text("activityParity.header.registeredCount \\(count)")',
                      'else { Text(verbatim: "—") }',
                      'accessibilityIdentifier("activity.detail.category")',
                      'accessibilityIdentifier("activity.detail.meetingPoint")',
                      'accessibilityIdentifier("activity.detail.registeredCount")',
                      ".font(.body)"):
            self.assertIn(token, meta)
        for forbidden in ("Button", "Task", "URLSession", "?? 0", "lineLimit", "payment", "StoreKit", "WXApi",
                          ".system(size:", ".caption2", "Theme.Font"):
            self.assertNotIn(forbidden, meta)

    def test_header_facts_keep_unknown_values_unknown(self):
        core = read("Core/ActivityDetailHeaderPresentation.swift")
        for token in ('joined(separator: " · ")', "registrationCount = detail.people.registrationCount",
                      "detail.summary.hasValidCoordinates", "meetingPoint = .unconfirmed",
                      "Self.nonempty(detail.summary.addressName) ?? Self.nonempty(detail.summary.address)"):
            self.assertIn(token, core)
        for forbidden in ("participants.count", "?? 0", "URLSession", "Date()"):
            self.assertNotIn(forbidden, core)


class RegistrationCheckoutParityTests(unittest.TestCase):
    def setUp(self):
        self.view = read("App/RegistrationSheetView.swift")

    def test_fresh_form_section_order_matches_source(self):
        body = self.view.split("var body: some View {")[1].split("private var recoveredOrderSection")[0]
        fresh = body.split("} else {\n                        // Source order")[1].split(".scrollDismissesKeyboard")[0]
        ordered(self, fresh, ("participantSection", "activitySection", "ticketSection",
                              "quoteSection", "waitlistSection", "confirmationSection"))
        self.assertLess(body.index("alreadyRegisteredSection"), body.index("if flow.hasRetainedIntent"))
        # Retained and pending outcomes still show the activity before their status sections.
        retained = body.split("if flow.hasRetainedIntent {")[1].split("} else if case .pending")[0]
        self.assertLess(retained.index("activitySection"), retained.index("RegistrationOperationSections"))
        pending = body.split("} else if case .pending(let registrationID) = flow.durableCreation {")[1]
        self.assertLess(pending.index("activitySection"), pending.index('Section("registration.form.outcomeUnknown")'))
        # Declaration order stays unchanged for the existing ticket/waitlist/quote source guards.
        ordered(self, self.view, ("private var ticketSection:", "private var waitlistSection:", "private var quoteSection:"))

    def test_fee_rows_follow_source_breakdown(self):
        quote = self.view.split("private var quoteSection: some View {")[1].split("private var confirmationSection")[0]
        ordered(self, quote, ('key: "registrationParity.orderAmount"', 'key: "registration.form.memberDiscount"',
                              '"registrationParity.clubBenefit"', 'key: "registration.form.pointsDiscount"',
                              'key: "registration.form.total"'))
        self.assertIn("RegistrationCheckoutClubBenefit.from(quote)?.noteKey", quote)
        self.assertIn('Section {', quote)

    def test_activity_banner_and_meeting_point_rows(self):
        self.assertIn(".viewerAlreadyRegistered", self.view)
        self.assertIn('Label("registrationParity.alreadyRegistered"', self.view)
        self.assertIn('accessibilityIdentifier("registration.alreadyRegistered")', self.view)
        activity = self.view.split("private var activitySection: some View {")[1].split("private var participantSection")[0]
        for token in ('return Section {', "if let meetingPoint = checkout.meetingPoint",
                      'Text("registrationParity.meetingPointValue \\(meetingPoint)")',
                      'if let venue = checkout.venue { Text(verbatim: venue) } else { Text(verbatim: "—") }',
                      'accessibilityIdentifier("registration.activity.meetingPoint")',
                      'accessibilityIdentifier("registration.activity.venue")'):
            self.assertIn(token, activity)
        self.assertIn('private var participantSection: some View {\n        Section {', self.view)
        core = read("Core/RegistrationCheckoutPresentation.swift")
        self.assertIn("viewerAlreadyRegistered = activity.signUpFlag == 1", core)
        self.assertIn("orderAmount = ticket?.price", core)
        self.assertNotIn("?? 0", core)
        # The one remaining `?? .zero` only decides the points toggle auto-disable (nil deduction disables); it is never displayed.
        self.assertEqual(core.count("?? .zero"), 1)
        self.assertIn("let deduct = quote.pointsDeductYuan ?? .zero", core)

    def test_slice_confirms_explicitly_then_reads_back_without_new_writes(self):
        self.assertIn("await flow.confirmAndReadBack()", self.view)  # h-offline-2 wraps the free path in the write opt-in
        self.assertNotIn("await flow.confirm()", self.view)
        self.assertIn('Text("registration.form.review")', self.view)
        self.assertIn("if flow.prepareConfirmation() {", self.view)
        self.assertIn("showingConfirmation = true", self.view)
        slice_source = read("Core/RegistrationConfirmedReadback.swift")
        confirm = slice_source.split("func confirmAndReadBack() async {")[1].split("func uncertainOutcomeEvidence")[0]
        ordered(self, confirm, ("let previousRequestID = coordinator.retainedIntent?.requestID",
                                "await confirm()", "intent.requestID != previousRequestID",
                                "case .responseReceived(let requestID, _) = creationState",
                                "await readKnownStatus()"))
        self.assertEqual(confirm.count("await readKnownStatus()"), 1)
        evidence = slice_source.split("func uncertainOutcomeEvidence")[1]
        self.assertIn("case .outcomeUnknown(let requestID, _) = creationState", evidence)
        self.assertIn("reader.identity == identity", evidence)
        self.assertEqual(evidence.count("try await"), 1)
        for forbidden in ("URLSession", "URLRequest", "api/", "coordinator.confirm(", "service.create",
                          "makeRequestID", "UUID()", "WXApi", "StoreKit", "payParams", "UserDefaults"):
            self.assertNotIn(forbidden, slice_source)

    def test_creation_gates_stay_closed_outside_offline_debug_fixtures(self):
        form = read("Core/RegistrationUIForm.swift")
        self.assertIn("case disabled", form)
        self.assertIn("#if DEBUG\n    case offlineFixture\n    #endif", form)
        self.assertIn("creationPolicy: RegistrationUICreationPolicy = .disabled", self.view)
        self.assertIn("creationPolicy: RegistrationUICreationPolicy = .disabled", read("Core/RegistrationUIFlow.swift"))
        self.assertIn("guard creationPolicy.permitsCreation else { block = .creationDisabled", read("Core/RegistrationUIFlow.swift"))
        fixture = read("App/RegistrationFixtureSupport.swift")
        self.assertTrue(fixture.startswith("#if DEBUG"))
        self.assertIn("case alreadyRegistered", fixture)
        self.assertIn('scenario == .alreadyRegistered ? "\\"isSignUp\\":1," : ""', fixture)
        for path in ("App/ActivityFixtureSupport.swift",):
            self.assertTrue(read(path).startswith("#if DEBUG"))

    def test_quote_and_ticket_contracts_decode_new_optional_fields_leniently(self):
        contracts = read("Core/RegistrationContracts.swift")
        self.assertIn("prioritySignupEnabled = ((try? c.decodeIfPresent(Bool.self, forKey: .prioritySignupEnabled)) ?? nil) == true", contracts)
        detail = read("Core/ActivityDetail.swift")
        # R7-PC-C1-5 (MP scene-play-activity-detail/index.wxml:89-96): the ticket also decodes its cmsRegistrationList lineup.
        # R7-PC-C2-1 (MP baoming.wxml:155-161): child fields follow for the 儿童年龄 picker.
        self.assertIn("signupDeadline,meetingPoint,cmsRegistrationList,childCount,childAgeMin,childAgeMax }", detail)
        self.assertIn("(try? c.decodeIfPresent(String.self,forKey:.meetingPoint))", detail)


class ParityLocalizationTests(unittest.TestCase):
    def known_keys(self):
        catalog = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        pending = json.loads(KEYS_JSON.read_text()) if KEYS_JSON.is_file() else {}
        return catalog, pending

    def used_keys(self):
        found = set()
        for path in SWIFT_FILES:
            source = read(path)
            for literal in re.findall(r'"((?:activityParity|registrationParity)\.(?:\\.|[^"\\])*)"', source):
                key = re.sub(r"\\\((\w+)\)", lambda match: INTERPOLATION_FORMATS[match.group(1)], literal)
                found.add(key)
        return found

    def test_every_new_key_is_bilingual_and_known(self):
        catalog, pending = self.known_keys()
        used = self.used_keys()
        self.assertTrue(used)
        for key in sorted(used):
            self.assertTrue(key.isascii(), key)
            if key in catalog:
                localizations = catalog[key]["localizations"]
                values = {lang: localizations[lang]["stringUnit"]["value"] for lang in ("en", "zh-Hans")}
            else:
                self.assertIn(key, pending, key)
                values = pending[key]
            for lang in ("en", "zh-Hans"):
                self.assertTrue(values[lang].strip(), (key, lang))
                self.assertEqual(sorted(re.findall(r"%(?:lld|@)", key)),
                                 sorted(re.findall(r"%(?:lld|@)", values[lang])), (key, lang))

    def test_pending_keys_use_parity_prefixes(self):
        _, pending = self.known_keys()
        for key, values in pending.items():
            self.assertRegex(key, r"^(activityParity|registrationParity)\.")
            self.assertTrue(key.isascii(), key)
            self.assertEqual(set(values), {"en", "zh-Hans"}, key)


if __name__ == "__main__":
    unittest.main()
