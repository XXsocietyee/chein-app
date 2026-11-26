import SwiftUI

@MainActor struct SearchMapFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GlobalSearchQuery
    @State private var minimum: String
    @State private var maximum: String
    @State private var dateDraft: SearchMapDateFilterDraft
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
                        Picker("searchMap.sort", selection: $sortType) {
                            Text("searchMap.nearest").tag(1) // R7-PC-A5-3: MP searchmap sort_type 最近 only; 最热 removed (pages/searchmap/index.js:281)
                        }
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
                        Text("searchMap.categoryFailed").font(.caption)
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
                    // R7-PC-A3-3: MP search2 start/end `picker mode="date"` rows (pages/search2/index.wxml:100-129).
                    // Native: a Toggle that reveals an inline compact DatePicker, as Reminders does for an optional date.
                    Toggle("searchMap.startDate", isOn: dateEnabled(\.startDate))
                        .accessibilityIdentifier("searchMap.filter.start.toggle")
                    if !dateDraft.startDate.isEmpty {
                        DatePicker("mapDatePicker.start", selection: dateValue(\.startDate), displayedComponents: .date)
                            .accessibilityIdentifier("searchMap.filter.start")
                    }
                    Toggle("searchMap.endDate", isOn: dateEnabled(\.endDate))
                        .accessibilityIdentifier("searchMap.filter.end.toggle")
                    if !dateDraft.endDate.isEmpty {
                        DatePicker("mapDatePicker.end", selection: dateValue(\.endDate), displayedComponents: .date)
                            .accessibilityIdentifier("searchMap.filter.end")
                    }
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
    }
    /// Gregorian civil day in the phone's zone, matching `SearchMapDateFilterDraft.select` (YYYY-MM-DD).
    private static var civilCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current; return calendar
    }
    private static func civilString(_ date: Date) -> String {
        let parts = civilCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
    private static func civilDate(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return civilCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
    /// On: today (or the start day for 结束日期). Off: clears the bound.
    private func dateEnabled(_ field: WritableKeyPath<SearchMapDateFilterDraft, String>) -> Binding<Bool> {
        Binding(get: { !dateDraft[keyPath: field].isEmpty }, set: { isOn in
            if isOn {
                let fallback = field == \SearchMapDateFilterDraft.endDate && !dateDraft.startDate.isEmpty
                    ? dateDraft.startDate : Self.civilString(Date())
                dateDraft[keyPath: field] = fallback
            } else {
                dateDraft[keyPath: field] = ""
            }
            invalid = false
        })
    }
    private func dateValue(_ field: WritableKeyPath<SearchMapDateFilterDraft, String>) -> Binding<Date> {
        Binding(get: { Self.civilDate(dateDraft[keyPath: field]) ?? Date() },
                set: { dateDraft[keyPath: field] = Self.civilString($0); invalid = false })
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
