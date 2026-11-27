import SwiftUI

@MainActor
struct ProfileBadgesView: View {
    let reader: any ProfileReading
    var body: some View {
        ProfileReadScreen(reader: reader, accessibilityPrefix: "profile.badges", load: { try await reader.profileBadges() }) { wall in
            if wall.isEmpty {
                ProfileEmptyState(title: "profile.badges.empty", hint: "profile.badges.emptyHint", symbol: "medal", identifier: "profile.badges.empty")
            } else {
                List {
                    if wall.isPartial {
                        Section {
                            Label {
                                Text("profile.badges.partial")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            }
                            .accessibilityIdentifier("profile.badges.partial")
                            if let message = wall.medalFailureMessage, !message.isEmpty { Text(verbatim: message) }
                            Text("profile.badges.partialHint").foregroundStyle(.secondary)
                        }
                    }
                    if !wall.identities.isEmpty {
                        Section("profile.badges.identities") {
                            ForEach(Array(wall.identities.enumerated()), id: \.offset) { index, badge in
                                badgeLink(.identity(badge), identifier: "profile.badge.identity.\(index)")
                            }
                        }
                    }
                    if let medals = wall.medals {
                        let city = medals.filter { !$0.isAchievement }
                        let achievements = medals.filter(\.isAchievement)
                        if !city.isEmpty {
                            Section("profile.badges.medals") {
                                ForEach(Array(city.enumerated()), id: \.offset) { index, badge in
                                    badgeLink(.medal(badge), identifier: "profile.badge.medal.\(index)")
                                }
                            }
                        }
                        if !achievements.isEmpty {
                            Section("profile.badges.achievements") {
                                ForEach(Array(achievements.enumerated()), id: \.offset) { index, badge in
                                    badgeLink(.medal(badge), identifier: "profile.badge.achievement.\(index)")
                                }
                            }
                        }
                    }
                }
            }
        }
        .appNavigationTitle("profile.badges.title").navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
    }
    private func badgeLink(_ badge: ProfileBadgeSelection, identifier: String) -> some View {
        NavigationLink { ProfileBadgeDetailView(badge: badge) } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    ProfileBadgeTitle(badge: badge)
                    ProfileBadgeStatus(badge: badge)
                }
            } icon: {
                ProfileBadgeMedal(badge: badge, size: 36)
            }
        }.accessibilityIdentifier(identifier)
    }
}

enum ProfileBadgeSelection {
    case identity(ProfileIdentityBadge), medal(ProfileMedal)
    var image: String {
        switch self { case .identity(let value): return value.iconURL; case .medal(let value): return value.medalImage }
    }
    var name: String {
        switch self { case .identity(let value): return value.badgeName; case .medal(let value): return value.medalName }
    }
    var isLocked: Bool {
        if case .identity(let value) = self { return !value.unlocked }
        return false
    }
    var seed: String { name.isEmpty ? image : name }
    /// Locked hides the foil. Achievements take the full strength, city medals less, identity badges least.
    var foilStrength: Double {
        if isLocked { return 0 }
        switch self {
        case .identity: return 0.45
        case .medal(let value): return value.isAchievement ? 1 : 0.7
        }
    }
    var familyKey: LocalizedStringKey {
        switch self {
        case .identity: return "profile.badges.identities"
        case .medal(let value): return value.isAchievement ? "profile.badges.achievements" : "profile.badges.medals"
        }
    }
}

struct ProfileBadgeDetailView: View {
    let badge: ProfileBadgeSelection
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ProfileBadgeMedal(badge: badge, size: 96)
                        .motionR2HoloSheen(active: !badge.isLocked, cornerRadius: 48) // motion r2 R2 (unlocked only)
                        .motionR2Tilt() // motion r2 R13: turns with the phone
                    ProfileBadgeTitle(badge: badge).font(.title2.weight(.semibold))
                    ProfileBadgeStatus(badge: badge)
                }.frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            Section("profile.badges.details") {
                LabeledContent("profile.badges.family") { Text(badge.familyKey) }
                switch badge {
                case .identity(let value):
                    ProfileOptionalRow(key: "profile.badges.category", value: value.category)
                    ProfileOptionalRow(key: "profile.badges.statement", value: value.statement)
                    ProfileOptionalRow(key: "profile.badges.unlockHint", value: value.unlockHint)
                    if value.unlocked { ProfileOptionalRow(key: "profile.badges.obtained", value: value.unlockTime) }
                case .medal(let value):
                    ProfileOptionalRow(key: "profile.badges.condition", value: value.displayCondition)
                    ProfileOptionalRow(key: "profile.badges.obtained", value: value.getTime)
                }
            }
        }
        .appNavigationTitle("profile.badges.detail")
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
    }
}

private struct ProfileBadgeTitle: View {
    let badge: ProfileBadgeSelection
    var body: some View {
        if badge.name.isEmpty { Text(badge.familyKey) }
        else { Text(verbatim: badge.name) }
    }
}

/// Locked / unlocked as a tinted SF Symbol label (colour is never the only signal: the text says it).
private struct ProfileBadgeStatus: View {
    let badge: ProfileBadgeSelection
    var body: some View {
        Label {
            Text(badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked")
        } icon: {
            Image(systemName: badge.isLocked ? "lock.fill" : "checkmark.seal.fill")
                .foregroundStyle(badge.isLocked ? Color.secondary : Color.green)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// SF Symbol medal (Fitness Awards style): no crafted foil art. Identity badges, city medals and achievements
/// each keep their own symbol; locked badges are drawn in the secondary colour.
private struct ProfileBadgeMedal: View {
    let badge: ProfileBadgeSelection
    let size: CGFloat
    private var symbol: String {
        switch badge {
        case .identity: return "person.crop.circle.badge.checkmark"
        case .medal(let value): return value.isAchievement ? "trophy.fill" : "medal.fill"
        }
    }
    var body: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(badge.isLocked ? Color.secondary : Color.accentColor)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
