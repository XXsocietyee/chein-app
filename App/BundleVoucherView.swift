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
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(text("bundle.voucher.loading"))
                }
                .listRowBackground(Color.clear)
            case .unavailable:
                Section {
                    ContentUnavailableView {
                        Label {
                            text("bundle.voucher.unavailable").accessibilityIdentifier("bundleVoucher.unavailable")
                        } icon: {
                            Image(systemName: "qrcode")
                        }
                    }
                }
                .listRowBackground(Color.clear)
            case .failed:
                Section {
                    ContentUnavailableView {
                        Label {
                            text("bundle.voucher.error").accessibilityIdentifier("bundleVoucher.error")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    } actions: {
                        Button { Task { await model.reload() } } label: { Text("action.retry") }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .listRowBackground(Color.clear)
            case .loaded(let voucher):
                content(voucher)
            }
        }
        .navigationTitle(Text("bundle.voucher.title", tableName: table)).navigationBarTitleDisplayMode(.inline)
        .task { await model.appear() }
        .refreshable { await model.reload() }
        .onDisappear { model.disappear() }
        .listStyle(.insetGrouped)
        .themeDomain(.player)
    }

    @ViewBuilder private func content(_ voucher: BundleVoucher) -> some View {
        let hidden = scenePhase != .active
        Section {
            if hidden {
                text("bundle.voucher.hidden")
            } else if let code = voucher.mainCode, !code.isEmpty {
                Text(verbatim: code)
                    .font(.title.weight(.semibold)).monospaced()
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
                    Text(verbatim: sub.status).font(.subheadline).foregroundStyle(.secondary)
                    if let validTo = sub.validTo { Text(verbatim: validTo).font(.footnote).foregroundStyle(.secondary) }
                }
            }
        } header: { text("bundle.voucher.subs") }
    }
}
