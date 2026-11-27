"""Page-ready contract for pages/activity/baoming/baoming.

Source shape only. This does not compile Swift, run xcodebuild, or claim an Xcode Cloud result.
"""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / 'Core/RegistrationCheckoutPresentation.swift'
TESTS = ROOT / 'Tests/CoreTests/ActivityRegistrationParityW206Tests.swift'
STRINGS = ROOT / 'docs/release/ui-strings-pages-activity-baoming-baoming.json'
CATALOG = ROOT / 'Resources/Localizable.xcstrings'
VIEW = ROOT / 'App/RegistrationSheetView.swift'
MARK = '\u2014'


def model_section(source):
    marker = '// MARK: - pages/activity/baoming/baoming read model'
    start = source.index(marker)
    return source[start:]


class ActivityBaomingPageReadyTests(unittest.TestCase):
    def test_model_has_four_states_and_unknown_is_an_em_dash(self):
        section = model_section(MODEL.read_text())
        for phase in ('loading', 'empty', 'error', 'unknown', 'ready'):
            self.assertIn(f'case {phase}', section)
        self.assertIn(f'public static let unknownMark = "{MARK}"', section)
        self.assertNotIn('?? 0', section)
        self.assertNotIn('?? "0"', section)
        self.assertNotIn('/api/registration/pay', section)
        self.assertNotIn('showsMerchantChoice', section)
        self.assertNotIn('http://', section)
        self.assertNotIn('https://', section)
        self.assertIn('paymentStaysHidden: Bool { true }', section)

    def test_fixture_data_is_debug_only_and_offline(self):
        section = model_section(MODEL.read_text())
        start = section.index('#if DEBUG')
        end = section.index('#endif', start)
        fixture = section[start:end]
        self.assertIn('public enum RegistrationBaomingFixtureData', fixture)
        self.assertNotIn('http://', fixture)
        self.assertNotIn('https://', fixture)
        self.assertNotIn('payParams', fixture)
        self.assertNotIn('showsMerchantChoice', fixture)
        self.assertTrue(section.strip().endswith('#endif'))

    def test_unit_tests_cover_phases_without_removing_the_previous_case(self):
        source = TESTS.read_text()
        for name in (
            'testBaomingUnknownMoneyIsEmDashAndLiteralZeroStaysZero',
            'testBaomingPagePhasesHideAmountsUntilAKnownQuote',
            'testBaomingCoordinatorProjectsTheExistingQuoteAndDoesNotCreateOrPay',
            'testActivityPublishingWizardHeadingsMerchantTicketRuleAndReviewSummary',
        ):
            self.assertEqual(source.count(f'func {name}('), 1)
        self.assertIn('XCTAssertEqual(missing.displayText, "—")', source)
        self.assertIn('XCTAssertNotEqual(missing.displayText, "0")', source)
        self.assertIn('XCTAssertTrue(service.creates.isEmpty)', source)
        self.assertIn('XCTAssertTrue(facts.paymentStaysHidden)', source)

    def test_string_catalog_has_english_chinese_and_accessibility_identifiers(self):
        doc = json.loads(STRINGS.read_text())
        self.assertEqual(doc['table'], 'Localizable')
        self.assertEqual(doc['page'], 'pages/activity/baoming/baoming')
        catalog = json.loads(CATALOG.read_text())['strings']
        self.assertGreaterEqual(len(doc['strings']), 1)
        seen = set()
        for row in doc['strings']:
            key = row['key']
            self.assertNotIn(key, seen)
            seen.add(key)
            self.assertTrue(row['en'].strip())
            self.assertTrue(row['zh-Hans'].strip())
            self.assertNotIn('http://', row['en'] + row['zh-Hans'])
            self.assertNotIn('https://', row['en'] + row['zh-Hans'])
            entry = catalog[key]['localizations']
            self.assertEqual(row['en'], entry['en']['stringUnit']['value'])
            self.assertEqual(row['zh-Hans'], entry['zh-Hans']['stringUnit']['value'])
            if 'accessibilityIdentifier' in row:
                self.assertEqual(row['accessibilityIdentifier'], key)
        view = VIEW.read_text()
        identifiers = doc['accessibilityIdentifiers']
        self.assertGreaterEqual(len(identifiers), 1)
        self.assertEqual(len(identifiers), len(set(identifiers)))
        for identifier in identifiers:
            # US launch r1: the phone row is the shared PhoneCountryField, which takes its identifier as an argument.
            self.assertTrue(f'accessibilityIdentifier("{identifier}")' in view or f'identifier: "{identifier}"' in view, identifier)
        paired = {row['accessibilityIdentifier'] for row in doc['strings'] if 'accessibilityIdentifier' in row}
        self.assertTrue(paired)
        self.assertTrue(paired <= set(identifiers))


if __name__ == '__main__':
    unittest.main()
