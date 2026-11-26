"""Contract checks for shared design-system components & tokens across App/.

Enforces:
1. Outside `App/DesignSystem/` (and token definitions under `App/Theme/`):
   - No raw `Color(...)` / `UIColor(...)` initializers
   - No raw `#RRGGBB` / `0xRRGGBB` hex literals
   - No hardcoded `.cornerRadius(<number>)`
   Pre-existing baseline hits in untouched production screens are strictly ratcheted
   by file so `new = 0` and any new occurrence fails immediately.
2. Purple (`#7A5CFF`) restraint across all of `App/`: forbidden outside the 3
   reserved uses (`tabSelected` / `tabSelectedTint`, `avatarRing`, `resultSpinner`).
3. State -> token mappings (`disabled` -> `textDisabled`, `danger` -> `#D0323B`,
   `.merchant` domain -> `.light`) and unit-test presence.
"""
from __future__ import annotations

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

COLOR_INIT_RE = re.compile(r"(?:\bColor\s*\(|\bUIColor\s*\()")
HEX_LITERAL_RE = re.compile(r"#[0-9A-Fa-f]{6}\b|0x[0-9A-Fa-f]{6}\b")
CORNER_RADIUS_RE = re.compile(r"\.cornerRadius\s*\(\s*[0-9]+(?:\.[0-9]+)?\s*\)")
PURPLE_LITERAL_RE = re.compile(
    r"(#7A5CFF|0x7A5CFF|\bColor\s*\.\s*purple\b|\bUIColor\s*\.\s*systemPurple\b|122\.0?\s*/\s*255)",
    re.IGNORECASE,
)
PURPLE_TOKEN_RE = re.compile(r"\b(tabSelected|tabSelectedTint|avatarRing|resultSpinner)\b")

# Exact pre-existing baseline counts outside App/DesignSystem/ & App/Theme/ (ratchet: no increases).
RAW_COLOR_ALLOWLIST: dict[str, int] = {
    "App/ActivityPresentationComponents.swift": 1,
    "App/ChatMessageBubble.swift": 1,
    "App/ClubComponents.swift": 2,
    "App/DesignFixtures/RoamFixtures.swift": 4,
    "App/DiceD20View.swift": 5,
    "App/E1CommerceComponents.swift": 4,
    "App/FogOverlayLayer.swift": 1,
    # subpackageP3/pages/growthcenter/leaderboard/index.js:29-33 RING_BG gold / pale gold / bronze.
    "App/GrowthLeaderboardView.swift": 3,
    "App/IMInboxViews.swift": 2,
    "App/MapCoreEntryHubView.swift": 1,
    "App/MapVisualLayerControlSectionView.swift": 1,
    "App/MerchantContentViews.swift": 1,
    "App/MerchantGameNodeView.swift": 2,
    "App/MerchantGamePlayerView.swift": 1,
    "App/MerchantNPCPresetPicker.swift": 1,
    "App/MerchantTopicDetailSection+Wire2.swift": 2,
    "App/NativeAttributeAuthorViews.swift": 1,
    "App/NativeAuthorPresentation.swift": 1,
    "App/NearbyTeamMapViews.swift": 1,
    "App/ObjectBadgeViews.swift": 5,
    "App/OfficialEventComponents.swift": 1,
    "App/OwnMediaModelPreviewDevice.swift": 1,
    "App/PlayKitSensorChallengeView.swift": 1,
    "App/PlayNativeDeviceProvider.swift": 2,
    # pages/play/index.wxml:168 story map; unselected stop disc is systemBackground, same as PlayRouteMapView.
    "App/PlayExperienceView.swift": 1,
    "App/PlayRouteMapView.swift": 1,
    "App/PrivateHomeMapPicker.swift": 1,
    "App/PrivateHomeView.swift": 1,
    "App/ProfileCurrentMediaPreview.swift": 1,
    # native r2: semantic UIKit system colours (no raw RGB/hex) prescribed by the native conversion brief.
    "App/ProjectEditExitGuard.swift": 1,  # secondarySystemGroupedBackground under the inset exit bar
    "App/PublishingContextHandoffViews.swift": 1,  # systemGroupedBackground canvas
    "App/TemplateAuthoringCoverHeader.swift": 1,  # secondarySystemFill cover placeholder
    "App/TemplateAuthoringMineView.swift": 1,  # secondarySystemFill cover placeholder
    "App/TemplateDetailXbChrome.swift": 1,  # tertiarySystemFill capsule
    "App/ProjectChapterAtmosphereFields.swift": 1,
    "App/QuestifyImageEntityCard.swift": 1,
    "App/QuestifyMotionComponents.swift": 3,
    "App/QuestifyPalette.swift": 3,
    "App/RoamHomeTabsView.swift": 4,
    "App/RoamSubpageParityViews.swift": 1,
    "App/SearchMapCanvas.swift": 8,
    "App/SearchMapComponents.swift": 1,
    "App/SocialGuideViews.swift": 6,
    "App/SquareXcxPostCard.swift": 2,
    "App/TicketWalletView.swift": 8,
    "App/WelcomeView.swift": 1,
}

