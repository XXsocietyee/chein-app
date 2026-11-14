"""The log-field lint fails when a log call interpolates a secret field."""
import os
import tempfile
import unittest

from tools import check_log_redaction as gate


class LogRedactionLintTests(unittest.TestCase):
    def findings(self, source, relative='App/Sample.swift'):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, relative)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(source)
            return gate.scan(root)

    def test_raw_interpolation_fails(self):
        found = self.findings('print("id=\\(token)")\n')
        self.assertEqual(found, [('App/Sample.swift', 1, 'token')])

    def test_direct_redaction_passes(self):
        source = 'print(LogFieldRedaction.redacted(token))\nNSLog("%@", LogFieldRedaction.redacted(user.phone))\n'
        self.assertEqual(self.findings(source), [])

    def test_redaction_inside_interpolation_passes(self):
        source = 'print("\\(LogFieldRedaction.redacted(openId))")\n'
        self.assertEqual(self.findings(source), [])

    def test_secret_inside_redacted_string_still_fails(self):
        source = 'print(LogFieldRedaction.redacted("\\(streetAddress)"))\n'
        self.assertEqual(found_fields(self.findings(source)), ['streetAddress'])

    def test_logger_and_os_log_are_calls(self):
        source = (
            'logger.error("\\(accessToken)")\n'
            'Logger(subsystem: "q", category: "q").info("\\(address)")\n'
            'os_log("%@", log, shareToken)\n'
        )
        self.assertEqual(found_fields(self.findings(source)), ['accessToken', 'address', 'shareToken'])

    def test_word_inside_a_string_or_comment_is_not_a_field(self):
        source = 'print("token")\n// print(token)\nlet raw = #"print(phone)"#\n'
        self.assertEqual(self.findings(source), [])

    def test_unrelated_call_is_not_a_log(self):
        source = 'save(token: token)\nerror(phone)\n'
        self.assertEqual(self.findings(source), [])

    def test_repository_logs_are_clean(self):
        self.assertEqual(gate.scan(), [])


def found_fields(findings):
    return [field for _, _, field in findings]


if __name__ == '__main__':
    unittest.main()
