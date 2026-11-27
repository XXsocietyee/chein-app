#if DEBUG
import SwiftUI

/// Explicit, opt-in simulator/UI-test data. No account, service, URL or credential is created.
enum ActivityFixtureScenario: String {
    case tickets
    case people
    case reviews
    case reviewsEmpty = "reviews-empty"
    case reviewsUnknown = "reviews-unknown"
    case clubGate = "club-gate"
    case retry
    case pagination
    /// Source detail meta rows: category names, meeting point and registration count.
    case meta

    static func selected(arguments: [String]) -> Self? {
        guard let flag=arguments.firstIndex(of:"--uitesting-activity-fixture"),
              arguments.indices.contains(flag+1) else { return nil }
        return Self(rawValue:arguments[flag+1])
    }
}

@MainActor
struct ActivityFixtureRootView: View {
    @State private var reader: ActivityFixtureReader
    @State private var profile = ActivityPeopleFixtureProfileReader()
    @State private var revision = 0
    private let scenario: ActivityFixtureScenario
    private let square = SquareFixtureReader()

    init(scenario: ActivityFixtureScenario) {
        self.scenario = scenario
        _reader=State(initialValue:ActivityFixtureReader(scenario:scenario))
    }

    var body: some View {
        VStack(spacing:0) {
            Text("activity.fixtureNotice")
                .cyText(.meta, weight: .bold)
                .padding(8)
                .frame(maxWidth:.infinity)
                .background(.yellow.opacity(0.2))
                .accessibilityIdentifier("activity.fixture.notice")
            if scenario == .people {
                Button("Switch fixture account") { profile.switchAccount(); revision += 1 }
                    .accessibilityIdentifier("activity.people.switchAccount")
            }
            ActivityBrowserView(reader:reader, peopleProfile: scenario == .people ? .init(reader: profile, squareReader: square) : nil)
                .id(revision)
        }
    }
}

@MainActor
final class ActivityFixtureReader: ActivityReading {
    let isConfigured=true
    private let scenario: ActivityFixtureScenario
    private var didFailList=false
    private var didFailDetail=false

    init(scenario: ActivityFixtureScenario) { self.scenario=scenario }

