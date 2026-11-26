"""Static contract checks for ui/h-tokens-v1 design-token unification, violet retirement, and borderless cards/secondary buttons."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def strip_swift_comments(text: str) -> str:
    """Strip // line and /* ... */ block comments while preserving line structure."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def extract_block(text: str, marker: str, next_marker: str) -> str:
    start = text.index(marker)
    end = text.index(next_marker, start + len(marker))
    return text[start:end]


class TestDesignTokenUnificationContract(unittest.TestCase):
    def test_generated_tokens_cite_latest_hengyin_master(self):
        generated = (ROOT / "App/Theme/Theme+Generated.swift").read_text(encoding="utf-8")
        self.assertIn("561cafd10214853e8b43128a3ffe419cf115cca2", generated)
        self.assertIn("b7766933ac47befbb41f937d1186a97ff0f546fe49fb3e9e3759925ad5a8e02c", generated)
        for token in (
            '"--cy-color-text-secondary"',
            '"--cy-color-text-tertiary"',
            '"--cy-color-text-placeholder"',
            '"--cy-comp-sheet-player-glass"',
            '"--cy-comp-sheet-player-card"',
            '"--cy-comp-modal-panel"',
            '"--cy-color-rare"',
            '"--cy-color-medal-gold"',
            '"--cy-game-accent"',
            '"--cy-comp-profile-avatar-ring"',
            '"--cy-comp-result-spinner"',
        ):
            self.assertIn(token, generated)

    def test_cy_design_tokens_delegates_and_fixes_radius_type_spacing(self):
        tokens = (ROOT / "App/DesignSystem/CYDesignTokens.swift").read_text(encoding="utf-8")
        code = strip_swift_comments(tokens)

        for forbidden in (
            "0x0F172A",
            "accentRGB",
            "accentStrongLightRGB",
            "accentTextDarkRGB",
            "accentSoftLightRGB",
            "accentSoftDarkRGB",
            "accentWarm",
            "0x18181B",
            "0xF5F5F7",
            "0x71717A",
            "0x8E8E98",
        ):
            self.assertNotIn(forbidden, code)

        for required in (
            "public static let textPrimary = resolved { $0.textPrimary }",
            "public static let textSecondary = resolved { $0.textSecondary }",
            "public static let textTertiary = resolved { $0.textTertiary }",
            "public static let textPlaceholder = resolved { $0.textPlaceholder }",
            "public static let borderSubtle = resolved { $0.borderSubtle }",
            "public static let borderStrong = resolved { $0.borderStrong }",
            "public static let sheetGlass = resolved { $0.sheetGlass }",
            "public static let sheetCard = resolved { $0.sheetCard }",
            "public static let modalPanel = resolved { $0.modalPanel }",
            "public static let rare = resolved { $0.rare }",
            "public static let medalGold = resolved { $0.medalGold }",
            "public static let gameAccent = CYDomainPalette(.game).gameAccent",
            # Native restyle (native-ios-r1 §2.4): the half-steps snap to the 4/8 grid.
            "public static let s1_5: CGFloat = Theme.Space.s2",
            "public static let s2_5: CGFloat = Theme.Space.s3",
            "public static let s3_5: CGFloat = Theme.Space.s4",
            '@available(*, deprecated, renamed: "sm")',
            "public static let sm: CGFloat = Theme.Radius.sm",
            "public static let md: CGFloat = Theme.Radius.md",
            "public static let lg: CGFloat = Theme.Radius.lg",
            "public static let xl: CGFloat = Theme.Radius.xl",
            "public static let xxl: CGFloat = Theme.Radius.xxl",
            "public static var button: Font {",
        ):
            self.assertIn(required, code)

        theme = strip_swift_comments((ROOT / "App/Theme/Theme.swift").read_text(encoding="utf-8"))
        # consist-1: Theme.Font delegates to the one scale (CYTextStyle.spec in CYDesignTokens.swift); page title
        # weight follows the mini-program (700 = .bold, was .heavy).
        self.assertIn("static var pageTitle: SwiftUI.Font { CYTextStyle.pageTitle.font }", theme)
        self.assertIn("static var button: SwiftUI.Font { CYTextStyle.button.font }", theme)
        # Native iOS restyle r1 (owner, 11-24): every token is a semantic Dynamic Type style, nothing below .caption.
        self.assertIn('case .pageTitle: return CYTypeSpec(.title, .bold', code)
        self.assertIn('case .body: return CYTypeSpec(.body, .regular', code)
        self.assertIn('case .micro: return CYTypeSpec(.caption,', code)
        self.assertIn('case .dataXL: return CYTypeSpec(.largeTitle, .bold', code)
        self.assertIn('case .button: return CYTypeSpec(.headline, .semibold)', code)
        self.assertIn('.system(spec.textStyle, design: spec.design', code)
        self.assertNotIn('CYTypeSpec(.caption2', code)

        # Ensure every required Theme.length/color/duration key actually exists in Theme+Generated.swift
        generated = (ROOT / "App/Theme/Theme+Generated.swift").read_text(encoding="utf-8")
        gen_keys = set(re.findall(r'case "(--[^"]+)":', generated))
        for path in (ROOT / "App").rglob("*.swift"):
            if path.name == "Theme+Generated.swift":
                continue
            src = strip_swift_comments(path.read_text(encoding="utf-8"))
            for m in re.finditer(r'Theme\.(?:length|color|duration)\("(--[^"]+)"\)', src):
                self.assertIn(m.group(1), gen_keys, f"{path.relative_to(ROOT)} references missing key {m.group(1)}")

    def test_violet_7a5cff_restricted_to_three_allowed_roles_and_accent_retired(self):
        app_files = sorted((ROOT / "App").rglob("*.swift"))
        allowed_raw_violet_files = {
            "App/Theme/Theme+Generated.swift",
            "App/Theme/Theme+MiniProgramReference.swift",
            "App/DesignSystem/CYDomainTabBar.swift",
        }
        allowed_tab_selected_files = {
            "App/DesignSystem/CYDesignTokens.swift",
            "App/DesignSystem/CYDomainPalette.swift",
            "App/DesignSystem/CYDomainTabBar.swift",
            "App/DesignSystem/CYNightTabBar.swift",
            "App/DesignSystem/CYNight.swift",
            "App/DesignSystem/CYScreenStyle.swift",
        }
        allowed_avatar_ring_files = {
            "App/DesignSystem/CYDesignTokens.swift",
            "App/DesignSystem/CYDomainPalette.swift",
            "App/DesignSystem/CYDesignComponents.swift",
            "App/DesignFixtures/E3Fixtures.swift",
            "App/GrowthCenterView.swift",
            "App/GrowthLeaderboardView.swift",
            "App/MemberHomeHeader.swift",
            "App/ProfileCurrentAvatarView.swift",
            "App/SettingsView.swift",
            "App/SocialPublicProfileView.swift",
        }
        allowed_result_spinner_files = {
            "App/DesignSystem/CYDesignTokens.swift",
            "App/DesignSystem/CYDomainPalette.swift",
            "App/GlobalSearchView.swift",
            "App/SearchMapResultsCapsule.swift",
        }

        retired_symbol_re = re.compile(
            r"\b(?:CYColor\.(?:accent|accentStrong|accentPressed|accentText|accentSoft|accentWarm)"
            r"|CYNight\.(?:violet|selection))\b"
        )
        raw_violet_re = re.compile(r"7A5CFF|122\.0/255|6A4AF0|C4B5FD|EDE9FE", re.IGNORECASE)

        for path in app_files:
            rel = path.relative_to(ROOT).as_posix()
            code = strip_swift_comments(path.read_text(encoding="utf-8"))

            retired = retired_symbol_re.findall(code)
            self.assertEqual(retired, [], f"{rel} still uses retired accent symbol(s): {retired}")

            if rel not in allowed_raw_violet_files:
                raw_hits = raw_violet_re.findall(code)
                self.assertEqual(raw_hits, [], f"{rel} contains disallowed #7A5CFF / violet literal: {raw_hits}")

            if re.search(r"\b(?:tabSelected|tabSelectedTint)\b", code):
                self.assertIn(rel, allowed_tab_selected_files, f"{rel} uses tabSelected outside tab bar chrome")
            if re.search(r"\bavatarRing\b", code):
                self.assertIn(rel, allowed_avatar_ring_files, f"{rel} uses avatarRing outside avatar ring")
            if re.search(r"\bresultSpinner\b", code):
                self.assertIn(rel, allowed_result_spinner_files, f"{rel} uses resultSpinner outside result spinner")

    def test_no_stroke_borders_on_cards_or_secondary_buttons(self):
        components = strip_swift_comments((ROOT / "App/DesignSystem/CYDesignComponents.swift").read_text(encoding="utf-8"))
        card_mod = extract_block(components, "public struct CYCardSurfaceModifier", "public extension View {")
        sec_btn = extract_block(components, "public struct CYSecondaryButtonStyle", "public struct CYDestructiveButtonStyle")
        dest_btn = extract_block(components, "public struct CYDestructiveButtonStyle", "public extension ButtonStyle")
        for label, block in (("CYCardSurfaceModifier", card_mod), ("CYSecondaryButtonStyle", sec_btn), ("CYDestructiveButtonStyle", dest_btn)):
            self.assertNotIn("strokeBorder(", block, f"{label} must not draw an outer strokeBorder")
            self.assertNotIn(".stroke(", block, f"{label} must not draw an outer stroke")
            self.assertNotIn(".border(", block, f"{label} must not draw a border")

        palette = strip_swift_comments((ROOT / "App/DesignSystem/CYDomainPalette.swift").read_text(encoding="utf-8"))
        dom_sec = extract_block(palette, "struct CYDomainSecondaryButtonStyle", "struct CYDomainDestructiveButtonStyle")
        dom_dest = extract_block(palette, "struct CYDomainDestructiveButtonStyle", "extension ButtonStyle")
        for label, block in (("CYDomainSecondaryButtonStyle", dom_sec), ("CYDomainDestructiveButtonStyle", dom_dest)):
            self.assertNotIn("strokeBorder(", block, f"{label} must not draw a border")
            self.assertNotIn(".stroke(", block, f"{label} must not draw a border")
        dom_card = extract_block(palette, "struct CYDomainCardModifier", "extension View {")
        self.assertNotIn("borderSubtle", dom_card)
        self.assertNotIn("borderStrong", dom_card)

        pill = strip_swift_comments((ROOT / "App/DesignSystem/CYPillButton.swift").read_text(encoding="utf-8"))
        pill_style = extract_block(pill, "struct CYPillButtonStyle", "private struct CYPillButtonPreviewBody")
        self.assertNotIn("strokeBorder(", pill_style, "CYPillButtonStyle secondary pill must use fill, not strokeBorder")
        self.assertNotIn(".stroke(", pill_style)

        order = strip_swift_comments((ROOT / "App/OrderLifecycleView.swift").read_text(encoding="utf-8"))
        # native-r2 me-account (8bd25cb04): the custom CYOrderActionSecondaryLabel became Apple stock buttons;
        # nothing in the order lifecycle screen may draw an outer strokeBorder on its actions.
        self.assertNotIn("CYOrderActionSecondaryLabel", order)
        self.assertNotIn("strokeBorder(", order, "OrderLifecycleView actions must not draw a strokeBorder")


if __name__ == "__main__":
    unittest.main()
