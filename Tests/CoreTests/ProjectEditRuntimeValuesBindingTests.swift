import XCTest
@testable import QuestifyCore

/// MP `fabu/theme-values.js` `references` (node gameplay-binding walk) and `theme-runtime.js`
/// `saveValueEditor` with `r.attributeBinding` (definition read-only, 关联 still saved).
final class ProjectEditRuntimeValuesBindingTests: XCTestCase {
    private let key = "counter.stamina"

    private func base() throws -> ProjectEditDraft {
        var draft = ProjectEditSyntheticFixtures.draft(product: .city)
        let data = try JSONEncoder().encode(ProjectEditJSON.object(["schemaVersion": .number(1)]))
        draft.preserved["themeRuntimeConfig"] = .string(try XCTUnwrap(String(data: data, encoding: .utf8)))
        return try ProjectEditRuntimeStats.setEnabled(true, .hp, in: draft)
    }

    private func rules(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
        try ProjectEditD20Rules.readable(draft)
    }

    private func withRules(_ draft: ProjectEditDraft, _ change: (inout [String: ProjectEditJSON]) -> Void) throws -> ProjectEditDraft {
        var object = try rules(draft)
        change(&object)
        var next = draft
        next.preserved["journeyRules"] = .object(object)
        return next
    }

    private var row: ProjectEditJSON {
        .object(["key": .string(key), "label": .string("体力"), "min": .number(0), "max": .number(10), "initial": .number(5), "visible": .bool(true)])
    }

    func testNodeGameplayBindingBlocksRemovalWithItsPath() throws {
        let saved = try withRules(try base()) { $0["attributes"] = .array([row]) }
        var draft = saved
        var chapter = ProjectEditChapter()
        var named = ProjectEditNode()
        named.name = "钟楼"
        // MP walk: JSON text starting with { or [ is parsed; arrays add [n] (1-based).
        named.localMetadata["templateInfo"] = .string("{\"rules\":[{\"statKey\":\"other\"},{\"statKey\":\"\(key)\"}]}")
        var unnamed = ProjectEditNode()
        unnamed.localMetadata["binding"] = .object(["sourceKey": .string(key)])
        chapter.nodes = [named, unnamed]
        draft.chapters = [chapter]
        let found = ProjectEditRuntimeValues.references(key, in: draft)
        XCTAssertEqual(found, [
            .node(chapter: 1, node: "钟楼", path: "templateInfo.rules.[2]statKey"),
            .node(chapter: 1, node: "2", path: "binding.sourceKey"),
        ])
        XCTAssertThrowsError(try ProjectEditRuntimeValues.remove(key, in: draft)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeValues.Refusal, .referenced(found))
        }
        // Plain text and other keys never count.
        draft.chapters[0].nodes[0].localMetadata["templateInfo"] = .string("statKey \(key)")
        draft.chapters[0].nodes[1].localMetadata["binding"] = .object(["note": .string(key)])
        XCTAssertTrue(ProjectEditRuntimeValues.references(key, in: draft).isEmpty)
        XCTAssertNoThrow(try ProjectEditRuntimeValues.remove(key, in: draft))
    }

    func testBoundTopicSavesOnlyTheLink() throws {
        let bound = try withRules(try base()) {
            $0["attributes"] = .array([row])
            $0["attributeBinding"] = .object(["enabledKeys": .array([.string(key)])])
        }
        let value = try XCTUnwrap(ProjectEditRuntimeValues.values(in: bound).first)
        XCTAssertTrue(ProjectEditRuntimeValues.bound(in: bound))
        // MP: link on writes one default link; the definition is untouched.
        let linked = try ProjectEditRuntimeValues.save(value, link: true, in: bound)
        XCTAssertTrue(ProjectEditRuntimeValues.linked(key, in: linked))
        XCTAssertEqual(try rules(linked)["attributes"], .array([row]))
        XCTAssertEqual(try rules(linked)["stateEnabled"], .bool(true))
        let unlinked = try ProjectEditRuntimeValues.save(value, link: false, in: linked)
        XCTAssertFalse(ProjectEditRuntimeValues.linked(key, in: unlinked))
        // MP: 属性定义已变化，请重新读取后编辑关联.
        var changed = value
        changed.max = 20
        XCTAssertThrowsError(try ProjectEditRuntimeValues.save(changed, link: true, in: bound)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeValues.Refusal, .copy(ProjectEditRuntimeValues.Copy.definitionChanged))
        }
        // MP: 请先在初始状态中启用注册属性.
        let disabled = try withRules(bound) { $0["attributeBinding"] = .object(["enabledKeys": .array([])]) }
        XCTAssertThrowsError(try ProjectEditRuntimeValues.save(value, link: true, in: disabled)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeValues.Refusal, .copy(ProjectEditRuntimeValues.Copy.notEnabled))
        }
        // Removing stays with 初始状态 (MP removeValue on a bound topic).
        XCTAssertThrowsError(try ProjectEditRuntimeValues.remove(key, in: bound)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeValues.Refusal, .copy(ProjectEditRuntimeValues.Copy.bound))
        }
    }
}
