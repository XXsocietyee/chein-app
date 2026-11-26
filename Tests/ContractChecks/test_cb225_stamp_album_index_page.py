"""Stamp-album loading, empty, error, and unknown projection.

Unknown and empty totals are an em dash. A literal integer 0 on an empty album stays
empty, not the digit 0. A numeric string is unknown. This test does not open a route
or a host, does not mount a view, and does not turn a payment switch on.
"""
from pathlib import Path
import json
import math
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Core" / "RoamExperienceCoordinators.swift"
CATALOG = ROOT / "docs" / "release" / "ui-strings-subpackageP3-pages-stamp-album-index-index.json"
SWITCHES = ROOT / "Core" / "ChinaReviewedRouteCapability.swift"
DASH = "\u2014"


def section():
    text = SOURCE.read_text()
    start = text.index("public enum StampAlbumIndexPhase")
    return text[start:]


def literal_total(value):
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, int):
        return value if value >= 0 else None
    if isinstance(value, float):
        if not math.isfinite(value) or value < 0 or value > 9_007_199_254_740_991:
            return None
        number = int(value)
        return number if float(number) == value else None
    return None


def visible_count(value):
    if not isinstance(value, list):
        return None
    seen = []
    for row in value:
        if not isinstance(row, dict):
            continue
        stamp_id = row.get("id")
        if isinstance(stamp_id, bool) or not isinstance(stamp_id, int) or stamp_id <= 0:
            continue
        check = row.get("checkState", 0)
        if isinstance(check, bool) or not isinstance(check, int) or check not in (0, 1):
            continue
        if stamp_id in seen:
            return None
        seen.append(stamp_id)
    return len(seen)


def classify(token):
    trimmed = token.strip()
    if trimmed == "" or trimmed.lower() == "unknown" or trimmed == DASH or trimmed == "0":
        return ("unknown", DASH, None)
    if trimmed in ("unauthorized", "401"):
        access = "login"
    elif trimmed == "403":
        access = "denied"
    else:
        access = None
    return ("error", trimmed, access)


def slots(count):
    if count is None or not 0 <= count <= 100:
        return []
    return list(range(count))


def finish(failure, total, visible, retains):
    if failure is not None:
        phase, text, access = classify(failure)
        if phase == "unknown":
            return ("unknown", DASH, DASH, None, None, False, [])
        if retains and isinstance(total, int) and total > 0:
            shown = DASH if visible is None else str(visible)
            return ("ready", str(total), shown, text, access, True, slots(visible))
        return ("error", text, DASH, text, access, False, [])
    if total is None:
        return ("unknown", DASH, DASH, None, None, False, [])
    if total == 0:
        if visible != 0:
            return ("unknown", DASH, DASH, None, None, False, [])
        return ("empty", DASH, DASH, None, None, False, [])
    if visible is not None and visible > total:
        return ("unknown", DASH, DASH, None, None, False, [])
    shown = DASH if visible is None else str(visible)
    return ("ready", str(total), shown, None, None, False, slots(visible))


def project(loading, loaded, failure=None, server_total=None, visible=None, retains=False):
    if loading:
        return ("loading", "", "", None, None, False, [])
    total = server_total if loaded and isinstance(server_total, int) and server_total >= 0 else None
    rows = visible if loaded else None
    return finish(failure, total, rows, retains and loaded)


def payload(raw):
    try:
        wire = json.loads(raw)
    except json.JSONDecodeError:
        return ("malformed",)
    if not isinstance(wire, dict):
        return ("malformed",)
    if "code" not in wire:
        return ("page", literal_total(wire.get("total")), visible_count(wire.get("list")))
    code = wire.get("code")
    if isinstance(code, bool) or not isinstance(code, int):
        return ("unreadable",)
    if code == 200:
        body = wire.get("data")
        if not isinstance(body, dict):
            return ("page", None, None)
        return ("page", literal_total(body.get("total")), visible_count(body.get("list")))
    if code == 401:
        return ("failed", "unauthorized")
    if code == 403:
        return ("failed", "403")
    return ("failed", "business.%s" % code)


def project_data(raw, loading=False, failure=None):
    if loading:
        return project(True)
    kind = payload(raw)
    if kind[0] == "malformed":
        return project(False, False, failure or "malformed")
    if kind[0] == "unreadable":
        return project(False, False, failure)
    if kind[0] == "failed":
        return project(False, False, failure or kind[1])
    return project(False, True, failure, kind[1], kind[2], False)


def album_json():
    text = (ROOT / "Core" / "RoamExperienceSyntheticFixtures.swift").read_text()
    match = re.search(r'public static let album = #"(.*)"#', text)
    if not match:
        raise AssertionError("existing album fixture missing")
    return match.group(1)


