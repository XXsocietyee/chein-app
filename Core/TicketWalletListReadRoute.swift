import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exact two list requests emitted by the existing ticket-wallet service. This is not
/// an endpoint-prefix grant: order lists, details, pagination and writes are excluded.
public enum TicketWalletListReadRoute: Int, Equatable, CaseIterable {
    case route = 1, activity = 2
    public init?(request: URLRequest, baseURL: URL) {
        guard baseURL.scheme == "https", baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil,
              let url = request.url, url.query == nil, url.fragment == nil,
              url.absoluteString.utf8.elementsEqual(baseURL.appendingPathComponent("api/registration/list").absoluteString.utf8),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              let body = request.httpBody, body.count <= 2048,
              let text = String(data: body, encoding: .utf8),
              let type = request.value(forHTTPHeaderField: "Content-Type"),
              type.hasPrefix("multipart/form-data; boundary=") else { return nil }
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        guard !boundary.isEmpty, boundary.count <= 70,
              boundary.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { return nil }
        guard let fields = Self.fields(text, boundary: boundary) else { return nil }
        guard let raw = fields["owner_type"], raw == "1" || raw == "2", let value = Int(raw),
              let lane = Self(rawValue: value) else { return nil }
        let keys = Set(fields.keys)
        if keys == ["owner_type"] {
            // Older owner-type-only body stays a list read.
        } else if keys == ["owner_type", "pageNum", "pageSize"] {
            guard let page = fields["pageNum"], let pageSize = fields["pageSize"],
                  page == String(Int(page) ?? -1), (Int(page) ?? 0) >= 1, pageSize == "10" else { return nil }
        } else { return nil }
        guard let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: nil, boundary: boundary),
              canonical.httpBody == body else { return nil }
        self = lane
    }

    private static func fields(_ text: String, boundary: String) -> [String: String]? {
        let marker = "--\(boundary)"
        guard text.hasPrefix(marker), text.hasSuffix("\(marker)--\r\n") else { return nil }
        var fields: [String: String] = [:]
        for part in text.components(separatedBy: marker).dropFirst() {
            if part == "--\r\n" { continue }
            let header = "\r\nContent-Disposition: form-data; name=\""
            guard part.hasPrefix(header) else { return nil }
            let rest = part.dropFirst(header.count)
            guard let quote = rest.firstIndex(of: "\"") else { return nil }
            let name = String(rest[..<quote])
            let after = rest[rest.index(after: quote)...]
            guard after.hasPrefix("\r\n\r\n") else { return nil }
            // "\r\n" is ONE Swift Character, so trim by separator Character counts, not
            // byte counts: dropFirst(4)/removeLast(2) from a12ffd853 also ate the value itself.
            var value = String(after.dropFirst("\r\n\r\n".count))
            guard value.hasSuffix("\r\n") else { return nil }
            value.removeLast("\r\n".count)
            guard fields[name] == nil, !name.isEmpty else { return nil }
            fields[name] = value
        }
        return fields
    }

    /// Defense in depth before the existing display DTO discards memberId. A successful
    /// mixed/unknown-owner lane is rejected as a whole; no private rows are filtered into
    /// an apparently complete success. HTTP/business/401 failures retain existing meaning.
    public func validateResponse(_ response: (Data, Int), expectedAccountID: Int) throws {
        guard expectedAccountID > 0 else { throw APIError.invalidRequest }
        guard (200..<300).contains(response.1) else { return }
        let envelope: OwnershipEnvelope
        do { envelope = try JSONDecoder().decode(OwnershipEnvelope.self, from: response.0) }
        catch { throw APIError.malformedResponse }
        guard envelope.code == 200 else { return }
        guard envelope.rows.allSatisfy({ $0.id > 0 && $0.memberId == expectedAccountID &&
            $0.memberId > 0 && $0.ownerType == rawValue }) else { throw APIError.malformedResponse }
    }
    private struct OwnedRow: Decodable {
        let id: Int
        let memberId: Int
        let ownerType: Int
    }
    private struct OwnershipPage: Decodable { let rows: [OwnedRow] }
    private struct OwnershipEnvelope: Decodable {
        let code: Int
        let rows: [OwnedRow]
        enum CodingKeys: String, CodingKey { case code, data }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            code = try c.decode(Int.self, forKey: .code)
            // Do not let an unrelated malformed payload obscure a current 401/business error.
            guard code == 200 else { rows = []; return }
            // Existing wallet semantics define absent/null data as empty, not a network fallback.
            guard c.contains(.data), try !c.decodeNil(forKey: .data) else { rows = []; return }
            if let array = try? c.decode([OwnedRow].self, forKey: .data) { rows = array }
            else { rows = try c.decode(OwnershipPage.self, forKey: .data).rows }
        }
    }
}
