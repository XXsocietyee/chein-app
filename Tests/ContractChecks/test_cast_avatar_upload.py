"""mp-publish: 编辑角色 avatar upload (MP `publish/fabu/cast-sheet.wxml:71-77`, `theme-cast.js` `pickCastAvatar`).

One photo → the editor's approved `api/common/uploadOSS` (story-picture upload) → `cast[].avatarUrl`;
完成 waits for a running upload (MP L03-085 还在上传，请稍候再点完成); only MEDIA_URL values are saved.
"""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
EDITOR = ROOT / "App/MPGap/AccountPublish/ProjectEditCastMemberEditor.swift"
MOUNTS = ROOT / "App/MPGap/AccountPublish/AccountPublishR8Mounts.swift"


class CastAvatarUploadTests(unittest.TestCase):
    def test_editor_picks_and_uploads_through_the_story_image_source(self):
        text = EDITOR.read_text(encoding="utf-8")
        self.assertIn("PhotosPicker(selection: $avatarItem, matching: .images)", text)
        self.assertIn("RetainedImageSanitizer.sanitize(bytes)", text)
        self.assertIn("model.coordinator.storyImageSource", text)
        self.assertIn("source.upload(image, attemptID: UUID(), session: session).reference", text)
        self.assertIn("source.permitsPicker(session: session)", text)

    def test_done_waits_for_a_running_upload_before_the_name_rules(self):
        text = EDITOR.read_text(encoding="utf-8")
        save = text[text.index("private func save()"):]
        self.assertLess(save.index("issue = .avatarUploading"), save.index("issue = .nameMissing"))

    def test_saved_avatar_follows_mp_media_url(self):
        text = MOUNTS.read_text(encoding="utf-8")
        self.assertIn("static func savableAvatar(_ raw: String?) -> String?", text)
        self.assertIn('if let avatar = savableAvatar(member.avatarURL) {\n                row["avatarUrl"] = .string(avatar)', text)
        self.assertIn('avatarURL: savableAvatar(m["avatarUrl"]?.text)', text)

    def test_editor_is_wired_from_the_fabu_page(self):
        view = (ROOT / "App/ProjectEditView.swift").read_text(encoding="utf-8")
        self.assertIn("avatarUpload: ProjectEditCastAvatarUpload.make(model)", view)

    def test_copy_is_bilingual(self):
        strings = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"]
        for key in ("upload", "change", "uploading", "unreadable", "failed", "stillUploading"):
            loc = strings["castMember.avatar." + key]["localizations"]
            self.assertTrue(loc["en"]["stringUnit"]["value"])
            self.assertTrue(loc["zh-Hans"]["stringUnit"]["value"])


if __name__ == "__main__":
    unittest.main()
