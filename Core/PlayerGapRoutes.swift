import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G7/G8 capability gaps: player routes the mini-program calls that the app did not.
/// Each method is one request with no retry. Shapers port the mini-program helpers named beside them.
/// Money routes (payment readiness, payout receiver, settlement) and club host-only routes are not here.
public enum PlayerGapReply: Equatable, Sendable {
    case ok(PlayWireValue, message: String?)
    case refused(code: Int, message: String?)
    case unauthorized
    case unknown

    /// Only a 4xx business code proves the server did not apply the request.
    public static func classify(data: Data, status: Int) -> PlayerGapReply {
        let envelope = try? JSONDecoder().decode(PlayWireValue.self, from: data)
        let code = envelope?["code"].tolerantInteger
        if status == 401 || code == 401 { return .unauthorized }
        guard (200..<300).contains(status), let envelope, let code else { return .unknown }
        if code == 200 { return .ok(envelope["data"], message: envelope["msg"].text) }
        guard (400..<500).contains(code) else { return .unknown }
        return .refused(code: code, message: envelope["msg"].text)
    }

    public var data: PlayWireValue? { if case .ok(let value, _) = self { return value }; return nil }
    public var message: String? {
        switch self { case .ok(_, let m), .refused(_, let m): return m; default: return nil }
    }
}

@MainActor public final class PlayerGapService {
    /// Every route this service may build, relative to the API base.
    public static let paths: Set<String> = [
        "api/official/active-for-roam", "api/official/signup-command", "api/official/signup-command/query",
        "api/official/signup-command/cancel", "api/team/invite-qrcode", "api/team/trail/state",
        "api/team/trail/consent", "api/team/trail/sync", "api/registration/join_info", "api/city/nodes/favorites",
        "api/city/nodes/merchant/{}", "api/activity/publish_precheck", "api/media/asset/attribution",
        "api/object-card/rename", "api/user/player-code", "api/club/event-ops/host/request",
        "api/club/lead/arrive", "api/club/lead/broadcast", "api/club/post/like-state"
    ]

    public let baseURL: URL
    public let accountID: Int?
    private let token: () -> String?
    let transport: any HTTPTransport

    public init(baseURL: URL, accountID: Int? = nil, token: @escaping () -> String?, transport: any HTTPTransport) {
        self.baseURL = baseURL; self.accountID = accountID; self.token = token; self.transport = transport
    }

    // MARK: request shapes

