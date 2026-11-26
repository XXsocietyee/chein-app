import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Appeal and dispute ride the reports grant. Sync, settle, and recovery admit the MP body. Purchase and payout do not.
enum OrientScoreReviewLease {
    static let appeal = "api/orient/scoring/appeal"
    static let dispute = "api/orient/scoring/dispute"
    static let receipt = "api/orient/scoring/receipt"
}

extension ReviewedProductionFormMutationRoute {
    /// Nil when this request is not an orient score review. Sync, settle, and recovery
    /// send only the MP body. Purchase and payout stay closed.
    static func orientScoreReviewDecision(_ request: URLRequest, relative: String, reports: OperationEndpointApproval) -> Bool? {
        if relative.hasPrefix("api/orient/scoring/session/") && (relative.hasSuffix("/sync") || relative.hasSuffix("/settle")) {
            return scoreSessionWrite(request, relative: relative)
        }
        if relative.hasPrefix("api/orient/scoring/session/") && relative.hasSuffix("/recovery") {
            return scoreRecoveryWrite(request, relative: relative)
        }
        if relative == OrientScoreReviewLease.receipt {
            guard covers(OrientScoreReviewLease.appeal, reports), covers(OrientScoreReviewLease.dispute, reports) else { return false }
            return receiptRead(request)
        }
        if relative == OrientScoreReviewLease.appeal || relative == OrientScoreReviewLease.dispute {
            guard covers(relative, reports) else { return false }
            return reviewBody(request, appeal: relative == OrientScoreReviewLease.appeal)
        }
        return nil
    }

    private static func reviewBody(_ request: URLRequest, appeal: Bool) -> Bool {
        guard request.httpMethod == "POST", request.url?.query == nil,
              request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8",
              let body = request.httpBody, let text = String(data: body, encoding: .utf8),
              let fields = formFields(text) else { return false }
        let money = ["payChannel", "payAmount", "price", "amount", "payableAmount"]
        guard money.allSatisfy({ fields[$0] == nil }) else { return false }
        guard reviewKey(fields["idempotencyKey"]), positive(fields["sessionId"]),
              let reason = fields["reason"], (try? OrientSessionScoreReason.normalized(reason)) == reason else { return false }
        let allowed: Set<String>
        if appeal {
            let entry = positive(fields["entryId"])
            let node = positive(fields["nodeId"])
            guard entry || node else { return false }
            allowed = ["idempotencyKey", "sessionId", "reason", "entryId", "nodeId"]
        } else {
            guard fields["entryId"] == nil, fields["nodeId"] == nil else { return false }
            allowed = ["idempotencyKey", "sessionId", "reason"]
        }
        return Set(fields.keys).isSubset(of: allowed)
    }

    /// POST sync or settle. Body is exactly `idempotencyKey` and `sessionId` (`orient-score/index.js` `write`).
    private static func scoreSessionWrite(_ request: URLRequest, relative: String) -> Bool {
        guard request.httpMethod == "POST", request.url?.query == nil,
              request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8",
              let body = request.httpBody, let text = String(data: body, encoding: .utf8),
              let fields = formFields(text) else { return false }
        let money = ["payChannel", "payAmount", "price", "amount", "payableAmount"]
        guard money.allSatisfy({ fields[$0] == nil }),
              Set(fields.keys) == ["idempotencyKey", "sessionId"],
              reviewKey(fields["idempotencyKey"]), positive(fields["sessionId"]),
              let session = fields["sessionId"] else { return false }
        return relative == "api/orient/scoring/session/\(session)/sync"
            || relative == "api/orient/scoring/session/\(session)/settle"
    }

    /// POST recovery. Body is exactly `kind` (`orient-score/index.js` `requestManualReview`).
    private static func scoreRecoveryWrite(_ request: URLRequest, relative: String) -> Bool {
        guard request.httpMethod == "POST", request.url?.query == nil,
              request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8",
              let body = request.httpBody, let text = String(data: body, encoding: .utf8),
              let fields = formFields(text), Set(fields.keys) == ["kind"],
              let kind = fields["kind"], ["SYNC", "SETTLE", "APPEAL", "DISPUTE"].contains(kind) else { return false }
        let prefix = "api/orient/scoring/session/"
        let suffix = "/recovery"
        guard relative.hasPrefix(prefix), relative.hasSuffix(suffix) else { return false }
        let session = String(relative.dropFirst(prefix.count).dropLast(suffix.count))
        return positive(session)
    }

    private static func receiptRead(_ request: URLRequest) -> Bool {
        guard request.httpMethod == "GET", request.httpBody == nil || request.httpBody?.isEmpty == true,
              request.value(forHTTPHeaderField: "Content-Type") == nil,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              let url = request.url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = parts.queryItems, items.count == 3 else { return false }
        let names = items.map(\.name)
        guard Set(names).count == names.count else { return false }
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        guard values.count == 3, reviewKey(values["idempotencyKey"]), positive(values["sessionId"]),
              ["SYNC", "SETTLE", "APPEAL", "DISPUTE"].contains(values["kind"] ?? "") else { return false }
        return true
    }

    private static func formFields(_ text: String) -> [String: String]? {
        guard !text.isEmpty else { return nil }
        var fields: [String: String] = [:]
        for part in text.split(separator: "&", omittingEmptySubsequences: false) {
            let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2,
                  let key = String(pieces[0]).removingPercentEncoding,
                  let value = String(pieces[1]).removingPercentEncoding,
                  !key.isEmpty, fields[key] == nil else { return nil }
            fields[key] = value
        }
        return fields.isEmpty ? nil : fields
    }

    private static func reviewKey(_ value: String?) -> Bool {
        guard let value, (1...96).contains(value.utf8.count) else { return false }
        return value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [95, 46, 58, 45].contains($0)
        }
    }

    private static func positive(_ value: String?) -> Bool {
        guard let value, let number = Int(value), number > 0, String(number) == value else { return false }
        return true
    }
}
