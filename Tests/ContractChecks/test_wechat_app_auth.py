"""Source checks only, never substitutes for Swift or SDK/runtime execution."""
from pathlib import Path
import json, unittest
ROOT = Path(__file__).resolve().parents[2]
class WeChatAuthSourceChecks(unittest.TestCase):
    def test_source_contract_is_app_only(self):
        source = (ROOT/'Core/WeChatAppAuth.swift').read_text()
        self.assertIn('builder.make(.wechatApp, fields: ["code": code])', source)
        for forbidden in ['/login/code', 'getwxbindphone', 'UserDefaults', 'Keychain', 'print(', 'URLSession', 'UIApplication']:
            self.assertNotIn(forbidden, source)
    def test_all_grants_default_false_and_host_unconfigured(self):
        source = (ROOT/'Core/WeChatAppAuth.swift').read_text()
        for field in ['sdkVerified','providerVerified','legalVerified','appleAlternativeVerified','liveExchangeApproved']:
            self.assertIn(f'var {field} = false', source)
        host = (ROOT/'App/AppSession.swift').read_text()
        # P0-5 (audit 11-28): the host reads the owner configuration from the bundle and re-derives the gate on every use.
        self.assertIn('lazy var weChatAuth = WeChatAppAuthCoordinator(adapter: weChatSDKAdapter, service: weChatExchangeService, gate:', host)
        self.assertIn('private let weChatSDKConfiguration: WeChatSDKConfiguration? = WeChatAppLaunch.bundleConfiguration()', host)
        self.assertIn('private var weChatSDKGate: WeChatAppAuthGate { weChatReleaseGate(sdkLinked: weChatSDKDriver.isLinked, configured: weChatSDKConfiguration != nil) }', host)
        links = (ROOT/'App/AppSession+AppLinks.swift').read_text()
        self.assertIn("guard composition.reviewed?.weChatSignInApproved == true", links)
        self.assertIn("appleAlternative: reviewed?.appleSignInApproved == true", links)
        self.assertIn('return try self.commitChannelLogin(result, expected: expected.session)', host)
    def test_callback_claim_precedes_exchange(self):
        source = (ROOT/'Core/WeChatAppAuth.swift').read_text()
        self.assertLess(source.index('phase = .exchanging;'), source.index('exchangeTask = Task'))
        self.assertIn('state == request?.state', source)
        self.assertIn('captured == context()', source)
        self.assertIn('guard request?.attemptID == attemptID else { return }', source)
    def test_localization_and_accessibility(self):
        catalog = json.loads((ROOT/'Resources/WeChatAppAuthLocalizations.fragment.json').read_text())
        # K40: the mini-program account note and its dismiss label (en + zh-Hans).
        self.assertEqual(len(catalog['strings']), 20)
        for key in ('auth.wechat.linkedMiniProgram', 'auth.wechat.linkedMiniProgram.dismiss'):
            self.assertIn(key, catalog['strings'])
            for language in ('en', 'zh-Hans'):
                self.assertTrue(catalog['strings'][key]['localizations'][language]['stringUnit']['value'])
        for entry in catalog['strings'].values():
            for language in ['en','zh-Hans']:
                self.assertTrue(entry['localizations'][language]['stringUnit']['value'])
        view=(ROOT/'App/WeChatAppAuthSection.swift').read_text()
        self.assertIn('.disabled(!model.coordinator.canStart)', view)
        self.assertIn('.accessibilityIdentifier("auth.wechat.signIn")', view)
        self.assertIn('.onDisappear { model.coordinator.cancel() }', view)
    def test_existing_channels_preserved(self):
        login=(ROOT/'App/LoginView.swift').read_text()
        for key in ['auth.signIn','auth.otherChannels','AuthChannelView(embeddedModel: model', 'LoginAuthChannelHost(coordinator: channelCoordinator)', 'return session.authChannels']:
            # mp-nav 11-28: the host reads `channelCoordinator` (session.authChannels; DEBUG fixtures may inject one).
            self.assertIn(key, login)
        self.assertIn('USLaunchPresentation.signInLeadsWithApple(storefront: RegionalLaunchConfiguration.storefrontMarket, deployment: session.operationalMarket)', login)
        self.assertIn('WeChatAppAuthSection(coordinator: session.weChatAuth, context: session.authChannelSnapshot)', login)
    def test_no_sdk_or_entitlement_activation(self):
        manifest=(ROOT/'Package.swift').read_text()
        self.assertNotIn('Wechat', manifest)
        self.assertNotIn('WeChatSDK', manifest)
    def test_mini_program_note_is_not_authorization(self):
        auth = (ROOT/'Core/WeChatAppAuth.swift').read_text()
        self.assertIn('linkedMiniProgram = (try? c.decode(Bool.self, forKey: .linkedMiniProgram)) ?? false', auth)
        self.assertIn('linkedMiniProgram: body.linkedMiniProgram', auth)
        self.assertIn('linkedMiniProgram: result.linkedMiniProgram', auth)
        self.assertNotIn('body.msg', auth)
        session = (ROOT/'App/AppSession.swift').read_text()
        self.assertIn('return try self.commitChannelLogin(result, expected: expected.session)', session)
        note_before_commit = session.index('if result.linkedMiniProgram { noteLinkedMiniProgramAccount() }; self.commitAuthenticatedSession(token: result.token, account: result.account);self.errorKey=nil')
        self.assertGreater(note_before_commit, 0)
        self.assertEqual(session.count('clearLinkedMiniProgramAccountNote()'), 2)
        self.assertIn('clearLinkedMiniProgramAccountNote(); roamArea=nil;searchMapSelection.select(nil);token=nil;account=nil;isWorking=false;errorKey=nil', session)
        self.assertIn('clearLinkedMiniProgramAccountNote(); roamArea=nil;searchMapSelection.select(nil);token=nil;account=nil;isWorking=false;errorKey="auth.expired"', session)
        phone = (ROOT/'Core/AuthChannelService.swift').read_text()
        self.assertIn('return LoginResult(token: token, account: account)', phone)
        self.assertNotIn('linkedMiniProgram: true', phone)
        view = (ROOT/'App/WeChatAppAuthSection.swift').read_text()
        self.assertIn('.accessibilityIdentifier("auth.wechat.linkedMiniProgram")', view)
        self.assertIn('session.clearLinkedMiniProgramAccountNote()', view)
        catalog = json.loads((ROOT/'Resources/Localizable.xcstrings').read_text())
        for key in ('auth.wechat.linkedMiniProgram', 'auth.wechat.linkedMiniProgram.dismiss'):
            entry = catalog['strings'][key]
            for language in ('en', 'zh-Hans'):
                self.assertTrue(entry['localizations'][language]['stringUnit']['value'])
if __name__ == '__main__': unittest.main()
