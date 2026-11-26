"""ROAM-7 source pins. These do not execute Swift or claim a parse."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class RoamEntryNearbyProductionChecks(unittest.TestCase):
    def test_production_gates_lease_both_reads_and_admit_a_guest_entry_get(self):
        root = (ROOT / 'App/AppCompositionRoot.swift').read_text()
        self.assertIn(
            'roamNearbyPlayersReadAccess(context) ?? (productionGatesEnabled ? gates.roamNearbyPlayers(context) : nil)',
            root)
        self.assertIn(
            'roamEntryNearbyReadAccess(context) ?? (productionGatesEnabled ? gates.roamEntryNearby(context) : nil)',
            root)
        players = root[root.index('} else if nearbyPlayers != nil'):root.index('} else if entryNearby != nil')]
        self.assertIn('captured.isSignedInContentViewer', players)
        entry = root[root.index('} else if entryNearby != nil'):root.index('} else if receivedStamp != nil')]
        self.assertIn('guestEntryRead', entry)
        self.assertIn('captured.accountID == nil && captured.isPublicTemplateViewer', entry)
        self.assertIn('request.value(forHTTPHeaderField: "Authorization") == nil', entry)
        leases = (ROOT / 'App/ReviewedPlayerWriteLeases.swift').read_text()
        self.assertIn('paths: [RoamEntryNearbyRoute.path]', leases)
        self.assertIn('paths: [RoamNearbyPlayersReadRoute.path]', leases)
        reader = (ROOT / 'Core/RoamEntryNearby.swift').read_text()
        self.assertIn('func publicRequest(baseURL: URL, area: RoamSearchArea)', reader)
        self.assertIn('setValue(nil, forHTTPHeaderField: "Authorization")', reader)
        self.assertIn('return try await publicEntry()', reader)

    def test_money_sends_stay_off(self):
        journey = (ROOT / 'Core/JourneyLoopSource.swift').read_text()
        claim = journey[journey.index('func giftClaim(token credential:'):journey.index('// MARK: Seat writes')]
        self.assertIn('throw JourneyRefusal.moneyOff', claim)
        self.assertNotIn('transport', claim)
        self.assertNotIn('.send(', claim)
        gate = (ROOT / 'Core/PlayGameStage.swift').read_text()
        analytics = gate[gate.index('public enum PlayStageAnalyticsGate'):gate.index('public enum PlayStageAnalyticsGate') + 240]
        self.assertIn('enabled: Bool { false }', analytics)
        passes = (ROOT / 'Core/PlatformPass.swift').read_text()
        self.assertGreaterEqual(passes.count('throw PlatformPassWriteRefusal.unreachable'), 3)
