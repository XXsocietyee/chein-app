import SwiftUI
import Charts
import Accessibility

/// Original income-table analysis: at most ten approved 20-row reads, not an atomic snapshot.
@MainActor struct WalletIncomeAnalysisView: View {
    let reader: WalletCommerceReader
    /// PC-D-6-5: the signed-out state names its next step (MP 登录). Nil (in-app, already signed in) keeps the text only.
    var onSignIn: (() -> Void)? = nil
    @StateObject private var model = WalletIncomeAnalysisReader()
    @Environment(\.scenePhase) private var phase
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.themeDomain) private var domain
    @State private var visible = false
    @State private var mode = WalletIncomeAnalysisPresentation.Mode.income
    @State private var selectedCurrency: String?
    @State private var measuredAt = Date()
    private func text(_ key: String) -> Text { Text(LocalizedStringKey("wallet.analysis." + key), tableName: "WalletIncomeAnalysis") }
    private func readText(_ key: String) -> Text { Text(LocalizedStringKey("wallet.analysis.read." + key), tableName: "WalletIncomeAnalysisRead") }
    var body: some View {
        List {
            // PC-D-6-3: the page title is drawn once, by the bar (no in-content hero header).
            if !reader.isConfigured { text("unavailable") }
            else if reader.scope == nil || model.requiresLogin {
                text("login")
                if let onSignIn {
                    Button(action: onSignIn) { Text("mp.common.signIn") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .accessibilityIdentifier("wallet.analysis.signIn")
                }
            }
            else if model.loading {
                Section {
                    ProgressView { text("loading") }.frame(maxWidth: .infinity)
                }.accessibilityIdentifier("wallet.analysis.loading")
            }
            else if model.unavailable { text("unavailable") }
            else if model.failed {
                Label { text("failed") } icon: { Image(systemName: "exclamationmark.circle").accessibilityHidden(true) }
                    .font(.headline).fixedSize(horizontal: false, vertical: true)
                Button { Task { await load() } } label: { text("retry") }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else if let slice = model.displayedResult(for: reader) {
                content(slice)
            } else { ProgressView().frame(maxWidth: .infinity) }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("wallet.analysis.title", tableName: "WalletIncomeAnalysis"))
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .themeDomain(domain)
        .privacySensitive()
        .task(id: WalletIncomeAnalysisReadIdentity(reader)) { visible = true; await load() }
        .refreshable { await load() }
        .onDisappear { visible = false; model.cancel() }
        .disabled(phase != .active)
        .onChange(of: phase) { _, value in
            if value != .active { model.cancel() }
            else if visible { Task { await load() } }
        }
        .accessibilityIdentifier("wallet.analysis")
        .cyDomainScreen(.player)
    }
    @ViewBuilder private func content(_ slice: WalletIncomeAnalysisSlice) -> some View {
        let currencies = WalletIncomeAnalysisPresentation.currencies(slice.rows)
        let currency = selectedCurrency.flatMap { currencies.contains($0) ? $0 : nil } ?? currencies.first
        let summary = WalletIncomeAnalysisPresentation(rows: slice.rows, mode: mode, currency: currency, now: measuredAt)
        Section {
            // Mini-program `an-seg` 收入 / 提现 first; read-mechanics notes are not user copy.
            if slice.isPartial {
                Label { readText("partial") } icon: { Image(systemName: "exclamationmark.circle").accessibilityHidden(true) }
                Button { Task { await load() } } label: { text("retry") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("wallet.analysis.partial.retry")
            } else if slice.stop == .budget {
                readText("budget").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if dynamicTypeSize.isAccessibilitySize { modePicker.pickerStyle(.menu) }
            else { modePicker.cyAdaptiveSegmented() }
            if currencies.count > 1 {
                Picker(selection: Binding(get: { currency ?? "" }, set: { selectedCurrency = $0 })) {
                    ForEach(currencies, id: \.self) { Text(verbatim: $0).tag($0) }
                } label: { text("currency") }
            }
            if summary.unknownCount > 0 {
                LabeledContent { Text(verbatim: String(summary.unknownCount)) } label: { text("unknown") }
            }
        }
        if model.pageModel.phase == .unknown || model.pageModel.phase == .empty {
            Text(verbatim: model.pageModel.moneyText)
                .font(.headline).monospacedDigit()
                .accessibilityIdentifier("wallet.analysis.page")
        }
        if slice.rows.isEmpty {
            if slice.isPartial { readText("noVerifiedRecords") }
            else {
                ContentUnavailableView {
                    Label { text("empty") } icon: { Image(systemName: "chart.bar.xaxis") }
                }
            }
        }
        else if let currency {
            Section {
                if let current = summary.months.last {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: current.id).font(.footnote).foregroundStyle(.secondary)
                        if summary.unknownCount > 0, current.count == 0 {
                            monthAmount(current, summary: summary, currency: currency)
                                .font(.largeTitle.bold()).monospacedDigit()
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            // Headline amount rolls when the month figure changes (reload, currency switch).
                            Text(verbatim: WalletIncomeAnalysisPresentation.text(current.amount, currency: currency, locale: locale))
                                .font(.largeTitle.bold()).monospacedDigit().contentTransition(.numericText())
                        }
                        if summary.unknownCount > 0 { text("knownSubtotal").font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    // R7-PC-D6-2: VoiceOver reads the month values from the chart itself (Audio Graph + data table),
                    // without opening the disclosure below.
                    monthChart(summary)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(text("months"))
                        .accessibilityChartDescriptor(WalletIncomeMonthChartDescriptor(
                            months: summary.months.map { (label: $0.id, value: NSDecimalNumber(decimal: $0.amount).doubleValue,
                                                          spoken: WalletIncomeAnalysisPresentation.text($0.amount, currency: currency, locale: locale)) },
                            title: String(localized: LocalizedStringResource("wallet.analysis.months", table: "WalletIncomeAnalysis", locale: locale))))
                    DisclosureGroup { monthRows(summary, currency: currency) } label: { text("months") }
                } else { monthRows(summary, currency: currency) }
            } header: { text("months") }
            if mode == .income {
                Section {
                    if summary.sources.isEmpty { text("noSources") }
                    ForEach(summary.sources) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent { Text(verbatim: WalletIncomeAnalysisPresentation.text(source.amount, currency: currency, locale: locale)).monospacedDigit() } label: { text("source." + source.id) }
                            ProgressView(value: sourceFraction(source, summary: summary))
                                .tint(.green).accessibilityHidden(true)
                        }.accessibilityElement(children: .combine)
                    }
                } header: { text("sources") }
            }
        } else { text("currencyUnknown") }
    }
    @ViewBuilder private func monthAmount(_ month: WalletIncomeAnalysisPresentation.Month,
                                          summary: WalletIncomeAnalysisPresentation, currency: String) -> some View {
        if summary.unknownCount > 0, month.count == 0 { text("unverified") }
        else { Text(verbatim: WalletIncomeAnalysisPresentation.text(month.amount, currency: currency, locale: locale)) }
    }
    private func monthRows(_ summary: WalletIncomeAnalysisPresentation, currency: String) -> some View {
        ForEach(summary.months) { month in
            VStack(alignment: .leading, spacing: 2) {
                LabeledContent { monthAmount(month, summary: summary, currency: currency).monospacedDigit() }
                    label: { Text(verbatim: month.id) }
                if summary.unknownCount > 0, month.count > 0 { text("knownSubtotal").font(.footnote).foregroundStyle(.secondary) }
            }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
        }
    }
    private func monthChart(_ summary: WalletIncomeAnalysisPresentation) -> some View {
        // Swift Charts bar chart (system); unverified months plot as zero, the current month is tinted.
        Chart(summary.months) { month in
            BarMark(x: .value(month.id, month.id),
                    y: .value(month.id, (summary.unknownCount == 0 || month.count > 0) ? summary.fraction(month.amount) : 0))
                .foregroundStyle(month.id == summary.months.last?.id ? Color.accentColor : Color.secondary.opacity(0.4))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    Text(verbatim: String((value.as(String.self) ?? "").suffix(2)))
                }
            }
        }
        .frame(height: 120)
    }
    private func sourceFraction(_ source: WalletIncomeAnalysisPresentation.Source,
                                summary: WalletIncomeAnalysisPresentation) -> Double {
        guard let maximum = summary.sources.map(\.amount).max(), maximum > 0 else { return 0 }
        let fraction = NSDecimalNumber(decimal: source.amount / maximum).doubleValue
        return fraction.isFinite ? min(1, max(0, fraction)) : 0
    }
    private var modePicker: some View {
        Picker(selection: $mode) {
            text("income").tag(WalletIncomeAnalysisPresentation.Mode.income)
            text("withdrawal").tag(WalletIncomeAnalysisPresentation.Mode.withdrawal)
        } label: { text("mode") }
    }
    private func load() async {
        guard visible, phase == .active, !Task.isCancelled else { return }
        measuredAt = Date()
        await model.load(reader)
    }
}


/// R7-PC-D6-2: month income as an accessible chart (categorical x = month, y = amount).
private struct WalletIncomeMonthChartDescriptor: AXChartDescriptorRepresentable {
    let months: [(label: String, value: Double, spoken: String)]
    let title: String
    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: title, categoryOrder: months.map { $0.label })
        let maxValue = max(months.map { $0.value }.max() ?? 0, 1)
        let spokenByValue = Dictionary(months.map { ($0.value, $0.spoken) }, uniquingKeysWith: { first, _ in first })
        let y = AXNumericDataAxisDescriptor(title: title, range: 0...maxValue, gridlinePositions: []) { value in
            spokenByValue[value] ?? String(format: "%.2f", value)
        }
        let series = AXDataSeriesDescriptor(name: title, isContinuous: false,
                                            dataPoints: months.map { AXDataPoint(x: $0.label, y: $0.value) })
        return AXChartDescriptor(title: title, summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }
}
