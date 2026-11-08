import SwiftUI

/// Unmounted candidate (no route, no composition wiring). Renders only what the injected model holds;
/// with the shipped `UnavailableBundleVoucherClient` it shows the unavailable state, never sample codes.
/// Codes are not selectable (no pasteboard affordance) and are hidden whenever the scene is not active.
@MainActor struct BundleVoucherView: View {
    @ObservedObject var model: BundleVoucherModel
    @Environment(\.scenePhase) private var scenePhase
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading:
                Section { ProgressView { text("bundle.voucher.loading") } }
            case .unavailable:
                Section { text("bundle.voucher.unavailable").accessibilityIdentifier("bundleVoucher.unavailable") }
            case .failed:
                Section {
                    text("bundle.voucher.error").accessibilityIdentifier("bundleVoucher.error")
                    Button { Task { await model.reload() } } label: { text("bundle.voucher.retry") }
                }
            case .loaded(let voucher):
                content(voucher)
            }
        }
        .navigationTitle(Text("bundle.voucher.title", tableName: table))
        .task { await model.appear() }
        .onDisappear { model.disappear() }
    }

    @ViewBuilder private func content(_ voucher: BundleVoucher) -> some View {
        let hidden = scenePhase != .active
        Section {
            if hidden {
                text("bundle.voucher.hidden")
            } else if let code = voucher.mainCode, !code.isEmpty {
                Text(verbatim: code)
                    .font(.title3.monospaced())
                    .privacySensitive()
                    .accessibilityIdentifier("bundleVoucher.mainCode")
                if let validTo = voucher.mainValidTo { LabeledContent { Text(verbatim: validTo) } label: { text("bundle.voucher.validTo") } }
            } else {
                text("bundle.voucher.noMainCode")
            }
        } header: { text("bundle.voucher.main") }
        Section {
            if voucher.subs.isEmpty { text("bundle.voucher.noSubs") }
            ForEach(voucher.subs, id: \.unitID) { sub in
                VStack(alignment: .leading, spacing: 4) {
                    if !hidden { Text(verbatim: sub.unitCode).font(.body.monospaced()).privacySensitive() }
                    Text(verbatim: sub.status).font(.footnote)
                    if let validTo = sub.validTo { Text(verbatim: validTo).font(.caption) }
                }
            }
        } header: { text("bundle.voucher.subs") }
    }
}
