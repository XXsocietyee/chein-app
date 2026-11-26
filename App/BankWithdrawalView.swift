import SwiftUI

/// Reachable native form with an honest dormant state. The session host supplies a separately approved adapter when configured.
/// Restyle only: this screen does not turn withdrawal, payout, or virtual goods on. `adapter.isAvailable` stays the switch.
@MainActor struct BankWithdrawalView: View {
    let reader: WalletCommerceReader
    var adapter: BankWithdrawalAdapter? = nil
    var currentDocument: BankWithdrawalCurrentDocument? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    @Environment(\.analyticsEventClient) private var analytics
    @State private var draft = BankWithdrawalDraft()
    @State private var snapshot: BankWithdrawalDraft?
    @State private var review: BankWithdrawalReview?
    @State private var proof: BankWithdrawalProof?
    @State private var receipt: BankWithdrawalReceipt?
    @State private var issue: String?
    @State private var busy = false
    @State private var showReview = false
    @State private var confirmDiscard = false
    @State private var generation = UUID()
    @State private var commitPulse = 0
    @State private var warnPulse = 0
    @FocusState private var focused: Field?
    private enum Field: Hashable { case amount, name, bank, account, phone }
    private var available: Bool { adapter?.isAvailable == true }
    private var hasInput: Bool { draft != BankWithdrawalDraft() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                Cloud02ScreenHeader(title: "bank.withdrawal.title", seed: "bank-withdrawal", symbol: "lock.shield")
                if let receipt {
                    receiptBlock(receipt)
                } else {
                    notice
                    CYSectionHeader("bank.withdrawal.destination")
                    destinationFields
                    CYSectionHeader("bank.withdrawal.amount")
                    amountField
                    NavigationLink { WalletWithdrawalsView(reader: reader) } label: {
                        CYListRow("wallet.withdrawals", trailing: .chevron) { CYRowIcon(systemImage: "clock.arrow.circlepath") }
                    }
                    .buttonStyle(.plain)
                    .questifyHidesLinkIndicator()
                    .accessibilityLabel(Text("wallet.withdrawals"))
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyHeroScreen()
        .cyDomainPageBackground()
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if receipt == nil { reviewBar }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) { Button("bank.withdrawal.keyboardDone") { focused = nil } }
            ToolbarItem(placement: .topBarTrailing) { Button("action.close") {
                if hasInput || showReview { confirmDiscard = true } else { clear(); dismiss() }
            }.disabled(busy) }
        }
        .cySheet(isPresented: $confirmDiscard) {
            MemberBankWithdrawalDiscardConfirmSheet {
                confirmDiscard = false
                clear()
                dismiss()
            }
        }
        .cySheet(isPresented: $showReview, onDismiss: { snapshot = nil; review = nil; proof = nil }) {
            reviewSheet
                .cyPlayerSheetGlass()
        }
        .onChange(of: reader.scope) { _, _ in clear() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { clear() } }
        .onChange(of: showReview) { _, shown in if shown { commitPulse += 1 } }
        .onChange(of: issue) { _, new in if new != nil { warnPulse += 1 } }
        .cyHaptic(.impactMedium, trigger: commitPulse)
        .cyHaptic(.warning, trigger: warnPulse)
        .cyHaptic(.impactMedium, trigger: receipt?.applicationID) { old, new in old == nil && new != nil }
        .onDisappear { clear() }
        .cyPushedChrome(domain: .player)
        .appSwitcherPrivacyShield()
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if reader.scope == nil {
                statusLine("person.crop.circle.badge.exclamationmark", "wallet.login", tone: palette.textSecondary)
            } else if !available {
                statusLine("lock.fill", "bank.withdrawal.unavailable", tone: palette.textPrimary)
            }
            if adapter?.hasUnresolvedOutcome == true {
                statusLine("exclamationmark.triangle.fill", "bank.withdrawal.unresolved", tone: palette.warning)
            }
            Text("bank.withdrawal.privacy")
                .cyText(.bodyCompact)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let currentDocument {
                Link(destination: currentDocument.officialURL) {
                    HStack(spacing: CYSpacing.sm) {
                        CYRowIcon(systemImage: "doc.text")
                        Text("bank.withdrawal.currentDocument")
                            .cyText(.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: CYSpacing.sm)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.textTertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityLabel(Text("bank.withdrawal.currentDocument"))
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }

    private var destinationFields: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            labeled("bank.withdrawal.name") {
                TextField("bank.withdrawal.name", text: $draft.realname)
                    .focused($focused, equals: .name)
                    .textContentType(.name)
                    .accessibilityIdentifier("bank.withdrawal.name")
                    .accessibilityLabel(Text("bank.withdrawal.name"))
                    .submitLabel(.next)
                    .onSubmit { focused = .bank }
            }
            labeled("bank.withdrawal.bank") {
                TextField("bank.withdrawal.bank", text: $draft.bankName)
                    .focused($focused, equals: .bank)
                    .submitLabel(.next)
                    .onSubmit { focused = .account }
                    .accessibilityIdentifier("bank.withdrawal.bank")
                    .accessibilityLabel(Text("bank.withdrawal.bank"))
            }
            labeled("bank.withdrawal.account") {
                SecureField("bank.withdrawal.account", text: $draft.bankAccount)
                    .focused($focused, equals: .account)
                    .keyboardType(.numbersAndPunctuation)
                    .textContentType(.none)
                    .accessibilityIdentifier("bank.withdrawal.account")
                    .accessibilityLabel(Text("bank.withdrawal.account"))
            }
            labeled("bank.withdrawal.phone") {
                SecureField("bank.withdrawal.phone", text: $draft.mobilephone)
                    .focused($focused, equals: .phone)
                    .keyboardType(.phonePad)
                    .textContentType(.none)
                    .accessibilityIdentifier("bank.withdrawal.phone")
                    .accessibilityLabel(Text("bank.withdrawal.phone"))
            }
        }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .privacySensitive()
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            labeled("bank.withdrawal.amountCNY") {
                TextField("bank.withdrawal.amountCNY", text: $draft.amount)
                    .focused($focused, equals: .amount)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .accessibilityIdentifier("bank.withdrawal.amount")
                    .accessibilityLabel(Text("bank.withdrawal.amountCNY"))
            }
            Text("bank.withdrawal.feeArrivalUnknown")
                .cyText(.meta)
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reviewBar: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if let issue { issueLine(issue, identified: true) }
            Cloud02ActionButton(title: "bank.withdrawal.review", identifier: "bank.withdrawal.review", systemImage: "checkmark.circle", primary: true, isDisabled: busy || reader.scope == nil || adapter?.hasUnresolvedOutcome == true) {
                localReview()
            }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.top, CYSpacing.sm)
        .padding(.bottom, CYSpacing.sm)
        .background(palette.bgPage)
    }

    private func receiptBlock(_ receipt: BankWithdrawalReceipt) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityHidden(true)
                Text("bank.withdrawal.accepted")
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bank.withdrawal.receipt")
            }
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text("bank.withdrawal.applicationID")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: String(receipt.applicationID))
                    .cyText(.dataXL)
                    .monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(palette.warning)
                    .accessibilityHidden(true)
                Text("bank.withdrawal.notPaid")
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink { WalletWithdrawalsView(reader: reader) } label: {
                CYListRow("wallet.withdrawals", trailing: .chevron) { CYRowIcon(systemImage: "clock.arrow.circlepath") }
            }
            .buttonStyle(.plain)
            .questifyHidesLinkIndicator()
            .accessibilityLabel(Text("wallet.withdrawals"))
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }

    private var reviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xl) {
                    Cloud02ScreenHeader(title: "bank.withdrawal.checkDetails", seed: "bank-withdrawal-review", symbol: "lock.shield")
                    if let snapshot {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            CYListRow("bank.withdrawal.amountCNY", trailing: .value(amountText(snapshot))) { CYRowIcon(systemImage: "yensign.circle") }
                            CYListRow("bank.withdrawal.name", trailing: .value(cloud02Known(snapshot.realname))) { CYRowIcon(systemImage: "person") }
                            CYListRow("bank.withdrawal.bank", trailing: .value(cloud02Known(snapshot.bankName))) { CYRowIcon(systemImage: "building.columns") }
                            CYListRow("bank.withdrawal.account", trailing: .value(cloud02Known(snapshot.accountMask))) { CYRowIcon(systemImage: "creditcard") }
                            CYListRow("bank.withdrawal.phone", trailing: .value(cloud02Known(snapshot.phoneMask))) { CYRowIcon(systemImage: "phone") }
                        }
                        .privacySensitive()
                    }
                    if let proof {
                        CYSectionHeader("bank.withdrawal.serverConfirmation")
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            if proof.riskLevel == "WARNING" {
                                CYStatusChip("bank.withdrawal.serverWarning", tone: .warning, systemImage: "exclamationmark.triangle")
                            }
                            Text(verbatim: cloud02Known(proof.question))
                                .cyText(.body)
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: cloud02Known(proof.consequence))
                                .cyText(.bodyCompact)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(proof.safetyMessages.enumerated()), id: \.offset) { _, text in
                                Text(verbatim: cloud02Known(text))
                                    .cyText(.bodyCompact)
                                    .foregroundStyle(palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text("bank.withdrawal.feeArrivalUnknown")
                                .cyText(.meta)
                                .foregroundStyle(palette.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                            Cloud02ActionButton(title: "bank.withdrawal.confirmSubmit", identifier: "bank.withdrawal.confirmSubmit", systemImage: "paperplane.fill", primary: true, isDisabled: busy) {
                                Task { await submit(proof) }
                            }
                            Button("bank.withdrawal.reject", role: .destructive) { Task { await reject(proof) } }
                                .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                                .disabled(busy)
                                .accessibilityLabel(Text("bank.withdrawal.reject"))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            if adapter?.hasUnresolvedOutcome == true {
                                statusLine("exclamationmark.triangle.fill", "bank.withdrawal.unresolved", tone: palette.warning)
                            } else {
                                Text("bank.withdrawal.notSubmitted")
                                    .cyText(.body)
                                    .foregroundStyle(palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if snapshot != nil {
                                Text("bank.withdrawal.disclosure")
                                    .cyText(.bodyCompact)
                                    .foregroundStyle(palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if !available {
                                statusLine("lock.fill", "bank.withdrawal.unavailable", tone: palette.textPrimary)
                            }
                            Cloud02ActionButton(title: "bank.withdrawal.prepare", identifier: "bank.withdrawal.prepare", systemImage: "lock", primary: true, isDisabled: !available || busy || review == nil) {
                                Task { await prepare() }
                            }
                        }
                    }
                    if busy {
                        CYSkeleton().accessibilityLabel(Text("wallet.loading"))
                        Text("wallet.loading")
                            .cyText(.meta)
                            .foregroundStyle(palette.textSecondary)
                    }
                    if let issue { issueLine(issue, identified: false) }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            }
            .cyHeroScreen()
            .cyDomainPageBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel") {
                    if let proof { Task { await reject(proof) } } else { clear() }
                }.disabled(busy)
            } }
        }
        .themeDomain(.player)
        .interactiveDismissDisabled(true)
        .presentationDetents([.large])
    }

    private func labeled<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(title)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            content()
                .cyText(.body)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
    }

    private func statusLine(_ symbol: String, _ key: LocalizedStringKey, tone: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tone)
                .accessibilityHidden(true)
            Text(key)
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    private func issueLine(_ key: String, identified: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(palette.danger)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(key))
                .cyText(.body)
                .foregroundStyle(palette.danger)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Cloud02Identifier(identified ? "bank.withdrawal.issue" : nil))
        }
        .accessibilityElement(children: .contain)
    }

    /// A validated amount stays as written, including a real zero. An amount that did not validate is unknown.
    private func amountText(_ draft: BankWithdrawalDraft) -> String {
        guard let value = try? draft.validatedAmount() else { return "—" }
        let number = NSDecimalNumber(decimal: value)
        return number == .notANumber ? "—" : number.stringValue
    }

    private func localReview() {
        focused = nil; issue = nil
        do {
            _ = try draft.validatedAmount()
            snapshot = draft
            if let adapter { review = try adapter.review(draft) }
            showReview = true
        } catch { issue = errorKey(error) }
    }
    private func prepare() async {
        guard let adapter, let review, !busy else { return }
        busy = true; issue = nil; let ticket = generation
        defer { if ticket == generation { busy = false } }
        do {
            let value = try await adapter.prepare(review)
            guard ticket == generation else { return }; proof = value
        } catch {
            guard ticket == generation else { return }; issue = errorKey(error)
        }
    }
    private func submit(_ value: BankWithdrawalProof) async {
        guard let adapter, !busy else { return }
        busy = true; issue = nil; let ticket = generation
        defer { if ticket == generation { busy = false } }
        do {
            let result = try await adapter.submit(value)
            guard ticket == generation else { return }
            var properties: [String: PlayWireValue] = [:]
            if let amount = MiniProgramAnalytics.amount(value.amount) { properties["amount"] = amount }
            MiniProgramAnalytics.track(analytics, "withdrawal_submit", bizType: "withdrawal",
                bizID: MiniProgramAnalytics.bizID(result.applicationID), pagePath: "/subpackageA/pages/assetcenter/earnings/index", properties: properties)
            clear(); receipt = result
        } catch {
            guard ticket == generation else { return }
            proof = nil; review = nil; snapshot = nil; draft = .init()
            issue = adapter.hasUnresolvedOutcome ? "bank.withdrawal.unresolved" : errorKey(error)
        }
    }
    private func reject(_ value: BankWithdrawalProof) async {
        guard let adapter, !busy else { return }
        busy = true; issue = nil; let ticket = generation
        defer { if ticket == generation { busy = false } }
        do { try await adapter.reject(value); guard ticket == generation else { return }; clear() }
        catch { guard ticket == generation else { return }; proof = nil; review = nil; issue = errorKey(error) }
    }
    private func clear() {
        generation = UUID(); focused = nil; draft = .init(); snapshot = nil; review = nil; proof = nil
        receipt = nil; issue = nil; busy = false; showReview = false; adapter?.discardLocalInput()
    }
    private func errorKey(_ error: Error) -> String {
        if adapter?.hasUnresolvedOutcome == true { return "bank.withdrawal.unresolved" }
        if (error as? APIError) == .unauthorized { return "wallet.login" }
        switch error as? BankWithdrawalFailure {
        case .invalidInput: return "bank.withdrawal.invalidInput"
        case .consentRequired: return "bank.withdrawal.consentRequired"
        case .expired: return "bank.withdrawal.expired"
        case .unavailable: return "bank.withdrawal.unavailable"
        case .staleSession: return "wallet.login"
        case .serverBlocked: return "bank.withdrawal.serverBlocked"
        default: return "wallet.failed"
        }
    }
}
