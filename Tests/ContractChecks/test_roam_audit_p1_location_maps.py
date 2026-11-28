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


if __name__ == '__main__':
    unittest.main()
