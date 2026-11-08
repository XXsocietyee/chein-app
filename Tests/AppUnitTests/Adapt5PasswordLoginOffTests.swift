import XCTest
@testable import Questify

/// ADAPT-5 job A. Tests run in Debug, where the password capability gate is intentionally still compiled.
/// The shipped (non-DEBUG) configuration is therefore proven structurally: the compile-time markers exist at
/// every entry point, and phone / WeChat / Apple entries remain. No network, no provider.
@MainActor final class Adapt5PasswordLoginOffTests: XCTestCase {
    private func source(_ relative: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        var url = URL(fileURLWithPath: "\(file)")
        url.deleteLastPathComponent(); url.deleteLastPathComponent(); url.deleteLastPathComponent()
        return try String(contentsOf: url.appendingPathComponent(relative), encoding: .utf8)
    }

    func testCompileTimeSwitchMatchesBuildConfiguration() {
#if DEBUG
        XCTAssertTrue(AppSession.passwordLoginCompiledIn)
#else
        XCTAssertFalse(AppSession.passwordLoginCompiledIn)
#endif
    }

    func testCanUsePasswordIsCompiledToFalseOutsideDebug() throws {
        let session = try source("App/AppSession.swift")
        let body = try XCTUnwrap(session.components(separatedBy: "    var canUsePassword:Bool {").dropFirst().first)
            .components(separatedBy: "    var supportsDomesticPhoneInput").first ?? ""
        XCTAssertTrue(body.contains("#if DEBUG"))
        XCTAssertTrue(body.contains("#else\n        false\n#endif"))
        // The only capability-based expression lives in the DEBUG branch.
        let release = body.components(separatedBy: "#else").last ?? ""
        XCTAssertFalse(release.contains("availability(of:.usernamePassword)"))
    }

    func testAuthServiceIsNeverCreatedForPasswordOutsideDebug() throws {
        let session = try source("App/AppSession.swift")
        XCTAssertTrue(session.contains("#if DEBUG\n            service=regional.availability(of:.usernamePassword) == .available ? AuthService("))
        XCTAssertTrue(session.contains("#else\n            service=nil\n#endif"))
    }

    func testLoginMethodRejectsBeforeTouchingTheServiceOutsideDebug() throws {
        let session = try source("App/AppSession.swift")
        let login = try XCTUnwrap(session.components(separatedBy: "    func login(username:String,password:String) async {").dropFirst().first)
        let guardIndex = try XCTUnwrap(login.range(of: "guard Self.passwordLoginCompiledIn else { errorKey=\"auth.notConfigured\";return }"))
        let serviceIndex = try XCTUnwrap(login.range(of: "service.login(username:username,password:password)"))
        XCTAssertLessThan(guardIndex.lowerBound, serviceIndex.lowerBound)
    }

    func testOnlyAppSessionLoginCallsAuthServicePasswordRoute() throws {
        let root = try source("App/AppCompositionRoot.swift")
        XCTAssertFalse(root.contains("AuthEndpoint.password,"))
        let loginView = try source("App/LoginView.swift")
        let calls = loginView.components(separatedBy: "session.login(").count - 1
        XCTAssertEqual(calls, 1)
        // The single UI call is behind the same gate that is false in release.
        XCTAssertTrue(loginView.contains("guard session.canUsePassword, !session.isWorking"))
        XCTAssertTrue(loginView.contains("if session.canUsePassword {"))
    }

    func testPhoneWeChatAndAppleEntriesRemain() throws {
        let loginView = try source("App/LoginView.swift")
        XCTAssertTrue(loginView.contains("auth.otherChannels"))
        XCTAssertTrue(loginView.contains("auth.channels.phoneTitle"))
        XCTAssertTrue(loginView.contains("WeChatAppAuthSection("))
        XCTAssertTrue(loginView.contains("AuthChannelView("))
        let channels = try source("App/AuthChannelView.swift")
        XCTAssertTrue(channels.contains("auth.channels.phoneSignIn"))
        XCTAssertTrue(channels.contains("auth.channels.sendCode"))
        XCTAssertTrue(channels.contains("auth.channels.appleSignIn"))
    }

    func testBackendRouteStaysInCoreAndTestsAreUntouched() throws {
        let core = try source("Core/AuthService.swift")
        XCTAssertTrue(core.contains("execute(.password"))
        let api = try source("Core/APIConfiguration.swift")
        XCTAssertTrue(api.contains("case password = \"api/login\""))
    }
}
