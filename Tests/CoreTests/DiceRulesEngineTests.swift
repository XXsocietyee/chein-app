import XCTest
@testable import QuestifyCore

final class DiceRulesEngineTests: XCTestCase {
    func testIcosahedronGeometryAndFaceOrientationParity() throws {
        let faces = DiceD20Geometry.faces
        XCTAssertEqual(faces.count, 20)

        var vertices = Set<String>()
        var edges: [String: Int] = [:]

        for face in faces {
            XCTAssertEqual(face.points.count, 3)
            for i in 0..<3 {
                let p = face.points[i]
                let key = String(format: "%.6f,%.6f,%.6f", p.x, p.y, p.z)
                vertices.insert(key)
                let nextP = face.points[(i + 1) % 3]
                let nextKey = String(format: "%.6f,%.6f,%.6f", nextP.x, nextP.y, nextP.z)
                let edgeKey = [key, nextKey].sorted().joined(separator: "|")
                edges[edgeKey, default: 0] += 1
            }

            let q = DiceD20Geometry.orientFace(face.value)
            let rotatedNormal = DiceD20Geometry.rotate(q, face.normal)
            XCTAssertLessThan(abs(rotatedNormal.x), 1e-9)
            XCTAssertLessThan(abs(rotatedNormal.y), 1e-9)
            XCTAssertGreaterThan(rotatedNormal.z, 0.999)

            let rotatedUp = DiceD20Geometry.rotate(q, face.up)
            XCTAssertGreaterThan(rotatedUp.y, 0.999, "Oriented face top vector must point upward")

            let opposite = try XCTUnwrap(faces.first { f in
                abs(f.normal.x + face.normal.x) < 1e-9 &&
                abs(f.normal.y + face.normal.y) < 1e-9 &&
                abs(f.normal.z + face.normal.z) < 1e-9
            })
            XCTAssertEqual(face.value + opposite.value, 21, "Opposite faces on D20 must sum to 21")
        }

        XCTAssertEqual(vertices.count, 12)
        XCTAssertEqual(edges.count, 30)
        XCTAssertTrue(edges.values.allSatisfy { $0 == 2 })
        XCTAssertEqual(faces.map(\.value).sorted(), Array(1...20))
    }

    func testD20RendererDualDiceSelectionAndValidation() throws {
        let renderer = DiceD20RendererState(width: 320, height: 220, count: 2)
        renderer.roll(reducedMotion: false, nowMs: 1000)
        XCTAssertEqual(renderer.mode, "roll")

        let before = renderer.lastRenderItems
        renderer.step(nowMs: 1250)
        XCTAssertNotEqual(renderer.lastRenderItems, before)

        let immediateDone = try renderer.settle(values: [1, 20], kept: 20, immediate: false, nowMs: 1250)
        XCTAssertFalse(immediateDone)
        XCTAssertEqual(renderer.mode, "settle")

        // After 1200ms of settle, dual-dice enters 'select' phase before finishing
        let doneAfterSettle = renderer.step(nowMs: 2450)
        XCTAssertFalse(doneAfterSettle)
        XCTAssertEqual(renderer.mode, "select")

        // Mid-selection: unchosen fades out, chosen moves toward center (160)
        renderer.step(nowMs: 2750)
        XCTAssertEqual(renderer.lastRenderItems.count, 2)
        XCTAssertLessThan(renderer.lastRenderItems[0].alpha, 1.0)
        XCTAssertGreaterThan(renderer.lastRenderItems[0].alpha, 0.0)
        XCTAssertGreaterThan(renderer.lastRenderItems[1].centerX, 160.0)
        XCTAssertLessThan(renderer.lastRenderItems[1].centerX, 227.2)

        // Selection finishes at +600ms
        let finished = renderer.step(nowMs: 3050)
        XCTAssertTrue(finished)
        XCTAssertEqual(renderer.mode, "done")
        XCTAssertEqual(renderer.lastRenderItems.count, 1)
        XCTAssertEqual(renderer.lastRenderItems[0].centerX, 160.0, accuracy: 1e-6)
        XCTAssertEqual(renderer.lastRenderItems[0].frontValue, 20)
        XCTAssertTrue(renderer.lastRenderItems[0].gold)

        // Disadvantage keeps 1 when authoritative kept is 1
        _ = try renderer.settle(values: [20, 1], kept: 1, immediate: true, nowMs: 4000)
        XCTAssertEqual(renderer.lastRenderItems.count, 1)
        XCTAssertEqual(renderer.lastRenderItems[0].frontValue, 1)
        XCTAssertFalse(renderer.lastRenderItems[0].gold)

        // Out-of-range face value throws
        XCTAssertThrowsError(try renderer.settle(values: [21, 1], kept: 1, immediate: true))
    }