    func makeRequest(_ path: String, method: String, query: [String: String] = [:],
                     json: [String: PlayWireValue]? = nil, form: [String: String]? = nil) throws -> URLRequest {
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.first == "api", segments.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
                  (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
              } }), let token = token(), AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let built = components.url else { throw APIError.invalidRequest }
            url = built
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
        } else if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents()
            components.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
            request.httpBody = Data(encoded.utf8)
        }
        return request
    }

    /// Multipart POST. The appeal image upload uses this so the file bytes are not passed through the JSON encoder.
    func makeMultipart(_ path: String, body: Data, boundary: String, timeout: TimeInterval) throws -> URLRequest {
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.first == "api", segments.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
                  (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
              } }), let token = token(), AuthRequestBuilder.isValidToken(token),
              !body.isEmpty, (1.0...120.0).contains(timeout),
              !boundary.isEmpty, boundary.utf8.allSatisfy({ $0 >= 33 && $0 != 34 && $0 < 127 }) else { throw APIError.invalidRequest }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func send(_ request: URLRequest) async -> PlayerGapReply {
        do {
            let (data, status) = try await transport.send(request)
            return PlayerGapReply.classify(data: data, status: status)
        } catch { return .unknown }
    }

    private func get(_ path: String, query: [String: String] = [:]) async -> PlayerGapReply {
        guard let request = try? makeRequest(path, method: "GET", query: query) else { return .unknown }
        return await send(request)
    }
    private func post(_ path: String, json: [String: PlayWireValue]) async -> PlayerGapReply {
        guard let request = try? makeRequest(path, method: "POST", json: json) else { return .unknown }
        return await send(request)
    }
    private func postForm(_ path: String, form: [String: String]) async -> PlayerGapReply {
        guard let request = try? makeRequest(path, method: "POST", form: form) else { return .unknown }
        return await send(request)
    }

    // MARK: official events

    /// `utils/roam-official-active.js`: GET with no parameters.
    public func activeOfficialForRoam() async -> OfficialRoamActiveCard? {
        guard case .ok(let data, _) = await get("api/official/active-for-roam") else { return nil }
        return OfficialRoamActiveCard.make(data["list"].array ?? data.array)
    }

    /// `utils/team-event-command.js` domain SIGNUP: submit sends the frozen command, query sends `{requestId}`.
    public func signupCommand(_ mode: OfficialSignupCommandMode, command: OfficialSignupCommand) async -> OfficialSignupReceipt? {
        let path: String
        let body: [String: PlayWireValue]
        switch mode {
        case .submit: path = "api/official/signup-command"; body = command.body
        case .cancel: path = "api/official/signup-command/cancel"; body = command.body
        case .query: path = "api/official/signup-command/query"; body = ["requestId": .string(command.requestID)]
        }
        guard case .ok(let data, _) = await post(path, json: body) else { return nil }
        return OfficialSignupReceipt(data, requestID: command.requestID)
    }

    // MARK: team

    /// `pages/team/utils/team-invite-qr.js` load + viewOf.
    public func teamInviteQRCode(teamID: Int) async -> TeamInviteQRView {
        guard teamID > 0 else { return .error(message: nil) }
        return TeamInviteQRView.make(await post("api/team/invite-qrcode", json: ["teamId": .int(teamID)]))
    }

    public func teamTrailState(activityID: Int) async -> PlayerGapReply {
        await get("api/team/trail/state", query: ["activityId": String(activityID)])
    }
    public func teamTrailConsent(activityID: Int, share: Bool) async -> PlayerGapReply {
        await post("api/team/trail/consent", json: ["activityId": .string(String(activityID)), "share": .bool(share)])
    }
    public func teamTrailSync(activityID: Int, points: [TeamTrailPoint], done: Int, finished: Bool = false) async -> PlayerGapReply {
        var body: [String: PlayWireValue] = [
            "activityId": .string(String(activityID)),
            "pts": .array(points.map { .array([.number($0.latitude), .number($0.longitude)]) }),
            "done": .int(done)
        ]
        if finished { body["finished"] = .bool(true) }
        return await post("api/team/trail/sync", json: body)
    }

    // MARK: registration / club ops

    /// Profile `loadJoinData`: `{member_id}`; a 200 without data is `{id:0}`.
    public func joinInfo(memberID: Int) async -> RegistrationJoinInfo? {
        guard memberID > 0, case .ok(let data, _) = await postForm("api/registration/join_info", form: ["member_id": String(memberID)]) else { return nil }
        return RegistrationJoinInfo(data)
    }

    /// Baoming `requestHost`: JSON `{activityId, ticketId}`. The result is the reread reservation state, not this reply.
    public func requestHost(activityID: Int, ticketID: Int) async -> PlayerGapReply {
        guard activityID > 0, ticketID > 0 else { return .unknown }
        return await post("api/club/event-ops/host/request", json: ["activityId": .int(activityID), "ticketId": .int(ticketID)])
    }

    /// Activity publish `guardPublisherRole`: 200 allows, 401 is sign-in, 403 is a denial with the server text.
    public func publishPrecheck(merchantHost: Bool) async -> ActivityPublishPrecheck {
        ActivityPublishPrecheck.make(await postForm("api/activity/publish_precheck", form: merchantHost ? ["scope": "MERCHANT"] : [:]))
    }

    // MARK: club lead (member actions only)

    /// `leadArrive`: one GCJ-02 fix the player approved for this check-in.
    public func leadArrive(activityID: Int, latitude: Double, longitude: Double) async -> PlayerGapReply {
        guard activityID > 0, latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180 else { return .unknown }
        return await postForm("api/club/lead/arrive", form: ["activityId": String(activityID),
            "latitude": String(latitude), "longitude": String(longitude)])
    }
    public func leadBroadcast(activityID: Int, text: String) async -> PlayerGapReply {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard activityID > 0, !trimmed.isEmpty else { return .unknown }
        return await postForm("api/club/lead/broadcast", form: ["activityId": String(activityID), "text": text])
    }

    /// Club detail like readback after an unknown like outcome.
    public func clubPostLikeState(postID: Int, clubID: Int) async -> ClubPostLikeState? {
        guard postID > 0, clubID > 0,
              case .ok(let data, _) = await post("api/club/post/like-state", json: ["id": .int(postID), "clubId": .int(clubID)]) else { return nil }
        return ClubPostLikeState(data, postID: postID, clubID: clubID)
    }

    // MARK: city, media, cards, profile

    /// `pages/mylike`: one full read, no paging. Rows keyed by `poiId`.
    public func favoriteCityNodes() async -> [CityFavoriteNode]? {
        guard case .ok(let data, _) = await get("api/city/nodes/favorites"), let rows = data.array else { return nil }
        guard rows.allSatisfy({ $0.object != nil }) else { return nil }
        return rows.compactMap(CityFavoriteNode.init)
    }

    /// `merchant-node-favorite.js` shapeMerchantNode: nil hides the block.
    public func merchantCityNode(merchantID: Int) async -> CityMerchantNode? {
        guard merchantID > 0, case .ok(let data, _) = await get("api/city/nodes/merchant/\(merchantID)") else { return nil }
        return CityMerchantNode(data)
    }

    /// BL-69 toggle: only a 200 with a boolean `favorited` counts; anything else leaves local state unchanged.
    public func toggleCityNodeFavorite(poiID: Int) async -> Bool? {
        guard poiID > 0, case .ok(let data, _) = await post("api/city/nodes/\(poiID)/favorite", json: [:]) else { return nil }
        return data["favorited"].bool
    }

    /// `topic-adoption.js` creditText: only the attribution line, at most 40 characters.
    public func assetCredit(reference: String) async -> String? {
        let reference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reference.isEmpty, case .ok(let data, _) = await get("api/media/asset/attribution", query: ["reference": reference]) else { return nil }
        return MediaAssetCredit.text(data)
    }

    /// Object cards `onRenameSubmit`: the server validates the title; a saved title comes back in `data.title`.
    public func renameObjectCard(id: Int, title: String) async -> ObjectCardRenameResult {
        guard id > 0 else { return .failed(message: nil) }
        let reply = await postForm("api/object-card/rename", form: ["id": String(id), "title": title])
        if case .ok(let data, _) = reply, let saved = data["title"].text { return .renamed(saved) }
        if case .unknown = reply { return .failed(message: nil) }
        return .failed(message: reply.message)
    }

    /// `player-code.js` readPlayerCode: only an http(s) `data.qr`.
    public func playerCode() async -> URL? {
        guard case .ok(let data, _) = await post("api/user/player-code", json: [:]) else { return nil }
        return PlayerCode.read(data)
    }
}

