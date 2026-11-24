import SwiftUI

// MC-01 / MC-10 · wizard kit for the real 创建俱乐部 flow (类型 → 方向 → 资料 → 城市) that lives in
// ClubOperationsProfileForm. Option cards with a check badge, direction chips, 城市 as a picker row.

/// Wizard/Option Card: icon, title, one line; selected = 1.5 pt border + check badge.
struct ClubR1OptionCard: View {
    let title: Text
    var subtitle: String?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .cyText(.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgRaised))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    title
                        .cyText(.bodyMedium)
                        .foregroundStyle(palette.textPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(verbatim: subtitle)
                            .cyText(.meta)
                            .foregroundStyle(palette.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .cyText(.cardTitle)
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textTertiary)
                    .scaleEffect(isSelected || reduceMotion ? 1 : 0.85)
                    .accessibilityHidden(true)
            }
            .padding(CYSpacing.md)
            .frame(minHeight: 64)
            .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgElevated))
            .overlay {
                RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)
                    .strokeBorder(isSelected ? palette.textPrimary : palette.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Selectable capsule chip: 36 visual, 44 target. Selected = filled ink, unselected = surface.
struct ClubR1Chip: View {
    let title: Text
    var icon: Image? = nil
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 16

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.xs) {
                // Round 2 MP asset: the MP chip shows the tag-library icon before the label (create wxml:82).
                if let icon {
                    icon.resizable().renderingMode(.template).scaledToFit()
                        .frame(width: iconSide, height: iconSide).accessibilityHidden(true)
                }
                title
            }
                .cyText(.bodyMedium)
                .foregroundStyle(isSelected ? palette.actionPrimaryFg : palette.textPrimary)
                .padding(.horizontal, CYSpacing.lg)
                .frame(minHeight: 36)
                .background(Capsule(style: .continuous).fill(isSelected ? palette.actionPrimaryBg : palette.bgElevated))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .cyText(.meta)
        .foregroundStyle(palette.danger)
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
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Button { showsPicker = true } label: {
            HStack(spacing: CYSpacing.sm) {
                Text(verbatim: clubR1("create.city.label", locale))
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: CYSpacing.sm)
                Text(verbatim: city.isEmpty ? clubR1("create.city.placeholder", locale) : city)
                    .foregroundStyle(city.isEmpty ? (hasError ? palette.danger : palette.textPlaceholder) : palette.textSecondary)
                Image(systemName: "chevron.right")
                    .cyText(.label, weight: .semibold)
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .cyText(.body)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(verbatim: clubR1("create.city.hint", locale)))
        .sheet(isPresented: $showsPicker) { Group {
            ClubCreateCityPicker(current: currentCity, selection: city.isEmpty ? nil : city) { picked in
                city = picked
            }
        }.cySheet()
        }
    }
}

/// 选择城市 sheet: search, 当前定位, 热门城市. Commits on tap (pick-one), no 确定.
struct ClubCreateCityPicker: View {
    let current: String?
    let selection: String?
    let onPick: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        let lists = ClubCreateCityCatalog.filtered(current: current, query: query)
        // Shared resizable sheet (fit → large); it owns the header, the scroll view and the detents.
        CYResizableSheet(kind: .pickerLong, title: Text(verbatim: clubR1("create.city.sheetTitle", locale))) {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
                TextField(text: $query, prompt: Text(verbatim: clubR1("create.city.search", locale))) {
                    Text(verbatim: clubR1("create.city.search", locale))
                }
                .cyText(.body)
            }
            .padding(.horizontal, CYSpacing.md)
            .frame(minHeight: 36)
            .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgSurfaceSubtle))
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    if let here = lists.current {
                        ClubR1Group(header: clubR1("create.city.current", locale)) { row(here) }
                    }
                    if !lists.others.isEmpty {
                        ClubR1Group(header: clubR1("create.city.hot", locale)) {
                            ForEach(lists.others, id: \.self) { name in
                                row(name)
                                if name != lists.others.last { Divider().padding(.leading, CYSpacing.lg) }
                            }
                        }
                    }
                }
        }
        }
    }

    private func row(_ name: String) -> some View {
        Button {
            onPick(name)
            dismiss()
        } label: {
            ClubR1Row(title: name) { ClubR1AccessoryView(accessory: name == selection ? .check : .none) }
        }
        .buttonStyle(CYListRowButtonStyle())
        .accessibilityAddTraits(name == selection ? .isSelected : [])
    }
}

/// Icons for the six club types, in `ClubOperationsCatalog.types` order.
enum ClubR1CreateSymbols {
    static let types = ["graduationcap", "figure.hiking", "person.3", "building.2", "camera", "ellipsis.circle"]
    static func type(_ index: Int) -> String { types.indices.contains(index) ? types[index] : "circle.grid.2x2" }
}