HEX_LITERAL_ALLOWLIST: dict[str, int] = {
    "App/MerchantBusinessEditor.swift": 1,
}

CORNER_RADIUS_ALLOWLIST: dict[str, int] = {
    "App/SquarePostVideoViews.swift": 1,
}

PURPLE_LITERAL_ALLOWED_FILES = {
    "App/DesignSystem/CYDomainTabBar.swift",
    "App/Theme/Theme+MiniProgramReference.swift",
}

PURPLE_TOKEN_ALLOWED_BY_FILE: dict[str, set[str]] = {
    "App/DesignFixtures/E3Fixtures.swift": {"avatarRing"},
    "App/DesignSystem/CYDesignComponents.swift": {"avatarRing"},
    "App/DesignSystem/CYDesignTokens.swift": {"avatarRing", "resultSpinner", "tabSelected", "tabSelectedTint"},
    "App/DesignSystem/CYDomainPalette.swift": {"avatarRing", "resultSpinner", "tabSelectedTint"},
    "App/DesignSystem/CYDomainTabBar.swift": {"tabSelectedTint"},
    "App/DesignSystem/CYNight.swift": {"tabSelected"},
    "App/DesignSystem/CYNightTabBar.swift": {"tabSelected"},
    "App/DesignSystem/CYScreenStyle.swift": {"tabSelectedTint"},
    "App/GlobalSearchView.swift": {"resultSpinner"},
    "App/GrowthCenterView.swift": {"avatarRing"},
    "App/GrowthLeaderboardView.swift": {"avatarRing"},
    "App/MemberHomeHeader.swift": {"avatarRing"},
    "App/ProfileCurrentAvatarView.swift": {"avatarRing"},
    "App/SearchMapResultsCapsule.swift": {"resultSpinner"},
    "App/SettingsView.swift": {"avatarRing"},
    "App/SocialPublicProfileView.swift": {"avatarRing"},
}


def strip_swift_comments(text: str) -> str:
    """Remove // and /* ... */ comments so prose examples do not trigger lint."""
    without_block = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", without_block)


def collect_app_swift_files(root: Path, overrides: dict[str, str] | None = None) -> dict[str, str]:
    files: dict[str, str] = {}
    app_dir = root / "App"
    for path in sorted(app_dir.rglob("*.swift")):
        rel = path.relative_to(root).as_posix()
        files[rel] = path.read_text(encoding="utf-8")
    if overrides:
        for rel, text in overrides.items():
            files[rel] = text
    return dict(sorted(files.items()))


def scan_design_system_component_contracts(
    root: Path,
    overrides: dict[str, str] | None = None,
) -> list[str]:
    errors: list[str] = []
    sources = collect_app_swift_files(root, overrides=overrides)

    for rel, raw_text in sources.items():
        code = strip_swift_comments(raw_text)
        in_design_system = rel.startswith("App/DesignSystem/")
        in_theme = rel.startswith("App/Theme/")

        # 1. Hardcoded .cornerRadius(<number>) forbidden anywhere outside App/DesignSystem/
        if not in_design_system:
            corner_count = len(CORNER_RADIUS_RE.findall(code))
            allowed_corners = CORNER_RADIUS_ALLOWLIST.get(rel, 0)
            if corner_count > allowed_corners:
                errors.append(
                    f"[cornerRadius] {rel}: found {corner_count} hardcoded .cornerRadius(<number>) "
                    f"(allowed={allowed_corners}) outside App/DesignSystem/"
                )

        # 2. Raw Color(...)/UIColor(...) and hex literals forbidden outside App/DesignSystem/ and App/Theme/
        if not in_design_system and not in_theme:
            color_count = len(COLOR_INIT_RE.findall(code))
            allowed_colors = RAW_COLOR_ALLOWLIST.get(rel, 0)
            if color_count > allowed_colors:
                errors.append(
                    f"[raw-color] {rel}: found {color_count} Color(...)/UIColor(...) calls "
                    f"(allowed={allowed_colors}) outside App/DesignSystem/"
                )

            hex_count = len(HEX_LITERAL_RE.findall(code))
            allowed_hex = HEX_LITERAL_ALLOWLIST.get(rel, 0)
            if hex_count > allowed_hex:
                errors.append(
                    f"[hex-literal] {rel}: found {hex_count} hex literal(s) "
                    f"(allowed={allowed_hex}) outside App/DesignSystem/"
                )

        # 3. Purple literals & tokens strictly restricted to the 3 reserved uses
        purple_lit = PURPLE_LITERAL_RE.findall(code)
        if purple_lit and rel not in PURPLE_LITERAL_ALLOWED_FILES:
            errors.append(
                f"[purple-literal] {rel}: forbidden purple literal {purple_lit} outside approved files"
            )

        purple_tokens = set(PURPLE_TOKEN_RE.findall(code))
        allowed_tokens = PURPLE_TOKEN_ALLOWED_BY_FILE.get(rel, set())
        disallowed_tokens = sorted(purple_tokens - allowed_tokens)
        if disallowed_tokens:
            errors.append(
                f"[purple-token] {rel}: disallowed purple token(s) {disallowed_tokens} "
                f"(allowed for file: {sorted(allowed_tokens)})"
            )

    return errors


