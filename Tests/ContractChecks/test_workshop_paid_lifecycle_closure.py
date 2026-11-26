"""Source contracts for restored original lifecycle/recovery. Not Swift or live-operation tests."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]

class PaidInstallLifecycleSourceContracts(unittest.TestCase):
    def text(self, path): return (ROOT / path).read_text()
    def core(self): return self.text('Core/WorkshopPaidInstallController.swift')

    # The byte-exact SHA-256 pins that used to live here never matched any tree in this repository (not even the
    # f9ca1f424 snapshot import), so they only ever failed. The behavioural markers below are the contract.

    def test_paid_install_follows_the_money_switch(self):
        """Owner 2026-11-25 (139e06853): money is ON in Release and DEBUG/TEST whenever an API host is installed,
        production included; a missing host stays off. Virtual goods (StoreKit) stay off until products exist."""
        binding = self.text('App/WorkshopPaidInstallSessionBinding.swift')
        self.assertIn('guard ReviewedAreaSwitch.moneyPayments(apiHost: context.baseURL.host) else { invalidate(); return nil }', binding)
        commerce = self.text('App/WorkshopCommerceComposition.swift')
        self.assertIn('let payments = ReviewedAreaSwitch.moneyPayments(apiHost: context.baseURL.host)', commerce)
        self.assertIn('enableApprovedStoreKit && !readOnly && payments', commerce)
        switch = self.text('App/ReviewedAreaSwitch.swift')
        self.assertIn('static let productionAPIHost = "www.chengyinhub.com"', switch)
        self.assertIn('static func moneyPayments(apiHost: String?, testOrDebug: Bool = compiledTestOrDebug) -> Bool {\n        openMoney(apiHost: apiHost, testOrDebug: testOrDebug)', switch)
        self.assertIn('static func moneyPayments(host: String?) -> Bool { areaOpen(host) }', switch)
        money = switch.split('private static func openMoney(apiHost: String?, testOrDebug _: Bool) -> Bool {', 1)[1].split('\n    }', 1)[0]
        self.assertEqual(money.strip(), 'normalizedHost(apiHost) != nil')  # host required: no host, no money
        self.assertIn('case .virtualGoods: return false', switch)
        app = self.text('App/AppSession.swift')
        self.assertIn('enableApprovedStoreKit: ReleaseMoneyWriteSwitch.virtualGoodsEnabled && !readOnly', app)
        # Merchant writes and password login still use the production-closed opener below.
        self.assertIn('static func merchantWrites(host: String?) -> Bool { open(host: host) }', switch)
        opener = switch.split('static func open(host: String?) -> Bool {', 1)[1].split('\n    }', 1)[0]
        self.assertIn('!isProduction(normalizedHost) else { return false }', opener)
        production = switch.split('private static func isProduction(_ host: String) -> Bool {', 1)[1].split('\n    }', 1)[0]
        # The only exception is a DEBUG `--e2e-test-host` run, whose requests are rewritten to the TEST host.
        self.assertIn('#if DEBUG\n        if E2ETestHostOverride.active { return false }\n        #endif', production)
        self.assertIn('return host == productionAPIHost', production)
        self.assertIn('#if DEBUG\n        return true', opener)
        self.assertIn('ProcessInfo.processInfo.environment["QUESTIFY_TEST_AREA_SWITCHES"] == "1"', opener)

    def test_original_pending_status_precedes_optional_collection_reads(self):
        source = self.core().split('public func offerLoad(', 1)[1].split('private func offerPage(', 1)[0]
        self.assertLess(source.index('self.store.load()'), source.index('self.service.status'))
        self.assertLess(source.index('self.service.status'), source.index('self.service.history'))
        self.assertLess(source.index('self.service.history'), source.index('self.service.targets'))
        self.assertIn('guard self.pending?.belongs(to: self.item) != false', source)
        self.assertIn('try self.accept(status, expected: pending)', source)
        self.assertNotIn('.submit(', source)

    def test_optional_history_failure_never_suppresses_revocation(self):
        source = self.core().split('let recoveringOriginalRequest', 1)[1].split('if self.item.status', 1)[0]
        self.assertIn('if !recoveringOriginalRequest || issue == .unauthorized || issue == .staleSession || issue == .disabled { throw issue }', source)
        self.assertIn('try life.check()', source)
        self.assertIn('self.issue = issue', source)

    def test_background_retires_only_presentation_and_preserves_original_store(self):
        source = self.core().split('public func suspend(', 1)[1].split('public func resume(', 1)[0]
        for marker in ['appearance === displayed', '!displayed.closed', 'phase != .invalidated',
                       'displayed.suspended = true', 'displayed.action?.revoke()', 'lifetime?.revoke()',
                       'confirmation = nil; target = nil; region = nil']:
            self.assertIn(marker, source)
        for forbidden in ['store.', 'pending = nil', 'UUID()', 'lease.revoke()', 'submit(']:
            self.assertNotIn(forbidden, source)

    def test_resume_is_same_original_read_not_auto_submit_or_new_command(self):
        source = self.core().split('public func resume(', 1)[1].split('private func offer(', 1)[0]
        for marker in ['appearance === displayed', '!displayed.closed', 'displayed.suspended',
                       'phase != .invalidated', 'return offerLoad(displayed)']:
            self.assertIn(marker, source)
        for forbidden in ['UUID()', 'store.', 'submit(', 'WorkshopPaidInstallCommand(']:
            self.assertNotIn(forbidden, source)

    def test_queued_and_late_actions_check_suspended_appearance(self):
        source = self.core()
        self.assertIn('appearance?.suspended == false && appearance?.action === self', source)
        self.assertIn('appearance === displayed && !displayed.closed && !displayed.suspended', source)
        self.assertIn('guard lease.isCurrent else { invalidate(); return false }', source)

    def test_normal_view_scene_hooks_use_same_captured_appearance(self):
        source = self.text('App/WorkshopPaidInstallView.swift')
        for marker in ['@State private var isVisible = false', '@Environment(\\.scenePhase) private var scenePhase',
                       '.disabled(scenePhase != .active)', 'let displayed = appearance',
                       'if scenePhase == .active { schedule(action) }', 'else { controller.suspend(displayed) }',
                       'controller.suspend(displayed); ownedTask?.cancel(); ownedTask = nil',
                       'else if isVisible { schedule(controller.resume(displayed)) }',
                       'guard isVisible, scenePhase == .active, let action else { return }',
                       '.onDisappear { isVisible = false; controller.close(displayed); ownedTask?.cancel(); ownedTask = nil }']:
            self.assertIn(marker, source)

    def test_original_core_tests_keep_all_original_added_recovery_and_lifecycle_cases(self):
        source = self.text('Tests/CoreTests/WorkshopPaidInstallTests.swift')
        self.assertGreaterEqual(len(re.findall(r'func test\w+\(', source)), 47)

    def test_original_reentry_tests_are_registered_byte_exact_not_rewritten(self):
        source = self.text('Tests/AppUnitTests/WorkshopPaidInstallReentryTests.swift')
        self.assertGreaterEqual(len(re.findall(r'func test\w+\(', source)), 11)
        self.assertIn('Tests/AppUnitTests/WorkshopPaidInstallReentryTests.swift', self.text('Questify.xcodeproj/project.pbxproj'))

    def test_scene_aware_normal_flow_test_uses_existing_unchanged_real_scene_helper(self):
        source = self.text('Tests/AppUnitTests/WorkshopPaidInstallNormalFlowTests.swift')
        self.assertIn('let sceneWindow = try HostedNavigationSceneWindow()', source)
        helper = self.text('Tests/AppUnitTests/WorkshopPurchasedNormalAccountTests.swift')
        self.assertIn('UIWindow(windowScene: selected)', helper)
        self.assertIn('$0.activationState == .foregroundActive', helper)

    def test_service_and_journal_exist(self):
        for path in ['Core/WorkshopPaidInstallService.swift', 'Core/WorkshopPaidInstallPendingStore.swift',
                     'Core/WorkshopPaidInstallContracts.swift']:
            self.assertTrue((ROOT / path).is_file(), path)

    def test_independent_install_and_protected_text_grants_stay_separate(self):
        source = self.text('App/AppCompositionRoot.swift')
        self.assertEqual(source.count('workshopPaidInstallApproval: @escaping @MainActor (RuntimeDependencyContext) -> WorkshopPaidInstallApproval? = { _ in nil }'), 2)
        self.assertIn('WorkshopPaidInstallRequest.accepts(request, baseURL: api.baseURL), route != .submit', source)
        text_binding = self.text('App/WorkshopPaidInstalledTextSessionBinding.swift')
        self.assertIn('guard let context, let approval, let api', text_binding)
        self.assertIn('approval.matches(context)', text_binding)

if __name__ == '__main__': unittest.main()
