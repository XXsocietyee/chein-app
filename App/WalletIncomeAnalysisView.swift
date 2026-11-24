import SwiftUI
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
                        .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule).frame(minHeight: 44)
                        .accessibilityIdentifier("wallet.analysis.signIn")
                }
            }
            else if model.loading {
                Section {
                    CYSkeleton()
                    text("loading").frame(maxWidth: .infinity)
                }.accessibilityIdentifier("wallet.analysis.loading")
            }
            else if model.unavailable { text("unavailable") }
            else if model.failed {
                Label { text("failed") } icon: { Image(systemName: "exclamationmark.circle").accessibilityHidden(true) }
                    .cyText(.sectionTitle).fixedSize(horizontal: false, vertical: true)
                Button { Task { await load() } } label: { text("retry") }
                    .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule).frame(minHeight: 44)
            } else if let slice = model.displayedResult(for: reader) {
                content(slice)
            } else { CYSkeleton(variant: .detail) }
        }
        .listStyle(.insetGrouped)
        .cyText(.body)
        .background(Theme.Color.bgPage(in: domain))
        .labeledContentStyle(WalletIncomeAnalysisDetailStyle())
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
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                    .accessibilityIdentifier("wallet.analysis.partial.retry")
            } else if slice.stop == .budget {
                readText("budget").cyText(.caption).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if dynamicTypeSize.isAccessibilitySize { modePicker.pickerStyle(.menu) }
            else { modePicker.pickerStyle(.segmented) }
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
                .cyText(.sectionTitle).monospacedDigit()
                .accessibilityIdentifier("wallet.analysis.page")
        }
        if slice.rows.isEmpty {
            if slice.isPartial { readText("noVerifiedRecords") }
            else {
                CYEmptyState(systemImage: "chart.bar.xaxis", LocalizedStringKey("wallet.analysis.empty"), tableName: "WalletIncomeAnalysis")
                text("empty").frame(width: 0, height: 0).clipped().accessibilityHidden(true)
            }
        }
        else if let currency {
            Section {
                if let current = summary.months.last {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: current.id).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                        if summary.unknownCount > 0, current.count == 0 {
                            monthAmount(current, summary: summary, currency: currency)
                                .cyText(.dataXL).monospacedDigit()
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            // Headline amount rolls when the month figure changes (reload, currency switch).
                            CYStatNumber(text: WalletIncomeAnalysisPresentation.text(current.amount, currency: currency, locale: locale),
                                         font: CYTypography.dataXL)
                        }
                        if summary.unknownCount > 0 { text("knownSubtotal").cyText(.caption).foregroundStyle(CYColor.textSecondary) }
                    }.padding(.vertical, CYSpacing.sm)
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
                        VStack(alignment: .leading, spacing: Theme.Space.s2) {
                            LabeledContent { Text(verbatim: WalletIncomeAnalysisPresentation.text(source.amount, currency: currency, locale: locale)).monospacedDigit().cyText(.cardTitle) } label: { text("source." + source.id) }
                            GeometryReader { geometry in
                                Capsule().fill(Theme.Color.success(in: domain))
                                    .frame(width: geometry.size.width * CGFloat(sourceFraction(source, summary: summary)))
                            }.frame(height: Theme.Space.s1).accessibilityHidden(true)
                        }.padding(.vertical, Theme.Space.s2).accessibilityElement(children: .combine)
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
            VStack(alignment: .leading, spacing: Theme.Space.s1) {
                LabeledContent { monthAmount(month, summary: summary, currency: currency).monospacedDigit() }
                    label: { Text(verbatim: month.id) }
                if summary.unknownCount > 0, month.count > 0 { text("knownSubtotal").cyText(.label).foregroundStyle(.secondary) }
            }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
        }
    }
    private func monthChart(_ summary: WalletIncomeAnalysisPresentation) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Space.s3) {
            ForEach(summary.months) { month in
                VStack(spacing: Theme.Space.s2) {
                    GeometryReader { geometry in
                        VStack {
                            Spacer(minLength: 0)
                            if summary.unknownCount == 0 || month.count > 0 {
                                RoundedRectangle(cornerRadius: CYRadius.inner)
                                    .fill(month.id == summary.months.last?.id ? Theme.Color.textPrimary(in: domain) : Theme.Color.bgRaised(in: domain))
                                    .frame(height: geometry.size.height * CGFloat(summary.fraction(month.amount)))
                            }
                        }
                    }.frame(height: 120)
                    Text(verbatim: String(month.id.suffix(2))).cyText(.label).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
            }
        }.padding(.vertical, Theme.Space.s3)
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


// Feature-local layout; it neither supplies a reader nor alters any value.
private struct WalletIncomeAnalysisDetailStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            configuration.label.cyText(.body).foregroundStyle(.secondary)
            configuration.content.fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
