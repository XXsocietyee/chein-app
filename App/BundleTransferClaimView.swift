import SwiftUI

/// IWP-8c receiver screen. Unmounted. The typed code stays in this view's @State only for the call;
/// it is cleared as soon as the claim is submitted and is never persisted or logged.
/// Every rejection (wrong / expired / used) shows the same single message.
@MainActor struct BundleTransferClaimView: View {
    @ObservedObject var model: BundleTransferClaimModel
    @State private var code = ""
    @State private var claimTick = 0
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .largeTitle) private var artHeight: CGFloat = 112
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        // Native restyle r1 (spec §3.2): an inset-grouped Form with a system inline title.
        Form {
            Section {
                CYCoverArt(seed: "bundle-claim", symbol: "arrow.left.arrow.right", showsDebugLabel: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: artHeight)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
                    .accessibilityHidden(true)
            }
            .cyCardRow()
            switch model.phase {
            case .claimed:
                Section { claimed }.cyCardRow()
            case .unavailable:
                Section { CYEmptyState(systemImage: "wifi.slash", "transfer.unavailable", tableName: table, messageIdentifier: "bundleTransfer.unavailable") }
                    .cyCardRow()
            default:
                claimForm
                Section { phaseNote }.cyCardRow()
            }
        }
        .navigationTitle(Text(verbatim: ChannelCopy.text("领取转赠", "Claim a transfer", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
        .cyAnimation(value: model.phase)
        .cyHaptic(.success, trigger: model.phase) { _, new in
            if case .claimed = new { return true }
            return false
        }
        .cyHaptic(.warning, trigger: model.phase) { _, new in new == .codeNotAccepted }
        .onDisappear { code = "" }
    }

    private var claimed: some View {
        CYEmptyState(systemImage: "checkmark.circle", "transfer.claim.done", tableName: table, messageIdentifier: "bundleTransfer.claimed")
    }

    @ViewBuilder private var claimForm: some View {
        Section {
            TextField(text: $code) { text("transfer.claim.code") }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .cyText(.body)
                .accessibilityLabel(text("transfer.claim.code"))
        }
        Section {
            CYPillButton("transfer.claim.action", systemImage: "arrow.down.circle", tableName: table) {
                let typed = code
                code = ""
                claimTick += 1
                Task { await model.claim(code: typed) }
            }
            .disabled(code.isEmpty || model.phase == .claiming)
            .accessibilityLabel(text("transfer.claim.action"))
            .cyHaptic(.impactMedium, trigger: claimTick)
        }
        .cyCardRow()
    }

    @ViewBuilder private var phaseNote: some View {
        switch model.phase {
        case .claiming:
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYSkeleton().accessibilityHidden(true)
                text("transfer.claiming")
                    .cyText(.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        case .codeNotAccepted:
            CYNoteBanner(text: text("transfer.claim.rejected"), symbol: "exclamationmark.triangle", tone: .danger)
                .accessibilityIdentifier("bundleTransfer.rejected")
        case .outcomeUnknown:
            CYNoteBanner(text: text("transfer.claim.unknown"), symbol: "questionmark.circle", tone: .warning)
        case .failed:
            CYNoteBanner(text: text("transfer.error"), symbol: "exclamationmark.circle", tone: .danger)
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
