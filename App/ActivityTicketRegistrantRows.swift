import SwiftUI

/// R11-PC-C-4: MP scene-play-activity-detail/index.wxml:89-98 — one avatar + nickname per registrant, each opening
/// that member's page (`goUserInfo`); an empty lineup says 这个票种还没有人报名. Kept out of the presentation-only
/// ActivityPresentationComponents file; rows stay outside the ticket card's combined accessibility element.
struct ActivityTicketRegistrantRows: View {
    let ticket: ActivityTicket
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .subheadline) private var avatarSide: CGFloat = 28
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        if ticket.registrants.isEmpty {
            Text(verbatim: copy.t("这个票种还没有人报名", "No one has signed up for this ticket yet"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("activity.ticket.registrants.empty.\(ticket.id)")
        } else {
            ForEach(Array(ticket.registrants.enumerated()), id: \.offset) { _, person in
                if person.memberID > 0 {
                    NavigationLink {
                        MPReviewedPageScreen(page: "pages/userinfo/userinfo", query: ["userId": String(person.memberID)])
                    } label: { registrantLabel(person) }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("activity.ticket.registrant.\(person.memberID)")
                } else {
                    registrantLabel(person)
                }
            }
        }
    }
    private func registrantLabel(_ person: TopicRegistrant) -> some View {
        Label {
            Text(verbatim: person.nickname.isEmpty ? copy.t("报名用户", "Participant") : person.nickname)
                .foregroundStyle(.primary)
        } icon: {
            AsyncImage(url: person.avatar.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
            }
            .frame(width: avatarSide, height: avatarSide)
            .clipShape(Circle())
            .accessibilityHidden(true)
        }
        .font(.subheadline)
    }
}
