import XCTest
@testable import QuestifyCore

final class WP11ScopedCacheKeyTests: XCTestCase {
    private func key(_ account: String = "a1", _ object: String = "o1",
                     _ privacy: ScopedCacheKey.Privacy = .accountPrivate, _ version: String = "v1") -> ScopedCacheKey {
        ScopedCacheKey(accountID: account, objectID: object, privacy: privacy, contentVersion: version)!
    }

    func testKeyDiffersByAccountObjectPrivacyAndVersion() {
        let base = key()
        XCTAssertNotEqual(base, key("a2"))
        XCTAssertNotEqual(base, key("a1", "o2"))
        XCTAssertNotEqual(base, key("a1", "o1", .publicContent))
        XCTAssertNotEqual(base, key("a1", "o1", .accountPrivate, "v2"))
        let names = Set([base, key("a2"), key("a1", "o2"), key("a1", "o1", .publicContent), key("a1", "o1", .accountPrivate, "v2")].map(\.storageName))
        XCTAssertEqual(names.count, 5)
        XCTAssertNil(ScopedCacheKey(accountID: " ", objectID: "o", privacy: .publicContent, contentVersion: "v"))
        XCTAssertNotEqual(key("a|b", "c").storageName, key("a", "b|c").storageName)
    }

    func testRevokedShareImageNotReusable() {
        var index = ScopedCacheIndex()
        let share = key("a1", "share-9", .shareLink, "v1")
        XCTAssertTrue(index.insert(share))
        XCTAssertTrue(index.isReusable(share))
        let purged = index.revoke(objectID: "share-9", privacy: .shareLink)
        XCTAssertEqual(purged, [share])
        XCTAssertFalse(index.isReusable(share))
        XCTAssertFalse(index.insert(key("a1", "share-9", .shareLink, "v2")))
    }

    func testLogoutPurgesAccountKeys() {
        var index = ScopedCacheIndex()
        index.insert(key("a1", "o1"))
        index.insert(key("a1", "o2"))
        index.insert(key("a2", "o1"))
        XCTAssertEqual(ImageAndVideoDiskCacheBudgetAudit.foreignKeys(in: index, ownedBy: "a1").count, 1)
        let purged = index.purgeAccount("a1")
        XCTAssertEqual(purged.count, 2)
        XCTAssertEqual(index.liveKeys, [key("a2", "o1")])
        XCTAssertFalse(index.isReusable(key("a1", "o1")))
    }
}
