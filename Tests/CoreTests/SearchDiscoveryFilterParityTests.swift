import XCTest
import QuestifyCore

final class SearchDiscoveryFilterParityTests: XCTestCase {
    func testListSortIsRecentOnlyAndDoesNotSendActivitySortType() {
        XCTAssertEqual(SearchDiscoveryFilterParity.listSorts, [.recent])
        XCTAssertEqual(SearchListSort.recent.zh, "最近")
        XCTAssertEqual(SearchListSort.recent.en, "Recent")
        XCTAssertFalse(SearchDiscoveryFilterParity.listSorts.map(\.zh).contains("最热"))
        XCTAssertFalse(SearchDiscoveryFilterParity.listSendsActivitySortType(.recent))
    }

    func testMapSortStillHasNearestAndPopular() {
        XCTAssertEqual(SearchDiscoveryFilterParity.mapSorts, [.nearest, .popular])
        XCTAssertEqual(SearchMapSortChoice.nearest.rawValue, 1)
        XCTAssertEqual(SearchMapSortChoice.popular.rawValue, 2)
        XCTAssertEqual(SearchMapSortChoice.popular.zh, "最热")
        XCTAssertEqual(SearchMapSortChoice.popular.en, "Popular")
    }

    func testDiscoveryHasNoSortAndHidesEmptyCompetitionTag() throws {
        XCTAssertTrue(SearchDiscoveryFilterParity.discoverySorts.isEmpty)
        let rows = try [
            topic(id: 1, name: "风味巡游", seconds: 0),
            topic(id: 2, name: "野生邻居观察局", seconds: 100)
        ]
        let tags = SearchDiscoveryFilterParity.topicTags(in: rows, selected: "versus")
        XCTAssertNil(tags.selection)
        XCTAssertFalse(tags.row.map(\.key).contains("versus"))
        XCTAssertFalse(tags.groups.flatMap(\.tags).map(\.key).contains("versus"))
        XCTAssertEqual(SearchDiscoveryFilterParity.visibleTopics(rows).map(\.name), ["风味巡游"])
        XCTAssertEqual(try topic(id: 3, name: "风味巡游", seconds: 0).totalTime, 0)
    }

    func testTopicTagsUseThemeKeyDurationAndPrefix() throws {
        let rows = try [
            topic(id: 1, name: "高温末日逃生", seconds: 0),
            topic(id: 2, name: "城市藏宝猎人", seconds: 3600),
            topic(id: 3, name: "预制人生 · 四站试玩版", seconds: 7200),
            topic(id: 4, name: "生活不掉线", seconds: 8000)
        ]
        let explore = SearchDiscoveryFilterParity.topics(rows, matching: "explore").map(\.name)
        XCTAssertEqual(explore, ["预制人生 · 四站试玩版"])
        XCTAssertEqual(SearchDiscoveryFilterParity.topics(rows, matching: "t1h").map(\.id), [2])
        XCTAssertEqual(SearchDiscoveryFilterParity.topics(rows, matching: "t2h").map(\.id), [3])
        XCTAssertEqual(SearchDiscoveryFilterParity.topics(rows, matching: "halfday").map(\.id), [4])
        XCTAssertFalse(SearchDiscoveryFilterParity.topics(rows, matching: "t1h").map(\.id).contains(1))
        let calm = SearchDiscoveryFilterParity.topicTags(in: rows, selected: "calm")
        XCTAssertEqual(calm.selection, "calm")
        XCTAssertEqual(calm.row.first?.key, "calm")
        XCTAssertEqual(calm.row.first?.zh, "治愈放松")
        XCTAssertEqual(calm.row.first?.en, "Calm")
        XCTAssertEqual(SearchDiscoveryFilterParity.themeKey("预制人生 · 四站试玩版"), "预制人生")
    }

    func testShelfGamesKeepHighestIDAndDropOtherPacks() throws {
        let rows = try [
            game(id: 3, title: "今晚的暗号", duration: 0, players: "单人"),
            game(id: 9, title: "今晚的暗号", duration: 5, players: "2-4 人"),
            game(id: 4, title: "今晚的暗号", packType: 1, duration: 5),
            game(id: 5, title: "G1｜今晚的暗号", duration: 5),
            game(id: 6, title: "未上架", duration: 5)
        ]
        let shelf = SearchDiscoveryFilterParity.shelfGames(rows)
        XCTAssertEqual(shelf.map(\.id), [9])
        XCTAssertEqual(shelf.first?.duration, 5)
        let zero = try game(id: 8, title: "沉默点单", duration: 0, players: "")
        XCTAssertEqual(zero.duration, 0)
        XCTAssertFalse(SearchDiscoveryFilterParity.gameMatches(zero, key: "quick"))
        XCTAssertTrue(SearchDiscoveryFilterParity.gameMatches(shelf[0], key: "quick"))
        XCTAssertTrue(SearchDiscoveryFilterParity.gameMatches(shelf[0], key: "p2"))
        XCTAssertTrue(SearchDiscoveryFilterParity.gameMatches(try game(id: 7, title: "沉默点单", players: "单人"), key: "p1"))
        let tags = SearchDiscoveryFilterParity.gameTags(in: rows, selected: nil)
        XCTAssertFalse(tags.row.map(\.zh).contains("最热"))
        XCTAssertTrue(tags.row.map(\.key).contains("promo"))
    }

    private func topic(id: Int, name: String, seconds: Int) throws -> DiscoveryTopicTemplate {
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "name": name, "totalTime": seconds])
        return try JSONDecoder().decode(DiscoveryTopicTemplate.self, from: data)
    }

    private func game(id: Int, title: String, packType: Int? = nil, duration: Int? = nil, players: String? = nil) throws -> DiscoveryPlayTemplate {
        var object: [String: Any] = ["id": id, "title": title]
        if let packType { object["packType"] = packType }
        if let duration { object["duration"] = duration }
        if let players { object["players"] = players }
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(DiscoveryPlayTemplate.self, from: data)
    }
}
