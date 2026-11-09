"""CB49 locale rules: dates, numbers, CNY/USD, plurals, and the closed US backend."""

from datetime import datetime
from decimal import Decimal
from pathlib import Path
import unittest

from tools import locale_formats as lf

ROOT = Path(__file__).resolve().parents[2]


class LocaleIdentityTests(unittest.TestCase):
    def test_supported_tags_collapse_and_unknown_locales_fail_closed(self):
        for tag in ("zh-Hans", "zh-CN", "zh_CN", "zh_Hans_CN"):
            self.assertEqual(lf.normalize_locale(tag), "zh-Hans")
        for tag in ("en", "en-US", "en_US", "en-GB"):
            self.assertEqual(lf.normalize_locale(tag), "en")
        for tag in ("", "de-DE", "und"):
            with self.assertRaises(ValueError):
                lf.normalize_locale(tag)

    def test_both_display_locales_share_grouping_and_decimal_marks(self):
        self.assertEqual(lf.separators("zh-Hans"), (",", "."))
        self.assertEqual(lf.separators("en-US"), (",", "."))
        self.assertEqual(lf.format_number("1234.5678", "zh-Hans"), "1,234.5678")
        self.assertEqual(lf.format_number("1234.5678", "en"), "1,234.5678")
        self.assertEqual(lf.format_number("-10000", "zh_CN"), "-10,000")
        self.assertEqual(lf.format_number("01", "en"), "01")
        self.assertEqual(lf.format_number("1,234", "en"), "1,234")


class CurrencyRuleTests(unittest.TestCase):
    def test_unknown_amounts_are_an_em_dash_and_never_zero(self):
        for amount in (None, "", "  ", "UNKNOWN", "unknown", "NaN", "null", "—", "-", 0.0, False):
            for currency in ("CNY", "USD", None):
                rendered = lf.format_money(amount, currency, "en")
                self.assertEqual(rendered, lf.EM_DASH)
                self.assertNotIn("0", rendered)
        self.assertEqual(lf.format_fen(None, "CNY", "zh-Hans"), lf.EM_DASH)
        self.assertEqual(lf.format_fen(None, "USD", "en"), lf.EM_DASH)
        self.assertNotEqual(lf.format_fen(True, "CNY", "en"), "¥1.00")

    def test_known_zero_stays_zero_for_explicit_currency(self):
        self.assertEqual(lf.format_money(0, "CNY", "zh-Hans"), "¥0.00")
        self.assertEqual(lf.format_money("0", "USD", "en"), "$0.00")
        self.assertEqual(lf.format_money("+0", "CNY", "en"), "¥0.00")
        self.assertEqual(lf.format_money("−0", "USD", "zh-Hans"), "$0.00")
        self.assertEqual(lf.format_fen(0, "CNY", "en"), "¥0.00")
        self.assertEqual(lf.format_fen(0, "USD", "zh-Hans"), "$0.00")

    def test_locale_does_not_choose_or_convert_currency(self):
        self.assertEqual(lf.format_money("1234.5", "CNY", "en"), "¥1,234.50")
        self.assertEqual(lf.format_money("1234.5", "USD", "zh-Hans"), "$1,234.50")
        self.assertEqual(lf.format_money("1234.5", "CNY", "zh-CN"), "¥1,234.50")
        self.assertEqual(lf.format_money("1234.5", "USD", "en-US"), "$1,234.50")
        self.assertEqual(lf.format_money(Decimal("1.005"), "USD", "zh-Hans"), "$1.01")
        self.assertEqual(lf.format_money(Decimal("-1.005"), "CNY", "en"), "-¥1.01")
        self.assertEqual(lf.format_fen(9900, "CNY", "en"), "¥99.00")
        self.assertEqual(lf.format_fen(1, "USD", "zh-Hans"), "$0.01")
        self.assertEqual(lf.format_fen(-1, "USD", "en"), "-$0.01")
        self.assertEqual(lf.format_money("12.5", None, "en"), "12.50")
        self.assertEqual(lf.format_money("12.5", "", "zh-Hans"), "12.50")
        self.assertEqual(lf.format_money("12.5", "EUR", "en"), "12.50 EUR")
        self.assertNotIn("$", lf.format_money("12.5", "CNY", "en-US"))
        self.assertNotIn("¥", lf.format_money("12.5", "USD", "zh-Hans"))

    def test_usd_formatting_does_not_enable_a_us_backend(self):
        self.assertEqual(lf.format_money("8", "USD", "en"), "$8.00")
        self.assertIsNone(lf.api_host("US"))
        self.assertFalse(lf.US_BACKEND_ENABLED)
        self.assertEqual(lf.api_host("CN"), "https://www.chengyinhub.com/prod-api/")
        with self.assertRaises(ValueError):
            lf.api_host("EU")
        module = Path(lf.__file__).read_text()
        self.assertNotIn("47.103.124.64", module)
        self.assertNotIn("us.chengyinhub", module)
        self.assertNotIn("https://us.", module)


