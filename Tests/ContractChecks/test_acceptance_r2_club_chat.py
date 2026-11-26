"""Acceptance R2 F-08..F-10 source contracts (club leave confirmation, club chat send, composer
keyboard). These do not compile Swift; the behaviour tests are in
Tests/AppUnitTests/AcceptanceR2ClubChatComposerTests.swift."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


def strip_comments(text):
    return re.sub(r'//[^\n]*', '', text)


class AcceptanceR2ClubLeaveConfirmation(unittest.TestCase):
    """F-08: 退出俱乐部 must open `club.action.confirm`."""

    def setUp(self):
        self.source = strip_comments(read('App/ClubActionPanel.swift'))
        body = self.source.split('var body: some View {', 1)[1]
        self.body = body.split('private var confirmationPresented', 1)[0]

    def test_no_presenter_or_lifecycle_modifier_on_the_section(self):
        # Modifiers on a List Section apply to every row: the transient progress row's
        # onDisappear reset the confirmation before it could present.
        after_section = self.body.split('} header: {', 1)[1]
        header, tail = after_section.split('\n        }\n', 1)
        for modifier in ['.cySheet(', '.onDisappear', '.onChange(', '.confirmationDialog(']:
            self.assertNotIn(modifier, tail, modifier)
        self.assertIn('.onDisappear { reset() }', header)
        self.assertIn('.onChange(of: identity) { _, _ in reset() }', header)

    def test_single_confirmation_sheet_on_membership_button(self):
        # One presenter per placement: the header placement's membership row, and (design r1 MC-20)
        # the single page-end row. The two placements are exclusive branches of one panel instance.
        self.assertEqual(self.source.count('.cySheet('), 2)
        page_end = self.source.split('private var pageEndSection', 1)[1].split('private func membershipButton', 1)[0]
        self.assertIn('.cySheet(isPresented: confirmationPresented) { confirmationSheet }', page_end)
        self.assertIn('.onDisappear { reset() }', page_end)
        self.assertNotIn('ProgressView', page_end)
        self.assertIn('membershipButton(action, state: state)\n'
                      '                                .cySheet(isPresented: confirmationPresented) { confirmationSheet }',
                      self.source)
        self.assertIn('confirmIdentifier: "club.action.confirm"', self.source)
        self.assertIn('{ submit(value) }', self.source)
        self.assertIn('set: { if !$0 { cancelConfirmation() } }', self.source)
        self.assertIn('ProgressView("club.action.working")', self.body)


class AcceptanceR2ClubChatSend(unittest.TestCase):
    """F-09: the club chat history keeps one reader, so it does not restart its read on re-render."""

    def test_club_chat_history_uses_retained_reader(self):
        source = strip_comments(read('App/ClubChatEntryView.swift'))
        self.assertIn('@StateObject private var readerOwner = SessionMessagingHomeReaderOwner()', source)
        self.assertIn('reader: readerOwner.reader(for: session)', source)
        self.assertNotIn('reader: session.messagingReader', source)

    def test_typing_is_not_gated_on_history_load(self):
        source = read('App/MessageActionComposer.swift')
        self.assertIn('.focused($typing).disabled(!model.acceptsTyping)', source)
        accepts = source.split('var acceptsTyping: Bool {', 1)[1].split('}', 1)[0]
        for gate in ['conversationReady', 'canReply', 'typing']:
            self.assertNotIn(gate, accepts)
        # Send still requires the loaded history and the reply lease.
        self.assertIn('.disabled(!canCompose || draftIsEmpty)', source)
        self.assertIn('private var ready:Bool { conversationReady && canReply()', source)
        self.assertIn('accessibilityIdentifier("message.send.receipt")', source)


class AcceptanceR2ComposerKeyboard(unittest.TestCase):
    """F-10: no keyboard pill over Send; the composer rides above the keyboard."""

    def test_composer_has_no_keyboard_toolbar(self):
        source = strip_comments(read('App/MessageActionComposer.swift'))
        self.assertNotIn('placement: .keyboard', source)
        self.assertNotIn('placement:.keyboard', source)
        self.assertNotIn('message.send.keyboard.done', source)
        self.assertNotIn('onTapGesture', source)
        send = source.split('accessibilityIdentifier("message.send.input")', 1)[1].split('accessibilityIdentifier("message.send.button")', 1)[0]
        self.assertNotIn('typing', send.split('.disabled(', 1)[1].split(')', 1)[0])

    def test_history_pins_composer_with_bottom_safe_area_inset(self):
        source = strip_comments(read('App/MessagingHistoryView.swift'))
        inset = source.split('.safeAreaInset(edge:.bottom) {', 1)[1].split('.cySheet(isPresented: $showingPollComposer)', 1)[0]
        self.assertIn('MessageActionComposer(', inset)
        self.assertIn('.scrollDismissesKeyboard(.interactively)', source)
        self.assertNotIn('onTapGesture', source.split('private var transcript', 1)[1].split('private func reload', 1)[0])


if __name__ == '__main__':
    unittest.main()
