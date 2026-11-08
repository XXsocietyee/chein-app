import Foundation
import XCTest
@testable import Questify
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Scripted transport for the ADAPT-1 tests. No network. Responses are consumed in order; once empty it
/// answers the bare backend success `{code:200,msg}`.
final class Adapt1FakeTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var responses: [(body: String, status: Int)]
    init(_ responses: [(body: String, status: Int)] = []) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let next = responses.isEmpty ? (body: Adapt1Fixture.bareSuccess, status: 200) : responses.removeFirst()
        return (Data(next.body.utf8), next.status)
    }
}

/// Shapes below are the JSON the real backend (hengyin@4ac8c249) produces: `AjaxResult` envelope
/// (`{msg,code[,data]}`), `ApiImController.conversations` rows (`ImServiceImpl.listConversations`),
/// and the `ImMessage` entity serialisation. They live in Tests only.
enum Adapt1Fixture {
    static let bareSuccess = #"{"msg":"操作成功","code":200}"#
    static let reportSuccess = #"{"msg":"举报已提交","code":200}"#
    static let businessError = #"{"msg":"操作失败，请稍后重试","code":500}"#
    static func error(_ message: String, code: Int = 500) -> String { #"{"msg":"\#(message)","code":\#(code)}"# }

    static func conversations(id: Int = 9, type: Int = 1, unread: Int = 3, muted: Int? = 1, extraRows: [Int] = []) -> String {
        func row(_ id: Int, _ muted: Int?) -> String {
            let mutedField = muted.map { #","muted":\#($0)"# } ?? ""
            return #"{"conversationId":\#(id),"type":\#(type),"lastMsgType":1,"lastMsgText":"hi","lastMsgAt":"2026-10-21 10:00:00","unread":\#(unread)\#(mutedField),"counterparty":{"id":42,"nickname":"A","avatar":""}}"#
        }
        let rows = ([row(id, muted)] + extraRows.map { row($0, 0) }).joined(separator: ",")
        return #"{"msg":"操作成功","code":200,"data":[\#(rows)]}"#
    }
    static let emptyConversations = #"{"msg":"操作成功","code":200,"data":[]}"#

    static func sendEnvelope(conversationID: Int = 9, senderID: Int = 7, clientMessageID: String, content: String,
                             card: [String: Any]) -> String {
        let extra = String(data: try! JSONSerialization.data(withJSONObject: card, options: [.sortedKeys]), encoding: .utf8)!
        let message: [String: Any] = ["id": 101, "conversationId": conversationID, "senderId": senderID, "receiverId": NSNull(),
            "msgType": 3, "content": content, "extraJson": extra, "status": 0, "checkStatus": 1,
            "clientMessageId": clientMessageID, "createTime": "2026-10-21 10:00:00"]
        let envelope: [String: Any] = ["msg": "操作成功", "code": 200, "data": message]
        return String(data: try! JSONSerialization.data(withJSONObject: envelope), encoding: .utf8)!
    }
}

func adapt1Fields(_ request: URLRequest) -> [String: String] {
    guard let body = request.httpBody, let text = String(data: body, encoding: .utf8) else { return [:] }
    var fields: [String: String] = [:]
    for part in text.components(separatedBy: "\r\n--").map({ $0 }) {
        guard let nameRange = part.range(of: "name=\""),
              let end = part[nameRange.upperBound...].range(of: "\"\r\n\r\n") else { continue }
        let key = String(part[nameRange.upperBound..<end.lowerBound])
        var value = String(part[end.upperBound...])
        if let cut = value.range(of: "\r\n") { value = String(value[..<cut.lowerBound]) }
        fields[key] = value
    }
    return fields
}

func adapt1Adapter(_ transport: Adapt1FakeTransport, writes: Bool = true, paths: Set<String>) throws -> Adapt1IMBackendAdapter {
    Adapt1IMBackendAdapter(configuration: try APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!),
                           transport: transport, writesEnabled: writes, enabledPaths: paths)
}
func adapt1Scope() throws -> IMScope { try IMScope(identity: MessagingReadIdentity(accountID: 7, epoch: 1), conversationID: 9) }
