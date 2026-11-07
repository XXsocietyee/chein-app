#if canImport(QuestifyApp)
@testable import QuestifyApp
#endif
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
import XCTest
@testable import Questify

@MainActor
final class NPCChatAndSceneAISafetySectionViewTests: XCTestCase {
    func testDefaultSnapshotEnforcesNonGenerativeKillSwitchAndNPCDeletionFence() {
        let view = NPCChatAndSceneAISafetySectionView()
        _ = view.body

        XCTAssertFalse(view.snapshot.globalGenerationEnabled)
        XCTAssertFalse(view.snapshot.streamingDisplayAllowed)
        XCTAssertTrue(view.snapshot.enforcesScopeEchoAndIsolation)
        XCTAssertTrue(view.snapshot.dropsForbiddenBusinessEffects)
        XCTAssertTrue(view.snapshot.enforcesNPCChatDeletionReReadFence)
        XCTAssertTrue(view.snapshot.hasCanonicalGuards)
        XCTAssertTrue(view.snapshot.isAllCompliant)
        XCTAssertEqual(
            view.snapshot.rows.map(\.guardID),
            ["SceneAIKillSwitch", "SceneAIScopeIsolation", "NPCNarrativeEffectWhitelist", "NPCChatDeletionFence"]
        )
        XCTAssertTrue(view.statusHeadline.contains("I08"))
    }

    func testEnabledGenerationOrStreamingFailsSceneAIKillSwitchGuard() {
        let generativeSnapshot = NPCChatAndSceneAISafetySnapshot(
            globalGenerationEnabled: true,
            streamingDisplayAllowed: false,
            locale: Locale(identifier: "zh-Hans")
        )
        let view = NPCChatAndSceneAISafetySectionView(snapshot: generativeSnapshot)
        _ = view.body

        XCTAssertFalse(view.snapshot.isAllCompliant)
        XCTAssertFalse(view.snapshot.rows[0].isEnforced)
        XCTAssertTrue(view.statusHeadline.contains("非生成式"))
    }

    func testDisabledNPCDeletionFenceOrNarrativeWhitelistReportsViolation() {
        let noDeletionFenceSnapshot = NPCChatAndSceneAISafetySnapshot(
            enforcesNPCChatDeletionReReadFence: false,
            locale: Locale(identifier: "zh-Hans")
        )
        let fenceView = NPCChatAndSceneAISafetySectionView(snapshot: noDeletionFenceSnapshot)
        _ = fenceView.body

        XCTAssertFalse(fenceView.snapshot.isAllCompliant)
        XCTAssertFalse(fenceView.snapshot.rows[3].isEnforced)
        XCTAssertTrue(fenceView.statusHeadline.contains("I08"))

        let unguardedEffectsSnapshot = NPCChatAndSceneAISafetySnapshot(
            dropsForbiddenBusinessEffects: false,
            locale: Locale(identifier: "zh-Hans")
        )
        let effectsView = NPCChatAndSceneAISafetySectionView(snapshot: unguardedEffectsSnapshot)
        _ = effectsView.body

        XCTAssertFalse(effectsView.snapshot.isAllCompliant)
        XCTAssertTrue(effectsView.statusHeadline.contains("白名单"))
    }

    func testEnglishLocaleShowsNoChineseCopy() {
        let en = Locale(identifier: "en")
        for snapshot in [NPCChatAndSceneAISafetySnapshot(locale: en),
                         NPCChatAndSceneAISafetySnapshot(globalGenerationEnabled: true, enforcesNPCChatDeletionReReadFence: false, locale: en)] {
            let view = NPCChatAndSceneAISafetySectionView(snapshot: snapshot)
            _ = view.body
            let texts = [view.statusHeadline] + snapshot.rows.flatMap { [$0.title, $0.detail] }
            for text in texts {
                XCTAssertNil(text.range(of: "\\p{Han}", options: .regularExpression), text)
            }
        }
        let city = CitySwitchIsolationSnapshot.ready(locale: en)
        for row in city.rows {
            XCTAssertNil((row.title + row.detail).range(of: "\\p{Han}", options: .regularExpression))
        }
    }
}
