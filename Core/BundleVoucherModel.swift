import Foundation

// MARK: - Voucher presentation model (IWP-5, T-07 / T-08)
// Polls the cheap version endpoint only while the screen is visible and refetches the full voucher only when
// `voucherVersion` differs from the one on screen. The model holds no storage dependency: the voucher lives in
// memory for the lifetime of the screen and is dropped on `disappear()`.

public enum BundleVoucherState: Equatable {
    case idle
    case loading
    case loaded(BundleVoucher)
    case failed
    case unavailable
}

/// What the redeem-result screen shows. Anything the app does not recognise is neutral "processing".
public enum BundleRedeemPresentation: Equatable {
    case success, review, rejected, notRedeemed, processing

    public init(_ outcome: BundleRedeemOutcome) {
        switch outcome {
        case .success: self = .success
        case .review: self = .review
        case .rejected: self = .rejected
        case .notRedeemed: self = .notRedeemed
        case .unknown: self = .processing
        }
    }
}

public enum BundleRedeemResultState: Equatable {
    case idle
    case loading
    case loaded(BundleRedeemPresentation, BundleRedeemResult)
    case failed
    case unavailable
}

@MainActor public final class BundleVoucherModel: ObservableObject {
    public static let minimumPollInterval: TimeInterval = 5
    public static let maximumPollInterval: TimeInterval = 60

    @Published public private(set) var state: BundleVoucherState = .idle
    @Published public private(set) var redeemState: BundleRedeemResultState = .idle
    public private(set) var isVisible = false
    public private(set) var consecutiveFailures = 0
    /// Seconds the next poll will wait (>= 5, server hint honoured, backoff on failure).
    public private(set) var currentInterval: TimeInterval = BundleVoucherModel.minimumPollInterval

    public let registrationID: String
    private let client: any BundleVoucherServing
    private let sleep: (TimeInterval) async throws -> Void
    private var generation: UInt64 = 0
    private var pollTask: Task<Void, Never>?

    public init(registrationID: String, client: any BundleVoucherServing = UnavailableBundleVoucherClient(),
                sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }) {
        self.registrationID = registrationID; self.client = client; self.sleep = sleep
    }

    private var loadedVoucher: BundleVoucher? {
        if case .loaded(let voucher) = state { return voucher }
        return nil
    }

    /// Screen became visible: load once, then poll until `disappear()`.
    public func appear() async {
        guard !isVisible else { return }
        isVisible = true
        generation &+= 1
        await loadVoucher()
        guard isVisible, state != .unavailable else { return }
        startPolling()
    }

    /// Screen left: stop polling and drop the in-memory voucher.
    public func disappear() {
        isVisible = false
        generation &+= 1
        pollTask?.cancel()
        pollTask = nil
        if state != .unavailable { state = .idle }
        redeemState = .idle
        consecutiveFailures = 0
        currentInterval = Self.minimumPollInterval
    }

    /// Manual refresh (pull to refresh / retry). No-op when hidden.
    public func reload() async {
        guard isVisible else { return }
        await loadVoucher()
    }

    private func loadVoucher() async {
        let epoch = generation
        if loadedVoucher == nil { state = .loading }
        let outcome = await client.voucher(registrationID: registrationID)
        guard isVisible, epoch == generation else { return }
        switch outcome {
        case .voucher(let voucher):
            state = .loaded(voucher)
            consecutiveFailures = 0
        case .failed:
            if loadedVoucher == nil { state = .failed }
            noteFailure()
        case .unavailable:
            state = .unavailable
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        let epoch = generation
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isVisible, epoch == self.generation else { return }
                do { try await self.sleep(self.currentInterval) } catch { return }
                guard !Task.isCancelled, self.isVisible, epoch == self.generation else { return }
                await self.pollOnce()
                if self.state == .unavailable { return }
            }
        }
    }

    /// One poll tick. Internal-visible for deterministic tests; the loop calls it after each sleep.
    func pollOnce() async {
        guard isVisible else { return }
        let epoch = generation
        let outcome = await client.version(registrationID: registrationID)
        guard isVisible, epoch == generation else { return }
        switch outcome {
        case .version(let version, let hint):
            consecutiveFailures = 0
            currentInterval = Self.clamp(hint ?? Self.minimumPollInterval)
            if loadedVoucher?.version != version { await loadVoucher() }
        case .failed:
            noteFailure()
        case .unavailable:
            state = .unavailable
        }
    }

    private func noteFailure() {
        consecutiveFailures += 1
        let exponent = Double(min(consecutiveFailures, 6))
        currentInterval = Self.clamp(Self.minimumPollInterval * pow(2, exponent))
    }

    private static func clamp(_ seconds: TimeInterval) -> TimeInterval {
        guard seconds.isFinite else { return minimumPollInterval }
        return min(max(seconds, minimumPollInterval), maximumPollInterval)
    }

    /// T-08 result for one unit. Unknown `outcome` strings land on `.processing`.
    public func loadRedeemResult(unitID: String) async {
        guard isVisible, !unitID.isEmpty else { return }
        let epoch = generation
        redeemState = .loading
        let outcome = await client.redeemResult(registrationID: registrationID, unitID: unitID)
        guard isVisible, epoch == generation else { return }
        switch outcome {
        case .result(let result): redeemState = .loaded(BundleRedeemPresentation(result.outcome), result)
        case .failed: redeemState = .failed
        case .unavailable: redeemState = .unavailable
        }
    }
}
