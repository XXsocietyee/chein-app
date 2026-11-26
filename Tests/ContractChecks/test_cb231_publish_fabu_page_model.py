"""Loading, empty, error, and unknown for the professional theme editor page.

Unknown and empty text is an em dash. A literal integer 0 stays "0". A missing
pro capability stays hidden. This test does not open the player-first entry,
does not mark a route live, and does not turn a payment switch on.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Core" / "ProjectEditService.swift"
COORDINATOR = ROOT / "Core" / "ProjectEditCoordinator.swift"
STRINGS = ROOT / "docs" / "release" / "ui-strings-pages-publish-fabu-index.json"
SWITCHES = ROOT / "Core" / "ChinaReviewedRouteCapability.swift"
WELCOME = ROOT / "App" / "WelcomeView.swift"
DASH = "\u2014"
NUMERIC = re.compile(r"^-?\d+(\.\d+)?$")


def explicit_pro(home):
    if not isinstance(home, dict):
        return False
    permission = home.get("permission")
    if not isinstance(permission, dict):
        return False
    return permission.get("canProPublish") is True


def is_unknown_token(token):
    trimmed = token.strip()
    return trimmed == "" or trimmed.lower() == "unknown" or trimmed == DASH or NUMERIC.fullmatch(trimmed) is not None


def quota_field(home):
    if not isinstance(home, dict):
        return ("unknown", DASH, "unknown")
    quota = home.get("quota")
    if not isinstance(quota, dict) or "themesRemaining" not in quota or quota["themesRemaining"] is None:
        return ("unknown", DASH, "unknown")
    number = quota["themesRemaining"]
    if isinstance(number, bool) or not isinstance(number, int):
        return ("unknown", DASH, "unknown")
    return ("ready", str(number), "ready.quota")


def chapter_field(chapter_count):
    if chapter_count is None or chapter_count < 0:
        return ("unknown", DASH, "unknown")
    if chapter_count == 0:
        return ("empty", DASH, "empty")
    return ("ready", str(chapter_count), "ready.chapters")


def hidden():
    return {
        "phase": "unknown", "text": DASH, "reason": "hidden", "visible": False,
        "accessibilityIdentifier": "projectEdit.fabu.hidden",
        "quota": ("unknown", DASH, "unknown"), "chapters": ("unknown", DASH, "unknown"),
    }


def unknown_page(visible):
    return {
        "phase": "unknown", "text": DASH, "reason": "unknown", "visible": visible,
        "accessibilityIdentifier": "projectEdit.fabu.unknown",
        "quota": ("unknown", DASH, "unknown"), "chapters": ("unknown", DASH, "unknown"),
    }


def project(state, message_key, home, chapter_count):
    if state in ("loading", "reviewing", "submitting"):
        return {
            "phase": "loading", "text": "", "reason": "loading", "visible": False,
            "accessibilityIdentifier": "projectEdit.fabu.loading",
            "quota": ("loading", "", "loading"), "chapters": ("loading", "", "loading"),
        }
    if state in ("unknown", "notSent"):
        return unknown_page(False)
    if state in ("blocked", "rejected"):
        if not explicit_pro(home):
            return hidden()
        token = (message_key or "").strip()
        if is_unknown_token(token):
            return unknown_page(True)
        return {
            "phase": "error", "text": token, "reason": "error", "visible": True,
            "accessibilityIdentifier": "projectEdit.fabu.error",
            "quota": ("unknown", DASH, "unknown"), "chapters": ("unknown", DASH, "unknown"),
        }
    if state not in ("idle", "simulated", "acknowledged"):
        raise AssertionError(state)
    if not explicit_pro(home):
        return hidden()
    quota = quota_field(home)
    chapters = chapter_field(chapter_count)
    if chapters[0] == "empty":
        phase, text, reason, identifier = "empty", DASH, "empty", "projectEdit.fabu.empty"
    elif quota[0] == "unknown" and chapters[0] == "unknown":
        phase, text, reason, identifier = "unknown", DASH, "unknown", "projectEdit.fabu.unknown"
    else:
        text = quota[1] if quota[0] == "ready" else chapters[1]
        phase, reason, identifier = "ready", "ready", "projectEdit.fabu.ready"
    return {
        "phase": phase, "text": text, "reason": reason, "visible": True,
        "accessibilityIdentifier": identifier, "quota": quota, "chapters": chapters,
    }


def pro_home(remaining="omit"):
    home = {"permission": {"canProPublish": True}}
    if remaining != "omit":
        home["quota"] = {"themesRemaining": remaining}
    return home


class PublishFabuPageModelContract(unittest.TestCase):
    def test_empty_and_unknown_are_an_em_dash_and_zero_stays_zero(self):
        self.assertEqual(DASH, "—")
        self.assertEqual(ord(DASH), 0x2014)
        empty = project("idle", None, pro_home(2), 0)
        self.assertEqual(empty["phase"], "empty")
        self.assertEqual(empty["text"], DASH)
        self.assertEqual(empty["chapters"], ("empty", DASH, "empty"))
        self.assertNotEqual(empty["chapters"][1], "0")
        self.assertEqual(empty["quota"], ("ready", "2", "ready.quota"))
        zero = project("idle", None, pro_home(0), 3)
        self.assertEqual(zero["text"], "0")
        self.assertEqual(zero["quota"][1], "0")
        self.assertEqual(zero["chapters"][1], "3")
        numeric = project("idle", None, pro_home("0"), 2)
        self.assertEqual(numeric["quota"][0], "unknown")
        self.assertEqual(numeric["quota"][1], DASH)
        self.assertNotIn("0", numeric["quota"][1])

    def test_missing_capability_stays_hidden(self):
        homes = [None, {}, {"permission": {}}, {"permission": {"canProPublish": False}},
                 {"permission": {"canProPublish": "true"}}, {"permission": None}]
        for home in homes:
            hidden_page = project("idle", None, home, 0)
            self.assertFalse(hidden_page["visible"], home)
            self.assertEqual(hidden_page["phase"], "unknown")
            self.assertEqual(hidden_page["text"], DASH)
            self.assertEqual(hidden_page["accessibilityIdentifier"], "projectEdit.fabu.hidden")
            self.assertNotEqual(hidden_page["chapters"][1], "0")

    def test_loading_and_unknown_outcome_do_not_show_zero(self):
        loading = project("loading", "0", pro_home(0), 0)
        self.assertEqual(loading["phase"], "loading")
        self.assertEqual(loading["text"], "")
        self.assertNotIn(DASH, loading["text"])
        self.assertNotIn("0", loading["quota"][1])
        self.assertNotIn("0", loading["chapters"][1])
        for state in ("reviewing", "submitting"):
            self.assertEqual(project(state, None, pro_home(0), 0)["phase"], "loading")
        for state in ("unknown", "notSent"):
            outcome = project(state, None, pro_home(0), 4)
            self.assertEqual(outcome["phase"], "unknown")
            self.assertFalse(outcome["visible"])
            self.assertEqual(outcome["quota"][1], DASH)
            self.assertNotIn("0", outcome["quota"][1])

    def test_error_token_and_gated_failure(self):
        failed = project("blocked", " projectEdit.loadFailed ", pro_home(0), 0)
        self.assertEqual(failed["phase"], "error")
        self.assertEqual(failed["text"], "projectEdit.loadFailed")
        self.assertTrue(failed["visible"])
        self.assertEqual(failed["quota"][1], DASH)
        for token in ("", "  ", "UNKNOWN", "unknown", "0", "0.0", "12", DASH):
            state = project("rejected", token, pro_home(1), 1)
            self.assertEqual(state["phase"], "unknown", token)
            self.assertEqual(state["text"], DASH, token)
        gated = project("blocked", "projectEdit.loadFailed", None, 2)
        self.assertFalse(gated["visible"])
        self.assertEqual(gated["accessibilityIdentifier"], "projectEdit.fabu.hidden")

    def test_swift_source_locks_states_dash_and_gate(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn('public static let emptyText = "—"', source)
        self.assertIn('public static let unknownText = "—"', source)
        for phase in ("loading", "empty", "error", "unknown", "ready"):
            self.assertIn(f"case {phase}", source)
        self.assertIn("case .loading, .reviewing, .submitting:", source)
        self.assertIn("case .unknown, .notSent:", source)
        self.assertIn("guard explicitPro(home) else { return hiddenProjection() }", source)
        self.assertIn("if case .bool(true) = flag { return true }", source)
        self.assertIn("guard let number = raw.integer else { return unknownField(PublishFabuAccessibility.quota) }", source)
        self.assertIn("if chapterCount == 0 {", source)
        self.assertIn('token.range(of: #"^-?\\d+(\\.\\d+)?$"#, options: .regularExpression)', source)
        self.assertIn("public static let registersRoute = false", source)
        self.assertIn("public static let marksRouteLive = false", source)
        self.assertIn("public static let opensPlayerFirstEntry = false", source)
        self.assertNotIn("api/", source)
        self.assertNotIn("://", source)
        self.assertNotIn("paymentEnabled = true", source)
        self.assertNotIn("showsMerchantChoice = true", source)
        coordinator = COORDINATOR.read_text(encoding="utf-8")
        self.assertIn("public func fabuPageModel(home: [String: ProjectEditJSON]?, chapterCount: Int?) -> PublishFabuPageProjection", coordinator)
        method = coordinator.split("public func fabuPageModel", 1)[1]
        self.assertNotIn("submit(", method)
        self.assertNotIn("api/", method)
        states = re.search(r"public enum State: Equatable \{ case ([^}]+) \}", coordinator)
        self.assertIsNotNone(states)
        names = [part.strip() for part in states.group(1).split(",")]
        self.assertEqual(names, ["idle", "loading", "reviewing", "submitting", "simulated", "acknowledged", "unknown", "rejected", "notSent", "blocked"])
        for name in names:
            self.assertIn(f"case .{name}: self = .{name}", source)

    def test_strings_are_bilingual_and_match_identifiers(self):
        catalog = json.loads(STRINGS.read_text(encoding="utf-8"))
        self.assertEqual(catalog["page"], "pages/publish/fabu/index")
        self.assertEqual(catalog["status"], "gated")
        self.assertEqual(catalog["native"], "App/ProjectEditView.swift")
        expected = {
            "projectEdit.fabu.loading": "projectEdit.fabu.loading",
            "projectEdit.fabu.empty": "projectEdit.fabu.empty",
            "projectEdit.fabu.error": "projectEdit.fabu.error",
            "projectEdit.fabu.unknown": "projectEdit.fabu.unknown",
            "projectEdit.fabu.ready": "projectEdit.fabu.ready",
            "projectEdit.fabu.hidden": "projectEdit.fabu.hidden",
            "projectEdit.fabu.quota": "projectEdit.fabu.quota",
            "projectEdit.fabu.chapters": "projectEdit.fabu.chapters",
        }
        self.assertEqual(set(catalog["strings"]), set(expected))
        for key, identifier in expected.items():
            row = catalog["strings"][key]
            self.assertEqual(set(row), {"en", "zh-Hans", "accessibilityIdentifier"})
            self.assertTrue(row["en"].strip())
            self.assertTrue(row["zh-Hans"].strip())
            self.assertEqual(row["accessibilityIdentifier"], identifier)
            self.assertNotIn("http", row["en"].lower())
            self.assertNotIn("http", row["zh-Hans"].lower())
        self.assertEqual(catalog["strings"]["projectEdit.fabu.unknown"]["en"], DASH)
        self.assertEqual(catalog["strings"]["projectEdit.fabu.unknown"]["zh-Hans"], DASH)
        self.assertEqual(catalog["strings"]["projectEdit.fabu.empty"]["en"], DASH)
        self.assertEqual(catalog["strings"]["projectEdit.fabu.empty"]["zh-Hans"], DASH)
        self.assertNotEqual(catalog["strings"]["projectEdit.fabu.unknown"]["en"], "0")

    def test_page_is_not_mounted_and_player_entry_stays_closed(self):
        for path in (ROOT / "App").rglob("*View*.swift"):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("PublishFabuPageModel", text, path)
            self.assertNotIn("fabuPageModel", text, path)
        welcome = WELCOME.read_text(encoding="utf-8")
        self.assertIn("static let showsMerchantChoice = false", welcome)
        self.assertNotIn("showsMerchantChoice = true", welcome)

    def test_existing_debug_fixtures_and_payment_switches(self):
        for name in ("Core/ProjectEditSyntheticFixtures.swift", "Core/ProjectEditRemoteFixtures.swift"):
            text = (ROOT / name).read_text(encoding="utf-8").strip()
            self.assertTrue(text.startswith("#if DEBUG"), name)
            self.assertTrue(text.endswith("#endif"), name)
        source = SWITCHES.read_text(encoding="utf-8")
        for name in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn(f"public static var {name}: Bool {{ testDerivation?", source)
            self.assertNotIn(f"public static let {name} = true", source)


if __name__ == "__main__":
    unittest.main()