class PluralRuleTests(unittest.TestCase):
    def test_english_one_is_absolute_integer_one_and_chinese_is_always_other(self):
        self.assertEqual(lf.plural_category("en", 0), "other")
        self.assertEqual(lf.plural_category("en", 1), "one")
        self.assertEqual(lf.plural_category("en", -1), "one")
        self.assertEqual(lf.plural_category("en", "+1"), "one")
        self.assertEqual(lf.plural_category("en", "1.0"), "other")
        self.assertEqual(lf.plural_category("en", "2"), "other")
        for amount in (0, 1, -1, "1.0", 21):
            self.assertEqual(lf.plural_category("zh-Hans", amount), "other")

    def test_chinese_does_not_read_the_english_singular_template(self):
        english = {"one": "{n} member", "other": "{n} members"}
        chinese = {"one": "{n} member", "other": "{n} 名成员"}
        self.assertEqual(lf.format_count("en", 1, english), "1 member")
        self.assertEqual(lf.format_count("en", -1, english), "-1 member")
        self.assertEqual(lf.format_count("en", 0, english), "0 members")
        self.assertEqual(lf.format_count("en", 21, english), "21 members")
        self.assertEqual(lf.format_count("zh-Hans", 1, chinese), "1 名成员")
        self.assertEqual(lf.format_count("zh-CN", 0, chinese), "0 名成员")
        self.assertEqual(lf.format_count("zh-Hans", -1, chinese), "-1 名成员")
        self.assertEqual(lf.format_count("en", 0, chinese), "0 名成员")
        self.assertEqual(lf.format_count("en", 10000, {"other": "{n} members"}), "10,000 members")
        self.assertEqual(lf.format_count("zh-Hans", 10000, {"other": "{n} 名成员"}), "10,000 名成员")
        points = {"one": "{n} point", "other": "{n} points"}
        self.assertEqual(lf.format_count("en", 1, points), "1 point")
        self.assertEqual(lf.format_count("en", "1.5", points), "1.5 points")
        self.assertEqual(lf.format_count("zh-Hans", 1, {"one": "{n} point", "other": "{n} 积分"}), "1 积分")
        with self.assertRaises(ValueError):
            lf.format_count("zh-Hans", 1, {"one": "{n} point"})


