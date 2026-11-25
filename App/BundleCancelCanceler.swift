import Foundation

/// `FreeExploreReservationCanceling` over `BundleAPIClient` (IWP-1). Constructed only by composition (IWP-9)
/// under the same approval that gates reads; `FreeExploreCancelFactory.makeCanceler` is untouched, so
/// production keeps returning `.unavailable`.
///
/// Server is the authority: `expectedOutcome` is the quote's value verbatim, the outcome text is chosen from
/// the server's `outcome`, and free-cancel hours come from the server policy. Nothing is computed here.
/// An unknown POST outcome is `.unconfirmed` and is never re-sent; the caller reads the order back instead.
@MainActor final class BundleCancelCanceler: FreeExploreReservationCanceling {
    private let client: BundleAPIClient
    private let policy: () -> BundlePolicy?
    /// Set when the server answered BUNDLE_CANCEL_QUOTE_CHANGED; consumed by `confirm(on:)`.
    private(set) var quoteChangedPending = false

    init(client: BundleAPIClient, policy: @escaping () -> BundlePolicy? = { nil }) {
        self.client = client; self.policy = policy
    }

    func quote(reservationID: String, useWaiver: Bool) async -> FreeExploreCancelQuoteOutcome {
        guard let id = Self.id(reservationID) else { return .failed(message: "") }
        do {
            let quote = try await client.cancelQuote(reservationID: id, useWaiver: useWaiver)
            // A waiver outcome the user did not ask for is never offered for confirmation.
            if quote.expectedOutcome.hasPrefix("WAIVED"), !useWaiver { return .failed(message: "") }
            quoteChangedPending = false
            return .quote(FreeExploreCancelQuote(expectedOutcome: quote.expectedOutcome, canCancel: quote.canCancel,
                                                 message: message(for: quote)))
        } catch let failure as FreeExploreLaunchFailure {
            return failure == .disabled || failure == .cancellationQuoteUnavailable ? .unavailable : .failed(message: "")
        } catch {
            return .failed(message: "")
        }
    }

    func cancel(reservationID: String, useWaiver: Bool, expectedOutcome: String) async -> FreeExploreCancelOutcome {
        guard let id = Self.id(reservationID) else { return .rejected(message: "") }
        do {
            let reservation = try await client.cancel(reservationID: id, useWaiver: useWaiver, expectedOutcome: expectedOutcome)
            // Success only counts once the server reports a reservation that is no longer BOOKED.
            return reservation.status == "BOOKED" ? .unconfirmed : .cancelled(status: reservation.status)
        } catch let failure as FreeExploreLaunchFailure {
            switch failure {
            case .disabled, .staleSession: return .unavailable
            case .invalid: return .rejected(message: "")
            case .response(_, _, let code, _):
                switch code {
                case "BUNDLE_CANCEL_QUOTE_CHANGED":
                    quoteChangedPending = true
                    return .rejected(message: W8Text.t("取消条件已变化，请重新确认", "The cancellation terms changed. Please review them again."))
                case "BUNDLE_WAIVER_USED":
                    return .rejected(message: W8Text.t("本月豁免次数已用完", "This month's waiver has already been used."))
                case "LOGIN_REQUIRED":
                    return .rejected(message: W8Text.t("请先登录后再取消", "Please sign in before cancelling."))
                default: return .rejected(message: "")
                }
            default: return .unconfirmed
            }
        } catch let error as APIError where error == .unauthorized {
            return .rejected(message: W8Text.t("登录已过期，请重新登录", "Your session expired. Please sign in again."))
        } catch {
            return .unconfirmed
        }
    }

    /// Confirm, then, only if the server said the quote changed, fetch a NEW quote and stop at the
    /// confirmation step again. A changed quote is never confirmed automatically.
    func confirm(on model: FreeExploreCancelModel) async {
        guard case .awaitingConfirmation(let id, let waiver, _) = model.state else { return }
        quoteChangedPending = false
        await model.confirm()
        guard quoteChangedPending else { return }
        quoteChangedPending = false
        model.dismiss()
        await model.requestQuote(reservationID: id, useWaiver: waiver)
    }

    /// Read the order back (never re-POST) and let the model resolve "awaiting confirmation".
    func readBack(model: FreeExploreCancelModel, service: any FreeExploreLaunchServing,
                  registrationID: FreeExploreLaunchID, reservationID: String) async {
        guard let id = Self.id(reservationID),
              let order = try? await service.order(registrationID: registrationID),
              let row = order.bundle?.reservations.first(where: { $0.id == id }) else { return }
        model.resolveAfterReadback(reservationStatus: row.status)
    }

    private static func id(_ text: String) -> FreeExploreLaunchID? {
        guard let value = Int64(text), let id = try? FreeExploreLaunchID(value), id.text == text else { return nil }
        return id
    }

    /// Wording only; every figure shown comes from the server (quote outcome, policy hours).
    private func message(for quote: BundleCancelQuote) -> String {
        switch quote.outcome {
        case "CANCELLED":
            if let hours = policy()?.freeCancelHours {
                return W8Text.t("可免费取消（服务器规则：开始前 \(hours) 小时）", "Free cancellation (server rule: \(hours) hours before start).")
            }
            return W8Text.t("可免费取消", "Free cancellation.")
        case "LATE_CANCELLED":
            return W8Text.t("已过免费取消时间，本次将按迟到取消处理，不免费", "Past the free-cancel window. This counts as a late cancellation, not a free one.")
        case "WAIVED":
            return W8Text.t("将使用本月的豁免次数取消", "This will use this month's waiver.")
        default:
            return W8Text.t("服务器结果：\(quote.outcome)", "Server result: \(quote.outcome)")
        }
    }
}
