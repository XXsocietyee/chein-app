"""Source contracts only; Swift/Apple navigation and runtime tests are separate."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class TicketWalletPlayEntryContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.account = (ROOT / 'App/AccountView.swift').read_text()
        cls.detail = (ROOT / 'App/TicketWalletDetailView.swift').read_text()
        cls.screen = cls.detail.split('private struct TicketWalletPlayLoadKey:', 1)[0]
        cls.provider = cls.detail.split('struct TicketWalletPlayProvider {', 1)[1].split('@MainActor struct TicketWalletPlayEntry', 1)[0]
        cls.entry = cls.detail.split('@MainActor struct TicketWalletPlayEntry {', 1)[1].split('private struct TicketWalletDetailHeader', 1)[0]

    def test_provider_is_opt_in_and_only_injected_into_account_wallet_sheet(self):
        self.assertIn('static let defaultValue: TicketWalletPlayProvider? = nil', self.detail)
        line = next(line for line in self.account.splitlines() if '.cySheet(isPresented:$showsTickets)' in line)
        self.assertIn('.environment(\\.ticketWalletPlayProvider, ticketPlayProvider)', line)
        self.assertIn('TicketWalletPlayProvider(reader: session.ticketWalletReader, revision: session.sessionRevision', self.account)
        self.assertIn('currentRevision: { session.sessionRevision }', self.account)
        # PLY-21-3: the pass sheet gets the same provider, and every other wallet entry uses SessionTicketWalletHost.
        self.assertEqual(self.account.count('.environment(\\.ticketWalletPlayProvider, ticketPlayProvider)'), 2)
        host = (ROOT / 'App/SessionTicketWalletHost.swift').read_text()
        self.assertIn('.environment(\\.ticketWalletPlayProvider, SessionTicketWalletProviders.play(session))', host)
        self.assertIn('currentRevision: { session.sessionRevision }', host)

    def test_existing_generic_runtime_and_registration_toolbar_are_preserved(self):
        self.assertIn('SessionPlayRuntimeView(session: session, destination: .journey(entry.scope))', self.account)
        self.assertIn('TicketWalletDetailView(id: entry.registrationID, reader: session.ticketWalletReader)', self.account)
        self.assertIn('.environment(\\.ticketWalletPlayProvider, nil)', self.account)
        self.assertNotIn('destination: .prefab', self.account)

    def test_fresh_detail_success_is_required_before_button_or_destination(self):
        self.assertIn('else if let ticket = model.value(owner: key), ticket.id == id {', self.screen)
        self.assertEqual(self.screen.count('playReadOwner == playProvider.owner'), 3)
        self.assertIn('guard !model.isLoading, model.value(owner: key) == ticket,', self.screen)
        self.assertIn('playEntry.retire()\n        playReadOwner = nil', self.screen)
        self.assertIn('await model.load(presentation: presentation, currentOwner: { key }) { try await reader.ticketDetail(id: id) }', self.screen)
        self.assertIn('if !Task.isCancelled, model.accepts(presentation, currentOwner: key),', self.screen)
        self.assertIn('let provider, provider.owner == playProvider?.owner, provider.matches(reader: reader),', self.screen)
        self.assertIn('model.value(owner: captured)?.id == id, captured == key', self.screen)

    def test_positive_exact_registration_and_known_ready_status_only(self):
        self.assertIn('requestedID > 0, ticket.id == requestedID, ticket.registrationStatus == 2', self.entry)
        self.assertIn('ticket.isWalletUsable, !ticket.isWalletLocked', self.entry)
        self.assertIn('let ownerID = ticket.ownerID, ownerID > 0', self.entry)
        self.assertIn('ParticipationPlayEntry(registrationID: requestedID, scope: scope)', self.entry)
        for forbidden in ['ticket.status', 'ticket.title', 'ticket.productType', 'cmsTopic', 'cmsActivity']:
            self.assertNotIn(forbidden, self.entry)

    def test_owner_type_routes_are_explicit_and_conflicting_ids_are_rejected(self):
        for token in ['switch ticket.ownerType', 'case 1:', 'ticket.activityID == nil, ticket.topicID == nil || ticket.topicID == ownerID', 'scope = .topic(ownerID)', 'case 2:', 'ticket.topicID == nil, ticket.activityID == nil || ticket.activityID == ownerID', 'scope = .activity(ownerID)', 'default: return nil']:
            self.assertIn(token, self.entry)

    def test_provider_matches_actual_reader_scope_and_live_session_revision(self):
        for token in ['readerID = ObjectIdentifier(reader)', 'scope = reader.scope', 'self.revision = revision']:
            self.assertIn(token, self.detail)
        for token in ['reader.isConfigured && reader.isAuthenticated', 'owner == TicketWalletPlayOwner(reader: reader, revision: currentRevision())', 'guard owner == target.owner, matches(reader: reader) else { return nil }']:
            self.assertIn(token, self.provider)

    def test_destination_builder_runs_only_after_selected_navigation_checks(self):
        self.assertEqual(self.screen.count('playProvider.destination('), 1)
        nav = self.screen.split('.navigationDestination(item: $playEntry.target)', 1)[1]
        self.assertIn('playEntry.matches(target, ticket: ticket, requestedID: id, reader: reader, provider: playProvider)', nav)
        self.assertIn('let destination = playProvider.destination(target: target, reader: reader)', nav)
        self.assertEqual(self.provider.count('makeDestination(target.entry)'), 1)
        self.assertNotIn('makeDestination(', self.entry)

    def test_play_waits_for_this_detail_to_confirm_the_registration(self):
        button = self.screen.split('accessibilityIdentifier("ticketWallet.play.open")', 1)[0].split('Button {', 1)[1].split('} label:', 1)[0]
        self.assertNotIn('playEntry.activate', button)
        self.assertIn('let permit = model.presentation, model.accepts(permit, currentOwner: key)', button)
        self.assertIn('schedule(permit, confirmPlay: true)', button)
        load = self.screen.split('private func load(presentation:', 1)[1].split('private struct TicketWalletPlayLoadKey', 1)[0]
        self.assertLess(load.index('reader.ticketDetail(id: id)'), load.index('playEntry.activate'))
        self.assertLess(load.index('confirmPlay || (autoStartsPlay && !didAutoStart)'), load.index('playEntry.activate'))
        self.assertNotIn('api/registration/pay', self.detail)
        self.assertNotIn('api/registration/create', self.detail)
        self.assertNotIn('OrderLifecycleCoordinator(', self.detail)

    def test_stale_taps_duplicate_selection_and_changed_ticket_facts_are_rejected(self):
        for token in ['visible && target == nil && provider.matches(reader: reader)', 'self.presentationID == presentationID', 'self.target == target && target.owner == provider.owner', 'target.entry == Self.entry(ticket: ticket, requestedID: requestedID)', 'let id = UUID()']:
            self.assertIn(token, self.entry)
        self.assertIn('let presentationID = playEntry.presentationID', self.screen)

    def test_native_back_source_disappearance_and_reload_lifetimes_are_separate(self):
        disappear = self.entry.split('mutating func disappear() {', 1)[1].split('\n    }', 1)[0]
        self.assertIn('visible = false; presentationID = UUID()', disappear)
        self.assertNotIn('target = nil', disappear)
        self.assertIn('mutating func retire() { target = nil; presentationID = UUID() }', self.entry)
        for token in ['.onChange(of: playProvider?.owner)', '.onChange(of: ObjectIdentifier(reader))', '.onChange(of: key)', 'TicketWalletPlayLoadKey(readerID: ObjectIdentifier(reader), key: key, providerOwner: playProvider?.owner)']:
            self.assertIn(token, self.screen)

    def test_no_new_transport_permission_payment_or_runtime_factory(self):
        for forbidden in ['URLSession', 'api/', 'requestWhenInUseAuthorization', 'startSession(', 'PlayExperienceCoordinator(', 'OrderLifecycleCoordinator(', 'purchaseKind ==', 'hasPrefix(']:
            self.assertNotIn(forbidden, self.detail)
        self.assertIn('OrderLifecycleView(id: id, coordinator: lifecycleCoordinator)', self.screen)
        # The em-dash noCode placeholder is gone: the pass code is now only presented on explicit action for a ready ticket, via the injected factory.
        self.assertIn('if ticket.status == .ready && ticket.clearedFlag != true && !ticket.isWalletLocked {', self.screen)
        self.assertIn('.accessibilityIdentifier("ticketWallet.present.open")', self.screen)
        self.assertNotIn('ticketWallet.noCode', self.screen)
        self.assertIn('ticketWallet.party.share', self.screen)
        self.assertIn('ticketWallet.explore.redeemed', self.screen)
        self.assertIn('schedule(permit, confirmPlay: true)', self.screen)
        self.assertIn('allowsOwnerActions(ticket)', self.screen)


if __name__ == '__main__':
    unittest.main()
