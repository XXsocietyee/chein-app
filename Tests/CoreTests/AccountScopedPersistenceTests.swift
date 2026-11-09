import XCTest
@testable import QuestifyCore

final class AccountScopedPersistenceTests: XCTestCase {
    private let namespace = "questify.session.v2.abc+def"
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "cb37-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func testSchemaVersionsAndReaderKeys() {
        XCTAssertEqual(AccountScopedPersistence.playContinuationSchema, 2)
        XCTAssertEqual(AccountScopedPersistence.ledgerSchema, 1)
        XCTAssertEqual(AccountScopedPersistence.continuationRoles, ["player", "club", "merchant"])
        let keys = AccountScopedPersistence.legacyKeys(namespace: namespace, accountID: 8, role: "player")
        XCTAssertEqual(keys?.scopes, "play.continuation.\(namespace).8.player.scopes")
        XCTAssertEqual(keys?.titles, "play.continuation.\(namespace).8.player.titles")
        XCTAssertEqual(keys?.envelope, "play.continuation.\(namespace).8.player.envelope")
        XCTAssertNil(AccountScopedPersistence.legacyKeys(namespace: "", accountID: 8, role: "player"))
        XCTAssertNil(AccountScopedPersistence.legacyKeys(namespace: namespace, accountID: 0, role: "player"))
        XCTAssertNil(AccountScopedPersistence.legacyKeys(namespace: namespace, accountID: 8, role: "guest"))
        XCTAssertNil(AccountScopedPersistence.ledgerKey(namespace: namespace, accountID: 0))
    }

    func testClassifyAuthorizesDeletionOnlyForADifferentAccount() {
        XCTAssertNil(AccountPersistenceTransition.classify(rememberedAccountID: nil, nextAccountID: nil))
        XCTAssertNil(AccountPersistenceTransition.classify(rememberedAccountID: 0, nextAccountID: -1))
        XCTAssertEqual(AccountPersistenceTransition.classify(rememberedAccountID: 7, nextAccountID: nil), .logout(rememberedAccountID: 7))
        XCTAssertEqual(AccountPersistenceTransition.classify(rememberedAccountID: 7, nextAccountID: 0), .logout(rememberedAccountID: 7))
        XCTAssertEqual(AccountPersistenceTransition.classify(rememberedAccountID: nil, nextAccountID: 7), .firstLogin(accountID: 7))
        XCTAssertEqual(AccountPersistenceTransition.classify(rememberedAccountID: 0, nextAccountID: 8), .firstLogin(accountID: 8))
        XCTAssertEqual(AccountPersistenceTransition.classify(rememberedAccountID: 7, nextAccountID: 7), .sameAccount(accountID: 7))
        XCTAssertEqual(AccountPersistenceTransition.classify(rememberedAccountID: 7, nextAccountID: 8), .accountSwitch(from: 7, to: 8))
        XCTAssertFalse(AccountPersistenceTransition.logout(rememberedAccountID: 7).authorizesDeletion)
        XCTAssertFalse(AccountPersistenceTransition.firstLogin(accountID: 7).authorizesDeletion)
        XCTAssertFalse(AccountPersistenceTransition.sameAccount(accountID: 7).authorizesDeletion)
        XCTAssertFalse(AccountPersistenceTransition.accountSwitch(from: 7, to: 7).authorizesDeletion)
        XCTAssertTrue(AccountPersistenceTransition.accountSwitch(from: 7, to: 8).authorizesDeletion)
    }

    func testLegacySchemaMigratesWithoutDeletingTheReaderKeys() throws {
        plantLegacy(accountID: 7, role: "player", scopes: ["activity:41"], titles: ["activity:41": "外滩暗影"])
        plantLegacy(accountID: 9, role: "merchant", scopes: ["topic:3"], titles: [:])
        defaults.set("en", forKey: "preferences.language")
        defaults.set(Data("keep".utf8), forKey: "questify.operations.pending.v1.keep")

        let first = AccountScopedPersistence.apply(.firstLogin(accountID: 7), namespace: namespace, defaults: defaults)
        XCTAssertEqual(first.deletedKeys, [])
        XCTAssertEqual(defaults.stringArray(forKey: playerKeys(7).scopes), ["activity:41"])
        XCTAssertEqual(defaults.dictionary(forKey: playerKeys(7).titles) as? [String: String], ["activity:41": "外滩暗影"])
        let migrated = try envelope(playerKeys(7).envelope)
        XCTAssertEqual(migrated["schemaVersion"] as? Int, 2)
        XCTAssertEqual(migrated["scopes"] as? [String], ["activity:41"])
        XCTAssertEqual(migrated["titles"] as? [String: String], ["activity:41": "外滩暗影"])
        let recordedLedger = try ledger(7)
        XCTAssertEqual(recordedLedger["schemaVersion"] as? Int, 1)
        XCTAssertEqual(recordedLedger["playContinuation"] as? Int, 2)
        XCTAssertNil(defaults.data(forKey: AccountScopedPersistence.ledgerKey(namespace: namespace, accountID: 9)!))
        XCTAssertEqual(defaults.stringArray(forKey: roleKeys(9, "merchant").scopes), ["topic:3"])
        XCTAssertEqual(defaults.string(forKey: "preferences.language"), "en")
        XCTAssertEqual(defaults.data(forKey: "questify.operations.pending.v1.keep"), Data("keep".utf8))

        let again = AccountScopedPersistence.apply(.sameAccount(accountID: 7), namespace: namespace, defaults: defaults)
        XCTAssertEqual(again, .none)
        XCTAssertEqual(AccountScopedPersistence.apply(.logout(rememberedAccountID: 7), namespace: namespace, defaults: defaults), .none)
        XCTAssertEqual(defaults.stringArray(forKey: playerKeys(7).scopes), ["activity:41"])
        XCTAssertNotNil(defaults.data(forKey: playerKeys(7).envelope))
    }

    func testExistingSchema2EnvelopeIsNotReplacedByOlderReaderKeys() throws {
        plantLegacy(accountID: 7, role: "player", scopes: ["activity:1"], titles: ["activity:1": "old"])
        let keys = playerKeys(7)
        let newer = try JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "scopes": ["activity:2"], "titles": ["activity:2": "new"]], options: [.sortedKeys])
        defaults.set(newer, forKey: keys.envelope)
        let effect = AccountScopedPersistence.apply(.firstLogin(accountID: 7), namespace: namespace, defaults: defaults)
        XCTAssertEqual(effect.deletedKeys, [])
        XCTAssertFalse(effect.writtenKeys.contains(keys.envelope))
        XCTAssertEqual(defaults.data(forKey: keys.envelope), newer)
        XCTAssertEqual(defaults.stringArray(forKey: keys.scopes), ["activity:1"])
        XCTAssertEqual(try ledger(7)["schemaVersion"] as? Int, 1)
    }

    func testRecordContinuationRefreshesSchema2AndDoesNotDelete() throws {
        plantLegacy(accountID: 7, role: "club", scopes: ["topic:4"], titles: [:])
        defaults.set(Data("keep".utf8), forKey: "questify.operations.pending.v1.keep")
        let first = AccountScopedPersistence.recordContinuation(namespace: namespace, accountID: 7, role: "club", defaults: defaults)
        XCTAssertEqual(first.deletedKeys, [])
        XCTAssertEqual(try envelope(roleKeys(7, "club").envelope)["scopes"] as? [String], ["topic:4"])
        defaults.set(["topic:4", "topic:5"], forKey: roleKeys(7, "club").scopes)
        defaults.set(["topic:5": "第二"], forKey: roleKeys(7, "club").titles)
        let second = AccountScopedPersistence.recordContinuation(namespace: namespace, accountID: 7, role: "club", defaults: defaults)
        XCTAssertEqual(second.deletedKeys, [])
        let refreshed = try envelope(roleKeys(7, "club").envelope)
        XCTAssertEqual(refreshed["schemaVersion"] as? Int, 2)
        XCTAssertEqual(refreshed["scopes"] as? [String], ["topic:4", "topic:5"])
        XCTAssertEqual(refreshed["titles"] as? [String: String], ["topic:5": "第二"])
        XCTAssertEqual(defaults.stringArray(forKey: roleKeys(7, "club").scopes), ["topic:4", "topic:5"])
        XCTAssertEqual(defaults.data(forKey: "questify.operations.pending.v1.keep"), Data("keep".utf8))
        XCTAssertEqual(AccountScopedPersistence.recordContinuation(namespace: namespace, accountID: 7, role: "guest", defaults: defaults), .none)
    }

    func testAccountSwitchWipesOnlyThePreviousAccountAndRecoversTheNext() throws {
        plantLegacy(accountID: 7, role: "player", scopes: ["activity:41"], titles: ["activity:41": "外滩暗影"])
        plantLegacy(accountID: 7, role: "merchant", scopes: ["activity:70"], titles: [:])
        plantLegacy(accountID: 8, role: "player", scopes: ["activity:80"], titles: ["activity:80": "新"])
        plantLegacy(accountID: 9, role: "player", scopes: ["topic:9"], titles: [:])
        defaults.set("zh-Hans", forKey: "preferences.language")
        defaults.set(Data("receipt".utf8), forKey: "questify.operations.pending.v1.keep")
        _ = AccountScopedPersistence.apply(.firstLogin(accountID: 7), namespace: namespace, defaults: defaults)
        XCTAssertNotNil(defaults.data(forKey: playerKeys(7).envelope))

        let effect = AccountScopedPersistence.apply(.accountSwitch(from: 7, to: 8), namespace: namespace, defaults: defaults)
        XCTAssertTrue(effect.deletedKeys.contains(playerKeys(7).scopes))
        XCTAssertTrue(effect.deletedKeys.contains(playerKeys(7).titles))
        XCTAssertTrue(effect.deletedKeys.contains(playerKeys(7).envelope))
        XCTAssertTrue(effect.deletedKeys.contains(roleKeys(7, "merchant").scopes))
        XCTAssertTrue(effect.deletedKeys.contains(AccountScopedPersistence.ledgerKey(namespace: namespace, accountID: 7)!))
        XCTAssertFalse(effect.deletedKeys.contains(playerKeys(8).scopes))
        XCTAssertFalse(effect.deletedKeys.contains(playerKeys(9).scopes))
        XCTAssertNil(defaults.object(forKey: playerKeys(7).scopes))
        XCTAssertNil(defaults.object(forKey: playerKeys(7).titles))
        XCTAssertNil(defaults.object(forKey: playerKeys(7).envelope))
        XCTAssertNil(defaults.object(forKey: roleKeys(7, "merchant").scopes))
        XCTAssertNil(defaults.object(forKey: AccountScopedPersistence.ledgerKey(namespace: namespace, accountID: 7)!))
        XCTAssertEqual(defaults.stringArray(forKey: playerKeys(8).scopes), ["activity:80"])
        XCTAssertEqual(try envelope(playerKeys(8).envelope)["titles"] as? [String: String], ["activity:80": "新"])
        XCTAssertEqual(try ledger(8)["playContinuation"] as? Int, 2)
        XCTAssertEqual(defaults.stringArray(forKey: playerKeys(9).scopes), ["topic:9"])
        XCTAssertNil(defaults.data(forKey: playerKeys(9).envelope))
        XCTAssertEqual(defaults.string(forKey: "preferences.language"), "zh-Hans")
        XCTAssertEqual(defaults.data(forKey: "questify.operations.pending.v1.keep"), Data("receipt".utf8))
    }

    func testLogoutSameAccountAndEmptyNamespaceDoNotWipe() throws {
        plantLegacy(accountID: 7, role: "player", scopes: ["activity:41"], titles: ["activity:41": "外滩暗影"])
        _ = AccountScopedPersistence.apply(.firstLogin(accountID: 7), namespace: namespace, defaults: defaults)
        let before = defaults.data(forKey: playerKeys(7).envelope)
        XCTAssertEqual(AccountScopedPersistence.apply(.logout(rememberedAccountID: 7), namespace: namespace, defaults: defaults), .none)
        XCTAssertEqual(AccountScopedPersistence.apply(.sameAccount(accountID: 7), namespace: namespace, defaults: defaults), .none)
        XCTAssertEqual(AccountScopedPersistence.apply(.accountSwitch(from: 7, to: 7), namespace: "", defaults: defaults), .none)
        XCTAssertEqual(AccountScopedPersistence.apply(.accountSwitch(from: 7, to: 7), namespace: namespace, defaults: defaults).deletedKeys, [])
        XCTAssertEqual(defaults.data(forKey: playerKeys(7).envelope), before)
        XCTAssertEqual(defaults.stringArray(forKey: playerKeys(7).scopes), ["activity:41"])
    }

    func testFutureSchemaIsNotMigratedOrWiped() throws {
        plantLegacy(accountID: 7, role: "player", scopes: ["activity:41"], titles: [:])
        let future = try JSONSerialization.data(withJSONObject: ["schemaVersion": 3, "scopes": ["activity:41"], "titles": [:]], options: [.sortedKeys])
        defaults.set(future, forKey: playerKeys(7).envelope)
        let futureLedger = try JSONSerialization.data(withJSONObject: ["playContinuation": 3, "schemaVersion": 2], options: [.sortedKeys])
        defaults.set(futureLedger, forKey: AccountScopedPersistence.ledgerKey(namespace: namespace, accountID: 7)!)
        let migrated = AccountScopedPersistence.apply(.firstLogin(accountID: 7), namespace: namespace, defaults: defaults)
        XCTAssertEqual(migrated, .none)
        XCTAssertEqual(defaults.data(forKey: playerKeys(7).envelope), future)
        let recorded = AccountScopedPersistence.recordContinuation(namespace: namespace, accountID: 7, role: "player", defaults: defaults)
        XCTAssertEqual(recorded, .none)
        let wiped = AccountScopedPersistence.apply(.accountSwitch(from: 7, to: 8), namespace: namespace, defaults: defaults)
        XCTAssertEqual(wiped.deletedKeys, [])
        XCTAssertEqual(defaults.data(forKey: playerKeys(7).envelope), future)
        XCTAssertEqual(defaults.stringArray(forKey: playerKeys(7).scopes), ["activity:41"])
        XCTAssertEqual(defaults.data(forKey: AccountScopedPersistence.ledgerKey(namespace: namespace, accountID: 7)!), futureLedger)
        XCTAssertNil(defaults.object(forKey: playerKeys(8).scopes))
        XCTAssertNil(defaults.data(forKey: playerKeys(8).envelope))
    }

    func testCorruptReaderKeysStayOnMigrationAndClearOnAccountSwitch() {
        let keys = playerKeys(7)
        defaults.set(Data("not-an-array".utf8), forKey: keys.scopes)
        defaults.set("en", forKey: "preferences.language")
        let migrated = AccountScopedPersistence.apply(.sameAccount(accountID: 7), namespace: namespace, defaults: defaults)
        XCTAssertEqual(migrated.deletedKeys, [])
        XCTAssertEqual(defaults.data(forKey: keys.scopes), Data("not-an-array".utf8))
        XCTAssertNil(defaults.data(forKey: keys.envelope))
        let wiped = AccountScopedPersistence.apply(.accountSwitch(from: 7, to: 8), namespace: namespace, defaults: defaults)
        XCTAssertEqual(wiped.deletedKeys, [keys.scopes])
        XCTAssertNil(defaults.object(forKey: keys.scopes))
        XCTAssertNil(defaults.object(forKey: playerKeys(8).scopes))
        XCTAssertEqual(defaults.string(forKey: "preferences.language"), "en")
    }

    private func playerKeys(_ accountID: Int) -> PlayContinuationLegacyKeys {
        roleKeys(accountID, "player")
    }

    private func roleKeys(_ accountID: Int, _ role: String) -> PlayContinuationLegacyKeys {
        AccountScopedPersistence.legacyKeys(namespace: namespace, accountID: accountID, role: role)!
    }

    private func plantLegacy(accountID: Int, role: String, scopes: [String], titles: [String: String]) {
        let keys = roleKeys(accountID, role)
        defaults.set(scopes, forKey: keys.scopes)
        if !titles.isEmpty { defaults.set(titles, forKey: keys.titles) }
    }

    private func envelope(_ key: String) throws -> [String: Any] {
        let data = try XCTUnwrap(defaults.data(forKey: key))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func ledger(_ accountID: Int) throws -> [String: Any] {
        try envelope(AccountScopedPersistence.ledgerKey(namespace: namespace, accountID: accountID)!)
    }
}
