"""Scoped source contracts; these do not compile or execute Swift/XCTest."""
from pathlib import Path
import hashlib,json,re,unittest
ROOT=Path(__file__).resolve().parents[2]
OLD_EDITOR_HUNK = b'            Section { field("submissionId"); Toggle("merchant.content.approve", isOn: Binding(get: { approve }, set: { approve = $0; dirty = true; model.cancel() }))\n                if !approve { reasonPicker(["ANSWER_MISMATCH", "EVIDENCE_UNCLEAR", "DUPLICATE_SUBMISSION"]) }\n'
NEW_EDITOR_HUNK = b'            MerchantStationSubmissionImportView(owner: model, snapshot: snapshot, nodeID: station["nodeId"].safeInteger ?? 0, text: $text, approve: $approve) {\n                dirty = true; model.cancel()\n'
# combined-r5: re-pinned for fix-parity player-content chrome (MerchantContentEditor one exit guard, cyGuardedBack).
# fix/r8-player-content: re-pinned for merchantapply picker mount + 承接标的 (R7-PC-B3-2/B3-3) only.
EDITOR_BASE_SHA = 'fd44d1b7bf271896ff16be40c3be68eace763afd969266550a56c7ebef552280'
# combined-r5: MerchantContentViews / MerchantOperationsViews (merchant-coop X0 probe panel removed, decor chrome + cyGuardedBack),
# fix-parity2 merchant-coop: MerchantOperationsViews re-pinned for decor P1 per-page load-failure titles only.
# fix/r3-merchant-coop-b: MerchantOperationsViews re-pinned for decor apply/denied/failed-title states (MC7-19-3/5/6) only.
# fix/r3-merchant-coop-b round 2: MerchantOperationsViews re-pinned for the decor 城市节点 row opening the hub (MC7-24-4) only.
# fix/r3-merchant-coop-b round 4: MerchantOperationsViews re-pinned for the 口碑 row (MC7-19-10) and the inline 营业状态 switch (MC7-19-7) only.
# fix/r8-merchant-coop: MerchantOperationsViews re-pinned for decor hub rows only (MC8-19-1 看公开主页, MC8-19-5 联系运营开通, MC8-19-8 相册张数, MC8-19-11 / MC8-20-3 MP empty art).
# MerchantBusinessEditor (customer-detail P1 tag colour picker, aftercare-detail P1 no storage-key field),
# MerchantAftercareEvidenceFlow / MerchantEngagementViews (merchant-coop title-mode chrome) re-pinned; Core files unchanged.
PROTECTED = {'Core/MerchantStationContracts.swift': '54d04df6f2f28571617f084c3c6cd7fcf1b6601b0c0fa587af88314dcad48c61', 'Core/MerchantStationServiceWindow.swift': '62e93707db9f0bbad6e1f28477e012524b299930edfc6e03493c1a1c1d57066b', 'Core/MerchantContentCommands.swift': '12ccf512a90e2f03a52d17fdaff7af088e1f62d35ef40d7078098913e2cca73d', 'Core/MerchantContentCoordinator.swift': '164e7c67cd1ead53d4285506ee492b4c85e8a3b71174bb1b382a1f0556dd42a2', 'Core/MerchantContentDomain.swift': '17a2b3af5e8b35dfe9d4278fc77f9feaff7685c00d5af422f5743a3d9a3ef404', 'Core/MerchantContentService.swift': '64e457128507f50bebca6182a8230fa8fa03eb638a21bfd2f92f77fb2de8dab1', 'Core/MerchantContentSyntheticFixtures.swift': '1f97e1640c7eb9c148c94833f535512e82152a1e0ecb46d8de5e056b34cdee01', 'App/MerchantContentViews.swift': '3515e416078fa09eeba0a6f895ec3ef298e921d2d2e0cb417eb9771e54d532ea', 'App/MerchantStationServiceTimeFields.swift': '019a17a8188c5ebcd352b6beed782bfb09562b496eb508b9f0dcd57463b01bda', 'App/MerchantStationLiveCodeView.swift': '992eeff1dbeab2726a3539f988216a67b1e8f23d57884e402403f6eb24873c19', 'App/NativeQRScanner.swift': 'cfed504d0dca25055a0c913bb2e880f76b79158df6493a5ff7a8e288dfbe8ed9', 'App/NativeVerificationView.swift': 'a2bacd31fd6af8c70266e178adf6c222086daecb96139c04d67ce3f9bbfe6507', 'Core/BusinessRuntimeConfiguration.swift': '4ddd26ae13d23970d5cbb5c71d75aa19ab79765ff97345732b3e642dcb77a45e', 'App/MerchantBusinessEditor.swift': 'b6c5d1ae2704fd3c10bcd0810f62b70b9959ac369d6ae88230b099dd220b9236', 'App/MerchantAftercareEvidenceFlow.swift': '23dc70ff73ae266e173efb46917e116209ad01ab1f10849fad01527aa527930c', 'App/MerchantEngagementViews.swift': '1792a645ece3bf781f4d980d60e9f6dc8a71d0560055eee5945b852f3455ca2d', 'App/MerchantOperationsViews.swift': 'afa248802cea509705ba3758c258da54ba0beb042a66982744bcf144e3900a3a'}

