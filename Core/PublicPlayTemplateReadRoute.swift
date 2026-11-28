import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exact public play-template reads `DiscoveryService` emits: `api/template/info`, `api/template/list`,
/// and `api/template/homeData`. The composition admits these only with `.homeAndSearch` and a public
/// template viewer. `api/template/myinfo`, `scope`, and any extra field stay out.
public enum PublicPlayTemplateReadRoute {
    public static func accepts(_ request: URLRequest, baseURL: URL) -> Bool {
        guard request.httpMethod == "POST", request.httpBodyStream == nil, request.url?.query == nil,
              request.url?.fragment == nil, let url = request.url else { return false }
        if url.absoluteString == baseURL.appendingPathComponent("api/template/homeData").absoluteString {
            return request.value(forHTTPHeaderField: "Content-Type") == "application/json"
                && request.httpBody == Data("{}".utf8)
        }
        if url.absoluteString == baseURL.appendingPathComponent("api/template/info").absoluteString {
            return form(request, allowed: ["id"], required: ["id"]) { fields in
                guard let raw = fields["id"], let id = Int(raw), id > 0, String(id) == raw else { return false }
                return true
            }
        }
        if url.absoluteString == baseURL.appendingPathComponent("api/template/list").absoluteString {
            return form(request, allowed: ["pageNum", "pageSize", "keyword", "pack_type"],
                        required: ["pageNum", "pageSize"]) { fields in
                guard let rawPage = fields["pageNum"], let page = Int(rawPage),
                      (1...DiscoveryService.playTemplatePageCap).contains(page), String(page) == rawPage,
                      fields["pageSize"] == String(DiscoveryService.playTemplatePageSize) else { return false }
                if let keyword = fields["keyword"], keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
                if let pack = fields["pack_type"], DiscoveryPackType(rawValue: Int(pack) ?? -1) == nil || String(Int(pack) ?? -1) != pack {
                    return false
                }
                return true
            }
        }
        return false
    }

    private static func form(_ request: URLRequest, allowed: Set<String>, required: Set<String>,
                             valid: ([String: String]) -> Bool) -> Bool {
        let typePrefix = "multipart/form-data; boundary="
        guard let type = request.value(forHTTPHeaderField: "Content-Type"), type.hasPrefix(typePrefix),
              let body = request.httpBody, body.count <= 8_192,
              let text = String(data: body, encoding: .utf8) else { return false }
        let boundary = String(type.dropFirst(typePrefix.count))
        guard !boundary.isEmpty, boundary.count <= 70,
              boundary.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { return false }
        let opener = "--\(boundary)\r\n"
        let closer = "\r\n--\(boundary)--\r\n"
        guard text.hasPrefix(opener), text.hasSuffix(closer) else { return false }
        let middle = String(text.dropFirst(opener.count).dropLast(closer.count))
        var fields: [String: String] = [:]
        for part in middle.components(separatedBy: "\r\n--\(boundary)\r\n") {
            let header = "Content-Disposition: form-data; name=\""
            guard part.hasPrefix(header) else { return false }
            let rest = part.dropFirst(header.count)
            guard let endName = rest.firstIndex(of: "\"") else { return false }
            let name = String(rest[..<endName])
            let afterName = rest[rest.index(after: endName)...]
            guard afterName.hasPrefix("\r\n\r\n"), allowed.contains(name), fields[name] == nil else { return false }
            fields[name] = String(afterName.dropFirst(4))
        }
        guard required.isSubset(of: Set(fields.keys)), valid(fields), let url = request.url,
              let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: nil, boundary: boundary),
              canonical.httpBody == body else { return false }
        return true
    }
}
