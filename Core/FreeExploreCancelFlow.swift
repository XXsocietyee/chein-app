import Foundation

// MARK: - Free-explore reservation cancel (quote -> confirm -> cancel), injected and gated by default
// Request shapes match subpackageMember/free-explore/index.js:
//   GET  /api/free-explore/bundle/reservation/{id}/cancel-quote  { useWaiver }
//   POST /api/free-explore/bundle/reservation/{id}/cancel        { useWaiver, expectedOutcome }
// `expectedOutcome` is always the server quote's value, never computed by the client. A cancel is only
// shown as cancelled after the server answers with a non-BOOKED reservation; anything ambiguous stays
// "awaiting confirmation" and keeps the original choice. No refund or payment is executed client-side.

public struct FreeExploreCancelQuote: Equatable {
    public let expectedOutcome: String
    public let canCancel: Bool
    public let message: String

    public init(expectedOutcome: String, canCancel: Bool, message: String) {
        self.expectedOutcome = expectedOutcome
        self.canCancel = canCancel
        self.message = message
    }
}

public enum FreeExploreCancelQuoteOutcome: Equatable {
    case quote(FreeExploreCancelQuote)
    case failed(message: String)
    case unavailable
}

public enum FreeExploreCancelOutcome: Equatable {
    /// Server answered success with a reservation whose status is no longer BOOKED.
    case cancelled(status: String)
    /// Server refused with one of the definite business codes (waiver used, quote changed, ...).
    case rejected(message: String)
    /// Network error or malformed/ambiguous answer.
    case unconfirmed
    case unavailable
}

@MainActor public protocol FreeExploreReservationCanceling {
    func quote(reservationID: String, useWaiver: Bool) async -> FreeExploreCancelQuoteOutcome
    func cancel(reservationID: String, useWaiver: Bool, expectedOutcome: String) async -> FreeExploreCancelOutcome
}

public struct GatedFreeExploreReservationCanceler: FreeExploreReservationCanceling {
    public init() {}
    public func quote(reservationID: String, useWaiver: Bool) async -> FreeExploreCancelQuoteOutcome { .unavailable }
    public func cancel(reservationID: String, useWaiver: Bool, expectedOutcome: String) async -> FreeExploreCancelOutcome { .unavailable }
}

public enum FreeExploreCancelState: Equatable {
    case idle
    case quoting
    case awaitingConfirmation(reservationID: String, useWaiver: Bool, quote: FreeExploreCancelQuote)
    case cancelling
    case cancelled(status: String)
    case failed(String)
    case awaitingServerConfirmation
    case unavailable
}

@MainActor public final class FreeExploreCancelModel: ObservableObject {
    @Published public private(set) var state: FreeExploreCancelState = .idle
    private let canceler: FreeExploreReservationCanceling

    public init(canceler: FreeExploreReservationCanceling) { self.canceler = canceler }

    public func requestQuote(reservationID: String, useWaiver: Bool) async {
        switch state {
        case .quoting, .cancelling, .awaitingServerConfirmation: return
        default: break
        }
        guard !reservationID.isEmpty else { state = .failed(W8Text.t("预约编号无效", "Invalid reservation")); return }
        state = .quoting
        switch await canceler.quote(reservationID: reservationID, useWaiver: useWaiver) {
        case .quote(let quote):
            state = quote.canCancel
                ? .awaitingConfirmation(reservationID: reservationID, useWaiver: useWaiver, quote: quote)
                : .failed(W8Text.t("当前不可取消，请刷新预约状态", "This reservation can't be canceled right now. Refresh its status."))
        case .failed(let message):
            state = .failed(message.isEmpty ? W8Text.t("取消试算失败，未发送取消", "Could not get a cancellation quote. Nothing was canceled.") : message)
        case .unavailable:
            state = .unavailable
        }
    }

    public func confirm() async {
        guard case .awaitingConfirmation(let id, let waiver, let quote) = state else { return }
        state = .cancelling
        switch await canceler.cancel(reservationID: id, useWaiver: waiver, expectedOutcome: quote.expectedOutcome) {
        case .cancelled(let status): state = .cancelled(status: status)
        case .rejected(let message):
            state = .failed(message.isEmpty ? W8Text.t("取消被拒绝，请重新确认", "The cancellation was refused. Review it again.") : message)
        case .unconfirmed: state = .awaitingServerConfirmation
        case .unavailable: state = .unavailable
        }
    }

    public func dismiss() {
        switch state {
        case .quoting, .cancelling, .awaitingServerConfirmation: return
        default: state = .idle
        }
    }

    /// Call after the host re-read the order and found the reservation resolved (or still BOOKED).
    public func resolveAfterReadback(reservationStatus: String) {
        guard state == .awaitingServerConfirmation else { return }
        state = reservationStatus == "BOOKED" ? .idle : .cancelled(status: reservationStatus)
    }
}
