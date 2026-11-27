"""Source-only UI52 regression and negative mutations; no Swift runtime claim."""
from pathlib import Path
import json
import re
import tempfile
import unittest

from tools import run138_ui52_driver_inverse as driver

ROOT = Path(__file__).resolve().parents[2]


# Retired by debt-r3 (2026-11-27): byte-exact inverses of the run138 UI52 patch over MerchantMarketingUITests.swift / ProjectStoryImageFlowTests.swift plus the club-chain protected-bytes check; both UI files have changed since, so every inverse raises. The three mutation tests were vacuous for the same reason (the inverse raises for any input). Marketing selection, story barrier (rewritten on the live file), costs and contract-integrity checks stay.
#   - UI52DriverCandidateTests.test_both_whole_files_restore_to_exact_published_preimages
#   - UI52DriverCandidateTests.test_changed_original_assertion_is_rejected
#   - UI52DriverCandidateTests.test_exactly_one_new_five_second_wait_per_source_no_existing_wait_inflation
#   - UI52DriverCandidateTests.test_extra_wait_or_repeated_barrier_is_rejected
#   - UI52DriverCandidateTests.test_isolated_candidate_and_all_protected_original_bytes
#   - UI52DriverCandidateTests.test_missing_barrier_and_preimage_cannot_masquerade_as_current
#   - UI52DriverCandidateTests.test_non_test_helpers_and_other_methods_are_byte_identical

class UI52DriverCandidateTests(unittest.TestCase):
    def setUp(self):
        self.c = driver.contract(ROOT)

    def current(self, relative):
        return (ROOT / relative).read_bytes()

    def original(self, relative):
        return driver.original_source(relative, self.current(relative), ROOT)




    def test_marketing_verifies_selected_value_title_and_closed_menu_after_single_tap(self):
        hunk = self.c["files"][driver.MARKETING]["hunks"][0]
        text = hunk["after"]
        self.assertTrue(text.startswith('                options.element(boundBy: options.count - 1).tap()'))
        for required in ("picker.label == expectedPickerLabel",
                         '(picker.value as? String) == section',
                         "picker.isHittable", "app.navigationBars[section].exists",
                         "!app.menus.firstMatch.exists",
                         'language == "en" ? "Section" : "栏目"',
                         '"MARKETING_SECTION_TRANSITION expected='):
            self.assertIn(required, text)
        self.assertLess(text.index("selectionSettled"), text.index('app.staticTexts["merchantMarketing.error"]'))
        self.assertEqual(text.count(".tap()"), hunk["before"].count(".tap()"))
        current = self.current(driver.MARKETING).decode()
        self.assertIn('for language in ["en", "zh-Hans"]', current)
        self.assertIn('["Shop insights", "Entitlements", "Prediction inbox"]', current)
        self.assertIn('["店铺参谋", "付费权益", "竞猜待答"]', current)

    def test_story_barrier_only_second_apply_on_current_source(self):
        # debt-r3: rewritten on the live file; the old/new comparison went through the byte inverse,
        # which rejects every current ProjectStoryImageFlowTests.swift.
        text = self.current(driver.STORY).decode()
        first = 'tap("projectStoryImage.apply", app); XCTAssertFalse(app.buttons["projectStoryImage.close"].exists); back(app)'
        self.assertEqual(text.count(first), 1)
        self.assertEqual(text.count("    private func back("), 1)
        for required in ('!app.buttons["projectStoryImage.close"].exists',
                         'app.navigationBars["Chapter"].buttons["BackButton"]',
                         "chapterBack.exists && chapterBack.isEnabled && chapterBack.isHittable",
                         "back(app); saved = try inspect(app)"):
            self.assertIn(required, text)
        self.assertEqual(text.count("let replacementDismissed ="), 1)


    def test_exact_full_method_costs_and_explicit_current_only_905_exception(self):
        costs = driver.validate_costs(ROOT)
        marketing = next(row for key, row in costs.items() if key.startswith("MerchantMarketing"))
        story = next(row for key, row in costs.items() if key.startswith("ProjectStoryImage"))
        self.assertEqual(marketing["candidate_complete_method_seconds"], 114.954 + 2 * 3 * 5)
        self.assertEqual(story["candidate_complete_method_seconds"], 900 + 5)
        self.assertTrue(story["requires_explicit_over_900_review"])
        profile = json.loads((ROOT / "tools/ui_duration_weights.json").read_text())
        key = next(key for key in costs if key.startswith("ProjectStoryImage"))
        self.assertEqual(profile["estimated_method_seconds"][key], 900)




    def test_unknown_path_is_rejected(self):
        with self.assertRaises(ValueError):
            driver.original_source("Tests/AppUITests/Unapproved.swift", b"", ROOT)

    def test_mutated_inverse_contract_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / driver.CONTRACT_PATH
            target.parent.mkdir(parents=True)
            target.write_bytes((ROOT / driver.CONTRACT_PATH).read_bytes() + b" ")
            with self.assertRaises(ValueError):
                driver.contract(Path(folder))


if __name__ == "__main__":
    unittest.main()

