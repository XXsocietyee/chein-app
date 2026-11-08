import Foundation
import Observation

// MARK: - Bundle order read model (IWP-2; wires nothing)
// View-model over `BundleOrderView` (IWP-0 richer decode) or the thinner `FreeExploreLaunchOrder`.
// Everything shown is a server value: activation is derived only from the server's status ints and
// server-provided flags, balance counts are copied from `BundleBalance.counts`, reservation rows keep the
// server's order. No price / refund / threshold / clock arithmetic lives here. The client never decides "paid":
// `.active` means the server reported its own paid+registered pair (2/2), nothing more.

public enum BundleActivation: Equatable {
    /// Server reported a status pair that is not the active pair (no client interpretation beyond that).
    case pending
    case active
    /// Every balance row carries the server's `expired == true`.
    case expired
    /// Every unit carries the server status `REFUNDED`.
    case refunded
    /// Status ints missing from the response.
    case unknown
}

public struct BundleBalanceRow: Equatable {
    public let grantId: FreeExploreLaunchID
    public let chapterId: FreeExploreLaunchID
    public let grantNo: Int
    public let grantType: String
    public let unitsTotal: Int
    /// Verbatim server counts keyed by unit status; rendered, never recomputed from `units`.
    public let counts: [String: Int]
    /// Server-side display text (raw) plus parsed epoch when available.
    public let validFrom: BundleTimestamp
    public let validTo: BundleTimestamp
    public let expired: Bool
    /// Count keys in a stable display order: known statuses first (catalog order), then unknown keys sorted.
    public var orderedCountKeys: [String] {
        let known = ["AVAILABLE", "RESERVED", "REDEEMED", "FORFEITED", "HELD", "REFUND_PENDING", "REFUNDED"]
        let present = known.filter { counts[$0] != nil }
        let unknown = counts.keys.filter { !known.contains($0) }.sorted()
        return present + unknown
    }
}

public struct BundleReservationRow: Equatable {
    public let id: FreeExploreLaunchID
    public let unitId: FreeExploreLaunchID
    public let chapterId: FreeExploreLaunchID
    public let offerId: FreeExploreLaunchID
    public let merchantId: FreeExploreLaunchID
    /// Server string, shown as-is.
    public let startAt: String
    /// Unknown statuses stay readable; `isKnownStatus` only decides whether localized copy exists.
    public let status: String
    public var isKnownStatus: Bool { BundleStatusCatalog.knownReservationStatuses.contains(status) }
}

public struct BundleUnitRow: Equatable {
    public let id: FreeExploreLaunchID
    public let chapterId: FreeExploreLaunchID
    public let status: String
    /// Only present when the richer `BundleUnit` decode was available.
    public let unitCode: String?
    public let validFrom: BundleTimestamp?
    public let validTo: BundleTimestamp?
    public var isKnownStatus: Bool { BundleStatusCatalog.knownUnitStatuses.contains(status) }
}

public struct BundleOrderReadModel: Equatable {
    public let registrationId: FreeExploreLaunchID
    public let registrationNo: String?
    public let paymentStatus: Int?
    public let registrationStatus: Int?
    /// `bundle == nil` on the server: render the existing non-bundle path.
    public let isLegacy: Bool
    public let activation: BundleActivation
    public let balances: [BundleBalanceRow]
    public let units: [BundleUnitRow]
    /// Server order preserved verbatim (the server returns them ordered by start time); never re-sorted here.
    public let reservations: [BundleReservationRow]
    /// Server-provided policy display values (nil for the thin order decode).
    public let policyVersion: String?
    public let freeCancelHours: Int?
    /// False when only the thin `FreeExploreLaunchOrder` was available (no balances/validity window).
    public let hasBalanceDetail: Bool

    public init(view: BundleOrderView) {
        registrationId = view.registrationId
        registrationNo = view.registrationNo
        paymentStatus = view.paymentStatus
        registrationStatus = view.registrationStatus
        guard let bundle = view.bundle else {
            isLegacy = true; balances = []; units = []; reservations = []
            policyVersion = nil; freeCancelHours = nil; hasBalanceDetail = false
            activation = Self.activation(payment: view.paymentStatus, registration: view.registrationStatus,
                                         balances: [], unitStatuses: [])
            return
        }
        isLegacy = false
        balances = bundle.balances.map {
            BundleBalanceRow(grantId: $0.grantId, chapterId: $0.chapterId, grantNo: $0.grantNo, grantType: $0.grantType,
                             unitsTotal: $0.unitsTotal, counts: $0.counts, validFrom: $0.validFrom,
                             validTo: $0.validTo, expired: $0.expired)
        }
        units = bundle.units.map {
            BundleUnitRow(id: $0.id, chapterId: $0.chapterId, status: $0.status, unitCode: $0.unitCode,
                          validFrom: $0.validFrom, validTo: $0.validTo)
        }
        reservations = bundle.reservations.map(Self.row)
        policyVersion = bundle.policy.version
        freeCancelHours = bundle.policy.freeCancelHours
        hasBalanceDetail = true
        activation = Self.activation(payment: view.paymentStatus, registration: view.registrationStatus,
                                     balances: bundle.balances.map(\.expired), unitStatuses: bundle.units.map(\.status))
    }

