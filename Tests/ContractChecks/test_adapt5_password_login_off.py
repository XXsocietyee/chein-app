"""ADAPT-5: password login is compiled out of release builds (additive; existing contracts untouched)."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class Adapt5PasswordLoginOff(unittest.TestCase):
    def text(self, name): return (ROOT/name).read_text()
    def test_markers_exist(self):
        s = self.text('App/AppSession.swift')
        self.assertIn('static var passwordLoginCompiledIn:Bool {\n#if DEBUG\n        true\n#else\n        false\n#endif', s)
        self.assertIn('var canUsePassword:Bool {\n#if DEBUG\n        storageScope != nil && regionalConfiguration?.availability(of:.usernamePassword) == .available\n#else\n        false\n#endif', s)
        self.assertIn('#else\n            service=nil\n#endif', s)
        login = s.split('    func login(username:String,password:String) async {', 1)[1]
        self.assertLess(login.index('guard Self.passwordLoginCompiledIn'), login.index('service.login('))
    def test_route_and_tests_retained_and_not_allowlisted(self):
        self.assertIn('execute(.password', self.text('Core/AuthService.swift'))
        self.assertNotIn('[AuthEndpoint.password,', self.text('App/AppCompositionRoot.swift'))
        self.assertIn('session.canUsePassword', self.text('App/LoginView.swift'))
if __name__ == '__main__': unittest.main()
