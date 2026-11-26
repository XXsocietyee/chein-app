import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import Questify

@MainActor
final class DesignSystemTokenMappingTests: XCTestCase {
    private struct RGBA {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat
    }

    private func resolveRGBA(_ color: Color, scheme: ColorScheme) -> RGBA? {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let uiColor = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return RGBA(r: r, g: g, b: b, a: a)
        }
        if let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
           let converted = uiColor.cgColor.converted(to: sRGB, intent: .defaultIntent, options: nil),
           let components = converted.components {
            if components.count >= 4 {
                return RGBA(r: components[0], g: components[1], b: components[2], a: components[3])
            }
            if components.count == 2 {
                return RGBA(r: components[0], g: components[0], b: components[0], a: components[1])
            }
        }
        #endif
        return nil
    }

    private func assertColor(
        _ color: Color,
        matchesHex hex: UInt32,
        alpha expectedAlpha: CGFloat = 1.0,
        scheme: ColorScheme,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let rgba = resolveRGBA(color, scheme: scheme) else {
            return
        }
        let expectedR = CGFloat((hex >> 16) & 0xFF) / 255.0
        let expectedG = CGFloat((hex >> 8) & 0xFF) / 255.0
        let expectedB = CGFloat(hex & 0xFF) / 255.0
        let tolerance: CGFloat = 0.02
        XCTAssertEqual(rgba.r, expectedR, accuracy: tolerance, "R mismatch \(message)", file: file, line: line)
        XCTAssertEqual(rgba.g, expectedG, accuracy: tolerance, "G mismatch \(message)", file: file, line: line)
        XCTAssertEqual(rgba.b, expectedB, accuracy: tolerance, "B mismatch \(message)", file: file, line: line)
        XCTAssertEqual(rgba.a, expectedAlpha, accuracy: tolerance, "A mismatch \(message)", file: file, line: line)
    }

    private func assertSameColor(
        _ lhs: Color,
        _ rhs: Color,
        scheme: ColorScheme,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let a = resolveRGBA(lhs, scheme: scheme),
              let b = resolveRGBA(rhs, scheme: scheme) else {
            return
        }
        let tolerance: CGFloat = 0.015
        XCTAssertEqual(a.r, b.r, accuracy: tolerance, "R diff \(message)", file: file, line: line)
        XCTAssertEqual(a.g, b.g, accuracy: tolerance, "G diff \(message)", file: file, line: line)
        XCTAssertEqual(a.b, b.b, accuracy: tolerance, "B diff \(message)", file: file, line: line)
        XCTAssertEqual(a.a, b.a, accuracy: tolerance, "A diff \(message)", file: file, line: line)
    }

    private func isPurpleHue(_ color: Color, scheme: ColorScheme) -> Bool {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let uiColor = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var bri: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) else {
            return false
        }
        let degrees = hue * 360.0
        return alpha > 0.05 && sat > 0.25 && degrees >= 245.0 && degrees <= 295.0
        #else
        return false
        #endif
    }

    private func assertNotPurple(
        _ color: Color,
        scheme: ColorScheme,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            isPurpleHue(color, scheme: scheme),
            "Unexpected purple hue in \(label) (\(scheme))",
            file: file,
            line: line
        )
    }

    // MARK: - 1. Domain -> Theme & Light/Dark Tokens

    func testMerchantDomainGivesLightTokensAndPlayerGivesDarkTokens() {
        XCTAssertEqual(ThemeDomain.merchant.colorScheme, .light)
        XCTAssertEqual(ThemeDomain.topicEditor.colorScheme, .light)
        XCTAssertEqual(ThemeDomain.player.colorScheme, .dark)
        XCTAssertEqual(ThemeDomain.dark.colorScheme, .dark)
        XCTAssertEqual(ThemeDomain.game.colorScheme, .dark)

        let merchant = CYDomainPalette(.merchant)
        XCTAssertFalse(merchant.isDarkDomain)
        XCTAssertEqual(merchant.resolvedSurfaceDomain, .merchant)

        // Native iOS r2: player follows the system appearance; only the play stage is forced dark.
        XCTAssertNil(ThemeDomain.player.forcedColorScheme)
        XCTAssertNil(ThemeDomain.merchant.forcedColorScheme)
        XCTAssertEqual(ThemeDomain.game.forcedColorScheme, .dark)
        let player = CYDomainPalette(.player)
        XCTAssertFalse(player.isDarkDomain)
        XCTAssertTrue(player.followsSystem)
        XCTAssertEqual(player.resolvedSurfaceDomain, .player)

        let game = CYDomainPalette(.game)
        XCTAssertTrue(game.isDarkDomain)
        XCTAssertEqual(game.resolvedSurfaceDomain, .player)

        // Merchant light palette exact values from DESIGN.md / tokens.wxss
        // Native restyle (native-ios-r1 §2.2): page, surface, label tokens are the iOS semantic colours in the domain appearance.
        assertSameColor(merchant.bgPage, Color(uiColor: .systemGroupedBackground), scheme: .light, "merchant.bgPage")
        assertColor(merchant.bgPage, matchesHex: 0xF2F2F7, scheme: .light, "merchant.bgPage")
        assertColor(merchant.bgSurface, matchesHex: 0xFFFFFF, scheme: .light, "merchant.bgSurface")
        assertColor(merchant.bgElevated, matchesHex: 0xFFFFFF, scheme: .light, "merchant.bgElevated")
        // Native iOS r2 (82bcf2c2d): the primary action is the system accent with a white label.
        XCTAssertEqual(merchant.actionPrimaryBg, .accentColor, "merchant.actionPrimaryBg")
        XCTAssertEqual(merchant.actionPrimaryFg, .white, "merchant.actionPrimaryFg")
        assertColor(merchant.textPrimary, matchesHex: 0x000000, scheme: .light, "merchant.textPrimary")
        assertSameColor(merchant.textDisabled, Color(uiColor: .quaternaryLabel), scheme: .light, "merchant.textDisabled")
        assertColor(merchant.danger, matchesHex: 0xD0323B, scheme: .light, "merchant.danger")
        assertColor(merchant.actionDangerBg, matchesHex: 0xD0323B, scheme: .light, "merchant.actionDangerBg")
        assertColor(merchant.actionDangerFg, matchesHex: 0xFFFFFF, scheme: .light, "merchant.actionDangerFg")
        assertColor(merchant.cardShadowColor, matchesHex: 0x000000, alpha: 0.05, scheme: .light, "merchant.cardShadowColor")

        // Player dark palette exact values
        assertColor(player.bgPage, matchesHex: 0x000000, scheme: .dark, "player.bgPage")
        assertColor(player.bgSurface, matchesHex: 0x1C1C1E, scheme: .dark, "player.bgSurface")
        assertSameColor(player.bgSurface, Color(uiColor: .secondarySystemGroupedBackground), scheme: .dark, "player.bgSurface")
        // Native iOS r2: no white-on-black player CTA; the primary action is the system accent with a white label.
        XCTAssertEqual(player.actionPrimaryBg, .accentColor, "player.actionPrimaryBg")
        XCTAssertEqual(player.actionPrimaryFg, .white, "player.actionPrimaryFg")
        // Native restyle: text follows the system label colours (label / quaternaryLabel) in the domain appearance.
        assertSameColor(player.textPrimary, Color(uiColor: .label), scheme: .dark, "player.textPrimary")
        assertColor(player.textPrimary, matchesHex: 0xFFFFFF, scheme: .dark, "player.textPrimary")
        assertSameColor(player.textDisabled, Color(uiColor: .quaternaryLabel), scheme: .dark, "player.textDisabled")
        assertColor(player.actionDangerBg, matchesHex: 0xD0323B, scheme: .dark, "player.actionDangerBg")
        assertColor(player.actionDangerFg, matchesHex: 0xFFFFFF, scheme: .dark, "player.actionDangerFg")
    }

    // MARK: - 2. Disabled State -> text-disabled / Button Disabled Tokens

    func testDisabledStatesMapToTextDisabledAndButtonDisabledSurface() {
        for domain in [ThemeDomain.player, ThemeDomain.merchant] {
            let palette = CYDomainPalette(domain)
            let scheme = domain.colorScheme
            // Native restyle (native-ios-r1 §2.2): text-disabled is the system quaternaryLabel in the domain appearance.
            let systemDisabled = Color(uiColor: .quaternaryLabel)

            // CYListRow disabled (both standard and danger become textDisabled and suppress pressed highlight)
            let disabledRow = CYListRowTokens.resolve(tone: .standard, isDisabled: true, isPressed: true, in: palette)
            assertSameColor(disabledRow.title, palette.textDisabled, scheme: scheme, "row disabled title")
            assertSameColor(disabledRow.meta, palette.textDisabled, scheme: scheme, "row disabled meta")
            assertSameColor(disabledRow.value, palette.textDisabled, scheme: scheme, "row disabled value")
            assertSameColor(disabledRow.chevron, palette.textDisabled, scheme: scheme, "row disabled chevron")
            assertSameColor(disabledRow.background, Color.clear, scheme: scheme, "row disabled suppresses press fill")
            XCTAssertEqual(disabledRow.leadingOpacity, 0.4, accuracy: 0.001)
            assertSameColor(disabledRow.title, systemDisabled, scheme: scheme, "row disabled title == text-disabled")

            let disabledDangerRow = CYListRowTokens.resolve(tone: .danger, isDisabled: true, isPressed: false, in: palette)
            assertSameColor(disabledDangerRow.title, palette.textDisabled, scheme: scheme, "disabled danger row uses textDisabled")

            // CYField disabled
            let fieldDisabled = CYField.tokens(for: .disabled, hasText: true, colorScheme: scheme, in: palette)
            assertSameColor(fieldDisabled.background, palette.inputDisabledBg, scheme: scheme, "field disabled bg")
            assertSameColor(fieldDisabled.textForeground, palette.textDisabled, scheme: scheme, "field disabled text")
            assertSameColor(fieldDisabled.textForeground, systemDisabled, scheme: scheme, "field disabled == text-disabled")
            XCTAssertFalse(fieldDisabled.showsSuccessIcon)

            // CYRouteNodeRow locked / disabled
            let routeLocked = CYRouteNodeRow.tokens(for: .locked, in: palette)
            assertSameColor(routeLocked.titleColor, palette.textDisabled, scheme: scheme, "route locked title")
            assertSameColor(routeLocked.nodeGlyphColor, palette.textDisabled, scheme: scheme, "route locked glyph")
            assertSameColor(routeLocked.nodeFill, palette.bgRaised, scheme: scheme, "route locked fill")
            XCTAssertEqual(routeLocked.badgeTone, .neutral)

            // CYTaskStatusCard locked / disabled
            let taskLocked = CYTaskStatusCard.tokens(
                for: .locked(requirement: "需先完成第 1 站"),
                in: palette
            )
            assertSameColor(taskLocked.iconColor, palette.textDisabled, scheme: scheme, "task locked iconColor")
            assertSameColor(taskLocked.iconColor, systemDisabled, scheme: scheme, "task locked == text-disabled")
            XCTAssertEqual(taskLocked.badgeTone, .neutral)

            // CYAvatarView offline indicator uses textDisabled
            if let offlineDot = CYAvatarView.onlineDotColor(isOnline: false) {
                assertSameColor(offlineDot, systemDisabled, scheme: scheme, "avatar offline dot == text-disabled")
            } else {
                XCTFail("Expected non-nil offline dot color")
            }

            // Disabled buttons keep textPlaceholder on bgSurfaceSubtle (>= 4.56:1 WCAG AA per DESIGN.md)
            for variant in [CYButtonVariant.primary, .secondary, .ghost, .danger] {
                let buttonTokens = CYButtonTokens.resolve(variant: variant, isEnabled: false, isPressed: true)
                assertSameColor(buttonTokens.foreground, CYColor.textPlaceholder, scheme: scheme, "CYButton disabled fg \(variant)")
                let expectedBg = variant == .ghost ? Color.clear : CYColor.bgSurfaceSubtle
                assertSameColor(buttonTokens.background, expectedBg, scheme: scheme, "CYButton disabled bg \(variant)")
            }

            for kind in [CYDomainButtonKind.primary, .secondary, .destructive] {
                let domainBtn = CYDomainButtonTokens.resolve(kind: kind, isEnabled: false, isPressed: true, in: palette)
                assertSameColor(domainBtn.foreground, palette.textPlaceholder, scheme: scheme, "CYDomainButton disabled fg")
                assertSameColor(domainBtn.background, palette.bgSurfaceSubtle, scheme: scheme, "CYDomainButton disabled bg")
            }

            for style in [CYPillStyle.primary, .secondary, .tertiary] {
                let pill = CYPillButtonStyle.tokens(style: style, isEnabled: false, in: palette)
                assertSameColor(pill.foreground, palette.textPlaceholder, scheme: scheme, "CYPill disabled fg")
                let expectedFill = style == .tertiary ? Color.clear : palette.bgSurfaceSubtle
                assertSameColor(pill.fill, expectedFill, scheme: scheme, "CYPill disabled fill")
            }
        }
    }

    // MARK: - 3. Danger State -> #D0323B

    func testDangerStatesResolveToDangerRedD0323B() {
        for domain in [ThemeDomain.player, ThemeDomain.merchant, ThemeDomain.topicEditor, ThemeDomain.game] {
            let palette = CYDomainPalette(domain)
            let scheme = domain.colorScheme
            assertColor(palette.actionDangerBg, matchesHex: 0xD0323B, scheme: scheme, "\(domain).actionDangerBg")
            assertColor(CYColor.actionDangerBg, matchesHex: 0xD0323B, scheme: scheme, "CYColor.actionDangerBg")
            assertColor(CYColor.dangerSolid, matchesHex: 0xD0323B, scheme: scheme, "CYColor.dangerSolid")
        }

        for domain in [ThemeDomain.player, ThemeDomain.merchant] {
            let palette = CYDomainPalette(domain)
            let scheme = domain.colorScheme

            // Destructive buttons use solid #D0323B + #FFFFFF
            let cyDangerBtn = CYButtonTokens.resolve(variant: .danger, isEnabled: true, isPressed: false)
            assertColor(cyDangerBtn.background, matchesHex: 0xD0323B, scheme: scheme, "CYDestructive bg == #D0323B")
            assertColor(cyDangerBtn.foreground, matchesHex: 0xFFFFFF, scheme: scheme, "CYDestructive fg == #FFFFFF")

            let domainDangerBtn = CYDomainButtonTokens.resolve(kind: .destructive, isEnabled: true, isPressed: false, in: palette)
            assertColor(domainDangerBtn.background, matchesHex: 0xD0323B, scheme: scheme, "CYDomainDestructive bg == #D0323B")
            assertColor(domainDangerBtn.foreground, matchesHex: 0xFFFFFF, scheme: scheme, "CYDomainDestructive fg == #FFFFFF")

            // Badges (CYCountBadge / CYUnreadBadge danger) use #D0323B fill + white foreground
            assertColor(CYUnreadBadge.fillColor(for: .danger), matchesHex: 0xD0323B, scheme: scheme, "CYUnreadBadge danger == #D0323B")
            assertColor(CYUnreadBadge.foregroundColor(for: .danger), matchesHex: 0xFFFFFF, scheme: scheme, "CYUnreadBadge danger fg")

            // Tag / status chip danger uses palette.danger + palette.dangerSoft
            let dangerChip = CYStatusChip.tokens(for: .danger, isSelected: false, in: palette)
            assertSameColor(dangerChip.foreground, palette.danger, scheme: scheme, "status chip danger fg")
            assertSameColor(dangerChip.background, palette.dangerSoft, scheme: scheme, "status chip danger bg")

            // Field error uses palette.danger border + footer
            let errorField = CYField.tokens(for: .error("请输入有效手机号"), hasText: true, colorScheme: scheme, in: palette)
            assertSameColor(errorField.borderColor, palette.danger, scheme: scheme, "field error border")
            XCTAssertEqual(errorField.borderWidth, 1.0)
            if let footerColor = errorField.footerForeground {
                assertSameColor(footerColor, palette.danger, scheme: scheme, "field error footer")
            } else {
                XCTFail("Expected non-nil footerForeground on error state")
            }

            // CYListRow danger uses palette.danger for title and leading icon
            let dangerRow = CYListRowTokens.resolve(tone: .danger, isDisabled: false, isPressed: false, in: palette)
            assertSameColor(dangerRow.title, palette.danger, scheme: scheme, "row danger title")
            assertSameColor(dangerRow.leadingForeground, palette.danger, scheme: scheme, "row danger leading")

            // CYSheetModal destructive option + modal confirm
            let optionDanger = CYSheetModalTokens.optionRowForeground(isDanger: true, in: palette)
            assertSameColor(optionDanger, palette.danger, scheme: scheme, "option sheet danger foreground")
            let modalDanger = CYSheetModalTokens.modal(isDestructive: true, in: palette)
            assertSameColor(modalDanger.consequenceIcon, palette.danger, scheme: scheme, "modal destructive icon")
            XCTAssertEqual(modalDanger.confirmVariant, .danger)

            // CYTaskStatusCard retryableFailure uses palette.danger + .danger badgeTone
            let failureTask = CYTaskStatusCard.tokens(
                for: .retryableFailure(
                    requestId: "req-1",
                    detail: "提交失败",
                    onQueryOriginalReceipt: {},
                    onRetry: {}
                ),
                in: palette
            )
            assertSameColor(failureTask.iconColor, palette.danger, scheme: scheme, "task failure icon")
            assertSameColor(failureTask.detailForeground, palette.danger, scheme: scheme, "task failure detail")
            XCTAssertEqual(failureTask.badgeTone, .danger)

            // In light/merchant mode, palette.danger itself is #D0323B
            if domain == .merchant {
                assertColor(dangerChip.foreground, matchesHex: 0xD0323B, scheme: .light, "merchant chip danger == #D0323B")
                assertColor(dangerRow.title, matchesHex: 0xD0323B, scheme: .light, "merchant row danger == #D0323B")
                assertColor(optionDanger, matchesHex: 0xD0323B, scheme: .light, "merchant option danger == #D0323B")
                assertColor(failureTask.iconColor, matchesHex: 0xD0323B, scheme: .light, "merchant task failure == #D0323B")
            }
        }
    }

    // MARK: - 4. No Purple Outside the 3 Reserved Uses

    func testReservedPurpleTokensMatchVioletAndNoComponentLeaksPurpleOutsideThreeUses() {
        for domain in [ThemeDomain.player, ThemeDomain.merchant] {
            let palette = CYDomainPalette(domain)
            let scheme = domain.colorScheme

            // The ONLY allowed #7A5CFF roles: avatarRing and resultSpinner.
            // Native iOS r2 (82bcf2c2d): the selected tab is the system accent, like Apple's tab bars (was PL-01 primary ink).
            XCTAssertEqual(palette.tabSelectedTint, .accentColor, "\(domain) tabSelectedTint is the system accent")
            assertNotPurple(palette.tabSelectedTint, scheme: scheme, "\(domain) tabSelectedTint")
            assertColor(palette.avatarRing, matchesHex: 0x7A5CFF, scheme: scheme, "\(domain) avatarRing")
            assertColor(palette.resultSpinner, matchesHex: 0x7A5CFF, scheme: scheme, "\(domain) resultSpinner")
            assertNotPurple(CYColor.tabSelected, scheme: scheme, "CYColor.tabSelected")
            assertColor(CYColor.avatarRing, matchesHex: 0x7A5CFF, scheme: scheme, "CYColor.avatarRing")
            assertColor(CYColor.resultSpinner, matchesHex: 0x7A5CFF, scheme: scheme, "CYColor.resultSpinner")

            let tabSelected = CYRootTabBarStrip.stripTokens(isSelected: true, in: palette)
            assertSameColor(tabSelected.foreground, palette.tabSelectedTint, scheme: scheme, "selected tab bar item uses the selected tint")
            assertColor(CYAvatarView.ringColor(showAccentRing: true), matchesHex: 0x7A5CFF, scheme: scheme, "avatar accent ring")

            // Every non-reserved token & component state MUST NOT be purple:
            assertNotPurple(palette.actionPrimaryBg, scheme: scheme, "actionPrimaryBg")
            assertNotPurple(palette.actionPrimaryFg, scheme: scheme, "actionPrimaryFg")
            assertNotPurple(palette.brand, scheme: scheme, "brand")
            assertNotPurple(palette.brandSoft, scheme: scheme, "brandSoft")
            assertNotPurple(CYColor.brand, scheme: scheme, "CYColor.brand")
            assertNotPurple(CYColor.actionPrimaryBg, scheme: scheme, "CYColor.actionPrimaryBg")

            // Unselected tab bar & default avatar ring are neutral
            let tabUnselected = CYRootTabBarStrip.stripTokens(isSelected: false, in: palette)
            assertNotPurple(tabUnselected.foreground, scheme: scheme, "tabBar unselected")
            for stop in tabSelected.gradientStops {
                assertNotPurple(stop, scheme: scheme, "tabBar gradient")
            }
            assertNotPurple(CYAvatarView.ringColor(showAccentRing: false), scheme: scheme, "avatar default ring")

            // Buttons (all variants & states)
            for variant in [CYButtonVariant.primary, .secondary, .ghost, .danger] {
                for enabled in [true, false] {
                    for pressed in [true, false] {
                        let t = CYButtonTokens.resolve(variant: variant, isEnabled: enabled, isPressed: pressed)
                        assertNotPurple(t.foreground, scheme: scheme, "CYButton fg \(variant)")
                        assertNotPurple(t.background, scheme: scheme, "CYButton bg \(variant)")
                        assertNotPurple(t.spinnerTint, scheme: scheme, "CYButton spinner \(variant)")
                    }
                }
            }
            for kind in [CYDomainButtonKind.primary, .secondary, .destructive] {
                for enabled in [true, false] {
                    let t = CYDomainButtonTokens.resolve(kind: kind, isEnabled: enabled, isPressed: false, in: palette)
                    assertNotPurple(t.foreground, scheme: scheme, "CYDomainButton fg")
                    assertNotPurple(t.background, scheme: scheme, "CYDomainButton bg")
                }
            }
            for style in [CYPillStyle.primary, .secondary, .tertiary] {
                for enabled in [true, false] {
                    let t = CYPillButtonStyle.tokens(style: style, isEnabled: enabled, in: palette)
                    assertNotPurple(t.foreground, scheme: scheme, "CYPill fg")
                    assertNotPurple(t.fill, scheme: scheme, "CYPill fill")
                }
            }

            // Tags / status chips (all 6 tones) + badges
            for tone in [CYStatusTone.neutral, .success, .warning, .danger, .info, .rare] {
                let chip = CYStatusChip.tokens(for: tone, isSelected: true, in: palette)
                assertNotPurple(chip.foreground, scheme: scheme, "CYStatusChip fg \(tone)")
                assertNotPurple(chip.background, scheme: scheme, "CYStatusChip bg \(tone)")
                if let border = chip.selectedBorder {
                    assertNotPurple(border, scheme: scheme, "CYStatusChip border \(tone)")
                }
            }
            for badgeStyle in [CYUnreadBadgeStyle.danger, .accent, .muted] {
                assertNotPurple(CYUnreadBadge.fillColor(for: badgeStyle), scheme: scheme, "CYUnreadBadge fill \(badgeStyle)")
                assertNotPurple(CYUnreadBadge.foregroundColor(for: badgeStyle), scheme: scheme, "CYUnreadBadge fg \(badgeStyle)")
            }

            // Filter chip & CYTabs (all 4 variants: selected uses textPrimary, NEVER violet)
            for selected in [false, true] {
                let filter = CYFilterChip.tokens(isSelected: selected, in: palette)
                assertNotPurple(filter.foreground, scheme: scheme, "CYFilterChip fg")
                assertNotPurple(filter.background, scheme: scheme, "CYFilterChip bg")

                for variant in [CYTabsVariant.underline, .segmented, .chip, .sticky] {
                    let tab = CYTabsTokens.resolve(variant: variant, isSelected: selected, in: palette)
                    assertNotPurple(tab.foreground, scheme: scheme, "CYTabs fg \(variant)")
                    if let ind = tab.indicatorFill {
                        assertNotPurple(ind, scheme: scheme, "CYTabs indicator \(variant)")
                    }
                    if let track = tab.trackFill {
                        assertNotPurple(track, scheme: scheme, "CYTabs track \(variant)")
                    }
                }
            }

            // Cells, Cards, Fields, Sheets, Chrome bars
            for tone in [CYListRowTone.standard, .danger] {
                for disabled in [false, true] {
                    let row = CYListRowTokens.resolve(tone: tone, isDisabled: disabled, isPressed: !disabled, in: palette)
                    assertNotPurple(row.title, scheme: scheme, "CYListRow title")
                    assertNotPurple(row.background, scheme: scheme, "CYListRow bg")
                }
            }
            for cardVariant in [CYCardVariant.surface, .elevated, .subtle, .accentTint] {
                assertNotPurple(CYCardSurfaceModifier.backgroundColor(for: cardVariant), scheme: scheme, "CYCard \(cardVariant)")
            }
            for fieldState in [CYFieldState.idle, .focused, .filled, .help("tip"), .error("err"), .success, .disabled] {
                let ft = CYField.tokens(for: fieldState, hasText: true, colorScheme: scheme, in: palette)
                assertNotPurple(ft.background, scheme: scheme, "CYField bg \(fieldState)")
                assertNotPurple(ft.borderColor, scheme: scheme, "CYField border \(fieldState)")
                assertNotPurple(ft.textForeground, scheme: scheme, "CYField text \(fieldState)")
            }
            let sheet = CYSheetModalTokens.sheet(in: palette)
            assertNotPurple(sheet.background, scheme: scheme, "sheet background")
            assertNotPurple(sheet.card, scheme: scheme, "sheet card")
            let modal = CYSheetModalTokens.modal(isDestructive: false, in: palette)
            assertNotPurple(modal.panel, scheme: scheme, "modal panel")
            for navMode in [CYNavBarMode.plain, .solid, .overlayHero] {
                let nav = CYNavBarTokens.resolve(mode: navMode, colorScheme: scheme, in: palette)
                assertNotPurple(nav.titleColor, scheme: scheme, "nav title \(navMode)")
                assertNotPurple(nav.backgroundColor, scheme: scheme, "nav bg \(navMode)")
            }
            let footer = CYFooterBarTokens.resolve(isAccessibilitySize: false, in: palette)
            assertNotPurple(footer.background, scheme: scheme, "footer bg")
            assertNotPurple(footer.divider, scheme: scheme, "footer divider")

            // Business components: Activity card, Route node, Task status
            let activity = CYActivityFeedCard.tokens(in: palette)
            assertNotPurple(activity.coverFallback, scheme: scheme, "activity coverFallback")
            assertNotPurple(activity.rare, scheme: scheme, "activity rare")
            for completion in [CYRouteNodeCompletion.upcoming, .current, .completed, .locked] {
                let node = CYRouteNodeRow.tokens(for: completion, in: palette)
                assertNotPurple(node.nodeFill, scheme: scheme, "route node fill \(completion)")
                assertNotPurple(node.railColor, scheme: scheme, "route node rail \(completion)")
            }
            let allTaskStates: [CYTaskStatusState] = [
                .locked(requirement: "locked"),
                .available(methodLabel: "GPS", onStart: {}),
                .submitting(requestId: "r1"),
                .completed(receiptNo: "c1", completedAt: "10:00"),
                .retryableFailure(requestId: "r2", detail: "fail", onQueryOriginalReceipt: {}, onRetry: {}),
                .offlineAwaitingSync(draftId: "d1", savedAt: "10:01", onSyncNow: {}, onViewDraft: {}),
            ]
            for taskState in allTaskStates {
                let tt = CYTaskStatusCard.tokens(for: taskState, in: palette)
                assertNotPurple(tt.iconColor, scheme: scheme, "task icon")
                assertNotPurple(tt.detailForeground, scheme: scheme, "task detail")
            }
        }
    }

    // MARK: - 5. Per-Component Token State Matrix

    func testTabsCellsChipsNavFooterBusinessTokenMatrices() {
        let player = CYDomainPalette(.player)
        let merchant = CYDomainPalette(.merchant)

        // CYFilterChip selected swaps to actionPrimaryBg/actionPrimaryFg; unselected uses bgElevated/textSecondary
        let chipSelMerchant = CYFilterChip.tokens(isSelected: true, in: merchant)
        XCTAssertEqual(chipSelMerchant.background, .accentColor, "merchant selected chip bg")
        XCTAssertEqual(chipSelMerchant.foreground, .white, "merchant selected chip fg")

        let chipSelPlayer = CYFilterChip.tokens(isSelected: true, in: player)
        // Native iOS r2: the selected chip is the accent primary action (no forced-dark white chip on the player).
        XCTAssertEqual(chipSelPlayer.background, .accentColor, "player selected chip bg")
        XCTAssertEqual(chipSelPlayer.foreground, .white, "player selected chip fg")

        // CYTabs underline & segmented indicators use neutral textPrimary (never violet)
        let underlineSelected = CYTabsTokens.resolve(variant: .underline, isSelected: true, in: player)
        let underlineUnselected = CYTabsTokens.resolve(variant: .underline, isSelected: false, in: player)
        assertSameColor(underlineSelected.indicatorFill ?? .clear, player.textPrimary, scheme: .dark)
        XCTAssertNil(underlineUnselected.indicatorFill)
        assertSameColor(underlineSelected.foreground, player.textPrimary, scheme: .dark)
        assertSameColor(underlineUnselected.foreground, player.textSecondary, scheme: .dark)

        let segSelected = CYTabsTokens.resolve(variant: .segmented, isSelected: true, in: merchant)
        // Native restyle (native-ios-r1 §3.7): the segmented variant is drawn like UISegmentedControl.
        assertSameColor(segSelected.foreground, merchant.textPrimary, scheme: .light)
        assertSameColor(segSelected.indicatorFill ?? .clear, merchant.segmentThumb, scheme: .light)
        assertColor(merchant.segmentThumb, matchesHex: 0xFFFFFF, scheme: .light, "merchant segment thumb")
        assertSameColor(segSelected.trackFill ?? .clear, merchant.bgSurfaceSubtle, scheme: .light)

        let sticky = CYTabsTokens.resolve(variant: .sticky, isSelected: true, in: merchant)
        assertSameColor(sticky.containerBackground ?? .clear, merchant.bgPage, scheme: .light)

        // CYNavBar modes
        let navOverlay = CYNavBarTokens.resolve(mode: .overlayHero, colorScheme: .light, in: merchant)
        XCTAssertNotNil(navOverlay.backBadgeFill)
        assertSameColor(navOverlay.titleColor, merchant.onCoverFg, scheme: .light)
        let navSolidLight = CYNavBarTokens.resolve(mode: .solid, colorScheme: .light, in: merchant)
        XCTAssertNotNil(navSolidLight.dividerColor)
        let navSolidDark = CYNavBarTokens.resolve(mode: .solid, colorScheme: .dark, in: player)
        XCTAssertNil(navSolidDark.dividerColor)

        // CYFooterBar dual AX stacking
        let footerCompact = CYFooterBarTokens.resolve(isAccessibilitySize: false, in: merchant)
        let footerAX = CYFooterBarTokens.resolve(isAccessibilitySize: true, in: merchant)
        XCTAssertFalse(footerCompact.usesStackedDualLayout)
        XCTAssertTrue(footerAX.usesStackedDualLayout)
        XCTAssertEqual(footerCompact.primaryVariant, .primary)
        XCTAssertEqual(footerCompact.secondaryVariant, .secondary)

        // CYField state resolution priority (forced -> disabled -> error -> focused -> success -> filled -> help -> idle)
        XCTAssertEqual(
            CYField.resolveState(forcedState: nil, isDisabled: true, errorText: "err", isFocused: true, isSuccess: true, text: "x", helperText: "h"),
            .disabled
        )
        XCTAssertEqual(
            CYField.resolveState(forcedState: nil, isDisabled: false, errorText: "err", isFocused: true, isSuccess: true, text: "x", helperText: "h"),
            .error("err")
        )
        XCTAssertEqual(
            CYField.resolveState(forcedState: nil, isDisabled: false, errorText: nil, isFocused: true, isSuccess: true, text: "x", helperText: "h"),
            .focused
        )
        XCTAssertEqual(
            CYField.resolveState(forcedState: nil, isDisabled: false, errorText: nil, isFocused: false, isSuccess: true, text: "", helperText: nil),
            .success
        )
        XCTAssertEqual(
            CYField.resolveState(forcedState: nil, isDisabled: false, errorText: nil, isFocused: false, isSuccess: false, text: "已填写", helperText: nil),
            .filled
        )
        XCTAssertEqual(
            CYField.resolveState(forcedState: nil, isDisabled: false, errorText: nil, isFocused: false, isSuccess: false, text: "", helperText: "提示"),
            .help("提示")
        )
        XCTAssertEqual(
            CYField.resolveState(forcedState: nil, isDisabled: false, errorText: nil, isFocused: false, isSuccess: false, text: "", helperText: nil),
            .idle
        )

        // CYRouteNodeRow progression tokens
        let nodeCompleted = CYRouteNodeRow.tokens(for: .completed, in: player)
        let nodeCurrent = CYRouteNodeRow.tokens(for: .current, in: player)
        let nodeUpcoming = CYRouteNodeRow.tokens(for: .upcoming, in: player)
        XCTAssertEqual(nodeCompleted.badgeTone, .success)
        XCTAssertEqual(nodeCurrent.badgeTone, .info)
        XCTAssertEqual(nodeUpcoming.badgeTone, .neutral)
        assertSameColor(nodeCompleted.railColor, player.textPrimary, scheme: .dark)
        assertSameColor(nodeCurrent.railColor, player.borderStrong, scheme: .dark)

        // CYTaskStatusCard badge tone coverage across all 6 states
        XCTAssertEqual(CYTaskStatusCard.tokens(for: .available(methodLabel: "扫码", onStart: {}), in: merchant).badgeTone, .info)
        XCTAssertEqual(CYTaskStatusCard.tokens(for: .submitting(requestId: "r1"), in: merchant).badgeTone, .info)
        XCTAssertEqual(CYTaskStatusCard.tokens(for: .completed(receiptNo: "n1", completedAt: "12:00"), in: merchant).badgeTone, .success)
        XCTAssertEqual(CYTaskStatusCard.tokens(for: .offlineAwaitingSync(draftId: "d1", savedAt: "12:01", onSyncNow: {}, onViewDraft: {}), in: merchant).badgeTone, .warning)
    }
}
