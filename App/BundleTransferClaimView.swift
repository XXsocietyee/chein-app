import SwiftUI

/// IWP-8c receiver screen. Unmounted. The typed code stays in this view's @State only for the call;
/// it is cleared as soon as the claim is submitted and is never persisted or logged.
/// Every rejection (wrong / expired / used) shows the same single message.
@MainActor struct BundleTransferClaimView: View {
    @ObservedObject var model: BundleTransferClaimModel
    @State private var code = ""
    @State private var claimTick = 0
    @Environment(\.locale) private var locale
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        // Native r2: an inset-grouped Form with a system inline title.
        Form {
            switch model.phase {
            case .claimed:
                Section { claimed }
            case .unavailable:
                Section {
                    ContentUnavailableView {
                        Label {
                            text("transfer.unavailable").accessibilityIdentifier("bundleTransfer.unavailable")
                        } icon: {
                            Image(systemName: "wifi.slash")
                        }
                    }
                }
            default:
                claimForm
                Section { phaseNote }
            }
        }
        .navigationTitle(Text(verbatim: ChannelCopy.text("领取转赠", "Claim a transfer", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
        .cyAnimation(value: model.phase)
        .cyHaptic(.success, trigger: model.phase, where: Self.transferClaimed)
        .cyHaptic(.warning, trigger: model.phase == .codeNotAccepted, where: CYHapticTransition.turnedOn)
        .onDisappear { code = "" }
    }

    private var claimed: some View {
        ContentUnavailableView {
            Label {
                text("transfer.claim.done").accessibilityIdentifier("bundleTransfer.claimed")
            } icon: {
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder private var claimForm: some View {
        Section {
            TextField(text: $code) { text("transfer.claim.code") }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .submitLabel(.done)
                .accessibilityLabel(text("transfer.claim.code"))
        }
        Section {
            Button {
                let typed = code
                code = ""
                claimTick += 1
                Task { await model.claim(code: typed) }
            } label: {
                Label { text("transfer.claim.action") } icon: { Image(systemName: "arrow.down.circle") }
            }
            .disabled(code.isEmpty || model.phase == .claiming)
            .accessibilityLabel(text("transfer.claim.action"))
            .cyHaptic(.impactMedium, trigger: claimTick)
        }
    }

    @ViewBuilder private var phaseNote: some View {
        switch model.phase {
        case .claiming:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                text("transfer.claiming")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        case .codeNotAccepted:
            Cloud03Note(text: text("transfer.claim.rejected"), symbol: "exclamationmark.triangle", tone: .danger)
                .accessibilityIdentifier("bundleTransfer.rejected")
        case .outcomeUnknown:
            Cloud03Note(text: text("transfer.claim.unknown"), symbol: "questionmark.circle", tone: .warning)
        case .failed:
            Cloud03Note(text: text("transfer.error"), symbol: "exclamationmark.circle", tone: .danger)
        default:
            EmptyView()
        }
    }
}

#if DEBUG
#Preview("Claim · player dark") {
    ClaimPreviewHost(domain: .player)
}
#Preview("Claim · merchant light") {
    ClaimPreviewHost(domain: .merchant)
}

@MainActor private struct ClaimPreviewHost: View {
    let domain: ThemeDomain
    @StateObject private var model: BundleTransferClaimModel
    init(domain: ThemeDomain) {
        self.domain = domain
        let session = try! FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                                    namespace: "preview", role: "player", epoch: 1, token: "synthetic-test-credential")
        let pending = BundleTransferPendingStore(storage: ClaimPreviewStorage(), session: session)
        _model = StateObject(wrappedValue: BundleTransferClaimModel(service: BundleTransferUnavailableClient(), pending: pending, makeKey: { "bc-preview" }))
    }
    var body: some View {
        NavigationStack { BundleTransferClaimView(model: model) }
            .themeDomain(domain)
    }
}

@MainActor private final class ClaimPreviewStorage: TemplateAuthoringStorage {
    private var values: [String: Data] = [:]
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data, key: String) throws { values[key] = data }
    func remove(_ key: String) throws { values[key] = nil }
}
#endif

/// Typed haptic condition (design consistency `untyped haptic`): fires when the state lands on `.claimed`.
private extension BundleTransferClaimView {
    static func transferClaimed(_ old: BundleTransferClaimPhase, _ new: BundleTransferClaimPhase) -> Bool {
        if case .claimed = new { return true }
        return false
    }
}
