import SwiftUI

/// Pure presentation mapping for the bundle order screens (IWP-2). No copy is hard-coded: every string is a key in
/// the `BundleCommerce` table (requested in docs/owner-plan/iwp-2-new-strings.md, added by the orchestrator).
enum BundleOrderStatusPresentation {
    static let table = "BundleCommerce"

    enum Banner: Equatable {
        case none
        /// Receipt polling is running (first read or a NOT_FOUND answer so far).
        case confirming
        /// Poll budget used up with NOT_FOUND only: still unconfirmed, NOT failed, NOT "nothing was created".
        case stillConfirming
        case failed
        /// The read itself could not be completed.
        case unavailable
    }

    static func banner(for state: BundleReceiptPollState) -> Banner {
        switch state {
        case .idle, .found: return .none
        case .polling: return .confirming
        case .stillUnconfirmed: return .stillConfirming
        case .failed: return .failed
        case .readUnavailable: return .unavailable
        }
    }

    static func bannerKey(_ banner: Banner) -> String? {
        switch banner {
        case .none: return nil
        case .confirming: return "order.receipt.confirming"
        case .stillConfirming: return "order.receipt.stillConfirming"
        case .failed: return "order.receipt.failed"
        case .unavailable: return "order.receipt.unavailable"
        }
    }

    static func activationKey(_ activation: BundleActivation) -> String {
        switch activation {
        case .pending: return "activation.pending"
        case .active: return "activation.active"
        case .expired: return "activation.expired"
        case .refunded: return "activation.refunded"
        case .unknown: return "activation.unknown"
        }
    }

    /// nil for an unknown server status: the view then shows the raw server string instead of inventing copy.
    static func reservationStatusKey(_ row: BundleReservationRow) -> String? {
        row.isKnownStatus ? "reservation.status.\(row.status)" : nil
    }

    static func unitStatusKey(_ row: BundleUnitRow) -> String? {
        row.isKnownStatus ? "unit.status.\(row.status)" : nil
    }

    static func unitStatusKey(_ status: String) -> String? {
        BundleStatusCatalog.knownUnitStatuses.contains(status) ? "unit.status.\(status)" : nil
    }
}

/// T-05. Real-data consumer only: it renders an injected server model and (optionally) a receipt poller.
/// Not mounted anywhere; no fixture or provider is installed here. It never shows a "paid" claim of its own:
/// the activation line is the server's status pair, mapped through `BundleOrderReadModel.activation`.
@MainActor struct BundleOrderStatusView: View {
    let order: BundleOrderReadModel?
    var poller: BundleReceiptPollerBinding?
    private let table = BundleOrderStatusPresentation.table
    @Environment(\.locale) private var locale

    init(order: BundleOrderReadModel?, poller: BundleReceiptPoller? = nil) {
        self.order = order; self.poller = poller.map(BundleReceiptPollerBinding.init)
    }

    var body: some View {
        let banner = poller.map { BundleOrderStatusPresentation.banner(for: $0.state) } ?? .none
        Cloud03Screen(
            title: Cloud03Copy.line("订单状态", "Order status", locale: locale),
            seed: order?.registrationId.text ?? "bundle-order",
            symbol: "shippingbox"
        ) {
            if let key = BundleOrderStatusPresentation.bannerKey(banner) {
                Section {
                    HStack(spacing: CYSpacing.sm) {
                        Cloud03Note(text: Text(verbatim: catalog(key)), symbol: bannerSymbol(banner), tone: bannerTone(banner))
                            .accessibilityIdentifier("bundle.order.receiptBanner")
                        if banner == .confirming {
                            Spacer(minLength: 0)
                            ProgressView()
                        }
                    }
                    if poller?.state == .stillUnconfirmed || poller?.state == .readUnavailable {
                        Button {
                            poller?.poller.start()
                        } label: {
                            Label(catalog("order.receipt.recheck"), systemImage: "arrow.clockwise")
                        }
                        .accessibilityLabel(Text(verbatim: catalog("order.receipt.recheck")))
                    }
                }
            }
            if let order {
                orderBody(order)
            } else if banner == .none {
                ContentUnavailableView(
                    Cloud03Copy.line("还没有可显示的订单", "No order to show", locale: locale),
                    systemImage: "shippingbox"
                )
                .listRowBackground(Color.clear)
            }
        }
        .cyAnimation(value: poller?.state)
        .cyHaptic(.success, trigger: receiptFound, where: CYHapticTransition.isOn)
        .onDisappear { poller?.poller.stop() }
    }

