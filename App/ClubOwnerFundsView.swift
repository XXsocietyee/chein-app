import SwiftUI

struct ClubOwnerFundsContext {
    var reader: (any ClubOwnerFundsReading)? = nil
    var isCurrent: () -> Bool = { false }
    var support: (() -> AnyView)? = nil
}
private struct ClubOwnerFundsKey: EnvironmentKey {
    static let defaultValue = ClubOwnerFundsContext()
}
extension EnvironmentValues {
    var clubOwnerFunds: ClubOwnerFundsContext {
        get { self[ClubOwnerFundsKey.self] }
        set { self[ClubOwnerFundsKey.self] = newValue }
    }
}
@MainActor extension AppSession {
    func clubOwnerFundsContext() -> ClubOwnerFundsContext {
        let reader = walletHistoryReader, supportReader = withdrawalSupportReader
        let identity = clubIdentity, revision = walletHistoryViewIdentity
        return .init(reader: reader, isCurrent: { [weak self, weak reader] in
            guard let self, let reader else { return false }
            return self.clubIdentity == identity && self.walletHistoryViewIdentity == revision &&
                self.walletHistoryReader === reader
        }, support: {
            AnyView(WithdrawalSupportContactView().environment(\.withdrawalSupportReader, supportReader))
        })
    }
}

@MainActor final class ClubOwnerFundsWorkflow: ObservableObject {
    @Published private(set) var funds: WalletFundsStages?
    @Published private(set) var loadedScope: WalletCommerceScope?
    @Published private(set) var loading = false
    @Published private(set) var failure: String?
    @Published private(set) var contactPresented = false
    private var generation: UInt64 = 0
    private var liveCheck: (() -> Bool)?
    var revision: UInt64 { generation }
    var availability: ClubOwnerFundsAvailability { .init(funds) }
    var contactIsCurrent: Bool { contactPresented && liveCheck?() == true }

    func load(target: ClubOwnerFundsTarget, access: any ClubGovernanceAccess,
              context: ClubOwnerFundsContext, sourceIsCurrent: @escaping () -> Bool, expectedGeneration: UInt64? = nil) async {
        guard expectedGeneration == nil || expectedGeneration == generation, !loading else { return }
        generation &+= 1; let ticket = generation
        funds = nil; loadedScope = nil; failure = nil; liveCheck = nil; contactPresented = false; loading = true
        do {
            guard let reader = context.reader, reader.isConfigured, let scope = reader.scope,
                  scope.accountID == target.context.identity?.accountID,
                  !scope.namespace.isEmpty, scope.namespace == access.storageNamespace else { throw WalletCommerceSafetyError.unavailable }
            let check: () throws -> Void = { [weak self] in
                guard let self, self.generation == ticket, !Task.isCancelled, sourceIsCurrent(), context.isCurrent(),
                      access.isConfigured, access.identity == target.context.identity,
                      access.authorizationGeneration == target.context.authorizationGeneration,
                      target.context.accessIdentity == ObjectIdentifier(access),
                      access.storageNamespace == scope.namespace, reader.isConfigured, reader.scope == scope else {
                    throw ClubGovernanceFailure.targetChanged
                }
            }
            try check()
            let before = try await access.read(.settlement, scope: target.context.scope, options: [:], check: check)
            try check(); guard target.accepts(before) else { throw ClubGovernanceFailure.forbidden }
            let value = try await reader.readClubOwnerFunds()
            try check()
            // Ownership/finance access can change while the wallet request is in flight.
            let after = try await access.read(.settlement, scope: target.context.scope, options: [:], check: check)
            try check(); guard target.accepts(after) else { throw ClubGovernanceFailure.forbidden }
            funds = value; loadedScope = scope; loading = false
            liveCheck = { (try? check()) != nil }
        } catch {
            guard generation == ticket else { return }
            funds = nil; loadedScope = nil; contactPresented = false; loading = false; liveCheck = nil
            if let error = error as? ClubGovernanceFailure { failure = error.localizationKey }
            else if (error as? WalletCommerceSafetyError) == .unavailable { failure = "wallet.unavailable" }
            else { failure = "wallet.failed" }
        }
    }
    func openContact(target: ClubOwnerFundsTarget, access: any ClubGovernanceAccess,
                     context: ClubOwnerFundsContext, sourceIsCurrent: @escaping () -> Bool, expectedGeneration: UInt64? = nil) async {
        guard expectedGeneration == nil || expectedGeneration == generation,
              !loading, target.hasSettlementRows, availability == .positive, context.support != nil else { return }
        // The displayed amount cannot authorize even a contact route: read it again.
        await load(target: target, access: access, context: context, sourceIsCurrent: sourceIsCurrent)
        guard availability == .positive, liveCheck?() == true else { return }
        contactPresented = true
    }
    func closeContact() { contactPresented = false }
    func invalidate() {
        generation &+= 1; funds = nil; loadedScope = nil; failure = nil
        contactPresented = false; loading = false; liveCheck = nil
    }
}

