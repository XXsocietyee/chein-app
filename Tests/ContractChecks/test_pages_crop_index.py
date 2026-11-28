"""Source checks for pages/crop/index. Not a Swift or Xcode run."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DASH = "\u2014"
NOTE = "docs/release/page-ready/pages-crop-index.md"
MISSING_KEYS = [
    "pages.crop.loading",
    "pages.crop.empty",
    "pages.crop.error",
    "pages.crop.unknown",
    "pages.crop.busy",
    "pages.crop.retry",
]
MISSING_STRINGS = [
    "正在准备图片",
    "正在准备要裁剪的图片",
    "没有可裁剪的图片",
    "图片没能打开",
    "这张图片暂时无法读取，请重试或使用原图",
    "裁剪没有完成",
    "裁剪结果没有生成，请重试或使用原图",
    "裁剪范围无效，请调整图片后重试",
    "裁剪工具暂时不可用，请重试或使用原图",
    "图片载入失败，请重试或使用原图",
    "图片尺寸无法识别，请重试或使用原图",
    "使用未经裁剪的原图",
]


class PagesCropIndexTests(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text(encoding="utf-8")

    def test_page_model_keeps_unknown_as_an_em_dash_and_does_not_upload(self):
        source = self.read("Core/MiniCropSession.swift")
        model = source.split("public enum CropPagePhase", 1)[1]
        session = source.split("public enum CropPagePhase", 1)[0]
        for token in [
            "case loading",
            "case empty",
            "case error",
            "case unknown",
            "case ready",
            'public static let unknownDisplay = "—"',
            "public static let routeInstalled = false",
            "public static let routeMarkedLive = false",
            "public static let uploadEnabled = false",
            "guard let count else { return unknownDisplay }",
            "return String(count)",
            "public static func countText(numericString _: String) -> String { unknownDisplay }",
            "public static func dimensionText(numericString _: String) -> String { unknownDisplay }",
            'if value == 0 { return "0" }',
            'ratioTrimmed?.uppercased() == "UNKNOWN"',
            "frameWidth == 0 && session.frameHeight == 0",
        ]:
            self.assertIn(token, model)
        self.assertIn(DASH, model)
        self.assertIn("self.frameWidth = 0", session)
        self.assertIn("guard frameWidth > 0", session)
        for forbidden in [
            "upload(",
            "URLSession",
            "URLRequest",
            "https://",
            "http://",
            "api/",
            "showsMerchantChoice = true",
            "paymentEnabled = true",
            "payoutEnabled = true",
            "withdrawalEnabled = true",
            "virtualGoodsEnabled = true",
            "routeMarkedLive = true",
        ]:
            self.assertNotIn(forbidden, source)
        tests = self.read("Tests/CoreTests/MiniCropSessionTests.swift")
        for name in [
            "testConfirmWithoutFrameRecordsNothing",
            "testPanThenConfirmProducesClampedSourceRect",
            "testUntouchedFreeCropKeepsOriginalButFixedRatioCrops",
            "testBatchIteratesInOrderAndResetsTransformBetweenImages",
            "testGestureIsClampedToScaleRange",
            "testCropPageUnknownStaysAnEmDashAndALiteralZeroStaysZero",
        ]:
            self.assertIn("func " + name, tests)
        self.assertEqual(self.read("Tests/CoreTests/MiniCropGeometryTests.swift").count("func test"), 5)

    def test_missing_keys_are_listed_and_not_added_to_the_catalog(self):
        note = self.read(NOTE)
        catalog = json.loads(self.read("Resources/Localizable.xcstrings"))["strings"]
        model = self.read("Core/MiniCropSession.swift")
        owned = set()
        for key in MISSING_KEYS:
            self.assertIn("`%s`" % key, note)
            # The crop model now references these keys. They are bilingual catalog entries, not invented sentences.
            self.assertIn('"%s"' % key, model)
            entry = catalog[key]
            self.assertEqual(set(entry["localizations"]), {"en", "zh-Hans"})
            for language in ("en", "zh-Hans"):
                value = entry["localizations"][language]["stringUnit"]["value"].strip()
                self.assertTrue(value)
                owned.add(value)
        present = set()
        for entry in catalog.values():
            for node in (entry.get("localizations") or {}).values():
                value = (node.get("stringUnit") or {}).get("value")
                if isinstance(value, str):
                    present.add(value)
        # mp-states r3: the MP cy-error title 图片没能打开 / inline 裁剪没有完成 now ship as catalog copy (undecodable-source state, cover export failure).
        for key in ("pages.crop.openFailed", "profile.localCover.cropFailed"):
            owned.update(node["stringUnit"]["value"].strip() for node in catalog[key]["localizations"].values())
        for literal in MISSING_STRINGS:
            self.assertIn(literal, note)
            if literal not in owned:
                self.assertNotIn(literal, present)
        for key in [
            "publishParity.crop.title",
            "publishParity.crop.confirm",
            "publishParity.crop.useOriginal",
            "publishParity.crop.cancel",
            "publishParity.crop.failed",
            "template.imageCrop.title",
            "template.imageCrop.confirm",
        ]:
            self.assertIn(key, catalog)
            for language in ("en", "zh-Hans"):
                value = catalog[key]["localizations"][language]["stringUnit"]["value"]
                self.assertTrue(value)
        self.assertIn("CropPageModel.facts", self.read("App/TemplateImageCropView.swift"))
        self.assertIn("CropPageModel.facts", self.read("App/MiniCropView.swift"))
        for view in ["App/MerchantImageCropView.swift", "App/CreatorCropExportView.swift"]:
            self.assertNotIn("CropPageModel", self.read(view))


if __name__ == "__main__":
    unittest.main()