    /// True once polling lands on a receipt: the one `.success` tick of this screen (motion-spec-purchase.md).
    private var receiptFound: Bool {
        if case .found? = poller?.state { return true }
        return false
    }

    private func orderBody(_ order: BundleOrderReadModel) -> some View {
        Section {
            LabeledContent {
                Text(verbatim: Cloud03Copy.shown(order.registrationId.text))
            } label: {
                Label(catalog("order.number"), systemImage: "number")
            }
            if let number = order.registrationNo {
                Text(verbatim: Cloud03Copy.shown(number))
                    .font(.body.monospacedDigit())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if order.isLegacy {
                Cloud03Note(text: Text(verbatim: catalog("order.legacy")), symbol: "doc.text", tone: .neutral)
                    .accessibilityIdentifier("bundle.order.legacy")
            } else {
                let key = BundleOrderStatusPresentation.activationKey(order.activation)
                LabeledContent {
                    Text(verbatim: catalog(key))
                } label: {
                    Label(catalog("order.status"), systemImage: activationSymbol(order.activation))
                }
                .accessibilityIdentifier("bundle.order.activation")
            }
        }
    }

    private func catalog(_ key: String) -> String {
        Cloud03Copy.catalog(key, table: table, locale: locale)
    }

    private func bannerSymbol(_ banner: BundleOrderStatusPresentation.Banner) -> String {
        switch banner {
        case .none: return "info.circle"
        case .confirming, .stillConfirming: return "clock"
        case .failed: return "exclamationmark.triangle"
        case .unavailable: return "wifi.exclamationmark"
        }
    }

    private func bannerTone(_ banner: BundleOrderStatusPresentation.Banner) -> CYStatusTone {
        switch banner {
        case .none, .confirming: return .info
        case .stillConfirming, .unavailable: return .warning
        case .failed: return .danger
        }
    }

    private func activationSymbol(_ activation: BundleActivation) -> String {
        switch activation {
        case .pending: return "clock"
        case .active: return "checkmark.circle"
        case .expired: return "calendar.badge.exclamationmark"
        case .refunded: return "arrow.uturn.backward"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Lets a struct view observe the `@Observable` poller through a stable reference.
@MainActor struct BundleReceiptPollerBinding {
    let poller: BundleReceiptPoller
    init(_ poller: BundleReceiptPoller) { self.poller = poller }
    var state: BundleReceiptPollState { poller.state }
}

// MARK: - Shared chrome for this lane (player dark, one hero title, 16pt gutters)

enum Cloud03Copy {
    static let dash = "—"

    /// Empty and raw catalog keys become an em dash. A real 0, including `0.00`, stays.
    static func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isRawKey(trimmed) { return dash }
        return trimmed
    }

    /// Lowercase dotted catalog keys (`order.status`). Decimals such as `0` and `0.00` are not keys.
    static func isRawKey(_ value: String) -> Bool {
        value.range(of: #"^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$"#, options: .regularExpression) != nil
    }

    static func catalog(_ key: String, table: String, locale: Locale) -> String {
        let resolved = String(
            localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: table, locale: locale)
        )
        if resolved == key || isRawKey(resolved) { return dash }
        return resolved
    }

    static func line(_ zh: String, _ en: String, locale: Locale) -> String {
        if locale.language.languageCode?.identifier == "zh" { return zh }
        if locale.language.languageCode == nil { return W8Text.t(zh, en) }
        return en
    }
}

/// Native r2: a note line is a system `Label` with a tinted SF Symbol (replaces the custom note banner on this lane).
struct Cloud03Note: View {
    let text: Text
    let symbol: String
    var tone: CYStatusTone = .info

    var body: some View {
        Label {
            text.fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Cloud03Note.tint(tone))
        }
    }

    static func tint(_ tone: CYStatusTone) -> Color {
        switch tone {
        case .neutral: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        case .info, .rare: return .accentColor
        }
    }
}

/// Native r2: every screen on this lane is a system inset-grouped list with the inline navigation title.
/// `seed` and `symbol` are kept for call-site compatibility; the generated cover art is retired.
struct Cloud03Screen<Content: View>: View {
    let title: String
    var subtitle: String?
    let seed: String
    let symbol: String
    let content: () -> Content

    init(title: String, subtitle: String? = nil, seed: String, symbol: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.seed = seed
        self.symbol = symbol
        self.content = content
    }

    var body: some View {
        List {
            if let subtitle {
                Section {
                    Text(verbatim: subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
    }
}
