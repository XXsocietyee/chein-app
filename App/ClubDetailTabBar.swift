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
            .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.lg, bottom: CYSpacing.xs, trailing: CYSpacing.lg))
            .listRowBackground(Color.clear)
        }
    }
    /// Native restyle R2 (spec §3.7 / §4.9): drawn as a system segmented control (tertiary-fill track, the selected
    /// segment lifted on the grouped surface) but kept as buttons, because UI tests tap `club.detail.tab.<key>` and a
    /// `Picker(.segmented)` cannot carry an identifier per segment.
    private var tabRow: some View {
            HStack(spacing: 2) {
                ForEach(tabs) { tab in
                    Button { select(tab) } label: {
                        Text(tab.titleKey)
                            .cyText(.label, weight: selection == tab ? .semibold : nil)
                            .foregroundStyle(selection == tab ? CYColor.textPrimary : CYColor.textSecondary)
                            .lineLimit(1).minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.8)
                            .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, minHeight: CYSpacing.minTouchTarget)
                            .padding(.horizontal, typeSize.isAccessibilitySize ? CYSpacing.md : CYSpacing.xs)
                            .background {
                                if selection == tab {
                                    RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous)
                                        .fill(CYColor.bgSurface)
                                        .matchedGeometryEffect(id: "club.tab.segment", in: ns)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                    .accessibilityIdentifier("club.detail.tab." + tab.rawValue)
                }
            }
            .padding(2)
            .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.inner + 2, style: .continuous))
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