// MARK: - Shapers

public struct OfficialRoamActiveCard: Equatable {
    public let firstTitle: String
    public let count: Int
    public let cover: String
    /// Set only when one event is open, so the card opens its detail; several go to the list.
    public let eventID: Int?

    static func make(_ list: [PlayWireValue]?) -> OfficialRoamActiveCard? {
        guard let list else { return nil }
        let rows = list.filter { row in
            guard row["id"].tolerantInteger != nil, let title = row["title"].text else { return false }
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard let first = rows.first, let title = first["title"].text else { return nil }
        return .init(firstTitle: title.trimmingCharacters(in: .whitespacesAndNewlines), count: rows.count,
                     cover: (first["coverImg"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                     eventID: rows.count == 1 ? first["id"].tolerantInteger : nil)
    }
}

public enum OfficialSignupCommandMode { case submit, query, cancel }

/// One frozen signup intention. The 32-hex request id is persisted before dispatch.
public struct OfficialSignupCommand: Codable, Equatable {
    public let eventID: Int
    public let requestID: String
    public let action: String
    public init?(eventID: Int, requestID: String, action: String = "signup") {
        guard eventID > 0, OfficialSignupCommand.validRequestID(requestID) else { return nil }
        self.eventID = eventID; self.requestID = requestID; self.action = action
    }
    var body: [String: PlayWireValue] {
        ["targetId": .string(String(eventID)), "action": .string(action), "requestId": .string(requestID)]
    }
    public static func validRequestID(_ value: String) -> Bool {
        value.count == 32 && value.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
    }
    public static func newRequestID() -> String { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
}

public struct OfficialSignupReceipt: Equatable {
    public enum State: String { case applied = "APPLIED", rejected = "REJECTED", cancelled = "CANCELLED" }
    public let state: State
    public let message: String?
    public let errorCode: String?
    /// A receipt for another request id, or a non-terminal state, is not a result.
    init?(_ raw: PlayWireValue, requestID: String) {
        guard raw["requestId"].text == requestID, let state = raw["state"].text.flatMap(State.init(rawValue:)) else { return nil }
        self.state = state; message = raw["message"].text
        errorCode = raw["errorCode"].text ?? raw["data"]["errorCode"].text
    }
    public var safetyBlocked: Bool { state == .rejected && errorCode == "ORIENT_SAFETY_BLOCKED" }
}

/// Persisted signup intentions per account and event. Absence from the server never clears one.
public protocol OfficialSignupCommandStoring: AnyObject {
    func load(key: String) -> OfficialSignupCommand?
    func save(_ command: OfficialSignupCommand, key: String) -> Bool
    func clear(key: String) -> Bool
}

public final class OfficialSignupCommandDefaultsStore: OfficialSignupCommandStoring {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load(key: String) -> OfficialSignupCommand? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(OfficialSignupCommand.self, from: $0) }
    }
    public func save(_ command: OfficialSignupCommand, key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(command) else { return false }
        defaults.set(data, forKey: key)
        return load(key: key) == command
    }
    public func clear(key: String) -> Bool { defaults.removeObject(forKey: key); return defaults.data(forKey: key) == nil }
}

/// Port of `createRecovery` for domain SIGNUP with `settle` on.
@MainActor @Observable public final class OfficialSignupCommandFlow {
    public enum Phase: Equatable { case idle, busy, unknown, settled(OfficialSignupReceipt.State, message: String?), storageError }
    public private(set) var phase: Phase = .idle
    public private(set) var safetyBlocked = false
    private let service: PlayerGapService
    private let store: any OfficialSignupCommandStoring
    private let key: String
    private let eventID: Int

    public init(service: PlayerGapService, store: any OfficialSignupCommandStoring, accountID: Int, eventID: Int) {
        self.service = service; self.store = store; self.eventID = eventID
        key = "cy-team-event-command-v1:\(accountID):SIGNUP:\(eventID)"
        if store.load(key: key) != nil { phase = .unknown }
    }

    public var hasPending: Bool { store.load(key: key) != nil || phase == .busy }

    /// Persistence precedes dispatch. An open intention is never replaced by a new one.
    public func start() async -> OfficialSignupReceipt.State? {
        guard phase != .busy, store.load(key: key) == nil else { return nil }
        guard let command = OfficialSignupCommand(eventID: eventID, requestID: OfficialSignupCommand.newRequestID()),
              store.save(command, key: key) else { phase = .storageError; return nil }
        return await send(.submit, command)
    }
    public func query() async -> OfficialSignupReceipt.State? { await resume(.query) }
    public func retry() async -> OfficialSignupReceipt.State? { await resume(.submit) }
    public func cancel() async -> OfficialSignupReceipt.State? { await resume(.cancel) }

    private func resume(_ mode: OfficialSignupCommandMode) async -> OfficialSignupReceipt.State? {
        guard phase != .busy, let command = store.load(key: key) else { return nil }
        return await send(mode, command)
    }

    private func send(_ mode: OfficialSignupCommandMode, _ command: OfficialSignupCommand) async -> OfficialSignupReceipt.State? {
        phase = .busy
        guard let receipt = await service.signupCommand(mode, command: command) else { phase = .unknown; return nil }
        // A terminal receipt is a definite result: archive the slot and keep a plain outcome.
        guard store.clear(key: key) else { phase = .storageError; return nil }
        safetyBlocked = receipt.safetyBlocked
        phase = .settled(receipt.state, message: receipt.state == .rejected ? receipt.message : nil)
        return receipt.state
    }
}

public enum TeamInviteQRView: Equatable {
    case ready(qr: URL, code: String)
    case code(String)
    case error(message: String?)

    /// `viewOf`: the code comes only from the reply; the image only when `qrState` is READY with a URL.
    static func make(_ reply: PlayerGapReply) -> TeamInviteQRView {
        guard case .ok(let data, _) = reply, data.object != nil else { return .error(message: reply.message) }
        let code = (data["inviteCode"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return .error(message: nil) }
        if data["qrState"].text == "READY", let raw = data["qrcodeUrl"].text?.trimmingCharacters(in: .whitespacesAndNewlines),
           PlayExperienceService.validHTTPS(raw), let url = URL(string: raw) {
            return .ready(qr: url, code: code)
        }
        return .code(code)
    }

    /// `normalizeJoinCode`: six-character codes are case-insensitive; two legacy forms still pass.
    public static func normalizeJoinCode(_ text: String) -> String? {
        let code = text.filter { !$0.isWhitespace }
        let six = Set("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        if code.count == 6, code.uppercased().allSatisfy({ six.contains($0) }) { return code.uppercased() }
        if code.count == 22, code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) { return code }
        if code.count == 32, code.allSatisfy({ $0.isHexDigit }) { return code.lowercased() }
        return nil
    }
}

public struct TeamTrailPoint: Equatable {
    public let latitude: Double, longitude: Double
    public init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude }
}

public struct TeamTrailTeam: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let avatar: String
    public let colorIndex: Int
    public let done: Int
    public let points: [TeamTrailPoint]
    public var last: TeamTrailPoint { points[points.count - 1] }
    /// `initialOf`: the first character of the name when there is no avatar.
    public var initial: String { avatar.isEmpty ? name.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? "" : "" }
}

public struct TeamTrailState: Equatable {
    public var available = false, share = false, decided = false
}

/// Port of `pages/play/utils/team-trail.js`. Only on an activity run, only while the player shares.
/// About 12 s per sync, backing off to 60 s; each sync uploads only points since the last success (at most 40).
@MainActor @Observable public final class TeamTrailModel {
    public static let interval: TimeInterval = 12, maxInterval: TimeInterval = 60, maxUpload = 40
    public private(set) var state = TeamTrailState()
    public private(set) var teams: [TeamTrailTeam] = []
    private let service: PlayerGapService
    private let activityID: Int
    private var colorByKey: [String: Int] = [:]
    private var sentCount = 0
    private var stopped = false

