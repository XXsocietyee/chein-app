import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Cast contract v1 (hengyin docs/design/cast-contract-1119.md) plus feat/cast-1119.
/// Fictional sample text only. PlayExperienceCoordinator stays with P2, so coordinator
/// behaviour is exercised on CastCoordinator. Document and topic fields P2/P3 own are
/// read through CastRuntimeFacts and CastConfig.fromTopic.
final class CastContractsTests: XCTestCase {
    static let config = ##"{"enabled":true,"playerName":true,"playerIdentity":true,"identities":[{"key":"i_a","title":"信使","sub":"替灯塔送一封信"},{"key":"i_a","title":"重复"}],"cast":[{"id":"c_a","name":"阿岚","identity":"守塔人，雾夜里点灯的人","color":"#3d8bfd","voice":{"mode":"preset","preset":"warm_female"},"clues":[{"text":"她总在午夜换灯芯","chapterId":null},{"text":"塔下埋着一只铁盒","chapterId":9}],"lockedCount":2,"endingLines":{"high":"灯会一直为你亮着。","low":"她没有回头。"}},{"id":"c_b","name":"渡口","color":"#123456","voice":{"mode":"none"}},{"id":"c_a","name":"重复编号"},{"id":"c_c","name":"名字太长了超过八个字"}]}"##

