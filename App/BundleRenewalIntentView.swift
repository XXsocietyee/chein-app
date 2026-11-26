import SwiftUI

/// Unmounted candidate. Real-data consumer only: no fixture, transport or entry point is installed here.
/// Records an intention to renew and nothing else: the only controls are the three intent choices, an
/// optional note and a submit button (pinned by a source scan in BNDRenewalModelTests).
@MainActor struct BundleRenewalIntentView: View {
    @Bindable var model: BundleRenewalModel
    @State private var choice: BundleRenewalIntent = .maybe
    @State private var note = ""
    @State private var submitTick = 0
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
        // Native r2: an inset-grouped Form, a system inline title, explanations in footers.
        Form {
            if !model.current {
                Section { notice("clock.arrow.circlepath", "renewal.stale") }
            } else {
                currentBody
            }
        }
        .navigationTitle(text("renewal.title"))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
        .cyAnimation(value: model.phase)
        .cyAnimation(value: model.busy)
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    /// A system unavailable-content view with an SF Symbol; the identifier stays on the message text.
    private func notice(_ symbol: String, _ key: String, identifier: String? = nil) -> some View {
        ContentUnavailableView {
            Label {
                text(key).accessibilityIdentifier(identifier ?? key)
            } icon: {
                Image(systemName: symbol)
            }
        }
    }

    @ViewBuilder private var currentBody: some View {
        if model.busy {
            Section {
                HStack(spacing: CYSpacing.sm) {
                    ProgressView()
                    text("renewal.loading")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        if model.phase == .unavailable {
            Section {
                notice("wifi.slash", "renewal.unavailable", identifier: "bundleRenewal.unavailable")
            } footer: {
                text("renewal.intentOnly")
            }
        } else if model.failure != nil && model.phase != .outcomeUnknown {
            Section { notice("exclamationmark.triangle", "renewal.error", identifier: "bundleRenewal.error") }
        }
        if let latest = model.latest {
            Section {
                if let known = latest.knownIntent {
                    label(known).fixedSize(horizontal: false, vertical: true)
                } else {
                    text("renewal.intent.unrecognized").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let note = latest.note {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(verbatim: trimmed.isEmpty ? "—" : note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                text("renewal.latest")
            }
        } else if model.phase == .loaded {
            Section {
                text("renewal.none")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if model.phase == .outcomeUnknown {
            Section {
                text("renewal.unknown")
                    .fixedSize(horizontal: false, vertical: true)
            } footer: {
                text("renewal.intentOnly")
            }
            Section {
                Button { Task { await model.recover() } } label: { text("renewal.recover") }
                    .disabled(!model.canRecover)
                    .accessibilityLabel(text("renewal.recover"))
                Button { Task { await model.retry() } } label: { text("renewal.retry") }
                    .disabled(!model.canRetry)
                    .accessibilityLabel(text("renewal.retry"))
            }
        } else if model.phase != .unavailable {
            Section {
                Picker(selection: $choice) {
                    ForEach(BundleRenewalIntent.allCases, id: \.self) { intent in
                        label(intent).tag(intent)
                    }
                } label: {
                    text("renewal.choose")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                text("renewal.choose")
            }
            Section {
                TextField(text: $note, axis: .vertical) { text("renewal.note") }
                    .lineLimit(3...8)
                    .onChange(of: note) { _, value in
                        if value.count > BundleRenewalCommand.noteLimit {
                            note = String(value.prefix(BundleRenewalCommand.noteLimit))
                        }
                    }
            } footer: {
                text("renewal.intentOnly")
            }
            Section {
                Button {
                    submitTick += 1
                    Task { await model.submit(intent: choice, note: note) }
                } label: {
                    Label { text("renewal.submit") } icon: { Image(systemName: "paperplane.fill") }
                }
                .disabled(!model.canSubmit)
                .accessibilityLabel(text("renewal.submit"))
                .cyHaptic(.impactMedium, trigger: submitTick)
            }
        }
    }
}

#if DEBUG
#Preview("Renewal · player dark") {
    RenewalIntentPreviewHost(domain: .player)
}
#Preview("Renewal · merchant light") {
    RenewalIntentPreviewHost(domain: .merchant)
}

@MainActor private struct RenewalIntentPreviewHost: View {
    let domain: ThemeDomain
    @State private var model: BundleRenewalModel
    init(domain: ThemeDomain) {
        self.domain = domain
        let id = try! FreeExploreLaunchID(1)
        _model = State(initialValue: BundleRenewalModel(registrationID: id, service: BundleRenewalUnavailableService()))
    }
    var body: some View {
        NavigationStack { BundleRenewalIntentView(model: model) }
            .themeDomain(domain)
    }
}
#endif
