"""IM recipient-preview leases (channels contract item 18, coordinator security review 2026-11-13).

Condition of the review: the `messageConversationID` an app call site passes to `IMPreviewTemplateLease.issue(...)`
must come from the server-provided message record (a decoded message's `conversationID`), never from UI selection,
a route, a deep link or other client input. Source guard only: it does not compile Swift.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
CLIENT_INPUT = re.compile(r'(route|link|deep|intent|selected|selection|input|text|field|query|param|binding|state)', re.I)


class IMPreviewLeaseConversationSource(unittest.TestCase):
    def call_sites(self):
        for path in (ROOT / 'App').rglob('*.swift'):
            if 'DesignFixtures' in path.parts:
                continue
            text = path.read_text(encoding='utf-8')
            for match in re.finditer(r'messageConversationID:\s*([^,)\n]+)', text):
                yield path.relative_to(ROOT), match.group(1).strip()

    def test_conversation_id_comes_from_a_server_message_record(self):
        offenders = []
        for path, argument in self.call_sites():
            from_record = re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*\.conversationID', argument)
            receiver = argument.rsplit('.conversationID', 1)[0]
            if not from_record or CLIENT_INPUT.search(receiver):
                offenders.append(f'{path}: messageConversationID: {argument}')
        self.assertEqual(offenders, [], 'pass the decoded server message\'s conversationID, never client input')

    def test_lease_refuses_a_message_from_another_conversation(self):
        source = (ROOT / 'Core/IMPreviewTemplateLease.swift').read_text(encoding='utf-8')
        self.assertIn('guard messageConversationID == conversationID, messageID > 0 else { return nil }', source)


if __name__ == '__main__':
    unittest.main()
