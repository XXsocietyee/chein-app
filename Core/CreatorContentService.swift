import Foundation

/// Two independently loaded own-account domains. Only audited read routes exist here.
/// Inject the app's existing ephemeral/no-redirect transport; there is no default host.
public struct CreatorContentService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let reads = InFlightReadCoalescer<InFlightHTTPBody>()
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
    }
    public func projects(query: CreatorContentQuery = .init(), operationScope: String? = nil, token: String) async throws -> CreatorContentProjectPage {
        guard query.isValid else { throw APIError.invalidRequest }
        var fields = ["type": query.type, "state": query.state, "ownerType": query.ownerType, "pageNum": "1", "pageSize": "200"]
        if let scope = try Self.merchantWireScope(operationScope) { fields["scope"] = scope }
        let data = try await post("api/project/my", fields: fields, token: token)
        let page = try decode(ProjectsEnvelope.self, data).data
        // subpackageA/utils/merchant-join-projects.js: only the merchant list appends accepted joins.
        guard try Self.merchantWireScope(operationScope) == "MERCHANT" else { return page }
        let legacy = try await post("api/registration/merchant/list", fields: ["status": "0"], token: token)
        let chapter = try await post("api/merchant/chapter-application/mine", fields: [:], token: token)
        let joined = try MerchantJoinProjects.cards(
            legacyRows: Self.recordRows(legacy), chapterRows: Self.recordRows(chapter), today: MerchantJoinProjects.shanghaiDay()
        )
        var seen = Set(page.rows.map(\.id))
        let extra = joined.filter { seen.insert($0.id).inserted }
        return CreatorContentProjectPage(rows: page.rows + extra, total: page.total + extra.count, serverScope: page.serverScope)
    }
    /// `data` as a record list, or `data.rows`. A missing or non-list payload fails the whole read.
    static func recordRows(_ data: Data) throws -> [[String: Any]] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.malformedResponse }
        let payload = root["data"]
        if let list = payload as? [[String: Any]] { return list }
        if let page = payload as? [String: Any], let rows = page["rows"] as? [[String: Any]] { return rows }
        if let list = payload as? [Any], list.isEmpty { return [] }
        throw APIError.malformedResponse
    }
    /// Personal and club entries omit `scope`. Only the merchant entry sends `MERCHANT`.
    /// Any other non-empty value is rejected here; the server also rejects unknown scopes.
    public static func merchantWireScope(_ raw: String?) throws -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard trimmed.caseInsensitiveCompare("MERCHANT") == .orderedSame else { throw APIError.invalidRequest }
        return "MERCHANT"
    }
    public func center(token: String) async throws -> CreatorContentCenter {
        let data = try await post("api/creator/center", fields: [:], token: token)
        return try decode(CenterEnvelope.self, data).data
    }
    private func post(_ path: String, fields: [String: String], token: String) async throws -> Data {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        let key = InFlightReadKey.fields(method: "POST", path: path, fields: fields, token: token)
        try Task.checkCancellation()
        let response = try await reads.join(key) {
            let request = try AuthRequestBuilder.makeFormRequest(url: self.configuration.baseURL.appendingPathComponent(path), fields: fields, token: token)
            let (data, status) = try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        try Task.checkCancellation()
        let (data, status) = (response.data, response.status)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            if let envelope = try? JSONDecoder().decode(StatusEnvelope.self, from: data), let message = envelope.message {
                throw CreatorContentReadFailure.rejected(code: envelope.code, message: message)
            }
            throw APIError.httpStatus(status)
        }
        let statusEnvelope = try decode(StatusEnvelope.self, data)
        if statusEnvelope.code == 401 { throw APIError.unauthorized }
        guard statusEnvelope.code == 200 else {
            throw CreatorContentReadFailure.rejected(code: statusEnvelope.code, message: statusEnvelope.message)
        }
        return data
    }
    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.malformedResponse }
    }
    private struct StatusEnvelope: Decodable {
        let code: Int
        let message: String?
        enum CodingKeys: String, CodingKey { case code, msg }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            code = try c.decode(Int.self, forKey: .code)
            message = try? c.decode(String.self, forKey: .msg)
        }
    }
    private struct ProjectsEnvelope: Decodable { let data: CreatorContentProjectPage }
    private struct CenterEnvelope: Decodable { let data: CreatorContentCenter }
}