    func testFixedSeedDeterministicDiceEngineAndReroll() {
        var rng1 = DiceSeededRNG(seed: 42)
        var rng2 = DiceSeededRNG(seed: 42)
        let seq1 = (0..<10).map { _ in rng1.rollDie(sides: 20) }
        let seq2 = (0..<10).map { _ in rng2.rollDie(sides: 20) }
        XCTAssertEqual(seq1, seq2)
        XCTAssertTrue(seq1.allSatisfy { (1...20).contains($0) })

        var checkRNG = DiceSeededRNG(seed: 1001)
        let input = DiceCheckEngine.CheckInput(
            tier: "medium",
            dc: 13,
            rollMode: .advantage,
            skillLabel: "观察",
            skillValue: 2,
            mods: [
                DiceJourneyCheckMod(label: "提着马灯", value: 2, held: true),
                DiceJourneyCheckMod(label: "夜雾", value: 3, held: true),
            ],
            situationalCap: 3,
            bargain: 1,
            momentum: 1,
            luck: 2,
            hp: 5,
            successText: "看清了暗格",
            failText: "被机关擦伤",
            failCostLabel: "体力 -1"
        )
        let receipt = DiceCheckEngine.evaluate(input: input, rng: &checkRNG)
        XCTAssertEqual(receipt.dice.count, 2)
        XCTAssertEqual(receipt.kept, receipt.dice.max())
        // Situational raw is 2 + 3 = 5, capped at 3; total = kept + 2 + 3 + 1 + 1
        let expectedTotal = (receipt.kept ?? 0) + 2 + 3 + 1 + 1
        XCTAssertEqual(receipt.total, expectedTotal)
        XCTAssertTrue(DiceJourneyCheckRules.canReroll(receipt, r5: false))

        let rerolled = DiceCheckEngine.reroll(previous: receipt, input: input, rng: &checkRNG)
        XCTAssertNotNil(rerolled)
        XCTAssertEqual(rerolled?.rerolled, true)
        XCTAssertEqual(rerolled?.luck, 1)
        XCTAssertFalse(DiceJourneyCheckRules.canReroll(rerolled, r5: false), "Cannot reroll twice")

        let settled = DiceCheckEngine.settle(receipt: rerolled!, input: input)
        XCTAssertTrue(settled.settled)
        XCTAssertEqual(settled.text, settled.success == true ? "看清了暗格" : "被机关擦伤")
    }

    func testThemeD20RulesAndTemplateValidator() {
        let initial = DiceThemeD20Rules.apply(nil, enabled: true, presetKey: "hard")
        let readout = DiceThemeD20Rules.read(initial)
        XCTAssertTrue(readout.enabled)
        XCTAssertEqual(readout.preset, "hard")
        XCTAssertEqual(readout.dcs, [12, 15, 18])
        XCTAssertEqual(readout.attrs.count, 3)
        XCTAssertEqual(readout.clocks.first?.segments, 4)
        XCTAssertEqual(DiceThemeD20Rules.summary(initial), "硬核 · 3 项属性 · 1 个进度钟")

        let noCheck = DiceThemeD20Rules.setCheckEnabled(initial, checkEnabled: false)
        XCTAssertTrue(DiceThemeD20Rules.summary(noCheck).contains("仅记录数值"))

        let withWindow = DiceThemeD20Rules.setPlayWindow(noCheck, key: "night")
        XCTAssertEqual(DiceThemeD20Rules.playWindowOf(withWindow), "night")
        XCTAssertEqual(DiceThemeD20Rules.playWindowLabel(withWindow), "夜行场")

        let withPrep = DiceThemeD20Rules.setPrep(withWindow, list: [" 穿好走的鞋 ", "带耳机", "带耳机"])
        XCTAssertEqual(DiceThemeD20Rules.prepOf(withPrep), ["穿好走的鞋", "带耳机"])

        var tpl = DiceD20TemplateConfig(mode: "d20", dc: 15, modifier: 2, rollMode: "disadvantage", successText: "成功文案", failText: "失败文案")
        XCTAssertEqual(DiceD20TemplateValidator.validate(tpl), "")
        let preview = DiceD20TemplateValidator.previewD20Result(tpl)
        XCTAssertEqual(preview.values, [12, 7])
        XCTAssertEqual(preview.kept, 7)
        XCTAssertEqual(preview.total, 9)
        XCTAssertFalse(preview.success)
        XCTAssertEqual(preview.text, "失败文案")

        tpl.dc = 41
        XCTAssertFalse(DiceD20TemplateValidator.validate(tpl).isEmpty)
    }

    func testJourneyCheckReceiptViewRedactionAndHelpers() {
        let normalWire: PlayWireValue = .object([
            "tier": .string("hard"),
            "dc": .int(16),
            "dice": .array([.int(20)]),
            "kept": .int(20),
            "total": .int(23),
            "success": .bool(true),
            "nat": .string("CRIT"),
            "settled": .bool(false),
            "luck": .int(1),
            "breakdown": .object([
                "die": .int(20),
                "skill": .object(["label": .string("胆量"), "value": .int(3)]),
            ]),
        ])
        let view = DiceJourneyCheckRules.receiptView(from: normalWire)
        XCTAssertFalse(view.detailsHidden)
        XCTAssertEqual(DiceJourneyCheckRules.natTag(view), "天然 20")
        XCTAssertEqual(DiceJourneyCheckRules.marginText(view), "过线 7 点")
        XCTAssertEqual(DiceJourneyCheckRules.trackPct(20), 100.0, accuracy: 1e-6)
        XCTAssertEqual(DiceJourneyCheckRules.trackPct(1), 0.0, accuracy: 1e-6)
        XCTAssertEqual(view.breakdownRows, [
            DiceJourneyBreakdownRow(label: "骰子", value: "20"),
            DiceJourneyBreakdownRow(label: "胆量", value: "+3"),
        ])

        let redactedWire: PlayWireValue = .object([
            "detailsHidden": .bool(true),
            "dc": .int(16),
            "dice": .array([.int(20)]),
            "kept": .int(20),
            "total": .int(23),
            "success": .bool(true),
            "nat": .string("CRIT"),
        ])
        let redacted = DiceJourneyCheckRules.receiptView(from: redactedWire)
        XCTAssertTrue(redacted.detailsHidden)
        XCTAssertNil(redacted.kept)
        XCTAssertNil(redacted.total)
        XCTAssertTrue(redacted.dice.isEmpty)
        XCTAssertEqual(DiceJourneyCheckRules.natTag(redacted), "")
        XCTAssertEqual(DiceJourneyCheckRules.marginText(redacted), "")
    }
}
