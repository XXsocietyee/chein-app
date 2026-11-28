"""Function audit 11-28 P1-28 (mp-publish): IM image send is admitted in the China player/club runtime.

MP `subpackageB/pages/im/chat/index.js:850-858` `onPickImage` → `app.chooseImage` (multipart `file` + `bizType`,
`app.js:665`, default `image_free`) → `api/common/uploadOSS` → `_sendMessage({ msg_type: 2, content: url })`.
Before: no `.imUpload` route and `imImageSelection` false, yet the 发送图片 row still showed.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class IMImageSendAdmissionTests(unittest.TestCase):
    def test_runtime_grants_upload_route_and_picker(self):
        text = (ROOT / "App/ReviewedPlayerWriteLeases.swift").read_text(encoding="utf-8")
        self.assertIn('imRoutes[.imUpload] = Set([try? BusinessRuntimeRoute.post("api/common/uploadOSS")]', text)
        self.assertIn("imImageSelection: socialRole(context)", text)
        self.assertIn('RetainedImageOrigin.configured(apiBase: context.baseURL', text)

    def test_upload_sends_mp_biz_type(self):
        text = (ROOT / "Core/IMExpandedService.swift").read_text(encoding="utf-8")
        self.assertIn('name=\\"bizType\\"\\r\\n\\r\\nimage_free', text)

    def test_photo_row_hidden_when_upload_is_off(self):
        text = (ROOT / "App/IMExpandedViews.swift").read_text(encoding="utf-8")
        self.assertIn("if let uploadOwner, uploadOwner.isConfigured, focus == nil || focus == .image {", text)
        self.assertIn("uploadOwner?.isConfigured == true", text)


if __name__ == "__main__":
    unittest.main()
