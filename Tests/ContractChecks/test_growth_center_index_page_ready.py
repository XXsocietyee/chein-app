"""Page-ready catalog for the growth center index. Source check only; not an Xcode build."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAGE = "subpackageP3/pages/growthcenter/index/index"
CATALOG = ROOT / "docs/release/ui-strings-subpackageP3-pages-growthcenter-index-index.json"
VIEW = ROOT / "App/GrowthCenterView.swift"
COMPONENTS = ROOT / "App/GrowthCenterComponents.swift"
CONTRACTS = ROOT / "Core/GrowthCenterContracts.swift"
SERVICE = ROOT / "Core/GrowthCenterService.swift"
FIXTURE = ROOT / "Core/GrowthCenterSyntheticFixtures.swift"
UNKNOWN = "\u2014"
IDENTIFIER = re.compile(r'\.accessibilityIdentifier\("([^"]+)"\)')
QUOTED = re.compile(
    r'"(growth(?:\.[A-Za-z]+)*(?: \\\([^"]*\))?|growthExplore\.[A-Za-z.]+|profile\.selfGrowth\.[A-Za-z.]+|growthNormalEntry\.[A-Za-z.]+)"'
)


def _catalog_key(literal):
    if literal.startswith("growth.level.value"):
        return "growth.level.value %lld"
    return literal


def page_sources():
    return VIEW.read_text() + "\n" + COMPONENTS.read_text()


def accessibility_identifiers():
    return sorted(set(IDENTIFIER.findall(page_sources())))


def string_keys():
    stripped = IDENTIFIER.sub("", page_sources())
    keys = {_catalog_key(match) for match in QUOTED.findall(stripped)}
    issue = CONTRACTS.read_text().split("public var localizationKey", 1)[1].split("public enum GrowthCenterFormatting", 1)[0]
    keys.update(re.findall(r'return "(growth\.[A-Za-z.]+)"', issue))
    return keys


def catalog_value(key, table=None):
    filename = "Localizable.xcstrings" if not table else f"{table}.xcstrings"
    strings = json.loads((ROOT / "Resources" / filename).read_text())["strings"]
    entry = strings[key]["localizations"]
    return {"en": entry["en"]["stringUnit"]["value"], "zh-Hans": entry["zh-Hans"]["stringUnit"]["value"]}


def expected_strings():
    payload = {}
    for key in sorted(string_keys()):
        table = "GrowthNormalEntry" if key.startswith("growthNormalEntry.") else None
        value = catalog_value(key, table)
        if table:
            value["table"] = table
        payload[key] = value
    return payload


class GrowthCenterIndexPageReady(unittest.TestCase):
    def test_catalog_matches_live_copy_and_identifiers(self):
        document = json.loads(CATALOG.read_text())
        self.assertEqual(document["page"], PAGE)
        self.assertEqual(document["unknownDisplay"], UNKNOWN)
        self.assertNotEqual(document["unknownDisplay"], "0")
        self.assertEqual(document["strings"], expected_strings())
        self.assertEqual(document["accessibilityIdentifiers"], accessibility_identifiers())
        unknown = document["strings"]["growth.unknown"]
        self.assertEqual(unknown["en"], UNKNOWN)
        self.assertEqual(unknown["zh-Hans"], UNKNOWN)
        for key, value in document["strings"].items():
            self.assertEqual(set(value) - {"table"}, {"en", "zh-Hans"}, key)
            self.assertTrue(value["en"] and value["zh-Hans"], key)
            blob = json.dumps(value, ensure_ascii=False)
            self.assertNotIn("http://", blob)
            self.assertNotIn("https://", blob)
            self.assertNotIn("ICP", blob)
            self.assertNotIn("备案", blob)

    def test_unknown_stays_nil_in_the_model_and_live_routes_stay_closed(self):
        contracts = CONTRACTS.read_text()
        self.assertIn("Unknown values remain nil, never invented zeroes", contracts)
        self.assertNotIn("?? 0", contracts)
        self.assertIn("case unknown", (ROOT / "Core/GrowthLeaderboardStanding.swift").read_text())
        reading = (ROOT / "Core/GrowthCenterReading.swift").read_text()
        self.assertIn("var isLoading = false", reading)
        self.assertIn("issue = GrowthCenterIssue(error)", reading)
        service = SERVICE.read_text()
        self.assertIn("leaderboardContract: GrowthLeaderboardReadContract = .legacy", service)
        self.assertNotIn("api/growth/mission/complete", service)
        self.assertNotIn("showsMerchantChoice", service)
        for flag in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertNotIn(flag, service)

    def test_debug_fixture_data_already_exists(self):
        text = FIXTURE.read_text()
        self.assertTrue(text.startswith("#if DEBUG\n"))
        self.assertIn("public enum GrowthCenterSyntheticFixtures", text)
        self.assertTrue(text.rstrip().endswith("#endif"))
        raws = re.findall(r'=#"(.*?)"#', text) + re.findall(r'= #"(.*?)"#', text)
        self.assertEqual(len(raws), 6)
        for raw in raws:
            json.loads(raw)
            self.assertNotIn("https://", raw)
            self.assertNotIn("http://", raw)


if __name__ == "__main__":
    unittest.main()
