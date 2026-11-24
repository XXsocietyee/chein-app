#if DEBUG
import SwiftUI

@MainActor final class TopicFixtureReader: TopicReading {
    enum Scenario: String { case content, empty, failure, unauthorized, unconfigured, unavailable, closed, itinerary, reviews, reviewsEmpty, reviewsUnknown
        /// Port P3 acceptance screens: chapter cards, 出发前, story-only 活动内容 and 0/empty hiding.
        case routeDetail, routeDetailSparse }
    let scenario: Scenario
    let scope = UUID()
    var isConfigured: Bool { scenario != .unconfigured }
    var isOfflineExample: Bool { true }
    init(scenario: Scenario = .content) { self.scenario = scenario }
    private func check() throws {
        switch scenario {
        case .failure: throw APIError.httpStatus(503)
        case .unauthorized: throw APIError.unauthorized
        case .unconfigured: throw APIError.notConfigured
        default: break
        }
    }
    func topicList(query: TopicQuery, pageNumber: Int) async throws -> TopicPage {
        try check()
        let rows: [TopicSummary]
        if scenario == .empty || pageNumber > 2 { rows = [] }
        else {
            let ids = pageNumber == 1 ? Array(7..<(7 + query.pageSize)) : [7 + query.pageSize]
            rows = try ids.map { id in
                try JSONDecoder().decode(TopicSummary.self, from: Data("{\"id\":\(id),\"name\":\"Sample route \(id)\",\"description\":\"Offline synthetic route\"}".utf8))
            }.filter { query.keyword == nil || $0.name.localizedCaseInsensitiveContains(query.keyword!) }
        }
        return TopicPage(rows: rows, pageNumber: pageNumber, pageSize: query.pageSize)
    }
    func topicDetail(id: Int) async throws -> TopicDetail {
        try check()
        if scenario == .unavailable { throw TopicReadFailure.unavailable }
        if [.reviews, .reviewsEmpty, .reviewsUnknown].contains(scenario) {
            let fields: String
            switch scenario {
            case .reviews where id == 7:
                fields = #", "averageRating":4.2,"commentCount":12,"commentList":[{"memberNickname":"Example walker","createTime":"2030-01-02 10:00","rating":4,"contents":"A useful route review."},{"rating":0}]"#
            case .reviews:
                fields = #", "averageRating":3,"commentCount":3,"commentList":[{"memberNickname":"Another walker","rating":3,"contents":"A different route review."}]"#
            case .reviewsEmpty:
                fields = #", "averageRating":0,"commentCount":0,"commentList":[]"#
            default:
                fields = #", "averageRating":null,"commentCount":null,"commentList":null"#
            }
            let json = "{\"id\":\(id),\"name\":\"Synthetic review route\"\(fields)}"
            return try JSONDecoder().decode(TopicDetail.self, from: Data(json.utf8))
        }
        if scenario == .routeDetail || scenario == .routeDetailSparse {
            return try JSONDecoder().decode(TopicDetail.self, from: Data(TopicP3Fixtures.json(sparse: scenario == .routeDetailSparse).utf8))
        }
        if scenario == .itinerary {
            // Fictional geometry only; no device location or routed directions.
            let json = #"""
            {"id":7,"name":"Synthetic itinerary","storyLocked":true,"totalChapterCount":4,"chaptersList":[
              {"id":11,"title":"Adjacent stops","nodes":[
                {"id":21,"name":"First example stop","latitude":1,"longitude":1},
                {"id":22,"name":"Second example stop","latitude":"1.001","longitude":"1","nodeTime":240},
                {"id":23,"name":"Unknown location stop"},
                {"id":24,"name":"Last example stop","latitude":1.003,"longitude":1}]},
              {"id":12,"title":"Separate chapter","nodes":[
                {"id":25,"name":"New chapter first stop","latitude":1.005,"longitude":1}]},
              {"id":13,"title":"Empty chapter","nodes":[]} ]}
            """#
            return try JSONDecoder().decode(TopicDetail.self, from: Data(json.utf8))
        }
        let json = TopicSyntheticFixtures.detailJSON
            .replacingOccurrences(of: "\"id\":7,", with: "\"id\":\(id),")
            .replacingOccurrences(of: "\"merchantClosed\":false", with: "\"merchantClosed\":\(scenario == .closed ? "true" : "false")")
        return try JSONDecoder().decode(TopicDetail.self, from: Data(json.utf8))
    }
}

/// Synthetic route-detail data for port P3 (no backend records, coordinates or remote assets). `totalTime` is seconds.
enum TopicP3Fixtures {
    static func json(sparse: Bool) -> String {
        if sparse {
            // Free exploration with nothing known: no 出发前, no zero rows, no 0 review total, no chapter cards.
            return #"{"id":7,"name":"Synthetic open walk","productType":2,"locationCount":0,"templateCount":0,"registrationMerchantCount":0,"totalTime":0,"finishMedalName":"  ","averageRating":0,"commentCount":0,"commentList":[],"chaptersList":[{"id":11,"title":"Open walk","totalTime":0,"templateCount":0,"nodes":[]}]}"#
        }
        return #"""
        {"id":7,"name":"Synthetic lost-cat street","subtitle":"Follow the cat through the old lanes","productType":1,"locationCount":6,"templateCount":5,"totalChapterCount":4,
         "registrationMerchantCount":0,"totalTime":0,"selfPlay":1,"selfPlayPrice":30,"finishMedalName":"Lost-cat finder","completeRewardCouponId":12,
         "description":"Tonight the cat did not come home. You follow its trail along the old street.\n过马路请注意红绿灯。\n\n【注意事项】\n1. 部分店铺18点打烊；\n2. 带好充电宝",
         "activityList":[{"id":1,"name":"Saturday session","startDate":"2030-01-05"}],
         "omsTicketList":[{"id":51,"name":"Pair ticket","price":59,"teamSize":2},{"id":52,"name":"Pair ticket","price":49,"teamSize":2},{"id":53,"name":"Single ticket","price":29}],
         "averageRating":4.5,"commentCount":2,"commentList":[{"memberNickname":"Example walker","createTime":"2030-01-02 10:00","rating":5,"contents":"Lovely evening walk."}],
         "chaptersList":[
          {"id":13,"sortId":3,"title":"The harbour","description":"The trail ends where the boats sleep.","templateCount":1,"totalTime":20,"nodes":[{"id":23,"name":"Harbour steps"}]},
          {"id":11,"sortId":1,"title":"The old lane","description":"A bowl of milk, still warm, by a shuttered door.","templateCount":3,"totalTime":1800,"nodes":[{"id":21,"name":"Shuttered door"},{"id":22,"name":"Tea house"}]},
          {"id":12,"sortId":2,"title":"Rooftops","templateCount":1,"totalTime":0,"nodes":[{"id":24,"name":"Fire escape","cmsMemberTemplate":{"id":31,"title":"Count the chimneys","duration":15}}]},
          {"id":14,"sortId":4,"title":"结局 · 黎明","templateCount":0,"totalTime":0,"nodes":[]}
         ]}
        """#
    }
}

@MainActor struct TopicFixtureHostView: View {
    @State private var reader: TopicFixtureReader
    init() {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-topic-scenario")
        let raw = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        _reader = State(initialValue: TopicFixtureReader(scenario: raw.flatMap(TopicFixtureReader.Scenario.init(rawValue:)) ?? .content))
    }
    var body: some View {
        if [.unavailable, .itinerary, .routeDetail, .routeDetailSparse].contains(reader.scenario) {
            NavigationStack { TopicDetailView(id: 7, reader: reader) }
        } else { TopicBrowserView(reader: reader, pageSize: 2) }
    }
}
#endif