    /// Thin fallback from the existing `FreeExploreLaunchService.order` decode (per-order host entry).
    public init(order: FreeExploreLaunchOrder) {
        registrationId = order.registrationId
        registrationNo = order.registrationNo
        paymentStatus = order.paymentStatus
        registrationStatus = order.registrationStatus
        balances = []; policyVersion = nil; freeCancelHours = nil; hasBalanceDetail = false
        guard let bundle = order.bundle else {
            isLegacy = true; units = []; reservations = []
            activation = Self.activation(payment: order.paymentStatus, registration: order.registrationStatus,
                                         balances: [], unitStatuses: [])
            return
        }
        isLegacy = false
        units = bundle.units.map {
            BundleUnitRow(id: $0.id, chapterId: $0.chapterId, status: $0.status, unitCode: nil, validFrom: nil, validTo: nil)
        }
        reservations = bundle.reservations.map(Self.row)
        activation = Self.activation(payment: order.paymentStatus, registration: order.registrationStatus,
                                     balances: [], unitStatuses: bundle.units.map(\.status))
    }

    private static func row(_ r: FreeExploreLaunchReservation) -> BundleReservationRow {
        BundleReservationRow(id: r.id, unitId: r.unitId, chapterId: r.chapterId, offerId: r.offerId,
                             merchantId: r.merchantId, startAt: r.startAt, status: r.status)
    }

    /// Derived ONLY from server values: the two status ints, server `expired` flags and server unit statuses.
    /// There is no device-clock comparison and no money logic.
    static func activation(payment: Int?, registration: Int?, balances: [Bool], unitStatuses: [String]) -> BundleActivation {
        guard let payment, let registration else { return .unknown }
        guard payment == 2, registration == 2 else { return .pending }
        if !unitStatuses.isEmpty, unitStatuses.allSatisfy({ $0 == "REFUNDED" }) { return .refunded }
        if !balances.isEmpty, balances.allSatisfy({ $0 }) { return .expired }
        return .active
    }
}

// MARK: - Receipt polling (recovery for an UNKNOWN order create)

public enum BundleReceiptPollState: Equatable {
    case idle
    /// `attempt` counts reads already made (>= 1 while waiting for the next one).
    case polling(attempt: Int)
    case found(BundleOrderReadModel)
    /// Retry budget used up with only NOT_FOUND answers. NOT a failure and NOT proof that nothing was written:
    /// the screen keeps saying "still confirming" and offers a manual re-check.
    case stillUnconfirmed
    /// The read itself could not be completed (transport / auth error); says nothing about the order.
    case readUnavailable
    /// Definite non-retryable answer (stale session, login required, malformed, ...).
    case failed(FreeExploreLaunchFailure)
}

/// Reads `order/receipt` with the ORIGINAL request id until the server says FOUND. It has no write capability
/// (it is given only a read closure), so it can never create or re-create an order.
@MainActor @Observable public final class BundleReceiptPoller {
    public typealias Fetch = (String) async throws -> BundleOrderReceipt
    public typealias Sleep = (UInt64) async throws -> Void
    public private(set) var state: BundleReceiptPollState = .idle
    public let requestId: String
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private let sleep: Sleep
    @ObservationIgnored private let delaysNanoseconds: [UInt64]
    @ObservationIgnored private var task: Task<Void, Never>?

    /// `delaysNanoseconds` is the backoff schedule between reads (one entry per retry); its length bounds retries.
    /// Both the schedule and the sleeper are injected so tests never use the real clock.
    public init(requestId: String, delaysNanoseconds: [UInt64] = [2_000_000_000, 4_000_000_000, 8_000_000_000, 16_000_000_000, 30_000_000_000],
                fetch: @escaping Fetch, sleep: @escaping Sleep = { try await Task.sleep(nanoseconds: $0) }) {
        self.requestId = requestId; self.delaysNanoseconds = delaysNanoseconds
        self.fetch = fetch; self.sleep = sleep
    }

    public var isRunning: Bool { task != nil }

    /// Starts (or restarts after `.stillUnconfirmed`) polling. No-op while already running or after FOUND.
    public func start() {
        guard task == nil else { return }
        if case .found = state { return }
        task = Task { @MainActor [weak self] in
            await self?.run()
            self?.task = nil
        }
    }

    /// Cancels in-flight work (view disappeared). A cancelled poll leaves `state` untouched.
    public func stop() { task?.cancel(); task = nil }

    /// Runs the loop to completion; exposed so tests can await it deterministically.
    public func run() async {
        var attempt = 0
        while true {
            attempt += 1
            state = .polling(attempt: attempt)
            do {
                let receipt = try await fetch(requestId)
                switch receipt.receipt {
                case .found:
                    guard let order = receipt.order else { state = .failed(.malformed); return }
                    state = .found(BundleOrderReadModel(view: order)); return
                case .notFound:
                    break // keep polling; NOT_FOUND is a negative read, never a failure
                }
            } catch is CancellationError {
                return
            } catch let failure as FreeExploreLaunchFailure {
                switch failure {
                case .outcomeUnknown, .busy: break // transient: treat like NOT_FOUND
                default: state = .failed(failure); return
                }
            } catch {
                // Transport / auth errors are not an answer about the order: stop and let the UI offer a manual re-check.
                state = .readUnavailable; return
            }
            guard attempt <= delaysNanoseconds.count else { state = .stillUnconfirmed; return }
            do { try await sleep(delaysNanoseconds[attempt - 1]) } catch { return }
        }
    }
}