class SubmissionImportContracts(unittest.TestCase):
    def setUp(self):
        self.parser=(ROOT/'Core/MerchantStationSubmissionCode.swift').read_text()
        self.view=(ROOT/'App/MerchantStationSubmissionImportView.swift').read_text()
        self.editor=(ROOT/'App/MerchantContentEditor.swift').read_text()
    def test_exact_single_editor_inverse_preserves_every_other_hunk(self):
        raw=(ROOT/'App/MerchantContentEditor.swift').read_bytes()
        self.assertEqual(raw.count(NEW_EDITOR_HUNK),1)
        self.assertEqual(hashlib.sha256(raw.replace(NEW_EDITOR_HUNK,OLD_EDITOR_HUNK)).hexdigest(),EDITOR_BASE_SHA)
    def test_existing_services_commands_journal_and_scanners_unchanged(self):
        for path,expected in PROTECTED.items():self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),expected,path)
    def test_parser_bounds_before_trimming_and_never_coerces_via_float(self):
        self.assertIn('maximumInputBytes = 4_096',self.parser)
        self.assertLess(self.parser.index('raw.utf8.count <='),self.parser.index('raw.trimmingCharacters'))
        self.assertIn('let identifier = Int64(candidate), identifier > 0',self.parser)
        for token in ['JSONSerialization','Double(', 'URLComponents(', 'URLSession', 'openURL']:self.assertNotIn(token,self.parser)
    def test_json_single_field_and_query_single_identifier_are_strict(self):
        self.assertIn('"submissionId"[ \\t\\r\\n]*:',self.parser)
        self.assertIn('(?:"([1-9][0-9]{0,18})"|([1-9][0-9]{0,18}))',self.parser)
        self.assertIn('\\}\\z',self.parser)
        self.assertIn('value.hasPrefix("?submissionId=")',self.parser)
        self.assertIn('candidate.utf8.allSatisfy({ (48...57).contains($0) })',self.parser)
    def test_all_absolute_links_fail_closed_without_host_inference(self):
        self.assertIn('!value.contains("://"), !value.hasPrefix("//")',self.parser)
        self.assertIn('throw Failure.unsupportedLink',self.parser)
    def test_no_new_device_network_persistence_or_clipboard_action(self):
        for token in ['UIPasteboard','PasteButton','NativeQRScanner','AVCapture','requestAccess','URLSession','openURL','UserDefaults','FileManager','service.load(','service.perform(','owner.prepare(','model.prepare(']:
            self.assertNotIn(token,self.view+self.parser)
    def test_input_preview_apply_are_three_separate_steps(self):
        for token in ['func update(', 'func preview()', 'func apply() -> Bool', 'session.update', 'session.preview()', 'session.apply()'] :self.assertIn(token,self.view)
        self.assertIn('code = try .init(raw); raw = ""',self.view)
        self.assertIn('SecureField("merchant.submissionImport.input"',self.view)
        self.assertIn('Section("merchant.submissionImport.unverified")',self.view)
    def test_context_is_exact_current_observation_and_authorized_station(self):
        for token in ['snapshot.access.active','projection.allows(.verify, nodeID: nodeID)','snapshot.query == .game(activityID: projection.activityID)','lhs.snapshot.observedAt == rhs.snapshot.observedAt','lhs.bytes == rhs.bytes','owner.isCurrent','owner.service.isConfigured','!owner.busy, !owner.locked','owner.review == nil, owner.receipt == nil','current.scope == owner.service.scope']:
            self.assertIn(token,self.view)
    def test_raw_draft_uses_utf8_and_all_fields_not_only_identifier(self):
        for token in ['lhs.approve == rhs.approve','lhs.text.count == rhs.text.count','lhs.text.allSatisfy','value.utf8.elementsEqual(other.utf8)','currentDraft() == original','draft == original']:self.assertIn(token,self.view)
    def test_manual_edit_and_lifecycle_generation_prevent_aba(self):
        for token in ['generation == permit','self.generation == captured','model.invalidate(); approve = $0','model.invalidate(); text[name] = $0','.onChange(of: scenePhase)','.onDisappear { model.deactivate() }','.onChange(of: context)','.onChange(of: draft)']:
            self.assertIn(token,self.view)
        self.assertIn('let permit = model.generation',self.view)
    def test_final_stage_is_synchronous_and_preserves_decision_and_reason(self):
        apply=self.view[self.view.index('@discardableResult func apply()'):self.view.index('    func retire(')]
        self.assertNotIn('await ', '\n'.join(line.split('//')[0] for line in apply.splitlines()))
        self.assertLess(apply.index('guard isCurrent'),apply.index('stage(code.submissionID)'))
        callback=self.view[self.view.index('currentDraft: { draft }'):self.view.index('            }.disabled')]
        self.assertIn('text["submissionId"] = identifier; didChange(); return true',callback)
        self.assertNotIn('approve =',callback);self.assertNotIn('reasonCode',callback)
        self.assertIn('utf8.elementsEqual(identifier.utf8) { return true }',callback)
    def test_cancel_retirement_scrubs_memory_and_old_cancel_cannot_close_new_sheet(self):
        self.assertIn('guard session?.id == id else { return }; invalidate()',self.view)
        self.assertIn('session?.retire(); session = nil',self.view)
        self.assertIn('retired = true; raw = ""; code = nil',self.view)
    def test_actual_sheet_binding_captures_presented_id_for_get_and_dismiss(self):
        binding=self.view[self.view.index('    func presentationBinding()'):self.view.index('    func open(')]
        self.assertIn('let presentedID = session?.id',binding)
        self.assertIn('self.session?.id == presentedID',binding)
        self.assertIn('guard value == nil, let presentedID else { return }',binding)
        self.assertIn('self?.cancel(id: presentedID)',binding)
        self.assertIn('.sheet(item: model.presentationBinding())',self.view)
        self.assertNotIn('let id = model.session?.id { model.cancel',self.view)
        tests=(ROOT/'Tests/AppUnitTests/MerchantStationSubmissionImportTests.swift').read_text()
        self.assertIn('testOldPresentationBindingCannotDismissOrExposeReopenedSession',tests)
        self.assertIn('oldBinding.wrappedValue = nil',tests)
    def test_manual_controls_retain_existing_labels_ids_and_reason_choices(self):
        for token in ['merchant.content.field.submissionId','merchant.content.approve','merchant.content.field.reasonCode','merchant.content.chooseReason','ANSWER_MISMATCH','EVIDENCE_UNCLEAR','DUPLICATE_SUBMISSION','.textInputAutocapitalization(.sentences).autocorrectionDisabled()']:
            self.assertIn(token,self.view)
        self.assertIn('dirty = true; model.cancel()',self.editor)
    def test_localizations_cover_labels_and_truthful_scope(self):
        fragment=json.loads((ROOT/'Resources/MerchantStationSubmissionImportLocalizations.fragment.json').read_text())
        keys=set(re.findall(r'merchant\.submissionImport\.[A-Za-z]+',self.view))-{'merchant.submissionImport.cancel'}
        self.assertEqual(set(fragment),keys);self.assertEqual(len(fragment),15)
        for value in fragment.values():self.assertEqual(set(value['localizations']),{'en','zh-Hans'})
        self.assertIn('not been checked',fragment['merchant.submissionImport.unverifiedBody']['localizations']['en']['stringUnit']['value'])
        self.assertIn('does not support camera',fragment['merchant.submissionImport.noCamera']['localizations']['en']['stringUnit']['value'])
    def test_negative_lifecycle_and_preservation_xctests_are_authored(self):
        core=(ROOT/'Tests/CoreTests/MerchantStationSubmissionCodeTests.swift').read_text();app=(ROOT/'Tests/AppUnitTests/MerchantStationSubmissionImportTests.swift').read_text()
        self.assertEqual(len(re.findall(r'func test',core)),19);self.assertEqual(len(re.findall(r'func test',app)),23)
        for token in ['testDuplicateJSONIDs','testMultipleQueryIDs','testOversizedInput','testAbsoluteAndNetworkPathLinks','testExactIntegerBeyondJavaScriptPrecision']:self.assertIn(token,core)
        for token in ['testCancelPreservesBytes','testManualEditABA','testBackgroundAndReturn','testRawDraftUnicodeOnlyChange','testChangedScopeAuthenticationOrConfiguration','testExistingDecisionReviewBlocksImport','testExplicitApplyChangesOnlyID']:self.assertIn(token,app)

if __name__=='__main__':unittest.main(verbosity=2)
