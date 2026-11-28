"""Function audit P1-15: 填写邀请人 sends POST /api/user/setInviter (inviter_id), like MP pages/index/index.js:454."""
import unittest
from pathlib import Path
W=Path(__file__).resolve().parents[2]
D=(W/'App/AppSessionDoorEntry.swift').read_text();V=(W/'App/NativeEntryLandingView.swift').read_text();S=(W/'Core/DoorReferralService.swift').read_text()
class InviterBindingTests(unittest.TestCase):
 def test_binding_on(self):self.assertIn('scanEnabled: false, bindingEnabled: true',D)
 def test_sheet_enabled(self):self.assertIn('queue: queue, enabled: true)',V);self.assertNotIn('enabled: false)',V.split('struct SessionDoorInviterView')[1].split('struct NativeEntryLandingView')[0])
 def test_request_shape(self):self.assertIn('path: "api/user/setInviter", field: "inviter_id"',S)
 def test_server_confirmed(self):self.assertIn('guard body.code == 200 else',S)
if __name__=='__main__':unittest.main()
