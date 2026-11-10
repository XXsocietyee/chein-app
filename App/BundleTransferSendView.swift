import SwiftUI

/// IWP-8c sender screen. Unmounted: no route, entry, lease or composition references it.
/// The one-time code is shown from the model's in-memory value only; this view keeps no copy of it
/// (no @State / @SceneStorage / @AppStorage), and leaving the screen asks the model to discard it.
@MainActor struct BundleTransferSendView: View {
    @ObservedObject var model: BundleTransferSendModel
    let registrationID: FreeExploreLaunchID
    @State private var phone = ""
    @State private var channel: BundleTransferChannel = .inApp
    @State private var confirming = false
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        Form {
            switch model.phase {
            case .idle, .loadingPreview:
                CYLoadingStateView(rows: 2).accessibilityLabel(text("transfer.loading"))
            case .unavailable:
                text("transfer.unavailable").accessibilityIdentifier("bundleTransfer.unavailable")
            case .ineligible:
                text("transfer.ineligible").accessibilityIdentifier("bundleTransfer.ineligible")
            case .ready(let preview):
                Section {
                    // Impact text is the server's; nothing is computed or paraphrased here.
                    ForEach(preview.impactLines, id: \.self) { line in Text(verbatim: line) }
                } header: { text("transfer.impact") }
                Section {
                    TextField(text: $phone) { text("transfer.phone") }
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    if preview.offersSMS {
                        Picker(selection: $channel) {
                            text("transfer.channel.inApp").tag(BundleTransferChannel.inApp)
                            text("transfer.channel.sms").tag(BundleTransferChannel.sms)
                        } label: { text("transfer.channel") }
                    }
                    CYPillButton("transfer.confirm", style: .primary, tableName: table) { confirming = true }
                        .disabled(phone.isEmpty)
                }
            case .sending:
                CYLoadingStateView(rows: 2).accessibilityLabel(text("transfer.sending"))
            case .shown:
                Section {
                    if let code = model.oneTimeCode {
                        Text(verbatim: code.reveal()).font(.title2.monospaced()).textSelection(.enabled)
                            .accessibilityIdentifier("bundleTransfer.code")
                    }
                    text("transfer.code.once")
                    if let state = model.display { stateLabel(state) }
                    Button(role: .destructive) { Task { await model.revoke() } } label: { text("transfer.revoke") }
                }
            case .recovered:
                Section {
                    text("transfer.code.unavailable")
                    if let state = model.display { stateLabel(state) }
                    Button(role: .destructive) { Task { await model.revoke() } } label: { text("transfer.revoke") }
                }
            case .revoked:
                Section { if let state = model.display { stateLabel(state) } }
            case .outcomeUnknown:
                Section {
                    text("transfer.unknown")
                    CYPillButton("transfer.recover", style: .secondary, tableName: table) { Task { await model.recover() } }
                }
            case .failed(let code):
                text("transfer.error").accessibilityIdentifier("bundleTransfer.error")
                if let code { Text(verbatim: code).font(.caption) }
            }
        }
        .cyGroupedSurface()
        .confirmationDialog(Text(LocalizedStringKey("transfer.confirm.title"), tableName: table),
                            isPresented: $confirming, titleVisibility: .visible) {
            Button(role: .destructive) {
                let number = phone, selected = channel
                Task { await model.confirm(phone: number, channel: selected) }
            } label: { text("transfer.confirm.action") }
        } message: { text("transfer.confirm.message") }
        .task { await model.loadPreview(registrationID: registrationID) }
        .onDisappear { model.leave() }
    }

    @ViewBuilder private func stateLabel(_ state: BundleTransferDisplayState) -> some View {
        switch state {
        case .sent: text("transfer.state.sent")
        case .pending: text("transfer.state.pending")
        case .claimed: text("transfer.state.claimed")
        case .expired: text("transfer.state.expired")
        case .revoked: text("transfer.state.revoked")
        case .unknown: text("transfer.state.unknown")
        }
    }
}
