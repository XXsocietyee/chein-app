"""Function audit 11-28 P1-17 / P1-21 (mp-roam): source wiring checks only; Apple runtime tests remain unrun."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]


class RoamAuditLocationMapsChecks(unittest.TestCase):
    def read(self, name): return (ROOT / 'App' / name).read_text(encoding='utf-8')

    def test_map_home_locates_with_the_device_like_mp_enable_entry_location(self):
        # MP pages/roam/index.js enableEntryLocation: wx.getLocation gcj02 → center → _loadEntryMap.
        locate = self.read('AppSessionRoamLocate.swift')
        self.assertIn('RoamDeviceFixGCJ.currentGCJ02Fix(provider: RuntimeNativeLocationProvider(enabled: true))', locate)
        self.assertIn('roamArea = area', locate)
        self.assertIn('locateArea: { try await session.locateRoamArea() }', self.read('QuestifyApp.swift'))
        sheet = self.read('NativeR2/MapHome/RoamMapHomeSheet.swift')
        self.assertIn('"roam.mapHome.locate"', sheet)
        self.assertIn('CYBusyLabel(busy: locating) { Text("nativeR2.city.enableLocation") }', sheet)
        # _syncRoamPermission on onShow: re-read the status when returning from Settings.
        self.assertIn('if phase == .active { Task { await syncLocation(automatic: true) } }', sheet)

    def test_session_supplies_the_apple_maps_driver(self):
        # MP roam-place-card / utils/open-address.js wx.openLocation: 导航 must not stay hidden in Release.
        self.assertIn('PlatformConsumerSessionOwner(maps: PlatformConsumerSessionOwner.appleMaps)', self.read('AppSession.swift'))
        owner = self.read('PlatformConsumerSessionOwner.swift')
        self.assertIn('PlatformExternalMaps(opener: NativePlatformMapOpener(), copier: NativePlatformAddressCopier(), enabled: true)', owner)

    def test_guest_go_signs_in_then_starts_like_mp_go_start(self):
        # MP pages/roam/index.js goStart: guest → app.requireLogin({ reason: 'roam' }) → goStart() again.
        self.assertIn('signInToStart: session.account == nil ? { resume in requestSignIn(then: resume) } : nil',
                      self.read('QuestifyApp.swift'))
        sheet = self.read('NativeR2/MapHome/RoamMapHomeSheet.swift')
        self.assertIn('Button("nativeR2.mapHome.start.action", action: startRoam)', sheet)
        self.assertIn('if let gate = dependencies.signInToStart { gate { model.showsLive = true } }', sheet)
    def test_empty_official_routes_offer_back_to_map(self):
        # Coordinator 07:05: r3-roam-routes-empty needs a next step (MP goBack → pages/roam/index).
        routes = self.read('NativeR2/MapHome/RoamMapHomeRoutes.swift')
        self.assertIn('Button("roamSub.w208.poi.backToMap") { dismiss() }', routes)

    def test_live_lease_carries_presence_like_mp_report_presence(self):
        # P1-18: MP _reportPresence POST /api/roam/presence {sessionId, lat, lng, explorePct}, after the separate consent.
        leases = self.read('ReviewedPlayerWriteLeases.swift')
        self.assertIn('RoamLiveApproval.requiredPaths.union(["api/roam/presence"])', leases)
        self.assertIn('RoamLiveApproval(endpoints: endpoints, foregroundLocation: true, presence: true)', leases)
        controller = (ROOT / 'Core' / 'RoamLiveSessionController.swift').read_text(encoding='utf-8')
        self.assertIn('presenceAccepted: Bool = false', controller)
        self.assertIn('presenceEnabled = visible && presenceAvailable', controller)
        fields = (ROOT / 'Core' / 'RoamExperienceMutationContracts.swift').read_text(encoding='utf-8')
        self.assertIn('["sessionId": String(id), "explorePct": String(percent)]', fields)

    def test_personal_location_share_entries_hide_while_off(self):
        # P1-24: no MP page; approvals are never installed, so the Settings / profile rows must not show.
        host = self.read('PersonalLocationShareHost.swift')
        self.assertIn('var isOffered: Bool { readApproval() != nil && baseURL() != nil }', host)
        self.assertIn('if let host, host.isOffered {', host)
        self.assertIn('PersonalLocationShareOfferedLink(recipientId: nil', self.read('SettingsView.swift'))
        self.assertIn('PersonalLocationShareOfferedLink(recipientId: Int64(memberID)', self.read('SocialPublicProfileView.swift'))


if __name__ == '__main__':
    unittest.main()