/// Stable owner for the current page's read-only funds and contact presentation.
@MainActor final class ClubOwnerFundsParent: ObservableObject {
    struct Source: Equatable {
        let target: ClubOwnerFundsTarget
        let readerID: ObjectIdentifier?
        let walletScope: WalletCommerceScope?
        let generation: UInt64
        let namespace: String
    }
    struct Ticket: Equatable { let attachment: UUID; let source: Source; let revision: UUID }
    struct Contact: Identifiable, Equatable {
        let id = UUID()
        let ticket: Ticket
    }
    @Published private(set) var workflow = ClubOwnerFundsWorkflow()
    @Published private(set) var attachment: UUID?
    @Published private(set) var source: Source?
    @Published private(set) var contact: Contact?
    @Published private(set) var isPresented = false
    private(set) var visible = false
    private(set) var needsRead = true
    private var revision = UUID()
    var retainsContact: Bool { contact != nil }
    func appear() { if attachment == nil { attachment = UUID() }; visible = true }
    func synchronize(_ value: Source?) {
        guard source != value else { return }
        invalidate(); source = value
    }
    func hide() {
        visible = false
        if contact == nil { invalidate() }
    }
    @discardableResult func depart(_ expected: UUID) -> Bool {
        guard attachment == expected else { return false }
        invalidate(); attachment = nil; source = nil; visible = false; return true
    }
    func background() { invalidate() }
    private func invalidate() {
        revision = UUID(); contact = nil; isPresented = false; needsRead = true
        workflow.invalidate(); workflow = ClubOwnerFundsWorkflow()
    }
    func ticket(current: Source?, active: Bool, otherPresented: Bool) -> Ticket? {
        guard visible, active, !otherPresented, contact == nil, let attachment, let source, source == current else { return nil }
        return .init(attachment: attachment, source: source, revision: revision)
    }
    private func matches(_ ticket: Ticket, current: Source?, active: Bool) -> Bool {
        active && attachment == ticket.attachment && revision == ticket.revision && source == ticket.source && current == ticket.source
    }
    func accepts(_ ticket: Ticket, current: Source?, active: Bool, otherPresented: Bool) -> Bool {
        visible && !otherPresented && contact == nil && matches(ticket, current: current, active: active)
    }
    func load(_ offered: Ticket, access: any ClubGovernanceAccess, context: ClubOwnerFundsContext,
              current: @escaping () -> Source?, active: @escaping () -> Bool,
              otherPresented: @escaping () -> Bool, force: Bool = false) async {
        guard !Task.isCancelled, accepts(offered, current: current(), active: active(), otherPresented: otherPresented()),
              !workflow.loading, needsRead || force else { return }
        needsRead = false
        await workflow.load(target: offered.source.target, access: access, context: context,
            sourceIsCurrent: { self.accepts(offered, current: current(), active: active(), otherPresented: otherPresented()) })
    }
    func openContact(_ offered: Ticket, access: any ClubGovernanceAccess, context: ClubOwnerFundsContext,
                     current: @escaping () -> Source?, active: @escaping () -> Bool,
                     otherPresented: @escaping () -> Bool) async {
        guard !Task.isCancelled, accepts(offered, current: current(), active: active(), otherPresented: otherPresented()), !workflow.loading else { return }
        await workflow.openContact(target: offered.source.target, access: access, context: context,
            sourceIsCurrent: { self.matches(offered, current: current(), active: active()) &&
                (self.visible || self.contact?.ticket == offered) && !otherPresented() })
        guard accepts(offered, current: current(), active: active(), otherPresented: otherPresented()), workflow.contactIsCurrent else { return }
        contact = Contact(ticket: offered); isPresented = true
    }
    func current(_ item: Contact, source: Source?, active: Bool) -> Bool {
        isPresented && contact == item && matches(item.ticket, current: source, active: active) && workflow.contactIsCurrent
    }
    func close(_ item: Contact) {
        guard contact == item else { return }; isPresented = false; workflow.closeContact()
    }
    func binding(_ item: Contact, current: @escaping () -> Source?, active: @escaping () -> Bool) -> Binding<Bool> {
        Binding(get: { self.current(item, source: current(), active: active()) }, set: { shown in
            guard !shown, self.contact == item, self.matches(item.ticket, current: current(), active: active()) else { return }
            self.close(item)
        })
    }
    @discardableResult func dismissed(_ item: Contact, current: Source?, active: Bool) -> Bool {
        guard contact == item, !isPresented, matches(item.ticket, current: current, active: active) else { return false }
        contact = nil; revision = UUID(); needsRead = true; workflow.invalidate(); return true
    }
}