    func activities(page: Int, keyword: String) async throws -> [ActivitySummary] {
        try Task.checkCancellation()
        guard page > 0 else { throw APIError.invalidRequest }
        if scenario == .retry, !didFailList {
            didFailList=true
            throw APIError.httpStatus(503)
        }
        // Any submitted search intentionally has no matches in these small fixtures.
        guard keyword.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return [] }
        if scenario == .pagination {
            let ids: [Int]
            switch page {
            case 1: ids=Array(601...610)
            case 2: ids=[611]
            default: ids=[]
            }
            return try ids.map { try summary(id:$0,name:"Fixture activity \($0)") }
        }
        guard page == 1 else { return [] }
        return [try summary(id:101,name:scenario == .clubGate ? "Fixture club activity" : "Fixture ticket activity")]
    }

    func activityDetail(id: Int) async throws -> ActivityDetailAccess {
        try Task.checkCancellation()
        guard id == 101 || (scenario == .pagination && (601...611).contains(id)) else {
            throw APIError.invalidRequest
        }
        if scenario == .clubGate { return .clubRequired(clubID:201,message:nil) }
        if scenario == .retry, !didFailDetail {
            didFailDetail=true
            throw APIError.httpStatus(503)
        }
        if scenario == .people {
            let data = Data(#"{"id":101,"name":"Fixture people activity","memberId":99,"collaboratorsList":[{"id":901,"memberId":82,"memberRealName":"Fixture host"}],"registrationList":[{"id":902,"memberId":83,"nickname":"Fixture participant"},{"id":903,"nickname":"Fixture unnamed link"},{"id":904,"memberId":0,"nickname":"Fixture invalid link"}],"registrationCount":12}"#.utf8)
            return .allowed(try JSONDecoder().decode(ActivityDetail.self, from: data))
        }
        if scenario == .meta {
            let data = Data(#"{"id":101,"name":"Fixture meta activity","addressName":"Fixture meeting point","sysCategoryList":[{"categoryName":"Fixture walk"},{"categoryName":" "},{"categoryName":"Fixture puzzle"}],"registrationCount":7}"#.utf8)
            return .allowed(try JSONDecoder().decode(ActivityDetail.self, from: data))
        }
        if [.reviews, .reviewsEmpty, .reviewsUnknown].contains(scenario) {
            let fields: String
            switch scenario {
            case .reviews:
                fields = #","averageRating":4.2,"commentCount":12,"commentList":[{"memberNickname":"Fixture reviewer","createTime":"2030-01-02","rating":4,"contents":"Fixture review text"},{"rating":null,"contents":"Fixture unrated review"}]"#
            case .reviewsEmpty:
                fields = #","averageRating":0,"commentCount":0"#
            default:
                fields = ""
            }
            // mp-home r3 (19:50 sweep): fixture data follows the UI language.
            let zh = Locale.preferredLanguages.first?.hasPrefix("zh") == true
            let place = zh ? "灯笼广场（示例）" : "Lantern Square (fixture)"
            let about = zh ? "沿着老集市小巷慢慢走，一路听故事。离线示例文案。" : "A slow, story-led walk through the old market lanes. Offline fixture copy."
            let walk = zh ? "漫步" : "Walk", food = zh ? "美食" : "Food"
            let standard = zh ? "标准票" : "Standard ticket", early = zh ? "早鸟票" : "Early bird"
            let includes = zh ? "含向导、路线手册和一次试吃。" : "Guide, route booklet and one tasting."
            let title = zh ? "灯笼集市探索（示例）" : "Lantern Market Quest (fixture)"
            let base = "\"startDate\":\"2026-11-21 14:00:00\",\"endDate\":\"2026-11-21 17:30:00\",\"addressName\":\"\(place)\",\"description\":\"\(about)\",\"minAmout\":58,\"registrationCount\":24,\"sysCategoryList\":[{\"categoryName\":\"\(walk)\"},{\"categoryName\":\"\(food)\"}],\"omsTicketList\":[{\"id\":501,\"name\":\"\(standard)\",\"price\":58,\"remainingInventory\":18,\"description\":\"\(includes)\"},{\"id\":502,\"name\":\"\(early)\",\"price\":42,\"remainingInventory\":0}]"
            let data = Data("{\"id\":101,\"name\":\"\(title)\",\(base)\(fields)}".utf8)
            return .allowed(try JSONDecoder().decode(ActivityDetail.self, from: data))
        }
        // Intentionally omit image URLs and coordinates: no Map or remote media is instantiated.
        let data=Data("""
        {
          "id": \(id), "name": "Fixture ticket activity", "minAmout": null,
          "omsTicketList": [
            {"id": 501, "name": "Fixture unknown ticket", "price": null, "remainingInventory": null},
            {"id": 502, "name": "Fixture sold-out ticket", "price": 12.5, "remainingInventory": 0}
          ]
        }
        """.utf8)
        return .allowed(try JSONDecoder().decode(ActivityDetail.self,from:data))
    }

    private func summary(id: Int, name: String) throws -> ActivitySummary {
        var object: [String: Any] = ["id":id,"name":name]
        if scenario == .pagination {
            // Labelled synthetic metadata so the list is judged with date, place, status and price.
            let titles = ["Old Town Night Walk", "Riverside Sunrise Run", "Lantern Market Quest", "Hutong Photo Trail", "Jazz in the Courtyard", "Temple Hill Hike", "Street Food Crawl"]
            let places = ["Gulou East Lane", "Riverside Park Gate 2", "Lantern Square", "Nanluoguxiang", "Courtyard No. 9", "Temple Hill Trailhead", "Dumpling Street"]
            let slot = id % 7
            object["name"] = titles[slot] + " (fixture \(id))"
            object["addressName"] = places[slot]
            let day = [3, 14, 21, 28, 6, 12, 25][slot]
            let month = slot % 3 == 0 ? 10 : 11
            object["startDate"] = String(format: "2026-%02d-%02d 18:30:00", month, day)
            object["endDate"] = String(format: "2026-%02d-%02d 21:00:00", month, day)
            if slot % 3 != 2 { object["minAmout"] = slot % 3 == 1 ? 0 : Double(40 + slot * 12) }
        }
        let data=try JSONSerialization.data(withJSONObject:object)
        return try JSONDecoder().decode(ActivitySummary.self,from:data)
    }
}

@MainActor private final class ActivityPeopleFixtureProfileReader: SocialAccountReading {
    private(set) var identity = SocialAccountIdentity(accountID: 81, epoch: 1, role: "player")
    let isConfigured = true
    let isOfflineExample = true
    func switchAccount() { identity = .init(accountID: 84, epoch: identity.epoch + 1, role: "player") }
    func publicProfile(memberID: Int) async throws -> SocialPublicProfile {
        try Task.checkCancellation()
        let name: String
        switch memberID {
        case 82: name = "Fixture host profile"
        case 83: name = "Fixture participant profile"
        default: throw APIError.invalidRequest
        }
        let data = try JSONSerialization.data(withJSONObject: ["id": memberID, "nickname": name])
        return try JSONDecoder().decode(SocialPublicProfile.self, from: data)
    }
    func informationList() async throws -> [SocialInformation] { throw APIError.invalidRequest }
    func information(id: Int) async throws -> SocialInformation { throw APIError.invalidRequest }
    func invitationHistory(page: Int) async throws -> SocialInviteHistory { throw APIError.invalidRequest }
}
#endif
