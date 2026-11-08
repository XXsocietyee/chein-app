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
                }.padding(.vertical, 4)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("profile.orderFilter.title"))
            .accessibilityIdentifier("profile.orderFilter.picker")
            if isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("profile.orderFilter.empty").accessibilityIdentifier("profile.orderFilter.empty")
                    Text("profile.orderParity.filterEmptyHint").font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.orderFilter.emptyHint")
                }
                Button("profile.orderFilter.clear") { selection = .all }
                    .accessibilityIdentifier("profile.orderFilter.clear")
            }
        }
    }
}

private struct ProfileOrderFilterChip: View {
    let filter: ProfileOrderHistoryFilter
    let isSelected: Bool
    let choose: () -> Void
    var body: some View {
        Button(action: choose) {
            Text(LocalizedStringKey(filter.chipTitleKey)).font(.subheadline)
                .padding(.horizontal, 12).frame(minHeight: CYSpacing.minTouchTarget)
                .background(Capsule().fill(isSelected ? CYColor.accent : Color.secondary.opacity(0.15)))
                .foregroundStyle(isSelected ? CYColor.textOnAccent : Color.primary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("profile.orderFilter.chip.\(filter.rawValue)")
    }
}