@MainActor struct ClubOwnerFundsContactOwner: View {
    let item: ClubOwnerFundsParent.Contact
    @ObservedObject var owner: ClubOwnerFundsParent
    let context: ClubOwnerFundsContext
    let current: () -> ClubOwnerFundsParent.Source?
    let active: () -> Bool
    let returned: () -> Void
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .sheet(isPresented: owner.binding(item, current: current, active: active), onDismiss: {
                if owner.dismissed(item, current: current(), active: active()) { returned() }
            }) {
                Group {
                    if owner.current(item, source: current(), active: active()), let support = context.support { support() }
                    else { Text("club.gov.changed") }
                }
            }
    }
}

struct ClubOwnerFundsSection: View {
    let target: ClubOwnerFundsTarget
    let access: any ClubGovernanceAccess
    let context: ClubOwnerFundsContext
    let sourceGeneration: UInt64
    let sourceIsCurrent: () -> Bool
    @ObservedObject var workflow: ClubOwnerFundsWorkflow
    @ObservedObject var parent: ClubOwnerFundsParent
    let currentSource: () -> ClubOwnerFundsParent.Source?
    let otherPresented: () -> Bool
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    private var current: Bool {
        scenePhase == .active && parent.attachment != nil && parent.source == currentSource() &&
        sourceIsCurrent() && context.isCurrent() && access.identity == target.context.identity &&
        access.authorizationGeneration == target.context.authorizationGeneration &&
        target.context.accessIdentity == ObjectIdentifier(access)
    }
    var body: some View {
        let offered = parent.ticket(current: currentSource(), active: current, otherPresented: otherPresented())
        Section("club.ownerFunds.title") {
            Text("club.ownerFunds.accountScope").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            if workflow.loading {
                CYSkeletonLocal()
                Text("wallet.loading").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            if current, let value = workflow.funds, workflow.loadedScope == context.reader?.scope {
                if !value.amountsKnown { Text("wallet.amountsUnknown").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                CYBalanceHeroLocal(
                    label: "wallet.available",
                    amount: value.amountsKnown ? amount(value.withdrawable, currency: value.currency) : "—",
                    delta: value.amountsKnown ? amount(value.pendingSettlement, currency: value.currency) : "—"
                )
                if value.pendingSettlement.value > 0 {
                    CYMoneyRowLocal(title: "wallet.pendingSettlement", detail: "", amount: amount(value.pendingSettlement, currency: value.currency), incoming: true)
                }
                ForEach(Array(value.complaintPeriod.enumerated()), id: \.offset) { _, item in
                    CYMoneyRowLocal(title: "wallet.complaintPeriod", detail: item.availableDate, amount: amount(item.amount, currency: value.currency), incoming: true)
                }
                if value.disputed.value > 0 {
                    CYMoneyRowLocal(title: "wallet.disputed", detail: "", amount: amount(value.disputed, currency: value.currency), incoming: false)
                }
            }
            if let key = workflow.failure { Text(LocalizedStringKey(key)).accessibilityIdentifier("club.ownerFunds.error") }
            if target.hasSettlementRows {
            if let hint = ClubOpsWithdrawHint(isOwner: true, availability: workflow.availability) {
                Text(LocalizedStringKey(hint.localizationKey), tableName: "ClubOpsCustomer").cyText(.meta)
                    .accessibilityIdentifier("clubOps.settlement.withdraw." + hint.rawValue)
            } else { Text("club.ownerFunds.manual").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            // HANDOFF-R1 MC-29 (owner Q-C): withdrawal stays a support hand-off, named and explained.
            ClubWithdrawalHandOffNote()
            Button {
                guard let offered else { return }
                Task { await parent.openContact(offered, access: access, context: context, current: currentSource,
                    active: { current }, otherPresented: otherPresented) }
            } label: { Text(verbatim: clubR1("funds.withdrawViaSupport", locale)) }
            .buttonStyle(.cyPrimary(fullWidth: true))
            .disabled(offered == nil || workflow.loading || workflow.availability != .positive || context.support == nil)
                .accessibilityIdentifier("club.ownerFunds.contact")
            }
            Button("wallet.retry") {
                guard let offered else { return }
                Task { await parent.load(offered, access: access, context: context, current: currentSource,
                    active: { current }, otherPresented: otherPresented, force: true) }
            }
            .buttonStyle(.cySecondary(fullWidth: true))
            .disabled(workflow.loading || offered == nil)
                .accessibilityIdentifier("club.ownerFunds.retry")
        }
    }
    private func amount(_ value: WalletAmount, currency: String?) -> String {
        value.text + " " + (currency ?? appLocalized("wallet.currencyUnknown", locale: locale))
    }
}

// Local stand-ins for the shared names agreed with CA1. The train replaces the Local suffix.
private struct CYBalanceHeroLocal: View {
    let label: LocalizedStringKey
    let amount: String
    let delta: String
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(label).cyText(.meta).foregroundStyle(CYColor.textSecondary).cyWrapText()
            Text(verbatim: amount)
                .cyText(.data2XL)
                .foregroundStyle(CYColor.textPrimary)
                .cyWrapText()
            Text(verbatim: delta)
                .cyText(.caption)
                .foregroundStyle(CYColor.textSecondary)
                .cyWrapText()
                .padding(.horizontal, CYSpacing.sm)
                .padding(.vertical, CYSpacing.xs)
                .background(CYColor.bgSurfaceSubtle, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct CYMoneyRowLocal: View {
    let title: LocalizedStringKey
    let detail: String
    let amount: String
    let incoming: Bool
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).cyWrapText()
                if !detail.isEmpty {
                    Text(verbatim: detail).cyText(.meta).foregroundStyle(CYColor.textSecondary).cyWrapText()
                }
            }
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: amount)
                .cyText(.numericBody)
                .foregroundStyle(incoming ? CYColor.successText : CYColor.textPrimary)
                .cyWrapText(alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct CYSkeletonLocal: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous)
                .fill(CYColor.bgRaised)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.sm, alignment: .leading)
            RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous)
                .fill(CYColor.bgRaised)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.xxl, alignment: .leading)
            RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous)
                .fill(CYColor.bgRaised)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.md, alignment: .leading)
        }
        .accessibilityHidden(true)
    }
}

private struct CYConfirmSheetLocal: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                Text(title).cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary)
                Text(message).cyText(.body).foregroundStyle(CYColor.textSecondary)
                Spacer(minLength: CYSpacing.lg)
                Button(confirmTitle) { onConfirm(); dismiss() }
                    .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                Button("action.cancel") { dismiss() }
                    .buttonStyle(.cySecondary(fullWidth: true))
            }
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(CYColor.bgPage)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Owner funds tokens") {
    VStack(alignment: .leading, spacing: CYSpacing.lg) {
        CYBalanceHeroLocal(label: "wallet.available", amount: "128.00", delta: "12.00")
        CYMoneyRowLocal(title: "wallet.pendingSettlement", detail: "Synthetic", amount: "12.00", incoming: true)
        CYMoneyRowLocal(title: "wallet.disputed", detail: "", amount: "—", incoming: false)
        CYSkeletonLocal()
    }
    .padding(CYSpacing.lg)
    .background(CYColor.bgPage)
    .preferredColorScheme(.dark)
}

#Preview("Confirm sheet") {
    CYConfirmSheetLocal(title: "wallet.available", message: "wallet.amountsUnknown", confirmTitle: "action.cancel", onConfirm: {})
        .preferredColorScheme(.light)
}
