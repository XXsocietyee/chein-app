#!/usr/bin/env python3
"""Fail when a log call in App/ or Core/ interpolates a sensitive field.

A sensitive field is a phone number, an OpenID, a token, or a street address.
The identifier has to be an argument of LogFieldRedaction.redacted, not text
inside the string passed to print, os_log, Logger, or NSLog. A log that does
not mention those fields is left alone. This does not compile Swift.

usage: python3 -B tools/check_log_redaction.py
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIRS = ('App', 'Core')
# Same names as Core/LogFieldRedaction.fieldNames, plus the camelCase spellings
# a Swift identifier can use. A longer name is its own identifier, so `token`
# does not match `accessToken`.
FIELDS = {
    'phone', 'phoneNumber', 'mobile', 'mobilePhone', 'telephone',
    'openId', 'openID', 'openid', 'open_id', 'wechatOpenId', 'wxOpenId',
    'unionId', 'unionid', 'unionID',
    'token', 'accessToken', 'access_token', 'refreshToken', 'refresh_token',
    'sessionToken', 'authToken', 'idToken', 'bearerToken', 'shareToken',
    'street', 'streetAddress', 'street_address', 'addressLine', 'address_line',
    'detailAddress', 'fullAddress', 'address',
}
LOG_WORDS = {'print', 'NSLog', 'os_log'}
LOGGER_RECEIVERS = {'logger', 'osLog'}
LOGGER_METHODS = {'debug', 'info', 'notice', 'warning', 'error', 'fault', 'critical', 'log'}


def scan(root=ROOT):
    """Return (path, line, field) for each unredacted field in a log call."""
    findings = []
    base = pathlib.Path(root)
    for directory in DIRS:
        folder = base / directory
        if not folder.is_dir():
            continue
        for path in sorted(folder.rglob('*.swift')):
            text = path.read_text(encoding='utf-8', errors='replace')
            relative = path.relative_to(base).as_posix()
            for index, field in fields_in_logs(text):
                line = text.count('\n', 0, index) + 1
                findings.append((relative, line, field))
    return findings


def fields_in_logs(text):
    walker = _Walker(text)
    walker.walk_code(0, len(text), [], False)
    return walker.findings


class _Walker:
    def __init__(self, text):
        self.text = text
        self.n = len(text)
        self.findings = []

    def walk_code(self, i, end, stack, logging):
        text = self.text
        while i < end:
            start = i
            c = text[i]
            if c.isspace():
                i += 1
            elif text.startswith('//', i):
                newline = text.find('\n', i)
                i = end if newline < 0 else newline + 1
            elif text.startswith('/*', i):
                close = text.find('*/', i + 2)
                i = end if close < 0 else close + 2
            elif c == '"' or c == '#':
                hashed = self._string_hashes(i)
                if hashed is None:
                    i += 1
                else:
                    i = self._walk_string(i, end, stack, hashed, logging)
            elif c == ')':
                return i
            elif c == '(':
                stack.append('call')
                i = self.walk_code(i + 1, end, stack, logging)
                if i < end and text[i] == ')':
                    i += 1
                stack.pop()
            elif c.isalpha() or c == '_':
                j = i + 1
                while j < end and (text[j].isalnum() or text[j] == '_'):
                    j += 1
                word = text[i:j]
                k = self._skip_space(j, end)
                if word in LOG_WORDS and k < end and text[k] == '(':
                    i = self._log_call(k, end)
                elif word in LOGGER_RECEIVERS and k < end and text[k] == '.':
                    method, paren = self._method_call(k + 1, end)
                    if method in LOGGER_METHODS and paren is not None:
                        i = self._log_call(paren, end)
                    else:
                        i = j
                elif word == 'Logger':
                    i = self._logger_value(j, end)
                elif k < end and text[k] == '(':
                    stack.append('redacted' if self._is_redacted_call(i) else 'call')
                    i = self.walk_code(k + 1, end, stack, logging)
                    if i < end and text[i] == ')':
                        i += 1
                    stack.pop()
                else:
                    if logging and word in FIELDS and not self._covered(stack):
                        self.findings.append((i, word))
                    i = j
            else:
                i += 1
            if i == start:
                i += 1
        return i

    def _log_call(self, open_paren, end):
        """Scan one log call's arguments. Sensitive fields start uncovered."""
        inner = self.walk_code(open_paren + 1, end, [], True)
        if inner < end and self.text[inner] == ')':
            return inner + 1
        return inner

    def _logger_value(self, after_ident, end):
        text = self.text
        k = self._skip_space(after_ident, end)
        i = after_ident
        if k < end and text[k] == '(':
            stack = ['call']
            i = self.walk_code(k + 1, end, stack, False)
            if i < end and text[i] == ')':
                i += 1
            stack.pop()
        k = self._skip_space(i, end)
        if k < end and text[k] == '.':
            method, paren = self._method_call(k + 1, end)
            if method in LOGGER_METHODS and paren is not None:
                return self._log_call(paren, end)
        return after_ident

    def _method_call(self, i, end):
        text = self.text
        i = self._skip_space(i, end)
        if i >= end or not (text[i].isalpha() or text[i] == '_'):
            return None, None
        j = i + 1
        while j < end and (text[j].isalnum() or text[j] == '_'):
            j += 1
        k = self._skip_space(j, end)
        if k < end and text[k] == '(':
            return text[i:j], k
        return None, None

    def _walk_string(self, start, end, stack, hashes, logging):
        text = self.text
        i = start + hashes
        triple = text.startswith('"""', i)
        i += 3 if triple else 1
        stack.append('string')
        closer = ('"""' if triple else '"') + ('#' * hashes)
        while i < end:
            if hashes == 0 and text.startswith('\\(', i):
                i = self.walk_code(i + 2, end, stack, logging)
                if i < end and text[i] == ')':
                    i += 1
                continue
            if hashes and text.startswith('\\' + ('#' * hashes) + '(', i):
                i = self.walk_code(i + 1 + hashes + 1, end, stack, logging)
                if i < end and text[i] == ')':
                    i += 1
                continue
            if hashes == 0 and text[i] == '\\':
                i += 2 if i + 1 < end else 1
                continue
            if text.startswith(closer, i):
                stack.pop()
                return i + len(closer)
            i += 1
        if stack and stack[-1] == 'string':
            stack.pop()
        return i

    def _string_hashes(self, i):
        text = self.text
        hashes = 0
        while i + hashes < self.n and text[i + hashes] == '#':
            hashes += 1
        if i + hashes < self.n and text[i + hashes] == '"':
            return hashes
        return None

    def _is_redacted_call(self, ident):
        if self.text[ident:ident + len('redacted')] != 'redacted':
            return False
        i = ident - 1
        while i >= 0 and self.text[i].isspace():
            i -= 1
        if i < 0 or self.text[i] != '.':
            return False
        i -= 1
        while i >= 0 and self.text[i].isspace():
            i -= 1
        end = i + 1
        while i >= 0 and (self.text[i].isalnum() or self.text[i] == '_'):
            i -= 1
        return self.text[i + 1:end] == 'LogFieldRedaction'

    def _covered(self, stack):
        for frame in reversed(stack):
            if frame == 'string':
                return False
            if frame == 'redacted':
                return True
        return False

    def _skip_space(self, i, end):
        while i < end and self.text[i].isspace():
            i += 1
        return i


def main(argv=None):
    findings = scan(ROOT)
    if findings:
        print('Log redaction check failed:')
        for path, line, field in findings:
            print(f' - {path}:{line}: log interpolates {field} without LogFieldRedaction.redacted')
        return 1
    print(f'PASS log redaction: App/ and Core/ log calls do not interpolate phone, OpenID, token, or street fields raw ({len(findings)} findings)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
