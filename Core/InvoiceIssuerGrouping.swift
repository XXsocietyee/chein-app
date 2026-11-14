import Foundation

/// Orders grouped by issuing entity so members clearly see which issuer each batch belongs to.
public struct InvoiceIssuerGroup: Equatable, Identifiable {
    public let issuerID: Int64?
    public let issuerTitle: String
    public let isEnabled: Bool
    public let orders: [InvoiceLaunchOrder]

    public var id: String {
        if let issuerID { return "issuer-\(issuerID)" }
        return "unassigned-\(issuerTitle)"
    }
}

/// Outcome of toggling selection on an invoiceable order across potentially different issuers.
public enum InvoiceIssuerSelectionOutcome: Equatable {
    case updated(Set<Int64>)
    case rejectedUnenabledIssuer(message: String)
    case rejectedMixedIssuers(message: String)
}

/// Enforces the mini-program `invoice-apply` rules: orders without an active issuer cannot be
/// selected, and a single application cannot span orders from multiple issuers.
public enum InvoiceIssuerSelectionGuard {
    public static let unenabledIssuerMessage = "开票单位开通后可申请"
    public static let mixedIssuersMessage = "不同开票单位需分开申请"

    /// Groups eligible orders preserving input order within each issuer group.
    public static func group(orders: [InvoiceLaunchOrder]) -> [InvoiceIssuerGroup] {
        var bucketOrder: [String] = []
        var buckets: [String: (id: Int64?, name: String, enabled: Bool, items: [InvoiceLaunchOrder])] = [:]

        for order in orders {
            let trimmed = order.issuerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let enabled = (order.issuerId ?? 0) > 0
            let displayName = trimmed.isEmpty ? (enabled ? "开票单位 #\(order.issuerId ?? 0)" : unenabledIssuerMessage) : trimmed
            let key = order.issuerId.map { "id:\($0)" } ?? "name:\(displayName)"
            if var existing = buckets[key] {
                existing.items.append(order)
                buckets[key] = existing
            } else {
                bucketOrder.append(key)
                buckets[key] = (order.issuerId, displayName, enabled, [order])
            }
        }

        return bucketOrder.compactMap { key in
            guard let entry = buckets[key] else { return nil }
            return InvoiceIssuerGroup(issuerID: entry.id, issuerTitle: entry.name, isEnabled: entry.enabled, orders: entry.items)
        }
    }

    /// Toggles selection for `order` against `currentlySelected` orders in `allOrders`.
    public static func toggle(
        order: InvoiceLaunchOrder,
        in allOrders: [InvoiceLaunchOrder],
        currentlySelected: Set<Int64>
    ) -> InvoiceIssuerSelectionOutcome {
        if currentlySelected.contains(order.orderId) {
            var next = currentlySelected
            next.remove(order.orderId)
            return .updated(next)
        }

        guard let issuerID = order.issuerId, issuerID > 0 else {
            return .rejectedUnenabledIssuer(message: unenabledIssuerMessage)
        }

        let selectedOrders = allOrders.filter { currentlySelected.contains($0.orderId) }
        if let activeIssuer = selectedOrders.compactMap(\.issuerId).first, activeIssuer != issuerID {
            return .rejectedMixedIssuers(message: mixedIssuersMessage)
        }

        var next = currentlySelected
        next.insert(order.orderId)
        return .updated(next)
    }
}
