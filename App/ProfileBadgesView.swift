import SwiftUI

@MainActor
struct ProfileBadgesView: View {
    let reader: any ProfileReading
    @State private var stagger = CYStaggerGate()
    var body: some View {
        ProfileReadScreen(reader: reader, accessibilityPrefix: "profile.badges", load: { try await reader.profileBadges() }) { wall in
            if wall.isEmpty {
                ProfileEmptyState(title: "profile.badges.empty", hint: "profile.badges.emptyHint", symbol: "medal", identifier: "profile.badges.empty")
            } else {
                List {
                    if wall.isPartial {
                        Section {
                            CYStatusChip("profile.badges.partial", tone: .warning, systemImage: "exclamationmark.triangle")
                                .accessibilityIdentifier("profile.badges.partial")
                            if let message = wall.medalFailureMessage, !message.isEmpty { Text(verbatim: message) }
                            Text("profile.badges.partialHint").foregroundStyle(.secondary)
                        }
                    }
                    if !wall.identities.isEmpty {
                        Section("profile.badges.identities") {
                            ForEach(Array(wall.identities.enumerated()), id: \.offset) { index, badge in
                                badgeLink(.identity(badge), identifier: "profile.badge.identity.\(index)")
                                    .cyStaggeredAppear(index: index, gate: stagger)
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
                                        .cyStaggeredAppear(index: index, gate: stagger)
                                }
                            }
                        }
                        if !achievements.isEmpty {
                            Section("profile.badges.achievements") {
                                ForEach(Array(achievements.enumerated()), id: \.offset) { index, badge in
                                    badgeLink(.medal(badge), identifier: "profile.badge.achievement.\(index)")
                                        .cyStaggeredAppear(index: index, gate: stagger)
                                }
                            }
                        }
                    }
                }
            }
        }
        .appNavigationTitle("profile.badges.title").navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.player)
    }
    private func badgeLink(_ badge: ProfileBadgeSelection, identifier: String) -> some View {
        NavigationLink { ProfileBadgeDetailView(badge: badge) } label: {
            HStack(alignment: .center, spacing: 12) {
                ProfileBadgeMedal(badge: badge, size: 44)
                VStack(alignment: .leading, spacing: 5) {
                    ProfileBadgeTitle(badge: badge).cyText(.cardTitle)
                    CYStatusChip(badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked",
                                 tone: badge.isLocked ? .neutral : .success,
                                 systemImage: badge.isLocked ? "lock" : "checkmark.seal")
                }
            }.padding(.vertical, 5)
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
    @State private var revealed = false
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    ProfileBadgeMedal(badge: badge, size: 168)
                        .scaleEffect(revealed || reduceMotion ? 1 : 0.82)
                        .opacity(revealed ? 1 : 0)
                        .onAppear {
                            if reduceMotion { revealed = true }
                            else { withAnimation(CYMotion.entrance) { revealed = true } }
                        }
                    ProfileBadgeTitle(badge: badge).cyText(.sheetTitle)
                    CYStatusChip(badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked",
                                 tone: badge.isLocked ? .neutral : .success,
                                 systemImage: badge.isLocked ? "lock" : "checkmark.seal")
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
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
        .cyDomainScreen(.player)
    }
}

private struct ProfileBadgeTitle: View {
    let badge: ProfileBadgeSelection
    var body: some View {
        if badge.name.isEmpty { Text(badge.familyKey) }
        else { Text(verbatim: badge.name) }
    }
}

private struct ProfileBadgeMedal: View {
    let badge: ProfileBadgeSelection
    let size: CGFloat
    var body: some View {
        CYCraftedMedal(kind: CYBadgeKind(seed: badge.seed), seed: badge.seed, size: size, foilStrength: badge.foilStrength)
            .accessibilityHidden(true)
    }
}
