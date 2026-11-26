import SwiftUI

/// Merchant stall detail (T-03). Renders only what the server returned; with the default
/// `UnavailableBundleOfferClient` the caller passes `.unavailable` and no data is invented.
/// Not mounted anywhere.
struct BundleMerchantStallView: View {
    enum Content {
        case unavailable
        case loaded(BundleOfferDetail, window: BundleReserveWindow)
    }
    let content: Content
    let onChooseStart: (Int64) -> Void
    private let table = "BundleStall"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        Form {
            switch content {
            case .unavailable:
                ContentUnavailableView {
                    Label {
                        text("unavailable").accessibilityIdentifier("bundleStall.unavailable")
                    } icon: {
                        Image(systemName: "storefront")
                    }
                }
            case let .loaded(detail, window):
                Section {
                    if let name = detail.merchantName { Text(verbatim: name).font(.headline) }
                    if let terms = detail.termsMode { Text(verbatim: terms).font(.subheadline).foregroundStyle(.secondary) }
                    if let end = detail.validEnd { Text(verbatim: end.raw).font(.subheadline).foregroundStyle(.secondary) }
                }
                if !detail.reasons.isEmpty {
                    Section {
                        ForEach(Array(detail.reasons.enumerated()), id: \.offset) { _, reason in
                            Text(LocalizedStringKey(reason.copyKey), tableName: table)
                        }
                    } header: { text("reasons.header") }
                }
                if !detail.slots.isEmpty {
                    Section {
                        ForEach(detail.slots, id: \.startAt) { slot in
                            Button { onChooseStart(slot.startAt) } label: {
                                HStack {
                                    Text(Date(timeIntervalSince1970: Double(slot.startAt) / 1_000),
                                         format: .dateTime)
                                    Spacer()
                                    Text(verbatim: String(slot.remaining)).foregroundStyle(.secondary)
                                }
                            }
                            .disabled(!window.contains(slot.startAt) || slot.remaining <= 0)
                        }
                    } header: { text("slots.header") }
                } else if detail.reasons.isEmpty {
                    BundleReserveWindowView(window: window, onChoose: onChooseStart)
                }
            }
        }
    }
}
