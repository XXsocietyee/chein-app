#!/usr/bin/env python3
"""Source contract for the node-template editor readiness model. Not an Xcode run."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOMAIN = (ROOT / "Core/TemplateAuthoringDomain.swift").read_text()
COORD = (ROOT / "Core/TemplateAuthoringCoordinator.swift").read_text()
WIRE = (ROOT / "Core/TemplateAuthoringWireRequestBuilder.swift").read_text()
CONTRACT = (ROOT / "Core/TemplateAuthoringContract.swift").read_text()
FIXTURE = (ROOT / "Core/TemplateAuthoringSyntheticFixtures.swift").read_text()
STRINGS = json.loads((ROOT / "docs/release/ui-strings-pages-publish-temp-index.json").read_text())
NOTE = (ROOT / "docs/release/page-ready/pages-publish-temp-index.md").read_text()


class TemplateAuthoringPageReadinessContract(unittest.TestCase):
    def test_phases_and_em_dash_are_in_the_model(self):
        self.assertIn('public enum Phase: Equatable { case loading, empty, error, unknown, ready }', DOMAIN)
        self.assertIn('public static let unknownNumber = "—"', DOMAIN)
        self.assertIn("raw.rounded() == raw", DOMAIN)
        self.assertNotIn("isEmpty ? 0", DOMAIN[DOMAIN.index("struct TemplateAuthoringPageReadiness"):])

    def test_coordinator_classifies_without_a_new_send(self):
        self.assertIn("public var editorReadiness: TemplateAuthoringPageReadiness", COORD)
        self.assertIn("public func libraryInfoReadiness(", COORD)
        self.assertNotIn("libraryInfoReadiness", WIRE)
        self.assertEqual(COORD.count("await adapter.submit"), 2)
        form = WIRE.split("let formPaths = Set([", 1)[1].split("])", 1)[0]
        self.assertNotIn("/api/template/info", form)
        self.assertNotIn('"/api/template/info"', CONTRACT)

    def test_fixture_data_stays_debug_only(self):
        self.assertTrue(FIXTURE.startswith("#if DEBUG\n"))
        self.assertTrue(FIXTURE.rstrip().endswith("#endif"))
        self.assertIn("public enum TemplateAuthoringPageFixtureData", FIXTURE)
        self.assertLess(FIXTURE.index("#if DEBUG"), FIXTURE.index("enum TemplateAuthoringPageFixtureData"))
        self.assertGreater(FIXTURE.rindex("#endif"), FIXTURE.index("enum TemplateAuthoringPageFixtureData"))

    def test_strings_are_bilingual_and_name_identifiers(self):
        self.assertEqual(STRINGS["page"], "pages/publish/temp/index")
        self.assertEqual(STRINGS["status"], "gated")
        self.assertEqual(STRINGS["unknownNumber"]["en"], "—")
        self.assertEqual(STRINGS["unknownNumber"]["zh-Hans"], "—")
        self.assertGreaterEqual(len(STRINGS["strings"]), 20)
        for row in STRINGS["strings"]:
            self.assertTrue(row["en"].strip(), row["key"])
            self.assertTrue(row["zh-Hans"].strip(), row["key"])
        self.assertIn("templateAuthor.field.title", STRINGS["accessibilityIdentifiers"])
        self.assertIn("templateAuthor.readOriginalRequest", STRINGS["accessibilityIdentifiers"])

    def test_page_stays_gated_and_flags_stay_off(self):
        joined = DOMAIN + COORD + FIXTURE + NOTE
        for flag in ["showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"]:
            self.assertNotIn(flag + " = true", joined)
        self.assertIn("gated", NOTE)
        self.assertIn("Xcode was not run", NOTE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
