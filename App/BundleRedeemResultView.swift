import SwiftUI

/// Unmounted candidate. Three server-driven states (success / review / rejected) plus `NONE`; any outcome the
/// app does not recognise is shown as neutral "processing". Reason text comes from the server only.
@MainActor struct BundleRedeemResultView: View {
    @ObservedObject var model: BundleVoucherModel
    let unitID: String
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        List {
            Section { CYHeroHeader("bundle.redeem.title", tableName: table) }.e1HeroRow()
            switch model.redeemState {
            case .idle, .loading:
                Section { CYLoadingStateView(rows: 1).accessibilityLabel(text("bundle.redeem.loading")) }
            case .unavailable:
                Section { text("bundle.redeem.unavailable").accessibilityIdentifier("bundleRedeem.unavailable") }
            case .failed:
                Section {
                    text("bundle.redeem.error")
                    CYPillButton("bundle.redeem.retry", style: .secondary, systemImage: "arrow.clockwise", tableName: table) { Task { await model.loadRedeemResult(unitID: unitID) } }
                        .e1ActionRow()
                }
            case .loaded(let presentation, let result):
                Section {
                    HStack(spacing: CYSpacing.sm) {
                        Image(systemName: symbol(presentation)).foregroundStyle(tint(presentation)).accessibilityHidden(true)
                        headline(presentation)
                    }
                    .font(CYTypography.sectionTitle)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("bundleRedeem.state")
                    if let name = result.merchantName, presentation == .success { Text(verbatim: name) }
                    if let reason = result.reason, !reason.isEmpty, presentation == .rejected || presentation == .review {
                        Text(verbatim: reason).font(.footnote)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cyHeroScreen()
        .task { await model.loadRedeemResult(unitID: unitID) }
    }

    private func symbol(_ presentation: BundleRedeemPresentation) -> String {
        switch presentation {
        case .success: return "checkmark.seal.fill"
        case .review: return "hourglass"
        case .rejected: return "xmark.octagon.fill"
        case .notRedeemed, .processing: return "clock"
        }
    }

    private func tint(_ presentation: BundleRedeemPresentation) -> Color {
        switch presentation {
        case .success: return CYColor.successText
        case .review: return CYColor.warningText
        case .rejected: return CYColor.dangerText
        case .notRedeemed, .processing: return CYColor.textSecondary
        }
    }

    private func headline(_ presentation: BundleRedeemPresentation) -> Text {
        switch presentation {
        case .success: return text("bundle.redeem.success")
        case .review: return text("bundle.redeem.review")
        case .rejected: return text("bundle.redeem.rejected")
        case .notRedeemed: return text("bundle.redeem.none")
        case .processing: return text("bundle.redeem.processing")
        }
    }
}
