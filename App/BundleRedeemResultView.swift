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
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                stateBody
            }
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
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYSkeleton().accessibilityHidden(true)
                Text(verbatim: catalog("bundle.redeem.loading"))
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .unavailable:
            CYStateLayout(kind: .offline, title: Text(verbatim: catalog("bundle.redeem.unavailable")))
                .accessibilityIdentifier("bundleRedeem.unavailable")
        case .failed:
            CYStateLayout(
                kind: .failure,
                title: Text(verbatim: catalog("bundle.redeem.error")),
                primaryVerbatim: (title: catalog("bundle.redeem.retry"), action: {
                    Task { await model.loadRedeemResult(unitID: unitID) }
                }),
                primaryStyle: .primary
            )
        case .loaded(let presentation, let result):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if presentation == .success || presentation == .rejected {
                    CYResultMark(kind: presentation == .success ? .success : .failure, size: 96)
                        .frame(maxWidth: .infinity)
                        .cyRowTransition()
                }
                CYStatusChip(verbatim: headline(presentation), tone: tone(presentation), systemImage: symbol(presentation))
                    .accessibilityIdentifier("bundleRedeem.state")
                if let name = result.merchantName, !name.isEmpty, presentation == .success {
                    CYListRow(verbatim: Cloud03Copy.shown(name), trailing: .none, card: true) {
                        CYRowIcon(systemImage: "storefront")
                    }
                }
                if let reason = result.reason, !reason.isEmpty, presentation == .rejected || presentation == .review {
                    Text(verbatim: Cloud03Copy.shown(reason))
                        .font(CYTypography.body)
                        .foregroundStyle(CYColor.textSecondary)
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
