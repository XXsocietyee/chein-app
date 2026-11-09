#if DEBUG
import Foundation

/// DEBUG-only inventory of design-fixture symbols that must not be compiled into Release.
///
/// Every source in `App/DesignFixtures`, including this audit, is wrapped in `#if DEBUG`
/// and named by the Questify app target's Release `EXCLUDED_SOURCE_FILE_NAMES`.
/// `tools/check_design_fixture_release_exclusion.py` reads `symbols` and fails when any
/// of those identifiers survives in the app target's Release source projection.
/// This audit is a source gate. It does not compile or run a Release build.
enum DesignFixtureReleaseExclusionAudit {
    static let symbols: [String] = [
        "ConsentFixture",
        "D2Fixture",
        "D4ChannelsHost",
        "D4ClubFixture",
        "D4ConfirmHost",
        "D4MeFixture",
        "D4MemoryBlockedStore",
        "DesignFixtureRegistry",
        "DesignFixtureReleaseExclusionAudit",
        "E5Fixtures",
        "KitGalleryFixture",
        "LoginFixture",
        "OrdersWalletFixtures",
        "WelcomeFixture",
        "WelcomeMenuFixture",
    ]

    static func contains(_ symbol: String) -> Bool {
        symbols.contains(symbol)
    }
}
#endif
