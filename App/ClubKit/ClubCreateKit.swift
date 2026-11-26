import SwiftUI

// MC-01 / MC-10 · wizard kit for the real 创建俱乐部 flow (类型 → 方向 → 资料 → 城市) that lives in
// ClubOperationsProfileForm. Native rows: a checkmark list for single choice, bordered capsules for chips,
// 城市 as a value row that opens a searchable list.

/// Single-choice row (Settings checkmark list): optional icon, title, one line; selected = trailing checkmark.
struct ClubR1OptionCard: View {
    let title: Text
    var subtitle: String?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Label {
                        titleStack
                    } icon: {
                        Image(systemName: systemImage)
                    }
                } else {
                    titleStack
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
                .foregroundStyle(.primary)
            if let subtitle, !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Selectable capsule chip: system bordered capsule; selected = prominent.
struct ClubR1Chip: View {
    let title: Text
    var icon: Image? = nil
    let isSelected: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 16

    var body: some View {
        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Round 2 MP asset: the MP chip shows the tag-library icon before the label (create wxml:82).
                if let icon {
                    icon.resizable().renderingMode(.template).scaledToFit()
                        .frame(width: iconSide, height: iconSide).accessibilityHidden(true)
                }
                title
            }
        }
        .buttonBorderShape(.capsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Flow layout that wraps chips onto new lines.
struct ClubR1WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Inline error under a field (never a disabled primary).
struct ClubR1FieldError: View {
    let text: String
    var body: some View {
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .font(.footnote)
        .foregroundStyle(.red)
        .accessibilityElement(children: .combine)
    }
}

/// The city list of the 选择城市 sheet: current location first, then the hot list, filtered by search.
enum ClubCreateCityCatalog {
    static let hot = ["上海", "北京", "杭州", "南京", "成都", "广州", "深圳", "武汉", "西安", "重庆"]

    static func filtered(current: String?, query: String) -> (current: String?, others: [String]) {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCurrent = current?.trimmingCharacters(in: .whitespacesAndNewlines)
        let here = (trimmedCurrent?.isEmpty ?? true) ? nil : trimmedCurrent
        let others = hot.filter { $0 != here && (needle.isEmpty || $0.contains(needle)) }
        let shownCurrent: String? = here.flatMap { city in needle.isEmpty || city.contains(needle) ? city : nil }
        if shownCurrent == nil, others.isEmpty, !needle.isEmpty {
            // A city outside the hot list can still be picked by its typed name.
            return (nil, [needle])
        }
        return (shownCurrent, others)
    }
}

/// 城市 row: opens the picker sheet. Shows the placeholder until a city is chosen.
struct ClubCreateCityRow: View {
    @Binding var city: String
    var currentCity: String?
    var hasError: Bool
    @State private var showsPicker = false
    @Environment(\.locale) private var locale

    var body: some View {
        Button { showsPicker = true } label: {
            HStack {
                Text(verbatim: clubR1("create.city.label", locale))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(verbatim: city.isEmpty ? clubR1("create.city.placeholder", locale) : city)
                    .foregroundStyle(city.isEmpty ? (hasError ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tertiary)) : AnyShapeStyle(.secondary))
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityHint(Text(verbatim: clubR1("create.city.hint", locale)))
        .sheet(isPresented: $showsPicker) { Group {
            ClubCreateCityPicker(current: currentCity, selection: city.isEmpty ? nil : city) { picked in
                city = picked
            }
        }.cySheet()
        }
    }
}

/// 选择城市 sheet: searchable list with 当前定位 and 热门城市. Commits on tap (pick-one), no 确定.
struct ClubCreateCityPicker: View {
    let current: String?
    let selection: String?
    let onPick: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        let lists = ClubCreateCityCatalog.filtered(current: current, query: query)
        NavigationStack {
            List {
                if let here = lists.current {
                    Section {
                        row(here)
                    } header: {
                        Text(verbatim: clubR1("create.city.current", locale))
                    }
                }
                if !lists.others.isEmpty {
                    Section {
                        ForEach(lists.others, id: \.self) { name in row(name) }
                    } header: {
                        Text(verbatim: clubR1("create.city.hot", locale))
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text(verbatim: clubR1("create.city.search", locale)))
            .navigationTitle(Text(verbatim: clubR1("create.city.sheetTitle", locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ name: String) -> some View {
        Button {
            onPick(name)
            dismiss()
        } label: {
            HStack {
                Text(verbatim: name)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if name == selection {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(name == selection ? .isSelected : [])
    }
}

/// Icons for the six club types, in `ClubOperationsCatalog.types` order.
enum ClubR1CreateSymbols {
    static let types = ["graduationcap", "figure.hiking", "person.3", "building.2", "camera", "ellipsis.circle"]
    static func type(_ index: Int) -> String { types.indices.contains(index) ? types[index] : "circle.grid.2x2" }
}
