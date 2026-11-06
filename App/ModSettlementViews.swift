import SwiftUI

func modSettlementText(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "ModSettlement", locale: locale))
}

/// Insert in the existing Account creator/workshop section. Never routes to an admin or payment screen.
@MainActor struct ModSettlementAccountLink: View {
    let makeReader: @MainActor () -> ModSettlementReader
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationLink { ModSettlementSessionHost(makeReader: makeReader) } label: {
            Label(modSettlementText("modSettlement.title", locale: locale), systemImage: "doc.text.magnifyingglass")
        }.accessibilityIdentifier("modSettlement.accountEntry")
    }
}

/// Observe the real owner directly, so a pushed detail cannot outlive an account/role/realm epoch.
@MainActor private struct ModSettlementSessionHost: View {
    let makeReader: @MainActor () -> ModSettlementReader
    @EnvironmentObject private var session: AppSession
    private var identity: String {
        [String(session.account?.id ?? 0), session.account?.effectiveRole ?? "signed-out",
         String(session.sessionRevision), String(session.contentDetailRevision)].joined(separator: ":")
    }
    var body: some View {
        ModSettlementListView(reader: makeReader()).id(identity)
    }
}

@MainActor struct ModSettlementListView: View {
    @State private var model: ModSettlementBrowser
    @State private var selection: ModSettlementSelection?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    init(reader: ModSettlementReader) { _model = State(initialValue: ModSettlementBrowser(reader: reader)) }
    private func text(_ key: String) -> String { modSettlementText(key, locale: locale) }
    var body: some View {
        List {
            Section {
                Text(text("modSettlement.boundary")).font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(text("modSettlement.noPaymentAction")).font(Theme.Font.label).fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    ModCreatorIncomeListView(reader: model.reader)
                } label: {
                    Label(locale.language.languageCode?.identifier == "zh" ? "读取原 MOD 交易分配与退款/拒付事实" : "Read original MOD allocations and reversal facts", systemImage: "doc.text.magnifyingglass")
                }.accessibilityIdentifier("modCreatorIncome.open")
            }
            if model.loading { ProgressView(text("modSettlement.loading")) }
            if let issue = model.issue { ModSettlementIssueView(issue: issue) { await model.refresh() } }
            if let overview = model.visibleOverview {
                Section(text("modSettlement.qualification.title")) {
                    if let qualification = overview.qualification {
                        Text(text(qualification.presentationKey()))
                        LabeledContent(text("modSettlement.qualification.revision"), value: String(qualification.revision))
                        if let expiry = qualification.expiresAt { LabeledContent(text("modSettlement.qualification.expires")) { Text(expiry, style: .date) } }
                    } else { Text(text("modSettlement.qualification.missing")) }
                    Text(text("modSettlement.qualification.channelUnknown")).font(Theme.Font.label).foregroundStyle(.secondary)
                }
                Section(text("modSettlement.records")) {
                    if overview.records.isEmpty { Text(text("modSettlement.empty")).accessibilityIdentifier("modSettlement.empty") }
                    ForEach(overview.records) { record in
                        Button {
                            selection = model.select(record)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                                Text(verbatim: record.orderKey).font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                Text(text(record.state.localizationKey)).font(Theme.Font.cardTitle)
                                Text(verbatim: record.currency + " " + String(record.amount) + " · " + text("modSettlement.minorUnits")).font(Theme.Font.sectionTitle).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                                if record.frozen { Label(text("modSettlement.frozen"), systemImage: "exclamationmark.shield")
                            .font(Theme.Font.cardTitle).fixedSize(horizontal: false, vertical: true) }
                                Text(record.updatedAt, style: .date).font(Theme.Font.label).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Theme.Space.s2)
                        }.buttonStyle(.plain).accessibilityIdentifier("modSettlement.record." + record.id)
                    }
                    if model.hasMore {
                        Button(locale.language.languageCode?.identifier == "zh" ? "读取下一页原结算记录" : "Read next original settlement page") {
                            Task { await model.loadMore() }
                        }.disabled(model.loading || model.loadingMore)
                    }
                    if model.loadingMore { ProgressView() }
                }
                Section {
                    LabeledContent(text("modSettlement.lastRead")) { Text(overview.readAt, style: .time) }
                }
            }
        }
        .walletContentList()
        .navigationTitle(text("modSettlement.title"))
        .privacySensitive()
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await model.refresh() } } label: { Label(text("modSettlement.refresh"), systemImage: "arrow.clockwise") }
                .disabled(model.loading).accessibilityIdentifier("modSettlement.refresh")
        } }
        .navigationDestination(item: $selection) { value in
            ModSettlementDetailView(reader: model.reader, selection: value).id(value.id)
        }
        .onDisappear { model.invalidate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
            else { model.invalidate() }
        }
        .onChange(of: selection?.id) { _, id in
            if id == nil { Task { await model.refresh() } }
        }
    }
}

