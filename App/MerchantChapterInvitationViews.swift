import SwiftUI

/// C7 detail for one invitation from `chapter-application/mine`. Reached from a chapter
/// inbox row; returning always refreshes the parent list (a read, never a resend).
@MainActor struct MerchantChapterInvitationDetailView: View {
    let service: any MerchantContentServing
    let applicationID: Int
    var onReturn: (() -> Void)? = nil
    @StateObject private var model: MerchantContentViewModel
    init(service: any MerchantContentServing, applicationID: Int, onReturn: (() -> Void)? = nil) {
        self.service = service; self.applicationID = applicationID; self.onReturn = onReturn
        _model = StateObject(wrappedValue: .init(service: service, query: .chapterInvitations))
    }
    private var c: MerchantContentCoordinator { model.coordinator }
    private var invitation: MerchantChapterInvitation? {
        guard let snapshot = c.snapshot else { return nil }
        return snapshot.rows.first { $0["id"].integer == applicationID }.flatMap { try? MerchantChapterInvitation(row: $0) }
    }
    var body: some View {
        Form {
            Section {
                MerchantContentBoundary()
                if let message = c.serverMessage { Text(verbatim: message).accessibilityIdentifier("merchantChapterInvitation.serverMessage") }
                if let issue = c.issue { Text(LocalizedStringKey(issue)).cyText(.bodyCompact).accessibilityIdentifier("merchantChapterInvitation.issue") }
                if c.locked {
                    Text("merchantChapterInvitation.unknownLock").cyText(.bodyCompact)
                    Button("merchantChapterInvitation.readback") { Task { await model.reconcileChapterInvitation() } }
                        .disabled(c.busy).accessibilityIdentifier("merchantChapterInvitation.readback")
                }
                if c.isCurrent, let invitation {
                    Text(verbatim: invitation.chapterName ?? "—").cyText(.sheetTitle)
                    MerchantContentFields(value: invitation.raw, names: ["topicName", "chapterName", "status", "source", "message"])
                    if let reason = invitation.serverReason {
                        LabeledContent("merchantChapterInvitation.serverReason") { Text(verbatim: reason).textSelection(.enabled) }
                    }
                    switch invitation.status {
                    case .approved: Text("merchantChapterInvitation.approved").accessibilityIdentifier("merchantChapterInvitation.approved")
                    case .rejected: Text("merchantChapterInvitation.rejected").accessibilityIdentifier("merchantChapterInvitation.rejected")
                    case .pending:
                        if invitation.canRespond {
                            Text("merchantChapterInvitation.pending").cyText(.cardTitle)
                            ForEach(MerchantChapterInvitation.impactKeys(accepted: true), id: \.self) { Text(LocalizedStringKey($0)).cyText(.bodyCompact) }
                            Button("merchantChapterInvitation.accept") { prepare(invitation, accepted: true) }
                                .buttonStyle(.borderedProminent).disabled(c.busy || c.locked || c.review != nil || c.receipt != nil)
                                .accessibilityIdentifier("merchantChapterInvitation.accept")
                            ForEach(MerchantChapterInvitation.impactKeys(accepted: false), id: \.self) { Text(LocalizedStringKey($0)).cyText(.bodyCompact) }
                            Button("merchantChapterInvitation.reject", role: .destructive) { prepare(invitation, accepted: false) }
                                .disabled(c.busy || c.locked || c.review != nil || c.receipt != nil)
                                .accessibilityIdentifier("merchantChapterInvitation.reject")
                        } else { Text("merchantChapterInvitation.notInvite").accessibilityIdentifier("merchantChapterInvitation.notInvite") }
                    case .unknown(_): Text("merchantChapterInvitation.statusUnknown").accessibilityIdentifier("merchantChapterInvitation.statusUnknown")
                    }
                } else if c.busy { ProgressView("merchant.loading") }
                else if c.isCurrent { Text("merchantChapterInvitation.missing").accessibilityIdentifier("merchantChapterInvitation.missing") }
                if !c.busy { Button("action.retry") { Task { await model.load() } }.accessibilityIdentifier("merchantChapterInvitation.reload") }
            }
        }
        .listStyle(.insetGrouped)
        .cyPageTitle("merchantChapterInvitation.title")
        .task(id: service.scope) { await model.load() }
        .onDisappear { model.suspend(); onReturn?() }
        .sheet(item: Binding(get: { c.isCurrent ? c.review : nil }, set: { if $0 == nil { model.cancel() } })) { value in Group { MerchantContentReviewView(model: model, review: value) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
        .cyDomainScreen(.merchant)
    }
    private func prepare(_ invitation: MerchantChapterInvitation, accepted: Bool) {
        model.prepare(.respondChapterInvitation(applicationID: invitation.applicationID, accepted: accepted, chapterID: invitation.chapterID, topicID: invitation.topicID))
    }
}
