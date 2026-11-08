import XCTest
import UIKit
import UniformTypeIdentifiers
#if canImport(QuestifyApp)
@testable import QuestifyApp
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
#else
@testable import Questify
#endif

/// Accessibility and hardening wave (FP-A*, FP-M5..M7, FP-M12).
@MainActor
final class AccessibilityHardeningWaveTests: XCTestCase {
    // FP-A4
    func testLocationMapValueJoinsDistinctNonEmptyParts() {
        XCTAssertEqual(ActivityLocationAccessibility.value(name: "Park", addressName: "North Gate", address: "1 Main St"),
                       "Park, North Gate, 1 Main St")
        XCTAssertEqual(ActivityLocationAccessibility.value(name: "Park", addressName: " Park ", address: nil), "Park")
        XCTAssertEqual(ActivityLocationAccessibility.value(name: " ", addressName: "", address: "1 Main St"), "1 Main St")
        XCTAssertEqual(ActivityLocationAccessibility.value(name: "", addressName: nil, address: nil), "")
    }

    // FP-A5
    func testWalletAnnouncementOnlyAfterLoadCompletesWithValue() {
        XCTAssertTrue(WalletLoadAnnouncement.shouldAnnounce(wasLoading: true, isLoading: false, hasValue: true))
        XCTAssertFalse(WalletLoadAnnouncement.shouldAnnounce(wasLoading: true, isLoading: false, hasValue: false))
        XCTAssertFalse(WalletLoadAnnouncement.shouldAnnounce(wasLoading: true, isLoading: true, hasValue: true))
    }

    func testWalletAnnouncementCarriesNoAmountAndFollowsLocale() {
        XCTAssertEqual(WalletLoadAnnouncement.text(locale: Locale(identifier: "en")), "Wallet figures updated")
        XCTAssertEqual(WalletLoadAnnouncement.text(locale: Locale(identifier: "zh-Hans")), "钱包数据已更新")
    }

    // FP-A6
    func testSeriesDateRemovalLabelNamesRowAndDate() {
        XCTAssertEqual(ClubSeriesScheduleRemovalCopy.rowLabel(position: 3, day: "2026-12-01", locale: Locale(identifier: "en")),
                       "Remove date 3, 2026-12-01")
        XCTAssertEqual(ClubSeriesScheduleRemovalCopy.rowLabel(position: 3, day: "2026-12-01", locale: Locale(identifier: "zh-Hans")),
                       "移除第 3 个日期 2026-12-01")
        XCTAssertTrue(ClubSeriesScheduleRemovalCopy.confirmTitle(day: "2026-12-01", locale: Locale(identifier: "en")).contains("2026-12-01"))
    }

    // FP-M5
    private final class RecordingBoard: PasteboardWriting {
        var items: [[String: Any]] = []
        var options: [UIPasteboard.OptionsKey: Any] = [:]
        func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
            self.items = items; self.options = options
        }
    }

    func testLocalPasteboardCopiesLocalOnlyWithExpiry() {
        let board = RecordingBoard()
        let now = Date(timeIntervalSince1970: 1_000)
        LocalPasteboard.copy("ORDER-1", now: now, to: board)
        XCTAssertEqual(board.items.first?[UTType.utf8PlainText.identifier] as? String, "ORDER-1")
        XCTAssertEqual(board.options[.localOnly] as? Bool, true)
        XCTAssertEqual(board.options[.expirationDate] as? Date, now.addingTimeInterval(LocalPasteboard.defaultLifetime))
    }

    func testLocalPasteboardHonoursCustomLifetime() {
        let board = RecordingBoard()
        let now = Date(timeIntervalSince1970: 50)
        LocalPasteboard.copy("x", lifetime: 30, now: now, to: board)
        XCTAssertEqual(board.options[.expirationDate] as? Date, now.addingTimeInterval(30))
    }
}
