import SwiftUI

@MainActor struct SearchMapFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GlobalSearchQuery
    @State private var minimum: String
    @State private var maximum: String
    @State private var dateDraft: SearchMapDateFilterDraft
    @State private var datePicker: SearchMapDatePickerDraft?
    @State private var invalid = false
    @State private var tag: String
    @State private var cityRole: String
    @State private var sortType: Int
    let applyCityOptions: ((String, String, Int) -> Void)?
    let categories: [DiscoveryCategory]
    let categoryFailed: Bool
    let categoryLoading: Bool
    let categoryLoaded: Bool
    let retryCategories: (() -> Void)?
    let apply: (GlobalSearchQuery) -> Void
    init(filter: GlobalSearchQuery, categories: [DiscoveryCategory], categoryFailed: Bool,
         categoryLoading: Bool = false, categoryLoaded: Bool = false, retryCategories: (() -> Void)? = nil,
         tag: String = "", cityRole: String = "", sortType: Int = 1,
         applyCityOptions: ((String, String, Int) -> Void)? = nil, apply: @escaping (GlobalSearchQuery) -> Void) {
        _draft = State(initialValue: filter)
        _tag = State(initialValue: tag); _cityRole = State(initialValue: cityRole); _sortType = State(initialValue: sortType)
        self.applyCityOptions = applyCityOptions
        _minimum = State(initialValue: filter.minimumPrice.map { String($0) } ?? "")
        _maximum = State(initialValue: filter.maximumPrice.map { String($0) } ?? "")
        _dateDraft = State(initialValue: SearchMapDateFilterDraft(filter: filter))
        self.categories = categories; self.categoryFailed = categoryFailed; self.apply = apply
        self.categoryLoading = categoryLoading; self.categoryLoaded = categoryLoaded; self.retryCategories = retryCategories
    }
    var body: some View {
        NavigationStack {
            Form {
                if applyCityOptions != nil {
                    Section("searchMap.cityOptions") {
                        TextField("searchMap.tag", text: $tag).accessibilityIdentifier("searchMap.tag")
                        TextField("searchMap.cityRole", text: $cityRole).accessibilityIdentifier("searchMap.cityRole")
                        // R7-PC-A5-3 (r1 PC-A-5-4): MP searchmap sorts by 最近 only (`sort_type:1`); no 最热 option.
                    }
                }
                Section("searchMap.categories") {
                    Picker("searchMap.category", selection: $draft.categoryID) {
                        Text("searchMap.all").tag(Int?.none)
                        ForEach(categories) { Text(verbatim: $0.name).tag(Optional($0.id)) }
                        // Keep an explicit tag for a selection missing from the new directory.
                        // Only the user's selection/reset/Apply may change this manual draft.
                        if let selectedID = draft.categoryID, !categories.contains(where: { $0.id == selectedID }) {
                            (Text("searchMap.category") + Text(verbatim: " #\(selectedID)"))
                                .tag(Optional(selectedID))
                        }
                    }
                    .accessibilityIdentifier("searchMap.filter.category")
                    if categoryLoading {
                        ProgressView("searchMap.loading").accessibilityIdentifier("searchMap.category.loading")
                    } else if categoryFailed {
                        Text("searchMap.categoryFailed.mp").font(.caption)
                            .accessibilityIdentifier("searchMap.category.failed")
                        if let retryCategories {
                            Button("searchMap.retry", action: retryCategories).frame(minHeight: 44)
                                .accessibilityIdentifier("searchMap.category.retry")
                        }
                    } else if categoryLoaded && categories.isEmpty {
                        Text("searchMap.empty").font(.caption)
                            .accessibilityIdentifier("searchMap.category.empty")
                    }
                }
                Section("searchMap.dates") {
                    Button("mapDatePreset.today") { selectDatePreset(.today) }
                        .frame(minHeight: 44).accessibilityIdentifier("mapDatePreset.today")
                    Button("mapDatePreset.tomorrow") { selectDatePreset(.tomorrow) }
                        .frame(minHeight: 44).accessibilityIdentifier("mapDatePreset.tomorrow")
                    if applyCityOptions != nil {
                        Text("mapDatePreset.disclosure").font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("globalDatePreset.disclosure").font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // R7-PC-A3-3 (r1 PC-A-3-4): inline system date rows, no second sheet over 筛选 and no free-text dates.
                    SearchMapInlineDateRow(title: "searchMap.startDate", text: $dateDraft.startDate, identifier: "searchMap.filter.start")
                    SearchMapInlineDateRow(title: "searchMap.endDate", text: $dateDraft.endDate, identifier: "searchMap.filter.end")
                }
                Section("searchMap.price") {
                    TextField("searchMap.minimum", text: $minimum).keyboardType(.decimalPad)
                        .accessibilityIdentifier("searchMap.filter.min")
                        .accessibilityLabel(Text("searchMap.minimum"))
                        .accessibilityValue(Text(verbatim: minimum.isEmpty ? "—" : minimum))
                        .accessibilityHint(Text("searchMap.price"))
                    TextField("searchMap.maximum", text: $maximum).keyboardType(.decimalPad)
                        .accessibilityIdentifier("searchMap.filter.max")
                        .accessibilityLabel(Text("searchMap.maximum"))
                        .accessibilityValue(Text(verbatim: maximum.isEmpty ? "—" : maximum))
                        .accessibilityHint(Text("searchMap.price"))
                }
                if applyCityOptions == nil {
                    Section("searchMap.sort") {
                        Picker("searchMap.sort", selection: .constant(SearchListSort.recent)) {
                            Text("search.sort.recent").tag(SearchListSort.recent)
                        }
                        .accessibilityIdentifier("search.sort.recent")
                        .accessibilityLabel(Text("searchMap.sort"))
                        .accessibilityValue(Text("search.sort.recent"))
                        .accessibilityHint(Text("search.sort.recent"))
                    }
                }
                if invalid { Label("searchMap.invalidInput", systemImage: "exclamationmark.circle").accessibilityIdentifier("searchMap.filter.invalid") }
                Button("searchMap.resetFilters") {
                    draft = GlobalSearchQuery(keyword: draft.keyword); minimum = ""; maximum = ""; dateDraft = SearchMapDateFilterDraft(filter: draft); invalid = false
                    tag = ""; cityRole = ""; sortType = 1
                }.frame(minHeight: 44).accessibilityIdentifier("searchMap.filter.reset")
            }.textInputAutocapitalization(.never).autocorrectionDisabled()
                .appNavigationTitle("searchMap.filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("searchMap.cancel") { dismiss() }.accessibilityIdentifier("searchMap.filter.cancel") }
                    ToolbarItem(placement: .confirmationAction) { Button("searchMap.apply") { commit() }.accessibilityIdentifier("searchMap.filter.apply") }
                }
        }
        .sheet(item: $datePicker) { picker in Group {
            SearchMapDatePickerSheet(initial: picker) { selection in
                do {
                    dateDraft = try selection.confirming(in: dateDraft)
                    invalid = false; datePicker = nil
                    return true
                } catch { return false }
            }
        }.cySheet() }
    }
    private func openDatePicker(_ field: SearchMapDatePickerField) {
        datePicker = SearchMapDatePickerDraft(field: field, draft: dateDraft)
    }
    private func selectDatePreset(_ preset: SearchMapDatePreset) {
        do { try dateDraft.select(preset); invalid = false } catch { invalid = true }
    }
    private func commit() {
        func optional(_ text: String) -> String? {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value
        }
        if let value = optional(minimum), Double(value) == nil { invalid = true; return }
        if let value = optional(maximum), Double(value) == nil { invalid = true; return }
        draft.minimumPrice = optional(minimum).flatMap(Double.init); draft.maximumPrice = optional(maximum).flatMap(Double.init)
        do {
            let applied = try dateDraft.applying(to: draft)
            applyCityOptions?(tag, cityRole, sortType); apply(applied); dismiss()
        } catch { invalid = true }
    }
}

