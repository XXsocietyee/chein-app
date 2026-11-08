import Foundation

/// Pure presentation rules for the owner refund panel on pages/club/checkin-detail.
/// The panel (App/ClubOwnerRefundPanel.swift) asks this model which controls to show so
/// role gating (source `canRefund`, owner only) and gated-write states are unit-testable.
public struct ClubOwnerRefundPanelModel: Equatable {
    public let status: ClubOwnerRefundStatus
    public let sourceCanRefund: Bool
    public let coordinatorAvailable: Bool
    public let identityMatches: Bool
    public let canDispatch: Bool
    public init(status: ClubOwnerRefundStatus, sourceCanRefund: Bool, coordinatorAvailable: Bool, identityMatches: Bool, canDispatch: Bool) {
        self.status = status; self.sourceCanRefund = sourceCanRefund; self.coordinatorAvailable = coordinatorAvailable
        self.identityMatches = identityMatches; self.canDispatch = canDispatch
    }
    /// Members, non-owners and settled-nothing rows never see the panel.
    public var isVisible: Bool { sourceCanRefund || status.phase != .idle }
    public var showsLiveSection: Bool { coordinatorAvailable && identityMatches }
    public var showsReviewButton: Bool { showsLiveSection && sourceCanRefund && [.idle, .notSent].contains(status.phase) }
    public var reviewEnabled: Bool { !status.inFlight }
    public var showsReadbackButton: Bool {
        showsLiveSection && [.acknowledged, .manualReview, .outcomeUnknown, .refundRecorded].contains(status.phase)
    }
    public var showsNoReplayNote: Bool {
        showsLiveSection && (status.phase == .outcomeUnknown || status.phase == .refundRecorded)
    }
    /// Honest "not available yet" state while the production write grant is absent.
    public var showsNotAvailableNote: Bool { !showsLiveSection || !canDispatch }
    public var confirmEnabled: Bool { showsLiveSection && canDispatch && !status.inFlight }
}
