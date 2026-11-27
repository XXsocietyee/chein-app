import SwiftUI

/// CLB-customer-detail-04 (MP pages/club/customer-detail/index.wxml:83-118): 编辑 turns the 标签与备注 card into the
/// editor in place (no sheet). 保存 sends the reviewed saveCustomer command; 取消 drops the draft. A failure keeps the
/// draft with 标签与备注没保存成功 and the server sentence. An unknown outcome stays journal-locked
/// (Core/ClubGovernanceCoordinator.swift `isLocked`), so 保存 is not offered again for that draft.
@MainActor struct ClubCustomerInlineEditor: View {
    let value: ClubGovernanceValue
    let scope: ClubGovernanceScope
    let identity: ClubReadIdentity?
    let coordinator: ClubGovernanceCoordinator
    let onSaved: () -> Void
    @State private var draft: ClubGovernanceFormDraft?
    @State private var saving = false
    @State private var failure: ClubGovernanceFailure?

    var body: some View {
        if draft != nil { editing } else {
            Button { start() } label: { Text("clubR3b.customer.edit") }
                .accessibilityLabel(Text("club.gov.action.saveCustomer"))
                .accessibilityIdentifier("club.gov.customer.edit")
        }
    }

    @ViewBuilder private var editing: some View {
        ClubOpsCustomerTagRemarkEditor(tagsText: textBinding("tags"), remark: textBinding("remark"))
            .disabled(saving)
        if let failure { failureRows(failure) }
        Button { Task { await save() } } label: {
            if saving { ProgressView() } else { Text("clubR3b.customer.save") }
        }
        .disabled(saving || locked)
        .accessibilityIdentifier("club.gov.customer.save")
        Button("clubR11.customer.cancelEdit", role: .cancel) { draft = nil; failure = nil }
            .disabled(saving)
            .accessibilityIdentifier("club.gov.customer.cancelEdit")
    }

    @ViewBuilder private func failureRows(_ failure: ClubGovernanceFailure) -> some View {
        Label { Text("clubR3b.customer.saveFailed") } icon: { Image(systemName: "exclamationmark.circle") }
            .foregroundStyle(.red)
            .accessibilityIdentifier("club.gov.formError")
        if let message = failure.message { Text(verbatim: message).foregroundStyle(.secondary) }
        else if locked { Text("club.gov.unknown").foregroundStyle(.secondary) }
        else { Text("clubR3b.customer.saveFailedRetry").foregroundStyle(.secondary) }
    }

    private var locked: Bool {
        guard let identity, let command = try? draft?.command() else { return false }
        return coordinator.isLocked(command, identity: identity)
    }

    private func textBinding(_ key: String) -> Binding<String> {
        Binding(get: { draft?.text[key] ?? "" }, set: { next in draft?.text[key] = next; failure = nil })
    }

    private func start() {
        draft = ClubGovernanceFormDraft(operation: .saveCustomer, scope: scope, seed: ["remark": value["remark"], "tags": value["tags"]])
        failure = nil
    }

    private func save() async {
        guard !saving, let current = draft else { return }
        saving = true; failure = nil
        defer { saving = false }
        do {
            let review = try await coordinator.prepare(try current.command())
            _ = try await coordinator.confirm(review)
            draft = nil
            onSaved()
        } catch {
            failure = error as? ClubGovernanceFailure ?? .unknown(message: nil)
        }
    }
}
