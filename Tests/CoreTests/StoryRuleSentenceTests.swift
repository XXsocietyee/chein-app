import XCTest
@testable import QuestifyCore

@MainActor final class StoryRuleSentenceTests: XCTestCase {
    private func sampleNamesAndVars() -> (StoryRuleNames, [String: Int], Set<String>) {
        let journey: PlayWireValue = .object([
            "stateEnabled": .bool(true),
            "attributes": .array([
                .object(["key": .string("counter.observe"), "name": .string("观察"), "initial": .int(2)]),
                .object(["key": .string("counter.nerve"), "name": .string("胆量")]),
                .object(["key": .string("clue.ledger_half"), "name": .string("半张货单")]),
                .object(["key": .string("tag.night"), "name": .string("夜行")]),
            ]),
            "rpg": .object([
                "clocks": .array([
                    .object(["var": .string("counter.alarm"), "label": .string("巡夜人警觉"), "segments": .int(6)])
                ]),
                "aspects": .array([
                    .object(["key": .string("hurt"), "label": .string("受了伤")])
                ]),
            ]),
        ])
        let runtime: PlayWireValue = .object([
            "items": .array([
                .object(["id": .string("ilamp"), "name": .string("马灯")])
            ])
        ])
        let nodes: [PlayWireValue] = [
            .object(["id": .string("9007199254740993"), "label": .string("旧码头仓库")]),
            .object(["id": .string("node_b"), "label": .string("仓库二层")]),
        ]
        let names = StoryRuleSentenceEngine.buildNames(journey: journey, runtime: runtime, nodes: nodes, variables: ["sys.luck": 3])
        let vars = StoryRuleSentenceEngine.editorVariables(["sys.luck": 3], names: names)
        let nodeIds: Set<String> = ["9007199254740993", "node_b"]
        return (names, vars, nodeIds)
    }

    func testBuildNamesAndThreePrototypeSentences() {
        let (names, vars, nodeIds) = sampleNamesAndVars()
        XCTAssertEqual(names.attr.map(\.label), ["观察", "胆量"])
        XCTAssertEqual(names.clock.map(\.label), ["巡夜人警觉"])
        XCTAssertEqual(names.clue.map(\.key), ["clue.ledger_half"])
        XCTAssertEqual(names.value.map(\.label), ["幸运值"])
        XCTAssertEqual(vars["counter.observe"], 2)
        XCTAssertEqual(vars["counter.alarm"], 0)

        let editor = StoryRuleEditorModel(names: names, variables: vars, nodeIds: nodeIds, identity: "edge:x")
        editor.openAdd(target: "conditions")
        editor.onLayerKind("attr")
        editor.onLayerName("counter.observe")
        let path0 = editor.conditionRows[0].path
        editor.onAmount(path: path0, amount: 3)

        editor.openAdd(target: "conditions")
        editor.onLayerKind("clue")
        editor.onLayerName("clue.ledger_half")

        editor.openAdd(target: "effects")
        editor.onLayerKind("clock")
        editor.onLayerName("counter.alarm")

        XCTAssertEqual(editor.conditionRows.map(\.text), ["属性 · 观察 至少 3", "已获得线索 · 半张货单"])
        XCTAssertEqual(editor.effectRows.map(\.text), ["进度钟 · 巡夜人警觉 +1"])
        XCTAssertEqual(editor.error, "")

        let saved = editor.draft
        XCTAssertEqual(saved["conditions"], .array([
            .object(["op": .string("GTE"), "var": .string("counter.observe"), "value": .int(3)]),
            .object(["op": .string("HAS_TAG"), "value": .string("clue.ledger_half")]),
        ]))
        XCTAssertEqual(saved["effects"], .array([
            .object(["op": .string("TICK_CLOCK"), "var": .string("counter.alarm"), "value": .int(1), "max": .int(6)])
        ]))
    }

    func testTopModeGroupAndInlineRowEditing() {
        let (names, vars, nodeIds) = sampleNamesAndVars()
        let initial: PlayWireValue = .object([
            "conditions": .array([
                .object(["op": .string("HAS_TAG"), "value": .string("clue.ledger_half")]),
                .object(["op": .string("GTE"), "var": .string("counter.observe"), "value": .int(3)]),
            ]),
            "effects": .array([]),
        ])
        let editor = StoryRuleEditorModel(value: initial, names: names, variables: vars, nodeIds: nodeIds)
        XCTAssertTrue(editor.showTopSeg)
        editor.onTopMode("OR")
        XCTAssertEqual(editor.conditionRows.map(\.text), ["已获得线索 · 半张货单", "属性 · 观察 至少 3"])
        editor.onTopMode("AND")
        XCTAssertEqual(editor.draft["conditions"].array?.count, 2)

        // Negate first condition
        editor.toggleRow(path: "conditions.0", type: "leaf")
        editor.onNegate(path: "conditions.0", value: "1")
        XCTAssertEqual(editor.conditionRows[0].text, "未获得线索 · 半张货单")

        // Change second condition attribute & comparator
        editor.toggleRow(path: "conditions.1", type: "leaf")
        editor.onPickName(path: "conditions.1", key: "counter.nerve")
        editor.onCompare(path: "conditions.1", cmpIndex: "2")
        XCTAssertEqual(editor.conditionRows[1].text, "属性 · 胆量 正好 3")

        // Remove first condition
        editor.onRemove(path: "conditions.0")
        XCTAssertEqual(editor.draft["conditions"], .array([
            .object(["op": .string("EQ"), "var": .string("counter.nerve"), "value": .int(3)])
        ]))
    }