/// Numeric native wheels deliberately keep Gregorian civil dates separate from
/// instants, regardless of the device's preferred calendar or display locale.
@MainActor private struct SearchMapDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Wheel rows are clipped to this height. It tracks title2 so the clip window grows with the text.
    @ScaledMetric(relativeTo: .title2) private var wheelHeight: CGFloat = 160
    @State private var picker: SearchMapDatePickerDraft
    @State private var invalid = false
    let confirm: (SearchMapDatePickerDraft) -> Bool

    init(initial: SearchMapDatePickerDraft, confirm: @escaping (SearchMapDatePickerDraft) -> Bool) {
        _picker = State(initialValue: initial)
        self.confirm = confirm
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(verbatim: picker.value).font(.headline)
                        .accessibilityIdentifier("mapDatePicker.value")
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
                    layout {
                        wheel("mapDatePicker.year", values: SearchMapDatePickerDraft.years,
                              selection: Binding(get: { picker.year }, set: { picker.selectYear($0); invalid = false }),
                              identifier: "mapDatePicker.year")
                        wheel("mapDatePicker.month", values: 1...12,
                              selection: Binding(get: { picker.month }, set: { picker.selectMonth($0); invalid = false }),
                              identifier: "mapDatePicker.month")
                        wheel("mapDatePicker.day", values: picker.days,
                              selection: Binding(get: { picker.day }, set: { picker.selectDay($0); invalid = false }),
                              identifier: "mapDatePicker.day")
                    }
                    if invalid {
                        Label("mapDatePicker.invalidOrder", systemImage: "exclamationmark.circle")
                            .accessibilityIdentifier("mapDatePicker.invalidOrder")
                    }
                }.padding()
            }
            .appNavigationTitle(picker.field == .start ? "mapDatePicker.start" : "mapDatePicker.end")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("searchMap.cancel") { dismiss() }.accessibilityIdentifier("mapDatePicker.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("mapDatePicker.confirm") { invalid = !confirm(picker) }
                        .accessibilityIdentifier("mapDatePicker.confirm")
                }
            }
        }
    }

    private func wheel(_ title: LocalizedStringKey, values: ClosedRange<Int>, selection: Binding<Int>, identifier: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { Text(verbatim: String($0)).tag($0) }
            }
            .pickerStyle(.wheel).labelsHidden().frame(height: wheelHeight).clipped()
            .accessibilityIdentifier(identifier)
        }.frame(maxWidth: .infinity)
    }
}

/// One `YYYY-MM-DD` bound as an inline compact `DatePicker`. Empty shows a 选择 button; a set value can be cleared.
/// Gregorian civil date in the device zone, the same format the presets store.
@MainActor struct SearchMapInlineDateRow: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let identifier: String
    private static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c }
    private static func parse(_ value: String) -> Date? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
    private static func format(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
    var body: some View {
        if let date = Self.parse(text) {
            HStack {
                DatePicker(title, selection: Binding(get: { date }, set: { text = Self.format($0) }), displayedComponents: .date)
                    .environment(\.calendar, Self.calendar)
                    .accessibilityIdentifier(identifier)
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("searchMap.clearDate"))
                .accessibilityIdentifier("\(identifier).clear")
            }
        } else {
            Button { text = Self.format(Date()) } label: {
                LabeledContent(title) { Image(systemName: "calendar").foregroundStyle(.secondary) }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier(identifier)
        }
    }
}
