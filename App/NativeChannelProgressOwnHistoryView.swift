import SwiftUI

@MainActor struct NativeChannelProgressOwnHistoryView: View {
    @Bindable var model: NativeChannelProgressCoordinator
    @StateObject private var actions = NativeChannelProgressActionLifetime()
    var body: some View {
        List {
            Section {
                CYHeroHeader("d7.channelProgress.historyTitle", tableName: "NativeChannelProgress")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if !model.isCurrent {
                CYStatusChip(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.closed"), tone: .warning, systemImage: "lock")
                    .accessibilityLabel(Text("d7.channelProgress.closed", tableName: "NativeChannelProgress"))
            }
            if model.busy { NativeChannelProgressHistoryLoading() }
            Section {
                if let best = model.best { NativeChannelProgressMeCard(row: best).listRowBackground(Color.clear) }
                else if !model.busy && model.issue("best") == nil {
                    Text(verbatim: "—")
                        .font(CYTypography.dataXL)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(verbatim: "—"))
                }
                NativeChannelProgressIssueView(model: model, part: "best")
            } header: { NativeChannelSectionTitle(key: "best") }
            Section {
                if let page = model.recent.page {
                    if !page.visible {
                        CYEmptyState(systemImage: "eye.slash", "d7.channelProgress.hidden", tableName: "NativeChannelProgress")
                    } else {
                        if model.recent.rows.isEmpty {
                            CYEmptyState(systemImage: "clock", "d7.channelProgress.emptyHistory", tableName: "NativeChannelProgress")
                        }
                        ForEach(Array(model.recent.rows.enumerated()), id: \.offset) { _, row in NativeChannelProgressRowView(row: row) }
                        if page.nextCursor != nil {
                            CYPillButton("more", tableName: "NativeChannelProgress") {
                                actions.run { await model.loadMore(history: true) }
                            }
                            .disabled(model.busy)
                            .accessibilityLabel(Text("more", tableName: "NativeChannelProgress"))
                        }
                    }
                }
                NativeChannelProgressIssueView(model: model, part: "recent")
            } header: { NativeChannelSectionTitle(key: "d7.channelProgress.recent") }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, CYSpacing.pageHorizontal, for: .scrollContent)
        .listSectionSpacing(CYSpacing.xxl)
        .nativeChannelScreen()
        .cyHeroScreen()
        .privacySensitive()
        .onAppear { actions.activate() }
        .onDisappear { actions.retire() }
        .onChange(of: model.isCurrent) { _, current in if !current { actions.retire() } }
        .task { await model.refreshOwnHistory() }
        .refreshable { await model.refreshOwnHistory() }
        .accessibilityIdentifier("channelProgress.ownHistory")
    }
}

private struct NativeChannelProgressHistoryLoading: View {
    var body: some View {
        CYSkeleton()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("cy.state.loading"))
            .listRowBackground(Color.clear)
    }
}
