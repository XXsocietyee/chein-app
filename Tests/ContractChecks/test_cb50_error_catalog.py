import pathlib
import re
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import backend_error_catalog as catalog  # noqa: E402


class CB50ErrorCatalogTests(unittest.TestCase):
    def test_outputs_match_the_map(self):
        self.assertEqual((ROOT / "Core/BackendErrorCatalog.swift").read_text(encoding="utf-8"), catalog.render_swift())
        self.assertEqual((ROOT / "Resources/BackendErrorCatalog.xcstrings").read_text(encoding="utf-8"), catalog.render_catalog())
        self.assertEqual((ROOT / "docs/release/cb50-errors.md").read_text(encoding="utf-8"), catalog.render_doc())

    def test_unknown_code_stays_generic_and_hides_the_server_text(self):
        generic_en = catalog.sentence(language="en")
        generic_zh = catalog.sentence(language="zh-Hans")
        self.assertEqual(catalog.sentence(code="NOT_A_REAL_CODE", message="请先登录", language="en"), generic_en)
        self.assertEqual(catalog.sentence(code="NOT_A_REAL_CODE", message="请先登录", language="zh-Hans"), generic_zh)
        self.assertNotIn("NOT_A_REAL_CODE", generic_en)
        self.assertNotIn("请先登录", generic_en)
        self.assertNotIn("raw server text", catalog.sentence(code="NOPE", message="raw server text", language="en"))

    def test_known_code_message_and_status(self):
        self.assertEqual(catalog.sentence(code="FORBIDDEN", language="en"), "You don't have permission to do that.")
        self.assertEqual(catalog.sentence(code="FORBIDDEN", language="zh-Hans"), "你没有权限执行此操作。")
        self.assertEqual(catalog.sentence(code="UNKNOWN", language="en"), "The result is still unknown. Please try again later.")
        self.assertNotEqual(catalog.sentence(code="UNKNOWN", language="en"), catalog.sentence(language="en"))
        self.assertEqual(catalog.sentence(message="请先登录", language="zh-Hans"), "请先登录")
        self.assertEqual(catalog.sentence(message="请先登录", language="en"), "Sign in first.")
        self.assertEqual(catalog.sentence(status=401, language="zh-Hans"), "登录已过期，请重新登录。")
        self.assertEqual(catalog.sentence(status=520, message="please ignore", language="en"), "The original result is still unknown.")
        self.assertEqual(catalog.sentence(code="  FORBIDDEN  ", message="请先登录", language="en"), catalog.sentence(code="FORBIDDEN", language="en"))
        self.assertEqual(catalog.sentence(message="请先登录，请稍后再试", language="en"), catalog.sentence(language="en"))
        self.assertEqual(catalog.sentence(status=418, language="zh-Hans"), catalog.sentence(language="zh-Hans"))

    def test_missing_configuration_is_not_configured_before_a_request(self):
        for base, realm in [("", "realm"), ("https://example.invalid", ""), ("  ", "realm"), ("https://example.invalid", "  ")]:
            with self.assertRaises(LookupError):
                catalog.require_configuration(base, realm)
        catalog.require_configuration("https://example.invalid", "realm")
        source = (ROOT / "Core/BackendErrorCatalog.swift").read_text(encoding="utf-8")
        start = source.index("public static func requireConfiguration")
        end = source.index("private static let codes")
        body = source[start:end]
        throw_at = body.index("throw APIError.notConfigured")
        self.assertLess(body.index("guard !baseURL.isEmpty, !realm.isEmpty"), throw_at)
        for forbidden in ("URLSession", "URLRequest", "http://", "https://", "api/"):
            self.assertNotIn(forbidden, source)

    def test_catalog_is_bilingual_and_app_has_no_localized_string_literal(self):
        import json
        document = json.loads((ROOT / "Resources/BackendErrorCatalog.xcstrings").read_text(encoding="utf-8"))
        self.assertEqual(document["sourceLanguage"], "en")
        self.assertIn("backendError.unknown", document["strings"])
        for key, entry in document["strings"].items():
            self.assertEqual(set(entry["localizations"]), {"en", "zh-Hans"}, key)
            for lang in ("en", "zh-Hans"):
                unit = entry["localizations"][lang]["stringUnit"]
                self.assertEqual(unit["state"], "translated", (key, lang))
                self.assertTrue(unit["value"].strip(), (key, lang))
        # A table-qualified key lookup is not a sentence literal. Bare String(localized:) still fails.
        keyed = re.compile(r'String\(localized:\s*"([^"\n]*)"(?:,\s*table:\s*"([^"\n]+)")?')
        tables = {}
        offenders = []
        for path in (ROOT / "App").rglob("*.swift"):
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                match = keyed.search(line)
                if not match:
                    continue
                key, table = match.group(1), match.group(2)
                if table is None:
                    offenders.append(f"{path.relative_to(ROOT)}:{number}")
                    continue
                if table not in tables:
                    catalog_path = ROOT / "Resources" / f"{table}.xcstrings"
                    if not catalog_path.is_file():
                        offenders.append(f"{path.relative_to(ROOT)}:{number}")
                        continue
                    tables[table] = json.loads(catalog_path.read_text(encoding="utf-8"))["strings"]
                entry = tables[table].get(key)
                if entry is None or set(entry.get("localizations", {})) != {"en", "zh-Hans"}:
                    offenders.append(f"{path.relative_to(ROOT)}:{number}")
        self.assertEqual([], offenders)

    def test_release_defaults_stay_closed(self):
        config = (ROOT / "Config/Base.xcconfig").read_text(encoding="utf-8")
        self.assertIn("MARKETING_VERSION = 0.1.0\n", config)
        self.assertIn("CURRENT_PROJECT_VERSION = 1\n", config)
        self.assertIn("QUESTIFY_API_BASE_URL =\n", config)
        self.assertIn("QUESTIFY_SESSION_REALM =\n", config)
        joined = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (
                ROOT / "Core/BackendErrorCatalog.swift",
                ROOT / "docs/release/cb50-errors.md",
                ROOT / "tools/backend_error_catalog.py",
            )
        )
        self.assertNotIn("47.103.124.64", joined)


if __name__ == "__main__":
    unittest.main()
