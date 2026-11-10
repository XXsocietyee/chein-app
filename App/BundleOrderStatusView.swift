import SwiftUI

/// Pure presentation mapping for the bundle order screens (IWP-2). No copy is hard-coded: every string is a key in
/// the `BundleCommerce` table (requested in docs/owner-plan/iwp-2-new-strings.md, added by the orchestrator).
enum BundleOrderStatusPresentation {
    static let table = "BundleCommerce"

    enum Banner: Equatable {
        case none
        /// Receipt polling is running (first read or a NOT_FOUND answer so far).
        case confirming
        /// Poll budget used up with NOT_FOUND only: still unconfirmed, NOT failed, NOT "nothing was created".
        case stillConfirming
        case failed
        /// The read itself could not be completed.
        case unavailable
    }

    static func banner(for state: BundleReceiptPollState) -> Banner {
        switch state {
        case .idle, .found: return .none
        case .polling: return .confirming
        case .stillUnconfirmed: return .stillConfirming
        case .failed: return .failed
        case .readUnavailable: return .unavailable
        }
    }

    static func bannerKey(_ banner: Banner) -> String? {
        switch banner {
        case .none: return nil
        case .confirming: return "order.receipt.confirming"
        case .stillConfirming: return "order.receipt.stillConfirming"
        case .failed: return "order.receipt.failed"
        case .unavailable: return "order.receipt.unavailable"
        }
    }

    static func activationKey(_ activation: BundleActivation) -> String {
        switch activation {
        case .pending: return "activation.pending"
        case .active: return "activation.active"
        case .expired: return "activation.expired"
        case .refunded: return "activation.refunded"
        case .unknown: return "activation.unknown"
        }
    }

    /// nil for an unknown server status: the view then shows the raw server string instead of inventing copy.
    static func reservationStatusKey(_ row: BundleReservationRow) -> String? {
        row.isKnownStatus ? "reservation.status.\(row.status)" : nil
    }

    static func unitStatusKey(_ row: BundleUnitRow) -> String? {
        row.isKnownStatus ? "unit.status.\(row.status)" : nil
    }

    static func unitStatusKey(_ status: String) -> String? {
        BundleStatusCatalog.knownUnitStatuses.contains(status) ? "unit.status.\(status)" : nil
    }
}

/// T-05. Real-data consumer only: it renders an injected server model and (optionally) a receipt poller.
/// Not mounted anywhere; no fixture or provider is installed here. It never shows a "paid" claim of its own:
/// the activation line is the server's status pair, mapped through `BundleOrderReadModel.activation`.
@MainActor struct BundleOrderStatusView: View {
    let order: BundleOrderReadModel?
    var poller: BundleReceiptPollerBinding?
    private let table = BundleOrderStatusPresentation.table
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    init(order: BundleOrderReadModel?, poller: BundleReceiptPoller? = nil) {
        self.order = order; self.poller = poller.map(BundleReceiptPollerBinding.init)
    }

    var body: some View {
        Form {
            if let poller {
                if let key = BundleOrderStatusPresentation.bannerKey(BundleOrderStatusPresentation.banner(for: poller.state)) {
                    Section {
                        text(key).accessibilityIdentifier("bundle.order.receiptBanner")
                        if poller.state == .stillUnconfirmed || poller.state == .readUnavailable {
                            CYPillButton("order.receipt.recheck", style: .secondary, tableName: table) { poller.poller.start() }
                        }
                    }
                }
            }
            if let order {
                Section {
                    LabeledContent { Text(verbatim: order.registrationId.text) } label: { text("order.number") }
                    if let number = order.registrationNo { Text(verbatim: number).textSelection(.enabled) }
                    if order.isLegacy {
                        text("order.legacy").accessibilityIdentifier("bundle.order.legacy")
                    } else {
                        LabeledContent { text(BundleOrderStatusPresentation.activationKey(order.activation)) } label: { text("order.status") }
                            .accessibilityIdentifier("bundle.order.activation")
                    }
                }
            }
        }
        .cyGroupedSurface()
        .onDisappear { poller?.poller.stop() }
    }
}

/// Lets a struct view observe the `@Observable` poller through a stable reference.
@MainActor struct BundleReceiptPollerBinding {
    let poller: BundleReceiptPoller
    init(_ poller: BundleReceiptPoller) { self.poller = poller }
    var state: BundleReceiptPollState { poller.state }
}
