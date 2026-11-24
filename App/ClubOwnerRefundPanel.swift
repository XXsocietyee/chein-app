import SwiftUI

private struct ClubOwnerRefundCoordinatorKey: EnvironmentKey {
    static let defaultValue: ClubOwnerRefundCoordinator? = nil
}
extension EnvironmentValues {
    var clubOwnerRefundCoordinator: ClubOwnerRefundCoordinator? {
        get { self[ClubOwnerRefundCoordinatorKey.self] }
        set { self[ClubOwnerRefundCoordinatorKey.self] = newValue }
    }
}
@MainActor struct ClubOwnerRefundPanel: View {
    let target: ClubOwnerRefundTarget
    let identity: ClubReadIdentity?
    let sourceCanRefund: Bool
    let onReadback: () -> Void
    @Environment(\.clubOwnerRefundCoordinator) private var coordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var review: ClubOwnerRefundReview?
    @State private var failure: ClubOwnerRefundFailure?
    @State private var ownerID = UUID()
    private var status: ClubOwnerRefundStatus { coordinator?.state(target) ?? .init() }
    private var model: ClubOwnerRefundPanelModel {
        ClubOwnerRefundPanelModel(status: status, sourceCanRefund: sourceCanRefund, coordinatorAvailable: coordinator != nil,
            identityMatches: coordinator != nil && coordinator?.identity == identity, canDispatch: coordinator?.canDispatch == true)
    }
    var body: some View {
        if model.isVisible {
            VStack(alignment: .leading, spacing: 12) {
                Text("club.refund.title").cyText(.cardTitle).accessibilityIdentifier("club.refund.panel")
                if let coordinator, coordinator.identity == identity {
                    Text(LocalizedStringKey("club.refund.phase." + status.phase.rawValue))
                        .accessibilityIdentifier("club.refund.phase")
                    if status.inFlight { ProgressView("club.refund.working") }
                    if let receipt = status.receipt { receiptRows(receipt) }
                    if model.showsNoReplayNote {
                        Text("club.refund.noReplay").cyText(.bodyCompact)
                    }
                    if status.readbackUnavailable { Text("club.refund.readbackUnavailable").accessibilityIdentifier("club.refund.readbackUnavailable") }
                    if let failure = failure ?? status.failure {
                        Text(LocalizedStringKey(failure.localizationKey)).foregroundStyle(.secondary)
                        if let message = failure.message { fact("club.refund.serverMessage", message) }
                    }
                    if model.showsReviewButton {
                        Button("club.refund.review") { Task { await prepare(coordinator) } }
                            .disabled(!model.reviewEnabled).accessibilityIdentifier("club.refund.review")
                    }
                    if model.showsReadbackButton {
                        Button("club.refund.readback") {
                            Task { await coordinator.reconcile(target); if coordinator.identity == identity { onReadback() } }
                        }.disabled(status.inFlight).accessibilityIdentifier("club.refund.readback")
                    }
                    if !coordinator.canDispatch { Text("club.refund.disabled").cyText(.bodyCompact).accessibilityIdentifier("club.refund.disabled") }
                } else { Text("club.refund.disabled").cyText(.bodyCompact) }
                Text("club.refund.policy").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
            .sheet(item: $review, onDismiss: cancelPending) { pending in
                CYSheetContainer(
                    title: appLocalized("club.refund.question", locale: locale),
                    onClose: status.inFlight ? nil : {
                        coordinator?.cancel(pending)
                        review = nil
                    }
                ) {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYCard {
                            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                factRow("club.refund.player", pending.evidence.displayName)
                                factRow("club.refund.topic", pending.evidence.topicName)
                                factRow("club.refund.ticket", pending.evidence.ticketText)
                                factRow("club.refund.order", pending.evidence.orderNo)
                                factRow("club.refund.paid", pending.evidence.paidAmountText)
                            }
                        }

                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text("club.refund.scopeWarning")
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            refundConsequenceRow("arrow.uturn.backward.circle", "club.refund.consequence1")
                            refundConsequenceRow("ticket", "club.refund.consequence2")
                            refundConsequenceRow("exclamationmark.triangle", "club.refund.consequence3")
                        }

                        if coordinator?.canDispatchOffline == true {
                            CYNoteBanner(text: Text("club.refund.synthetic"), symbol: "info.circle", tone: .info)
                        } else if coordinator?.canDispatch != true {
                            CYNoteBanner(text: Text("club.refund.disabled"), symbol: "lock", tone: .warning)
                        }

                        if status.inFlight {
                            ProgressView("club.refund.working")
                                .frame(maxWidth: .infinity)
                        }

                        VStack(spacing: CYSpacing.sm) {
                            Button("club.refund.confirm") {
                                guard let coordinator else { return }
                                Task {
                                    await coordinator.confirm(pending)
                                    review = nil
                                    if coordinator.identity == identity { onReadback() }
                                }
                            }
                            .buttonStyle(CYDestructiveButtonStyle())
                            .disabled(!model.confirmEnabled)
                            .accessibilityIdentifier("club.refund.confirm")

                            Button("club.refund.cancel") {
                                coordinator?.cancel(pending)
                                review = nil
                            }
                            .buttonStyle(CYSecondaryButtonStyle())
                            .disabled(status.inFlight)
                            .accessibilityIdentifier("club.refund.cancel")
                        }
                    }
                }
                .cyDomainSheet(detents: [.half, .full])
                .interactiveDismissDisabled(status.inFlight)
            }
            .onChange(of: identity) { _, _ in coordinator?.leave(ownerID: ownerID); review = nil; failure = nil }
            .onDisappear { coordinator?.leave(ownerID: ownerID) }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { coordinator?.leave(ownerID: ownerID); review = nil; failure = nil }
            }
        }
    }
    private func cancelPending() { coordinator?.leave(ownerID: ownerID) }
    private func prepare(_ coordinator: ClubOwnerRefundCoordinator) async {
        failure = nil
        do {
            let pending = try await coordinator.prepare(target, ownerID: ownerID)
            guard coordinator.identity == identity, !Task.isCancelled else { coordinator.cancel(pending); return }
            review = pending
        } catch { if coordinator.identity == identity { failure = error as? ClubOwnerRefundFailure ?? .unknown } }
    }
    private func fact(_ title: LocalizedStringKey, _ value: String?) -> some View {
        LabeledContent(title) { if let value { Text(verbatim: value) } else { Text("club.refund.unknownValue") } }
    }
    private func factRow(_ title: LocalizedStringKey, _ value: String?) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Text(title)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
            Spacer(minLength: CYSpacing.sm)
            if let value {
                Text(verbatim: value)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("club.refund.unknownValue")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textTertiary)
            }
        }
    }
    private func refundConsequenceRow(_ systemImage: String, _ key: String.LocalizationValue) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: systemImage)
                .cyText(.label)
                .foregroundStyle(CYColor.dangerText)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(verbatim: appLocalized(key, locale: locale))
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private func receiptRows(_ receipt: ClubOwnerRefundReceipt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            receiptStatus("club.refund.cancellation", value: "club.refund.cancellation." + receipt.cancellation.rawValue)
                .accessibilityIdentifier("club.refund.receipt")
            receiptStatus("club.refund.cash", value: "club.refund.cash." + receipt.cash.rawValue)
                .accessibilityIdentifier("club.refund.cashStatus")
            receiptStatus("club.refund.points", value: "club.refund.points." + receipt.points.rawValue)
                .accessibilityIdentifier("club.refund.pointsStatus")
            if let message = receipt.message { Text(verbatim: message) }
            if receipt.scope == "PARENT_ORDER" { Text("club.refund.parentOrder") }
        }
    }
    private func receiptStatus(_ title: LocalizedStringKey, value: String) -> some View {
        LabeledContent(title) { Text(LocalizedStringKey(value)) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(LocalizedStringKey(value)))
    }

}
