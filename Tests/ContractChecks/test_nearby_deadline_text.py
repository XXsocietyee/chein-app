"""Source checks only, not App or server validation."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NearbyDeadlineTextTests(unittest.TestCase):
    def test_original_parseable_text_is_preserved_without_status_inference(self):
        source = (ROOT / "App/NearbyTeamViews.swift").read_text()
        section = source.split("@ViewBuilder private func expiry(", 1)[1].split("@MainActor private struct", 1)[0]
        self.assertIn("if let minutes = value?.remainingMinutes(now: Date())", section)
        branch = section.split("} else if let value, case .text(let raw) = value, value.date() != nil {", 1)[1]
        self.assertIn('LabeledContent("nearby.expiry.deadline")', branch)
        self.assertIn("Text(verbatim: raw).fixedSize(horizontal: false, vertical: true)", branch)
        self.assertIn('} else { Text("nearby.expiry.rule").font(.footnote) }', branch)
        for prohibited in ["DateFormatter", "ISO8601DateFormatter", "coordinator.", "prepare(", "confirm(", ".status ="]:
            self.assertNotIn(prohibited, branch)

    def test_shared_and_fragment_translations_match(self):
        catalogs = [
            json.loads((ROOT / path).read_text())["strings"]
            for path in ["Resources/NearbyTeamLocalizations.fragment.json", "Resources/Localizable.xcstrings"]
        ]
        key = "nearby.expiry.deadline"
        self.assertEqual(catalogs[0][key], catalogs[1][key])
        self.assertEqual(catalogs[0][key]["localizations"]["en"]["stringUnit"]["value"], "Application deadline (server value)")
        self.assertEqual(catalogs[0][key]["localizations"]["zh-Hans"]["stringUnit"]["value"], "申请截止时间（服务端原文）")


if __name__ == "__main__":
    unittest.main()
