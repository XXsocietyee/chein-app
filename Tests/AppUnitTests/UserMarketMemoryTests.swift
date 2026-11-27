import XCTest
@testable import Questify

/// US launch r1, one-app (owner 2026-11-27): device-local hints for the per-user market.
final class UserMarketMemoryTests: XCTestCase {
    private func makeDefaults() throws -> (UserDefaults, () -> Void) {
        let name = "UserMarketMemoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    func testSignInCountryThenAccountRegionDecide() throws {
        let (defaults, cleanup) = try makeDefaults(); defer { cleanup() }
        XCTAssertEqual(UserMarketMemory.resolve(buildDefault: .china, defaults: defaults, deviceRegion: "US"), .unitedStates)
        XCTAssertEqual(UserMarketMemory.resolve(buildDefault: .china, defaults: defaults, deviceRegion: "FR"), .china)
        UserMarketMemory.recordSignIn(phoneCountry: .china, defaults: defaults)
        XCTAssertEqual(UserMarketMemory.resolve(buildDefault: .china, defaults: defaults, deviceRegion: "US"), .china)
        UserMarketMemory.recordAccountRegion("US", defaults: defaults)
        XCTAssertEqual(UserMarketMemory.resolve(buildDefault: .china, defaults: defaults, deviceRegion: "CN"), .unitedStates)
        UserMarketMemory.recordAccountRegion("garbage", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: UserMarketMemory.accountRegionKey), "US")
        // A new sign-in drops the previous account's region; Apple sign-in clears the phone hint too.
        UserMarketMemory.recordSignIn(phoneCountry: .unitedStates, defaults: defaults)
        XCTAssertNil(defaults.string(forKey: UserMarketMemory.accountRegionKey))
        XCTAssertEqual(UserMarketMemory.resolve(buildDefault: .china, defaults: defaults, deviceRegion: "CN"), .unitedStates)
        UserMarketMemory.recordSignIn(phoneCountry: nil, defaults: defaults)
        XCTAssertEqual(UserMarketMemory.resolve(buildDefault: .unitedStates, defaults: defaults, deviceRegion: "CN"), .china)
        // Never touches the language preference.
        XCTAssertNil(defaults.string(forKey: AppLanguage.storageKey))
    }
}
