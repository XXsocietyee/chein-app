"""K40: AI NPC, guide, and creation source pins. No Swift runtime."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class K40AIContracts(unittest.TestCase):
    def test_quota_skip_is_the_exact_phrase_and_the_role_gate_does_not_contain_it(self):
        source = read("Core/AISafetyPrecheck.swift")
        self.assertIn('public static let quotaHint = "今日AI次数已用完"', source)
        self.assertIn('public static let roleGate = "当前身份暂不支持AI创作"', source)
        self.assertNotIn("今日AI次数已用完", source.split("roleGate", 1)[1].split("\n", 1)[0])
        skipped = source.split("func skipped(message: String?)", 1)[1].split("public var allowsPublish", 1)[0]
        self.assertIn("message == quotaHint", skipped)
        self.assertNotIn(".contains(quotaHint)", skipped)
        self.assertNotIn(".contains(\"今日AI次数已用完\")", source)
        auxiliary = read("Core/PublishingAuxiliaryService.swift")
        self.assertIn("return .rejected(AISafetyPrecheckVerdict.roleGate)", auxiliary)
        self.assertNotIn("当前身份暂不支持AI创作今日AI次数已用完", auxiliary)
        club = read("Core/ClubAIDesignFlow.swift")
        self.assertIn("message == AISafetyPrecheckVerdict.quotaHint", club)
        self.assertNotIn('message.contains("今日AI次数已用完")', club)

    def test_theme_draft_instants_are_utc_with_t_and_trailing_z(self):
        source = read("Core/G6AIThemeDraft.swift")
        body = source.split("public static func instant", 1)[1].split("static func older", 1)[0]
        self.assertIn('text.hasSuffix("Z")', body)
        self.assertIn('text.firstIndex(of: "T")', body)
        self.assertIn('!text.contains("+")', body)
        self.assertIn('.contains("-")', body)
        self.assertIn("TimeZone(secondsFromGMT: 0)", body)

    def test_unserved_dialogue_path_is_not_a_client_method(self):
        http = read("Core/ShopNPCHTTP.swift")
        self.assertNotIn("/api/ai/npc/dialogue", http)
        self.assertNotIn("func dialogue(", http)
        self.assertIn("/api/ai/npc/shop-chat", http)
        self.assertIn("/api/ai/npc/voice-chat", http)

    def test_ai_row_stays_first_in_the_player_create_menu(self):
        menu = read("App/PublishTabRootView.swift")
        sheet = menu.split("private var publishMenu", 1)[1].split("private var creatorMenu", 1)[0]
        self.assertLess(sheet.index("publishRoute = .aiCreation"), sheet.index("choose(.freeExplore)"))
        self.assertLess(sheet.index("choose(.freeExplore)"), sheet.index("choose(.city)"))
        self.assertLess(sheet.index("choose(.city)"), sheet.index("choose(.interaction)"))
        modes = read("App/PublishingModesViews.swift")
        body = modes.split("var body: some View", 1)[1].split("@MainActor struct QuickPublishingView", 1)[0]
        self.assertLess(body.index('accessibilityIdentifier("publishModes.ai")'), body.index('accessibilityIdentifier("publishModes.pro.freeExplore")'))

    def test_play_init_order_and_merchant_ai_stay_gated(self):
        leases = read("App/ReviewedPlayerWriteLeases.swift")
        self.assertIn(
            "publisherReads: true, devices: Self.playDevices, sensors: Self.playSensors,\n"
            "            artworkHosts: Self.playArtworkHosts(apiBase: context.baseURL), shopNPCWrites: true",
            leases,
        )
        approvals = read("App/AICreationReleaseApprovals.swift")
        self.assertIn('case "player":', approvals)
        self.assertIn('case "club":', approvals)
        self.assertNotIn('case "merchant":', approvals)
        self.assertIn("default: return []", approvals)
        session = read("App/AppSession.swift")
        self.assertLessEqual(len(session.splitlines()), 7977)

    def test_touched_ai_sources_add_no_string_localized_literals(self):
        for path in [
            "Core/AISafetyPrecheck.swift",
            "Core/G6AIThemeDraft.swift",
            "Core/ShopNPCHTTP.swift",
            "Core/ClubAIDesignFlow.swift",
            "Core/PublishingAuxiliaryService.swift",
            "App/NPCChatDataReadSettingsEntry.swift",
            "App/AICreationReleaseApprovals.swift",
            "App/AICreationHubView.swift",
        ]:
            self.assertNotIn("String(localized:", read(path), path)


if __name__ == "__main__":
    unittest.main()