/// Accepted merchant joins from `api/registration/merchant/list` and `api/merchant/chapter-application/mine`.
public enum MerchantJoinProjects {
    public static func shanghaiDay(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = .chinaActivity
        formatter.timeZone = Calendar.chinaActivity.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public static func cards(legacyRows: [[String: Any]], chapterRows: [[String: Any]], today: String) throws -> [CreatorContentProject] {
        let legacy = legacyRows.filter { intValue($0["status"]) == 1 && !isEnded($0, today: today) }
        var legacyTopics = Set(legacy.compactMap { topicKey($0) })
        var items: [(key: String, row: [String: Any], pending: Bool)] = legacy.compactMap { row in
            guard let key = topicKey(row) else { return nil }
            return (key, row, false)
        }
        var chapterTopics: [String: [String: Any]] = [:]
        for row in chapterRows {
            guard let key = topicKey(row), intValue(row["topicId"]).map({ $0 > 0 }) == true else { continue }
            let pending = isPendingInvite(row)
            guard intValue(row["status"]) == 1 || pending else { continue }
            if chapterTopics[key] == nil || pending { chapterTopics[key] = row }
        }
        for key in chapterTopics.keys.sorted() {
            guard let row = chapterTopics[key] else { continue }
            let pending = isPendingInvite(row)
            if !legacyTopics.contains(key) {
                items.append((key, row, pending))
            } else if pending, let index = items.firstIndex(where: { $0.key == key }) {
                items[index] = (key, row, true)
                legacyTopics.insert(key)
            }
        }
        return try items.map { try decodeCard($0.row, pending: $0.pending) }
    }

    private static func decodeCard(_ row: [String: Any], pending: Bool) throws -> CreatorContentProject {
        let topicID = intValue(row["topicId"]) ?? 0
        let dateLabel = statusLabel(row["startDate"], row["endDate"])
        let label = pending && dateLabel != "已结束" ? "待接受" : dateLabel
        let state: String
        switch label {
        case "待接受": state = "pending"
        case "未开始": state = "notStarted"
        case "已结束": state = "completed"
        case "进行中": state = "running"
        default: state = "running"
        }
        let title = text(row["topicName"]).isEmpty ? (text(row["addressName"]).isEmpty ? "未命名项目" : text(row["addressName"])) : text(row["topicName"])
        let cover = text(row["topicImgUrl"]).isEmpty ? text(row["imgUrl"]) : text(row["topicImgUrl"])
        let object: [String: Any] = [
            "id": topicID, "bizType": "topic", "ownerType": "merchant", "title": title, "cover": cover,
            "startTime": text(row["startDate"]), "endTime": text(row["endDate"]), "addressName": text(row["addressName"]),
            "state": state, "stateText": label.isEmpty ? "承接中" : label,
            "projectTypeText": pending ? "受邀" : "承接",
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(CreatorContentProject.self, from: data)
    }

    private static func isEnded(_ row: [String: Any], today: String) -> Bool { statusLabel(row["startDate"], row["endDate"], today: today) == "已结束" }
    private static func statusLabel(_ startRaw: Any?, _ endRaw: Any?, today: String = "") -> String {
        let start = day(startRaw)
        guard !start.isEmpty else { return "" }
        let rawEnd = day(endRaw)
        let end = rawEnd.isEmpty || rawEnd < start ? start : rawEnd
        let day = today.isEmpty ? shanghaiDay() : today
        if day < start { return "未开始" }
        if day > end { return "已结束" }
        return "进行中"
    }
    private static func isPendingInvite(_ row: [String: Any]) -> Bool {
        intValue(row["status"]) == 0 && intValue(row["source"]) == 1
    }
    private static func topicKey(_ row: [String: Any]) -> String? {
        guard let id = intValue(row["topicId"]), id > 0 else { return nil }
        return String(id)
    }
    private static func day(_ raw: Any?) -> String {
        let value = text(raw)
        guard value.count >= 10 else { return "" }
        let prefix = String(value.prefix(10))
        let parts = prefix.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return "" }
        return prefix
    }
    private static func text(_ raw: Any?) -> String {
        if let value = raw as? String { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        return ""
    }
    private static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let value = raw as? NSNumber {
            let number = value.doubleValue
            guard number.rounded() == number, number >= Double(Int.min), number <= Double(Int.max) else { return nil }
            return value.intValue
        }
        return nil
    }
}
