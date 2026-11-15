"""Static consumer check only; not Swift/App execution."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NearbyProductProvenanceTests(unittest.TestCase):
    def test_card_displays_only_known_product_labels(self):
        view = (ROOT / "App/NearbyTeamMapViews.swift").read_text()
        self.assertIn("if let key = team.productLabelKey { parts.append(Text(LocalizedStringKey(key))) }", view)
        self.assertNotIn("team.productType == 2 ?", view)

    def test_projection_keeps_unknown_and_uses_existing_contract_values(self):
        source = (ROOT / "Core/NearbyTeamContracts.swift").read_text()
        projection = source.split("public var productLabelKey: String?", 1)[1].split("public let distance", 1)[0]
        self.assertIn('case 1: return "nearby.urbanExplore"', projection)
        self.assertIn('case 2: return "nearby.freeExplore"', projection)
        self.assertIn("default: return nil", projection)
        self.assertIn("case city = 1, freeExplore = 2", (ROOT / "Core/ProjectEditDraft.swift").read_text())


if __name__ == "__main__":
    unittest.main()
