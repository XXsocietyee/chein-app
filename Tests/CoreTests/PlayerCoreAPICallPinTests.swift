import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Synthetic fixtures for player mini-program calls. No live backend is contacted.
@MainActor final class PlayerCoreAPICallPinTests: XCTestCase {
    private func config(_ raw: String = "https://example.com/test/") throws -> APIConfiguration {
        try APIConfiguration(baseURL: try XCTUnwrap(URL(string: raw)))
    }

    private func multipart(_ request: URLRequest) -> String {
        String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    }

    func testTopicListPostsSortAndDecodesNameImageSignupAndCategory() async throws {
        let json = #"{"code":200,"data":{"rows":[{"id":7,"name":"Nested","imgUrl":"https://example.com/a.png","signupCount":3,"sysCategoryList":[{"categoryName":"City"}]}]}}"#
        let transport = PinTransport(json)
        let page = try await TopicService(configuration: config(), transport: transport).list(
            query: TopicQuery(keyword: "river", categoryID: "2", recommend: true, pageSize: 20, sortType: "1"),
            pageNumber: 3, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/topic/list") == true)
        let body = multipart(request)
        for (key, value) in ["is_my": "0", "pageNum": "3", "pageSize": "20", "keyword": "river", "category_id": "2", "is_recommend": "1", "sort_type": "1"] {
            XCTAssertTrue(body.contains("name=\"\(key)\"\r\n\r\n\(value)\r\n"), key)
        }
        let row = try XCTUnwrap(page.rows.first)
        XCTAssertEqual(row.id, 7)
        XCTAssertEqual(row.name, "Nested")
        XCTAssertEqual(row.imageURL, "https://example.com/a.png")
        XCTAssertEqual(row.signupCount, 3)
        XCTAssertEqual(row.categoryNames, ["City"])
    }

    func testTopicDetailPostsIdAndDecodesNameImageAndIntroduction() async throws {
        let json = #"{"code":200,"data":{"id":7,"name":"Synthetic","imgUrl":"https://example.com/a.png","description":"A walk","subtitle":"Short"}}"#
        let transport = PinTransport(json)
        let detail = try await TopicService(configuration: config(), transport: transport).detail(id: 7, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/topic/info-to-user") == true)
        XCTAssertTrue(multipart(request).contains("name=\"id\"\r\n\r\n7\r\n"))
        XCTAssertEqual(detail.id, 7)
        XCTAssertEqual(detail.name, "Synthetic")
        XCTAssertEqual(detail.imageURL, "https://example.com/a.png")
        XCTAssertEqual(detail.introduction, "A walk")
        XCTAssertEqual(detail.subtitle, "Short")
    }

    func testHomeActivityListPostsOpenSortAndDecodesNameImageAmountAndDistance() async throws {
        let json = #"{"code":200,"data":{"rows":[{"id":7,"name":"River","imgUrl":"https://example.com/a.png","minAmout":12,"distance":120,"addressName":"North"}]}}"#
        let transport = PinTransport(json)
        let page = try await HomeFeedService(configuration: config(), transport: transport).page(
            query: HomeFeedQuery(kind: .activities, keyword: "river", categoryID: 2, pageSize: 20), number: 3, token: nil)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/activity/list") == true)
        let body = multipart(request)
        for (key, value) in ["is_my": "0", "status": "1", "sort_type": "1", "keyword": "river", "category_id": "2", "pageNum": "3", "pageSize": "20"] {
            XCTAssertTrue(body.contains("name=\"\(key)\"\r\n\r\n\(value)\r\n"), key)
        }
        guard case .activity(let row)? = page.items.first else { return XCTFail("activity row") }
        XCTAssertEqual(row.name, "River")
        XCTAssertEqual(row.imageURL, "https://example.com/a.png")
        XCTAssertEqual(row.minimumAmount, Decimal(12))
        XCTAssertEqual(row.distanceMeters, 120.0)
        XCTAssertEqual(row.addressName, "North")
    }

    func testHomeNearbyPostsTimeSortAndDecodesDistance() async throws {
        let json = #"{"code":200,"data":{"rows":[{"id":4,"name":"Near","distance":80}]}}"#
        let transport = PinTransport(json)
        let items = try await HomeFeedService(configuration: config(), transport: transport).section(.nearby, token: nil)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/activity/list") == true)
        let body = multipart(request)
        for (key, value) in ["is_my": "0", "sort_type": "2", "pageNum": "1", "pageSize": "4"] {
            XCTAssertTrue(body.contains("name=\"\(key)\"\r\n\r\n\(value)\r\n"), key)
        }
        XCTAssertFalse(body.contains("name=\"status\""))
        guard case .activity(let row)? = items.first else { return XCTFail("nearby") }
        XCTAssertEqual(row.name, "Near")
        XCTAssertEqual(row.distanceMeters, 80.0)
    }

    func testHomeUpcomingPostsPreviewFiltersAndDecodesName() async throws {
        let json = #"{"code":200,"data":{"rows":[{"id":5,"name":"Soon","statusLabel":"即将上线"}]}}"#
        let transport = PinTransport(json)
        let items = try await HomeFeedService(configuration: config(), transport: transport).section(.upcoming, token: nil)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/activity/list") == true)
        let body = multipart(request)
        for (key, value) in ["is_my": "2", "status": "2", "sort_type": "2", "pageNum": "1", "pageSize": "4"] {
            XCTAssertTrue(body.contains("name=\"\(key)\"\r\n\r\n\(value)\r\n"), key)
        }
        guard case .activity(let row)? = items.first else { return XCTFail("upcoming") }
        XCTAssertEqual(row.name, "Soon")
        XCTAssertEqual(row.statusLabel, "即将上线")
    }

    func testHomeRecommendedPostsRecommendFlagAndDecodesSignupCount() async throws {
        let json = #"{"code":200,"data":{"rows":[{"id":7,"name":"Pick","imgUrl":"https://example.com/a.png","signupCount":3}]}}"#
        let transport = PinTransport(json)
        let items = try await HomeFeedService(configuration: config(), transport: transport).section(.recommended, token: nil)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/topic/list") == true)
        let body = multipart(request)
        for (key, value) in ["is_my": "0", "is_recommend": "1", "pageNum": "1", "pageSize": "5"] {
            XCTAssertTrue(body.contains("name=\"\(key)\"\r\n\r\n\(value)\r\n"), key)
        }
        guard case .topic(let row)? = items.first else { return XCTFail("recommended") }
        XCTAssertEqual(row.name, "Pick")
        XCTAssertEqual(row.imageURL, "https://example.com/a.png")
        XCTAssertEqual(row.signupCount, 3)
    }

    func testDiscoveryBannersPostShowAndLinkAndDecodeDestination() async throws {
        let json = #"{"code":200,"data":[{"id":1,"picUrl":"https://example.com/b.png","linkType":4,"dataId":"9","contents":"hello"}]}"#
        let transport = PinTransport(json)
        let banners = try await DiscoveryService(configuration: config(), transport: transport).banners(token: nil)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/common/banner") == true)
        let body = multipart(request)
        XCTAssertTrue(body.contains("name=\"showType\"\r\n\r\n1\r\n"))
        XCTAssertTrue(body.contains("name=\"linkType\"\r\n\r\n0\r\n"))
        let banner = try XCTUnwrap(banners.first)
        XCTAssertEqual(banner.id, 1)
        XCTAssertEqual(banner.picUrl, "https://example.com/b.png")
        XCTAssertEqual(banner.linkType, 4)
        XCTAssertEqual(banner.dataId, "9")
        XCTAssertEqual(banner.contents, "hello")
        XCTAssertEqual(banner.destination, .topic(9))
    }

    func testDiscoveryCategoriesPostParentAndTypeAndDecodeName() async throws {
        let json = #"{"code":200,"data":[{"id":2,"categoryName":"City","type":4,"icon":"https://example.com/i.png"}]}"#
        let transport = PinTransport(json)
        let rows = try await DiscoveryService(configuration: config(), transport: transport).categories(type: 4, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/category/list") == true)
        let body = multipart(request)
        XCTAssertTrue(body.contains("name=\"parentid\"\r\n\r\n0\r\n"))
        XCTAssertTrue(body.contains("name=\"type\"\r\n\r\n4\r\n"))
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.id, 2)
        XCTAssertEqual(row.name, "City")
        XCTAssertEqual(row.type, 4)
        XCTAssertEqual(row.icon, "https://example.com/i.png")
    }

    func testGeocodePostsAddressAndRegionAndDecodesCoordinate() async throws {
        let transport = PinTransport(#"{"code":200,"data":{"lat":31.2,"lng":120.1}}"#)
        let client = PlayerCapabilityClient(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: "synthetic-token", transport: transport)
        let point = await MapSearchPlayerService(client: client).geocode(address: "North Road", region: "Hangzhou")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/map/geocode") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("address="))
        XCTAssertTrue(body.contains("region="))
        XCTAssertEqual(point?.latitude, 31.2)
        XCTAssertEqual(point?.longitude, 120.1)
    }

    func testPlaceSearchPostsKeywordAndCentreAndDecodesNameAddressAndCoordinate() async throws {
        let transport = PinTransport(#"{"code":200,"data":[{"name":"Gate","address":"North","lat":31.2,"lng":120.1}]}"#)
        let client = PlayerCapabilityClient(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: "synthetic-token", transport: transport)
        let rows = try await MapSearchPlayerService(client: client).placeSearch(keyword: "gate", latitude: 31.2, longitude: 120.1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/map/place-search") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("keyword="))
        XCTAssertTrue(body.contains("longitude="))
        XCTAssertTrue(body.contains("latitude="))
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.name, "Gate")
        XCTAssertEqual(row.address, "North")
        XCTAssertEqual(row.coordinate?.latitude, 31.2)
        XCTAssertEqual(row.coordinate?.longitude, 120.1)
    }

    func testWeatherGetsCellCentreAndDecodesKindAndIntensity() async throws {
        let transport = PinTransport(#"{"code":200,"data":{"kind":"rain","intensity":0.8}}"#)
        let client = PlayerCapabilityClient(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: "synthetic-token", transport: transport)
        let weather = await MapSearchPlayerService(client: client).weather(latitude: 31.2, longitude: 120.1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/map/weather") == true)
        let query = request.url?.query ?? ""
        XCTAssertTrue(query.contains("lat="))
        XCTAssertTrue(query.contains("lng="))
        XCTAssertEqual(weather?.kind, "rain")
        XCTAssertEqual(weather?.intensity, 0.8)
    }

    func testUnifiedSearchGetsKeywordTypesAndCityAndDecodesTitle() async throws {
        let json = #"{"code":200,"data":{"rows":[{"type":"topic","id":4,"name":"River","addressName":"Gate"}],"total":1}}"#
        let transport = PinTransport(json)
        let client = PlayerCapabilityClient(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: "synthetic-token", transport: transport)
        let page = try await MapSearchPlayerService(client: client).unifiedSearch(keyword: "river", types: ["topic", "activity"], cityCode: "330100", page: 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/search/unified") == true)
        let query = request.url?.query ?? ""
        for name in ["keyword", "types", "city_code", "pageNum", "pageSize"] {
            XCTAssertTrue(query.contains(name + "="), name)
        }
        XCTAssertTrue(query.contains("pageSize=12"))
        let item = try XCTUnwrap(page.items.first)
        XCTAssertEqual(item.type, "topic")
        XCTAssertEqual(item.itemID, 4)
        XCTAssertEqual(item.title, "River")
        XCTAssertEqual(page.total, 1)
    }

    func testClubHomePostsEmptyObjectAndDecodesOwnedNameAndEventTitle() async throws {
        let json = #"{"code":200,"data":{"owned":[{"id":3,"name":"North"}],"joined":[],"nearby":[],"events":[{"id":9,"title":"Night","clubId":3,"cover":"https://example.com/e.png"}]}}"#
        let transport = PinTransport(json)
        let home = try await ClubService(configuration: config(), transport: transport).home(token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/club/home") == true)
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "{}")
        XCTAssertEqual(home.owned.first?.name, "North")
        XCTAssertEqual(home.owned.first?.id, 3)
        XCTAssertEqual(home.events.first?.title, "Night")
        XCTAssertEqual(home.events.first?.clubId, 3)
        let event = try XCTUnwrap(home.events.first)
        XCTAssertEqual(event.cover, "https://example.com/e.png")
    }

    func testClubDetailPostsIdAndDecodesName() async throws {
        let transport = PinTransport(#"{"code":200,"data":{"id":3,"name":"North","logo":"https://example.com/l.png"}}"#)
        let club = try await ClubService(configuration: config(), transport: transport).detail(id: 3, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/club/detail") == true)
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "{\"id\":3}")
        XCTAssertEqual(club.id, 3)
        XCTAssertEqual(club.name, "North")
        XCTAssertEqual(club.logo, "https://example.com/l.png")
    }

    func testClubDirectoryPostsNameAndDecodesClubName() async throws {
        let transport = PinTransport(#"{"code":200,"data":[{"id":3,"name":"North"}]}"#)
        let rows = try await ClubService(configuration: config(), transport: transport).directory(name: "North", token: nil)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/club/list") == true)
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "{\"name\":\"North\"}")
        XCTAssertEqual(rows.first?.id, 3)
        XCTAssertEqual(rows.first?.name, "North")
    }

    func testClubMembersPostsClubIdAndDecodesNickname() async throws {
        let club = try JSONDecoder().decode(ClubRecord.self, from: Data(#"{"id":3,"name":"North","isJoined":true}"#.utf8))
        let transport = PinTransport(#"{"code":200,"data":[{"memberId":8,"nickname":"Ada","avatar":"https://example.com/a.png","role":1,"isOwner":false}]}"#)
        let rows = try await ClubService(configuration: config(), transport: transport).members(in: club, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/club/members") == true)
        XCTAssertTrue((String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "").contains("\"clubId\":3"))
        let member = try XCTUnwrap(rows.first)
        XCTAssertEqual(member.memberId, 8)
        XCTAssertEqual(member.nickname, "Ada")
        XCTAssertEqual(member.avatar, "https://example.com/a.png")
        XCTAssertEqual(member.role, 1)
    }

    func testGrowthCenterPostsEmptyObjectAndDecodesLevelPointsBadgeAndMission() async throws {
        let json = #"{"code":200,"data":{"growth":{"levelNo":2,"expValue":15},"points":3,"badges":[{"badgeName":"First","badgeCode":"first","iconUrl":"https://example.com/b.png","obtainTime":"2026-01-02 03:04:05"}],"missions":[{"missionName":"Walk","missionDesc":"Go","expReward":4}]}}"#
        let transport = PinTransport(json)
        let record = try await GrowthCenterService(configuration: config(), transport: transport).center(token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/growth/center") == true)
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "{}")
        XCTAssertEqual(record.level, 2)
        XCTAssertEqual(record.experience, 15)
        XCTAssertEqual(record.points, 3)
        let badge = try XCTUnwrap(record.badges.first)
        XCTAssertEqual(badge.name, "First")
        XCTAssertEqual(badge.code, "first")
        let mission = try XCTUnwrap(record.missions.first)
        XCTAssertEqual(mission.name, "Walk")
        XCTAssertEqual(mission.description, "Go")
        XCTAssertEqual(mission.experienceReward, 4)
    }

    func testGrowthProgressPostsEmptyObjectAndDecodesMileageWhenPresent() async throws {
        let json = #"{"code":200,"data":{"level":1,"totalCheckins":2,"totalMileage":3.5,"streakDays":4}}"#
        let transport = PinTransport(json)
        let progress = try await GrowthCenterService(configuration: config(), transport: transport).progress(token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/play/growth") == true)
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "{}")
        XCTAssertEqual(progress.level, 1)
        XCTAssertEqual(progress.totalCheckins, 2)
        XCTAssertEqual(progress.totalMileage, 3.5)
        XCTAssertEqual(progress.streakDays, 4)
    }

    func testGrowthCompletedPostsEmptyObjectAndDecodesTopicNameAndCover() async throws {
        let json = #"{"code":200,"data":[{"activityId":1,"topicId":2,"name":"Walk","cover":"https://example.com/c.png","total":3,"doneCount":1}]}"#
        let transport = PinTransport(json)
        let rows = try await GrowthCenterService(configuration: config(), transport: transport).completed(token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/play/my-completed") == true)
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "{}")
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.activityID, 1)
        XCTAssertEqual(row.topicID, 2)
        XCTAssertEqual(row.name, "Walk")
        XCTAssertEqual(row.cover, "https://example.com/c.png")
        XCTAssertEqual(row.total, 3)
        XCTAssertEqual(row.doneCount, 1)
    }

    func testGrowthLeaderboardPostsMetricPeriodLimitAndDecodesRank() async throws {
        let json = #"{"code":200,"data":{"metric":"point","period":"total","list":[{"rank":1,"memberId":4,"nickname":"Ada","score":9}],"me":{"rank":2,"memberId":8,"nickname":"Bea","score":1}}}"#
        let transport = PinTransport(json)
        let board = try await GrowthCenterService(configuration: config(), transport: transport).leaderboard(
            query: GrowthBoardQuery(metric: .point, period: .total), limit: 1, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/growth/leaderboard") == true)
        let body = multipart(request)
        for (key, value) in ["metric": "point", "period": "total", "limit": "1"] {
            XCTAssertTrue(body.contains("name=\"\(key)\"\r\n\r\n\(value)\r\n"), key)
        }
        XCTAssertEqual(board.metric, .point)
        XCTAssertEqual(board.period, .total)
        let leader = try XCTUnwrap(board.list.first)
        XCTAssertEqual(leader.nickname, "Ada")
        XCTAssertEqual(leader.rank, 1)
        XCTAssertEqual(leader.score, 9)
        XCTAssertEqual(board.me.nickname, "Bea")
        XCTAssertEqual(board.me.rank, 2)
        XCTAssertEqual(board.me.memberID, 8)
    }

    func testOfficialRouteListGetsNoQueryAndDecodesNameAndCity() async throws {
        let json = #"{"code":200,"data":[{"id":"12","name":"River","city":"HZ","previewImg":"https://example.com/r.png","totalDistance":1.5,"totalTime":40}]}"#
        let transport = PinTransport(json)
        let rows = try await RoamService(configuration: config(), transport: transport).officialRoutes(token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/preset/route/list") == true)
        XCTAssertNil(request.url?.query)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.id, "12")
        XCTAssertEqual(row.name, "River")
        XCTAssertEqual(row.city, "HZ")
        XCTAssertEqual(row.previewImage, "https://example.com/r.png")
    }

    func testOfficialRouteInfoGetsIdAndDecodesNodeName() async throws {
        let json = #"{"code":200,"data":{"id":"12","name":"River","nodes":[{"id":"1","name":"Gate","address":"North","imgUrl":"https://example.com/n.png","nodeTime":10,"latitude":1.25,"longitude":2.5}]}}"#
        let transport = PinTransport(json)
        let detail = try await RoamService(configuration: config(), transport: transport).officialRoute(id: "12", token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/preset/route/info") == true)
        XCTAssertTrue((request.url?.query ?? "").contains("id=12"))
        XCTAssertEqual(detail.route.name, "River")
        let node = try XCTUnwrap(detail.nodes.first)
        XCTAssertEqual(node.name, "Gate")
        XCTAssertEqual(node.address, "North")
        XCTAssertEqual(node.latitude, 1.25)
        XCTAssertEqual(node.longitude, 2.5)
    }

    func testExploreDayGetsLatLngAndDecodesActivityTitle() async throws {
        let json = #"{"code":200,"data":{"activityId":6,"title":"Day","subtitle":"Sub","meetingPoint":"Gate","distanceM":80}}"#
        let transport = PinTransport(json)
        let area = RoamSearchArea(coordinate: try XCTUnwrap(RoamCoordinate(latitude: 1.25, longitude: 2.5)), label: "Explicit synthetic test area")
        let day = try await RoamService(configuration: config(), transport: transport).exploreDay(area: area, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/roam/nearby-exploreday") == true)
        let query = request.url?.query ?? ""
        XCTAssertTrue(query.contains("lat="))
        XCTAssertTrue(query.contains("lng="))
        let shown = try XCTUnwrap(day)
        XCTAssertEqual(shown.id, 6)
        XCTAssertEqual(shown.title, "Day")
        XCTAssertEqual(shown.subtitle, "Sub")
        XCTAssertEqual(shown.meetingPoint, "Gate")
        XCTAssertEqual(shown.distanceM, 80)
    }

    func testRoamPlacesGetsLatLngRadiusAndDecodesNameAddress() async throws {
        let json = #"{"code":200,"data":[{"id":4,"name":"Gate","lat":1.25,"lng":2.5,"type":1,"address":"North"}]}"#
        let transport = PinTransport(json)
        let area = RoamSearchArea(coordinate: try XCTUnwrap(RoamCoordinate(latitude: 1.25, longitude: 2.5)), label: "Explicit synthetic test area")
        let rows = try await RoamService(configuration: config(), transport: transport).places(area: area, radiusM: 3000, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/roam/pois") == true)
        let query = request.url?.query ?? ""
        for name in ["lat", "lng", "radius"] { XCTAssertTrue(query.contains(name + "="), name) }
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.name, "Gate")
        XCTAssertEqual(row.address, "North")
        XCTAssertEqual(row.coordinate?.latitude, 1.25)
        XCTAssertEqual(row.coordinate?.longitude, 2.5)
        XCTAssertEqual(row.type, 1)
    }

    func testRouteNodesPostsCentreRadiusLimitAndDecodesAddressAndPhoto() async throws {
        let json = #"{"code":200,"data":[{"id":4,"addressName":"Gate","latitude":1.25,"longitude":2.5,"picUrl":"https://example.com/n.png","productType":1}]}"#
        let transport = PinTransport(json)
        let area = RoamSearchArea(coordinate: try XCTUnwrap(RoamCoordinate(latitude: 1.25, longitude: 2.5)), label: "Explicit synthetic test area")
        let rows = try await RoamService(configuration: config(), transport: transport).routeNodes(area: area, radiusM: 2000, limit: 50, token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/map/nearby") == true)
        let body = multipart(request)
        for name in ["latitude", "longitude", "radius", "limit"] {
            XCTAssertTrue(body.contains("name=\"\(name)\""), name)
        }
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.addressName, "Gate")
        XCTAssertEqual(row.coordinate?.latitude, 1.25)
        XCTAssertEqual(row.coordinate?.longitude, 2.5)
        XCTAssertEqual(row.picUrl, "https://example.com/n.png")
        XCTAssertEqual(row.productType, 1)
    }

    func testPlayThemeSupportMatrixGetsPathAndDecodesSchemaTypesAddonsConstraintsAndProofs() async throws {
        let wire = SupportMatrixWire()
        let context = RuntimeDependencyContext(market: .china, baseURL: try XCTUnwrap(URL(string: "https://author.test/")), role: "player",
            session: try .init(accountID: 7, epoch: 2, namespace: "author-fixture", token: "test-token", role: "player"))
        let session = try ProjectEditSession(accountID: 7, epoch: 2, storageNamespace: "author-fixture")
        let reader = try ProjectAuthorInputReader(context: context, session: session,
            routes: [try ProjectAuthorInputReadRoute.support.businessRoute], transport: wire, current: { true })
        let inputs = try await reader.runtimeStructureInputs(draft: ProjectEditDraft(), session: session)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/play/theme/support-matrix") == true)
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(inputs.matrix["schemaVersion"], .number(1))
        XCTAssertEqual(inputs.matrix["types"]?.array?.first?.object?["key"]?.text, "qaText")
        XCTAssertNotNil(inputs.matrix["types"]?.array?.first?.object?["tools"]?.object)
        XCTAssertEqual(inputs.matrix["addons"]?.array?.first?.object?["key"]?.text, "timer")
        XCTAssertNotNil(inputs.matrix["constraints"]?.object)
        XCTAssertNotNil(inputs.matrix["legacyProofs"]?.object)
    }

    func testImUnreadTotalPostsNoFieldsAndDecodesTotal() async throws {
        let transport = PinTransport(#"{"code":200,"data":4}"#)
        let total = try await IMUnreadTotalService(configuration: config(), transport: transport, enabledPaths: ["api/im/unread-total"]).total(token: "synthetic-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/im/unread-total") == true)
        XCTAssertFalse(multipart(request).contains("name=\""))
        XCTAssertEqual(total, 4)
    }

    func testOfficialSignupCancelPostsCommandAndDecodesCancelledState() async throws {
        let requestID = "0123456789abcdef0123456789abcdef"
        let json = #"{"code":200,"msg":"stopped","data":{"requestId":"0123456789abcdef0123456789abcdef","state":"CANCELLED","message":"stopped"}}"#
        let transport = PinTransport(json)
        let service = PlayerGapService(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: { "synthetic-token" }, transport: transport)
        let command = try XCTUnwrap(OfficialSignupCommand(eventID: 9, requestID: requestID, action: "signup"))
        let receipt = try XCTUnwrap(await service.signupCommand(.cancel, command: command))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/official/signup-command/cancel") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        for name in ["targetId", "action", "requestId"] { XCTAssertTrue(body.contains("\"\(name)\""), name) }
        XCTAssertEqual(receipt.state, .cancelled)
        XCTAssertEqual(receipt.message, "stopped")
    }

    func testOfficialSignupQueryPostsRequestIdAndDecodesAppliedState() async throws {
        let requestID = "0123456789abcdef0123456789abcdef"
        let json = #"{"code":200,"msg":"kept","data":{"requestId":"0123456789abcdef0123456789abcdef","state":"APPLIED","message":"kept"}}"#
        let transport = PinTransport(json)
        let service = PlayerGapService(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: { "synthetic-token" }, transport: transport)
        let command = try XCTUnwrap(OfficialSignupCommand(eventID: 9, requestID: requestID))
        let receipt = try XCTUnwrap(await service.signupCommand(.query, command: command))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/official/signup-command/query") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("\"requestId\""))
        XCTAssertFalse(body.contains("\"targetId\""))
        XCTAssertEqual(receipt.state, .applied)
        XCTAssertEqual(receipt.message, "kept")
    }

    func testOrientAbandonPostsSessionAndKeyAndDecodesAbandonedPhase() async throws {
        let transport = OrientTestTransport()
        transport.append(orientTestView(phase: "ABANDONED", status: 2))
        let pending = try orientTestPending(.abandon(sessionID: 9))
        guard case .session(let row) = try await orientTestService(transport).write(pending, token: "synthetic-token") else {
            return XCTFail("abandon")
        }
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/play/orient/session/abandon") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        for name in ["sessionId", "idempotencyKey"] { XCTAssertTrue(body.contains(name), name) }
        XCTAssertEqual(row.phase, .abandoned)
        XCTAssertEqual(row.sessionID, 9)
        XCTAssertEqual(row.status, 2)
        XCTAssertEqual(row.scope.topicID, 3)
    }

    func testTeamCommandQueryPostsSavedRequestIdAndDecodesApplied() async throws {
        let base = try XCTUnwrap(URL(string: "https://example.test/prod-api/"))
        let approval = try OperationEndpointApproval(baseURL: base, namespace: "team", accountID: 7, paths: TeamCommandWriter.paths)
        let transport = PinTransport(#"{"code":200,"data":{"requestId":"0123456789abcdef0123456789abcdef","state":"APPLIED","message":"kept"}}"#)
        let writer = try TeamCommandWriter(approval: approval, configuration: config("https://example.test/prod-api/"), transport: transport, token: { "synthetic-token" })
        let requestID = "0123456789abcdef0123456789abcdef"
        writer.adopt(key: "join-9", requestID: requestID)
        let terminal = await writer.query(key: "join-9")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/team/command/query") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("\"requestId\""))
        XCTAssertTrue(body.contains(requestID))
        XCTAssertEqual(terminal, .applied(200))
    }

    func testTeamCommandCancelPostsSavedCommandAndDecodesCancelled() async throws {
        let base = try XCTUnwrap(URL(string: "https://example.test/prod-api/"))
        let approval = try OperationEndpointApproval(baseURL: base, namespace: "team", accountID: 7, paths: TeamCommandWriter.paths)
        let transport = PinTransport(#"{"code":200,"data":{"requestId":"0123456789abcdef0123456789abcdef","state":"CANCELLED","message":"stopped"}}"#)
        let writer = try TeamCommandWriter(approval: approval, configuration: config("https://example.test/prod-api/"), transport: transport, token: { "synthetic-token" })
        writer.adopt(key: "quit-9", requestID: "0123456789abcdef0123456789abcdef")
        let terminal = await writer.cancel(key: "quit-9", fields: ["action": "quit", "targetId": "9"])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/team/command/cancel") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        for name in ["action", "targetId", "requestId"] { XCTAssertTrue(body.contains("\"\(name)\""), name) }
        XCTAssertEqual(terminal, .cancelled(200))
    }

    func testClubCustomersPostsFilterPageAndDecodesMemberRow() async throws {
        let service = ClubGovernanceService(configuration: try config(), transport: PinTransport("{}"))
        let fields = try ClubGovernanceRead.customers.fields(scope: ClubGovernanceScope(clubID: 3), options: [
            "filter": .string("repeat"), "keyword": .string("ada"), "pageNum": .integer(1), "pageSize": .integer(50)
        ])
        let request = try service.request(path: "api/club/crm/customers/list", fields: fields, form: false, token: "synthetic-token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/club/crm/customers/list") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        for name in ["clubId", "filter", "keyword", "pageNum", "pageSize"] { XCTAssertTrue(body.contains("\"\(name)\""), name) }
        XCTAssertTrue(body.contains("\"filter\":\"repeat\""))
        let payload = #"{"total":2,"monthNew":1,"items":[{"memberId":8,"displayName":"Ada","verifiedCount":1,"pendingCount":0,"lastVisitDate":"2026-03-04","phoneText":"138","avatar":"https://example.com/a.png","remark":"vip","lastTopicName":"Walk"}]}"#
        let value = try JSONDecoder().decode(ClubGovernanceValue.self, from: Data(payload.utf8))
        let page = try ClubOpsCustomerListPresentation(value: value)
        XCTAssertEqual(page.total, 2)
        XCTAssertEqual(page.monthNew, 1)
        let customer = try XCTUnwrap(page.rows.first)
        XCTAssertEqual(customer.displayName, "Ada")
        XCTAssertEqual(customer.subText, "vip")
        XCTAssertEqual(customer.avatar, "https://example.com/a.png")
        guard case .verified(let count, let day) = customer.meta else { return XCTFail("customer meta") }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(day, "03-04")
    }

    func testClubCheckinPostsRegistrationAndDecodesDisplayName() async throws {
        let service = ClubGovernanceService(configuration: try config(), transport: PinTransport("{}"))
        let fields = try ClubGovernanceRead.checkin.fields(scope: ClubGovernanceScope(clubID: 3, registrationID: 9))
        let request = try service.request(path: "api/club/crm/checkin/detail", fields: fields, form: false, token: "synthetic-token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/club/crm/checkin/detail") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        for name in ["clubId", "registrationId"] { XCTAssertTrue(body.contains("\"\(name)\""), name) }
        let payload = #"{"registrationId":9,"displayName":"Ada","topicName":"Walk","railStep":1,"canRefund":false}"#
        let value = try JSONDecoder().decode(ClubGovernanceValue.self, from: Data(payload.utf8))
        let page = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: value)
        guard case .ready(let facts)? = page.phase else { return XCTFail("checkin") }
        XCTAssertEqual(facts.registrationIDText, "9")
        XCTAssertEqual(facts.displayName, "Ada")
        XCTAssertEqual(facts.topicName, "Walk")
        XCTAssertEqual(facts.railStepText, "1")
        XCTAssertFalse(facts.serverCanRefund)
    }

    func testFollowActionPostsMemberAndFollowAndDecodesReply() async throws {
        let transport = PinTransport(#"{"code":200,"msg":"ok","data":{"follow":1}}"#)
        let service = MemberRound2Service(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: { "synthetic-token" }, transport: transport)
        guard case .ok(let data, let message) = await service.followClubOwner(memberID: 4, follow: true) else { return XCTFail("follow") }
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/user/follow/action") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("follow_member_id=4"))
        XCTAssertTrue(body.contains("follow=1"))
        XCTAssertEqual(message, "ok")
        XCTAssertEqual(data["follow"].integer, 1)
        let write = SquareFollowWrite.toggle(memberID: 4, isFollowing: false, inFlight: false)
        XCTAssertEqual(write?.fields["follow_member_id"], "4")
        XCTAssertEqual(write?.fields["follow"], "1")
    }

    func testSetInviterPostsInviterIdWhenBindingIsExplicitlyEnabled() async throws {
        let epoch = UUID()
        let session = DoorReferralSession(accountID: 7, epoch: epoch, token: "synthetic-token", restored: true)
        let transport = PinTransport(#"{"code":200,"msg":"ok"}"#)
        let service = DoorReferralService(configuration: try config(), transport: transport, bindingEnabled: true, currentSession: { session })
        try await service.bind(inviter: 9, session: session)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/user/setInviter") == true)
        XCTAssertTrue(multipart(request).contains("name=\"inviter_id\"\r\n\r\n9\r\n"))
        let dormant = DoorReferralService(configuration: try config(), transport: PinTransport(#"{"code":200}"#), currentSession: { session })
        XCTAssertFalse(dormant.bindingEnabled)
    }

    func testJoinInfoPostsMemberIdAndDecodesTitle() async throws {
        let transport = PinTransport(#"{"code":200,"data":{"id":4,"name":"Joined","title":"Walk"}}"#)
        let service = PlayerGapService(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: { "synthetic-token" }, transport: transport)
        let info = try XCTUnwrap(await service.joinInfo(memberID: 4))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.contains("api/registration/join_info") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("member_id=4"))
        XCTAssertEqual(info.id, 4)
        XCTAssertEqual(info.title, "Walk")
        XCTAssertTrue(info.hasJoin)
    }

    func testActiveOfficialForRoamGetsNoQueryAndDecodesTitle() async throws {
        let json = #"{"code":200,"data":{"list":[{"id":3,"title":"Night","coverImg":"https://example.com/c.png"}]}}"#
        let transport = PinTransport(json)
        let service = PlayerGapService(baseURL: try XCTUnwrap(URL(string: "https://example.com/")), token: { "synthetic-token" }, transport: transport)
        let card = try XCTUnwrap(await service.activeOfficialForRoam())
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.contains("api/official/active-for-roam") == true)
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(card.firstTitle, "Night")
        XCTAssertEqual(card.count, 1)
        XCTAssertEqual(card.cover, "https://example.com/c.png")
        XCTAssertEqual(card.eventID, 3)
    }

    func testRegistrationPayStaysBlockedAndSendsNothing() throws {
        XCTAssertEqual(Adapt5HighRiskWriteSupplement.registrationPay.rawValue, "/api/registration/pay")
        XCTAssertTrue(Adapt5HighRiskWriteSupplement.registrationPay.rawValue.contains("api/registration/pay"))
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "9")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
    }

    func testBindPhoneStaysUnconfiguredAndSendsNothing() async throws {
        let transport = PinTransport(#"{"code":200,"data":{"phone":"138"}}"#)
        let client = AccountPublishRemainingClient(configuration: try config(), transport: transport)
        do {
            _ = try await client.bindPhone(code: "1234", token: "synthetic-token")
            XCTFail("bind")
        } catch {
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testMerchantCenterPagesStayHiddenWhenTheReleaseFlagIsOff() {
        XCTAssertTrue(PlayerLaunch.isHidden(page: "pages/merchant/home/index", enabled: false))
        XCTAssertTrue(PlayerLaunch.isHidden(page: "pages/coop/index", enabled: false))
        XCTAssertTrue(PlayerLaunch.isHidden(page: "pages/cooperation/index", enabled: false))
        XCTAssertTrue(PlayerLaunch.isHidden(page: "pages/topic/merchantapply/index", enabled: false))
        XCTAssertTrue(PlayerLaunch.isHidden(page: "pages/topic/merchantinfo/merchantinfo", enabled: false))
        XCTAssertFalse(PlayerLaunch.isHidden(page: "pages/merchant/profile/index", enabled: false))
        XCTAssertFalse(PlayerLaunch.isHidden(page: "pages/index/index", enabled: false))
    }
}

private final class PinTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var response: String
    var status: Int
    init(_ response: String, status: Int = 200) {
        self.response = response
        self.status = status
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(response.utf8), status)
    }
}

private final class SupportMatrixWire: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let matrix: [String: Any] = [
            "schemaVersion": 1,
            "types": [["key": "qaText", "tools": [String: Any]()]],
            "addons": [["key": "timer", "tools": [String: Any]()]],
            "constraints": [String: Any](),
            "legacyProofs": [String: Any]()
        ]
        return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": matrix]), 200)
    }
}
