"""Source checks for subpackageMember/invoice-titles/index. Not a Swift or Xcode run."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DASH = "\u2014"
NOTE = "docs/release/page-ready/subpackageMember-invoice-titles-index.md"
RULES = "Core/InvoiceLaunchTitleRules.swift"
MISSING = [
    "invoice.titles.signIn",
    "invoice.titles.pendingHold",
    "invoice.titles.saveNotFound",
    "invoice.titles.deleteUnknown",
    "invoice.titles.deleteFailed",
    "invoice.titles.deleteTitle",
]
PRESENT = [
    "loading", "noTitles", "loadFailed", "unknown", "unavailable", "titles",
    "titlesReadOnly", "checkResult", "retry", "addTitle", "edit", "delete",
    "deleteConfirm", "keep", "defaultTitle", "PERSONAL", "COMPANY",
]


class InvoiceTitlesPageReadyTests(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text(encoding="utf-8")

    def page_source(self):
        source = self.read(RULES)
        return source.split("public enum InvoiceLaunchTitlesPage", 1)[1]

    def test_projection_keeps_unknown_as_an_em_dash_and_does_not_mark_a_route_live(self):
        source = self.page_source()
        rules = self.read(RULES).split("public enum InvoiceLaunchTitlesPage", 1)[0]
        for token in [
            "case loading, empty, error, unknown, ready",
            'public static let unknownDisplay = "—"',
            "public static let routeMarkedLive = false",
            "guard let count else { return unknownDisplay }",
            "return String(count)",
            "public static func countText(numericString _: String) -> String { unknownDisplay }",
            "InvoiceLaunchWire.masked(raw) ? raw : unknownDisplay",
            'readOnlyIdentifier: readOnly ? "invoice.titlesReadOnly" : nil',
            "allowsSave: Bool = false",
            "allowsDelete: Bool = false",
        ]:
            self.assertIn(token, source)
        self.assertIn(DASH, source)
        self.assertNotIn("routeMarkedLive = true", source)
        self.assertNotIn("api/", source)
        for forbidden in ["https://", "http://", "URLSession", "URLRequest", "15229020419", "@"]:
            self.assertNotIn(forbidden, source)
        self.assertNotIn("9134", source)
        self.assertIn("func canSubmit(type: String, name: String, tax: String) -> Bool", rules)
        self.assertNotIn("unknownDisplay", rules)
        titles = self.read("App/InvoiceLaunchTitlesView.swift")
        self.assertIn("InvoiceLaunchTitlesPage.facts", titles)
        self.assertNotIn("enum InvoiceLaunchTitlesPage", titles)
        catalog_row = self.read("docs/parity/page-map.csv")
        self.assertIn("subpackageMember/invoice-titles/index,发票抬头列表,App/InvoiceLaunchTitlesView.swift,exists,", catalog_row)

    def test_missing_keys_are_listed_and_existing_title_keys_stay_translated(self):
        note = self.read(NOTE)
        invoice = json.loads(self.read("Resources/InvoiceLaunchUI.xcstrings"))["strings"]
        localizable = json.loads(self.read("Resources/Localizable.xcstrings"))["strings"]
        for key in MISSING:
            self.assertIn("`%s`" % key, note)
            self.assertNotIn(key, invoice)
            self.assertNotIn(key, localizable)
        for key in PRESENT:
            self.assertIn(key, invoice)
            for language in ("en", "zh-Hans"):
                unit = invoice[key]["localizations"][language]["stringUnit"]
                self.assertEqual(unit["state"], "translated")
                self.assertTrue(unit["value"])
        wechat = localizable["auth.wechat.signIn"]["localizations"]
        self.assertEqual(wechat["zh-Hans"]["stringUnit"]["value"], "微信登录")
        self.assertEqual(wechat["en"]["stringUnit"]["state"], "translated")
        for literal in [
            "登录后管理发票抬头",
            "确认前请勿修改抬头",
            "暂未查到这次保存",
            "删除结果未确认，请刷新查看",
            "删除未完成",
            "删除发票抬头",
            "还没有发票抬头",
            "发票功能暂未开放",
            "发票抬头加载失败",
            "上次保存结果未确认",
            "新增发票抬头",
            "删除后不影响已提交的申请。",
        ]:
            self.assertIn(literal, note)
        view = self.read("App/InvoiceLaunchTitlesView.swift")
        # native r2 me-account (da7f2c201): the empty state is the stock ContentUnavailableView, same key and table.
        self.assertIn('ContentUnavailableView {\n                    Label { Text("noTitles", tableName: "InvoiceLaunchUI") }', view)
        self.assertIn("InvoiceLaunchStateSection", view)
        presentation = self.read("App/InvoiceLaunchPresentation.swift")
        self.assertIn('issue = "unknown"', presentation)
        self.assertIn("unresolved = true", presentation)

    def test_existing_title_form_rules_are_unchanged(self):
        source = self.read("Tests/CoreTests/InvoiceLaunchTitleRulesTests.swift")
        for name in [
            "testPersonalNeedsOnlyTrimmedNonEmptyNameUpToOneHundred",
            "testCompanyTaxNumberMustBeFifteenToTwentyDigitsOrLetters",
            "testDraftTrimsNameUppercasesTaxAndDropsTaxForPersonal",
            "testFormDraftIsTheExactBodySentToTheSaveRoute",
            "testInvalidFormNeverReachesTheTransport",
        ]:
            self.assertIn(name, source)


if __name__ == "__main__":
    unittest.main()
