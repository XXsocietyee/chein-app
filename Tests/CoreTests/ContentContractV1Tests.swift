import XCTest
@testable import QuestifyCore

/// Runs the official zip-v35 content-contract vectors. The JSON files are the contract, not samples.
final class ContentContractV1Tests: XCTestCase {
    func testOfficialVectorFileMatchesTheSchemaIdentity() throws {
        let root = try vectors()
        XCTAssertEqual(text(root["contract"]), ContentContractV1.contract)
        XCTAssertEqual(root["contractVersion"].integer, Optional(ContentContractV1.contractVersion))
        XCTAssertEqual(text(root["schema"]), "docs/contracts/content-schema.v1.json")
        let schema = try schemaDocument()
        XCTAssertEqual(schema["contractVersion"].integer, Optional(1))
        XCTAssertEqual(schema["x-cy-sections"]["sections"].array?.count, Optional(43))
        XCTAssertEqual(root["vectors"]["save"].array?.count, Optional(8))
        XCTAssertEqual(root["vectors"]["publicProjection"].array?.count, Optional(2))
        XCTAssertEqual(root["vectors"]["freeze"].array?.count, Optional(1))
        XCTAssertEqual(root["vectors"]["runQuota"].array?.count, Optional(5))
        XCTAssertEqual(root["vectors"]["hintPolicy"].array?.count, Optional(3))
        XCTAssertEqual(root["vectors"]["requestIdempotency"].array?.count, Optional(1))
        XCTAssertEqual(root["vectors"]["skip"].array?.count, Optional(2))
        XCTAssertEqual(root["vectors"]["hangman"].array?.count, Optional(6))
        XCTAssertEqual(root["vectors"]["accusation"].array?.count, Optional(2))
        XCTAssertEqual(root["vectors"]["capability"].array?.count, Optional(1))
        XCTAssertEqual(root["vectors"]["sections"].array?.count, Optional(72))
    }

