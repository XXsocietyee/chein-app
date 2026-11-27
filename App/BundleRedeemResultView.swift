import SwiftUI

/// Unmounted candidate. Three server-driven states (success / review / rejected) plus `NONE`; any outcome the
/// app does not recognise is shown as neutral "processing". Reason text comes from the server only.
@MainActor struct BundleRedeemResultView: View {
    @ObservedObject var model: BundleVoucherModel
    let unitID: String
    private let table = "BundleCommerce"
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        Cloud03Screen(
            title: catalog("bundle.redeem.title"),
            seed: unitID.isEmpty ? "bundle-redeem" : unitID,
            symbol: coverSymbol
        ) {
            stateBody
        }
        .cyAnimation(value: model.redeemState)
        .task { await model.loadRedeemResult(unitID: unitID) }
        .onChange(of: model.redeemState) { _, new in
            guard !reduceMotion else { return }
            if case .loaded(let presentation, _) = new, presentation == .success {
                CYHaptics.success.play()
            }
        }
    }

    private func catalog(_ key: String) -> String {
        Cloud03Copy.catalog(key, table: table, locale: locale)
    }

    @ViewBuilder private var stateBody: some View {
        switch model.redeemState {
        case .idle, .loading:
            Section {
                ProgressView { Text(verbatim: catalog("bundle.redeem.loading")) }
                    .frame(maxWidth: .infinity)
            }
        case .unavailable:
            ContentUnavailableView(catalog("bundle.redeem.unavailable"), systemImage: "exclamationmark.circle")
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("bundleRedeem.unavailable")
        case .failed:
            ContentUnavailableView {
                Label(catalog("bundle.redeem.error"), systemImage: "exclamationmark.triangle")
            } actions: {
                Button {
                    Task { await model.loadRedeemResult(unitID: unitID) }
                } label: {
                    Text(verbatim: catalog("bundle.redeem.retry"))
                }
                .buttonStyle(.borderedProminent)
            }
            .listRowBackground(Color.clear)
        case .loaded(let presentation, let result):
            Section {
                Label {
                    Text(verbatim: headline(presentation))
                        .font(.headline)
                } icon: {
                    Image(systemName: symbol(presentation))
                        .foregroundStyle(Cloud03Note.tint(tone(presentation)))
                }
                .accessibilityIdentifier("bundleRedeem.state")
                if let name = result.merchantName, !name.isEmpty, presentation == .success {
                    Label(Cloud03Copy.shown(name), systemImage: "storefront")
                }
                if let reason = result.reason, !reason.isEmpty, presentation == .rejected || presentation == .review {
                    Text(verbatim: Cloud03Copy.shown(reason))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var coverSymbol: String {
        if case .loaded(let presentation, _) = model.redeemState { return symbol(presentation) }
        return "ticket"
    }

    private func headline(_ presentation: BundleRedeemPresentation) -> String {
        switch presentation {
        case .success: return catalog("bundle.redeem.success")
        case .review: return catalog("bundle.redeem.review")
        case .rejected: return catalog("bundle.redeem.rejected")
        case .notRedeemed: return catalog("bundle.redeem.none")
        case .processing: return catalog("bundle.redeem.processing")
        }
    }

    private func symbol(_ presentation: BundleRedeemPresentation) -> String {
        switch presentation {
        case .success: return "checkmark.seal"
        case .review: return "clock"
        case .rejected: return "xmark.circle"
        case .notRedeemed: return "ticket"
        case .processing: return "hourglass"
        }
    }

    private func tone(_ presentation: BundleRedeemPresentation) -> CYStatusTone {
        switch presentation {
        case .success: return .success
        case .review, .processing: return .warning
        case .rejected: return .danger
        case .notRedeemed: return .neutral
        }
    }
}
