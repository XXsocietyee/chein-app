import SwiftUI

/// Environment observation resets the form when the authenticated identity/epoch changes.
@MainActor struct SessionRegistrationSheet:View {
    let activity:ActivityDetail
    var preselectedTicketID: Int? = nil
    @EnvironmentObject private var session:AppSession
    var body:some View {
        RegistrationSheetView(activity:activity,coordinator:session.registrationCoordinator,
                              participantReader:session.participantReader,
                              orderReader:session.ownedOrderReader,
                              participantCoordinator:session.participantCoordinator,
                              currentIdentity:{ session.profileReader.identity },
                              quoteEnabled:session.isConfigured,
                              creationPolicy:Self.freeWhenUnapproved(session.registrationCreationPolicy(activityID:activity.summary.id)),
                              waitlistService:session.registrationWaitlistService(activityID:activity.summary.id),
                              couponUsability:{
                                  guard let client = WP07CommerceSession.client(session) else { return [] }
                                  return try await client.usability()
                              },
                              // `Account.xp` decodes `userInfo.point`, the balance `baoming.js:1240` reads.
                              availablePoints:{ session.account?.xp },
                              preselectedTicketID: preselectedTicketID)
    }

    /// The integrator button opens this sheet. An unapproved session still cannot pay.
    /// Only the disabled policy becomes the free path; an approved grant is left as issued.
    static func freeWhenUnapproved(_ issued: RegistrationUICreationPolicy) -> RegistrationUICreationPolicy {
        if case .disabled = issued { return .free }
        return issued
    }
}
