import SwiftUI

/// Unmounted candidate. Real-data consumer only: no fixture, transport or entry point is installed here.
/// Records an intention to renew and nothing else: the only controls are the three intent choices, an
/// optional note and a submit button (pinned by a source scan in BNDRenewalModelTests).
@MainActor struct BundleRenewalIntentView: View {
    @Bindable var model: BundleRenewalModel
    @State private var choice: BundleRenewalIntent = .maybe
    @State private var note = ""
    @State private var submitTick = 0
    @Environment(\.cyPalette) private var palette
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
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader(LocalizedStringKey("renewal.title"), tableName: table) {
                    CYCoverArt(seed: "renewal-intent", symbol: "arrow.triangle.2.circlepath", showsDebugLabel: false)
                        .frame(maxWidth: .infinity)
                        .frame(height: artHeight)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .accessibilityHidden(true)
                }
                if !model.current {
                    CYEmptyState(systemImage: "clock.arrow.circlepath", "renewal.stale", tableName: table)
                } else {
                    currentBody
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.xxl)
        }
        .cyDomainPageBackground()
        .themeDomain(.player)
        .cyHeroScreen()
        .cyAnimation(value: model.phase)
        .cyAnimation(value: model.busy)
        .task { await model.load() }
    }

    private var currentBody: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxl) {
        CYNoteBanner(text: text("renewal.intentOnly"), symbol: "info.circle", tone: .info)
        if model.busy {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYSkeleton().accessibilityHidden(true)
                text("renewal.loading")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        if model.phase == .unavailable {
            CYEmptyState(systemImage: "wifi.slash", "renewal.unavailable", tableName: table, messageIdentifier: "bundleRenewal.unavailable")
        } else if model.failure != nil && model.phase != .outcomeUnknown {
            CYEmptyState(systemImage: "exclamationmark.triangle", "renewal.error", tableName: table, messageIdentifier: "bundleRenewal.error")
        }
        if let latest = model.latest {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                text("renewal.latest")
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let known = latest.knownIntent {
                    label(known).cyText(.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                } else {
                    text("renewal.intent.unrecognized").cyText(.body).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                if let note = latest.note {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(verbatim: trimmed.isEmpty ? "—" : note)
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.lg)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        } else if model.phase == .loaded {
            text("renewal.none")
                .cyText(.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if model.phase == .outcomeUnknown {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                text("renewal.unknown")
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("renewal.recover", tableName: table, action: { Task { await model.recover() } })
                    .disabled(!model.canRecover)
                    .accessibilityLabel(text("renewal.recover"))
                CYPillButton("renewal.retry", style: .secondary, tableName: table, action: { Task { await model.retry() } })
                    .disabled(!model.canRetry)
                    .accessibilityLabel(text("renewal.retry"))
            }
        } else if model.phase != .unavailable {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                text("renewal.choose")
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: CYSpacing.sm) {
                    ForEach(BundleRenewalIntent.allCases, id: \.self) { intent in
                        CYChoiceRow(label: copy(intentKey(intent)), selected: choice == intent) { choice = intent }
                    }
                }
                TextField(text: $note, axis: .vertical) { text("renewal.note") }
                    .cyText(.body)
                    .padding(CYSpacing.md)
                    .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .onChange(of: note) { _, value in
                        if value.count > BundleRenewalCommand.noteLimit {
                            note = String(value.prefix(BundleRenewalCommand.noteLimit))
                        }
                    }
                CYPillButton("renewal.submit", systemImage: "paperplane.fill", tableName: table) {
                    submitTick += 1
                    Task { await model.submit(intent: choice, note: note) }
                }
                .disabled(!model.canSubmit)
                .accessibilityLabel(text("renewal.submit"))
                .cyHaptic(.impactMedium, trigger: submitTick)
            }
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
