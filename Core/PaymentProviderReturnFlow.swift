import Foundation

public enum PaymentProviderReturnPhase: Equatable { case idle, checking, accepted, paid, failed, unknown, accessDenied }
/// Only server readback sets the result. This API intentionally takes no SDK success Boolean.
@MainActor public final class PaymentProviderReturnFlow: Identifiable {
    public let id = UUID()
    public let registrationID: Int
    public private(set) var phase: PaymentProviderReturnPhase = .idle
    public private(set) var detail: OrderLifecycleDetail?
    public var onChange: (() -> Void)?
    private let verifier: OrderPaymentVerifier
    private let currentScope: () -> UUID
    private let openedScope: UUID
    private var generation = 0
    private var retired = false
    public init(registrationID: Int, verifier: OrderPaymentVerifier, currentScope: @escaping () -> UUID) {
        self.registrationID = registrationID; self.verifier = verifier; self.currentScope = currentScope; openedScope = currentScope()
    }
    public var canClose: Bool { phase != .checking }
    public func reconcile() async {
        guard phase == .idle else { return }
        guard currentScope() == openedScope else {
            phase = .accessDenied; detail = nil; onChange?(); return
        }
        guard !retired, registrationID > 0, !Task.isCancelled else {
            phase = .unknown; detail = nil; onChange?(); return
        }
        generation += 1; let stamp = generation; phase = .checking; onChange?()
        let result = await verifier.verify(registrationID: registrationID)
        guard stamp == generation else { return }
        guard currentScope() == openedScope else { phase = .accessDenied; detail = nil; onChange?(); return }
        guard !Task.isCancelled else { phase = .unknown; onChange?(); return }
        switch result {
        case .observed(let observation, let value):
            detail = value
            switch observation {
            case .paid: phase = .paid
            case .registrationAccepted: phase = .accepted
            case .failed: phase = .failed
            default: phase = .unknown
            }
        case .unknown: phase = .unknown
        case .accessDenied: phase = .accessDenied
        }
        onChange?()
    }
    public func leave() { retired = true; generation += 1; verifier.abort(); detail = nil }
}
