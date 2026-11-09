"""CB49 locale display rules for dates, numbers, currency, and plurals.

Display locale and operational market are independent. Formatting USD does not
select a backend. The US market has no reviewed API host; this module does not
invent one and does not open a socket.

Unknown amounts render as an em dash. A known zero stays zero. Currency comes
only from an explicit code, never from the UI locale, and amounts are never
converted between CNY and USD.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from zoneinfo import ZoneInfo
import re

EM_DASH = "\u2014"
APP_VERSION = "0.1.0"
APP_BUILD = "1"
PASSWORD_LOGIN_ENABLED = False
BANK_CARD_WITHDRAWAL_ENABLED = False
VIRTUAL_GOODS_ENABLED = False
US_BACKEND_ENABLED = False

# Reviewed China host already named by ReviewedMarketLaunch. Not a US host.
CN_API_HOST = "https://www.chengyinhub.com/prod-api/"

_MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
_CANONICAL = re.compile(r"^[+-]?(0|[1-9][0-9]*)(\.[0-9]+)?$")
_MINUS = "\u2212"
_UNKNOWN_WORDS = {"unknown", "nan", "null", "none", "-", "--", EM_DASH, "\u2013"}
_CIVIL_DATE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")
_CIVIL_CLOCK = re.compile(r"^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$")
_CURRENCY_SYMBOLS = {"CNY": "¥", "USD": "$"}


def normalize_locale(locale: str) -> str:
    """Map the app's stored tags onto the two display locales. Anything else fails closed."""
    token = locale.strip().replace("_", "-")
    if not token:
        raise ValueError("locale is required")
    primary = token.split("-", 1)[0].lower()
    if primary == "zh":
        return "zh-Hans"
    if primary == "en":
        return "en"
    raise ValueError("unsupported locale: " + locale)


def api_host(market: str) -> str | None:
    """Reviewed API host for an operational market. US stays unset."""
    if market == "CN":
        return CN_API_HOST
    if market == "US":
        return None
    raise ValueError("unsupported market: " + market)


def separators(locale: str) -> tuple[str, str]:
    """Grouping mark, then decimal mark. zh-Hans and en share CLDR zh/en-US marks."""
    normalize_locale(locale)
    return ",", "."


def _split_canonical(source: str) -> tuple[str, str, str | None] | None:
    text = source.strip().replace(_MINUS, "-")
    if not _CANONICAL.fullmatch(text):
        return None
    sign = "-" if text.startswith("-") else ""
    body = text[1:] if text[0] in "+-" else text
    whole, dot, frac = body.partition(".")
    return sign, whole, frac if dot else None


def format_number(source: str, locale: str) -> str:
    """Group a canonical decimal. A non-canonical source is returned unchanged."""
    grouping, decimal_mark = separators(locale)
    parts = _split_canonical(source)
    if parts is None:
        return source
    sign, whole, frac = parts
    pieces = []
    rest = whole
    while rest:
        pieces.append(rest[-3:])
        rest = rest[:-3]
    grouped = grouping.join(reversed(pieces))
    if frac is None:
        return sign + grouped
    return sign + grouped + decimal_mark + frac


def _known_amount_text(amount) -> str | None:
    if isinstance(amount, bool) or isinstance(amount, float):
        return None
    if isinstance(amount, int):
        return str(amount)
    if isinstance(amount, Decimal):
        if not amount.is_finite():
            return None
        return format(amount, "f")
    if not isinstance(amount, str):
        return None
    text = amount.strip().replace(_MINUS, "-")
    if text == "" or text.lower() in _UNKNOWN_WORDS:
        return None
    return text


def _money_decimal(amount) -> Decimal | None:
    text = _known_amount_text(amount)
    if text is None:
        return None
    parts = _split_canonical(text)
    if parts is None:
        return None
    try:
        value = Decimal(text[1:] if text.startswith("+") else text)
    except InvalidOperation:
        return None
    if not value.is_finite():
        return None
    return value


def format_money(amount, currency: str | None, locale: str) -> str:
    """Format an explicit CNY or USD amount. Unknown amounts are an em dash, never 0."""
    normalize_locale(locale)
    value = _money_decimal(amount)
    if value is None:
        return EM_DASH
    quantized = value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    sign = "-" if quantized < 0 else ""
    body = format(abs(quantized), "f")
    number = format_number(sign + body, locale)
    code = (currency or "").strip().upper()
    if code == "":
        return number
    symbol = _CURRENCY_SYMBOLS.get(code)
    if symbol is not None:
        return sign + symbol + number[len(sign):]
    return number + " " + code


