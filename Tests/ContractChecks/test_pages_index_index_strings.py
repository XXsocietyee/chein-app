"""Contract for pages/index/index model states.

The ui-strings catalog is not on this branch, so these checks read Core only.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
CONTRACTS = ROOT / "Core/HomeFeedContracts.swift"
FIXTURE = ROOT / "Core/HomeFeedSyntheticFixtures.swift"
UNKNOWN = "—"


class PagesIndexIndexStrings(unittest.TestCase):
    def test_unknown_is_an_em_dash_in_the_model(self):
        self.assertNotEqual(UNKNOWN, "0")
        self.assertNotEqual(UNKNOWN, "-")
        source = CONTRACTS.read_text()
        self.assertIn(f'public static let unknownText = "{UNKNOWN}"', source)
        for state in ("loading", "empty", "error", "unknown", "ready"):
            self.assertIn(f"case {state}", source)

    def test_fixture_data_stays_debug_only_and_omits_a_price(self):
        source = FIXTURE.read_text()
        self.assertTrue(source.startswith("#if DEBUG"))
        self.assertIn("public enum HomeFeedFixtureData", source)
        self.assertIn("missingFactsActivity", source)
        self.assertNotIn("minAmout", source.split("missingFactsActivity", 1)[1])
        self.assertTrue(source.rstrip().endswith("#endif"))


if __name__ == "__main__":
    unittest.main()
