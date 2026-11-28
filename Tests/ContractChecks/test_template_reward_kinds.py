"""Reward configuration flow wiring checks. Swift and native UI are separate gates."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RewardKindContracts(unittest.TestCase):
    def test_all_three_types_offer_enable_edit_disable_in_the_existing_reward_section(self):
        forms = (ROOT / "App/TemplateAuthoringDetailForms.swift").read_text()
        reward = forms.split('Section("templateAuthor.reward")', 1)[1].split('Section("templateAuthor.story")', 1)[0]
        for kind in ["coupon", "feedback", "medal"]:
            self.assertIn(f"isOn: rewards.toggle(.{kind})", reward)
            self.assertIn(f"if rewards.isEnabled(.{kind})", reward)
            self.assertIn(f'templateRewardKinds.{kind}', reward)
        # The coupon control moved into `couponField` (MP reward-selector, plain ID field without a session).
        self.assertIn("couponField", reward)
        field = forms.split("@ViewBuilder private var couponField", 1)[1].split("var body: some View", 1)[0]
        self.assertIn("couponID: rewards.coupon()", field)
        self.assertIn("text: rewards.coupon()", field)
        for control in ["text: rewards.text(.feedback)", "text: rewards.text(.medalName)",
                        "text: rewards.text(.medalImage)", "selection: rewards.medalStyle()", "isOn: rewards.moduleEnabled()"]:
            self.assertIn(control, reward)
        self.assertIn("if !rewards.hasSelection", reward)
        self.assertIn("action: model.clearRewardMedalAction()", reward)
        self.assertIn(".disabled(!model.canEdit)", reward)

    def test_feedback_row_only_for_templates_that_already_have_text(self):
        # MP publish/temp/index.wxml:1409 `cg-rw-row wx:if="{{ rwText }}"`: 文字反馈 is no longer offered (2026-10-22);
        # an old template keeps its row until switched off, which clears it.
        forms = (ROOT / "App/TemplateAuthoringDetailForms.swift").read_text()
        reward = forms.split('Section("templateAuthor.reward")', 1)[1].split('Section("templateAuthor.story")', 1)[0]
        gate = reward.index("if rewards.isEnabled(.feedback) {")
        self.assertLess(gate, reward.index("isOn: rewards.toggle(.feedback)"))

    def test_each_off_switch_changes_only_its_existing_contents(self):
        core = (ROOT / "Core/TemplateRewardKinds.swift").read_text()
        self.assertIn("case .coupon: next.couponId = nil", core)
        self.assertIn("case .feedback: next.feedbackText = nil", core)
        self.assertIn("case .medal: next.medalImg = nil; next.medalName = nil", core)
        for forbidden in ["next.medalStyle =", "next.rewardEnabled =", "Codable", "URLSession", "HTTPTransport", "UserDefaults"]:
            self.assertNotIn(forbidden, core)

    def test_load_infers_without_normalizing_and_enable_does_not_fabricate_data(self):
        core = (ROOT / "Core/TemplateRewardKinds.swift").read_text()
        self.assertIn("(draft.couponId ?? 0) > 0", core)
        self.assertIn('!(draft.feedbackText ?? "").isEmpty', core)
        self.assertNotIn("trim", core)
        editor = (ROOT / "App/TemplateRewardKindEditor.swift").read_text()
        self.assertIn("enabled = TemplateRewardKinds.inferred(from: model.draft)", editor)
        self.assertIn("if value { self.enabled.insert(kind) }", editor)
        self.assertNotIn("makePlayer", editor)
        self.assertNotIn("submit(", editor)

    def test_type_generations_fence_old_fields_without_retiring_other_types(self):
        editor = (ROOT / "App/TemplateRewardKindEditor.swift").read_text()
        for token in ["kindGenerations[kind] == kindStamp", "self.kindGenerations[kind] = UUID()",
                      "mediaGeneration == model.mediaReviewGeneration", "session == model.coordinator.session",
                      "identity == model.coordinator.identity", "self.canEdit", "self.isEnabled(field.kind)",
                      "self.model.changed()", "func retire()", "func resume()"]:
            self.assertIn(token, editor)
        forms = (ROOT / "App/TemplateAuthoringDetailForms.swift").read_text()
        self.assertIn(".onDisappear { rewards.retire() }", forms)
        self.assertIn(".onChange(of: model.mediaReviewGeneration) { _, _ in rewards.reload() }", forms)

    def test_previous_editing_entries_remain_available(self):
        forms = (ROOT / "App/TemplateAuthoringDetailForms.swift").read_text()
        for token in ["TemplateChoiceOptionRowsFields(model: model)", "TemplateNarrationAudioPreviewEntry(model: model)",
                      "action: model.clearNarrationAudioAction()", "action: editor.removeImageAction(beat.id, at: imageIndex)",
                      "action: model.clearRewardMedalAction()"]:
            self.assertIn(token, forms)

    def test_fragments_cover_all_labels_and_only_new_reward_files(self):
        local = json.loads((ROOT / "docs/localization/template-reward-kinds.json").read_text())
        self.assertEqual(set(local["strings"]), {"templateRewardKinds.coupon", "templateRewardKinds.feedback", "templateRewardKinds.medal",
                                                "templateRewardKinds.clearNotice", "templateRewardKinds.empty"})
        for row in local["strings"].values(): self.assertEqual(set(row["localizations"]), {"en", "zh-Hans"})
        registry = json.loads((ROOT / "docs/registration/template-reward-kinds.json").read_text())
        self.assertEqual(registry["app_sources"], ["App/TemplateRewardKindEditor.swift", "Core/TemplateRewardKinds.swift"])
        self.assertEqual(registry["app_unit_tests"], ["Tests/AppUnitTests/TemplateRewardKindEditorTests.swift"])
        self.assertEqual(registry["package_tests"], ["Tests/CoreTests/TemplateRewardKindsTests.swift"])


if __name__ == "__main__": unittest.main()
