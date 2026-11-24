import SwiftUI

/// IWP-8c sender screen. Unmounted: no route, entry, lease or composition references it.
/// The one-time code is shown from the model's in-memory value only; this view keeps no copy of it
/// (no @State / @SceneStorage / @AppStorage), and leaving the screen asks the model to discard it.
@MainActor struct BundleTransferSendView: View {
    @ObservedObject var model: BundleTransferSendModel
    let registrationID: FreeExploreLaunchID
    @State private var phone = ""
    @State private var channel: BundleTransferChannel = .inApp
    @State private var confirming = false
    @Environment(\.locale) private var locale
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        // Native restyle r1 (spec §3.2): an inset-grouped Form with a system inline title; the CTA stays sticky.
        Form {
            phaseBody
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomAction }
        .navigationTitle(Text(verbatim: screenTitle))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
        .cyAnimation(value: model.phase)
        .cyHaptic(.success, trigger: model.phase) { _, new in
            if case .shown = new { return true }
            return false
        }
        .confirmationDialog(Text(LocalizedStringKey("transfer.confirm.title"), tableName: table),
                            isPresented: $confirming, titleVisibility: .visible) {
            Button(role: .destructive) {
                let number = phone, selected = channel
                Task { await model.confirm(phone: number, channel: selected) }
            } label: { text("transfer.confirm.action") }
        } message: { text("transfer.confirm.message") }
        .task { await model.loadPreview(registrationID: registrationID) }
        .onDisappear { model.leave() }
    }

    /// Page title. Catalog key `ui.cloud05.transfer.title` (docs/release/ui-strings-cloud-05.json).
    /// A missing catalog entry shows the bilingual copy, never the dotted key.
    private var screenTitle: String {
        Cloud05Copy.resolved("ui.cloud05.transfer.title", en: "Transfer a bundle", zh: "转赠套餐", locale: locale)
    }

    @ViewBuilder private var phaseBody: some View {
        switch model.phase {
        case .idle, .loadingPreview:
            Section { progressRow("transfer.loading") }
        case .unavailable:
            Section { CYEmptyState(systemImage: "arrow.triangle.2.circlepath", "transfer.unavailable", tableName: table, messageIdentifier: "bundleTransfer.unavailable") }
                .cyCardRow()
        case .ineligible:
            Section { CYEmptyState(systemImage: "exclamationmark.triangle", "transfer.ineligible", tableName: table, messageIdentifier: "bundleTransfer.ineligible", kind: .failure) }
                .cyCardRow()
        case .ready(let preview):
            readyBody(preview)
        case .sending:
            Section { progressRow("transfer.sending") }
        case .shown:
            codeBody
        case .recovered:
            recoveredBody
        case .revoked:
            if let state = model.display { Section { stateChip(state) } }
        case .outcomeUnknown:
            Section {
                text("transfer.unknown")
                    .cyText(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failed(let code):
            Section {
                CYEmptyState(systemImage: "exclamationmark.triangle", "transfer.error", tableName: table, messageIdentifier: "bundleTransfer.error", kind: .failure)
            } footer: {
                if let code { Text(verbatim: Cloud05Copy.server(code)) }
            }
            .cyCardRow()
        }
    }

    private func progressRow(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYSkeleton()
            text(key)
                .cyText(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text(key))
    }

    @ViewBuilder private func readyBody(_ preview: BundleTransferPreview) -> some View {
        Section {
            if preview.impactLines.isEmpty {
                Text(verbatim: "—")
                    .cyText(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(preview.impactLines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: Cloud05Copy.server(line))
                        .cyText(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            text("transfer.impact")
        }
        Section {
            TextField(text: $phone) { text("transfer.phone") }
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .cyText(.body)
                .privacySensitive()
        } header: {
            text("transfer.phone")
        }
        if preview.offersSMS {
            Section {
                Picker(selection: $channel) {
                    text("transfer.channel.inApp").tag(BundleTransferChannel.inApp)
                    text("transfer.channel.sms").tag(BundleTransferChannel.sms)
                } label: { text("transfer.channel") }
                .pickerStyle(.segmented)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityLabel(text("transfer.channel"))
            } header: {
                text("transfer.channel")
            }
        }
    }

    private var codeBody: some View {
        Section {
            if let code = model.oneTimeCode {
                Text(verbatim: code.reveal())
                    .cyText(.dataXL)
                    .monospacedDigit()
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bundleTransfer.code")
                    .accessibilityLabel(text("transfer.claim.code"))
                    .accessibilityValue(Text(verbatim: code.reveal()))
                    .privacySensitive()
            } else {
                Text(verbatim: "—")
                    .cyText(.dataXL)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("bundleTransfer.code")
            }
            if let state = model.display { stateChip(state) }
        } footer: {
            text("transfer.code.once")
        }
    }

    private var recoveredBody: some View {
        Section {
            text("transfer.code.unavailable")
                .cyText(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let state = model.display { stateChip(state) }
        }
    }

    @ViewBuilder private var bottomAction: some View {
        switch model.phase {
        case .ready:
            CYPillButton("transfer.confirm", systemImage: "paperplane.fill", tableName: table) { confirming = true }
                .disabled(phone.isEmpty)
                .accessibilityLabel(text("transfer.confirm"))
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.md)
                .background(.bar)
        case .shown, .recovered:
            Button { Task { await model.revoke() } } label: { text("transfer.revoke") }
                .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                .accessibilityLabel(text("transfer.revoke"))
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.md)
                .background(.bar)
        case .outcomeUnknown:
            CYPillButton("transfer.recover", systemImage: "arrow.clockwise", tableName: table) { Task { await model.recover() } }
                .accessibilityLabel(text("transfer.recover"))
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.md)
                .background(.bar)
        default:
            EmptyView()
        }
    }

    private func stateChip(_ state: BundleTransferDisplayState) -> some View {
        let key: String
        let tone: CYStatusTone
        let symbol: String
        switch state {
        case .sent: key = "transfer.state.sent"; tone = .info; symbol = "paperplane.fill"
        case .pending: key = "transfer.state.pending"; tone = .warning; symbol = "clock"
        case .claimed: key = "transfer.state.claimed"; tone = .success; symbol = "checkmark"
        case .expired: key = "transfer.state.expired"; tone = .warning; symbol = "clock.badge.exclamationmark"
        case .revoked: key = "transfer.state.revoked"; tone = .danger; symbol = "xmark"
        case .unknown: key = "transfer.state.unknown"; tone = .neutral; symbol = "questionmark"
        }
        return CYStatusChip(verbatim: Cloud05Copy.bundle(key), tone: tone, systemImage: symbol)
            .accessibilityLabel(text(key))
    }
}

/// Presentation copy for this screen. Server text that is a dotted catalog key is never shown raw.
private enum Cloud05Copy {
    static func resolved(_ key: String, en: String, zh: String, locale: Locale) -> String {
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key))
        if resolved == key || resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CYKitCopy(locale: locale)(en, zh)
        }
        return resolved
    }

    static func bundle(_ key: String) -> String {
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key), table: "BundleCommerce")
        if resolved == key || resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "—" }
        return resolved
    }

    static func server(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "—" }
        if trimmed.range(of: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#, options: .regularExpression) != nil {
            return "—"
        }
        return trimmed
    }
}
