import SwiftUI

@MainActor struct ActivityPeopleProfileContext {
    let reader: any SocialAccountReading
    let squareReader: any SquareReading
    var actions: SocialActionCoordinator? = nil
}

/// Uses only the people projection in the allowed detail; never requests an
/// administrative roster or infers participants from tickets or orders.
@MainActor struct ActivityPeopleSection: View {
    let people: ActivityPeople
    var onOpenProfile: ((Int) -> Void)? = nil
    /// PC-C-1-4: shop-hosted activity → the shop is the 主办方 (no member profile link).
    var organizerShopName: String? = nil
    /// `organizerShopLogo` when the shop name is present. https only; otherwise the storefront mark.
    var organizerShopLogo: String? = nil

    var body: some View {
        if let shop = organizerShopName {
            Section("activity.people.organizerShop") {
                HStack(spacing: 12) {
                    PeopleMark(url: MemberIdentityCardSection.remoteAvatarURL(organizerShopLogo), systemImage: "storefront.circle.fill")
                    Text(verbatim: shop)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("activity.people.organizerShop")
            }
        } else if let host = people.host, host.name != nil {
            Section("activity.people.host") {
                personRow(host, identifier: "activity.people.host")
            }
        }
        if !people.participants.isEmpty || people.registrationCount != nil {
            Section("activity.people.participants") {
                LabeledContent("activity.people.total") {
                    if let count = people.registrationCount {
                        Text(verbatim: String(count)).accessibilityIdentifier("activity.people.count")
                    }
                    else { Text("activity.people.countUnknown") }
                }.accessibilityIdentifier("activity.people.total")
                ForEach(Array(people.participants.enumerated()), id: \.offset) { index, person in
                    personRow(person, identifier: "activity.people.participant.\(index)")
                }
            }
        }
    }

    @ViewBuilder private func personRow(_ person: ActivityPerson, identifier: String) -> some View {
        if let memberID = person.memberID, let onOpenProfile {
            Button { onOpenProfile(memberID) } label: { label(person) }
                .buttonStyle(.plain)
                .accessibilityHint(Text("social.profile"))
                .accessibilityIdentifier(identifier)
        } else {
            label(person).accessibilityIdentifier(identifier + ".readOnly")
        }
    }
    private func label(_ person: ActivityPerson) -> some View {
        HStack(spacing: 12) {
            PeopleMark(url: MemberIdentityCardSection.remoteAvatarURL(person.avatarURL), systemImage: "person.crop.circle.fill")
            if let name = person.name { Text(verbatim: name) }
            else { Text("activity.people.unnamed") }
            Spacer(minLength: 8)
            if person.memberID != nil, onOpenProfile != nil {
                Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }.frame(minHeight: 44).contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }
}

/// Host `avatarURL` is `memberAvatar`. A registrant `avatarURL` is `avatar`. https only.
private struct PeopleMark: View {
    let url: URL?
    let systemImage: String
    /// R9-PC-CN-3: the 32 pt avatar follows Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 32
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: systemImage) }
                }
            } else {
                Image(systemName: systemImage)
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}