class DateRuleTests(unittest.TestCase):
    def test_civil_dates_follow_the_locale_and_invalid_days_stay_verbatim(self):
        self.assertEqual(lf.format_civil_date("2024-02-29", "zh-Hans"), "2024年2月29日")
        self.assertEqual(lf.format_civil_date("2024-02-29", "en-US"), "Feb 29, 2024")
        self.assertEqual(lf.format_civil_date("2024-01-01", "zh_CN"), "2024年1月1日")
        self.assertEqual(lf.format_civil_date("2000-02-29", "en"), "Feb 29, 2000")
        for source in ("2023-02-29", "1900-02-29", "2024-04-31", "2024-02-29 ", "2024-01-01T00:00:00Z", "unknown"):
            self.assertEqual(lf.format_civil_date(source, "zh-Hans"), source)
            self.assertEqual(lf.format_civil_date(source, "en"), source)

    def test_civil_clocks_do_not_shift_and_english_drops_seconds(self):
        self.assertEqual(lf.format_civil_clock("2026-10-23 20:00:00", "zh-Hans"), "2026-10-23 20:00:00")
        self.assertEqual(lf.format_civil_clock("2026-10-23 20:00:00", "en"), "Oct 23, 2026 8:00 PM")
        self.assertEqual(lf.format_civil_clock("2026-10-23 00:05:09", "zh-Hans"), "2026-10-23 00:05:09")
        self.assertEqual(lf.format_civil_clock("2026-10-23 00:05:09", "en"), "Oct 23, 2026 12:05 AM")
        self.assertEqual(lf.format_civil_clock("2026-10-23 12:00:00", "en"), "Oct 23, 2026 12:00 PM")
        self.assertEqual(lf.format_civil_clock("2026-13-01 00:00:00", "en"), "2026-13-01 00:00:00")

    def test_instants_use_the_named_zone_rather_than_the_locale(self):
        instant = lf.utc(2026, 10, 23, 12, 0, 0)
        self.assertEqual(
            lf.format_instant(instant, "zh-Hans", "Asia/Shanghai"),
            "2026-10-23 20:00:00")
        self.assertEqual(
            lf.format_instant(instant, "en", "America/New_York"),
            "Oct 23, 2026 8:00 AM")
        self.assertEqual(
            lf.format_instant(instant, "zh-CN", "America/New_York"),
            "2026-10-23 08:00:00")
        winter = lf.utc(2026, 1, 15, 12, 0, 0)
        self.assertEqual(
            lf.format_instant(winter, "en-US", "America/New_York"),
            "Jan 15, 2026 7:00 AM")
        with self.assertRaises(ValueError):
            lf.format_instant(datetime(2026, 10, 23, 12, 0, 0), "en", "Asia/Shanghai")


class ReleaseLockTests(unittest.TestCase):
    def test_version_and_gates_stay_off(self):
        self.assertEqual(lf.APP_VERSION, "0.1.0")
        self.assertEqual(lf.APP_BUILD, "1")
        self.assertFalse(lf.PASSWORD_LOGIN_ENABLED)
        self.assertFalse(lf.BANK_CARD_WITHDRAWAL_ENABLED)
        self.assertFalse(lf.VIRTUAL_GOODS_ENABLED)
        base = (ROOT / "Config/Base.xcconfig").read_text()
        self.assertIn("MARKETING_VERSION = 0.1.0\n", base)
        self.assertIn("CURRENT_PROJECT_VERSION = 1\n", base)
        session = (ROOT / "App/AppSession.swift").read_text()
        password = session.split("var canUsePassword:Bool {", 1)[1].split("var supportsDomesticPhoneInput", 1)[0]
        self.assertIn("#else", password)
        self.assertIn("false", password)
        self.assertIn("func makeBankWithdrawalContext() -> BankWithdrawalRuntimeContext?", session)
        self.assertIn("factory.permits(.bankPrepare)", session)
        visibility = (ROOT / "Core/WalletCommerceSafety.swift").read_text()
        self.assertIn("public var mall = false", visibility)
        host = (ROOT / "App/SessionWalletCommerceView.swift").read_text()
        self.assertIn("points/mall remain false", host)

    def test_us_production_profile_has_no_invented_host(self):
        profile = (ROOT / "Config/UnitedStates.Production.xcconfig").read_text()
        self.assertIn("QUESTIFY_API_BASE_URL =\n", profile)
        self.assertNotIn("https://", profile)
        self.assertNotIn("47.103.124.64", profile)
        regional = (ROOT / "Core/RegionalConfiguration.swift").read_text()
        self.assertIn('chinaProductionBaseURL = "https://www.chengyinhub.com/prod-api/"', regional)
        self.assertNotIn("https://us.", regional)
        merchant = (ROOT / "Core/MerchantContracts.swift").read_text()
        self.assertIn('guard let raw else { return "—" }', merchant)

    def test_shipped_plural_selectors_were_not_rewritten(self):
        club = (ROOT / "App/ClubComponents.swift").read_text()
        self.assertIn("if count == 1 {", club)
        wallet = (ROOT / "App/WalletNumberLocalization.swift").read_text()
        self.assertIn("value?.value == 1 || value?.value == -1", wallet)
        self.assertNotIn("locale_formats", club)
        self.assertNotIn("locale_formats", wallet)


if __name__ == "__main__":
    unittest.main()
