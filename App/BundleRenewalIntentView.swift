import SwiftUI

/// Unmounted candidate. Real-data consumer only: no fixture, transport or entry point is installed here.
/// Records an intention to renew and nothing else: the only controls are the three intent choices, an
/// optional note and a submit button (pinned by a source scan in BNDRenewalModelTests).
@MainActor struct BundleRenewalIntentView: View {
    @Bindable var model: BundleRenewalModel
    @State private var choice: BundleRenewalIntent = .maybe
    @State private var note = ""
    @State private var submitTick = 0
    @ScaledMetric(relativeTo: .largeTitle) private var artHeight: CGFloat = 112
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    private func copy(_ key: String) -> String {
        String(localized: String.LocalizationValue(stringLiteral: key), table: table)
    }
    private func label(_ intent: BundleRenewalIntent) -> Text {
        switch intent {
        case .willRenew: return text("renewal.intent.WILL_RENEW")
        case .maybe: return text("renewal.intent.MAYBE")
        case .no: return text("renewal.intent.NO")
        }
    }
    private func intentKey(_ intent: BundleRenewalIntent) -> String {
        switch intent {
        case .willRenew: return "renewal.intent.WILL_RENEW"
        case .maybe: return "renewal.intent.MAYBE"
        case .no: return "renewal.intent.NO"
        }
    }

    var body: some View {
        // Native restyle r1 (spec §3.2): an inset-grouped Form, a system inline title, explanations in footers.
        Form {
            Section {
                CYCoverArt(seed: "renewal-intent", symbol: "arrow.triangle.2.circlepath", showsDebugLabel: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: artHeight)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
                    .accessibilityHidden(true)
            }
            .cyCardRow()
            if !model.current {
                Section { CYEmptyState(systemImage: "clock.arrow.circlepath", "renewal.stale", tableName: table) }
                    .cyCardRow()
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
    }

    @ViewBuilder private var currentBody: some View {
        if model.busy {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CYSkeleton().accessibilityHidden(true)
                    text("renewal.loading")
                        .cyText(.meta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        if model.phase == .unavailable {
            Section {
                CYEmptyState(systemImage: "wifi.slash", "renewal.unavailable", tableName: table, messageIdentifier: "bundleRenewal.unavailable")
            } footer: {
                text("renewal.intentOnly")
            }
            .cyCardRow()
        } else if model.failure != nil && model.phase != .outcomeUnknown {
            Section { CYEmptyState(systemImage: "exclamationmark.triangle", "renewal.error", tableName: table, messageIdentifier: "bundleRenewal.error") }
                .cyCardRow()
        }
        if let latest = model.latest {
            Section {
                if let known = latest.knownIntent {
                    label(known).cyText(.body).fixedSize(horizontal: false, vertical: true)
                } else {
                    text("renewal.intent.unrecognized").cyText(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let note = latest.note {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(verbatim: trimmed.isEmpty ? "—" : note)
                        .cyText(.meta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                text("renewal.latest")
            }
        } else if model.phase == .loaded {
            Section {
                text("renewal.none")
                    .cyText(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if model.phase == .outcomeUnknown {
            Section {
                text("renewal.unknown")
                    .cyText(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } footer: {
                text("renewal.intentOnly")
            }
            Section {
                VStack(spacing: CYSpacing.md) {
                    CYPillButton("renewal.recover", tableName: table, action: { Task { await model.recover() } })
                        .disabled(!model.canRecover)
                        .accessibilityLabel(text("renewal.recover"))
                    CYPillButton("renewal.retry", style: .secondary, tableName: table, action: { Task { await model.retry() } })
                        .disabled(!model.canRetry)
                        .accessibilityLabel(text("renewal.retry"))
                }
            }
            .cyCardRow()
        } else if model.phase != .unavailable {
            Section {
                ForEach(BundleRenewalIntent.allCases, id: \.self) { intent in
                    CYChoiceRow(label: copy(intentKey(intent)), selected: choice == intent) { choice = intent }
                }
            } header: {
                text("renewal.choose")
            }
            Section {
                TextField(text: $note, axis: .vertical) { text("renewal.note") }
                    .cyText(.body)
                    .onChange(of: note) { _, value in
                        if value.count > BundleRenewalCommand.noteLimit {
                            note = String(value.prefix(BundleRenewalCommand.noteLimit))
                        }
                    }
            } footer: {
                text("renewal.intentOnly")
            }
            Section {
                CYPillButton("renewal.submit", systemImage: "paperplane.fill", tableName: table) {
                    submitTick += 1
                    Task { await model.submit(intent: choice, note: note) }
                }
                .disabled(!model.canSubmit)
                .accessibilityLabel(text("renewal.submit"))
                .cyHaptic(.impactMedium, trigger: submitTick)
            }
            .cyCardRow()
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
