import SwiftUI

/// OTA channel-code sheet. The entry stays visible and says the provider is off until a real receipt arrives.
/// A provider-off answer does not say the code was used. Success does not open a payment or a scan page.

struct ChannelRedeemSheet: View {
    let session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var working = false
    @State private var phase: ChannelRedeemPhase = .idle
    @State private var usingRegistration = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    Text("channelRedeem.note").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("channelRedeem.note")
                    TextField("channelRedeem.code", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("channelRedeem.code")
                    CYMorphButton("channelRedeem.submit", state: working ? .working : .idle) { Task { await redeem() } }
                        .disabled(working)
                        .accessibilityIdentifier("channelRedeem.submit")
                    result
                }
                .padding(CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            }
            .background { MPNightGround() }
            .navigationTitle(Text("channelRedeem.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var result: some View {
        switch phase {
        case .idle:
            CYEmptyState(systemImage: "ticket", "channelRedeem.empty", messageIdentifier: "channelRedeem.empty")
        case .loading:
            CYLoadingStateView(rows: 2).accessibilityIdentifier("channelRedeem.loading")
        case .unavailable:
            Text("channelRedeem.unavailable").accessibilityIdentifier("channelRedeem.unavailable")
        case .expired:
            Text("channelRedeem.expired")
        case .revoked:
            Text("channelRedeem.revoked")
        case .used:
            Text("channelRedeem.used")
        case .mismatch:
            Text("channelRedeem.mismatch")
        case .invalid:
            Text("channelRedeem.invalid")
        case .unsupported:
            Text("channelRedeem.unsupportedProduct")
        case .currency:
            Text("channelRedeem.currency")
        case .failed:
            CYEmptyState(systemImage: "exclamationmark.triangle", "channelRedeem.error", messageIdentifier: "channelRedeem.error",
                         actionTitle: "action.retry", action: { Task { await redeem() } })
        case .pending:
            Text("channelRedeem.pending")
        case .signedOut:
            CYEmptyState(systemImage: "person.crop.circle", "hostTip.signedOut", messageIdentifier: "channelRedeem.signedOut")
        case .redeemed(let receipt):
            receiptView(receipt)
        }
    }

    private func receiptView(_ receipt: ChannelRedeemReceipt) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(receipt.replayed ? "channelRedeem.replayed" : "channelRedeem.redeemed")
                .cyText(.bodyMedium)
                .accessibilityIdentifier(receipt.replayed ? "channelRedeem.replayed" : "channelRedeem.redeemed")
            labeled("channelRedeem.product", receipt.productName)
            labeled("channelRedeem.seats", receipt.seatCount)
            labeled("channelRedeem.valid", receipt.validFrom + " – " + receipt.validTo)
            labeled("channelRedeem.registration", receipt.registrationNo)
            Button("channelRedeem.use") { usingRegistration = true }
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("channelRedeem.use")
            if usingRegistration {
                Text(verbatim: receipt.registrationNo).cyText(.body).accessibilityIdentifier("channelRedeem.use.registration")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeled(_ title: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value).monospacedDigit()
        } label: {
            Text(title)
        }
        .cyText(.body)
        .frame(minHeight: CYSpacing.minTouchTarget)
    }

    private func redeem() async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .idle
            return
        }
        working = true
        phase = .loading
        defer { working = false }
        guard let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base),
              let token = session.token, AuthRequestBuilder.isValidToken(token) else {
            phase = .signedOut
            return
        }
        let source = ChannelRedeemSource(configuration: configuration, transport: session.composition.makeTransport())
        do {
            let envelope = try await source.redeem(code: trimmed, token: token)
            phase = Self.phase(ChannelRedeemSource.presentation(envelope))
        } catch ChannelRedeemRefusal.invalidRequest {
            phase = .invalid
        } catch {
            phase = .pending
        }
    }

    private static func phase(_ presentation: ChannelRedeemPresentation) -> ChannelRedeemPhase {
        switch presentation {
        case .pending: return .pending
        case .unavailable: return .unavailable
        case .expired: return .expired
        case .revoked: return .revoked
        case .usedByOther: return .used
        case .subjectMismatch: return .mismatch
        case .invalid: return .invalid
        case .productUnsupported: return .unsupported
        case .currencyUnsupported: return .currency
        case .failed: return .failed
        case .redeemed(let receipt): return .redeemed(receipt)
        }
    }
}

private enum ChannelRedeemPhase: Equatable {
    case idle
    case loading
    case unavailable
    case expired
    case revoked
    case used
    case mismatch
    case invalid
    case unsupported
    case currency
    case failed
    case pending
    case signedOut
    case redeemed(ChannelRedeemReceipt)
}