@MainActor struct ModSettlementDetailView: View {
    @State private var model: ModSettlementDetailModel
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    init(reader: ModSettlementReader, selection: ModSettlementSelection) {
        _model = State(initialValue: ModSettlementDetailModel(reader: reader, selection: selection))
    }
    private func text(_ key: String) -> String { modSettlementText(key, locale: locale) }
    var body: some View {
        List {
            if model.loading { ProgressView(text("modSettlement.loading")) }
            if model.reader.scope != model.selection.scope {
                Text(text("modSettlement.issue.stale")).accessibilityIdentifier("modSettlement.stale")
            } else if let issue = model.issue { ModSettlementIssueView(issue: issue) { await model.refresh() } }
            if let record = model.visibleRecord {
                Section(text("modSettlement.result")) {
                    Text(text(record.state.localizationKey)).font(Theme.Font.sectionTitle).fixedSize(horizontal: false, vertical: true)
                    Text(text(record.state.explanationKey))
                    if record.frozen {
                        Label(text("modSettlement.frozen"), systemImage: "exclamationmark.shield")
                            .font(Theme.Font.cardTitle).fixedSize(horizontal: false, vertical: true)
                        Text(text("modSettlement.frozenExplanation")).font(Theme.Font.label).fixedSize(horizontal: false, vertical: true)
                    }
                    LabeledContent(text(record.isProviderConfirmedPaid ? "modSettlement.confirmedAmount" : "modSettlement.proposedAmount"),
                                   value: record.currency + " " + String(record.amount)).font(Theme.Font.sectionTitle).monospacedDigit()
                    Text(text("modSettlement.minorUnitsExplanation")).font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    LabeledContent(text("modSettlement.retainedAmount"), value: record.currency + " " + String(record.retainedAmount)).monospacedDigit()
                    Text(text("modSettlement.reserveExplanation")).font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Section(text("modSettlement.trace")) {
                    value("modSettlement.settlementID", record.id)
                    value("modSettlement.orderID", record.orderKey)
                    LabeledContent(text("modSettlement.version"), value: String(record.version))
                    if let key = record.intentKey { value("modSettlement.intentKey", key) }
                    if let result = record.providerTransferId { value("modSettlement.providerResult", result) }
                    LabeledContent(text("modSettlement.createdAt")) { Text(record.createdAt, format: .dateTime) }
                    LabeledContent(text("modSettlement.updatedAt")) { Text(record.updatedAt, format: .dateTime) }
                    if let time = model.readAt { LabeledContent(text("modSettlement.lastRead")) { Text(time, style: .time) } }
                }
                Section {
                    Text(text("modSettlement.readbackOnly"))
                    Text(text("modSettlement.reviewBoundary")).font(Theme.Font.label).foregroundStyle(.secondary)
                    Text(text("modSettlement.noPaymentAction")).font(Theme.Font.label).foregroundStyle(.secondary)
                }
            }
        }
        .walletContentList()
        .navigationTitle(text("modSettlement.detail"))
        .privacySensitive()
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await model.refresh() } } label: { Label(text("modSettlement.refreshResult"), systemImage: "arrow.clockwise") }
                .disabled(model.loading || model.reader.scope != model.selection.scope)
                .accessibilityIdentifier("modSettlement.refreshResult")
        } }
        .onDisappear { model.invalidate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } } else { model.invalidate() }
        }
    }
    private func value(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text(key)).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.footnote).textSelection(.enabled)
        }
    }
}

@MainActor private struct ModSettlementIssueView: View {
    let issue: ModSettlementIssue
    let retry: @MainActor () async -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            Text(modSettlementText(issue.localizationKey, locale: locale)).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("modSettlement.issue")
            if issue != .login && issue != .stale && issue != .notConfigured {
                Button(modSettlementText("modSettlement.retry", locale: locale)) { Task { await retry() } }
                    .buttonStyle(.bordered).frame(minHeight: 44)
                    .accessibilityIdentifier("modSettlement.retry")
            }
        }
    }
}
