"""Source contract for the cover/shelf image. Does not compile Swift or fetch a remote image."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
COMPONENT = ROOT / "App" / "DesignSystem" / "CYCachedAsyncImage.swift"
TESTS = ROOT / "Tests" / "AppUnitTests" / "CYCachedAsyncImageTests.swift"
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"
FORBIDDEN = ("URLSession", "URLRequest", "dataTask", "AsyncImage", "Data(contentsOf:")


class CachedAsyncImageContract(unittest.TestCase):
    def test_component_and_tests_do_not_fetch(self):
        for path in (COMPONENT, TESTS):
            text = path.read_text()
            for token in FORBIDDEN:
                pattern = r"\b" + re.escape(token)
                if token[-1].isalnum():
                    pattern += r"\b"
                self.assertIsNone(re.search(pattern, text), (path.name, token))
            for url in re.findall(r"https?://[^\s\"\\)]+", text):
                self.assertTrue(
                    "example.invalid" in url or url.startswith("https:///"),
                    url,
                )

    def test_unknown_reference_returns_placeholder_before_any_loader(self):
        text = COMPONENT.read_text()
        resolve = text.split("static func resolve(", 1)[1].split("protocol CYCachedAsyncImageLoading", 1)[0]
        unknown = resolve.find("else { return .placeholder }")
        loader = resolve.find("loader.loadImage")
        self.assertGreaterEqual(unknown, 0)
        self.assertGreater(loader, unknown)
        self.assertIn("guard let loader else { return .placeholder }", resolve)
        self.assertIn("case placeholder", text)
        self.assertIn("case failed", text)
        self.assertIn("case cover", text)
        self.assertIn("case shelf", text)

    def test_copy_is_bilingual(self):
        strings = json.loads(CATALOG.read_text())["strings"]
        expected = {
            "cy.cachedImage.placeholder": ("Image", "图片"),
            "cy.cachedImage.failed": ("Image didn't load", "图片没加载出来"),
        }
        for key, (en, zh) in expected.items():
            entry = strings[key]["localizations"]
            self.assertEqual(set(entry), {"en", "zh-Hans"})
            self.assertEqual(entry["en"]["stringUnit"]["value"], en)
            self.assertEqual(entry["zh-Hans"]["stringUnit"]["value"], zh)
            self.assertEqual(entry["en"]["stringUnit"]["state"], "translated")
            self.assertEqual(entry["zh-Hans"]["stringUnit"]["state"], "translated")
