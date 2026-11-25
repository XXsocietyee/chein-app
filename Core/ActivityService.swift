import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read operations only. No registration, review, cancellation, payment or retrying writes.
public struct ActivityService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let reads = InFlightReadCoalescer<InFlightHTTPBody>()
    public init(configuration:APIConfiguration, transport:any HTTPTransport) {
        self.configuration=configuration;self.transport=transport
    }
    private func post<Response: Decodable>(_ path:String, fields:[String:String], token:String?) async throws -> Response {
        let key = InFlightReadKey.fields(method: "POST", path: path, fields: fields, token: token)
        let response = try await reads.join(key) {
            let request=try AuthRequestBuilder.makeFormRequest(url:self.configuration.baseURL.appendingPathComponent(path),fields:fields,token:token)
            let (data,status)=try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        let (data,status)=(response.data,response.status)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        do { return try JSONDecoder().decode(Response.self,from:data) }
        catch let error as APIError { throw error }
        catch { throw APIError.malformedResponse }
    }
    public func list(page:Int=1,pageSize:Int=10,keyword:String?=nil,token:String?=nil) async throws -> [ActivitySummary] {
        guard page > 0, (1...100).contains(pageSize) else { throw APIError.invalidRequest }
        var fields=["is_my":"0","pageNum":String(page),"pageSize":String(pageSize)]
        if let keyword, !keyword.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { fields["keyword"]=keyword }
        let response:ActivityListResponse=try await post("api/activity/list",fields:fields,token:token)
        return response.rows
    }
    public func detail(id:Int,token:String?=nil) async throws -> ActivityDetailAccess {
        guard id > 0 else { throw APIError.invalidRequest }
        let fields = ["id": String(id)]
        let key = InFlightReadKey.fields(method: "POST", path: "api/activity/info", fields: fields, token: token)
        let response = try await reads.join(key) {
            let request = try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent("api/activity/info"), fields: fields, token: token)
            let (data, status) = try await transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        let (data, status) = (response.data, response.status)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let envelope: DetailEnvelope
        do { envelope = try JSONDecoder().decode(DetailEnvelope.self, from: data) }
        catch let error as APIError { throw error }
        catch { throw APIError.malformedResponse }
        if envelope.code == 401 { throw APIError.unauthorized }
        if envelope.code != 200, envelope.errorCode == "ACTIVITY_CANCELLED" {
            return .cancelled(canViewOwnOrders: envelope.canViewOwnOrders == true)
        }
        guard envelope.code == 200 else { throw APIError.businessCode(envelope.code ?? -1) }
        guard let access = envelope.access else { throw ActivityDetailFailure.notFound }
        if case .allowed(let detail) = access, detail.summary.id != id { throw APIError.malformedResponse }
        return access
    }
    private struct DetailEnvelope: Decodable {
        let code: Int?
        let errorCode: String?
        let canViewOwnOrders: Bool?
        let access: ActivityDetailAccess?
        enum CodingKeys: String, CodingKey { case code, errorCode, canViewOwnOrders, data }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let number = try? c.decode(Int.self, forKey: .code) { code = number }
            else if let text = try? c.decode(String.self, forKey: .code) { code = Int(text) }
            else { code = nil }
            errorCode = try c.decodeIfPresent(String.self, forKey: .errorCode)
            canViewOwnOrders = try c.decodeIfPresent(Bool.self, forKey: .canViewOwnOrders)
            if code != 200, errorCode == "ACTIVITY_CANCELLED" {
                access = nil
                return
            }
            if c.contains(.data) == false || (try c.decodeNil(forKey: .data)) {
                access = nil
                return
            }
            access = try c.decode(ActivityDetailAccess.self, forKey: .data)
        }
    }
}

/// `api/activity/info` answered 200 with `data: null`. The page shows 活动不存在.
public enum ActivityDetailFailure: Error, Equatable {
    case notFound
}
