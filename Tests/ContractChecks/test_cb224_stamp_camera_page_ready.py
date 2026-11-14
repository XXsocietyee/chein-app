"""CB224 stamp-camera page-ready contract.

Source and catalog checks only. This does not compile Swift, run xcodebuild,
or claim an Xcode Cloud result.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
VIEW = "App/RoamStampCameraView.swift"
MODEL = "Core/RoamStampCaptureCoordinator.swift"
STRINGS = "docs/release/ui-strings-subpackageP3-pages-stamp-camera-index-index.json"
PAGE = "docs/release/page-ready/subpackageP3-pages-stamp-camera-index-index.md"
DASH = "\u2014"


def read(path):
    return (ROOT / path).read_text()


def page_keys(view):
    quoted = set(re.findall(
        r'"(media\.stamp\.[A-Za-z0-9.]+|roam\.[A-Za-z0-9.]+|action\.[A-Za-z0-9.]+|roamSub\.[A-Za-z0-9.]+)"',
        view,
    ))
    quoted = {key.rstrip(".") for key in quoted if key.rstrip(".")}
    quoted.discard("media.stamp.phase")
    phase_fn = view.split("func phaseKey", 1)[1].split("private func", 1)[0]
    for phase in re.findall(r'return "([A-Za-z]+)"', phase_fn):
        quoted.add("media.stamp.phase." + phase)
    identifiers = re.findall(r'\.accessibilityIdentifier\("([^"]+)"\)', view)
    return quoted, identifiers


class StampCameraPageReadyContract(unittest.TestCase):
    def test_catalog_matches_the_view_and_the_live_bilingual_strings(self):
        view = read(VIEW)
        quoted, identifiers = page_keys(view)
        catalog = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        document = json.loads(read(STRINGS))
        self.assertEqual(document["page"], "subpackageP3/pages/stamp-camera/index/index")
        self.assertEqual(document["screen"], VIEW)
        self.assertEqual(document["mapStatus"], "exists")
        self.assertEqual(document["unknownMark"], DASH)
        self.assertEqual(document["accessibilityIdentifiers"], identifiers)
        string_keys = {key for key in quoted if key in catalog}
        self.assertEqual(set(document["strings"]), string_keys)
        self.assertTrue(quoted - string_keys)
        self.assertLessEqual(quoted - string_keys, set(identifiers))
        for key, value in document["strings"].items():
            self.assertEqual(set(value), {"en", "zh-Hans"})
            live = catalog[key]["localizations"]
            self.assertEqual(value["en"], live["en"]["stringUnit"]["value"])
            self.assertEqual(value["zh-Hans"], live["zh-Hans"]["stringUnit"]["value"])
            self.assertNotIn("http://", value["en"] + value["zh-Hans"])
            self.assertNotIn("https://", value["en"] + value["zh-Hans"])

    def test_model_keeps_unknown_as_a_dash_and_hides_missing_writes(self):
        text = read(MODEL)
        section = text.split("public enum StampCameraCapturePhase", 1)[1]
        self.assertIn("executor.execute(.createStamp", text.split("public enum StampCameraCapturePhase", 1)[0])
        self.assertIn('public static let unknownMark = "\\u{2014}"', section)
        self.assertIn('return make(.loading, "", "loading")', section)
        self.assertIn("if loading { return project(.loading) }", section)
        self.assertIn("if confirmedTotal == 0 { return listIsEmpty ? project(.empty) : project(.unknown) }", section)
        self.assertIn("guard let id, id > 0 else { return project(.unknown) }", section)
        self.assertIn("guard let caption else { return project(.unknown) }", section)
        self.assertIn("RoamExperienceCapabilities.mediaUpload", section)
        self.assertIn("RoamExperienceCapabilities.stampExchange", section)
        self.assertIn("RoamAlbumMetadataReadRoute.path", section)
        self.assertIn("createPath = showsCreate ? StampCameraPageReady.createPath : nil", section)
        self.assertIn("exchangePath = showsExchange ? StampCameraPageReady.exchangePath : nil", section)
        self.assertIn("listPath = hasAlbumReader ? StampCameraPageReady.listPath : nil", section)
        self.assertIn("registersRoute = false", section)
        self.assertIn("marksRouteLive = false", section)
        self.assertNotIn("https://", section)
        self.assertNotIn('"api/', section)
        for name in (
            "showsMerchantChoice",
            "paymentEnabled",
            "payoutEnabled",
            "withdrawalEnabled",
            "virtualGoodsEnabled",
        ):
            self.assertIn(f"public static let {name} = false", section)
            self.assertNotIn(f"{name} = true", section)
        before, _, after = text.partition("#if DEBUG")
        self.assertNotIn("StampCameraPageFixtureData", before)
        self.assertLess(after.index("enum StampCameraPageFixtureData"), after.index("#endif"))
        self.assertNotIn("URLSession", after)
        view = read(VIEW)
        # The camera view measures the caption with the page-ready helper. It still does not register routes.
        self.assertIn("StampCameraPageReady.captionUnits(captionText)", view)
        self.assertNotIn("StampCameraPageReady.createPath", view)
        self.assertNotIn("marksRouteLive", view)

    def test_existing_stamp_tests_remain(self):
        captions = read("Tests/CoreTests/RoamStampCaptionTests.swift")
        media = read("Tests/CoreTests/MediaDestinationsTests.swift")
        lookup = read("Tests/CoreTests/RoamCreatedStampLookupTests.swift")
        self.assertGreaterEqual(len(re.findall(r"func test\w+\(", captions)), 13)
        self.assertGreaterEqual(len(re.findall(r"func test\w+\(", media)), 18)
        self.assertGreaterEqual(len(re.findall(r"func test\w+\(", lookup)), 18)
        self.assertIn("func testCaptionLimitUsesUTF16AndAllowsEmptyWithoutTruncation", captions)
        self.assertIn(".created(29)", media)
        self.assertIn(".unknown", lookup)
        added = read("Tests/CoreTests/StampCameraPageReadyTests.swift")
        self.assertGreaterEqual(len(re.findall(r"func test\w+\(", added)), 8)
        self.assertIn("XCTAssertNotEqual(value.text, \"0\")", added)
        note = read(PAGE)
        for evidence in (
            "Core/RoamStampCaptureCoordinator.swift",
            STRINGS,
            "StampCameraPageFixtureData",
            "Tests/CoreTests/StampCameraPageReadyTests.swift",
            "Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py",
        ):
            self.assertIn(evidence, note)


if __name__ == "__main__":
    unittest.main()
