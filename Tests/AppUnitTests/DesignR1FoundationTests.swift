import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import Questify

/// Design hand-off r1 foundation: handbook token fixes, the neutral tab selection, the player kit button,
/// the status tag, unknown values and the resizable sheet detent table (review/full-player.md §2–§3).
@MainActor
final class DesignR1FoundationTests: XCTestCase {
    private func rgba(_ color: Color, scheme: ColorScheme) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
        #else
        return nil
        #endif
    }

    private func assertHex(_ color: Color, _ hex: UInt32, alpha: CGFloat = 1, scheme: ColorScheme, _ message: String, line: UInt = #line) {
        guard let c = rgba(color, scheme: scheme) else { return }
        XCTAssertEqual(c.r, CGFloat((hex >> 16) & 0xFF) / 255, accuracy: 0.02, message, line: line)
        XCTAssertEqual(c.g, CGFloat((hex >> 8) & 0xFF) / 255, accuracy: 0.02, message, line: line)
        XCTAssertEqual(c.b, CGFloat(hex & 0xFF) / 255, accuracy: 0.02, message, line: line)
        XCTAssertEqual(c.a, alpha, accuracy: 0.02, message, line: line)
    }

    // MARK: Handbook fixes (owner ruling 5)

    func testLightHandbookFixesAreAdopted() {
        let light = CYDomainPalette(.merchant)
        assertHex(light.borderStrong, 0x8C8C8C, scheme: .light, "border-strong #8C8C8C")
        assertHex(light.inputIdleBg, 0xEFEFEF, scheme: .light, "input in a card #EFEFEF")
        assertHex(light.inputIdleBgOnPage, 0xE4E4E4, scheme: .light, "input on the page #E4E4E4")
        assertHex(light.inputFilledBg, 0xEFEFEF, scheme: .light, "a filled input keeps its fill")
        assertHex(light.successSoft, 0x0B7A57, alpha: 0.18, scheme: .light, "success soft 18%")
        assertHex(light.warningSoft, 0x96610A, alpha: 0.18, scheme: .light, "warning soft 18%")
        assertHex(light.dangerSoft, 0xD0323B, alpha: 0.18, scheme: .light, "danger soft 18%")
        assertHex(light.infoSoft, 0x2563EB, alpha: 0.18, scheme: .light, "info soft 18%")
        assertHex(light.homeFeedCount, 0xC2410C, scheme: .light, "feed count #C2410C")
        assertHex(CYDomainPalette(.player).homeFeedCount, 0xC2410C, scheme: .dark, "feed count #C2410C on player")
    }

    func testDarkPlayerTokensAreUnchanged() {
        let dark = CYDomainPalette(.player)
        assertHex(dark.borderStrong, 0xFFFFFF, alpha: 0.16, scheme: .dark, "player border-strong stays white 16%")
        assertHex(dark.successSoft, 0x22C55E, alpha: 0.14, scheme: .dark, "player success soft stays 14%")
    }

    // MARK: Tab bar (PL-01)

    func testSelectedTabIsNeutralInkWithA12PercentCapsule() {
        for domain in [ThemeDomain.player, .merchant] {
            let palette = CYDomainPalette(domain)
            let scheme = domain.colorScheme
            assertHex(palette.tabSelectedTint, domain == .player ? 0xF8F8F8 : 0x000000, scheme: scheme, "\(domain) selected tab ink")
            assertHex(palette.tabSelectedCapsule, domain == .player ? 0xF8F8F8 : 0x000000, alpha: 0.12, scheme: scheme, "\(domain) capsule 12%")
        }
    }

    func testPlayerTabsCarryTheFiveMiniProgramLabels() {
        XCTAssertEqual(RootTab.playerTabs.map(\.playerTitleKey), ["tabBar.home", "tabBar.roam", "tabBar.publish", "tabBar.club", "tabBar.mine"])
        XCTAssertEqual(CYDomainTabIcons.icon(for: .home, domain: .player), CYDomainTabIcon(idle: "images_icon_f1", selected: "images_icon_f01d", selectedIsOriginal: true))
        XCTAssertEqual(CYDomainTabIcons.icon(for: .mine, domain: .player).idle, "images_icon_f5")
        XCTAssertEqual(CYDomainTabIcons.titleKey(for: .mine, domain: .player), "tabBar.mine")
    }

    // MARK: Player/Button (PL-10, PL-12)

    func testPlayerPrimaryIsAWhitePillAndSecondaryADarkPill() {
        let player = CYDomainPalette(.player)
        let primary = CYPillButtonStyle.tokens(style: .primary, isEnabled: true, in: player)
        assertHex(primary.fill, 0xF8F8F8, scheme: .dark, "primary white pill")
        assertHex(primary.foreground, 0x0A0A0A, scheme: .dark, "primary black label")
        let secondary = CYPillButtonStyle.tokens(style: .secondary, isEnabled: true, in: player)
        assertHex(secondary.fill, 0x1C1C1E, scheme: .dark, "secondary #1C1C1E pill")
        assertHex(secondary.foreground, 0xFFFFFF, scheme: .dark, "secondary white label (system label), never dark on grey")
        let onSheet = CYPillButtonStyle.tokens(style: .secondary, isEnabled: true, in: player, onSheet: true)
        assertHex(onSheet.fill, 0x3B3B3D, scheme: .dark, "secondary steps up to surface-3 on a sheet")
        let tertiary = CYPillButtonStyle.tokens(style: .tertiary, isEnabled: true, in: player)
        assertHex(tertiary.foreground, 0xFFFFFF, alpha: 0.7, scheme: .dark, "tertiary text at 70% of the system label")
        let merchant = CYPillButtonStyle.tokens(style: .primary, isEnabled: true, in: CYDomainPalette(.merchant))
        assertHex(merchant.fill, 0x000000, scheme: .light, "merchant primary black pill")
    }

    // MARK: Status tag (PL-14)

    func testStatusTagsAlwaysCarryAnIconAndAWord() {
        XCTAssertEqual(CYStatusTag.Word.recording.state, .live)
        XCTAssertEqual(CYStatusTag.Word.paused.state, .paused)
        XCTAssertEqual(CYStatusTag.Word.locating.systemImage, "location")
        XCTAssertEqual(Set(CYStatusTagState.allCases.map(\.systemImage)).count, CYStatusTagState.allCases.count)
        XCTAssertEqual(CYStatusTagState.paused.tone, .neutral)
        XCTAssertEqual(CYStatusTagState.warning.tone, .warning)
    }

    // MARK: Unknown values (§2)

    func testUnknownValuesReadDashNeverZero() {
        XCTAssertEqual(CYUnknownValue.count(nil), "—")
        XCTAssertEqual(CYUnknownValue.count(0), "0")
        XCTAssertEqual(CYUnknownValue.count(38), "38")
        XCTAssertEqual(CYUnknownValue.string("  "), "—")
        XCTAssertEqual(CYUnknownValue.string(nil), "—")
        XCTAssertEqual(CYUnknownValue.string("武康大楼"), "武康大楼")
    }

    // MARK: Resizable sheets (§3)

    func testDetentTableMatchesTheHandOff() {
        XCTAssertEqual(CYSheetKind.propertyCard.sizes, [.fit, .large])
        XCTAssertEqual(CYSheetKind.district.sizes, [.height(96), .medium, .large])
        XCTAssertEqual(CYSheetKind.roamNearby.sizes, [.height(64), .medium, .large])
        XCTAssertEqual(CYSheetKind.liveRoam.sizes, [.height(120), .medium])
        XCTAssertEqual(CYSheetKind.teamChat.sizes, [.medium, .large])
        XCTAssertEqual(CYSheetKind.hint.sizes, [.medium, .large], "提示 396:4404: medium / large (r4)")
        XCTAssertEqual(CYSheetKind.ticketType.sizes, [.fit])
        XCTAssertEqual(CYSheetKind.released.sizes, [.fit])
        XCTAssertEqual(CYSheetKind.login.sizes, [.large])
        XCTAssertEqual(CYSheetKind.editorNode.sizes, [.fraction(0.62), .large])
        XCTAssertEqual(CYSheetKind.editorTextName.sizes, [.height(200), .large])
        XCTAssertTrue(CYSheetKind.roamNearby.mapInteractive)
        XCTAssertTrue(CYSheetKind.liveRoam.mapInteractive)
        XCTAssertFalse(CYSheetKind.hint.mapInteractive)
        XCTAssertFalse(CYSheetKind.editorList.mapInteractive)
    }

    func testFitIsTheContentHeightCappedAt62Percent() {
        XCTAssertEqual(CYSheetSize.fitCap, 0.62, accuracy: 0.0001)
        XCTAssertEqual(CYResizableSheet<EmptyView>.fitHeight(content: 300, chrome: 120, cap: 528), 420)
        XCTAssertEqual(CYResizableSheet<EmptyView>.fitHeight(content: 900, chrome: 120, cap: 528), 528)
        XCTAssertEqual(CYResizableSheet<EmptyView>.fitHeight(content: 0, chrome: 0, cap: 528), 240)
    }

    func testContentScrollsOnlyAtTheLargestDetent() {
        XCTAssertFalse(CYResizableSheet<EmptyView>.scrollEnabled(sizes: [.medium, .large], atLargest: false, natural: 2000, cap: 528))
        XCTAssertTrue(CYResizableSheet<EmptyView>.scrollEnabled(sizes: [.medium, .large], atLargest: true, natural: 100, cap: 528))
        XCTAssertFalse(CYResizableSheet<EmptyView>.scrollEnabled(sizes: [.fit], atLargest: true, natural: 400, cap: 528))
        XCTAssertTrue(CYResizableSheet<EmptyView>.scrollEnabled(sizes: [.fit], atLargest: true, natural: 600, cap: 528))
    }

    func testSheetHeaderGreyCloseCircle() {
        assertHex(CYSheetHeader.closeFill(in: CYDomainPalette(.player)), 0x3A3A3C, scheme: .dark, "player grey ✕")
        assertHex(CYSheetHeader.closeFill(in: CYDomainPalette(.merchant)), 0xEEEEEE, scheme: .light, "merchant grey ✕")
    }
}
