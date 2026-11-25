import Foundation

/// Deregister contract matching kept out of `AppCompositionRoot.swift` (size ratchet).
/// `AccountComplianceCompositionRoute.accepts` still decides these routes.
/// Empty GET/POST bodies stay admitted. The contract shape is admitted beside them.
enum AccountComplianceContractGlue {
    /// Status still calls `AccountPublishMPContract.deregisterStatusRequest`.
    static func acceptsStatus(_ request: URLRequest, baseURL: URL, token: String) -> Bool {
        if request.httpMethod == "GET" && request.httpBody == nil && request.value(forHTTPHeaderField: "Content-Type") == nil { return true }
        return matchesContract(request, try? AccountPublishMPContract.deregisterStatusRequest(baseURL: baseURL, token: token))
    }

    /// Precheck still calls `deregisterPrecheckRequest`. Cancel still calls `deregisterCancelRequest`.
    static func acceptsPrecheckOrCancel(_ request: URLRequest, url: URL, baseURL: URL, token: String) -> Bool {
        if request.httpMethod == "POST" && request.httpBody == nil && request.value(forHTTPHeaderField: "Content-Type") == nil { return true }
        if url == baseURL.appendingPathComponent("api/user/deregister/precheck") {
            return matchesContract(request, try? AccountPublishMPContract.deregisterPrecheckRequest(baseURL: baseURL, token: token))
        }
        if url == baseURL.appendingPathComponent("api/user/deregister/cancel") {
            return matchesContract(request, try? AccountPublishMPContract.deregisterCancelRequest(baseURL: baseURL, token: token))
        }
        return false
    }

    /// Apply form still calls `deregisterApplyRequest` with `requestId` and `smscode`.
    /// Multipart apply still calls `AuthRequestBuilder.makeFormRequest`.
    static func acceptsApply(_ request: URLRequest, url: URL, baseURL: URL, token: String) -> Bool {
        guard request.httpMethod == "POST",
              let type = request.value(forHTTPHeaderField: "Content-Type"),
              type.hasPrefix("multipart/form-data; boundary="),
              let body = request.httpBody, body.count <= 1024,
              let text = String(data: body, encoding: .utf8) else {
            return acceptsApplyForm(request, baseURL: baseURL, token: token)
        }
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        var fields: [String: String] = [:]
        for key in ["smscode", "requestId"] {
            let marker = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
            guard let range = text.range(of: marker),
                  let end = text[range.upperBound...].range(of: "\r\n") else { return false }
            fields[key] = String(text[range.upperBound..<end.lowerBound])
        }
        guard let code = fields["smscode"], (try? AuthChannelInput.code(code)) == code,
              let requestID = fields["requestId"],
              !requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, requestID.count <= 64,
              let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: token, boundary: boundary) else { return false }
        return canonical.httpBody == body
    }

    /// Form body for apply. Returns false when the request is not that form shape.
    private static func acceptsApplyForm(_ request: URLRequest, baseURL: URL, token: String) -> Bool {
        if request.httpMethod == "POST",
           request.value(forHTTPHeaderField: "Content-Type") == AccountPublishMPContract.formContentType,
           let body = request.httpBody, body.count <= 1024,
           let text = String(data: body, encoding: .utf8) {
            var fields: [String: String] = [:]
            for pair in text.split(separator: "&", omittingEmptySubsequences: false) {
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2, fields[parts[0]] == nil else { return false }
                fields[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
            guard Set(fields.keys) == ["requestId", "smscode"],
                  let requestID = fields["requestId"], !requestID.isEmpty, requestID.count <= 64,
                  let code = fields["smscode"], (try? AuthChannelInput.code(code)) == code,
                  let contract = try? AccountPublishMPContract.deregisterApplyRequest(
                    baseURL: baseURL, requestID: requestID, smsCode: code, token: token),
                  contract.httpBody == body else { return false }
            return true
        }
        return false
    }

    private static func matchesContract(_ request: URLRequest, _ contract: URLRequest?) -> Bool {
        guard let contract else { return false }
        return request.httpMethod == contract.httpMethod
            && request.value(forHTTPHeaderField: "Content-Type") == contract.value(forHTTPHeaderField: "Content-Type")
            && request.httpBody == contract.httpBody
    }
}