    public init(service: PlayerGapService, activityID: Int) { self.service = service; self.activityID = activityID }

    public func load() async {
        let reply = await service.teamTrailState(activityID: activityID)
        guard let data = reply.data, data.object != nil, data["available"].bool == true else { state = .init(); return }
        state = .init(available: true, share: data["share"].bool == true, decided: data["decided"].bool == true)
    }

    /// When the server does not confirm, the player's own choice wins locally: off stays off.
    @discardableResult public func consent(_ share: Bool) async -> Bool {
        let reply = await service.teamTrailConsent(activityID: activityID, share: share)
        guard let data = reply.data, data.object != nil else {
            state = .init(available: state.available, share: share && state.share, decided: false)
            if !state.share { teams = [] }
            return false
        }
        state = .init(available: data["available"].bool == true, share: data["share"].bool == true, decided: true)
        if !state.share { teams = [] }
        return true
    }

    public var needsConsent: Bool { state.available && !state.decided }
    public var canRun: Bool { !stopped && state.available && state.share }

    /// One sync. Returns false on failure so the caller backs off.
    @discardableResult public func tick(points all: [TeamTrailPoint], done: Int) async -> Bool {
        guard !stopped else { return true }
        if sentCount > all.count { sentCount = 0 }
        let fresh = Array(all.dropFirst(sentCount).suffix(Self.maxUpload))
        let upto = all.count
        let reply = await service.teamTrailSync(activityID: activityID, points: fresh, done: done)
        guard !stopped else { return true }
        guard let data = reply.data, data.object != nil else { return false }
        sentCount = upto
        if data["available"].bool != true || data["share"].bool != true {
            state = .init(available: data["available"].bool == true, share: data["share"].bool == true, decided: state.decided)
            teams = []
            return true
        }
        teams = Self.shapeTeams(data["teams"].array, colors: &colorByKey)
        return true
    }

