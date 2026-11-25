import SwiftUI

/// Inactive access/me has no merchant id. Accept still posts `{token, requestId}` (MC9-29-1).
enum MerchantInvitationAcceptGate {
    static func allows(_ command: MerchantEngagementCommand, merchantID: Int?, reader: any MerchantEngagementReading) -> Bool {
        if let merchantID, merchantID > 0 { return reader.canExecute(command, merchantID: merchantID) }
        guard case .acceptInvitation = command else { return false }
        return reader.canExecute(command, merchantID: 0)
    }
}

@MainActor struct MerchantOperatorInvitationLandingView: View {
    let invitation: MerchantOperatorAcceptance
    let reader: any MerchantEngagementReading
    let requestSignIn: () -> Void
    @StateObject private var model: MerchantEngagementViewModel
    @State private var consumed = false
    init(invitation: MerchantOperatorAcceptance, reader: any MerchantEngagementReading, journal: any MerchantBusinessIntentStore,
         exportRecovery: any MerchantExportRecoveryStoring, requestSignIn: @escaping () -> Void) {
        self.invitation = invitation; self.reader = reader; self.requestSignIn = requestSignIn
        _model = StateObject(wrappedValue: .init(reader: reader, journal: journal, exports: exportRecovery))
    }
    var body: some View {
        List {
            Text("merchant.engagement.invitationUnknownTarget")
            Text("merchant.engagement.invitationConsequence").cyText(.bodyCompact)
            if reader.scope == nil {
                Text("merchant.engagement.invitationSignInHint")
                Button("merchant.signIn", action: requestSignIn).accessibilityIdentifier("merchant.engagement.inviteSignIn")
            } else if !consumed {
                Button("merchant.engagement.acceptInvitation") { Task { await model.prepare(.acceptInvitation(invitation)) } }
                    .accessibilityIdentifier("merchant.engagement.inviteReview")
            }
            if let failure = model.coordinator.failure { Text(LocalizedStringKey(failure.key)) }
            if let receipt = model.coordinator.receipt, case .invitationAccepted = receipt { Text("merchant.engagement.membershipReceipt"); Text("merchant.engagement.refreshIdentity") }
        }.cyPageTitle("merchant.engagement.invitation")
        .sheet(item: Binding(get: { model.coordinator.review }, set: { if $0 == nil { model.cancel() } })) { review in
            Group {
                MerchantEngagementReviewView(review: review, enabled: MerchantInvitationAcceptGate.allows(review.command, merchantID: review.proof.access.merchantID, reader: reader), synthetic: reader.isSyntheticEnabled, busy: model.coordinator.busy, cancel: model.cancel) {
                    Task { await model.confirm(review); if let result = model.coordinator.receipt, case .invitationAccepted = result { consumed = true } }
                }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .onChange(of: reader.scope) { _, _ in model.invalidate() }
        .onDisappear { model.invalidate() }
        .cyDomainScreen(.merchant)
    }
}
