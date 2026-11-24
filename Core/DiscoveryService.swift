import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Explicitly configured and transport-injected read-only discovery requests.
public struct DiscoveryService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let reads = InFlightReadCoalescer<InFlightHTTPBody>()
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }
    public func banners(token: String? = nil) async throws -> [DiscoveryBanner] {
        let data = try await post("api/common/banner", fields: ["showType": "1", "linkType": "0"], token: token)
        return try await PlayerFeedJSON.perform { () -> [DiscoveryBanner] in
            do { return try JSONDecoder().decode(DiscoveryArrayEnvelope<DiscoveryBanner>.self, from: data).data }
            catch let error as APIError { throw error }
            catch { throw APIError.malformedResponse }
        }
    }
    public func categories(type: Int? = nil, token: String? = nil) async throws -> [DiscoveryCategory] {
        var fields = ["parentid": "0"] // Required by the retained contract, even for root categories.
        if let type { fields["type"] = String(type) }
        let data = try await post("api/category/list", fields: fields, token: token)
        return try await PlayerFeedJSON.perform { () -> [DiscoveryCategory] in
            do { return try JSONDecoder().decode(DiscoveryArrayEnvelope<DiscoveryCategory>.self, from: data).data }
            catch let error as APIError { throw error }
            catch { throw APIError.malformedResponse }
        }
    }
    public func templateMetadataDictionary(kind: TemplateMetadataKind, token: String? = nil) async throws -> [TemplateMetadataOption] {
        let data = try await post("api/common/dict", fields: ["dictType": kind.rawValue], token: token, templateMetadata: true)
        return try decode(TemplateMetadataEnvelope.self, data).data
    }
    public func templateHome(token: String? = nil) async throws -> DiscoveryTemplateHome {
        let data = try await post("api/template/homeData", fields: nil, token: token)
        return try await PlayerFeedJSON.perform { () -> DiscoveryTemplateHome in
            do { return try JSONDecoder().decode(DiscoveryValueEnvelope<DiscoveryTemplateHome>.self, from: data).data }
            catch let error as APIError { throw error }
            catch { throw APIError.malformedResponse }
        }
    }
    /// Shelf page size. The server caps a page at 50; the shelf keeps requesting until a short page or `total`.
    public static let playTemplatePageSize = 50
    /// Safety stop so a corrupt `total` cannot page forever. The mini-program has no cap.
    public static let playTemplatePageCap = 20
    public func playTemplates(keyword: String? = nil, packType: DiscoveryPackType? = nil,
                              token: String? = nil) async throws -> [DiscoveryPlayTemplate] {
        // Intentionally no category filter: Flutter documents categoryId/category_id mismatch.
        var fields: [String: String] = ["pageNum": "1", "pageSize": String(Self.playTemplatePageSize)]
        if let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields["keyword"] = keyword }
        if let packType { fields["pack_type"] = String(packType.rawValue) }
        var collected: [DiscoveryPlayTemplate] = []
        var seen = Set<Int>()
        var page = 1
        var announcedTotal: Int?
        while page <= Self.playTemplatePageCap {
            fields["pageNum"] = String(page)
            let data: Data
            do { data = try await post("api/template/list", fields: fields, token: token) }
            catch {
                if page == 1 { throw error }
                break
            }
            let parsed: (rows: [DiscoveryPlayTemplate], total: Int?)
            do { parsed = try Self.playTemplatePage(data) }
            catch {
                if page == 1 { throw error }
                break
            }
            if page == 1 { announcedTotal = parsed.total }
            let fresh = parsed.rows.filter { seen.insert($0.id).inserted }
            collected.append(contentsOf: fresh)
            if let announcedTotal, collected.count >= announcedTotal { break }
            if parsed.rows.count < Self.playTemplatePageSize || fresh.isEmpty { break }
            page += 1
        }
        return collected
    }
    private static func playTemplatePage(_ data: Data) throws -> (rows: [DiscoveryPlayTemplate], total: Int?) {
        let rows = try JSONDecoder().decode(DiscoveryRowsEnvelope<DiscoveryPlayTemplate>.self, from: data).rows
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.malformedResponse }
        let payload = root["data"]
        let rawTotal: Any?
        if let page = payload as? [String: Any], page.keys.contains("total") { rawTotal = page["total"] }
        else if root.keys.contains("total"), payload as? [Any] != nil || payload == nil { rawTotal = root["total"] }
        else { rawTotal = nil }
        guard let rawTotal else { return (rows, nil) }
        if rawTotal is NSNull { return (rows, nil) }
        guard let total = Self.wholeNumber(rawTotal), total >= 0 else { throw APIError.malformedResponse }
        return (rows, total)
    }
    private static func wholeNumber(_ raw: Any) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber {
            let number = value.doubleValue
            guard number.rounded() == number, number >= 0, number <= Double(Int.max) else { return nil }
            return value.intValue
        }
        return nil
    }
    public func topicTemplates(token: String? = nil) async throws -> [DiscoveryTopicTemplate] {
        let data = try await post("api/template/topic-template/list", fields: nil, token: token)
        return try await PlayerFeedJSON.perform { () -> [DiscoveryTopicTemplate] in
            do { return try JSONDecoder().decode(DiscoveryRowsEnvelope<DiscoveryTopicTemplate>.self, from: data).rows }
            catch let error as APIError { throw error }
            catch { throw APIError.malformedResponse }
        }
    }
    public func publicTopicTemplate(id: Int, token: String? = nil) async throws -> PublicTopicTemplateDetail {
        guard id > 0 else { throw APIError.invalidRequest }
        let data = try await post("api/template/topic-template/info", fields: ["id": String(id)], token: token, templateDetail: true)
        let detail = try decode(DiscoveryValueEnvelope<PublicTopicTemplateDetail>.self, data).data
        guard detail.id == id else { throw APIError.malformedResponse }
        return detail
    }
    public func playTemplate(id: Int, token: String? = nil) async throws -> DiscoveryPlayTemplate {
        guard id > 0 else { throw APIError.invalidRequest }
        let data = try await post("api/template/info", fields: ["id": String(id)], token: token, templateDetail: true)
        let detail = try decode(DiscoveryValueEnvelope<DiscoveryPlayTemplate>.self, data).data
        guard detail.id == id else { throw APIError.malformedResponse }
        return detail
    }
    /// Same `api/template/info` read, also decoding the mini-program detail fields.
    public func playTemplateRead(id: Int, token: String? = nil) async throws -> DiscoveryPlayTemplateRead {
        guard id > 0 else { throw APIError.invalidRequest }
        let data = try await post("api/template/info", fields: ["id": String(id)], token: token, templateDetail: true)
        let detail = try decode(DiscoveryValueEnvelope<DiscoveryPlayTemplate>.self, data).data
        guard detail.id == id else { throw APIError.malformedResponse }
        let extras = try decode(DiscoveryValueEnvelope<DiscoveryPlayTemplateExtras>.self, data).data
        return DiscoveryPlayTemplateRead(template: detail, extras: extras)
    }
    private func post(_ path: String, fields: [String: String]?, token: String?,
                      templateDetail: Bool = false, templateMetadata: Bool = false) async throws -> Data {
        let key = InFlightReadKey.fields(method: "POST", path: path, fields: fields ?? [:], token: token,
                                         tag: "\(fields == nil)")
        let response = try await reads.join(key) {
            var request = try AuthRequestBuilder.makeFormRequest(
                url: self.configuration.baseURL.appendingPathComponent(path), fields: fields ?? [:], token: token)
            if fields == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = Data("{}".utf8)
            }
            let (data, status) = try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        let (data, status) = (response.data, response.status)
        // Check gateway status and envelope code before payload decoding, including detail refusals.
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        if templateMetadata {
            let status = try decode(TemplateMetadataStatusEnvelope.self, data)
            if status.code == 401 { throw APIError.unauthorized }
            guard status.code == 200 else { throw APIError.businessCode(status.code) }
            return data
        }
        let envelope = try decode(DiscoveryStatusEnvelope.self, data)
        if envelope.code == 401 { throw APIError.unauthorized }
        guard envelope.code == 200 else {
            if templateDetail { throw DiscoveryTemplateUnavailable(message: envelope.msg) }
            throw APIError.businessCode(envelope.code)
        }
        return data
    }
    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch let error as APIError { throw error }
        catch { throw APIError.malformedResponse }
    }
}

private struct DiscoveryStatusEnvelope: Decodable {
    let code: Int
    let msg: String?
    enum CodingKeys: String, CodingKey { case code, msg }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(Int.self, forKey: .code)
        // Auth precedence must not depend on an optional server message being well-formed.
        msg = try? c.decode(String.self, forKey: .msg)
    }
}
private struct DiscoveryValueEnvelope<T: Decodable>: Decodable { let data: T }
private struct DiscoveryArrayEnvelope<T: Decodable>: Decodable {
    let data: [T]
    enum CodingKeys: String, CodingKey { case data }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decodeIfPresent([T].self, forKey: .data) ?? []
    }
}
private struct DiscoveryRowsEnvelope<T: Decodable>: Decodable {
    let rows: [T]
    enum CodingKeys: String, CodingKey { case data }
    private struct Page: Decodable { let rows: [T]? }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard c.contains(.data), try !c.decodeNil(forKey: .data) else { rows = []; return }
        if let list = try? c.decode([T].self, forKey: .data) { rows = list; return }
        rows = try c.decode(Page.self, forKey: .data).rows ?? []
    }
}
