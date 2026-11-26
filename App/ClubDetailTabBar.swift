import SwiftUI

/// Mini-program `cy-tabs.club-view-tabs`: 帖文 / 活动 / 概览 (+ 管理 when allowed), as a native segmented picker.
struct ClubDetailTabBar: View {
    let tabs: [ClubDetailTab]
    let selection: ClubDetailTab
    let select: (ClubDetailTab) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Section {
            // G-028 (design P1): the system segmented control itself, not a drawn look-alike. At accessibility sizes
            // four segments clip "Overview" / "Manage", so the same Picker becomes a menu (as Settings does).
            Group {
                if typeSize.isAccessibilitySize {
                    picker.pickerStyle(.menu)
                } else {
                    picker.pickerStyle(.segmented).labelsHidden()
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("club.detail.tabs")
        }
    }
    /// Each segment keeps `club.detail.tab.<key>` on its label; a segmented Picker exposes the segments as buttons
    /// with the `isSelected` trait, which is what the UI tests tap and read.
    private var picker: some View {
        Picker(selection: Binding(get: { selection }, set: { select($0) })) {
            ForEach(tabs) { tab in
                Text(tab.titleKey)
                    .tag(tab)
                    .accessibilityIdentifier("club.detail.tab." + tab.rawValue)
            }
        } label: {
            Text("club.detail.tabs.label")
        }
    }
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