class TestDesignSystemComponentContracts(unittest.TestCase):
    def test_app_outside_design_system_has_no_unratcheted_raw_color_hex_or_corner_radius(self):
        errors = scan_design_system_component_contracts(ROOT)
        self.assertEqual(errors, [], "\n".join(errors))

    def test_state_token_mappings_in_design_system_sources(self):
        palette_src = strip_swift_comments(
            (ROOT / "App/DesignSystem/CYDomainPalette.swift").read_text(encoding="utf-8")
        )
        tokens_src = strip_swift_comments(
            (ROOT / "App/DesignSystem/CYDesignTokens.swift").read_text(encoding="utf-8")
        )
        theme_src = strip_swift_comments(
            (ROOT / "App/Theme/Theme.swift").read_text(encoding="utf-8")
        )
        list_row_src = strip_swift_comments(
            (ROOT / "App/DesignSystem/CYListRow.swift").read_text(encoding="utf-8")
        )
        field_src = strip_swift_comments(
            (ROOT / "App/DesignSystem/CYField.swift").read_text(encoding="utf-8")
        )
        business_src = strip_swift_comments(
            (ROOT / "App/DesignSystem/CYBusinessComponents.swift").read_text(encoding="utf-8")
        )

        # 1. Merchant domain yields light scheme & light tokens
        self.assertIn("case .merchant, .topicEditor: return .light", theme_src)
        self.assertIn("0xF3F4F4", palette_src)
        self.assertIn("0xFFFFFF", palette_src)
        self.assertIn("0xD0323B", palette_src)
        self.assertIn("actionDangerBg = resolved { $0.actionDangerBg }", tokens_src)
        self.assertIn("dangerSolid = resolved { $0.actionDangerBg }", tokens_src)

        # 2. Disabled state maps to textDisabled on content controls (cell, field, route node, task status)
        self.assertIn("palette.textDisabled", list_row_src)
        self.assertIn("palette.textDisabled", field_src)
        self.assertIn("palette.textDisabled", business_src)

        # 3. Purple limited to its 3 reserved roles in CYDomainPalette & CYDesignTokens
        for reserved in ("tabSelectedTint", "avatarRing", "resultSpinner"):
            self.assertIn(reserved, palette_src)
            self.assertIn(reserved, tokens_src)

        # 4. Shared component unit test suites exist and are registered in Questify.xcodeproj
        token_tests = ROOT / "Tests/AppUnitTests/DesignSystemTokenMappingTests.swift"
        component_tests = ROOT / "Tests/AppUnitTests/DesignSystemSharedComponentsTests.swift"
        self.assertTrue(token_tests.is_file())
        self.assertTrue(component_tests.is_file())
        pbxproj = (ROOT / "Questify.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        self.assertIn("DesignSystemTokenMappingTests.swift", pbxproj)
        self.assertIn("DesignSystemSharedComponentsTests.swift", pbxproj)

    def test_synthetic_violations_are_caught(self):
        synthetic = {
            "App/SyntheticViolationView.swift": """
                import SwiftUI
                struct SyntheticViolationView: View {
                    var body: some View {
                        Text("Bad")
                            .foregroundStyle(Color(red: 1, green: 0, blue: 0))
                            .background(Color.purple)
                            .background(CYColor.avatarRing)
                            .cornerRadius(12)
                    }
                    let hex = "#123456"
                }
            """,
            "App/DesignSystem/SyntheticButtonLeak.swift": """
                import SwiftUI
                let bad = CYColor.tabSelectedTint
            """,
        }
        errors = scan_design_system_component_contracts(ROOT, overrides=synthetic)
        joined = "\n".join(errors)
        self.assertIn("[raw-color] App/SyntheticViolationView.swift", joined)
        self.assertIn("[hex-literal] App/SyntheticViolationView.swift", joined)
        self.assertIn("[cornerRadius] App/SyntheticViolationView.swift", joined)
        self.assertIn("[purple-literal] App/SyntheticViolationView.swift", joined)
        self.assertIn("[purple-token] App/SyntheticViolationView.swift", joined)
        self.assertIn("[purple-token] App/DesignSystem/SyntheticButtonLeak.swift", joined)


if __name__ == "__main__":
    unittest.main()