    /// OWN-10.3.c: the schema stays a test resource that registers `outcomeRules` as an open author section, and an
    /// author's pass/fail feedback round-trips through the wire value unchanged (the client never rewrites it).
    func testOutcomeRulesPassFailFeedbackRoundTrips() throws {
        let schema = try schemaDocument()
        XCTAssertNotNil(schema["$defs"]["outcomeRulesSection"].object)
        let raw = #"{"outcomeRules":{"version":1,"pass":{"feedback":"答对了，去下一站"},"fail":{"feedback":"差一点，再看看线索"}}}"#
        let value = try JSONDecoder().decode(PlayWireValue.self, from: Data(raw.utf8))
        let again = try JSONDecoder().decode(PlayWireValue.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(again, value)
        XCTAssertEqual(text(again["outcomeRules"]["pass"]["feedback"]), "答对了，去下一站")
        XCTAssertEqual(text(again["outcomeRules"]["fail"]["feedback"]), "差一点，再看看线索")
    }

    func testSaveVectors() throws {
        for item in try vectors()["vectors"]["save"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let expect = item["expect"]
            if let needle = text(expect["rejectContains"]) {
                XCTAssertThrowsError(try ContentContractV1.validate(item["config"]), id) { error in
                    XCTAssertTrue((error as? ContentContractV1.Rejection)?.message.contains(needle) == true, "\(id) \(error)")
                }
            } else {
                let report = try ContentContractV1.validate(item["config"])
                if let mechanic = expect["mechanic"].bool { XCTAssertEqual(report.mechanic, mechanic, id) }
                if let present = text(expect["present"]) { XCTAssertEqual(report.present, present, id) }
                if expect.object?.keys.contains("ladderSize") == true {
                    XCTAssertEqual(report.ladderSize, expect["ladderSize"].integer, id)
                }
                if expect.object?.keys.contains("quota") == true {
                    XCTAssertEqual(report.quota, expect["quota"].integer, id)
                }
            }
        }
    }

    func testSectionVectors() throws {
        for item in try vectors()["vectors"]["sections"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let expect = item["expect"]
            if expect["accepted"].bool == true {
                XCTAssertNoThrow(try ContentContractV1.validate(item["config"]), id)
            } else if let needle = text(expect["rejectContains"]) {
                XCTAssertThrowsError(try ContentContractV1.validate(item["config"]), id) { error in
                    XCTAssertTrue((error as? ContentContractV1.Rejection)?.message.contains(needle) == true, "\(id) \(error)")
                }
            } else {
                XCTFail("section \(id) has no expectation")
            }
        }
    }

    func testPublicProjectionVectors() throws {
        let root = try vectors()
        let saves = Dictionary(uniqueKeysWithValues: (root["vectors"]["save"].array ?? []).map { (text($0["id"]) ?? "", $0["config"]) })
        for item in root["vectors"]["publicProjection"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let config = item.object?.keys.contains("config") == true ? item["config"] : saves[text(item["configRef"]) ?? ""] ?? .null
            let expect = item["expect"]
            let projected = try ContentContractV1.project(config)
            XCTAssertEqual(text(projected["present"]), text(expect["present"]), id)
            for key in strings(expect["rootAbsentKeys"]) {
                XCTAssertFalse(projected.object?.keys.contains(key) == true, "\(id) root \(key)")
            }
            if expect.object?.keys.contains("hangman") == true {
                let hangman = projected["hangman"]
                XCTAssertEqual(hangman["enabled"].bool, expect["hangman"]["enabled"].bool, id)
                XCTAssertEqual(hangman["length"].integer, expect["hangman"]["length"].integer, id)
                XCTAssertEqual(hangman["blankCount"].integer, expect["hangman"]["blankCount"].integer, id)
                XCTAssertEqual(hangman["caseSensitive"].bool, expect["hangman"]["caseSensitive"].bool, id)
            }
            for key in strings(expect["hangmanAbsentKeys"]) {
                XCTAssertFalse(projected["hangman"].object?.keys.contains(key) == true, "\(id) hangman \(key)")
            }
            if expect.object?.keys.contains("accusation") == true {
                let accusation = projected["accusation"]
                XCTAssertEqual(accusation["enabled"].bool, expect["accusation"]["enabled"].bool, id)
                let suspects = accusation["suspects"].array ?? []
                expectInt(suspects.count, expect["accusation"]["suspectCount"], id)
                XCTAssertEqual(suspects.compactMap { text($0["name"]) }, strings(expect["accusation"]["suspectNames"]), id)
                XCTAssertEqual(accusation["earlyAccuse"]["allowed"].bool, expect["accusation"]["earlyAllowed"].bool, id)
                let testimony = suspects.reduce(0) { $0 + ($1["testimony"].array?.count ?? 0) }
                expectInt(testimony, expect["accusation"]["testimonyCount"], id)
            }
            for key in strings(expect["accusationAbsentKeys"]) {
                XCTAssertFalse(projected["accusation"].object?.keys.contains(key) == true, "\(id) accusation \(key)")
            }
            for option in projected["qa"]["options"].array ?? [] {
                for key in strings(expect["qaOptionAbsentKeys"]) {
                    XCTAssertFalse(option.object?.keys.contains(key) == true, "\(id) qa \(key)")
                }
            }
            if let qaEnabled = expect["qaEnabled"].bool {
                XCTAssertEqual(projected["qa"]["enabled"].bool == true, qaEnabled, id)
            }
            let encoded = String(decoding: try JSONEncoder().encode(projected), as: UTF8.self)
            for needle in strings(expect["forbiddenSubstrings"]) {
                XCTAssertFalse(encoded.contains(needle), "\(id) leaked \(needle)")
            }
        }
    }

    func testHangmanVectors() throws {
        for item in try vectors()["vectors"]["hangman"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let section = item["section"]
            let expect = item["expect"]
            if expect.object?.keys.contains("submits") != true, let needle = text(expect["rejectContains"]) {
                XCTAssertThrowsError(try ContentContractV1.validateHangmanSection(section), id) { error in
                    XCTAssertTrue((error as? ContentContractV1.Rejection)?.message.contains(needle) == true, "\(id) \(error)")
                }
                continue
            }
            let safe = try ContentContractV1.hangmanSafeConfig(section)
            if expect.object?.keys.contains("safeConfig") == true {
                expectBool(safe.enabled, expect["safeConfig"]["enabled"], id)
                expectInt(safe.length, expect["safeConfig"]["length"], id)
                expectInt(safe.blankCount, expect["safeConfig"]["blankCount"], id)
                expectBool(safe.caseSensitive, expect["safeConfig"]["caseSensitive"], id)
            }
            if expect.object?.keys.contains("projection") == true {
                let board = try ContentContractV1.hangmanBoard(section)
                XCTAssertEqual(board.display, text(expect["projection"]["display"]), id)
                expectInt(board.length, expect["projection"]["length"], id)
                expectInt(board.blankCount, expect["projection"]["blankCount"], id)
                expectBool(board.solved, expect["projection"]["solved"], id)
            }
            for submit in expect["submits"].array ?? [] {
                if let needle = text(submit["expect"]["rejectContains"]) {
                    XCTAssertThrowsError(try ContentContractV1.hangmanSubmit(section, payload: submit["payload"]), id) { error in
                        XCTAssertTrue((error as? ContentContractV1.Rejection)?.message.contains(needle) == true, "\(id) \(error)")
                    }
                    continue
                }
                let got = try ContentContractV1.hangmanSubmit(section, payload: submit["payload"])
                let wanted = submit["expect"]
                XCTAssertEqual(got.verdict, text(wanted["verdict"]), id)
                XCTAssertEqual(got.display, text(wanted["display"]), id)
                expectBool(got.solved, wanted["solved"], id)
                expectBool(got.alreadySolved, wanted["alreadySolved"], id)
                if wanted["answerTextAbsent"].bool == true {
                    XCTAssertNil(got.answerText, id)
                } else if wanted.object?.keys.contains("answerText") == true {
                    XCTAssertEqual(got.answerText, text(wanted["answerText"]), id)
                }
            }
        }
    }

    func testAccusationVectors() throws {
        for item in try vectors()["vectors"]["accusation"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let config = item["config"]
            let expect = item["expect"]
            XCTAssertNoThrow(try ContentContractV1.validate(config), id)
            if let enabled = expect["enabled"].bool {
                XCTAssertEqual(ContentContractV1.accusationEnabled(config), enabled, id)
            }
            if expect.object?.keys.contains("correctSuspectId") == true {
                XCTAssertEqual(ContentContractV1.accusationCorrectID(config), text(expect["correctSuspectId"]), id)
            }
            if expect.object?.keys.contains("public") == true {
                let projected = try ContentContractV1.project(config)["accusation"]
                XCTAssertEqual(projected["enabled"].bool, expect["public"]["enabled"].bool, id)
                expectInt(projected["suspects"].array?.count ?? -1, expect["public"]["suspectCount"], id)
                let testimony = (projected["suspects"].array ?? []).reduce(0) { $0 + ($1["testimony"].array?.count ?? 0) }
                expectInt(testimony, expect["public"]["testimonyCount"], id)
                XCTAssertEqual(projected["earlyAccuse"]["allowed"].bool, expect["public"]["earlyAllowed"].bool, id)
                let encoded = String(decoding: try JSONEncoder().encode(projected), as: UTF8.self)
                for needle in strings(expect["forbiddenSubstrings"]) {
                    XCTAssertFalse(encoded.contains(needle), "\(id) leaked \(needle)")
                }
            }
            if expect["publicEnabled"].bool == false {
                let projected = try ContentContractV1.project(config)
                XCTAssertNotEqual(projected["accusation"]["enabled"].bool, true, id)
            }
            if expect["resultScreenNull"].bool == true {
                XCTAssertFalse(ContentContractV1.accusationEnabled(config), id)
            }
            for submission in expect["cases"].array ?? [] {
                let got = ContentContractV1.accusationOutcome(config, submission: submission)
                let wanted = submission["expect"]
                XCTAssertEqual(got.verdict, text(wanted["verdict"]), id)
                expectBool(got.correct, wanted["correct"], id)
                expectBool(got.early, wanted["early"], id)
                XCTAssertEqual(got.recordCode, text(wanted["recordCode"]), id)
                expectBool(got.canRetry, wanted["canRetry"], id)
                expectBool(got.terminal, wanted["terminal"], id)
                XCTAssertEqual(got.endingScreen, text(wanted["endingScreen"]), id)
                XCTAssertEqual(got.refuseCode, text(wanted["refuseCode"]), id)
            }
        }
    }

    func testHintPolicyAndSkipVectors() throws {
        let root = try vectors()
        for item in root["vectors"]["hintPolicy"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let unlocked = (item["unlockedLevels"].array ?? []).compactMap(\.integer)
            let got = ContentContractV1.hintPolicy(ladder: item["ladder"], unlockedLevels: unlocked,
                                                   remainingFreeUses: item["remainingFreeUses"].integer ?? -1)
            let wanted = item["expect"].array ?? []
            XCTAssertEqual(got.count, wanted.count, id)
            for (layer, expect) in zip(got, wanted) {
                expectInt(layer.level, expect["level"], id)
                XCTAssertEqual(layer.type, text(expect["type"]), id)
                expectBool(layer.usable, expect["usable"], id)
                expectBool(layer.unlocked, expect["unlocked"], id)
                expectBool(layer.free, expect["free"], id)
                expectInt(layer.costPoints, expect["costPoints"], id)
                expectInt(layer.freeQuota, expect["freeQuota"], id)
                XCTAssertEqual(layer.reason, text(expect["reason"]), id)
            }
        }
        for item in root["vectors"]["skip"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let got = ContentContractV1.skipFact(ladder: item["ladder"])
            expectBool(got.configured, item["expect"]["skipConfigured"], id)
            expectBool(got.usable, item["expect"]["skipUsable"], id)
            XCTAssertFalse(UGGameplay.offersSkipButton, id)
        }
    }

    func testRunQuotaAndFreezeUseTheExistingReader() throws {
        let root = try vectors()
        for item in root["vectors"]["runQuota"].array ?? [] {
            let id = text(item["id"]) ?? "?"
            let finding = try ContentContractV1.runQuota(item["snapshot"])
            if let reason = text(item["expect"]["rejectReason"]) {
                XCTAssertEqual(finding, .conflict, id)
                XCTAssertEqual(finding.conflictReason, reason, id)
                XCTAssertNil(finding.literal, id)
            } else if item["expect"]["value"] == .null {
                XCTAssertEqual(finding, .legacyNull, id)
                XCTAssertNil(finding.literal, id)
            } else {
                XCTAssertEqual(finding, .value(item["expect"]["value"].integer ?? -1), id)
            }
        }
        let freeze = root["vectors"]["freeze"].array?.first ?? .null
        let run = try ContentContractV1.runQuota(freeze["snapshot"])
        let frozen = try ContentContractV1.runQuota(freeze["frozenAnswer"])
        XCTAssertEqual(run, .value(freeze["expect"]["runFreeUses"].integer ?? -1))
        XCTAssertEqual(frozen, .value(freeze["expect"]["frozenUses"].integer ?? -1))
    }

    func testCapabilityVectorsUseTheDeclarationDecoder() throws {
        let item = try vectors()["vectors"]["capability"].array?.first ?? .null
        let required = (item["required"].array ?? []).compactMap { row -> UGRequiredCapability? in
            guard let key = text(row["key"]), let version = row["minVersion"].integer else { return nil }
            return UGRequiredCapability(key: key, minVersion: version)
        }
        for row in item["cases"].array ?? [] {
            let id = text(row["id"]) ?? "?"
            let declared = text(row["supportedCapabilities"]) ?? ""
            let got = UGCompatibility.evaluate(required: required, supportedCapabilities: declared)
            let expect = row["expect"]
            expectBool(got.declared, expect["declared"], id)
            XCTAssertEqual(got.source, text(expect["source"]), id)
            if expect["supported"] == .null {
                XCTAssertNil(got.supported, id)
            } else {
                XCTAssertEqual(got.supported, expect["supported"].bool, id)
            }
            XCTAssertEqual(got.missingKeys, strings(expect["missingKeys"]), id)
        }
    }

    func testRequestIdempotencyVectorSeparatesFactKeyFromFingerprint() throws {
        let item = try vectors()["vectors"]["requestIdempotency"].array?.first ?? .null
        let scope = item["scope"]
        let id = text(item["id"]) ?? "?"
        let member = item["memberId"].integer ?? 0
        let key = ContentContractV1.requestFactKey(memberID: member, scope: scope, requestID: text(item["requestId"]) ?? "")
        let otherKey = ContentContractV1.requestFactKey(memberID: member, scope: scope, requestID: text(item["otherRequestId"]) ?? "")
        let fingerprint = ContentContractV1.requestFingerprint(factKey: key, level: item["level"].integer ?? 0,
                                                              free: item["free"].bool ?? false,
                                                              chargedPoints: item["chargedPoints"].integer ?? 0)
        let otherPayload = ContentContractV1.requestFingerprint(factKey: key, level: item["otherLevel"].integer ?? 0,
                                                               free: item["otherFree"].bool ?? false,
                                                               chargedPoints: item["otherChargedPoints"].integer ?? 0)
        let again = ContentContractV1.requestFingerprint(factKey: key, level: item["level"].integer ?? 0,
                                                        free: item["free"].bool ?? false,
                                                        chargedPoints: item["chargedPoints"].integer ?? 0)
        let expect = item["expect"]
        let topic = scope["topicId"].integer.map(String.init) ?? ""
        let activity = scope["activityId"].integer.map(String.init) ?? ""
        let node = scope["nodeId"].integer.map(String.init) ?? ""
        let instance = text(scope["playInstance"]) ?? ""
        let request = text(item["requestId"]) ?? ""
        let composed = [String(member), topic, activity, node, instance, request].joined(separator: "|")
        XCTAssertEqual(key, composed, id)
        XCTAssertFalse(key.contains("|\(item["level"].integer ?? -1)|"), id)
        XCTAssertFalse(key.contains("|\(item["chargedPoints"].integer ?? -1)|"), id)
        expectBool(key == composed, expect["sameRequestFactKeyIgnoresPayload"], id)
        expectBool(fingerprint != otherPayload, expect["sameRequestDifferentPayloadChangesFingerprint"], id)
        expectBool(key != otherKey, expect["differentRequestChangesFactKey"], id)
        expectBool(fingerprint == again, expect["sameInputsStayStable"], id)
    }

    private func vectors() throws -> PlayWireValue {
        try document("docs/release/zip-v35/chengyinhub-admin/src/test/resources/contracts/content-contract-v1-vectors.json")
    }

    private func schemaDocument() throws -> PlayWireValue {
        try document("docs/release/zip-v35/docs/contracts/content-schema.v1.json")
    }

    private func document(_ relative: String) throws -> PlayWireValue {
        let url = try repoRoot().appendingPathComponent(relative)
        return try JSONDecoder().decode(PlayWireValue.self, from: Data(contentsOf: url))
    }

    private func repoRoot() throws -> URL {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let files = FileManager.default
        while !files.fileExists(atPath: root.appendingPathComponent("Core/ContentContractV1.swift").path) {
            let parent = root.deletingLastPathComponent()
            if parent.path == root.path { throw MissingContract() }
            root = parent
        }
        return root
    }

    private func expectBool(_ got: Bool, _ wanted: PlayWireValue, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Optional(got), wanted.bool, id, file: file, line: line)
    }

    private func expectInt(_ got: Int, _ wanted: PlayWireValue, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Optional(got), wanted.integer, id, file: file, line: line)
    }

    private func text(_ value: PlayWireValue) -> String? {
        if case .string(let raw) = value { return raw }
        return nil
    }

    private func strings(_ value: PlayWireValue) -> [String] {
        (value.array ?? []).compactMap { text($0) }
    }

    private struct MissingContract: Error {}
}
