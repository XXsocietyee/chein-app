import XCTest
@testable import QuestifyCore

/// MP `theme-runtime-structure.js` kind `endings`: add / fallback / remove / save and the `endings` part of `validate`.
final class ProjectEditRuntimeEndingsTests: XCTestCase {
    func testAddNumbersRowsAndFirstRowIsTheDefault() throws {
        var rows = try ProjectEditRuntimeEndings.adding(to: [])
        rows = try ProjectEditRuntimeEndings.adding(to: rows)
        XCTAssertEqual(rows.map(\.id), ["ending_1", "ending_2"])
        XCTAssertEqual(rows.map(\.fallback), [true, false])
        rows = ProjectEditRuntimeEndings.choosingFallback(1, in: rows)
        XCTAssertEqual(rows.map(\.fallback), [false, true])
        var full: [ProjectEditRuntimeEndings.Row] = []
        for _ in 0..<30 { full = try ProjectEditRuntimeEndings.adding(to: full) }
        XCTAssertThrowsError(try ProjectEditRuntimeEndings.adding(to: full)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditRuntimeEndings.Copy.tooMany))
        }
    }

    func testSaveWritesEndingsAndRefusesMissingNameOrSecondDefault() throws {
        let start = try draft(["schemaVersion": .number(1), "gameplayRuntime": .object(["runtimeScope": .string("TEAM")])])
        var rows = try ProjectEditRuntimeEndings.adding(to: [])
        XCTAssertThrowsError(try ProjectEditRuntimeEndings.save(rows, into: start)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditRuntimeEndings.Copy.fields))
        }
        rows[0].title = "成功撤离"
        rows[0].summary = "全队带着物资离开。"
        let saved = try ProjectEditRuntimeEndings.save(rows, into: start)
        XCTAssertEqual(ProjectEditRuntimeEndings.rows(in: saved), rows)
        XCTAssertNil(ProjectEditRuntimeEndings.issueKey(in: saved))
        rows.append(.init(id: "ending_2", title: "全军覆没", fallback: true))
        XCTAssertThrowsError(try ProjectEditRuntimeEndings.save(rows, into: start)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditRuntimeEndings.Copy.fallback))
        }
    }

    func testRemoveIsRefusedWhileAVotePlanEndsThere() throws {
        let plans: ProjectEditJSON = .array([.object(["endingKey": .string("ending_1")])])
        let theme = try draft(["schemaVersion": .number(1), "gameplayRuntime": .object(["plans": plans]),
                               "endings": .array([.object(["id": .string("ending_1"), "title": .string("撤离"),
                                                           "summary": .string(""), "fallback": .bool(true)])])])
        let rows = ProjectEditRuntimeEndings.rows(in: theme)
        XCTAssertThrowsError(try ProjectEditRuntimeEndings.removing(0, from: rows, in: theme)) { error in
            XCTAssertEqual(error as? ProjectEditRuntimeActsError, .refused(ProjectEditRuntimeEndings.Copy.inUse))
        }
    }

    func testPublishCheckListsTheIssueButACloudDraftSkipsIt() throws {
        let plans: ProjectEditJSON = .array([.object(["endingKey": .string("ending_9")])])
        let broken = try draft(["schemaVersion": .number(1), "gameplayRuntime": .object(["plans": plans])])
        XCTAssertEqual(ProjectEditRuntimeEndings.issueKey(in: broken), ProjectEditRuntimeEndings.Copy.plan)
        let ids = ProjectEditValidation.issues(broken, scope: .full).map(\.id)
        XCTAssertTrue(ids.contains(ProjectEditRuntimeEndings.issueID))
        let draftIDs = ProjectEditSubmissionIntent.saveCloudDraft.issues(broken, scope: .full, baseline: nil).map(\.id)
        XCTAssertFalse(draftIDs.contains(ProjectEditRuntimeEndings.issueID))
        let location = ProjectEditIssueLocation.location(for: .init(ProjectEditRuntimeEndings.issueID, ProjectEditRuntimeEndings.Copy.plan),
                                                          in: broken, scope: .full)
        XCTAssertEqual(location, .root(anchor: ProjectEditRuntimeEndings.anchor))
        let noRuntime = try draft(["schemaVersion": .number(1), "endings": .array([.object(["id": .string("BAD")])])])
        XCTAssertNil(ProjectEditRuntimeEndings.issueKey(in: noRuntime))
    }

    private func draft(_ theme: [String: ProjectEditJSON]) throws -> ProjectEditDraft {
        var draft = ProjectEditSyntheticFixtures.draft(product: .city)
        let data = try JSONEncoder().encode(ProjectEditJSON.object(theme))
        draft.preserved["themeRuntimeConfig"] = .string(try XCTUnwrap(String(data: data, encoding: .utf8)))
        return draft
    }
}