def format_fen(fen: int | None, currency: str | None, locale: str) -> str:
    """Integer fen to a currency string. None is unknown. Zero fen is a known zero."""
    if fen is None:
        return EM_DASH
    if isinstance(fen, bool) or not isinstance(fen, int):
        return EM_DASH
    sign = "-" if fen < 0 else ""
    yuan, rem = divmod(abs(fen), 100)
    return format_money(f"{sign}{yuan}.{rem:02d}", currency, locale)


def plural_category(locale: str, amount) -> str:
    """English one is an integer whose absolute value is 1. Chinese is always other."""
    language = normalize_locale(locale)
    if language == "zh-Hans":
        return "other"
    text = _known_amount_text(amount)
    if text is None:
        raise ValueError("plural count is not a canonical number")
    parts = _split_canonical(text)
    if parts is None or parts[2] is not None:
        if parts is None:
            raise ValueError("plural count is not a canonical number")
        return "other"
    return "one" if parts[1] == "1" else "other"


def format_count(locale: str, amount, forms: dict) -> str:
    """Fill `{n}` from the locale's plural category. Chinese never reads `one`."""
    language = normalize_locale(locale)
    category = plural_category(locale, amount)
    if language == "zh-Hans":
        template = forms.get("other")
        if not template:
            raise ValueError("zh-Hans plural requires other")
    else:
        template = forms.get(category) or forms.get("other")
        if not template:
            raise ValueError("en plural requires one or other")
    text = _known_amount_text(amount)
    if text is None or _split_canonical(text) is None:
        raise ValueError("plural count is not a canonical number")
    shown = format_number(text[1:] if text.startswith("+") else text.replace(_MINUS, "-"), locale)
    return template.replace("{n}", shown)


def _valid_civil(year: int, month: int, day: int, hour: int = 0, minute: int = 0, second: int = 0) -> bool:
    if not (1 <= month <= 12 and 0 <= hour <= 23 and 0 <= minute <= 59 and 0 <= second <= 59):
        return False
    try:
        datetime(year, month, day)
    except ValueError:
        return False
    return True


def format_civil_date(source: str, locale: str) -> str:
    """Date-only civil text. Invalid input stays verbatim and is not shifted."""
    language = normalize_locale(locale)
    match = _CIVIL_DATE.fullmatch(source)
    if match is None:
        return source
    year, month, day = (int(match.group(i)) for i in (1, 2, 3))
    if not _valid_civil(year, month, day):
        return source
    if language == "zh-Hans":
        return f"{year}年{month}月{day}日"
    return f"{_MONTHS[month - 1]} {day}, {year}"


def _clock(hour: int, minute: int, second: int, language: str, year: int, month: int, day: int) -> str:
    if language == "zh-Hans":
        return f"{year:04d}-{month:02d}-{day:02d} {hour:02d}:{minute:02d}:{second:02d}"
    suffix = "AM" if hour < 12 else "PM"
    hour12 = hour % 12 or 12
    return f"{_MONTHS[month - 1]} {day}, {year} {hour12}:{minute:02d} {suffix}"


def format_civil_clock(source: str, locale: str) -> str:
    """A zone-less civil clock. The wall time is not converted."""
    language = normalize_locale(locale)
    match = _CIVIL_CLOCK.fullmatch(source)
    if match is None:
        return source
    year, month, day, hour, minute, second = (int(match.group(i)) for i in range(1, 7))
    if not _valid_civil(year, month, day, hour, minute, second):
        return source
    return _clock(hour, minute, second, language, year, month, day)


def format_instant(instant: datetime, locale: str, zone: str) -> str:
    """Format an aware instant in an explicit zone. A naive datetime is refused."""
    language = normalize_locale(locale)
    if instant.tzinfo is None or instant.tzinfo.utcoffset(instant) is None:
        raise ValueError("instant requires a timezone")
    local = instant.astimezone(ZoneInfo(zone))
    return _clock(local.hour, local.minute, local.second, language, local.year, local.month, local.day)


def utc(year: int, month: int, day: int, hour: int = 0, minute: int = 0, second: int = 0) -> datetime:
    return datetime(year, month, day, hour, minute, second, tzinfo=timezone.utc)
