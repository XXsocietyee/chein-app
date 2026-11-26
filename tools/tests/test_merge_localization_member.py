"""Fragment override and the member zh-Hans drift check. Fixtures only."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_merge():
    spec = importlib.util.spec_from_file_location(
        "merge_localization_fragments", ROOT / "tools/merge_localization_fragments.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def entry(en, zh):
    return {
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "zh-Hans": {"stringUnit": {"state": "translated", "value": zh}},
        }
    }


class MergeLocalizationMemberTests(unittest.TestCase):
    def test_fragment_overrides_a_different_zh_and_the_check_fails_until_then(self):
        merge = load_merge()
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            strings = root / "docs/port/strings"
            strings.mkdir(parents=True)
            catalog = root / "Localizable.xcstrings"
            fragment = strings / "fix-r3-member-a.json"
            catalog.write_text(json.dumps({
                "sourceLanguage": "en",
                "strings": {"kept": entry("Keep", "保持"), "drift": entry("Old", "旧")},
                "version": "1.0",
            }, ensure_ascii=False), encoding="utf-8")
            fragment.write_text(json.dumps({
                "sourceLanguage": "en",
                "strings": {
                    "kept": entry("Keep", "保持"),
                    "drift": entry("Old", "新"),
                    "added": entry("Add", "加"),
                },
                "version": "1.0",
            }, ensure_ascii=False), encoding="utf-8")
            drifts = merge.member_zh_drifts(catalog, [fragment])
            self.assertEqual(drifts, [(str(fragment), "drift"), (str(fragment), "added")])
            with self.assertRaises(SystemExit):
                merge.check_member(catalog, root)
            result = merge.merge([fragment], catalog)
            self.assertEqual(result["added"], 1)
            self.assertEqual(result["overridden"], 1)
            stored = json.loads(catalog.read_text(encoding="utf-8"))["strings"]
            self.assertEqual(stored["drift"]["localizations"]["zh-Hans"]["stringUnit"]["value"], "新")
            self.assertEqual(stored["kept"]["localizations"]["zh-Hans"]["stringUnit"]["value"], "保持")
            self.assertEqual(merge.member_zh_drifts(catalog, [fragment]), [])
            self.assertEqual(merge.check_member(catalog, root)["status"], "MATCH")


if __name__ == "__main__":
    unittest.main()