    func testRegistryMergeAndInlineCreation() {
        let (names, vars, nodeIds) = sampleNamesAndVars()
        let merged = StoryRuleSentenceEngine.mergeRegistry(names, entries: [
            StoryRuleRegistryEntry(stateKey: "clue.ledger_half", label: "半张旧货单"),
            StoryRuleRegistryEntry(stateKey: "tag.k2", label: "被盯上"),
            StoryRuleRegistryEntry(stateKey: "counter.v1", label: "线人好感", initialValue: 2),
            StoryRuleRegistryEntry(stateKey: "clue.k9", label: ""),
        ])
        XCTAssertEqual(merged.clue.first(where: { $0.key == "clue.ledger_half" })?.label, "半张旧货单")
        XCTAssertFalse(merged.clue.contains(where: { $0.key == "clue.k9" }))
        XCTAssertEqual(merged.tag.map(\.label), ["夜行", "被盯上"])
        XCTAssertEqual(merged.value.map(\.label), ["幸运值", "线人好感"])

        let editor = StoryRuleEditorModel(names: names, variables: vars, nodeIds: nodeIds, identity: "edge:x")
        editor.openAdd(target: "conditions")
        editor.onLayerKind("clue")
        editor.onLayerQuery("暗号")
        let openRow = editor.layerRows.first(where: \.open)
        XCTAssertEqual(openRow?.names.first?.label, "新建「暗号」")
        editor.onLayerName(StoryRuleEditorModel.newKey)
        editor.onLayerName(StoryRuleEditorModel.newKey) // Duplicate tap while creating is ignored
        XCTAssertEqual(editor.createRequests, [StoryRuleCreateRequest(identity: "edge:x", kind: "clue", label: "暗号")])

        editor.names = StoryRuleSentenceEngine.mergeRegistry(names, entries: [
            StoryRuleRegistryEntry(stateKey: "clue.k3", label: "暗号")
        ])
        editor.created("clue.k3")
        XCTAssertEqual(editor.conditionRows.first?.text, "已获得线索 · 暗号")
        XCTAssertNil(editor.layer)
    }

    func testStoryParticipationAndClubTopicChapters() throws {
        var joinState = StoryProjectJoinState(
            topicId: 12,
            role: .merchant,
            myJoined: false,
            myApplyState: 0,
            stations: [
                StoryProjectStation(stationId: 1, name: "老张咖啡", roleName: "守夜人"),
                StoryProjectStation(stationId: 2, name: "巷口书店", roleName: "旧书商"),
            ]
        )
        XCTAssertEqual(joinState.joinActionTitle, "商家申请入驻")
        XCTAssertTrue(joinState.canSubmitJoin)
        joinState.switchStation(to: 1)
        XCTAssertEqual(joinState.currentStation?.name, "巷口书店")

        let coordinator = StoryParticipationCoordinator(topicId: 12, activityId: 88, fromSource: "club", joinState: joinState)
        coordinator.loadStoryNodes([
            .object([
                "nodeId": .int(101),
                "chapterNo": .int(1),
                "chapterTitle": .string("序章 · 雾起"),
                "name": .string("旧码头"),
                "storyContent": .string("夜雾笼罩了河岸。"),
                "questionType": .int(1),
                "questionTitle": .string("你要先去哪？"),
                "options": .array([
                    .object(["key": .string("A"), "label": .string("进仓库")]),
                    .object(["key": .string("B"), "label": .string("问渡工")]),
                ]),
                "distance": .int(400),
                "duration": .int(25),
            ])
        ])
        XCTAssertEqual(coordinator.chapters.count, 1)
        XCTAssertEqual(coordinator.chapters[0].title, "序章 · 雾起")
        XCTAssertEqual(coordinator.chapters[0].nodes[0].walkText, "400 m · 步行约 5 分钟")
        XCTAssertEqual(coordinator.chapters[0].nodes[0].durationText, "约 25 分钟")

        coordinator.selectAnswer(nodeId: 101, value: "A")
        let req = try coordinator.buildAnswerRequest(nodeId: 101)
        XCTAssertEqual(req.endpoint, "api/club/topic-node-answer")
        XCTAssertEqual(req.payload["answer"], .string("A"))
        XCTAssertEqual(StoryClubTopicRules.answerEndpoint(from: "topic"), "api/topic/host-node-answer")
    }
}
