import SwiftUI

/// Uses only the enclosing screen's already-read rows. A filter selection never reloads.
/// Source scene-member-order-history uses a horizontal chip row (cy-tabs variant="chip").
struct ProfileOrderFilterSection: View {
    @Binding var selection: ProfileOrderHistoryFilter
    let isEmpty: Bool
    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProfileOrderHistoryFilter.allCases) { filter in
                        ProfileOrderFilterChip(filter: filter, isSelected: selection == filter) { selection = filter }
                    }
                }.padding(.vertical, CYSpacing.xs)
            }
            .contentMargins(.horizontal, CYSpacing.pageHorizontal, for: .scrollContent)
            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("profile.orderFilter.title"))
            .accessibilityIdentifier("profile.orderFilter.picker")
            if isEmpty {
                // Native restyle r1 (spec §3.5): the filtered-empty state is a ContentUnavailableView with its one action.
                ContentUnavailableView {
                    Label { Text("profile.orderFilter.empty").accessibilityIdentifier("profile.orderFilter.empty") } icon: {
                        // Round 4: MP filtered-empty is cy-empty kind=empty (empty_state_bg + figure).
                        CYEmptyIllustration(kind: .generic, size: 96)
                    }
                } description: {
                    Text("profile.orderParity.filterEmptyHint")
                        .accessibilityIdentifier("profile.orderFilter.emptyHint")
                } actions: {
                    Button("profile.orderFilter.clear") { selection = .all }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule)
                        .accessibilityIdentifier("profile.orderFilter.clear")
                }
            }
        }
    }
}

private struct ProfileOrderFilterChip: View {
    let filter: ProfileOrderHistoryFilter
    let isSelected: Bool
    let choose: () -> Void
    var body: some View {
        OrderFilterPill(title: LocalizedStringKey(filter.chipTitleKey), isSelected: isSelected, choose: choose)
            .accessibilityIdentifier("profile.orderFilter.chip.\(filter.rawValue)")
    }
}
