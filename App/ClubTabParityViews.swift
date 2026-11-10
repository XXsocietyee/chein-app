import SwiftUI

/// Mini-program 俱乐部 tab (`pages/talent/list`) details layered on `ClubHomeView`.
struct ClubTabTagLine: View {
    let club: ClubRecord
    let section: ClubTabPresentation.Section
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let tags = ClubTabPresentation.tags(club, in: section)
        let level = ClubTabPresentation.levelKey(club.level)
        if !tags.labels.isEmpty || tags.freeToJoin || level.key != nil || level.fallback != nil {
            chipLayout(tags: tags, level: level)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("clubTab.tags.\(club.id)")
        }
    }
    private func chipLayout(tags: (labels: [String], freeToJoin: Bool), level: (key: String?, fallback: String?)) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.xs))
        return layout {
            if let key = level.key { CYStatusChip(LocalizedStringKey(key), tone: .info, systemImage: "star") }
            else if let fallback = level.fallback { CYStatusChip(verbatim: fallback, tone: .info, systemImage: "star") }
            ForEach(tags.labels.prefix(3), id: \.self) { label in
                CYStatusChip(verbatim: label)
            }
            if tags.freeToJoin { CYStatusChip("club.tab.freeToJoin", tone: .success, systemImage: "person.badge.plus") }
        }
    }
}

struct ClubTabEmptyState: View {
    let merchant: Bool
    var body: some View {
        // Mini-program cy-empty shows only the title here; the create action sits in the row above.
        let keys = ClubTabPresentation.emptyKeys(merchant: merchant)
        CYEmptyState(systemImage: "person.3", LocalizedStringKey(keys.title))
            .accessibilityIdentifier("clubTab.empty")
    }
}
