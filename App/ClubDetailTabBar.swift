import SwiftUI

/// Mini-program `cy-tabs.club-view-tabs`: 帖文 / 活动 / 概览 (+ 管理 when allowed), as a native segmented picker.
struct ClubDetailTabBar: View {
    let tabs: [ClubDetailTab]
    let selection: ClubDetailTab
    let select: (ClubDetailTab) -> Void
    var body: some View {
        Section {
            // At accessibility sizes four equal columns clip "Overview" / "Manage": let the bar scroll instead.
            Group {
                if typeSize.isAccessibilitySize {
                    ScrollView(.horizontal, showsIndicators: false) { tabRow }
                } else {
                    tabRow
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: selection)
            .sensoryFeedback(.selection, trigger: selection)
            .listRowInsets(EdgeInsets(top: 0, leading: CYSpacing.lg, bottom: 0, trailing: CYSpacing.lg))
            .listRowBackground(Color.clear)
        }
    }
    private var tabRow: some View {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    Button { select(tab) } label: {
                        VStack(spacing: 6) {
                            Text(tab.titleKey)
                                .font(selection == tab ? CYTypography.bodyMedium.weight(.semibold) : CYTypography.bodyMedium)
                                .foregroundStyle(selection == tab ? CYColor.textPrimary : CYColor.textSecondary)
                                .lineLimit(1).minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.8)
                            ZStack {
                                Capsule().fill(Color.clear).frame(height: 3)
                                if selection == tab { Capsule().fill(Theme.Color.accent(in: domain)).frame(height: 3).matchedGeometryEffect(id: "club.tab.underline", in: ns) }
                            }
                        }
                        .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, minHeight: 44)
                        .padding(.horizontal, typeSize.isAccessibilitySize ? CYSpacing.md : 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                    .accessibilityIdentifier("club.detail.tab." + tab.rawValue)
                }
            }
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.themeDomain) private var domain
}

extension ClubDetailTab {
    var titleKey: LocalizedStringKey {
        switch self {
        case .posts: return "club.detail.tab.posts"
        case .events: return "club.detail.tab.events"
        case .overview: return "club.detail.tab.overview"
        case .manage: return "club.detail.tab.manage"
        }
    }
}

struct ClubDetailOverviewFactsGridView: View {
    let grid: ClubDetailOverviewFactsGrid
    var body: some View {
        HStack(spacing: 12) {
            ForEach(grid.items) { item in
                VStack(spacing: 4) {
                    Text(verbatim: item.label).cyText(.meta).foregroundStyle(.secondary)
                    Text(verbatim: item.value).cyText(.bodyMedium)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("club.detail.fact.\(item.id)")
            }
        }
        .accessibilityIdentifier("club.detail.factsGrid")
    }
}
