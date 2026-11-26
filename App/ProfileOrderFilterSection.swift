import SwiftUI

/// Uses only the enclosing screen's already-read rows. A filter selection never reloads.
/// Source scene-member-order-history uses a chip row (cy-tabs variant="chip"); design P1 G-053 draws it as the
/// system filter menu (Mail / Reminders "Filter by"): one `Picker(.menu)` row with the nine MP options in MP order,
/// instead of a horizontally scrolling row of capsule buttons.
struct ProfileOrderFilterSection: View {
    @Binding var selection: ProfileOrderHistoryFilter
    let isEmpty: Bool
    var body: some View {
        Section {
            Picker(selection: $selection) {
                ForEach(ProfileOrderHistoryFilter.allCases) { filter in
                    Text(LocalizedStringKey(filter.chipTitleKey))
                        .tag(filter)
                        .accessibilityIdentifier("profile.orderFilter.chip.\(filter.rawValue)")
                }
            } label: {
                Label {
                    Text("profile.orderFilter.title")
                } icon: {
                    Image(systemName: selection == .all ? "line.3.horizontal.decrease.circle"
                                                        : "line.3.horizontal.decrease.circle.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                }
            }
            .pickerStyle(.menu)
            .sensoryFeedback(.selection, trigger: selection)
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
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("profile.orderFilter.clear")
                }
            }
        }
    }
}