class StampAlbumIndexPageTests(unittest.TestCase):
    def test_source_keeps_the_existing_route_hidden_flags_and_debug_fixture(self):
        body = section()
        self.assertIn("public static let routePath = RoamAlbumMetadataReadRoute.path", body)
        for flag in ("registersRoute", "marksRouteLive", "opensHost", "showsCapture", "showsMerchantChoice"):
            self.assertIn("public static let %s = false" % flag, body)
            self.assertNotIn("%s = true" % flag, body)
        self.assertIn('public static let unknownText = "\\u{2014}"', body)
        self.assertIn("#if DEBUG", body)
        self.assertIn("public enum StampAlbumIndexFixtureData", body)
        self.assertNotIn("https://", body)
        self.assertNotIn("paymentEnabled = true", body)
        self.assertIn("static let showsMerchantChoice = false", (ROOT / "App" / "WelcomeView.swift").read_text())
        switches = SWITCHES.read_text()
        for name in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn("public static var %s: Bool { testDerivation?" % name, switches)

    def test_empty_and_unknown_are_an_em_dash_and_a_numeric_string_is_not_zero(self):
        self.assertEqual(ord(DASH), 0x2014)
        empty = project_data('{"list":[],"total":0,"pageNum":1,"pageSize":20}')
        unknown = project_data('{"list":[{"id":901,"picUrl":"","checkState":0}],"total":"UNKNOWN","pageNum":1,"pageSize":20}')
        zero_string = project_data('{"list":[],"total":"0","pageNum":1,"pageSize":20}')
        missing = project_data('{"list":[{"id":901,"picUrl":"","checkState":0}],"pageNum":1,"pageSize":20}')
        self.assertEqual(empty[0], "empty")
        self.assertEqual(unknown[0], "unknown")
        self.assertEqual(empty[1], DASH)
        self.assertEqual(unknown[1], DASH)
        self.assertNotIn("0", unknown[1])
        self.assertNotIn("1", unknown[1])
        self.assertEqual(zero_string[0], "unknown")
        self.assertNotEqual(zero_string[0], "empty")
        self.assertNotIn("0", zero_string[1])
        self.assertEqual(missing[0], "unknown")
        self.assertNotIn("1", missing[1])

    def test_server_total_is_not_replaced_by_the_visible_count(self):
        ready = project_data(album_json())
        self.assertEqual(ready[0], "ready")
        self.assertEqual(ready[1], "3")
        self.assertEqual(ready[2], "2")
        self.assertEqual(ready[6], [0, 1])
        hidden = project_data('{"list":[{"id":7,"picUrl":"","checkState":2},{"id":8,"checkState":99}],"total":2,"pageNum":1,"pageSize":20}')
        self.assertEqual(hidden[0], "ready")
        self.assertEqual(hidden[1], "2")
        self.assertEqual(hidden[2], "0")
        self.assertEqual(project_data('{"list":[],"total":-1,"pageNum":1,"pageSize":20}')[0], "unknown")
        self.assertEqual(project_data('{"list":[],"total":1.5,"pageNum":1,"pageSize":20}')[1], DASH)
        self.assertEqual(project(False, True, server_total=3, visible=None)[1], "3")
        self.assertEqual(project(False, True, server_total=3, visible=None)[2], DASH)

    def test_loading_wins_and_error_tokens_stay_distinct_from_zero(self):
        loading = project(True, True, failure="0", server_total=0, visible=0, retains=True)
        self.assertEqual(loading[0], "loading")
        self.assertEqual(loading[1], "")
        self.assertNotEqual(loading[1], DASH)
        self.assertNotIn("0", loading[1])
        failed = project(False, True, failure=" album.readFailed ", server_total=4, visible=1)
        self.assertEqual(failed[0], "error")
        self.assertEqual(failed[1], "album.readFailed")
        for token in ("", "  ", "UNKNOWN", "unknown", "0", DASH):
            state = project(False, True, failure=token, server_total=4, visible=1, retains=True)
            self.assertEqual(state[0], "unknown", token)
            self.assertEqual(state[1], DASH, token)
        continued = project(False, True, failure="http.503", server_total=3, visible=2, retains=True)
        self.assertEqual(continued[0], "ready")
        self.assertEqual(continued[1], "3")
        self.assertEqual(continued[2], "2")
        self.assertTrue(continued[5])
        unread = project(False, False, server_total=0, visible=0)
        self.assertEqual(unread[0], "unknown")
        self.assertNotEqual(unread[0], "empty")

    def test_denied_sign_in_and_bad_payloads_do_not_invent_a_count(self):
        denied = project_data('{"code":403,"data":null}')
        self.assertEqual(denied[0], "error")
        self.assertEqual(denied[4], "denied")
        self.assertEqual(denied[1], "403")
        self.assertEqual(denied[2], DASH)
        login = project(False, False, failure="unauthorized")
        self.assertEqual(login[0], "error")
        self.assertEqual(login[4], "login")
        self.assertEqual(project_data("not-json")[1], "malformed")
        coded = project_data('{"code":"403","data":{"total":0,"list":[]}}')
        self.assertEqual(coded[0], "unknown")
        self.assertIsNone(coded[4])
        self.assertEqual(project_data('{"code":200,"data":null}')[0], "unknown")
        self.assertEqual(project_data('{"code":401,"data":{"total":4,"list":[]}}')[1], "unauthorized")

    def test_catalog_has_both_languages_and_the_same_accessibility_identifiers(self):
        catalog = json.loads(CATALOG.read_text())
        self.assertEqual(catalog["page"], "subpackageP3/pages/stamp-album/index/index")
        keys = catalog["keys"]
        self.assertGreaterEqual(len(keys), 8)
        seen = set()
        for row in keys:
            self.assertNotIn(row["key"], seen)
            seen.add(row["key"])
            for lang in ("en", "zh-Hans"):
                self.assertTrue(row[lang].strip(), row["key"])
                self.assertNotIn("http://", row[lang])
                self.assertNotIn("https://", row[lang])
        unknown = next(row for row in keys if row["key"] == "stampAlbum.unknown")
        self.assertEqual(unknown["en"], DASH)
        self.assertEqual(unknown["zh-Hans"], DASH)
        identifiers = catalog["accessibilityIdentifiers"]
        self.assertEqual(len(identifiers), len(set(identifiers)))
        self.assertIn("roam.experience.album", identifiers)
        self.assertIn("roam.experience.album.empty", identifiers)
        listed = re.search(r"public static let accessibilityIdentifiers = \[(.*?)\]", section(), re.S)
        self.assertIsNotNone(listed)
        swift_ids = re.findall(r'"([^"]+)"', listed.group(1))
        self.assertEqual(identifiers, swift_ids)


if __name__ == "__main__":
    unittest.main()
