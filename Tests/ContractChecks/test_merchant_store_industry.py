"""Source-level supplementary checks; not Swift typechecking or simulator acceptance."""
import json
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
def read(path): return (ROOT / path).read_text()


class MerchantStoreIndustryChecks(unittest.TestCase):
    def core(self): return read('Core/MerchantStoreIndustrySelection.swift')
    def app(self): return read('App/MerchantStoreIndustryPicker.swift')

    def test_industry_catalog_uses_type_one_and_existing_profile_permission(self):
        service = read('Core/MerchantOperationsService.swift').split('public func storeIndustries(')[1].split('public func featuredActivities(')[0]
        self.assertIn('guard access.allows(.decor)', service)
        self.assertIn('read("api/category/list", body: .form(["type": "1", "parentid": "0"]), token: token)', service)
        self.assertNotIn('"type": "4"', service); self.assertNotIn('.templates', service)

    def test_catalog_accepts_only_existing_integer_single_industries(self):
        core = self.core()
        for text in ['id > 0, id <= Int(Int32.max)', 'type == nil || type == 1', '!name.trimmingCharacters',
                     'singleValueContainer().decode([MerchantStoreIndustry].self)', 'Set(rows.map(\\.id)).count == rows.count']:
            self.assertIn(text, core)
        self.assertNotIn('!rows.isEmpty', core)

    def test_session_read_preserves_access_and_account_fences(self):
        reader = read('Core/MerchantOperationsReading.swift')
        method = reader.split('public func storeIndustries()')[1].split('public func featuredActivities(')[0]
        for text in ['let expected = currentSession()', 'try await read', 'service.access(token: token)', 'expected == currentSession()']:
            self.assertIn(text, method)
        self.assertIn('currentSession() == session, captured == scope', reader)

    def test_apply_is_single_use_and_changes_only_existing_category_id(self):
        # Ordered 1–5 selection replaced the single categoryID write. Apply still
        # edits only that local decor buffer, then consumes itself. Saving stays outside.
        core = self.core(); apply = core.split('public func apply()')[1].split('public func cancel()')[0]
        self.assertIn('var edited = original', apply)
        self.assertIn('edited.selectIndustries(selectedIDs, catalog: rows)', apply)
        self.assertIn('cancel(); return edited', apply)
        self.assertIn('(1...5).contains(selectedIDs.count)', core)
        for text in ['save(', 'owner.edit(', 'categoryName', 'activityCategoryids', 'categoryID =']:
            self.assertNotIn(text, apply)
        self.assertIn('document.edit(.decor(value))', self.app())

    def test_unavailable_source_is_retained_without_automatic_selection_or_clear(self):
        # The buffer is seeded from the saved ordered ids. Reload replaces the catalog
        # only. An empty selection cannot apply, so a missing catalog row is not a clear.
        core = self.core()
        self.assertIn('selectedIDs = original.selectedCategoryIDs', core)
        self.assertIn('public var previousIsUnavailable:', core)
        self.assertIn('rows.contains(where: { $0.id == id })', core)
        self.assertNotIn('selectedID = nil', core)
        self.assertIn('(1...5).contains(selectedIDs.count)', core)
        reload = core.split('public func reload()')[1].split('public func apply()')[0]
        self.assertNotIn('selectedID =', reload)
        self.assertNotIn('selectedIDs =', reload)
        self.assertIn('merchant.industry.unavailable', self.app())
        self.assertIn('merchant.industry.sourceUnreadable', self.app())

    def test_new_industry_field_can_make_an_otherwise_empty_decor_draft_valid(self):
        # An ordered industry set is enough to leave the empty-decor state. The write
        # sends categoryIds only for an explicit replacement; omitting it keeps the server set.
        core = read('Core/MerchantOperationsContracts.swift')
        self.assertIn('gallery.isEmpty && tags.isEmpty && selectedCategoryIDs.isEmpty && !(featuredType == 0 && featuredID == nil)', core)
        fields = core.split('public func fields()')[1].split('public static func listString')[0]
        self.assertIn('fields["categoryIds"]', fields)
        self.assertIn('Only explicit replacement is writable', fields)
        self.assertNotIn('"categoryId"', fields)

    def test_cancel_stale_document_account_and_late_response_are_fenced(self):
        core = self.core()
        for text in ['owner.draft == .decor(original)', 'owner.reader.scope == scope', 'owner.draftIdentity == identity',
                     'ticket == generation, isCurrent', 'request?.cancel()', 'consumed = true']:
            self.assertIn(text, core)
        app = self.app()
        for text in ['.onChange(of: document.coordinator.draftIdentity)', '.onChange(of: document.coordinator.draft)',
                     '.onChange(of: document.coordinator.reader.scope)', '.onChange(of: scenePhase)', '.onDisappear { close() }']:
            self.assertIn(text, app)

    def test_frozen_review_and_industry_only_readback_mount_existing_flow(self):
        editor = read('App/MerchantOperationsEditor.swift')
        self.assertIn('MerchantStoreIndustryPicker(document: model)', editor)
        self.assertIn('MerchantStoreIndustryReview(change: change)', editor)
        reader = read('Core/MerchantOperationsReading.swift')
        section = reader.split('} else if MerchantStoreIndustryChange(baseline: value.baseline, draft: value.draft) != nil {')[1].split('} else if case .cooperation')[0]
        for text in ['document = nil; baseline = nil; draft = nil', 'reader.document(.decor)',
                     'baseline = .decor(returned); draft = .decor(returned)', 'merchant.industry.readbackFailed']:
            self.assertIn(text, section)
        for text in ['saveReviewed', 'saveExample', 'isLocked = true']: self.assertNotIn(text, section)

    def test_ui_has_load_empty_retry_buffer_and_clear_boundary(self):
        # replaceHint / reviewBody were the single-select copy. The ordered picker
        # uses orderedHint, reviewOrdered, the unreadable-source line, and the 1–5 limit.
        app = self.app()
        for text in ['merchant.industry.loading', 'merchant.industry.empty', 'merchant.industry.retry', 'merchant.industry.reload',
                     'merchant.industry.cancel', 'merchant.industry.apply', 'merchant.industry.orderedHint',
                     'merchant.industry.reviewOrdered', 'merchant.industry.sourceUnreadable',
                     'merchant.industry.selectionInvalid', 'merchant.industry.limit']:
            self.assertIn(text, app)
        self.assertIn('.disabled(model.busy || !model.selection.canApply)', app)
        self.assertNotIn('URLSession', app); self.assertNotIn('publish(', app)

    def test_bilingual_fragment_and_interpolation_are_complete(self):
        # The fragment is the older 22-key single-select snapshot. Shipped copy for the
        # ordered picker is in Localizable.xcstrings, including the primary-id interpolation.
        fragment = json.loads(read('Resources/MerchantStoreIndustryLocalizations.fragment.json'))
        source = self.app() + read('Core/MerchantOperationsReading.swift')
        source = re.sub(r'\.accessibilityIdentifier\("[^"\n]*"\)', '', source)
        keys = set(re.findall(r'"(merchant\.industry\.[A-Za-z]+)"', source))
        keys.add('merchant.industry.currentID %lld')
        self.assertIn('merchant.industry.currentID \\(value.selectedCategoryIDs[0])', self.app())
        self.assertEqual(keys, {
            'merchant.industry.apply', 'merchant.industry.catalog', 'merchant.industry.choose',
            'merchant.industry.currentID %lld', 'merchant.industry.empty', 'merchant.industry.limit',
            'merchant.industry.loading', 'merchant.industry.new', 'merchant.industry.none',
            'merchant.industry.orderedHint', 'merchant.industry.original', 'merchant.industry.previous',
            'merchant.industry.readback', 'merchant.industry.readbackFailed', 'merchant.industry.reload',
            'merchant.industry.remove', 'merchant.industry.retry', 'merchant.industry.reviewOrdered',
            'merchant.industry.reviewTitle', 'merchant.industry.selectedOrder',
            'merchant.industry.selectionInvalid', 'merchant.industry.sourceUnreadable',
            'merchant.industry.stale', 'merchant.industry.unavailable',
        })
        catalog = json.loads(read('Resources/Localizable.xcstrings'))['strings']
        for key in keys:
            row = catalog[key]
            for locale in ['en', 'zh-Hans']:
                self.assertTrue(row['localizations'][locale]['stringUnit']['value'].strip(), key)
        for value in fragment.values():
            for locale in ['en', 'zh-Hans']: self.assertTrue(value['localizations'][locale]['stringUnit']['value'])

    def test_authored_core_tests_cover_real_adapter_gate_readback_failure_and_recovery(self):
        tests = read('Tests/CoreTests/MerchantStoreIndustryTests.swift')
        self.assertEqual(len(re.findall(r'func test\w+\(', tests)), 19)
        for text in ['testIndustryAloneMakesNewDecorChoiceReviewable', 'testSingleSelectionChangesOnlyIndustryAndAppliesOnce',
                     'testMissingSavedIndustryRemainsUntilUserChoosesReplacement', 'testNewerReloadWinsOverOutOfOrderCatalog',
                     'testProjectPermissionAloneCannotReadIndustryPicker', 'testAcknowledgedSaveWithFailedReadbackCannotBeReplayed',
                     'transport.replies += [access, canonical]; await owner.load()', 'testNoApprovalStillPreventsStoreWrite']:
            self.assertIn(text, tests)

    def test_authored_ui_tests_cover_cancel_review_discard_save_reload(self):
        tests = read('Tests/AppUITests/MerchantStoreIndustryFlowTests.swift')
        self.assertEqual(len(re.findall(r'func test\w+\(', tests)), 3)
        for text in ['merchant.industry.cancel', 'merchant.industry.review.previous', 'merchant.industry.review.new',
                     'nativeAlertAction("merchant.operations.keepEditing", in: app)', 'nativeAlertAction("merchant.operations.discardReload", in: app)',
                     'keepEditing.waitForExistence(timeout: 5)', 'discardReload.waitForExistence(timeout: 5)',
                     'merchant.operations.exampleSaved', 'merchant.industry.reload']:
            self.assertIn(text, tests)


if __name__ == '__main__': unittest.main()
