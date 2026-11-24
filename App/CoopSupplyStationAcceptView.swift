import SwiftUI

/// MC7-30-6 / MP coop/list `supplyStationConfirmation`: accept on a station topic shows the frozen station, asks for a
/// confirm, then posts `api/coop/handle` with `supplyStationId` (`CoopFlowService.acceptSupplyStation`). The send goes
/// through the same TEST-only merchant-write gate as every other accept; where it is closed the button is disabled.
@MainActor struct CoopSupplyStationAcceptView: View {
    let inviteID: Int
    let stationID: Int
    let stationName: String?
    @Environment(\.coopFlowPreviewWrite) private var write
    @Environment(\.dismiss) private var dismiss
    private enum Outcome: Equatable { case idle, sending, sent, failed(String?), unknown }
    @State private var outcome: Outcome = .idle
    @State private var reason = ""
    @State private var confirming = false

    private var station: Text {
        if let stationName, !stationName.isEmpty { return Text(verbatim: stationName) }
        return Text("merchantCoop.station.fallback \(stationID)")
    }
    var body: some View {
        Form {
            Section {
                LabeledContent { station } label: { Text("merchantCoop.station.label") }
                    .accessibilityIdentifier("coopflow.stationAccept.station")
                Text("merchantCoop.station.note.beforeAccept").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            Section {
                TextField("merchantCoop.station.reasonPlaceholder", text: $reason, axis: .vertical)
                    .accessibilityIdentifier("coopflow.stationAccept.reason")
            }
            Section {
                switch outcome {
                case .sent:
                    Label("coopflow.submit.sent", systemImage: "checkmark.circle.fill").foregroundStyle(CYColor.successText)
                    Button("coopflow.submit.done") { dismiss() }
                case .unknown:
                    Label("coopflow.submit.unknown", systemImage: "questionmark.circle").foregroundStyle(CYColor.warningText)
                default:
                    if write?.stationAccept() != nil {
                        Button { confirming = true } label: {
                            HStack { Text("cooperation.detail.accept"); if outcome == .sending { Spacer(); ProgressView() } }
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .disabled(outcome == .sending)
                        .accessibilityIdentifier("coopflow.stationAccept.submit")
                        if case .failed(let message) = outcome {
                            Group { if let message { Text(verbatim: message) } else { Text("coopflow.submit.failed") } }
                                .cyText(.meta).foregroundStyle(CYColor.dangerText)
                        }
                    } else {
                        Button("cooperation.detail.accept") {}.disabled(true).accessibilityIdentifier("coopflow.stationAccept.disabled")
                        Text("coopflow.submit.gated").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
        }
        .navigationTitle(Text("merchantCoop.station.confirmTitle")).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(Text("merchantCoop.station.confirmTitle"), isPresented: $confirming, titleVisibility: .visible) {
            Button("cooperation.detail.accept") { Task { await submit() } }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("merchantCoop.station.note.beforeAccept")
        }
    }
    private func submit() async {
        guard outcome != .sending, let send = write?.stationAccept() else { return }
        outcome = .sending
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await send(inviteID, trimmed.isEmpty ? nil : trimmed, stationID)
            outcome = .sent
        } catch CoopFlowFailure.server(_, let message) { outcome = .failed(message) }
        catch CoopFlowFailure.inactiveMerchant(_, let message) { outcome = .failed(message) }
        catch CoopFlowFailure.ambiguous { outcome = .unknown }
        catch { outcome = .failed(nil) }
    }
}