    /// The player ended the run: the server drops their points, and polling stops.
    public func finish() async {
        guard !stopped else { return }
        stopped = true
        let shared = state.available && state.share
        teams = []
        if shared { _ = await service.teamTrailSync(activityID: activityID, points: [], done: 0, finished: true) }
    }

    static func shapeTeams(_ rows: [PlayWireValue]?, colors: inout [String: Int]) -> [TeamTrailTeam] {
        var teams: [TeamTrailTeam] = []
        for row in rows ?? [] {
            guard let key = row["key"].text ?? row["key"].integer.map(String.init), !key.isEmpty, let raw = row["pts"].array else { continue }
            let points = raw.compactMap { pair -> TeamTrailPoint? in
                guard let p = pair.array, p.count >= 2, let lat = p[0].double ?? p[0].text.flatMap(Double.init),
                      let lng = p[1].double ?? p[1].text.flatMap(Double.init), lat.isFinite, lng.isFinite else { return nil }
                return TeamTrailPoint(latitude: lat, longitude: lng)
            }
            guard !points.isEmpty else { continue }
            if colors[key] == nil { colors[key] = colors.count }
            teams.append(.init(id: key, name: row["name"].text ?? "", avatar: row["avatar"].text ?? "",
                               colorIndex: colors[key]!, done: max(0, row["done"].tolerantInteger ?? 0), points: points))
        }
        return teams
    }
}

public struct RegistrationJoinInfo: Equatable {
    public let id: Int
    public let raw: PlayWireValue
    init(_ data: PlayWireValue) {
        raw = data.object == nil ? .object(["id": .int(0)]) : data
        id = raw["id"].tolerantInteger ?? 0
    }
    public var hasJoin: Bool { id > 0 }
    public var title: String? { raw["title"].text ?? raw["activityTitle"].text ?? raw["name"].text }
}

public enum ActivityPublishPrecheck: Equatable {
    case allowed, signInRequired, denied(String?), failed(String?)
    static func make(_ reply: PlayerGapReply) -> ActivityPublishPrecheck {
        switch reply {
        case .ok: return .allowed
        case .unauthorized: return .signInRequired
        case .refused(let code, let message): return code == 403 ? .denied(message) : .failed(message)
        case .unknown: return .failed(nil)
        }
    }
}

public struct ClubPostLikeState: Equatable {
    public let isLiked: Bool
    public let likeCount: Int?
    init?(_ raw: PlayWireValue, postID: Int, clubID: Int) {
        guard raw.object != nil, raw["id"].tolerantInteger == postID, raw["clubId"].tolerantInteger == clubID,
              let liked = raw["isLiked"].bool else { return nil }
        if case .null = raw["likeCount"] { likeCount = nil }
        else { guard let count = raw["likeCount"].integer else { return nil }; likeCount = count }
        isLiked = liked
    }
}

public struct CityFavoriteNode: Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let address: String?
    public let cover: String?
    init?(_ raw: PlayWireValue) {
        guard let id = raw["poiId"].tolerantInteger, id > 0 else { return nil }
        self.id = id; name = raw["name"].text ?? ""; address = raw["address"].text
        cover = raw["cover"].text ?? raw["coverImg"].text
    }
}

public struct CityMerchantNode: Equatable {
    public let poiID: Int
    public let name: String
    public let favorited: Bool
    init?(_ raw: PlayWireValue) {
        guard raw.object != nil, let id = raw["poiId"].integer, id > 0 else { return nil }
        poiID = id; name = raw["name"].text ?? ""; favorited = raw["favorited"].bool == true
    }
}

public enum MediaAssetCredit {
    static func text(_ raw: PlayWireValue) -> String? {
        guard raw.object != nil, let line = raw["attribution"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else { return nil }
        return String(line.prefix(40))
    }
}

public enum ObjectCardRenameResult: Equatable { case renamed(String), failed(message: String?) }

public enum PlayerCode {
    static func read(_ raw: PlayWireValue) -> URL? {
        guard let qr = raw["qr"].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              qr.hasPrefix("https://") else { return nil }
        return URL(string: qr)
    }
}
