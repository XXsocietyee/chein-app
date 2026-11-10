import SwiftUI

/// Unmounted candidate. Real-data consumer only: no fixture, transport or entry point is installed here.
/// Records an intention to renew and nothing else: the only controls are the three intent choices, an
/// optional note and a submit button (pinned by a source scan in BNDRenewalModelTests).
@MainActor struct BundleRenewalIntentView: View {
    @Bindable var model: BundleRenewalModel
    @State private var choice: BundleRenewalIntent = .maybe
    @State private var note = ""
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    private func label(_ intent: BundleRenewalIntent) -> Text {
        switch intent {
        case .willRenew: return text("renewal.intent.WILL_RENEW")
        case .maybe: return text("renewal.intent.MAYBE")
        case .no: return text("renewal.intent.NO")
        }
    }

    var body: some View {
        Form {
            Section { CYHeroHeader("renewal.title", tableName: table).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if !model.current {
                text("renewal.stale")
            } else {
                Section { text("renewal.intentOnly") }
                if model.busy { CYLoadingStateView(rows: 1).accessibilityLabel(text("renewal.loading")) }
                if model.phase == .unavailable {
                    Section { text("renewal.unavailable").accessibilityIdentifier("bundleRenewal.unavailable") }
                } else if model.failure != nil && model.phase != .outcomeUnknown {
                    Section { text("renewal.error").accessibilityIdentifier("bundleRenewal.error") }
                }
                if let latest = model.latest {
                    Section {
                        if let known = latest.knownIntent { label(known) } else { text("renewal.intent.unrecognized") }
                        if let note = latest.note { Text(verbatim: note).font(.footnote) }
                    } header: { text("renewal.latest") }
                } else if model.phase == .loaded {
                    Section { text("renewal.none") }
                }
                if model.phase == .outcomeUnknown {
                    Section {
                        text("renewal.unknown")
                        CYPillButton("renewal.recover", style: .secondary, tableName: table) { Task { await model.recover() } }
                            .disabled(!model.canRecover)
                        CYPillButton("renewal.retry", style: .tertiary, tableName: table) { Task { await model.retry() } }
                            .disabled(!model.canRetry)
                    }
                } else if model.phase != .unavailable {
                    Section {
                        Picker(selection: $choice) {
                            ForEach(BundleRenewalIntent.allCases, id: \.self) { intent in
                                label(intent).tag(intent)
                            }
                        } label: { text("renewal.choose") }
                        TextField(text: $note, axis: .vertical) { text("renewal.note") }
                            .onChange(of: note) { _, value in
                                if value.count > BundleRenewalCommand.noteLimit {
                                    note = String(value.prefix(BundleRenewalCommand.noteLimit))
                                }
                            }
                        CYPillButton("renewal.submit", style: .primary, tableName: table) { Task { await model.submit(intent: choice, note: note) } }
                            .disabled(!model.canSubmit)
                    }
                }
            }
        }
        .cyGroupedSurface()
        .task { await model.load() }
    }
}
