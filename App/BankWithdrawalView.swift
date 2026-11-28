import SwiftUI

/// Reachable native form with an honest dormant state. The session host supplies a separately approved adapter when configured.
/// Restyle only: this screen does not turn withdrawal, payout, or virtual goods on. `adapter.isAvailable` stays the switch.
@MainActor struct BankWithdrawalView: View {
    let reader: WalletCommerceReader
    var adapter: BankWithdrawalAdapter? = nil
    var currentDocument: BankWithdrawalCurrentDocument? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
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
        // G-060 (design P1): system Form chrome (Wallet › Transfer to Bank). Same fields, order, identifiers,
        // gates and clearing; the hero header, card backgrounds, CY rows/chips/skeleton and sheet glass are gone.
        Form {
            if let receipt {
                receiptSections(receipt)
            } else {
                noticeSection
                Section {
                    destinationFields
                } header: {
                    Text("bank.withdrawal.destination")
                }
                Section {
                    amountField
                } header: {
                    Text("bank.withdrawal.amount")
                } footer: {
                    Text("bank.withdrawal.feeArrivalUnknown")
                }
                withdrawalsSection
            }
        }
        .navigationTitle(Text("bank.withdrawal.title"))
        .navigationBarTitleDisplayMode(.inline)
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
        }
        .onChange(of: reader.scope) { _, _ in clear() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { clear() } }
        .onChange(of: showReview) { _, shown in if shown { commitPulse += 1 } }
        .onChange(of: issue) { _, new in if new != nil { warnPulse += 1 } }
        .sensoryFeedback(.impact(weight: .medium), trigger: commitPulse)
        .sensoryFeedback(.warning, trigger: warnPulse)
        .sensoryFeedback(.success, trigger: receipt?.applicationID, condition: CYHapticTransition.becameSet)
        .onDisappear { clear() }
        .cyPushedChrome(domain: .player)
        .appSwitcherPrivacyShield()
    }

    private var noticeSection: some View {
        Section {
            if reader.scope == nil {
                statusLine("person.crop.circle.badge.exclamationmark", "wallet.login", tint: .secondary)
            } else if !available {
                statusLine("lock.fill", "bank.withdrawal.unavailable", tint: .secondary)
            }
            if adapter?.hasUnresolvedOutcome == true {
                statusLine("exclamationmark.triangle.fill", "bank.withdrawal.unresolved", tint: .orange)
            }
            if let currentDocument {
                Link(destination: currentDocument.officialURL) {
                    Label("bank.withdrawal.currentDocument", systemImage: "doc.text")
                }
                .accessibilityLabel(Text("bank.withdrawal.currentDocument"))
            }
        } footer: {
            Text("bank.withdrawal.privacy")
        }
    }

    private var withdrawalsSection: some View {
        Section {
            NavigationLink { WalletWithdrawalsView(reader: reader) } label: {
                Label("wallet.withdrawals", systemImage: "clock.arrow.circlepath")
            }
            .accessibilityLabel(Text("wallet.withdrawals"))
        }
    }

    @ViewBuilder private var destinationFields: some View {
        Group {
            TextField("bank.withdrawal.name", text: $draft.realname)
                .focused($focused, equals: .name)
                .textContentType(.name)
                .accessibilityIdentifier("bank.withdrawal.name")
                .accessibilityLabel(Text("bank.withdrawal.name"))
                .submitLabel(.next)
                .onSubmit { focused = .bank }
            TextField("bank.withdrawal.bank", text: $draft.bankName)
                .focused($focused, equals: .bank)
                .submitLabel(.next)
                .onSubmit { focused = .account }
                .accessibilityIdentifier("bank.withdrawal.bank")
                .accessibilityLabel(Text("bank.withdrawal.bank"))
            SecureField("bank.withdrawal.account", text: $draft.bankAccount)
                .focused($focused, equals: .account)
                .keyboardType(.numbersAndPunctuation)
                .textContentType(.none)
                .accessibilityIdentifier("bank.withdrawal.account")
                .accessibilityLabel(Text("bank.withdrawal.account"))
            SecureField("bank.withdrawal.phone", text: $draft.mobilephone)
                .focused($focused, equals: .phone)
                .keyboardType(.phonePad)
                .textContentType(.none)
                .accessibilityIdentifier("bank.withdrawal.phone")
                .accessibilityLabel(Text("bank.withdrawal.phone"))
        }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .privacySensitive()
    }

    private var amountField: some View {
        TextField("bank.withdrawal.amountCNY", text: $draft.amount)
            .focused($focused, equals: .amount)
            .keyboardType(.decimalPad)
            .monospacedDigit()
            .accessibilityIdentifier("bank.withdrawal.amount")
            .accessibilityLabel(Text("bank.withdrawal.amountCNY"))
    }

    private var reviewBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let issue { issueLine(issue, identified: true) }
            Button {
                localReview()
            } label: {
                Label("bank.withdrawal.review", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(busy || reader.scope == nil || adapter?.hasUnresolvedOutcome == true)
            .accessibilityIdentifier("bank.withdrawal.review")
            .accessibilityLabel(Text("bank.withdrawal.review"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    @ViewBuilder private func receiptSections(_ receipt: BankWithdrawalReceipt) -> some View {
        Section {
            Label {
                Text("bank.withdrawal.accepted")
                    .accessibilityIdentifier("bank.withdrawal.receipt")
            } icon: {
                Image(systemName: "clock.badge.checkmark").foregroundStyle(.secondary)
            }
            LabeledContent {
                Text(verbatim: String(receipt.applicationID))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            } label: {
                Text("bank.withdrawal.applicationID")
            }
            .accessibilityElement(children: .combine)
            Label {
                Text("bank.withdrawal.notPaid")
            } icon: {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            }
        }
        withdrawalsSection
    }

    private var reviewSheet: some View {
        NavigationStack {
            Form {
                if let snapshot {
                    Section {
                        LabeledContent { Text(verbatim: amountText(snapshot)).monospacedDigit() } label: {
                            Label("bank.withdrawal.amountCNY", systemImage: "yensign.circle")
                        }
                        LabeledContent { Text(verbatim: cloud02Known(snapshot.realname)) } label: {
                            Label("bank.withdrawal.name", systemImage: "person")
                        }
                        LabeledContent { Text(verbatim: cloud02Known(snapshot.bankName)) } label: {
                            Label("bank.withdrawal.bank", systemImage: "building.columns")
                        }
                        LabeledContent { Text(verbatim: cloud02Known(snapshot.accountMask)) } label: {
                            Label("bank.withdrawal.account", systemImage: "creditcard")
                        }
                        LabeledContent { Text(verbatim: cloud02Known(snapshot.phoneMask)) } label: {
                            Label("bank.withdrawal.phone", systemImage: "phone")
                        }
                    }
                    .privacySensitive()
                }
                if let proof {
                    Section {
                        if proof.riskLevel == "WARNING" {
                            statusLine("exclamationmark.triangle", "bank.withdrawal.serverWarning", tint: .orange)
                        }
                        Text(verbatim: cloud02Known(proof.question))
                        Text(verbatim: cloud02Known(proof.consequence))
                            .foregroundStyle(.secondary)
                        ForEach(Array(proof.safetyMessages.enumerated()), id: \.offset) { _, text in
                            Text(verbatim: cloud02Known(text))
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("bank.withdrawal.serverConfirmation")
                    } footer: {
                        Text("bank.withdrawal.feeArrivalUnknown")
                    }
                    Section {
                        Button {
                            Task { await submit(proof) }
                        } label: {
                            Label("bank.withdrawal.confirmSubmit", systemImage: "paperplane.fill").fontWeight(.semibold)
                        }
                        .disabled(busy)
                        .accessibilityIdentifier("bank.withdrawal.confirmSubmit")
                        .accessibilityLabel(Text("bank.withdrawal.confirmSubmit"))
                        Button("bank.withdrawal.reject", role: .destructive) { Task { await reject(proof) } }
                            .disabled(busy)
                            .accessibilityLabel(Text("bank.withdrawal.reject"))
                    }
                } else {
                    Section {
                        if adapter?.hasUnresolvedOutcome == true {
                            statusLine("exclamationmark.triangle.fill", "bank.withdrawal.unresolved", tint: .orange)
                        } else {
                            Text("bank.withdrawal.notSubmitted")
                        }
                        if snapshot != nil {
                            Text("bank.withdrawal.disclosure")
                                .foregroundStyle(.secondary)
                        }
                        if !available {
                            statusLine("lock.fill", "bank.withdrawal.unavailable", tint: .secondary)
                        }
                    }
                    Section {
                        Button {
                            Task { await prepare() }
                        } label: {
                            Label("bank.withdrawal.prepare", systemImage: "lock").fontWeight(.semibold)
                        }
                        .disabled(!available || busy || review == nil)
                        .accessibilityIdentifier("bank.withdrawal.prepare")
                        .accessibilityLabel(Text("bank.withdrawal.prepare"))
                    }
                }
                if busy {
                    Section {
                        ProgressView { Text("wallet.loading") }
                            .frame(maxWidth: .infinity)
                    }
                }
                if let issue {
                    Section { issueLine(issue, identified: false) }
                }
            }
            .navigationTitle(Text("bank.withdrawal.checkDetails"))
            .navigationBarTitleDisplayMode(.inline)
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

    private func statusLine(_ symbol: String, _ key: LocalizedStringKey, tint: Color) -> some View {
        Label {
            Text(key)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
    }

    private func issueLine(_ key: String, identified: Bool) -> some View {
        Label {
            Text(LocalizedStringKey(key))
                .foregroundStyle(.red)
                .modifier(Cloud02Identifier(identified ? "bank.withdrawal.issue" : nil))
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
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
