import Foundation
import Observation

// MARK: - Refund progress (IWP-R)
// Whole order only. Partial unit selection is rejected until the owner confirms it.
// The quote's route and amount are copied verbatim. Nothing here computes a price, ratio or refund.
// "Refunded" is only the server state REFUNDED. Processing, UNKNOWN, manual payout and approval are not cash arrival.

public struct BundleRefundApplyCommand: Equatable {
    public let registrationId: FreeExploreLaunchID
    public let unitIDs: [FreeExploreLaunchID]
    public let idempotencyKey: String
    public let expectedRoute: String
    public let expectedAmount: String

    /// A proposal is the whole order only when it is the same non-empty set. A subset is not a refund.
    public static func isWholeOrder(orderUnitIDs: [FreeExploreLaunchID], proposed: [FreeExploreLaunchID]) -> Bool {
        !orderUnitIDs.isEmpty && Set(orderUnitIDs) == Set(proposed)
    }

    public init(quote: FreeExploreLaunchRefundQuote, registrationId: FreeExploreLaunchID,
                orderUnitIDs: [FreeExploreLaunchID], proposedUnitIDs: [FreeExploreLaunchID],
                idempotencyKey: String) throws {
        guard Self.isWholeOrder(orderUnitIDs: orderUnitIDs, proposed: proposedUnitIDs) else { throw FreeExploreLaunchFailure.invalid }
        guard (1...64).contains(idempotencyKey.utf8.count),
              idempotencyKey.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }),
              !quote.route.isEmpty, quote.route.utf8.count <= 64,
              quote.route.utf8.allSatisfy({ $0 >= 0x20 && $0 < 0x7f }),
              !quote.amount.text.isEmpty else { throw FreeExploreLaunchFailure.invalid }
        self.registrationId = registrationId
        self.unitIDs = orderUnitIDs
        self.idempotencyKey = idempotencyKey
        self.expectedRoute = quote.route
        self.expectedAmount = quote.amount.text
    }
}

public struct BundleRefundProgressPresentation: Equatable {
    public let serverState: String
    public let refundNo: String?
    /// True only when the server state is exactly `REFUNDED`.
    public let showsRefunded: Bool
    public let titleZh: String
    public let titleEn: String

    public init(state: String, refundNo: String?) {
        serverState = state
        let trimmed = refundNo?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.refundNo = (trimmed?.isEmpty == false) ? trimmed : nil
        switch state {
        case "REFUNDED":
            showsRefunded = true
            titleZh = "已退款"
            titleEn = "Refunded"
        case "UNKNOWN":
            showsRefunded = false
            titleZh = "结果未知"
            titleEn = "Outcome unknown"
        case "MANUAL_PAYOUT", "MANUAL":
            showsRefunded = false
            titleZh = "人工处理中"
            titleEn = "Manual payout"
        case "REJECTED":
            showsRefunded = false
            titleZh = "未通过"
            titleEn = "Not approved"
        case "PROCESSING", "PENDING", "HELD", "REFUND_PENDING", "APPROVED":
            showsRefunded = false
            titleZh = "处理中"
            titleEn = "Processing"
        default:
            showsRefunded = false
            titleZh = "处理中"
            titleEn = "Processing"
        }
    }
}

@MainActor @Observable public final class BundleRefundProgressModel {
    public enum Phase: Equatable {
        case unavailable
        case ready
        case outcomeUnknown
        case progress(BundleRefundProgressPresentation)
    }

    public let expectedRoute: String
    public let expectedAmount: String
    public let canApply: Bool
    public private(set) var phase: Phase
    private let quote: FreeExploreLaunchRefundQuote
    private let client: (any BundleRefundServing)?
    private let registrationId: FreeExploreLaunchID
    private let orderUnitIDs: [FreeExploreLaunchID]
    private var sentKey: String?

    public init(quote: FreeExploreLaunchRefundQuote, registrationId: FreeExploreLaunchID,
                orderUnitIDs: [FreeExploreLaunchID], client: (any BundleRefundServing)? = nil) {
        self.quote = quote
        expectedRoute = quote.route
        expectedAmount = quote.amount.text
        self.registrationId = registrationId
        self.orderUnitIDs = orderUnitIDs
        self.client = client
        canApply = BundleMoneyWriteGate.allowsRefundApply && client?.permitsWrites == true
        phase = canApply ? .ready : .unavailable
    }

    /// Sends only when the money gate and the client both allow it. A closed gate does not touch the network.
    /// Unknown outcome keeps the same idempotency key and does not POST again.
    public func apply(idempotencyKey: String) async {
        guard canApply, sentKey == nil, phase != .outcomeUnknown, let client else { return }
        do {
            let command = try BundleRefundApplyCommand(quote: quote, registrationId: registrationId, orderUnitIDs: orderUnitIDs,
                                                        proposedUnitIDs: orderUnitIDs, idempotencyKey: idempotencyKey)
            sentKey = idempotencyKey
            phase = .progress(try await client.apply(command))
        } catch let failure as FreeExploreLaunchFailure {
            if case .outcomeUnknown = failure { phase = .outcomeUnknown; return }
            sentKey = nil
            phase = .unavailable
        } catch {
            phase = .outcomeUnknown
        }
    }

    /// Read-back only. Never POSTs.
    public func refresh() async {
        guard let client else { phase = .unavailable; return }
        do { phase = .progress(try await client.progress(registrationID: registrationId)) }
        catch let failure as FreeExploreLaunchFailure {
            if case .outcomeUnknown = failure { phase = .outcomeUnknown; return }
            phase = .unavailable
        } catch { phase = .outcomeUnknown }
    }
}