    func testAbsentNullDisabledOrMalformedConfigMeansFeatureOff() throws {
        XCTAssertNil(CastConfig(raw: .null))
        XCTAssertNil(CastConfig(raw: try wire(#"{"enabled":false,"cast":[{"id":"c_a","name":"阿岚"}]}"#)))
        XCTAssertNil(CastConfig(raw: .string("not json")))
        XCTAssertNil(CastConfig(raw: .array([])))
    }
    func testConfigDecodesLimitsPaletteAndJSONTextColumn() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        XCTAssertEqual(config.cast.map(\.id), ["c_a", "c_b"])
        XCTAssertEqual(config.identities.map(\.key), ["i_a"])
        XCTAssertEqual(config.cast[0].color, "#3D8BFD")
        XCTAssertEqual(config.cast[1].color, CastMember.neutralColor)
        XCTAssertTrue(config.cast[0].hasPresetVoice); XCTAssertFalse(config.cast[1].hasPresetVoice)
        XCTAssertEqual(config.cast[0].identityLead, "守塔人")
        XCTAssertEqual(CastConfig(raw: .string(Self.config)), config)
        let many = "[" + (0..<15).map { #"{"id":"c_\#($0)","name":"人\#($0)"}"# }.joined(separator: ",") + "]"
        XCTAssertEqual(CastConfig(raw: try wire(#"{"enabled":true,"cast":\#(many)}"#))?.cast.count, 12)
    }
    func testStartStepOnlyWhenAskingAndNoProfile() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        XCTAssertTrue(config.needsStartStep(profile: nil))
        XCTAssertFalse(config.needsStartStep(profile: CastPlayerProfile(name: nil, identityKey: nil)))
        let silent = try XCTUnwrap(CastConfig(raw: wire(#"{"enabled":true,"playerName":false,"playerIdentity":true,"identities":[],"cast":[]}"#)))
        XCTAssertFalse(silent.asksPlayer); XCTAssertFalse(silent.needsStartStep(profile: nil))
    }
    func testProfileIsFoundInRunStateAndTrimmed() throws {
        let profile = CastPlayerProfile.find(in: try wire(#"{"routeState":{"playerProfile":{"name":"  小舟  ","identityKey":"i_a"}}}"#))
        XCTAssertEqual(profile, CastPlayerProfile(name: "小舟", identityKey: "i_a"))
        XCTAssertNil(CastPlayerProfile.find(in: try wire(#"{"routeState":{}}"#)))
        XCTAssertNil(CastPlayerProfile(name: "   ", identityKey: "").name)
    }
    func testLineBlocksResolveSpeakersAndFillPlayerVariables() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        let chapter = try ChapterStoryDocument(raw: wire(#"{"chapterId":8,"blocks":[{"key":"b1","type":"line","speaker":"c_a","content":"{玩家}，你来了。","audioUrl":"https://voice.test/a.mp3"},{"key":"b2","type":"line","speaker":"player","content":"我是{身份}。"},{"key":"b3","type":"line","speaker":"c_gone","content":"被删掉的角色"},{"type":"line","speaker":"c_a","content":"   "}]}"#))
        let named = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:],
            cast: CastStoryContext(config: config, profile: CastPlayerProfile(name: "小舟", identityKey: "i_a")))
        XCTAssertEqual(named.map(\.content), [
            .line(.init(speaker: .cast("c_a"), text: "小舟，你来了。", audioURL: "https://voice.test/a.mp3", blockKey: "b1")),
            .line(.init(speaker: .player, text: "我是信使。", blockKey: "b2")),
            .line(.init(speaker: nil, text: "被删掉的角色", blockKey: "b3"))])
        let anonymous = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:],
            cast: CastStoryContext(config: config, profile: nil))
        XCTAssertEqual(anonymous.first?.content, .line(.init(speaker: .cast("c_a"), text: "你，你来了。", audioURL: "https://voice.test/a.mp3", blockKey: "b1")))
        let off = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:])
        XCTAssertEqual(off[0].content, .line(.init(speaker: nil, text: "{玩家}，你来了。", audioURL: "https://voice.test/a.mp3", blockKey: "b1")))
    }
    func testTextWhoMovesToTheMarginOfTheFirstParagraphOnly() throws {
        let chapter = try ChapterStoryDocument(raw: wire(#"{"chapterId":8,"blocks":[{"type":"text","who":"船夫","content":"雾很大。\n\n我们等一等。"},{"type":"text","who":"  ","content":"无名"}]}"#))
        let rows = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:])
        XCTAssertEqual(rows.map(\.content), [.line(.init(speaker: .named("船夫"), text: "雾很大。")), .text("我们等一等。"), .text("无名")])
        XCTAssertFalse(rows.contains { if case .text(let text) = $0.content { return text.contains("：") }; return false })
    }
    func testTrustTicksBandsAndShapes() throws {
        XCTAssertEqual(CastTrust(raw: try wire(#"{"c_a":3,"c_b":"-1"}"#)).values, ["c_a": 3, "c_b": -1])
        XCTAssertEqual(CastTrust(raw: try wire(#"[{"castId":"c_a","trust":2},{"castId":"c_b","value":-2}]"#)).values, ["c_a": 2, "c_b": -2])
        XCTAssertEqual([-3, 0, 2, 9].map(CastTrust.filledTicks), [0, 0, 2, 5])
        XCTAssertEqual([-1, 0, 2, 3].map(CastTrust.band), [.low, .mid, .mid, .high])
        XCTAssertEqual(CastTrust.find(in: try wire(#"{"routeState":{"trust":{"c_a":1}}}"#))["c_a"], 1)
        XCTAssertEqual(CastTrust()["missing"], 0)
    }
    func testCluesUnlockByReachedChapterAndCountWithheldText() throws {
        let member = try XCTUnwrap(CastConfig(raw: wire(Self.config))?.cast.first)
        XCTAssertEqual(member.knownClues(reachedChapters: [8]).map(\.text), ["她总在午夜换灯芯"])
        XCTAssertEqual(member.remainingClueCount(reachedChapters: [8]), 3)
        XCTAssertEqual(member.knownClues(reachedChapters: [8, 9]).count, 2)
        XCTAssertEqual(member.remainingClueCount(reachedChapters: [8, 9]), 2)
    }
    func testEndingCarriesTrustOwnerAndLegacyEndingStillDecodes() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        let raw = try wire(#"{"opener":"夜深了","fragments":[],"trust":{"c_a":4,"c_b":0},"endingFor":"c_a","endingCount":3}"#)
        let ending: PlayEndingDocument = try raw.decoded()
        XCTAssertEqual(ending.opener, "夜深了")
        let cast = CastEndingResult(raw: raw)
        XCTAssertEqual(cast.endingFor, "c_a"); XCTAssertEqual(cast.endingCount, 3)
        let rows = cast.rows(config)
        XCTAssertEqual(rows.map(\.member.id), ["c_a"]); XCTAssertEqual(rows.first?.line, "灯会一直为你亮着。")
        let legacyRaw = try wire(#"{"opener":"","fragments":[{"step":1,"name":"终点"}]}"#)
        let legacy: PlayEndingDocument = try legacyRaw.decoded()
        XCTAssertTrue(CastEndingResult(raw: legacyRaw).trust.isEmpty)
        XCTAssertNil(CastEndingResult(raw: legacyRaw).endingFor)
        XCTAssertTrue(legacy.hasStory)
    }
    func testBranchEchoAndRememberedNames() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        let echo = try XCTUnwrap(CastBranchEcho(branch: wire(#"{"lastChoice":{"label":"留下来陪她","trust":[{"castId":"c_a","delta":5},{"castId":"c_a","delta":1},{"castId":"c_x","delta":1},{"castId":"c_b","delta":0}]}}"#)))
        XCTAssertEqual(echo.label, "留下来陪她"); XCTAssertEqual(echo.trust.first?.delta, 2)
        XCTAssertEqual(CastTrustDelta.remembered(echo.trust, config: config).map(\.name), ["阿岚"])
        XCTAssertTrue(CastTrustDelta.remembered(echo.trust, config: nil).isEmpty)
        XCTAssertNil(CastBranchEcho(branch: try wire(#"{"currentStep":{"options":[]}}"#)))
    }
    func testRuntimeFactsAndTopicColumnCarryCastOrNothing() throws {
        let raw = try wire(#"{"topicId":9,"playable":true,"nodes":[],"castConfig":\#(Self.config),"playerProfile":{"name":"小舟"},"trust":{"c_a":1}}"#)
        let document: PlayExperienceDocument = try raw.decoded()
        XCTAssertEqual(document.base.topicID, 9)
        let facts = CastRuntimeFacts(raw: raw)
        XCTAssertEqual(facts.config?.cast.count, 2); XCTAssertEqual(facts.profile?.name, "小舟"); XCTAssertEqual(facts.trust["c_a"], 1)
        let plain = try wire(#"{"topicId":9,"playable":true,"nodes":[],"castConfig":null}"#)
        let plainDocument: PlayExperienceDocument = try plain.decoded()
        XCTAssertEqual(plainDocument.base.topicID, 9)
        XCTAssertNil(CastRuntimeFacts(raw: plain).config); XCTAssertNil(CastRuntimeFacts(raw: plain).profile)
        let topic = try wire(#"{"id":31,"name":"雾港","castConfig":\#(Self.config)}"#)
        XCTAssertEqual(CastConfig.fromTopic(topic)?.cast.first?.name, "阿岚")
        XCTAssertNil(CastConfig.fromTopic(try wire(#"{"id":31,"name":"雾港"}"#)))
    }
    func testProfileSaveIsGatedAndSendsExactJSON() async throws {
        let transport = CastTestTransport()
        let off = try service(transport, enabled: [])
        do { try await off.saveCastProfile(runID: 50, profile: .init(name: "小舟", identityKey: "i_a"), token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
        try await service(transport, enabled: [.castProfile]).saveCastProfile(runID: 50, profile: .init(name: "小舟", identityKey: "i_a"), token: "synthetic-token")
        let last = await transport.requests.last
        let sent = try XCTUnwrap(last)
        XCTAssertEqual(sent.httpMethod, "POST"); XCTAssertEqual(sent.url?.path, "/api/play/run/profile")
        XCTAssertEqual(String(decoding: try XCTUnwrap(sent.httpBody), as: UTF8.self), #"{"identityKey":"i_a","name":"小舟","runId":50}"#)
        try await service(transport, enabled: [.castProfile]).saveCastProfile(runID: 50, profile: .init(name: "  ", identityKey: nil), token: "synthetic-token")
        let unnamed = await transport.requests.last
        XCTAssertEqual(String(decoding: try XCTUnwrap(unnamed?.httpBody), as: UTF8.self), #"{"name":"你","runId":50}"#)
    }
    func testVoiceLookupUsesItsOwnGateAndReturnsHTTPSOrNothing() async throws {
        let transport = CastTestTransport()
        let off = try service(transport, enabled: [])
        do { _ = try await off.castVoice(topicID: 9, chapterID: 8, blockKey: "b1", token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        let reads = try service(transport, enabled: [.castVoice])
        let url = try await reads.castVoice(topicID: 9, chapterID: 8, blockKey: "b1", token: "synthetic-token")
        XCTAssertEqual(url, "https://voice.test/b1.mp3")
        let lastQuery = await transport.requests.last?.url?.query
        let query = try XCTUnwrap(lastQuery)
        XCTAssertEqual(query, "blockKey=b1&chapterId=8&topicId=9")
        let missing = try await reads.castVoice(topicID: 9, chapterID: 8, blockKey: "none", token: "synthetic-token")
        XCTAssertNil(missing)
    }
    func testChinaProductionHostRefusesCastEvenWhenGatesAreOn() async throws {
        let transport = CastTestTransport()
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let china = try CastService(configuration: APIConfiguration(baseURL: base), transport: transport,
                                    enabled: [.castProfile, .castVoice, .castBranch])
        do { _ = try await china.castVoice(topicID: 9, chapterID: 8, blockKey: "b1", token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }
    @MainActor func testCoordinatorKeepsLocalAnswerWhenSaveIsOffAndClearsOnInvalidate() async throws {
        let transport = CastTestTransport()
        let session = try PlayExperienceSession(accountID: 9, epoch: 1, namespace: "synthetic-cn", token: "synthetic-token")
        let model = CastCoordinator(service: try service(transport, enabled: []), currentSession: { session })
        model.adopt(raw: try wire(CastTestTransport.nodes), topicID: 9, runID: 50)
        XCTAssertNotNil(model.config); XCTAssertNil(model.profile)
        await model.saveProfile(name: "小舟", identityKey: "i_a")
        XCTAssertEqual(model.profile, CastPlayerProfile(name: "小舟", identityKey: "i_a")); XCTAssertTrue(model.profileLocalOnly)
        let posts = await transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertTrue(posts.isEmpty)
        model.invalidate()
        XCTAssertNil(model.config); XCTAssertNil(model.profile)
    }
    func testProfileIdentityTitleSnapshotWinsOverThemeTitle() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        let profile = try XCTUnwrap(CastPlayerProfile.find(in: wire(#"{"routeState":{"playerProfile":{"name":"小舟","identityKey":"i_a","identityTitle":"送信人"}}}"#)))
        XCTAssertEqual(profile.identityTitle, "送信人")
        XCTAssertEqual(CastStoryVariables.fill("我是{身份}", profile: profile, config: config), "我是送信人")
        XCTAssertEqual(CastPlayerProfile(name: nil, identityKey: "i_a").resolvedIdentityTitle(in: config), "信使")
    }
    func testEndingOwnerFallsBackToUniqueLeadingTrust() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        let landed = CastEndingResult(raw: try wire(#"{"opener":"","fragments":[],"trust":{"c_a":2,"c_b":1}}"#))
        XCTAssertNil(landed.endingFor); XCTAssertNil(landed.endingCount)
        XCTAssertEqual(landed.owner(config)?.id, "c_a")
        XCTAssertNil(CastEndingResult(trust: CastTrust(values: ["c_a": 2, "c_b": 2])).owner(config))
        XCTAssertNil(CastEndingResult(trust: CastTrust(values: ["c_a": -1])).owner(config))
        XCTAssertEqual(CastEndingResult(trust: CastTrust(values: ["c_a": 3]), endingFor: "c_b").owner(config)?.id, "c_b")
    }
    func testStoryBranchStopsTheFlowUntilPickedThenBecomesThePlayersLine() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        let chapter = try ChapterStoryDocument(raw: wire(#"{"chapterId":8,"blocks":[{"type":"text","content":"雾从海上来。"},{"key":"k1","type":"branch","content":"你要怎么做？","options":[{"text":"留下来陪{玩家}的灯","to":"continue","trust":[{"castId":"c_a","delta":1}]},{"text":"转身离开","to":"end"}]},{"type":"text","content":"灯还亮着。"}]}"#))
        let open = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:],
            cast: CastStoryContext(config: config, profile: CastPlayerProfile(name: "小舟", identityKey: nil)))
        XCTAssertEqual(open.count, 2)
        guard case .choice(let choice) = open[1].content else { return XCTFail() }
        XCTAssertEqual(choice.blockKey, "k1"); XCTAssertEqual(choice.question, "你要怎么做？")
        XCTAssertEqual(choice.options.map(\.text), ["留下来陪小舟的灯", "转身离开"])
        XCTAssertFalse(choice.options[0].endsFlow); XCTAssertTrue(choice.options[1].endsFlow)
        let stayed = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:],
            cast: CastStoryContext(config: config, profile: nil, picks: ["8:k1": 0]))
        XCTAssertEqual(stayed.map(\.content), [.text("雾从海上来。"),
            .line(.init(speaker: .player, text: "留下来陪你的灯", rememberedBy: ["c_a"])), .text("灯还亮着。")])
        let left = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:],
            cast: CastStoryContext(config: config, profile: nil, picks: ["8:k1": 1]))
        XCTAssertEqual(left.last?.content, .line(.init(speaker: .player, text: "转身离开")))
        XCTAssertEqual(ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(), variables: [:]).count, 2)
    }
    func testLocalTrustAppliesKnownCastOnly() throws {
        let config = try XCTUnwrap(CastConfig(raw: wire(Self.config)))
        let deltas = CastTrustDelta.read(try wire(#"[{"castId":"c_a","delta":2},{"castId":"c_x","delta":1}]"#))
        let next = CastTrust().applying(deltas, config: config)
        XCTAssertEqual(next.values, ["c_a": 2])
        XCTAssertEqual(next.applying(deltas, config: config, sign: -1)["c_a"], 0)
    }
    func testStoryBranchWriteIsGatedAndAdoptsTheOriginalPick() async throws {
        let transport = CastTestTransport()
        do { _ = try await service(transport, enabled: []).recordCastBranch(runID: 50, chapterID: 8, blockKey: "k1", optionIndex: 1, token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        let recorded = try await service(transport, enabled: [.castBranch]).recordCastBranch(runID: 50, chapterID: 8, blockKey: "k1", optionIndex: 1, token: "synthetic-token")
        XCTAssertEqual(recorded, 0)
        let last = await transport.requests.last
        let sent = try XCTUnwrap(last)
        XCTAssertEqual(sent.url?.path, "/api/play/run/branch")
        XCTAssertEqual(String(decoding: try XCTUnwrap(sent.httpBody), as: UTF8.self), #"{"blockKey":"k1","chapterId":8,"optionIndex":1,"runId":50}"#)
        let voice = try await service(transport, enabled: [.castVoice]).castVoice(topicID: 9, chapterID: 8, blockKey: "b1", runID: 50, token: "synthetic-token")
        XCTAssertNotNil(voice)
        let lastQuery = await transport.requests.last?.url?.query
        XCTAssertEqual(lastQuery, "blockKey=b1&chapterId=8&runId=50&topicId=9")
    }
    @MainActor func testCoordinatorPicksLocallyWhenWriteIsOff() async throws {
        let transport = CastTestTransport()
        let session = try PlayExperienceSession(accountID: 9, epoch: 1, namespace: "synthetic-cn", token: "synthetic-token")
        let model = CastCoordinator(service: try service(transport, enabled: []), currentSession: { session })
        model.adopt(raw: try wire(CastTestTransport.nodes), topicID: 9, runID: 50)
        let raw = try wire(#"{"key":"k1","options":[{"text":"留下","trust":[{"castId":"c_a","delta":1}]},{"text":"离开"}]}"#)
        let choice = try XCTUnwrap(ChapterStoryChoice(raw: raw, chapterID: 8, fill: { $0 }))
        await model.pick(choice, optionIndex: 0)
        await model.pick(choice, optionIndex: 1)
        XCTAssertEqual(model.storyPicks, ["8:k1": 0]); XCTAssertEqual(model.trust["c_a"], 1)
        let posts = await transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertTrue(posts.isEmpty)
        model.invalidate()
        XCTAssertTrue(model.storyPicks.isEmpty); XCTAssertTrue(model.trust.isEmpty)
    }

    private func service(_ transport: any HTTPTransport, enabled: Set<CastCapability>) throws -> CastService {
        .init(configuration: try APIConfiguration(baseURL: URL(string: "https://cast.test")!), transport: transport, enabled: enabled)
    }
    private func wire(_ source: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(source.utf8)) }
    private func snapshot() throws -> PlaySnapshot {
        let data = #"{"topicId":9,"mode":1,"playable":true,"registered":true,"nodes":[],"chapters":[{"chapterId":8,"name":"Chapter"}]}"#
        return try PlaySnapshot(scope: .topic(9), result: wire(data).decoded())
    }
}
private actor CastTestTransport: HTTPTransport {
    static let nodes = #"{"topicId":9,"mode":1,"registered":true,"playable":true,"total":1,"doneCount":0,"nodes":[{"nodeId":1,"chapterId":8,"done":false,"validationMethod":1}],"chapters":[{"chapterId":8,"name":"Synthetic chapter"}],"castConfig":\#(CastContractsTests.config)}"#
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        switch request.url?.path {
        case "/api/play/run/profile": return (Data(#"{"code":200,"data":null}"#.utf8), 200)
        case "/api/play/run/branch": return (Data(#"{"code":200,"data":{"chapterId":8,"blockKey":"k1","optionIndex":0,"to":"continue","duplicate":true}}"#.utf8), 200)
        case "/api/topic/cast/voice":
            let ok = request.url?.query?.contains("blockKey=b1") == true
            return (Data((ok ? #"{"code":200,"data":{"url":"https://voice.test/b1.mp3"}}"# : #"{"code":200,"data":{"url":""}}"#).utf8), 200)
        default:
            return (Data(("{\"code\":200,\"data\":" + Self.nodes + "}").utf8), 200)
        }
    }
}
